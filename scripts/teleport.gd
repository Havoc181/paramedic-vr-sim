extends Node3D
## Teleport: push the right stick forward to show an arc from the right
## controller, release to jump there. Only lands on open floor inside the room.

@export var launch_speed := 7.0
@export var gravity := 9.8
@export var max_steps := 40
@export var step_time := 0.035
@export var valid_colour := Color(0.3, 0.85, 1.0)
@export var invalid_colour := Color(1.0, 0.35, 0.3)

var aiming := false

@onready var player = get_parent()
@onready var controller: XRController3D = player.get_node("RightController")

var _target := Vector3.ZERO
var _target_valid := false
var _dots: MultiMeshInstance3D
var _dot_material: StandardMaterial3D
var _marker: MeshInstance3D


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_build_visuals()
	_set_visible(false)


func _process(_delta: float) -> void:
	if not player.input_enabled:
		if aiming:
			aiming = false
			_set_visible(false)
		return
	var stick: Vector2 = controller.get_vector2("primary")
	var wants_aim := stick.y > 0.6 and absf(stick.x) < 0.6
	if wants_aim:
		aiming = true
		_set_visible(true)
		_update_arc()
	elif aiming and stick.length() < 0.3:
		aiming = false
		_set_visible(false)
		if _target_valid:
			player.teleport_to(_target)


func _update_arc() -> void:
	var space := get_world_3d().direct_space_state
	var t := controller.global_transform
	var pos := t.origin
	var vel := -t.basis.z * launch_speed
	var count := 0
	_target_valid = false
	var hit := false
	for i in max_steps:
		_dots.multimesh.set_instance_transform(i, Transform3D(Basis(), pos))
		count = i + 1
		var next := pos + vel * step_time
		vel.y -= gravity * step_time
		var query := PhysicsRayQueryParameters3D.create(pos, next)
		var result := space.intersect_ray(query)
		if not result.is_empty():
			_target = result.position
			var normal: Vector3 = result.normal
			# Only open floor counts: not table tops, sofa cushions or walls.
			_target_valid = normal.y > 0.7 and _target.y < 0.1 and player.is_inside_room(_target)
			hit = true
			break
		pos = next
	_dots.multimesh.visible_instance_count = count
	_marker.visible = hit
	if hit:
		_marker.global_position = _target + Vector3(0, 0.01, 0)
	var colour := valid_colour if _target_valid else invalid_colour
	_dot_material.albedo_color = colour
	(_marker.material_override as StandardMaterial3D).albedo_color = colour


func _build_visuals() -> void:
	_dot_material = StandardMaterial3D.new()
	_dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dot_material.albedo_color = valid_colour

	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.012
	dot_mesh.height = 0.024
	dot_mesh.radial_segments = 8
	dot_mesh.rings = 4
	dot_mesh.material = _dot_material

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dot_mesh
	mm.instance_count = max_steps
	_dots = MultiMeshInstance3D.new()
	_dots.multimesh = mm
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dots)

	var ring := TorusMesh.new()
	ring.inner_radius = 0.2
	ring.outer_radius = 0.24
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = valid_colour
	_marker = MeshInstance3D.new()
	_marker.mesh = ring
	_marker.material_override = ring_mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)


func _set_visible(value: bool) -> void:
	_dots.visible = value
	_marker.visible = value and _marker.visible
