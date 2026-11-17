extends XROrigin3D
## Left thumbstick: smooth movement relative to where you're looking.
## Right thumbstick: snap turn. Keeps you inside the room.

@export var move_speed := 1.5
@export var snap_angle_deg := 30.0
@export var deadzone := 0.2
@export var room_half_extents := Vector2(2.8, 2.3)

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left: XRController3D = $LeftController
@onready var right: XRController3D = $RightController

var _snap_ready := true


func _process(delta: float) -> void:
	_move(delta)
	_snap_turn_input()
	_clamp_to_room()


func _move(delta: float) -> void:
	var stick: Vector2 = left.get_vector2("primary")
	if stick.length() < deadzone:
		return
	var b := camera.global_transform.basis
	var fwd := -b.z
	fwd.y = 0.0
	var side := b.x
	side.y = 0.0
	var dir := fwd.normalized() * stick.y + side.normalized() * stick.x
	global_position += dir * move_speed * delta


func _snap_turn_input() -> void:
	var x: float = right.get_vector2("primary").x
	if _snap_ready and absf(x) > 0.7:
		_rotate_around_head(-signf(x) * deg_to_rad(snap_angle_deg))
		_snap_ready = false
	elif absf(x) < 0.3:
		_snap_ready = true


func _rotate_around_head(angle: float) -> void:
	var pivot := camera.global_position
	var t := global_transform
	t.origin -= pivot
	t = t.rotated(Vector3.UP, angle)
	t.origin += pivot
	global_transform = t


func _clamp_to_room() -> void:
	var head := camera.global_position
	var dx := clampf(head.x, -room_half_extents.x, room_half_extents.x) - head.x
	var dz := clampf(head.z, -room_half_extents.y, room_half_extents.y) - head.z
	if dx != 0.0 or dz != 0.0:
		global_position += Vector3(dx, 0.0, dz)
