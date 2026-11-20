extends StaticBody3D
## A flat button for in-VR menus. Point at it and pull the trigger (or pinch).

signal pressed

@export var size := Vector2(0.34, 0.06)
@export var text := "Button":
	set(value):
		text = value
		if _label:
			_label.text = value

## Colour when not pointed at (accent buttons such as Next use a brighter one).
@export var idle_colour := Color(0.16, 0.2, 0.26):
	set(value):
		idle_colour = value
		if _material and not _hovered:
			_material.albedo_color = value
@export var hover_colour := Color(0.22, 0.42, 0.62)
## If set, the visible bar is this tall while the pointer target stays `size`
## (thin page-bar segments that are still easy to hit).
@export var visual_height := 0.0

var _hovered := false

var _label: Label3D
var _material: StandardMaterial3D
var _mesh: BoxMesh
var _shape: BoxShape3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = idle_colour
	# Menus draw on top of the world so furniture or people never hide them.
	_material.no_depth_test = true
	_material.render_priority = 10
	var mesh := BoxMesh.new()
	_mesh = mesh
	mesh.size = Vector3(size.x, visual_height if visual_height > 0.0 else size.y, 0.01)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var shape := BoxShape3D.new()
	_shape = shape
	shape.size = Vector3(size.x, size.y, 0.02)
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)

	_label = Label3D.new()
	_label.text = text
	_label.font_size = 28
	_label.pixel_size = 0.0008
	_label.position = Vector3(0, 0, 0.007)
	_label.modulate = Color(0.95, 0.97, 1.0)
	_label.outline_size = 0
	_label.no_depth_test = true
	_label.render_priority = 11
	add_child(_label)


## Re-apply `size` / `visual_height` after changing them at runtime.
func _resize() -> void:
	if _mesh:
		_mesh.size = Vector3(size.x, visual_height if visual_height > 0.0 else size.y, 0.01)
		_shape.size = Vector3(size.x, size.y, 0.02)


func interact() -> void:
	pressed.emit()


func hover_enter() -> void:
	_hovered = true
	_material.albedo_color = hover_colour


func hover_exit() -> void:
	_hovered = false
	_material.albedo_color = idle_colour
