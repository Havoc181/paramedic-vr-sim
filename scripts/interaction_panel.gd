extends Node3D
## Panel opened by pointing at the patient or bystander.
## "Ask" lists history questions (answered aloud as subtitles by whoever
## would answer); "Look, listen, feel" lists first-impression assessments;
## "Finish" asks for your impression and how urgent it is, then hands over
## to the debrief.

## Emitted when the learner finishes: impression id, urgency id.
signal finished(impression: String, urgency: String)
## Emitted for the instructor log: kind ("asked", "checked", "finished"), text.
signal logged(kind: String, text: String)

const BUTTON := preload("res://scripts/menu_button.gd")
const PER_PAGE := 6

var runner
var player

var _tab := "ask"
var _page := 0
var _asked := {}
var assessed := {}
var _impression := ""
var _talking_to := ""
## Exposure actions in order ("lifted", "off", "on"), for the debrief.
var exposure_log: Array = []
var _header: Label3D
var _tab_buttons := {}
var _item_buttons: Array = []
var _prev
var _next
var _page_label: Label3D
var _segments: Array = []
const BAR_WIDTH := 0.2
const BAR_Y := -0.14
const SEG_DIM := Color(0.24, 0.28, 0.34)
const ACCENT := Color(0.12, 0.4, 0.68)
const ACCENT_HOVER := Color(0.2, 0.55, 0.85)
var _result: Label3D
var _items: Array = []
var _speaking := false


func setup(scenario_runner, xr_player) -> void:
	runner = scenario_runner
	player = xr_player
	player.menu_toggle_requested.connect(close)
	_build()
	visible = false
	add_to_group("closes_on_outside_click")
	_set_enabled(false)


## who: the character you pointed at; questions are put to them and they
## answer for themselves (falls back to whoever can answer).
func open(who = null) -> void:
	if who != null:
		_talking_to = String(who.id)
		if _header:
			_header.text = "Talking to: " + String(who.display_name).get_slice(" ", 0)
	if visible:
		return
	var cam: Node3D = player.get_node("XRCamera3D")
	var fwd: Vector3 = -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	# Off to the right of where you're looking, so the patient stays in view.
	var right := fwd.cross(Vector3.UP).normalized()
	var pos: Vector3 = cam.global_position + fwd * 0.6 + right * 0.42 + Vector3(0, -0.12, 0)
	var face := pos - cam.global_position
	face.y = 0.0
	global_transform = Transform3D(Basis.looking_at(face.normalized(), Vector3.UP).scaled(Vector3.ONE * 0.8), pos)
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
	bg_mesh.size = Vector3(0.62, 0.78, 0.005)
	bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.07, 0.08, 0.1)
	bg_mat.no_depth_test = true
	bg_mat.render_priority = 9
	bg.material_override = bg_mat
	bg.position = Vector3(0, 0.03, -0.008)
	add_child(bg)

	_header = Label3D.new()
	_header.font_size = 26
	_header.pixel_size = 0.0008
	_header.position = Vector3(-0.29, 0.385, 0)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.modulate = Color(0.75, 0.85, 1.0)
	_header.no_depth_test = true
	_header.render_priority = 11
	add_child(_header)

	var tabs := [["ask", "Ask"], ["assess", "Look, listen, feel"], ["finish", "Finish"], ["close", "Close"]]
	for i in tabs.size():
		var w := 0.2 if tabs[i][0] == "assess" else 0.12
		var x: float = [-0.225, -0.055, 0.115, 0.245][i]
		var b = _button(Vector2(w, 0.05), tabs[i][1], Vector3(x, 0.31, 0))
		b.pressed.connect(_on_tab.bind(tabs[i][0]))
		_tab_buttons[tabs[i][0]] = b
	for i in PER_PAGE:
		var b = _button(Vector2(0.58, 0.05), "", Vector3(0, 0.23 - i * 0.06, 0))
		b.pressed.connect(_on_item.bind(i))
		_item_buttons.append(b)
	_prev = _button(Vector2(0.16, 0.045), "< Back", Vector3(-0.2, -0.14, 0), true)
	_prev.pressed.connect(_change_page.bind(-1))
	_next = _button(Vector2(0.16, 0.045), "More >", Vector3(0.2, -0.14, 0), true)
	_next.pressed.connect(_change_page.bind(1))
	_page_label = Label3D.new()
	_page_label.font_size = 22
	_page_label.pixel_size = 0.0008
	_page_label.position = Vector3(0, BAR_Y - 0.03, 0)
	_page_label.modulate = Color(0.7, 0.78, 0.86)
	_page_label.no_depth_test = true
	_page_label.render_priority = 11
	add_child(_page_label)


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


func _button(size: Vector2, text: String, pos: Vector3, accent := false):
	var b = BUTTON.new()
	b.size = size
	b.text = text
	b.position = pos
	if accent:
		b.idle_colour = ACCENT
		b.hover_colour = ACCENT_HOVER
	add_child(b)
	return b


func _change_page(step: int) -> void:
	_page += step
	_refresh()


func _go_to_page(p: int) -> void:
	_page = p
	_refresh()


## Horizontal page bar between Back and More: one segment per page, the
## current one lit. Each segment can be pointed at to jump to that page.
func _update_page_bar(pages: int) -> void:
	while _segments.size() < pages:
		var seg = BUTTON.new()
		seg.text = ""
		seg.visual_height = 0.012
		add_child(seg)
		seg.pressed.connect(_go_to_page.bind(_segments.size()))
		_segments.append(seg)
	var gap := 0.008
	var w := (BAR_WIDTH - gap * (pages - 1)) / pages
	for i in _segments.size():
		var seg = _segments[i]
		var show := pages > 1 and i < pages
		seg.visible = show
		seg.collision_layer = 1 if show else 0
		if not show:
			continue
		seg.size = Vector2(w, 0.045)
		seg.position = Vector3(-BAR_WIDTH / 2.0 + w / 2.0 + i * (w + gap), BAR_Y, 0)
		seg.idle_colour = ACCENT_HOVER if i == _page else SEG_DIM
		seg.hover_colour = Color(0.35, 0.68, 0.95)
		seg._resize()


func _on_tab(tab: String) -> void:
	if tab == "close":
		close()
		return
	_tab = tab
	_page = 0
	_result.text = ""
	if tab == "finish":
		_impression = ""
		_result.text = "Before you choose: say out loud what you think is going on, and why."
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
			var mark := ""
			if _tab == "ask" and done:
				mark = "(asked) "
			elif _tab == "assess" and assessed.has(it.get("id", "")):
				mark = "(checked) "
			b.text = mark + String(it.get("label", ""))
			b.visible = true
			b.collision_layer = 1
		else:
			b.visible = false
			b.collision_layer = 0
	_prev.visible = _page > 0
	_prev.collision_layer = 1 if _prev.visible else 0
	_next.visible = _page < pages - 1
	_next.collision_layer = 1 if _next.visible else 0
	_page_label.text = ("Page %d of %d" % [_page + 1, pages]) if pages > 1 else ""
	_update_page_bar(pages)
	for t in _tab_buttons.values():
		t.collision_layer = 1


func _option_label(key: String, id: String) -> String:
	for o in runner.scenario.get("debrief", {}).get(key, []):
		if String(o.get("id", "")) == id:
			return String(o.get("label", id))
	return id


## Open straight on the Finish tab (instructor ended the scenario).
func open_finish() -> void:
	open()
	_on_tab("finish")


func asked_ids() -> Dictionary:
	return _asked


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
	elif _tab == "finish":
		var deb: Dictionary = runner.scenario.get("debrief", {})
		var opts: Array = deb.get("impression_options", [])
		for o in opts:
			out.append(o)
	else:
		var pt = _patient()
		var state: String = pt.exposure() if pt and pt.can_expose() else ""
		if state == "on":
			out.append({"id": "_expose_lifted", "label": "Lift her top to look at her abdomen", "action": "lifted"})
		if state == "on" or state == "lifted":
			out.append({"id": "_expose_off", "label": "Ask her to take her top off (bra on)", "action": "off"})
		if state == "lifted" or state == "off":
			out.append({"id": "_expose_on", "label": "Cover her up again", "action": "on"})
		var legs: String = pt.legs_exposure() if pt and pt.can_expose_legs() else ""
		if legs == "on":
			out.append({"id": "_legs_off", "label": "Roll up her trousers and take her shoes off", "action": "legs_off"})
		elif legs == "off":
			out.append({"id": "_legs_on", "label": "Cover her legs and put her shoes back on", "action": "legs_on"})
		if pt and pt._rig:
			out.append({"id": "_mouth", "label": "Ask her to open her mouth (look at her tongue)", "action": "mouth"})
		for f in runner.scenario.get("first_impression", []):
			# Some findings can only be seen once that area is exposed.
			var need := String(f.get("requires_exposure", ""))
			if need == "mouth" and pt and pt._rig and not pt.mouth_looked:
				continue
			# (Models that can't be exposed show everything, as before.)
			if need == "abdomen" and state != "" and state != "lifted" and state != "off":
				continue
			if need == "chest" and state != "" and state != "off":
				continue
			if need == "legs" and legs != "" and legs != "off":
				continue
			out.append({"id": f.get("id", ""), "label": _assess_label(f), "finding": f.get("finding", "")})
	return out


## Something examined hands-on (pulse, capillary refill) counts as checked.
func mark_examined(id: String, text: String) -> void:
	assessed[id] = true
	logged.emit("checked", text)
	_result.text = text
	if visible:
		_refresh()


func _patient():
	for c in runner.characters.values():
		if c.data.get("role", "") == "patient":
			return c
	return null


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
	if _tab == "assess" and it.has("action"):
		var pt = _patient()
		var act := String(it["action"])
		if act == "mouth":
			if pt:
				pt.open_mouth()
			logged.emit("checked", "Asked her to open her mouth to look at her tongue.")
			_result.text = "She opens her mouth for you."
			_refresh()
			return
		if pt:
			if act.begins_with("legs_"):
				pt.set_legs("off" if act == "legs_off" else "on")
			else:
				pt.set_exposure(act)
		var msg := {"lifted": "Lifted her top to look at her abdomen.",
				"off": "Asked her to take her top off (bra on).",
				"on": "Covered her up again.",
				"legs_off": "Rolled up her trousers and took her shoes off.",
				"legs_on": "Covered her legs and put her shoes back on."}
		logged.emit("exposed", String(msg.get(it["action"], "")))
		exposure_log.append(String(it["action"]))
		_result.text = String(msg.get(it["action"], ""))
		_refresh()
		# Her reply (e.g. "Go on... quick...").
		var r: Dictionary = pt.data.get("reactions", {}).get(act, {}) if pt else {}
		if not r.is_empty() and not _speaking:
			_speak([{"by": pt.id, "text": r.get("text", ""), "audio": r.get("audio", "")}])
		return
	if _tab == "assess":
		if not assessed.has(it.get("id", "")):
			logged.emit("checked", String(it.get("label", "")) + ": " + String(it.get("finding", "")))
		assessed[it.get("id", "")] = true
		_result.text = String(it.get("finding", ""))
		_refresh()
		return
	if _tab == "finish":
		# Impression only for now (urgency comes back once treatment is in).
		_impression = String(it.get("id", ""))
		logged.emit("finished", "Impression: %s." % _option_label("impression_options", _impression))
		close()
		_tab = "ask"
		finished.emit(_impression, "")
		return
	if _speaking:
		return
	_asked[it.get("id", "")] = true
	var answers := _answers_for(it)
	var reply := PackedStringArray()
	for a in answers:
		reply.append(String(a.get("by", "")).capitalize() + ": " + String(a.get("text", "")))
	logged.emit("asked", "\"" + String(it.get("label", "")) + "\"  " + " / ".join(reply))
	_result.text = ""
	_refresh()
	_speak(answers)


## Answers from the person you're talking to; if they have none, whoever can.
func _answers_for(it: Dictionary) -> Array:
	var all: Array = it.get("answers", [])
	var mine := all.filter(func(a): return String(a.get("by", "")) == _talking_to)
	return mine if not mine.is_empty() else all


func _speak(answers: Array) -> void:
	_speaking = true
	for a in answers:
		var who = runner.characters.get(String(a.get("by", "")))
		var text := String(a.get("text", ""))
		var audio := String(a.get("audio", ""))
		var wait := clampf(1.2 + text.length() * 0.06, 2.0, 7.0)
		if who:
			wait = who.say(text, audio, runner.voice_info.get(audio, {}))
		_do_action(String(a.get("action", "")))
		_result.text = String(a.get("by", "")).capitalize() + ": " + text
		await get_tree().create_timer(wait).timeout
	_speaking = false


## Things that happen as a line is spoken (scenario "action" field).
func _do_action(action: String) -> void:
	match action:
		"offer_medicines_box":
			var box = runner.find_child("MedicinesBox", true, false)
			if box:
				box.hand_to(player.get_node("XRCamera3D"))


func _set_enabled(value: bool) -> void:
	for b in _item_buttons:
		b.collision_layer = 1 if value else 0
	for b in _tab_buttons.values():
		b.collision_layer = 1 if value else 0
	if _prev:
		_prev.collision_layer = 0
		_next.collision_layer = 0
