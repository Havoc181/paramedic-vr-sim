extends Node3D
## In-VR menu: comfort options and Quit. Opens in front of you with the left
## controller's menu button (or the button on your left wrist when using hands).

@export var player_path: NodePath

@onready var player = get_node(player_path)

var _buttons := {}
var _open := false

const MENU_BUTTON := preload("res://scripts/menu_button.gd")
## Shown in the menu so testers can say which build they ran.
const APP_VERSION := "v0.05-dev9"

## Test options: NOT saved, so if one misbehaves, quitting and reopening resets it.
## Foveation removed 2026-11-20: every level gave the grey screen on Quest 3.
var _fps_label: Label3D
var _link_label: Label3D
var _refresh_rates: Array = []
var _refresh_index := -1
const SCENARIOS := [["01 Breathless (APO), Joan", "res://scenarios/apo_01.json"],
		["02 COPD + haemoptysis, Maureen (draft)", "res://scenarios/copd_02.json"]]

## Demo mode: show each clinical sign on its own on the patient, with a caption.
const SIGN_LIB := preload("res://scripts/patient/sign_library.gd")
var _demo_caption: Label3D
var _signs_index := 0


func _ready() -> void:
	set_process(false)
	visible = false
	_build()
	player.menu_toggle_requested.connect(toggle)


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	_open = true
	_refresh_labels()
	# Place the panel 0.65 m in front of the head, level and facing you.
	var cam: XRCamera3D = player.get_node("XRCamera3D")
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var pos := cam.global_position + fwd * 0.65 + Vector3(0, -0.12, 0)
	global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)
	_set_buttons_enabled(true)
	visible = true
	player.input_enabled = false


func close() -> void:
	_open = false
	visible = false
	_set_buttons_enabled(false)
	player.input_enabled = true


func _build() -> void:
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(0.42, 0.71, 0.005)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.07, 0.08, 0.1)
	bg_mat.no_depth_test = true
	bg_mat.render_priority = 9
	var bg := MeshInstance3D.new()
	bg.mesh = bg_mesh
	bg.material_override = bg_mat
	bg.position = Vector3(0, -0.105, -0.008)
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bg)

	var title := Label3D.new()
	title.text = "Paramedic VR Sim  " + APP_VERSION
	title.font_size = 36
	title.pixel_size = 0.0008
	title.position = Vector3(0, 0.215, 0)
	title.no_depth_test = true
	title.render_priority = 11
	add_child(title)

	_link_label = Label3D.new()
	_link_label.font_size = 20
	_link_label.pixel_size = 0.0008
	_link_label.position = Vector3(0, -0.42, 0)
	_link_label.modulate = Color(0.7, 0.8, 0.9)
	_link_label.no_depth_test = true
	_link_label.render_priority = 11
	add_child(_link_label)

	var items := ["resume", "scenario", "movement", "turning", "vignette", "seated", "fps", "refresh", "signs", "quit"]
	for i in items.size():
		var b = MENU_BUTTON.new()
		b.name = "Button_" + items[i]
		b.position = Vector3(0, 0.16 - i * 0.056, 0)
		add_child(b)
		b.pressed.connect(_on_pressed.bind(items[i]))
		_buttons[items[i]] = b
	_set_buttons_enabled(false)


func _on_pressed(id: String) -> void:
	match id:
		"resume":
			close()
			return
		"movement":
			player.smooth_move_enabled = not player.smooth_move_enabled
		"turning":
			player.turn_mode = (player.turn_mode + 1) % 3
		"vignette":
			player.vignette_enabled = not player.vignette_enabled
		"seated":
			player.set_seated(not player.seated)
		"fps":
			_toggle_fps()
		"refresh":
			var xr2 := _xr()
			if xr2 and not _refresh_rates.is_empty():
				_refresh_index = (_refresh_index + 1) % _refresh_rates.size()
				xr2.display_refresh_rate = _refresh_rates[_refresh_index]
		"scenario":
			# Load the next scenario (restarts the room).
			var runner_script := load("res://scripts/scenario_runner.gd")
			var cur: String = runner_script.next_path if runner_script.next_path != "" else SCENARIOS[0][1]
			var idx := 0
			for k in SCENARIOS.size():
				if SCENARIOS[k][1] == cur:
					idx = k
			runner_script.next_path = SCENARIOS[(idx + 1) % SCENARIOS.size()][1]
			get_tree().paused = false
			get_tree().reload_current_scene()
			return
		"signs":
			_signs_index = (_signs_index + 1) % (SIGN_LIB.ORDER.size() + 1)
			_apply_signs()
		"quit":
			get_tree().quit()
			return
	player.save_settings()
	_refresh_labels()


func _refresh_labels() -> void:
	var turn_names := ["Snap 30°", "Snap 45°", "Smooth"]
	_buttons.resume.text = "Resume"
	_buttons.movement.text = "Movement: " + ("Stick + teleport" if player.smooth_move_enabled else "Teleport only")
	_buttons.turning.text = "Turning: " + turn_names[player.turn_mode]
	_buttons.vignette.text = "Comfort vignette: " + ("On" if player.vignette_enabled else "Off")
	_buttons.seated.text = "Seated mode: " + ("On" if player.seated else "Off")
	_buttons.fps.text = "Test: frame rate shown: " + ("On" if _fps_label and _fps_label.visible else "Off")
	_buttons.refresh.text = "Test: refresh rate: " + _refresh_text()
	_buttons.signs.text = "Demo sign: " + _demo_name()
	var rs := load("res://scripts/scenario_runner.gd")
	var cur: String = rs.next_path if rs.next_path != "" else SCENARIOS[0][1]
	var title := cur
	for sc in SCENARIOS:
		if sc[1] == cur:
			title = sc[0]
	_buttons.scenario.text = "Scenario: " + title + "  (change)"
	_buttons.quit.text = "Quit app"
	var link = get_tree().get_first_node_in_group("session_link")
	if _link_label:
		if link == null:
			_link_label.text = "Instructor link: not running"
		else:
			var addr: PackedStringArray = link.local_addresses()
			var where := ", ".join(addr) if addr.size() > 0 else "no network address"
			_link_label.text = "Instructor link: " + ("connected" if link.connected() else "waiting on " + where) \
					+ ("" if link.status == "" else "  (" + link.status + ")")


func _xr() -> OpenXRInterface:
	var xr := XRServer.find_interface("OpenXR") as OpenXRInterface
	return xr if xr and xr.is_initialized() else null


func _refresh_text() -> String:
	var xr := _xr()
	if xr == null:
		return "n/a"
	if _refresh_rates.is_empty():
		_refresh_rates = Array(xr.get_available_display_refresh_rates())
		_refresh_rates.sort()
		_refresh_index = _refresh_rates.find(xr.display_refresh_rate)
	if _refresh_rates.is_empty():
		return "%d Hz (fixed)" % int(round(xr.display_refresh_rate))
	return "%d Hz" % int(round(xr.display_refresh_rate))


## Small frame-rate readout fixed below your view, for performance testing.
func _toggle_fps() -> void:
	if _fps_label == null:
		_fps_label = Label3D.new()
		_fps_label.font_size = 28
		_fps_label.pixel_size = 0.0006
		_fps_label.position = Vector3(0, -0.12, -0.5)
		_fps_label.no_depth_test = true
		_fps_label.render_priority = 30
		_fps_label.modulate = Color(0.6, 1.0, 0.6)
		_fps_label.visible = false
		player.get_node("XRCamera3D").add_child(_fps_label)
	_fps_label.visible = not _fps_label.visible
	set_process(_fps_label.visible)


func _process(_delta: float) -> void:
	if _fps_label and _fps_label.visible:
		var ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_fps_label.text = "%d fps   %.1f ms   %d draw calls" % [Engine.get_frames_per_second(), ms,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]


## Hidden buttons must not block the pointer or the teleport arc.
func _set_buttons_enabled(value: bool) -> void:
	for b in _buttons.values():
		(b as StaticBody3D).collision_layer = 1 if value else 0


func _demo_name() -> String:
	if _signs_index == 0:
		return "off (as scenario)"
	return SIGN_LIB.SIGNS[SIGN_LIB.ORDER[_signs_index - 1]]["label"]


func _apply_signs() -> void:
	for c in get_tree().root.find_children("*", "", true, false):
		if not (c.has_method("reset_skin_signs") and c.data.get("role", "") == "patient"):
			continue
		if _demo_caption == null:
			_demo_caption = Label3D.new()
			_demo_caption.font_size = 30
			_demo_caption.pixel_size = 0.0009
			_demo_caption.width = 700
			_demo_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_demo_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_demo_caption.outline_size = 8
			c.add_child(_demo_caption)
			_demo_caption.position = Vector3(0, 1.45, 0)
		if _signs_index == 0:
			c.reset_skin_signs()
			if c.can_expose():
				c.set_exposure("on")
			c.set_legs("on")
			_demo_caption.visible = false
			return
		var id: String = SIGN_LIB.ORDER[_signs_index - 1]
		var info: Dictionary = SIGN_LIB.SIGNS[id]
		var all := {}
		all[id] = 0.85
		c._rig.signs.set_all(all)
		var need: String = info.get("exposure", "")
		if c.can_expose():
			c.set_exposure({"abdomen": "lifted", "chest": "off"}.get(need, "on"))
		c.set_legs("off" if need == "legs" else "on")
		var note := ""
		if need == "legs" and not c.can_expose_legs():
			note = "\n(This patient's model can't show the legs yet.)"
		elif info.get("seen", "") == "I":
			note = "\n(Try it: hold a fingertip with grip, then let go.)"
		_demo_caption.text = info["label"] + "\n" + String(info.get("demo", "")) + note
		_demo_caption.visible = true
