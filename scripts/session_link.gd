extends Node
## Instructor link, headset side. Lets a laptop running the instructor app
## watch and steer the scenario over a local network: a phone hotspot, a
## laptop hotspot or any Wi-Fi both devices are on. No internet is used.
##
## - Announces itself every second by UDP broadcast so the laptop finds it.
## - Accepts one instructor at a time on TCP; messages are JSON, one per line.
## - Sends: what the learner asks and checks (time-stamped), where they are,
##   and scenario state. Receives: pause/resume, patient better/worse,
##   events (Ken interrupts, phone rings), hints, reveal observations, end.

signal command(cmd: Dictionary)

const TCP_PORT := 47800
const BEACON_PORT := 47801
const APP_ID := "paramedic-vr-sim"

var scenario_name := ""
var _server := TCPServer.new()
var _client: StreamPeerTCP
var _buffer := ""
var _beacon := PacketPeerUDP.new()
var _beacon_timer := 0.0
var _pose_timer := 0.0
var _start_ms := Time.get_ticks_msec()
var _log: Array = []          # kept so a late-joining laptop gets the history
var player: Node3D
var state := {}
## Problems shown in the headset menu (e.g. couldn't open the port).
var status := ""


func _ready() -> void:
	add_to_group("session_link")
	var err := _server.listen(TCP_PORT)
	if err != OK:
		status = "port %d error %d" % [TCP_PORT, err]
		push_warning("Instructor link: could not listen on port %d (%s)" % [TCP_PORT, error_string(err)])
	_beacon.set_broadcast_enabled(true)
	err = _beacon.set_dest_address("255.255.255.255", BEACON_PORT)
	if err != OK:
		status += (" " if status != "" else "") + "broadcast error %d" % err


## This headset's addresses on the local network (shown in the menu so an
## instructor can type one in if automatic discovery is blocked).
static func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


func connected() -> bool:
	return _client != null and _client.get_status() == StreamPeerTCP.STATUS_CONNECTED


func log_event(kind: String, text: String) -> void:
	var e := {"t": "log", "time": (Time.get_ticks_msec() - _start_ms) / 1000.0, "kind": kind, "text": text}
	_log.append(e)
	_send(e)


func send_state() -> void:
	_send({"t": "state", "state": state})


func _process(delta: float) -> void:
	_beacon_timer -= delta
	if _beacon_timer <= 0.0:
		_beacon_timer = 1.0
		var msg := {"app": APP_ID, "scenario": scenario_name, "port": TCP_PORT,
			"addresses": local_addresses(), "busy": connected()}
		var perr := _beacon.put_packet(JSON.stringify(msg).to_utf8_buffer())
		if perr != OK and not status.contains("send"):
			status += (" " if status != "" else "") + "send error %d" % perr

	if _server.is_connection_available():
		var incoming := _server.take_connection()
		if connected():
			incoming.disconnect_from_host()   # one instructor at a time
		else:
			_client = incoming
			_buffer = ""
			_send({"t": "hello", "app": APP_ID, "scenario": scenario_name})
			for e in _log:
				_send(e)
			send_state()

	if _client == null:
		return
	_client.poll()
	if _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		if _client.get_status() != StreamPeerTCP.STATUS_CONNECTING:
			_client = null
		return
	var n := _client.get_available_bytes()
	if n > 0:
		var res := _client.get_partial_data(n)
		if res[0] == OK:
			_buffer += (res[1] as PackedByteArray).get_string_from_utf8()
			while _buffer.contains("\n"):
				var line := _buffer.get_slice("\n", 0)
				_buffer = _buffer.substr(line.length() + 1)
				var msg = JSON.parse_string(line)
				if msg is Dictionary and msg.get("t", "") == "cmd":
					command.emit(msg)

	_pose_timer -= delta
	if _pose_timer <= 0.0 and player:
		_pose_timer = 0.25
		var cam: Node3D = player.get_node_or_null("XRCamera3D")
		if cam:
			var p := cam.global_position
			var f := -cam.global_transform.basis.z
			_send({"t": "pose", "x": p.x, "y": p.y, "z": p.z, "yaw": atan2(f.x, f.z)})


func _send(msg: Dictionary) -> void:
	if connected():
		_client.put_data((JSON.stringify(msg) + "\n").to_utf8_buffer())
