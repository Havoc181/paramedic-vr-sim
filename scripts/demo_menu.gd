extends Node3D
## Demo mode: pick any clinical sign from a list and see it on the patient,
## mild or full, with a caption. Also sets how far into the tripod position she
## is. Opened from the pause menu ("Demo signs"); you can still move around
## while it's open. Uses the sign library, so new signs appear here by themselves.

const MENU_BUTTON := preload("res://scripts/menu_button.gd")
const SIGN_LIB := preload("res://scripts/patient/sign_library.gd")
const ACCENT := Color(0.12, 0.36, 0.42)
const IDLE := Color(0.16, 0.19, 0.24)
const COLS := 2
const BW := 0.3
const BH := 0.042
const GAP := 0.048

var player: Node3D
var _sign_buttons := {}
var _strength_buttons := {}
var _tripod_buttons := {}
var _sign := ""
var _mild := false
var _caption: Label3D
var _open := false


func _ready() -> void:
	visible = false
	_build()
	_set_enabled(false)


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	_open = true
	var cam: Node3D = player.get_node("XRCamera3D")
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	# Off to the right of where you're looking, turned towards you, so the
	# patient stays in view.
	var right := fwd.cross(Vector3.UP).normalized()
	var pos := cam.global_position + fwd * 0.6 + right * 0.42 + Vector3(0, -0.15, 0)
	global_transform = Transform3D(Basis.looking_at((pos - cam.global_position) * Vector3(1, 0, 1), Vector3.UP), pos)
	visible = true
	_set_enabled(true)
	_refresh()


func close() -> void:
	_open = false
	visible = false
	_set_enabled(false)


func _patient() -> Node:
	for c in get_tree().root.find_children("*", "", true, false):
		if c.has_method("reset_skin_signs") and c.data.get("role", "") == "patient":
			return c
	return null


func _build() -> void:
	var rows := int(ceil(SIGN_LIB.ORDER.size() / float(COLS)))
	var top := 0.0
	var h := 0.13 + rows * GAP + 0.18
	var bg := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(COLS * (BW + 0.01) + 0.04, h, 0.005)
	bg.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.07, 0.08, 0.1)
	mat.no_depth_test = true
	mat.render_priority = 9
	bg.material_override = mat
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bg.position = Vector3(0, top + 0.06 - h / 2.0, -0.008)
	add_child(bg)
	_label("Demo mode: clinical signs", 34, Vector3(0, top + 0.03, 0))

	var y0 := top - 0.03
	for i in SIGN_LIB.ORDER.size():
		var id: String = SIGN_LIB.ORDER[i]
		var b = MENU_BUTTON.new()
		b.size = Vector2(BW, BH)
		b.text = SIGN_LIB.SIGNS[id]["label"]
		b.idle_colour = IDLE
		var col := i % COLS
		b.position = Vector3((col - (COLS - 1) / 2.0) * (BW + 0.01), y0 - (i / COLS) * GAP, 0)
		add_child(b)
		_fit(b)
		b.pressed.connect(_pick.bind(id))
		_sign_buttons[id] = b

	var y := y0 - rows * GAP - 0.015
	_label("Strength", 22, Vector3(-0.22, y, 0))
	for k in [["mild", "Mild", -0.04], ["full", "Full", 0.1]]:
		var b = _small(k[1], Vector3(k[2], y, 0), 0.12)
		b.pressed.connect(func(): _mild = k[0] == "mild"; _apply(); _refresh())
		_strength_buttons[k[0]] = b
	y -= GAP
	_label("Tripod", 22, Vector3(-0.22, y, 0))
	for k in [[0.0, "Upright", -0.04], [0.5, "Mild", 0.1], [1.0, "Full", 0.24]]:
		var b = _small(k[1], Vector3(k[2], y, 0), 0.12)
		b.pressed.connect(func():
			var p = _patient()
			if p and p._rig:
				p._rig.set_tripod_level(k[0])
			_refresh())
		_tripod_buttons[k[0]] = b
	y -= GAP
	var reset = _small("Back to scenario signs", Vector3(-0.08, y, 0), 0.3)
	reset.pressed.connect(func(): _pick(""))
	var shut = _small("Close", Vector3(0.22, y, 0), 0.16)
	shut.idle_colour = ACCENT
	shut.pressed.connect(close)


func _small(text: String, pos: Vector3, w: float):
	var b = MENU_BUTTON.new()
	b.size = Vector2(w, BH)
	b.text = text
	b.idle_colour = IDLE
	b.position = pos
	add_child(b)
	_fit(b)
	return b


## Shrink a button's text until it fits inside the button.
func _fit(b) -> void:
	var l: Label3D = b._label
	l.font_size = 22
	var font := l.get_font() if l.get_font() else ThemeDB.fallback_font
	while l.font_size > 12:
		var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * l.pixel_size
		if w <= b.size.x - 0.016:
			break
		l.font_size -= 1


func _label(text: String, size: int, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0008
	l.position = pos
	l.no_depth_test = true
	l.render_priority = 11
	add_child(l)
	return l


func _pick(id: String) -> void:
	_sign = id
	_apply()
	_refresh()


func _apply() -> void:
	var c = _patient()
	if c == null:
		return
	if _caption == null or not is_instance_valid(_caption):
		_caption = Label3D.new()
		_caption.font_size = 30
		_caption.pixel_size = 0.0009
		_caption.width = 700
		_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_caption.outline_size = 8
		c.add_child(_caption)
		_caption.position = Vector3(0, 1.45, 0)
	if _sign == "":
		c.reset_skin_signs()
		if c.can_expose():
			c.set_exposure("on")
		c.set_legs("on")
		_caption.visible = false
		return
	var info: Dictionary = SIGN_LIB.SIGNS[_sign]
	var all := {}
	all[_sign] = float(info.get("mild", 0.4)) if _mild else 0.85
	c._rig.signs.set_all(all)
	var need: String = info.get("exposure", "")
	if c.can_expose():
		c.set_exposure({"abdomen": "lifted", "chest": "off"}.get(need, "on"))
	c.set_legs("off" if need == "legs" else "on")
	if _sign == "cyanosis_tongue":
		c.open_mouth(6.0)
	var note := ""
	if need == "legs" and not c.can_expose_legs():
		note = "\n(This patient's model can't show the legs yet.)"
	elif info.get("seen", "") == "I":
		note = "\n(Try it: hold a fingertip with grip, then let go.)"
	_caption.text = "%s (%s)\n%s%s" % [info["label"], "mild" if _mild else "full", String(info.get("demo", "")), note]
	_caption.visible = true


func _refresh() -> void:
	for id in _sign_buttons:
		_sign_buttons[id].idle_colour = ACCENT if id == _sign else IDLE
	_strength_buttons["mild"].idle_colour = ACCENT if _mild else IDLE
	_strength_buttons["full"].idle_colour = IDLE if _mild else ACCENT
	var p = _patient()
	var lvl: float = p._rig.tripod_level if p and p._rig else 1.0
	for k in _tripod_buttons:
		_tripod_buttons[k].idle_colour = ACCENT if absf(k - lvl) < 0.01 else IDLE


func _set_enabled(value: bool) -> void:
	for b in find_children("*", "StaticBody3D", false, false):
		(b as StaticBody3D).collision_layer = 1 if value else 0
