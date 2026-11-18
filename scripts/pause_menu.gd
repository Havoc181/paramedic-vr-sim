extends Node3D
## In-VR menu: comfort options and Quit. Opens in front of you with the left
## controller's menu button (or the button on your left wrist when using hands).

@export var player_path: NodePath

@onready var player = get_node(player_path)

var _buttons := {}
var _open := false

const MENU_BUTTON := preload("res://scripts/menu_button.gd")
## Shown in the menu so testers can say which build they ran.
const APP_VERSION := "v0.03-dev2"


func _ready() -> void:
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
	bg_mesh.size = Vector3(0.42, 0.5, 0.005)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.07, 0.08, 0.1)
	bg_mat.no_depth_test = true
	bg_mat.render_priority = 9
	var bg := MeshInstance3D.new()
	bg.mesh = bg_mesh
	bg.material_override = bg_mat
	bg.position = Vector3(0, 0, -0.008)
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

	var items := ["resume", "movement", "turning", "vignette", "seated", "quit"]
	for i in items.size():
		var b = MENU_BUTTON.new()
		b.name = "Button_" + items[i]
		b.position = Vector3(0, 0.15 - i * 0.07, 0)
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
	_buttons.quit.text = "Quit app"


## Hidden buttons must not block the pointer or the teleport arc.
func _set_buttons_enabled(value: bool) -> void:
	for b in _buttons.values():
		(b as StaticBody3D).collision_layer = 1 if value else 0
