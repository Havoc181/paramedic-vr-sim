extends StaticBody3D
## A simple object you can point at and use to read what it is or contains.

@export var size := Vector3(0.2, 0.1, 0.15)
@export var colour := Color(0.8, 0.8, 0.8)
@export var title := ""
@export_multiline var details := ""

var _label: Label3D
var _material: StandardMaterial3D


func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_material = StandardMaterial3D.new()
	_material.albedo_color = colour
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material
	add_child(mi)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 22
	_label.pixel_size = 0.001
	_label.outline_size = 8
	_label.no_depth_test = true
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.position = Vector3(0, size.y / 2.0 + 0.2, 0)
	_label.text = title + "\n" + details
	_label.visible = false
	add_child(_label)


func interact() -> void:
	_label.visible = not _label.visible


func hover_enter() -> void:
	_material.emission_enabled = true
	_material.emission = Color(0.25, 0.35, 0.45)


func hover_exit() -> void:
	_material.emission_enabled = false
