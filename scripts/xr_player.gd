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

var _comfort_sphere: Node3D
var _vignette_mesh: MeshInstance3D
var _vignette_material: StandardMaterial3D
var _fade_mesh: MeshInstance3D
var _fade_material: StandardMaterial3D
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
	# Built from plain StandardMaterial3D (no custom shader) so it renders the
	# same on every device. A ring in front of the eyes: clear in the middle,
	# dark at the edges; plus a full black quad for teleport fades.
	_comfort_sphere = Node3D.new()
	_comfort_sphere.name = "Comfort"
	camera.add_child(_comfort_sphere)

	var d := 0.2
	var r_clear := d * tan(deg_to_rad(28.0))
	var r_dark := d * tan(deg_to_rad(52.0))
	var r_outer := 1.5
	var segs := 48
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [[r_clear, 0.0], [r_dark, 1.0], [r_outer, 1.0]]
	for ring in 2:
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var r_in: float = rings[ring][0]
			var r_out: float = rings[ring + 1][0]
			var c_in := Color(0, 0, 0, rings[ring][1])
			var c_out := Color(0, 0, 0, rings[ring + 1][1])
			var p0 := Vector3(cos(a0) * r_in, sin(a0) * r_in, -d)
			var p1 := Vector3(cos(a1) * r_in, sin(a1) * r_in, -d)
			var p2 := Vector3(cos(a1) * r_out, sin(a1) * r_out, -d)
			var p3 := Vector3(cos(a0) * r_out, sin(a0) * r_out, -d)
			for v in [[p0, c_in], [p1, c_in], [p2, c_out], [p0, c_in], [p2, c_out], [p3, c_out]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
	_vignette_mesh = MeshInstance3D.new()
	_vignette_mesh.mesh = st.commit()
	_vignette_material = _overlay_material(true)
	_vignette_mesh.material_override = _vignette_material
	_vignette_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_comfort_sphere.add_child(_vignette_mesh)

	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_fade_mesh = MeshInstance3D.new()
	_fade_mesh.mesh = quad
	_fade_mesh.position = Vector3(0, 0, -0.15)
	_fade_material = _overlay_material(false)
	_fade_mesh.material_override = _fade_material
	_fade_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_comfort_sphere.add_child(_fade_mesh)
	_vignette_mesh.visible = false
	_fade_mesh.visible = false


func _overlay_material(use_vertex_alpha: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = use_vertex_alpha
	m.albedo_color = Color(0, 0, 0, 0)
	m.render_priority = 100
	return m


func _update_comfort_sphere() -> void:
	_vignette_mesh.visible = _vignette > 0.001
	_fade_mesh.visible = _fade > 0.001
	if _vignette_mesh.visible:
		_vignette_material.albedo_color = Color(1, 1, 1, _vignette) if _vignette_material.vertex_color_use_as_albedo else Color(0, 0, 0, _vignette)
	if _fade_mesh.visible:
		_fade_material.albedo_color = Color(0, 0, 0, _fade)


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
