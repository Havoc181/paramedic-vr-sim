extends Node3D
## Main menu shown when the app starts in the headset: pick a scenario.
## Each card shows only what a crew would know from the call (no diagnosis).
## The comfort settings stay on the left menu button, as in a scenario.

const MENU_BUTTON := preload("res://scripts/menu_button.gd")
const RUNNER := preload("res://scripts/scenario_runner.gd")
const PAUSE := preload("res://scripts/pause_menu.gd")
const ACCENT := Color(0.12, 0.36, 0.42)

var player: Node3D
var _buttons: Array = []


func setup(p: Node3D) -> void:
	player = p
	_build()
	# Wait for the headset pose before placing the menu in front of you.
	await get_tree().create_timer(0.6).timeout
	recentre()


func recentre() -> void:
	var cam: Node3D = player.get_node("XRCamera3D")
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var pos := cam.global_position + fwd * 0.95 + Vector3(0, -0.08, 0)
	global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)


func _label(text: String, size: int, pos: Vector3, colour := Color(0.95, 0.97, 1.0), width := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.001
	l.position = pos
	l.modulate = colour
	l.no_depth_test = true
	l.render_priority = 11
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = width / l.pixel_size
	add_child(l)
	return l


func _build() -> void:
	var scenarios: Array = []
	for path in RUNNER.SCENARIOS:
		var sc: Dictionary = RUNNER.load_scenario(path)
		if not sc.is_empty():
			scenarios.append([path, sc])
	var h := 0.36 + scenarios.size() * 0.19
	var bg := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.95, h, 0.005)
	bg.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.07, 0.08, 0.1)
	mat.no_depth_test = true
	mat.render_priority = 9
	bg.material_override = mat
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bg.position = Vector3(0, 0.2 - h / 2.0, -0.008)
	add_child(bg)

	_label("HAVOC EDUCATION", 22, Vector3(0, 0.155, 0), Color(0.55, 0.8, 0.85))
	_label("Paramedic VR Sim", 48, Vector3(0, 0.11, 0))
	_label("Choose a call. You'll know what the crew would know.", 22, Vector3(0, 0.06, 0), Color(0.72, 0.76, 0.82))

	var y := -0.04
	for entry in scenarios:
		var sc: Dictionary = entry[1]
		var m: Dictionary = sc.get("menu", {})
		var b = MENU_BUTTON.new()
		b.size = Vector2(0.85, 0.16)
		b.idle_colour = Color(0.13, 0.16, 0.21)
		b.text = ""
		b.position = Vector3(0, y, 0)
		add_child(b)
		b.pressed.connect(RUNNER.start.bind(entry[0], get_tree()))
		_buttons.append(b)
		_label(String(m.get("label", sc.get("id", ""))), 30, Vector3(0, y + 0.042, 0.008))
		_label("Dispatch: " + String(sc.get("dispatch", "")), 20, Vector3(0, y - 0.025, 0.008), Color(0.78, 0.82, 0.88), 0.76)
		if m.get("draft", false):
			_label("DRAFT", 18, Vector3(0.375, y + 0.062, 0.008), Color(0.95, 0.75, 0.35))
		y -= 0.19

	var rc = MENU_BUTTON.new()
	rc.size = Vector2(0.3, 0.05)
	rc.text = "Recentre menu"
	rc.idle_colour = ACCENT
	rc.position = Vector3(-0.2, y + 0.04, 0)
	add_child(rc)
	rc.pressed.connect(recentre)
	var q = MENU_BUTTON.new()
	q.size = Vector2(0.3, 0.05)
	q.text = "Quit app"
	q.position = Vector3(0.2, y + 0.04, 0)
	add_child(q)
	q.pressed.connect(func(): get_tree().quit())
	_label("Left menu button: comfort settings   ·   " + PAUSE.APP_VERSION, 18, Vector3(0, y - 0.025, 0), Color(0.55, 0.6, 0.66))

