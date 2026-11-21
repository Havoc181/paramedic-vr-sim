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
	# A compact card that grows upwards from just above the object and wraps,
	# so long descriptions stay in view at reading distance.
	_label.font_size = 30
	_label.pixel_size = 0.00085
	_label.render_priority = 20
	_label.outline_render_priority = 19
	_label.outline_size = 10
	_label.no_depth_test = true
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.width = 0.42 / _label.pixel_size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.position = Vector3(0, size.y / 2.0 + 0.05, 0)
	_label.text = title + "\n" + details
	_label.visible = false
	add_child(_label)


var _open := false
## Only one card open at a time, so cards on a crowded table don't overlap.
static var _current: Node = null
var _was_read := false
var _held := false
var _home: Transform3D


func interact() -> void:
	if _held:
		put_back()
		return
	_set_open(not _open)


func _set_open(value: bool) -> void:
	_open = value
	_label.visible = value
	if value:
		if is_instance_valid(_current) and _current != self:
			_current._set_open(false)
		_current = self


## Back where it came from (e.g. after Ken handed it over), closed.
func put_back() -> void:
	if not _held:
		return
	_held = false
	global_transform = _home
	_open = false
	_label.visible = false


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
	if _held:
		_label.text += "\n(point and click the box to put it back)"


## Someone hands this to you: it moves to just in front of you, open.
func hand_to(cam: Node3D) -> void:
	if not _held:
		_home = global_transform
		_held = true
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP).normalized()
	global_position = cam.global_position + fwd * 0.4 - right * 0.12 + Vector3(0, -0.3, 0)
	look_at(cam.global_position, Vector3.UP, true)
	_set_open(true)


func hover_enter() -> void:
	_material.emission_enabled = true
	_material.emission = Color(0.25, 0.35, 0.45)


func hover_exit() -> void:
	_material.emission_enabled = false
