extends RefCounted
## Shows clinical signs on one character. Everything is found from the model's
## own skeleton (lips from the mouth bones, notch from the clavicles, fingertips
## from the finger bones, ...) and sized by the model's height, so any MakeHuman
## character built by make_humans.py gets every sign. See sign_library.gd and
## docs/clinical-signs.md.
##
## Masks are baked into vertex data once at load:
##   COLOR   r lips, g face (sweat), b belly, a fingertips
##   CUSTOM0 x suprasternal notch, y intercostal (rib stripes), z subcostal, w Hoover (lower lateral ribs)
##   CUSTOM1 x JVP (0..1 up the neck, 0 outside), y knees, z ankles, w neck front (tracheal tug)
##   CUSTOM2 xyz outward direction for ankle swelling

const LIB := preload("res://scripts/patient/sign_library.gd")

var rig                     # rig_driver
var skeleton: Skeleton3D
var mat: ShaderMaterial
var strength := {}          # sign id -> 0..1
var heart_rate := 80.0
var irregular := false      # AF: irregular pulse and JVP
var crt_seconds := 2.0      # capillary refill time

var _s := 1.0               # model scale (1 = Joan's height)
var _lm := {}               # landmarks in mesh space
var _belly_box := AABB()
var _tongue_mats: Array = []
var _tongue_base: Array = []
var _face := {}             # bone name -> index for face bones we move
var _beat_t := 0.0
var _beat_len := 0.75
var _drowsy_t := 0.0
var _nod := 0.0
var _blanch := 0.0          # capillary refill blanching 0..1
var _blanch_hold := false


func _init(rig_driver) -> void:
	rig = rig_driver
	skeleton = rig.skeleton
	if skeleton == null:
		return
	_landmarks()
	_setup_skin()
	for n in ["oris04.L", "oris04.R", "oris06.L", "oris06.R", "oris03.L", "oris03.R", "oris07.L", "oris07.R", "orbicularis03.L", "orbicularis03.R", "head", "neck03"]:
		_face[n] = skeleton.find_bone(n)


# --- Public API ---------------------------------------------------------------------

func set_sign(id: String, v: float) -> void:
	strength[id] = clampf(v, 0.0, 1.0)
	if mat == null:
		return
	match id:
		"cyanosis_lips":
			mat.set_shader_parameter("cyanosis", strength[id])
		"clammy":
			mat.set_shader_parameter("clammy", strength[id])
		"pallor", "grey", "flushing", "mottling":
			mat.set_shader_parameter(id, strength[id])
		"cyanosis_peripheral":
			mat.set_shader_parameter("nail_cyanosis", strength[id])
		"cyanosis_tongue":
			# Keep the shaded base colour (rig_driver darkens the tongue: no
			# ambient occlusion in the mouth) and tint it dusky blue-purple.
			for i in _tongue_mats.size():
				var m: BaseMaterial3D = _tongue_mats[i]
				m.albedo_color = (_tongue_base[i] as Color) * Color(1, 1, 1).lerp(Color(0.5, 0.48, 0.8), strength[id])
		"oedema_ankle":
			mat.set_shader_parameter("oedema", strength[id])
		"capillary_refill":
			# Set live (instructor/demo): 0 = normal (about 1.5 s), 1 = very slow (6 s).
			# A scenario's capillary_refill_s takes priority when the sign isn't used.
			if strength[id] > 0.0:
				crt_seconds = lerpf(1.5, 6.0, strength[id])


func get_sign(id: String) -> float:
	return float(strength.get(id, 0.0))


func set_all(signs: Dictionary) -> void:
	for id in LIB.SIGNS:
		set_sign(id, float(signs.get(id, 0.0)))


## How far the belly moves at most, in metres.
func set_belly_depth(metres: float) -> void:
	if mat:
		mat.set_shader_parameter("belly_depth", metres * _s)


## Breath-out share of each breath: prolonged expiration makes it longer.
func inhale_fraction() -> float:
	return lerpf(0.4, 0.22, get_sign("prolonged_expiration"))


## Capillary refill: hold() while the nail is pressed, release() to let it refill.
func press_nail(pressed: bool) -> void:
	if pressed:
		_blanch_hold = true
	elif _blanch_hold:
		_blanch_hold = false


## Returns true on the frame a heartbeat starts (for the pulse haptics).
var beat_started := false


## Call every frame after the rig has set the breathing pose.
## breath 0..1 (1 = full in-breath), inhaling: true during the in-breath.
func update(delta: float, breath: float, inhaling: bool) -> void:
	if skeleton == null:
		return
	# Heartbeat clock (irregularly irregular when AF).
	beat_started = false
	_beat_t += delta
	if _beat_t >= _beat_len:
		_beat_t -= _beat_len
		_beat_len = 60.0 / maxf(heart_rate, 20.0)
		if irregular:
			_beat_len *= randf_range(0.65, 1.35)
		beat_started = true
	if mat:
		# Recession and Hoover's sign: drawn in during the in-breath.
		var insp := breath if inhaling else breath * 0.6
		mat.set_shader_parameter("recess_ss", get_sign("recession_suprasternal") * insp)
		mat.set_shader_parameter("recess_ic", get_sign("recession_intercostal") * insp)
		mat.set_shader_parameter("recess_sc", get_sign("recession_subcostal") * insp)
		mat.set_shader_parameter("hoover", get_sign("hoovers_sign") * insp)
		# Belly: out a little normally, in when paradoxical.
		var par := get_sign("abdominal_paradox")
		mat.set_shader_parameter("belly", lerpf(0.35, -1.0, par) * breath if par > 0.0 else 0.35 * breath)
		# JVP: a and v waves each beat; how far up the neck it shows = strength.
		var ph := _beat_t / maxf(_beat_len, 0.01)
		var wave := 0.0
		if not irregular:
			wave = exp(-pow((ph - 0.08) / 0.06, 2.0))   # a wave
		wave += 0.7 * exp(-pow((ph - 0.55) / 0.09, 2.0)) # v wave
		mat.set_shader_parameter("jvp_height", get_sign("jvp"))
		mat.set_shader_parameter("jvp_pulse", wave)
		# Capillary refill: white while pressed, colour back over crt_seconds.
		if _blanch_hold:
			_blanch = minf(_blanch + delta * 6.0, 1.0)
		else:
			_blanch = maxf(_blanch - delta / maxf(crt_seconds, 0.3), 0.0)
		mat.set_shader_parameter("blanch", _blanch)
	_face_update(delta, inhaling)


func is_blanched() -> bool:
	return _blanch > 0.05


# --- Face: pursed lips, heavy eyelids, head nodding -------------------------------

func _face_update(delta: float, inhaling: bool) -> void:
	# Pursed lips (tested on the MakeHuman face rig): oris07 = lower-lip sides,
	# oris03 = upper-lip sides (more than ~6 mm creases the philtrum), oris04 /
	# oris06 = lip centres (push forward to protrude).
	_pursed = lerpf(_pursed, get_sign("pursed_lips") * (0.0 if inhaling else 1.0), clampf(delta * 8.0, 0.0, 1.0))
	var pl := _pursed
	for b in ["oris07.L", "oris07.R"]:
		_set_lip(b, pl * 1.6)
	for b in ["oris03.L", "oris03.R"]:
		_set_lip(b, pl * 0.8)
	for b in ["oris04.L", "oris04.R", "oris06.L", "oris06.R"]:
		_offset_bone(b, Vector3(0, 0, 0.005 * _s * pl))
	# Drowsy: lids droop; every few seconds the head drifts down, then jerks up.
	var dz := get_sign("drowsy")
	for b in ["orbicularis03.L", "orbicularis03.R"]:
		var i: int = _face.get(b, -1)
		if i >= 0:
			var axis := (skeleton.get_bone_global_rest(i).basis.inverse() * Vector3.RIGHT).normalized()
			skeleton.set_bone_pose_rotation(i, skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
				* Quaternion(axis, deg_to_rad(LID_DEG) * dz))
	if dz > 0.0:
		_drowsy_t += delta
		var cycle := 7.0
		var t := fmod(_drowsy_t, cycle) / cycle
		var target := smoothstep(0.1, 0.85, t) * (1.0 - smoothstep(0.88, 0.93, t))
		_nod = lerpf(_nod, target, clampf(delta * 3.0, 0.0, 1.0))
	else:
		_nod = 0.0
	var h: int = _face.get("head", -1)
	if h >= 0 and rig._base_local.has(h):
		var hb: Basis = skeleton.get_bone_global_rest(h).basis
		var p := skeleton.get_bone_parent(h)
		if p >= 0:
			hb = (skeleton.get_bone_global_pose(p).basis * Basis(rig._base_local[h])).orthonormalized()
		var axis := (hb.inverse() * Vector3.RIGHT).normalized()
		skeleton.set_bone_pose_rotation(h, rig._base_local[h] * Quaternion(axis, deg_to_rad(NOD_DEG) * dz * _nod))


const LID_DEG := 24.0
const NOD_DEG := 16.0


var _pursed := 0.0


func _set_lip(bone: String, amount: float) -> void:
	# Towards the midline and slightly forward.
	var i: int = _face.get(bone, -1)
	if i < 0:
		return
	var x := skeleton.get_bone_global_rest(i).origin.x
	_offset_bone(bone, Vector3(-signf(x) * 0.006 * _s * amount, 0, 0.003 * _s * amount))


## Move a bone by an offset given in model space, from its rest position.
func _offset_bone(bone: String, offset: Vector3) -> void:
	var i: int = _face.get(bone, -1)
	if i < 0:
		return
	var p := skeleton.get_bone_parent(i)
	var local := offset
	if p >= 0:
		local = skeleton.get_bone_global_rest(p).basis.inverse() * offset
	skeleton.set_bone_pose_position(i, skeleton.get_bone_rest(i).origin + local)


# --- Landmarks from the skeleton --------------------------------------------------

func _bone(n: String) -> Vector3:
	var i := skeleton.find_bone(n)
	return skeleton.get_bone_global_rest(i).origin if i >= 0 else Vector3.ZERO


func _landmarks() -> void:
	var head := _bone("head")
	var foot := (_bone("foot.L") + _bone("foot.R")) * 0.5
	_s = maxf((head.y - foot.y) / 1.275, 0.3)   # 1.275 m: Joan, head bone to ankle
	var o1 := _bone("oris01")
	var o5 := _bone("oris05")
	_lm["mouth"] = Vector3(0.0, (o1.y + o5.y) * 0.5, _bone("oris02").z - 0.005 * _s)
	var cl := (_bone("clavicle.L") + _bone("clavicle.R")) * 0.5
	_lm["notch"] = cl + Vector3(0, 0.012 * _s, 0)
	_lm["neck01"] = _bone("neck01")
	_lm["jaw"] = _bone("jaw")
	_lm["clav_r"] = _bone("clavicle.R")
	_lm["chest_hi"] = _bone("spine01").y
	_lm["chest_lo"] = _bone("spine02").y
	_lm["waist"] = _bone("spine03").y
	_lm["shoulder_x"] = absf(_bone("shoulder01.L").x)
	var tips := []
	for side in ["L", "R"]:
		for f in range(1, 6):
			var f3 := _bone("finger%d-3.%s" % [f, side])
			var f2 := _bone("finger%d-2.%s" % [f, side])
			if f3 != Vector3.ZERO:
				tips.append(f3 + (f3 - f2).normalized() * 0.012 * _s)
	_lm["tips"] = tips
	# Mottling area: the exposed lower legs (trousers roll to mid-calf; rolling
	# over the knee distorted the cloth). Knees need shorts/nightie patients.
	_lm["knees"] = [_bone("lowerleg01.L") + Vector3(0, -0.24 * _s, 0), _bone("lowerleg01.R") + Vector3(0, -0.24 * _s, 0)]
	_lm["ankles"] = [_bone("foot.L"), _bone("foot.R")]
	# Patient's right = the .R side; which way that is in x comes from the rig.
	_lm["right_sign"] = signf(_bone("clavicle.R").x - _bone("clavicle.L").x)


# --- Skin material and masks --------------------------------------------------------

func _setup_skin() -> void:
	var body: MeshInstance3D = null
	var best := 0
	for mi in rig.model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower()
		if n.contains("tongue"):
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.get_active_material(s)
				if m is BaseMaterial3D:
					m = m.duplicate()
					mi.set_surface_override_material(s, m)
					_tongue_mats.append(m)
					_tongue_base.append((m as BaseMaterial3D).albedo_color)
			continue
		if n.contains("teeth") or rig._is_strands(n) or n.contains("suit") or n.contains("shoe") \
				or n.contains("eye") or n.contains("poly") or n.contains("skin_") \
				or n.ends_with("_bra") or n.ends_with("_lifted") or mi.mesh == null:
			continue
		var count: int = mi.mesh.surface_get_array_len(0)
		if count > best:
			best = count
			body = mi
	if body == null:
		return
	var src := body.get_active_material(0) as BaseMaterial3D
	if src == null or src.albedo_texture == null:
		return
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/skin_signs.gdshader")
	mat.set_shader_parameter("albedo_texture", src.albedo_texture)
	mat.set_shader_parameter("model_scale", _s)
	var targets := [body]
	for k in ["skin_abdomen", "skin_upper", "skin_legs"]:
		if rig._wear.has(k):
			targets.append(rig._wear[k])
	_belly_box = AABB()
	if rig._wear.has("skin_abdomen"):
		var pb: AABB = rig._wear["skin_abdomen"].mesh.get_aabb()
		var y0 := pb.position.y
		for mi in rig.model.find_children("*", "MeshInstance3D", true, false):
			var n := String(mi.name).to_lower()
			if n.contains("casualsuit") or n.contains("trouser") or n.contains("jeans"):
				var front_top := -INF
				for v in (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					if v.z > 0.04 * _s and absf(v.x) < 0.08 * _s:
						front_top = maxf(front_top, v.y)
				if front_top > -INF:
					y0 = front_top + 0.005
		_belly_box = AABB(Vector3(pb.position.x, y0, pb.position.z), Vector3(pb.size.x, pb.end.y - y0, pb.size.z))
	for mi in targets:
		_bake(mi)


func _bake(mi: MeshInstance3D) -> void:
	var mesh: ArrayMesh = mi.mesh
	var out := ArrayMesh.new()
	var s := _s
	var mouth: Vector3 = _lm["mouth"]
	var notch: Vector3 = _lm["notch"]
	var rs: float = _lm["right_sign"]
	# JVP line: from just above the right medial clavicle up the side of the neck.
	var cr: Vector3 = _lm["clav_r"]
	var jv0 := Vector3(rs * 0.03 * s, cr.y + 0.015 * s, cr.z + 0.012 * s)
	var jv1 := Vector3(rs * 0.045 * s, float(_lm["jaw"].y) - 0.04 * s, float(_lm["neck01"].z) + 0.0)
	var box := _belly_box
	var has_belly := box.size != Vector3.ZERO
	for si in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n := verts.size()
		var cols := PackedColorArray(); cols.resize(n)
		var c0 := PackedFloat32Array(); c0.resize(n * 4)
		var c1 := PackedFloat32Array(); c1.resize(n * 4)
		var c2 := PackedFloat32Array(); c2.resize(n * 4)
		for i in n:
			var v := verts[i]
			# Lips and face (sweat).
			var lip := 0.0
			var face := 0.0
			if v.z > mouth.z - 0.007 * s:
				var d := Vector2((v.x - mouth.x) / (0.03 * s), (v.y - mouth.y) / (0.014 * s)).length()
				lip = 1.0 - smoothstep(0.55, 1.0, d)
			var fy := v.y - mouth.y
			if fy > -0.045 * s and fy < 0.13 * s and v.z > mouth.z - 0.06 * s and absf(v.x - mouth.x) < 0.075 * s:
				face = smoothstep(mouth.z - 0.06 * s, mouth.z - 0.01 * s, v.z)
			# Belly (shared function so body and abdomen patch move together).
			var belly := 0.0
			if has_belly:
				var u := (v.y - box.position.y) / maxf(box.size.y, 0.001)
				if u >= 0.0 and u <= 1.0 and v.z >= box.position.z:
					var w := 1.0 - absf(v.x - box.get_center().x) / maxf(box.size.x * 0.5, 0.001)
					var front := smoothstep(0.35, 0.9, (v.z - box.position.z) / maxf(box.size.z, 0.001))
					# Fade out well below the underbust so it never pushes through the bra.
					belly = sin(PI * u) * (1.0 - smoothstep(0.62, 0.8, u)) * smoothstep(0.0, 0.5, w) * front
			# Fingertips.
			var tip := 0.0
			for t in _lm["tips"]:
				tip = maxf(tip, 1.0 - smoothstep(0.008 * s, 0.016 * s, v.distance_to(t)))
			cols[i] = Color(lip, face, belly, tip)
			# Suprasternal notch: a small dip between the clavicles, front only.
			var ss := 0.0
			if v.z > notch.z:
				var dn := Vector2(v.x - notch.x, (v.y - notch.y) * 1.2).length()
				ss = 1.0 - smoothstep(0.012 * s, 0.038 * s, dn)
			# Intercostal: sides of the chest, rib-spaced stripes.
			var ic := 0.0
			var ax := absf(v.x)
			# Torso only (the arms hang beside it in the build pose).
			var torso := 1.0 - smoothstep(0.15 * s, 0.17 * s, ax)
			if v.y > _lm["chest_lo"] + 0.01 * s and v.y < _lm["chest_hi"] and ax > 0.08 * s:
				var band := smoothstep(_lm["chest_lo"] + 0.01 * s, _lm["chest_lo"] + 0.03 * s, v.y) \
					* (1.0 - smoothstep(_lm["chest_hi"] - 0.03 * s, _lm["chest_hi"], v.y))
				# The rib-spaced stripes are drawn in the shader (the mesh is too
				# coarse to dent between individual ribs).
				ic = band * smoothstep(0.08 * s, 0.11 * s, ax) * torso
			# Subcostal: front, just under the rib margin.
			var sc := 0.0
			var y_sc: float = _lm["chest_lo"] - 0.01 * s
			if v.z > 0.04 * s and ax < 0.12 * s:
				sc = (1.0 - smoothstep(0.0, 0.025 * s, absf(v.y - (y_sc - ax * 0.25)))) * smoothstep(0.02 * s, 0.05 * s, ax)
			# Hoover's sign: lower lateral rib cage.
			var hv := 0.0
			if ax > 0.09 * s:
				var yc: float = (_lm["chest_lo"] + _lm["waist"]) * 0.5 + 0.03 * s
				hv = (1.0 - smoothstep(0.0, 0.05 * s, absf(v.y - yc))) * smoothstep(0.09 * s, 0.13 * s, ax) * torso
			c0[i * 4] = ss; c0[i * 4 + 1] = ic; c0[i * 4 + 2] = sc; c0[i * 4 + 3] = hv
			# JVP: how far along the neck line (0..1), only near it and on the right.
			var jvp := 0.0
			if signf(v.x) == rs and absf(v.x) > 0.015 * s:
				var seg := jv1 - jv0
				var t := clampf((v - jv0).dot(seg) / seg.length_squared(), 0.0, 1.0)
				var dist := v.distance_to(jv0 + seg * t)
				var w := 1.0 - smoothstep(0.006 * s, 0.018 * s, dist)
				if w > 0.0:
					jvp = maxf(t, 0.02) * w
			# Knees (mottling) and ankles (oedema).
			var knee := 0.0
			for k in _lm["knees"]:
				if v.z > k.z - 0.02 * s:
					knee = maxf(knee, 1.0 - smoothstep(0.04 * s, 0.10 * s, v.distance_to(k)))
			var ank := 0.0
			var dir := Vector3.ZERO
			for a in _lm["ankles"]:
				var dy: float = v.y - a.y
				var hd := Vector2(v.x - a.x, v.z - (a.z - 0.02 * s))
				if dy > -0.02 * s and dy < 0.14 * s and hd.length() < 0.07 * s:
					var w := (1.0 - smoothstep(0.08 * s, 0.14 * s, dy)) * smoothstep(-0.02 * s, 0.02 * s, dy)
					if w > ank:
						ank = w
						dir = Vector3(hd.x, 0, hd.y).normalized()
			c1[i * 4] = jvp; c1[i * 4 + 1] = knee; c1[i * 4 + 2] = ank; c1[i * 4 + 3] = 0.0
			c2[i * 4] = dir.x; c2[i * 4 + 1] = dir.y; c2[i * 4 + 2] = dir.z; c2[i * 4 + 3] = 0.0
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_CUSTOM0] = c0
		arrays[Mesh.ARRAY_CUSTOM1] = c1
		arrays[Mesh.ARRAY_CUSTOM2] = c2
		var fmt := mesh.surface_get_format(si) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		fmt |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		fmt |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
		fmt |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(si), arrays, [], {}, fmt)
		out.surface_set_material(si, mat)
	mi.mesh = out
	for si in out.get_surface_count():
		mi.set_surface_override_material(si, null)
