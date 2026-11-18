extends Node3D
## Panel opened by pointing at the patient or bystander.
## "Ask" lists history questions (answered aloud as subtitles by whoever
## would answer); "Look, listen, feel" lists first-impression assessments.

const BUTTON := preload("res://scripts/menu_button.gd")
const PER_PAGE := 6

var runner
var player

var _tab := "ask"
var _page := 0
var _asked := {}
var _tab_buttons := {}
var _item_buttons: Array = []
var _prev
var _next
var _result: Label3D
var _items: Array = []
var _speaking := false


func setup(scenario_runner, xr_player) -> void:
	runner = scenario_runner
	player = xr_player
	player.menu_toggle_requested.connect(close)
	_build()
	visible = false
	_set_enabled(false)


func open() -> void:
	if visible:
		return
	var cam: Node3D = player.get_node("XRCamera3D")
	var fwd: Vector3 = -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	# Off to the right of where you're looking, so the patient stays in view.
	var right := fwd.cross(Vector3.UP).normalized()
	var pos: Vector3 = cam.global_position + fwd * 0.5 + right * 0.32 + Vector3(0, -0.1, 0)
	var face := pos - cam.global_position
	face.y = 0.0
	global_transform = Transform3D(Basis.looking_at(face.normalized(), Vector3.UP), pos)
	visible = true
	player.input_enabled = false
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	_set_enabled(false)
	player.input_enabled = true


func _build() -> void:
	var bg := MeshInstance3D.new()
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(0.62, 0.72, 0.005)
	bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.07, 0.08, 0.1)
	bg_mat.no_depth_test = true
	bg_mat.render_priority = 9
	bg.material_override = bg_mat
	bg.position = Vector3(0, 0, -0.008)
	add_child(bg)

	var tabs := [["ask", "Ask"], ["assess", "Look, listen, feel"], ["close", "Close"]]
	for i in tabs.size():
		var b = _button(Vector2(0.19, 0.05), tabs[i][1], Vector3(-0.2 + i * 0.2, 0.31, 0))
		b.pressed.connect(_on_tab.bind(tabs[i][0]))
		_tab_buttons[tabs[i][0]] = b
	for i in PER_PAGE:
		var b = _button(Vector2(0.58, 0.05), "", Vector3(0, 0.23 - i * 0.06, 0))
		b.pressed.connect(_on_item.bind(i))
		_item_buttons.append(b)
	_prev = _button(Vector2(0.14, 0.045), "< Prev", Vector3(-0.21, -0.14, 0))
	_prev.pressed.connect(_change_page.bind(-1))
	_next = _button(Vector2(0.14, 0.045), "Next >", Vector3(0.21, -0.14, 0))
	_next.pressed.connect(_change_page.bind(1))

	_result = Label3D.new()
	_result.font_size = 24
	_result.pixel_size = 0.0008
	_result.width = 700.0
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_result.position = Vector3(0, -0.19, 0)
	_result.modulate = Color(0.85, 0.95, 1.0)
	_result.no_depth_test = true
	_result.render_priority = 11
	add_child(_result)


func _button(size: Vector2, text: String, pos: Vector3):
	var b = BUTTON.new()
	b.size = size
	b.text = text
	b.position = pos
	add_child(b)
	return b


func _change_page(step: int) -> void:
	_page += step
	_refresh()


func _on_tab(tab: String) -> void:
	if tab == "close":
		close()
		return
	_tab = tab
	_page = 0
	_result.text = ""
	_refresh()


func _refresh() -> void:
	_items = _available_items()
	var pages := maxi(1, ceili(_items.size() / float(PER_PAGE)))
	_page = clampi(_page, 0, pages - 1)
	for i in PER_PAGE:
		var idx := _page * PER_PAGE + i
		var b = _item_buttons[i]
		if idx < _items.size():
			var it: Dictionary = _items[idx]
			var done := _asked.has(it.get("id", ""))
			b.text = ("(asked) " if done and _tab == "ask" else "") + String(it.get("label", ""))
			b.visible = true
			b.collision_layer = 1
		else:
			b.visible = false
			b.collision_layer = 0
	_prev.visible = _page > 0
	_prev.collision_layer = 1 if _prev.visible else 0
	_next.visible = _page < pages - 1
	_next.collision_layer = 1 if _next.visible else 0
	for t in _tab_buttons.values():
		t.collision_layer = 1


func _available_items() -> Array:
	var out := []
	if _tab == "ask":
		for q in runner.scenario.get("questions", []):
			var ok := true
			for r in q.get("requires", []):
				if not _asked.has(r):
					ok = false
			if ok:
				out.append(q)
	else:
		for f in runner.scenario.get("first_impression", []):
			out.append({"id": f.get("id", ""), "label": _assess_label(f), "finding": f.get("finding", "")})
	return out


func _assess_label(f: Dictionary) -> String:
	var verbs := {"look": "Look at", "listen": "Listen to", "feel": "Feel",
			"look_feel": "Look at and feel", "look_listen": "Observe"}
	var what := String(f.get("id", "")).replace("_", " ")
	return String(verbs.get(f.get("method", "look"), "Check")) + " " + what


func _on_item(slot: int) -> void:
	var idx := _page * PER_PAGE + slot
	if idx >= _items.size():
		return
	var it: Dictionary = _items[idx]
	if _tab == "assess":
		_result.text = String(it.get("finding", ""))
		return
	if _speaking:
		return
	_asked[it.get("id", "")] = true
	_result.text = ""
	_refresh()
	_speak(it.get("answers", []))


func _speak(answers: Array) -> void:
	_speaking = true
	for a in answers:
		var who = runner.characters.get(String(a.get("by", "")))
		var text := String(a.get("text", ""))
		if who:
			who.say(text)
		_result.text = String(a.get("by", "")).capitalize() + ": " + text
		await get_tree().create_timer(clampf(1.2 + text.length() * 0.06, 2.0, 7.0)).timeout
	_speaking = false


func _set_enabled(value: bool) -> void:
	for b in _item_buttons:
		b.collision_layer = 1 if value else 0
	for b in _tab_buttons.values():
		b.collision_layer = 1 if value else 0
	if _prev:
		_prev.collision_layer = 0
		_next.collision_layer = 0
