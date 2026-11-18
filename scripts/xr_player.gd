extends XROrigin3D
## The player rig: movement, turning, teleport landing, comfort vignette,
## fades and seated mode. Comfort settings are saved between sessions.
##
## Controls:
##   Left stick           smooth movement (if enabled)
##   Right stick left/right  turn (snap or smooth)
##   Right stick forward  aim teleport, release to jump (see teleport.gd)
##   Left menu button     open/close the menu (see pause_menu.gd)

signal menu_toggle_requested

enum Turn { SNAP_30, SNAP_45, SMOOTH }

const SETTINGS_PATH := "user://settings.cfg"
const SEATED_EYE_HEIGHT := 1.6

@export var move_speed := 1.3
@export var smooth_turn_speed_deg := 75.0
@export var deadzone := 0.2
## Half-size of the walkable floor area (keeps your head inside the room).
@export var room_half_extents := Vector2(2.15, 1.85)

# Comfort settings (changed from the in-app menu).
var smooth_move_enabled := true
var turn_mode := Turn.SNAP_30
var vignette_enabled := true
var seated := false

## False while the menu is open, so the sticks don't move you.
var input_enabled := true

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left: XRController3D = $LeftController
@onready var right: XRController3D = $RightController

var _comfort_material: ShaderMaterial
var _comfort_sphere: MeshInstance3D
var _vignette := 0.0
var _fade := 0.0
var _fade_tween: Tween
var _snap_ready := true
var _menu_was_pressed := false
var _teleporting := false


func _ready() -> void:
	_create_comfort_sphere()
	load_settings()


func _process(delta: float) -> void:
	var comfort_needed := false
	if input_enabled:
		comfort_needed = _move(delta) or comfort_needed
		comfort_needed = _turn(delta) or comfort_needed
	_menu_button_input()
	_clamp_to_room()

	var target := 1.0 if (comfort_needed and vignette_enabled) else 0.0
	_vignette = move_toward(_vignette, target, delta * 5.0)
	_update_comfort_sphere()


# --- Movement --------------------------------------------------------------

func _move(delta: float) -> bool:
	if not smooth_move_enabled:
		return false
	var stick: Vector2 = left.get_vector2("primary")
	if stick.length() < deadzone:
		return false
	var b := camera.global_transform.basis
	var fwd := -b.z
	fwd.y = 0.0
	var side := b.x
	side.y = 0.0
	var dir := fwd.normalized() * stick.y + side.normalized() * stick.x
	# Ease in from the deadzone so starting to move isn't a jolt.
	var amount := clampf((stick.length() - deadzone) / (1.0 - deadzone), 0.0, 1.0)
	global_position += dir.normalized() * move_speed * amount * delta
	return true


func _turn(delta: float) -> bool:
	var stick: Vector2 = right.get_vector2("primary")
	# Pushing the stick forward is teleport, not turning.
	if stick.y > 0.6 and absf(stick.x) < 0.6:
		return false
	var x := stick.x
	if turn_mode == Turn.SMOOTH:
		if absf(x) < deadzone:
			return false
		_rotate_around_head(-signf(x) * deg_to_rad(smooth_turn_speed_deg) * absf(x) * delta)
		return true
	if _snap_ready and absf(x) > 0.7:
		var angle := 30.0 if turn_mode == Turn.SNAP_30 else 45.0
		_rotate_around_head(-signf(x) * deg_to_rad(angle))
		_snap_ready = false
	elif absf(x) < 0.3:
		_snap_ready = true
	return false


func _rotate_around_head(angle: float) -> void:
	var pivot := camera.global_position
	var t := global_transform
	t.origin -= pivot
	t = t.rotated(Vector3.UP, angle)
	t.origin += pivot
	global_transform = t


func is_inside_room(point: Vector3) -> bool:
	return absf(point.x) <= room_half_extents.x and absf(point.z) <= room_half_extents.y


func _clamp_to_room() -> void:
	var head := camera.global_position
	var dx := clampf(head.x, -room_half_extents.x, room_half_extents.x) - head.x
	var dz := clampf(head.z, -room_half_extents.y, room_half_extents.y) - head.z
	if dx != 0.0 or dz != 0.0:
		global_position += Vector3(dx, 0.0, dz)


## Fade out, move so your head is above `point`, fade back in.
func teleport_to(point: Vector3) -> void:
	if _teleporting:
		return
	_teleporting = true
	await fade_to(1.0, 0.12)
	var head := camera.global_position
	global_position += Vector3(point.x - head.x, 0.0, point.z - head.z)
	await fade_to(0.0, 0.18)
	_teleporting = false


func fade_to(value: float, duration: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "_fade", value, duration)
	await _fade_tween.finished


# --- Seated mode -----------------------------------------------------------

func set_seated(value: bool) -> void:
	seated = value
	if seated:
		# Raise the world-view so a seated player sees from standing height.
		var head_height := camera.position.y
		position.y = clampf(SEATED_EYE_HEIGHT - head_height, 0.0, 1.2)
	else:
		position.y = 0.0
	save_settings()


# --- Menu button -----------------------------------------------------------

func _menu_button_input() -> void:
	var pressed := left.is_button_pressed("menu_button")
	if pressed and not _menu_was_pressed:
		menu_toggle_requested.emit()
	_menu_was_pressed = pressed


# --- Comfort vignette and fade ---------------------------------------------

func _create_comfort_sphere() -> void:
	_comfort_material = ShaderMaterial.new()
	_comfort_material.shader = load("res://shaders/comfort.gdshader")
	_comfort_material.render_priority = 100
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	sphere.radial_segments = 32
	sphere.rings = 16
	_comfort_sphere = MeshInstance3D.new()
	_comfort_sphere.name = "ComfortSphere"
	_comfort_sphere.mesh = sphere
	_comfort_sphere.material_override = _comfort_material
	_comfort_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_comfort_sphere.visible = false
	camera.add_child(_comfort_sphere)


func _update_comfort_sphere() -> void:
	var active := _vignette > 0.001 or _fade > 0.001
	_comfort_sphere.visible = active
	if active:
		_comfort_material.set_shader_parameter("vignette", _vignette)
		_comfort_material.set_shader_parameter("fade", _fade)


# --- Settings --------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	smooth_move_enabled = cfg.get_value("comfort", "smooth_move", smooth_move_enabled)
	turn_mode = cfg.get_value("comfort", "turn_mode", turn_mode)
	vignette_enabled = cfg.get_value("comfort", "vignette", vignette_enabled)
	var was_seated: bool = cfg.get_value("comfort", "seated", false)
	if was_seated:
		# Wait a moment for head tracking before measuring height.
		await get_tree().create_timer(1.0).timeout
		set_seated(true)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("comfort", "smooth_move", smooth_move_enabled)
	cfg.set_value("comfort", "turn_mode", turn_mode)
	cfg.set_value("comfort", "vignette", vignette_enabled)
	cfg.set_value("comfort", "seated", seated)
	cfg.save(SETTINGS_PATH)
