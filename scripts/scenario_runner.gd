extends Node3D
## Loads a scenario file, places its characters and props in the room,
## and connects them to the interaction panel.

@export_file("*.json") var scenario_path := "res://scenarios/apo_01.json"
@export var room_path: NodePath
@export var player_path: NodePath

const CHARACTER := preload("res://scripts/patient/character.gd")
const PANEL := preload("res://scripts/interaction_panel.gd")
const DEBRIEF := preload("res://scripts/debrief.gd")
const LINK := preload("res://scripts/session_link.gd")

var scenario := {}
var characters := {}

@onready var room: Node3D = get_node(room_path)
@onready var player = get_node(player_path)

var _panel
var _debrief
## Things in the room the learner has looked at (for the debrief).
var seen := {}
var link
var _severity := 0.0
var _paused := false
var _message: Label3D
var _message_timer := 0.0


func _ready() -> void:
	scenario = load_scenario(scenario_path)
	if scenario.is_empty():
		push_error("Could not load scenario: " + scenario_path)
		return
	# The room builds itself in its own _ready; wait a frame so its markers exist.
	await get_tree().process_frame
	_spawn_characters()
	_spawn_props()
	_panel = PANEL.new()
	_panel.name = "InteractionPanel"
	add_child(_panel)
	_panel.setup(self, player)
	for c in characters.values():
		c.interacted.connect(func(_who): _panel.open())
	_debrief = DEBRIEF.new()
	_debrief.name = "Debrief"
	_debrief.visible = false
	add_child(_debrief)
	_panel.finished.connect(_on_finished)
	_setup_link()


func _on_finished(impression: String, urgency: String) -> void:
	_debrief.show_debrief(scenario, _panel.asked_ids(), _panel.assessed, seen, impression, urgency, player)
	if link:
		link.log_event("debrief", "Debrief opened")


# --- Instructor link -----------------------------------------------------------

func _setup_link() -> void:
	link = LINK.new()
	link.name = "SessionLink"
	link.player = player
	link.scenario_name = String(scenario.get("title", scenario.get("id", "Scenario")))
	add_child(link)
	link.command.connect(_on_command)
	_panel.logged.connect(func(kind, text): link.log_event(kind, text))
	_update_state()


func _update_state() -> void:
	link.state = {"paused": _paused, "severity": _severity}
	link.send_state()


func _on_command(msg: Dictionary) -> void:
	var events: Dictionary = scenario.get("instructor_events", {})
	match String(msg.get("c", "")):
		"pause":
			_set_paused(true)
		"resume":
			_set_paused(false)
		"severity":
			_severity = clampf(float(msg.get("v", 0.0)), -1.0, 1.0)
			for c in characters.values():
				if c.data.get("role", "") == "patient":
					c.set_severity(_severity)
			link.log_event("instructor", "Patient condition set to %+.1f (%s)" % [_severity,
					"worse" if _severity > 0.05 else ("better" if _severity < -0.05 else "as written")])
		"ken_interrupt":
			var ev: Dictionary = events.get("ken_interrupt", {})
			var lines: Array = ev.get("lines", [])
			var who = characters.get(String(ev.get("by", "ken")))
			if who and not lines.is_empty():
				var line := String(lines.pick_random())
				who.say(line)
				link.log_event("instructor", "Event: Ken interrupts: \"" + line + "\"")
		"phone_ring":
			_ring_phone(events.get("phone_ring", {}))
			link.log_event("instructor", "Event: the phone rings")
		"hint":
			var text := String(msg.get("text", "")).strip_edges()
			if text != "":
				_show_message("Instructor: " + text, 8.0)
				link.log_event("instructor", "Hint: " + text)
		"reveal_obs":
			_show_message(String(events.get("obs_text", "No observations in this scenario.")), 15.0)
			link.log_event("instructor", "Observations shown")
		"end":
			_set_paused(false)
			_panel.open_finish()
			link.log_event("instructor", "Scenario ended: learner asked for impression")
	_update_state()


func _set_paused(on: bool) -> void:
	if on == _paused:
		return
	_paused = on
	for c in characters.values():
		c.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if on:
		_show_message("Paused by your instructor", 0.0)
	else:
		_message.visible = false
	link.log_event("instructor", "Paused" if on else "Resumed")


## A message floating just below your view (hints, observations, pause).
func _show_message(text: String, seconds: float) -> void:
	if _message == null:
		_message = Label3D.new()
		_message.font_size = 30
		_message.pixel_size = 0.0007
		_message.width = 900.0
		_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_message.outline_size = 10
		_message.outline_modulate = Color(0, 0, 0, 0.85)
		_message.modulate = Color(1.0, 0.95, 0.7)
		_message.no_depth_test = true
		_message.render_priority = 40
		_message.outline_render_priority = 39
		_message.position = Vector3(0, -0.16, -0.7)
		player.get_node("XRCamera3D").add_child(_message)
	_message.text = text
	_message.visible = true
	_message_timer = seconds


func _process(delta: float) -> void:
	if _message and _message.visible and _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message.visible = false


## A UK landline ring (400 + 450 Hz; 0.4 on, 0.2 off, 0.4 on, 2 s off), three
## times, from the hallway side of the room; then Ken's line.
func _ring_phone(ev: Dictionary) -> void:
	var rate := 22050
	var pattern := [[0.4, true], [0.2, false], [0.4, true], [2.0, false]]
	var data := PackedByteArray()
	for _r in 3:
		for seg in pattern:
			var n := int(rate * float(seg[0]))
			for i in n:
				var v := 0.0
				if seg[1]:
					var t := float(i) / rate
					v = 0.25 * (sin(TAU * 400.0 * t) + sin(TAU * 450.0 * t))
				var s16 := int(clampf(v, -1.0, 1.0) * 32767.0)
				data.append(s16 & 0xFF)
				data.append((s16 >> 8) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	var p := AudioStreamPlayer3D.new()
	p.stream = wav
	p.unit_size = 2.0
	p.volume_db = -4.0
	add_child(p)
	p.global_position = Vector3(-2.0, 0.9, 1.2)
	p.play()
	p.finished.connect(p.queue_free)
	var after: Dictionary = ev.get("after_line", {})
	var who = characters.get(String(after.get("by", "")))
	if who:
		await get_tree().create_timer(4.0).timeout
		who.say(String(after.get("text", "")))


static func load_scenario(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _spawn_characters() -> void:
	var defs: Dictionary = scenario.get("characters", {})
	for cid in defs:
		var def: Dictionary = defs[cid]
		var c = CHARACTER.new()
		c.name = "Character_" + String(cid)
		add_child(c)
		if def.get("role", "") == "patient":
			var seat: Node3D = room.find_child(String(def.get("seat", "PatientSeat")).get_file(), true, false)
			if seat:
				c.global_transform = seat.global_transform
		else:
			# Bystander stands at the end of the sofa, turned towards the room.
			c.global_position = Vector3(0.95, 0.0, -0.55)
			c.look_at(Vector3(-0.6, 0.0, 0.6), Vector3.UP, true)
		c.setup(String(cid), def)
		characters[String(cid)] = c


func _spawn_props() -> void:
	for p in scenario.get("props", []):
		match String(p.get("id", "")):
			"pillows":
				for i in 3:
					var pillow := _prop_box(Vector3(0.5, 0.12, 0.34), Color(0.92, 0.92, 0.95))
					pillow.global_position = Vector3(0.38, 0.49 + i * 0.11, -1.62)
					pillow.rotation_degrees = Vector3(-12, 8.0 * (i - 1), 0)
			"tissue":
				var t := _prop_box(Vector3(0.1, 0.02, 0.1), Color(0.97, 0.95, 0.95))
				t.global_position = Vector3(-1.25, 0.67, -1.4)
			"medicines_box":
				_spawn_medicines_box(p)


func _spawn_medicines_box(p: Dictionary) -> void:
	var box := preload("res://scripts/info_prop.gd").new()
	box.name = "MedicinesBox"
	box.size = Vector3(0.24, 0.11, 0.17)
	box.colour = Color(0.85, 0.88, 0.92)
	box.title = "Medicines box"
	var lines := PackedStringArray()
	for item in p.get("contents", []):
		lines.append("- " + String(item))
	box.details = "\n".join(lines)
	add_child(box)
	box.read.connect(func():
		seen["medicines_box"] = true
		if link:
			link.log_event("checked", "Read the medicines box"))
	box.global_position = Vector3(1.05, 0.625, -1.68)
	box.rotation_degrees.y = 15.0


func _prop_box(size: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	add_child(mi)
	return mi
