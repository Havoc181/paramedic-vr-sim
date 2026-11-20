extends StaticBody3D
## One person in a scenario (patient or bystander). Uses the MakeHuman model
## if it has been exported to assets/characters/, otherwise a placeholder.
## Drives breathing from the scenario's presentation settings, shows spoken
## lines as subtitles, and opens the interaction panel when pointed at.

signal interacted(character)

const MANNEQUIN := preload("res://scripts/patient/mannequin.gd")
const BREATHING := preload("res://scripts/patient/breathing.gd")
const RIG := preload("res://scripts/patient/rig_driver.gd")

var id := ""
var display_name := ""
var data := {}

var _breath
var _depth := 0.5
var _accessory := 0.0
var _body: Node3D             # mannequin or imported model
var _rig = null               # rig_driver when a real model is used
var _subtitle: Label3D
var _subtitle_timer := 0.0
var _breath_player: AudioStreamPlayer3D
var _breath_clips: Array[AudioStream] = []
var _clip_period := 0.0
var _base_rate := 14.0
var _base_depth := 0.35
var _base_accessory := 0.0
var _base_volume := 0.0
# Speech (pre-generated voice clips)
var _voice: AudioStreamPlayer3D
var _speech := {}            # manifest entry for the line being spoken
var _speech_t := -1.0        # seconds into the current line, -1 when silent
var _speech_breath := 0.0    # chest value driven by in-breaths while talking


func setup(character_id: String, character_data: Dictionary) -> void:
	id = character_id
	data = character_data
	display_name = String(data.get("name", id))
	var p: Dictionary = data.get("presentation", {})
	var is_patient: bool = data.get("role", "") == "patient"
	_breath = BREATHING.new(float(p.get("respiratory_rate", 14.0)))
	_breath.inhale_fraction = 0.45 if float(p.get("work_of_breathing", 0.0)) > 0.6 else 0.4
	_depth = float(p.get("breath_depth", 0.35))
	_accessory = 1.0 if p.get("accessory_muscles", false) else 0.0
	_base_rate = _breath.rate
	_base_depth = _depth
	_base_accessory = _accessory

	var model_path := String(data.get("model", ""))
	if model_path != "" and ResourceLoader.exists(model_path):
		_body = (load(model_path) as PackedScene).instantiate()
		add_child(_body)
		_rig = RIG.new(_body, String(p.get("posture", "standing" if not is_patient else "seated")))
		reset_skin_signs()
		_rig.abdominal_paradox = bool(p.get("abdominal_paradox", false))
	else:
		var m = MANNEQUIN.new()
		m.seated = is_patient
		if is_patient:
			m.skin = Color(0.84, 0.8, 0.78) if p.get("skin", {}).get("colour", "") == "pale_grey" else m.skin
			m.clothing = Color(0.7, 0.66, 0.78)
			m.ankle_swelling = 1.0 if String(p.get("peripheral_oedema", "")) != "" else 0.0
			m.lean_deg = 25.0 if p.get("posture", "") == "tripod" else 5.0
		else:
			m.skin = Color(0.88, 0.75, 0.66)
			m.clothing = Color(0.45, 0.4, 0.33)
		add_child(m)
		m.build()
		_body = m

	_add_collider(is_patient)
	_make_subtitle(is_patient)
	_setup_breath_audio(p.get("sounds", {}).get("breathing_external", {}), is_patient)


func _process(delta: float) -> void:
	if _breath == null:
		return
	_breath.step(delta)
	var b: float = _breath.value
	var mouth := 0.0
	if _speech_t >= 0.0:
		_speech_t += delta
		# Talking happens on the out-breath: the chest settles, then lifts on
		# each audible in-breath in the clip.
		var target := 0.15
		for bt in _speech.get("breaths", []):
			var d := _speech_t - float(bt)
			if d >= 0.0 and d < 0.5:
				target = maxf(target, sin(PI * d / 0.5))
		_speech_breath = lerpf(_speech_breath, target, clampf(delta * 12.0, 0.0, 1.0))
		b = _speech_breath
		var env: Array = _speech.get("mouth", [])
		var i := int(_speech_t * 20.0)
		if i < env.size():
			mouth = float(env[i])
		if _speech_t > float(_speech.get("length", 0.0)) + 0.2:
			_speech_t = -1.0
	if _rig:
		_rig.update(delta)
		_rig.apply_breath(b, _depth, _accessory)
		_rig.set_jaw(mouth)
	elif _body:
		_body.apply_breath(b, _depth, _accessory)
	if _subtitle_timer > 0.0:
		_subtitle_timer -= delta
		if _subtitle_timer <= 0.0:
			_subtitle.visible = false


## Instructor control: -1 = much better, 0 = as written, +1 = much worse.
## Changes breathing rate, depth, shoulder use and how loud the breathing is.
## Exposure: "on", "lifted" (top lifted at the front) or "off" (bra on).
## While exposed she sits back with her hands beside her so the abdomen can be
## seen, then goes back to her own posture when covered up again.
func can_expose() -> bool:
	return _rig != null and _rig.can_expose()


func exposure() -> String:
	return _rig.top_state if _rig else "on"


func set_exposure(state: String) -> void:
	if not can_expose():
		return
	_rig.set_top_state(state)
	_rig.set_posture("sit_back" if state != "on" else _rig.home_posture, 1.4)


## Lip cyanosis and sweat sheen as the scenario describes them.
func reset_skin_signs() -> void:
	if _rig == null:
		return
	var skin: Dictionary = data.get("presentation", {}).get("skin", {})
	_rig.set_cyanosis(float(skin.get("cyanosis", 0.0)))
	_rig.set_clammy(float(skin.get("clammy_level", 0.6 if skin.get("clammy", false) else 0.0)))


func set_severity(v: float) -> void:
	v = clampf(v, -1.0, 1.0)
	_breath.rate = clampf(_base_rate * (1.0 + 0.3 * v), 8.0, 50.0)
	_depth = clampf(_base_depth * (1.0 + 0.25 * v), 0.15, 1.0)
	_accessory = clampf(_base_accessory + 0.6 * v, 0.0, 1.0)
	if _breath_player:
		_breath_player.volume_db = _base_volume + 4.0 * v


## Say a line: subtitle above the head and, if there's a voice clip, play it
## from the mouth. Returns how long the line lasts (seconds).
func say(text: String, audio_path := "", info := {}) -> float:
	_subtitle.text = display_name.get_slice(" ", 0) + ": " + text
	_subtitle.visible = true
	var length := clampf(1.5 + text.length() * 0.07, 2.5, 9.0)
	if audio_path != "" and ResourceLoader.exists(audio_path):
		if _voice == null:
			_voice = AudioStreamPlayer3D.new()
			_voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
			_voice.unit_size = 1.2
			_voice.max_distance = 12.0
			_voice.position = (_breath_player.position if _breath_player else Vector3(0, 1.62, 0.08))
			add_child(_voice)
		_voice.stream = load(audio_path)
		_voice.play()
		_speech = info
		_speech_t = 0.0
		_speech_breath = _breath.value
		length = float(info.get("length", length)) + 0.3
	_subtitle_timer = maxf(length + 1.0, 2.5)
	return length


func interact() -> void:
	interacted.emit(self)


## External breathing (through the air): one short clip per breath, started
## in time with the chest movement and played from the mouth in 3D.
## Loud close up, fading to barely audible a few metres away.
func _setup_breath_audio(cfg: Dictionary, seated: bool) -> void:
	for path in cfg.get("clips", []):
		if ResourceLoader.exists(path):
			_breath_clips.append(load(path))
	if _breath_clips.is_empty():
		return
	_clip_period = float(cfg.get("clip_period_s", 0.0))
	_breath_player = AudioStreamPlayer3D.new()
	_breath_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	_breath_player.unit_size = float(cfg.get("unit_size_m", 0.45))
	_breath_player.volume_db = float(cfg.get("volume_db", 0.0))
	_base_volume = _breath_player.volume_db
	_breath_player.max_db = 6.0
	_breath_player.max_distance = float(cfg.get("max_distance_m", 6.0))
	_breath_player.position = Vector3(0, 0.78, 0.22) if seated else Vector3(0, 1.62, 0.08)
	add_child(_breath_player)
	_breath.breath_started.connect(_on_breath_started)


func _on_breath_started() -> void:
	if _breath_player == null or _speech_t >= 0.0:
		return   # no separate breathing sound while they talk
	_breath_player.stream = _breath_clips[randi() % _breath_clips.size()]
	# Stretch the clip slightly to match this breath's length.
	if _clip_period > 0.0:
		_breath_player.pitch_scale = clampf(_clip_period / _breath.period, 0.88, 1.12)
	_breath_player.play()


func _add_collider(seated: bool) -> void:
	var shape := CapsuleShape3D.new()
	var col := CollisionShape3D.new()
	if seated:
		shape.radius = 0.28
		shape.height = 0.95
		col.position = Vector3(0, 0.35, 0.05)
	else:
		shape.radius = 0.25
		shape.height = 1.75
		col.position = Vector3(0, 0.88, 0)
	col.shape = shape
	add_child(col)


func _make_subtitle(seated: bool) -> void:
	_subtitle = Label3D.new()
	_subtitle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_subtitle.font_size = 26
	_subtitle.pixel_size = 0.0012
	_subtitle.outline_size = 8
	_subtitle.width = 900.0
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.no_depth_test = true
	_subtitle.render_priority = 20
	_subtitle.outline_render_priority = 19
	_subtitle.position = Vector3(0, 1.0 if seated else 2.0, 0.1)
	_subtitle.visible = false
	add_child(_subtitle)
