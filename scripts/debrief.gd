extends Node3D
## End-of-scenario debrief. Reports rather than judges: what was available
## in the scenario and what was checked, why each thing matters, how the
## likely causes compare, and the management considered. Expectations
## ("you should have...") are left to a future course profile. Content comes from the scenario's
## "debrief" block; what you found comes from the interaction panel.

const BUTTON := preload("res://scripts/menu_button.gd")
const CHARS_PER_LINE := 74
const LINES_PER_PAGE := 21

var player
var _pages: Array = []   # [title, body]
var _page := 0
var _title: Label3D
var _body: Label3D
var _count: Label3D
var _prev
var _next
var _close
var _restart


func show_debrief(scenario: Dictionary, asked: Dictionary, assessed: Dictionary, seen: Dictionary,
		impression: String, urgency: String, xr_player) -> void:
	player = xr_player
	if _body == null:
		_build()
	_pages = _paginate(_sections(scenario.get("debrief", {}), scenario, asked, assessed, seen, impression, urgency))
	_page = 0
	_place()
	visible = true
	player.input_enabled = false
	_refresh()


func _place() -> void:
	var cam: Node3D = player.get_node("XRCamera3D")
	var fwd: Vector3 = -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var pos: Vector3 = cam.global_position + fwd * 0.85 + Vector3(0, -0.05, 0)
	global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)


# --- Content -----------------------------------------------------------------

func _label_of(options: Array, id: String) -> String:
	for o in options:
		if String(o.get("id", "")) == id:
			return String(o.get("label", id))
	return id


func _finding(scenario: Dictionary, id: String) -> String:
	for f in scenario.get("first_impression", []):
		if String(f.get("id", "")) == id:
			return String(f.get("finding", ""))
	return ""


func _question(scenario: Dictionary, id: String) -> String:
	for q in scenario.get("questions", []):
		if String(q.get("id", "")) == id:
			return String(q.get("label", id))
	return id


func _mark(done: bool) -> String:
	return "[Checked]  " if done else "[Available, not checked]  "


func _sections(d: Dictionary, scenario: Dictionary, asked: Dictionary, assessed: Dictionary,
		seen: Dictionary, impression: String, urgency: String) -> Array:
	var out := []
	var ans: Dictionary = d.get("answer", {})

	# 1. Your impression
	var t := "You said: %s.\nUrgency: %s.\n\n" % [
		_label_of(d.get("impression_options", []), impression),
		_label_of(d.get("urgency_options", []), urgency).to_lower()]
	t += "Most likely: " + String(ans.get("summary", "")) + "\n\n"
	if impression == ans.get("impression", ""):
		t += "Your impression matches the most likely cause. The next pages show the findings that support it and any that were not checked."
	elif impression == "unsure":
		t += "No impression chosen. The next pages show the findings that point to the cause."
	else:
		t += "Your impression differs from the most likely cause. The next pages show the findings that point to pulmonary oedema and how it compares with what you chose."
	if ans.has("urgency"):
		t += "\n\nUrgency in this scenario: " + _label_of(d.get("urgency_options", []), String(ans.get("urgency"))).to_lower() + "."
	out.append(["Your impression", t])

	# 2. First impression (assessment triangle)
	var fi: Dictionary = d.get("first_impression", {})
	var found := 0
	var total := 0
	for g in fi.get("groups", []):
		var gt := ""
		if out.size() == 1:
			gt += String(fi.get("intro", "")) + "\n\n"
		for it in g.get("items", []):
			var id := String(it.get("id", ""))
			var done := assessed.has(id)
			total += 1
			found += 1 if done else 0
			gt += _mark(done) + _finding(scenario, id) + "\n      Why it matters: " + String(it.get("why", "")) + "\n\n"
		out.append(["First impression: " + String(g.get("name", "")), gt.strip_edges()])
	var extra := ""
	for it in fi.get("nice_to_spot", []):
		var id := String(it.get("id", ""))
		extra += _mark(assessed.has(id)) + _finding(scenario, id) + "\n      Why it matters: " + String(it.get("why", "")) + "\n\n"
	if fi.has("key"):
		extra += String(fi.get("key"))
	out.append(["First impression: also available", extra.strip_edges()])

	# 3. History
	var h: Dictionary = d.get("history", {})
	var asked_n := 0
	var asked_total := 0
	for part in [["key", "History: the key points"], ["supporting", "History: building the picture"],
			["pertinent_negatives", "History: useful negatives"]]:
		var ht := ""
		for it in h.get(part[0], []):
			var id := String(it.get("id", ""))
			var done := asked.has(id)
			asked_total += 1
			asked_n += 1 if done else 0
			ht += ("[Asked]  " if done else "[Available, not asked]  ") + "\"" + _question(scenario, id) + "\"\n      Why it matters: " + String(it.get("why", "")) + "\n\n"
		out.append([part[1], ht.strip_edges()])

	# 4. The scene
	var st := ""
	for it in d.get("scene", []):
		var id := String(it.get("id", ""))
		var prefix := "[Checked]  " if seen.has(id) else ("[Available, not checked]  " if id == "medicines_box" else "[In the room]  ")
		st += prefix + String(it.get("why", "")) + "\n\n"
	out.append(["The scene", st.strip_edges()])

	# 5. Differentials
	var dt := ""
	for x in d.get("differentials", []):
		dt += String(x.get("name", "")).to_upper() + "\n  For: " + String(x.get("for", "")) + "\n  Against: " + String(x.get("against", "")) + "\n\n"
	out.append(["How the likely causes compare", dt.strip_edges()])

	# 6. What next
	var nt := ""
	for line in d.get("next_steps", []):
		nt += "- " + String(line) + "\n"
	nt += "\nDoses and criteria: check current JRCALC guidance."
	out.append([String(d.get("next_steps_title", "Management considered for this presentation")), nt])

	# 7. Coming later, summary, references
	var ct := String(d.get("coming_later", "")) + "\n\n"
	ct += "This run: %d of %d first-impression findings checked; %d of %d history points asked.\n\n" % [found, total, asked_n, asked_total]
	# Objective for now; a supportive version is kept for the easy difficulty later.
	var closing_key := "closing_supportive" if String(d.get("tone", "objective")) == "supportive" else "closing"
	ct += String(d.get(closing_key, d.get("closing", ""))) + "\n\nReferences:\n"
	for r in d.get("references", []):
		ct += "- " + String(r.get("title", "")) + "\n  " + String(r.get("url", "")) + "\n"
	out.append(["To finish", ct])
	return out


## Split long sections over pages by estimated wrapped line count.
func _paginate(sections: Array) -> Array:
	var pages := []
	for sec in sections:
		var title := String(sec[0])
		var chunks := String(sec[1]).split("\n\n")
		var cur := ""
		var lines := 0
		var part := 1
		for c in chunks:
			var n := 0
			for l in c.split("\n"):
				n += maxi(1, ceili(l.length() / float(CHARS_PER_LINE)))
			if lines > 0 and lines + n > LINES_PER_PAGE:
				pages.append([title + ("" if part == 1 else " (cont.)"), cur.strip_edges()])
				part += 1
				cur = ""
				lines = 0
			cur += c + "\n\n"
			lines += n
		pages.append([title + ("" if part == 1 else " (cont.)"), cur.strip_edges()])
	return pages


# --- Panel ---------------------------------------------------------------------

func _build() -> void:
	var bg := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.96, 0.82, 0.005)
	bg.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.07, 0.08, 0.1)
	mat.no_depth_test = true
	mat.render_priority = 9
	bg.material_override = mat
	bg.position = Vector3(0, 0, -0.008)
	add_child(bg)

	_title = _label(34, Vector3(-0.44, 0.37, 0), Color(1, 1, 1))
	_body = _label(26, Vector3(-0.44, 0.31, 0), Color(0.88, 0.94, 1.0))
	_body.width = 1080.0
	_body.line_spacing = 3.0
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_count = _label(20, Vector3(0, -0.36, 0), Color(0.6, 0.65, 0.7))
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_prev = _button("< Back", Vector3(-0.36, -0.36, 0))
	_prev.pressed.connect(_turn.bind(-1))
	_next = _button("Next >", Vector3(0.36, -0.36, 0))
	_next.pressed.connect(_turn.bind(1))
	_restart = _button("Run again", Vector3(0.2, -0.36, 0))
	_restart.pressed.connect(func(): get_tree().reload_current_scene())
	_close = _button("Close", Vector3(0.36, -0.36, 0))
	_close.pressed.connect(_hide)


func _label(size: int, pos: Vector3, colour: Color) -> Label3D:
	var l := Label3D.new()
	l.font_size = size
	l.pixel_size = 0.0008
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.position = pos
	l.modulate = colour
	l.no_depth_test = true
	l.render_priority = 11
	add_child(l)
	return l


func _button(text: String, pos: Vector3):
	var b = BUTTON.new()
	b.size = Vector2(0.14, 0.05)
	b.text = text
	b.position = pos
	add_child(b)
	return b


func _turn(step: int) -> void:
	_page = clampi(_page + step, 0, _pages.size() - 1)
	_refresh()


func _refresh() -> void:
	var p: Array = _pages[_page]
	_title.text = String(p[0])
	# Label3D drops empty lines, so give blank lines a space.
	_body.text = String(p[1]).replace("\n\n", "\n \n")
	_count.text = "%d / %d" % [_page + 1, _pages.size()]
	var last := _page == _pages.size() - 1
	_show(_prev, _page > 0)
	_show(_next, not last)
	_show(_restart, last)
	_show(_close, last)


func _show(b, on: bool) -> void:
	b.visible = on
	b.collision_layer = 1 if on else 0


func _hide() -> void:
	visible = false
	for b in [_prev, _next, _restart, _close]:
		_show(b, false)
	player.input_enabled = true
