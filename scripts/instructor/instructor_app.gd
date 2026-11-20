extends Control
## Instructor app (laptop). Finds the headset on the local network (phone
## hotspot, laptop hotspot or shared Wi-Fi; no internet needed), shows where
## the learner is and what they ask and check, and lets the instructor steer
## the scenario. Run it by opening scenes/instructor.tscn and pressing F6 in
## the Godot editor, or from the "Instructor (Windows)" export.

const TCP_PORT := 47800
const BEACON_PORT := 47801
const APP_ID := "paramedic-vr-sim"
const MAP := preload("res://scripts/instructor/room_map.gd")

var _udp := PacketPeerUDP.new()
var _tcp: StreamPeerTCP
var _buffer := ""
var _found := {}          # address -> {scenario, busy, seen_ms}
var _connected_to := ""
var _session_start := ""
var _log_lines: Array[String] = []
var _state := {}
var _auto_connect := true   # connect by itself when exactly one headset is found

# UI
var _status: Label
var _headsets: ItemList
var _ip: LineEdit
var _connect_btn: Button
var _map
var _log: RichTextLabel
var _notes: TextEdit
var _pause_btn: Button
var _severity: HSlider
var _severity_label: Label
var _hint: LineEdit
var _controls: Array[Control] = []


func _ready() -> void:
	DisplayServer.window_set_title("Paramedic VR Sim - Instructor")
	_build_ui()
	if _udp.bind(BEACON_PORT) != OK:
		_set_status("Couldn't listen for headsets (port %d in use?). Type the headset's address instead." % BEACON_PORT)
	else:
		_set_status("Looking for headsets on this network...")
	_set_controls_enabled(false)


# --- Network ---------------------------------------------------------------------

func _process(_delta: float) -> void:
	while _udp.get_available_packet_count() > 0:
		var pkt := _udp.get_packet()
		var from := _udp.get_packet_ip()
		var msg = JSON.parse_string(pkt.get_string_from_utf8())
		if msg is Dictionary and msg.get("app", "") == APP_ID:
			_found[from] = {"scenario": msg.get("scenario", ""), "busy": msg.get("busy", false),
				"seen": Time.get_ticks_msec()}
	_refresh_headsets()
	if _tcp == null and _auto_connect and _found.size() == 1:
		var only: String = _found.keys()[0]
		if not bool(_found[only].get("busy", false)):
			_connect_to(only)

	if _tcp == null:
		return
	_tcp.poll()
	var st := _tcp.get_status()
	if st == StreamPeerTCP.STATUS_CONNECTING:
		return
	if st != StreamPeerTCP.STATUS_CONNECTED:
		_auto_connect = false
		_disconnected("Couldn't connect to %s (status %d). If this keeps happening, check the Windows firewall allows Godot / the instructor app." % [_connected_to, st]
				if _session_start == "" else "Connection lost.")
		return
	var n := _tcp.get_available_bytes()
	if n > 0:
		var res := _tcp.get_partial_data(n)
		if res[0] == OK:
			_buffer += (res[1] as PackedByteArray).get_string_from_utf8()
			while _buffer.contains("\n"):
				var line := _buffer.get_slice("\n", 0)
				_buffer = _buffer.substr(line.length() + 1)
				var msg = JSON.parse_string(line)
				if msg is Dictionary:
					_on_message(msg)


func _connect_to(addr: String) -> void:
	addr = addr.strip_edges()
	if addr == "":
		return
	if _tcp:
		_tcp.disconnect_from_host()
	_tcp = StreamPeerTCP.new()
	if _tcp.connect_to_host(addr, TCP_PORT) != OK:
		_set_status("Couldn't start connecting to " + addr)
		_tcp = null
		return
	_connected_to = addr
	_buffer = ""
	_set_status("Connecting to %s..." % addr)


func _disconnected(why: String) -> void:
	_tcp = null
	_connected_to = ""
	_set_status(why + " Pick the headset again to reconnect.")
	_set_controls_enabled(false)
	_connect_btn.text = "Connect"


func _on_message(msg: Dictionary) -> void:
	match String(msg.get("t", "")):
		"hello":
			_auto_connect = true
			_session_start = Time.get_datetime_string_from_system(false, true)
			_log.clear()
			_log_lines.clear()
			_set_status("Connected to %s - %s" % [_connected_to, msg.get("scenario", "")])
			_set_controls_enabled(true)
			_connect_btn.text = "Disconnect"
		"log":
			_add_log(float(msg.get("time", 0.0)), String(msg.get("kind", "")), String(msg.get("text", "")))
		"pose":
			_map.set_learner(Vector3(msg.get("x", 0.0), msg.get("y", 1.6), msg.get("z", 0.0)), float(msg.get("yaw", 0.0)))
		"state":
			_state = msg.get("state", {})
			var paused := bool(_state.get("paused", false))
			_pause_btn.text = "Resume" if paused else "Pause"
			_severity.set_value_no_signal(float(_state.get("severity", 0.0)))
			_update_severity_label()


func _send(cmd: Dictionary) -> void:
	if _tcp and _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		cmd["t"] = "cmd"
		_tcp.put_data((JSON.stringify(cmd) + "\n").to_utf8_buffer())


# --- Log -------------------------------------------------------------------------

const KIND_COLOURS := {"asked": "#9fd3ff", "checked": "#b8f0a8", "finished": "#ffd27f",
	"debrief": "#ffd27f", "instructor": "#ff9f9f"}
const KIND_NAMES := {"asked": "Asked", "checked": "Checked", "finished": "Finished",
	"debrief": "Debrief", "instructor": "Instructor"}


func _add_log(t: float, kind: String, text: String) -> void:
	var stamp := "%02d:%02d" % [int(t) / 60, int(t) % 60]
	var name := String(KIND_NAMES.get(kind, kind.capitalize()))
	_log.append_text("[color=#8a94a0]%s[/color]  [color=%s]%s[/color]  %s\n" % [
		stamp, KIND_COLOURS.get(kind, "#ffffff"), name, text.replace("[", "[lb]")])
	_log_lines.append("%s  %-10s %s" % [stamp, name, text])


func _save_log() -> void:
	DirAccess.make_dir_recursive_absolute("user://sessions")
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var path := "user://sessions/session_%s.txt" % stamp
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_set_status("Couldn't save the log.")
		return
	f.store_line("Paramedic VR Sim - session log")
	f.store_line("Started: " + _session_start)
	f.store_line("")
	for l in _log_lines:
		f.store_line(l)
	f.store_line("")
	f.store_line("Instructor notes:")
	f.store_line(_notes.text)
	f.close()
	_set_status("Saved: " + ProjectSettings.globalize_path(path))


# --- UI ------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	root.offset_left = 16
	root.offset_top = 12
	root.offset_right = -16
	root.offset_bottom = -12
	add_child(root)

	# Left: connection and controls
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 330
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	left.add_child(_heading("Instructor"))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.modulate = Color(0.75, 0.82, 0.9)
	left.add_child(_status)
	left.add_child(_small("Headsets found (phone hotspot or shared Wi-Fi):"))
	_headsets = ItemList.new()
	_headsets.custom_minimum_size.y = 70
	_headsets.item_activated.connect(func(i): _connect_to(_headsets.get_item_metadata(i)))
	_headsets.item_selected.connect(func(i):
		_ip.text = _headsets.get_item_metadata(i)
		if _tcp == null:
			_connect_to(_ip.text))
	left.add_child(_headsets)
	var row := HBoxContainer.new()
	_ip = LineEdit.new()
	_ip.placeholder_text = "or type the address shown in the headset menu"
	_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_ip)
	_connect_btn = Button.new()
	_connect_btn.text = "Connect"
	_connect_btn.pressed.connect(func():
		if _tcp:
			_auto_connect = false
			_tcp.disconnect_from_host()
			_disconnected("Disconnected.")
		elif _ip.text.strip_edges() == "" and not _found.is_empty():
			_connect_to(_found.keys()[0])
		else:
			_connect_to(_ip.text))
	row.add_child(_connect_btn)
	left.add_child(row)

	left.add_child(_heading("Scenario"))
	_pause_btn = _control_button(left, "Pause", func():
		_send({"c": "resume" if bool(_state.get("paused", false)) else "pause"}))
	_severity_label = _small("Patient: as written")
	left.add_child(_severity_label)
	_severity = HSlider.new()
	_severity.min_value = -1.0
	_severity.max_value = 1.0
	_severity.step = 0.1
	_severity.value_changed.connect(func(_v): _update_severity_label())
	_severity.drag_ended.connect(func(_c): _send({"c": "severity", "v": _severity.value}))
	left.add_child(_severity)
	_controls.append(_severity)
	var sev_row := HBoxContainer.new()
	for pair in [["Better", -0.5], ["As written", 0.0], ["Worse", 0.5], ["Much worse", 1.0]]:
		var b := Button.new()
		b.text = pair[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v: float = pair[1]
		b.pressed.connect(func():
			_severity.value = v
			_send({"c": "severity", "v": v}))
		sev_row.add_child(b)
		_controls.append(b)
	left.add_child(sev_row)

	left.add_child(_heading("Events"))
	_control_button(left, "Ken interrupts", func(): _send({"c": "ken_interrupt"}))
	_control_button(left, "Phone rings", func(): _send({"c": "phone_ring"}))
	_control_button(left, "Show observations in the headset", func(): _send({"c": "reveal_obs"}))
	var hint_row := HBoxContainer.new()
	_hint = LineEdit.new()
	_hint.placeholder_text = "Hint to show in the headset"
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.text_submitted.connect(func(_t): _send_hint())
	hint_row.add_child(_hint)
	_controls.append(_hint)
	var hb := Button.new()
	hb.text = "Send"
	hb.pressed.connect(_send_hint)
	hint_row.add_child(hb)
	_controls.append(hb)
	left.add_child(hint_row)
	_control_button(left, "End scenario (ask for their impression)", func(): _send({"c": "end"}))

	# Middle: map
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(mid)
	mid.add_child(_heading("Room (top view)"))
	_map = MAP.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.custom_minimum_size = Vector2(360, 320)
	mid.add_child(_map)

	# Right: log and notes
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 430
	root.add_child(right)
	right.add_child(_heading("What the learner does"))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_log)
	right.add_child(_heading("Your notes"))
	_notes = TextEdit.new()
	_notes.custom_minimum_size.y = 140
	_notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	right.add_child(_notes)
	var save_row := HBoxContainer.new()
	var save := Button.new()
	save.text = "Save log and notes"
	save.pressed.connect(_save_log)
	save_row.add_child(save)
	var open := Button.new()
	open.text = "Open saved logs"
	open.pressed.connect(func():
		DirAccess.make_dir_recursive_absolute("user://sessions")
		OS.shell_open(ProjectSettings.globalize_path("user://sessions")))
	save_row.add_child(open)
	right.add_child(save_row)


func _send_hint() -> void:
	if _hint.text.strip_edges() != "":
		_send({"c": "hint", "text": _hint.text})
		_hint.text = ""


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	return l


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(0.75, 0.78, 0.82)
	return l


func _control_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	_controls.append(b)
	return b


func _set_controls_enabled(on: bool) -> void:
	for c in _controls:
		if c is BaseButton:
			c.disabled = not on
		elif c is LineEdit:
			c.editable = on
		elif c is Range:
			c.editable = on


func _update_severity_label() -> void:
	var v := _severity.value
	var words := "as written"
	if v <= -0.6:
		words = "much better"
	elif v < -0.05:
		words = "better"
	elif v >= 0.6:
		words = "much worse"
	elif v > 0.05:
		words = "worse"
	_severity_label.text = "Patient: %s (%+.1f)" % [words, v]


func _refresh_headsets() -> void:
	var now := Time.get_ticks_msec()
	var keys := _found.keys()
	for k in keys:
		if now - int(_found[k]["seen"]) > 4000:
			_found.erase(k)
	if _headsets.item_count == _found.size():
		return
	_headsets.clear()
	for addr in _found:
		var info: Dictionary = _found[addr]
		var i := _headsets.add_item("%s  -  %s%s" % [addr, info.get("scenario", ""),
				"  (in use)" if info.get("busy", false) else ""])
		_headsets.set_item_metadata(i, addr)


func _set_status(t: String) -> void:
	_status.text = t
