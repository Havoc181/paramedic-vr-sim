extends StaticBody3D
## A simple object you can point at and use to read what it is or contains.

## Emitted once, the first time someone is close enough to read the details.
signal read

@export var size := Vector3(0.2, 0.1, 0.15)
@export var colour := Color(0.8, 0.8, 0.8)
@export var title := ""
@export_multiline var details := ""
## You have to be this close (metres, from your head) to read the details.
@export var read_distance := 0.9

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
	_label.font_size = 32
	_label.pixel_size = 0.0011
	_label.render_priority = 20
	_label.outline_render_priority = 19
	_label.outline_size = 8
	_label.no_depth_test = true
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.position = Vector3(0, size.y / 2.0 + 0.2, 0)
	_label.text = title + "\n" + details
	_label.visible = false
	add_child(_label)


var _open := false
var _was_read := false


func interact() -> void:
	_open = not _open
	_label.visible = _open


func _process(_delta: float) -> void:
	if not _open:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var near := cam.global_position.distance_to(global_position) <= read_distance
	if near and not _was_read:
		_was_read = true
		read.emit()
	_label.text = (title + "\n" + details) if near else (title + "\n(get closer to read)")


## Someone hands this to you: it moves to just in front of you, open.
func hand_to(cam: Node3D) -> void:
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP).normalized()
	global_position = cam.global_position + fwd * 0.4 - right * 0.12 + Vector3(0, -0.3, 0)
	look_at(cam.global_position, Vector3.UP, true)
	_open = true
	_label.visible = true


func hover_enter() -> void:
	_material.emission_enabled = true
	_material.emission = Color(0.25, 0.35, 0.45)


func hover_exit() -> void:
	_material.emission_enabled = false
