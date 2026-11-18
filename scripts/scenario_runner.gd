extends Node3D
## Loads a scenario file, places its characters and props in the room,
## and connects them to the interaction panel.

@export_file("*.json") var scenario_path := "res://scenarios/apo_01.json"
@export var room_path: NodePath
@export var player_path: NodePath

const CHARACTER := preload("res://scripts/patient/character.gd")
const PANEL := preload("res://scripts/interaction_panel.gd")

var scenario := {}
var characters := {}

@onready var room: Node3D = get_node(room_path)
@onready var player = get_node(player_path)

var _panel


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
