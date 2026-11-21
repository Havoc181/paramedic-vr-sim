extends RefCounted
## Poses and breathes a MakeHuman (MPFB) character.
##
## Postures are described as the direction each limb should point, in the
## character's own space (+Y up, +Z the way they face, +X their left), rather
## than as raw bone rotations, so they read clearly and don't depend on the
## rig's internal bone axes.
##
## Works with MPFB's "default_no_toes" rig (upper arm and forearm each split
## into two bones, so twist can be spread along the limb and sleeves don't
## wring) and, as a fallback, the older 53-bone "game_engine" rig.

const POSTURES := {
	"standing": {
		"limbs": {
			"upperarm": Vector3(0.12, -1.0, 0.04),
			"lowerarm": Vector3(0.04, -1.0, 0.12),
			"hand": Vector3(0.0, -1.0, 0.1),
		},
		"offset": Vector3.ZERO,
	},
	# Tripod: sitting forward on the edge of the seat, knees apart, trunk
	# leaning well forward, braced on the arms with the palms on the lower
	# thighs just above the knees; shoulders hunched up, head up looking ahead.
	"tripod": {
		"limbs": {
			"thigh": Vector3(0.2, -0.06, 1.0),
			"calf": Vector3(0.05, -1.0, 0.1),
			"foot": Vector3(0.1, -0.45, 0.9),
		},
		"lean_deg": 42.0,
		"shrug_deg": 12.0,
		"hands_on_knees": true,
		# Model origin relative to the seat marker (seat surface).
		"offset": Vector3(0.0, -0.67, 0.02),
	},
	# Sitting back briefly with hands on the seat beside the hips, so the
	# abdomen can be seen (only while it's being exposed). Still breathless:
	# shoulders stay up and she leans a little forward.
	"sit_back": {
		"limbs": {
			"thigh": Vector3(0.2, -0.06, 1.0),
			"calf": Vector3(0.05, -1.0, 0.1),
			"foot": Vector3(0.1, -0.45, 0.9),
		},
		"lean_deg": 10.0,
		"shrug_deg": 10.0,
		"hands_beside": true,
		"offset": Vector3(0.0, -0.67, 0.02),
	},
	"seated": {
		"limbs": {
			"thigh": Vector3(0.1, -0.05, 1.0),
			"calf": Vector3(0.0, -1.0, 0.1),
			"foot": Vector3(0.05, -0.45, 0.9),
			"upperarm": Vector3(0.15, -1.0, 0.25),
			"lowerarm": Vector3(0.0, -0.3, 1.0),
		},
		"offset": Vector3(0.0, -0.67, -0.05),
	},
}

## Logical limb -> bone chain, per rig. "%s" is the side suffix.
const RIGS := {
	"default": {
		"side": [".L", ".R"],
		"spine": ["spine04", "spine03", "spine02", "spine01"],
		"neck": ["neck01", "neck02", "neck03"],
		"head": ["head"],
		"chest": ["spine02"],
		"clavicle": ["clavicle%s"],
		"upperarm": ["upperarm01%s", "upperarm02%s"],
		"lowerarm": ["lowerarm01%s", "lowerarm02%s"],
		"hand": ["wrist%s"],
		"index1": ["finger2-1%s"],
		"pinky1": ["finger5-1%s"],
		"thigh": ["upperleg01%s", "upperleg02%s"],
		"calf": ["lowerleg01%s", "lowerleg02%s"],
		"foot": ["foot%s"],
		"jaw": ["jaw"],
	},
	"game_engine": {
		"side": ["_l", "_r"],
		"spine": ["spine_01", "spine_02", "spine_03"],
		"neck": ["neck_01"],
		"head": ["head"],
		"chest": ["spine_03"],
		"clavicle": ["clavicle%s"],
		"upperarm": ["upperarm%s"],
		"lowerarm": ["lowerarm%s"],
		"hand": ["hand%s"],
		"index1": ["index_01%s"],
		"pinky1": ["pinky_01%s"],
		"thigh": ["thigh%s"],
		"calf": ["calf%s"],
		"foot": ["foot%s"],
	},
}

var skeleton: Skeleton3D
var model: Node3D
var _map: Dictionary
var _base_local := {}   # bone index -> posed local rotation (Quaternion)
var _hinge := {}        # side -> elbow hinge axis in the upper arm's local frame
var _chest := -1
var _clav := [-1, -1]


func _init(model_root: Node3D, posture: String) -> void:
	model = model_root
	skeleton = _find_skeleton(model_root)
	if skeleton == null:
		push_warning("Character model has no Skeleton3D; posture and breathing disabled.")
		return
	_map = RIGS["default"] if skeleton.find_bone("upperarm01.L") >= 0 else RIGS["game_engine"]
	_measure_thigh()
	_reset_to_rest()
	for side in 2:
		_hinge[side] = _rest_hinge(side)
	var chest := _chain("chest")
	_chest = chest[0] if chest.size() > 0 else -1
	for side in 2:
		var c := _chain("clavicle", side)
		_clav[side] = c[0] if c.size() > 0 else -1
	home_posture = posture if POSTURES.has(posture) else "standing"
	_apply_pose(_pose(home_posture))
	posture_name = home_posture
	_capture_hands()
	_fix_materials()
	_tint_hair(Color(0.78, 0.76, 0.74))
	_find_garments()
	signs = SIGNS.new(self)
	# The skin shader exists only now: give it the clothing state (otherwise
	# nothing is tucked or hidden until the first exposure change).
	_apply_layers()


# --- Posture changes -----------------------------------------------------------

var home_posture := "standing"
var posture_name := ""
var _pose_cache := {}
var _blend_from: Dictionary = {}
var _blend_to: Dictionary = {}
var _blend_t := 1.0
var _blend_dur := 1.0


## Bone rotations and model offset for a posture, built from the rest pose.
func _pose(name: String) -> Dictionary:
	var key := name if name != "tripod" else "tripod@%.2f" % tripod_level
	if _pose_cache.has(key):
		return _pose_cache[key]
	var p: Dictionary = POSTURES.get(name, POSTURES["standing"])
	_reset_to_rest()
	_apply_limbs(p["limbs"])
	var lean: float = p.get("lean_deg", 0.0)
	var shrug: float = p.get("shrug_deg", 0.0)
	_hand_back = 0.0
	if name == "tripod":
		# 0 = sitting upright with hands resting on the thighs, 1 = full tripod.
		lean = lerpf(TRIPOD_MIN_LEAN, lean, tripod_level)
		shrug *= tripod_level
		_hand_back = (1.0 - tripod_level) * 0.07
	if lean != 0.0:
		_lean(deg_to_rad(lean))
	if shrug != 0.0:
		_shrug(deg_to_rad(shrug))
	_hand_mode = "knee" if p.get("hands_on_knees", false) else ("beside" if p.get("hands_beside", false) else "")
	if _hand_mode != "":
		for side in 2:
			_hand_on_knee(side)
	var rots := []
	for b in skeleton.get_bone_count():
		rots.append(skeleton.get_bone_pose_rotation(b))
	var out := {"rot": rots, "offset": p.get("offset", Vector3.ZERO)}
	_pose_cache[key] = out
	return out


func _apply_pose(pose: Dictionary) -> void:
	for b in skeleton.get_bone_count():
		skeleton.set_bone_pose_rotation(b, pose["rot"][b])
		_base_local[b] = pose["rot"][b]
	model.position = pose["offset"]


## How far into the tripod position she is (0 upright, hands on thighs;
## 0.5 mild; 1 full). Changing it moves her smoothly if she's in tripod.
var tripod_level := 1.0
const TRIPOD_MIN_LEAN := 8.0
var _hand_back := 0.0   # wrist further back up the thigh when more upright


func set_tripod_level(level: float, seconds := 1.5) -> void:
	tripod_level = clampf(level, 0.0, 1.0)
	if skeleton == null:
		return
	if posture_name == "tripod":
		posture_name = ""   # force the blend to the new tripod pose
		set_posture("tripod", seconds)
		if seconds <= 0.0:
			update(1.0)


## Move smoothly to another posture over `seconds`.
func set_posture(name: String, seconds := 1.2) -> void:
	if skeleton == null or name == posture_name:
		return
	var rots := []
	for b in skeleton.get_bone_count():
		rots.append(_base_local[b])
	_blend_from = {"rot": rots, "offset": model.position}
	_blend_to = _pose(name)
	# _pose() rebuilt the skeleton from rest; put the current pose back.
	_apply_pose(_blend_from)
	posture_name = name
	_blend_t = 0.0
	_blend_dur = maxf(seconds, 0.05)


## Call every frame before apply_breath().
func update(delta: float) -> void:
	if skeleton == null or _blend_t >= 1.0:
		return
	_blend_t = minf(_blend_t + delta / _blend_dur, 1.0)
	var k := _blend_t * _blend_t * (3.0 - 2.0 * _blend_t)
	for b in skeleton.get_bone_count():
		var q: Quaternion = (_blend_from["rot"][b] as Quaternion).slerp(_blend_to["rot"][b], k)
		skeleton.set_bone_pose_rotation(b, q)
		_base_local[b] = q
	model.position = (_blend_from["offset"] as Vector3).lerp(_blend_to["offset"], k)
	if _blend_t >= 1.0:
		_hand_back = (1.0 - tripod_level) * 0.07 if posture_name == "tripod" else 0.0
		_hand_mode = "knee" if POSTURES.get(posture_name, {}).get("hands_on_knees", false) \
			else ("beside" if POSTURES.get(posture_name, {}).get("hands_beside", false) else "")
		_capture_hands()


# --- Exposure (top on / lifted / off with bra) ------------------------------------

var top_state := "on"
var _wear := {}


func _find_garments() -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).to_lower().contains("suit") and mi.mesh:
			var uv2 = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
			if uv2 != null and not (uv2 as PackedVector2Array).is_empty():
				layered = true
	if layered:
		_setup_layers()
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower()
		if n.ends_with("_lifted"):
			_wear["lifted"] = mi
		elif n.ends_with("_bra"):
			_wear["bra"] = mi
		elif n.contains("skin_abdomen"):
			_wear["skin_abdomen"] = mi
		elif n.contains("skin_upper"):
			_wear["skin_upper"] = mi
		elif n.contains("skin_legs"):
			_wear["skin_legs"] = mi
		elif n.ends_with("_rolled"):
			_wear["rolled"] = mi
		elif n.contains("shoes"):
			_wear["shoes"] = mi
	for pair in [["lifted", "_lifted", "top"], ["rolled", "_rolled", "trousers"]]:
		if _wear.has(pair[0]):
			var base := String(_wear[pair[0]].name).replace(pair[1], "_export")
			for mi in model.find_children("*", "MeshInstance3D", true, false):
				if String(mi.name) == base:
					_wear[pair[2]] = mi
	set_top_state("on")
	set_legs_state("on")


func can_expose() -> bool:
	if layered:
		return _wear.has("top")
	return _wear.has("top") and _wear.has("lifted") and _wear.has("skin_abdomen")


func set_top_state(state: String) -> void:
	top_state = state
	if layered:
		_apply_layers()
		return
	var show: Array = {
		"on": ["top"],
		"lifted": ["lifted", "skin_abdomen"],
		"off": ["bra", "skin_abdomen", "skin_upper"],
	}.get(state, ["top"])
	for k in ["top", "lifted", "bra", "skin_abdomen", "skin_upper"]:
		if _wear.has(k):
			_wear[k].visible = k in show


var legs_state := "on"


func can_expose_legs() -> bool:
	if layered:
		return _wear.has("trousers")
	return _wear.has("rolled") and _wear.has("skin_legs") and _wear.has("trousers")


## "on" = trousers and shoes on; "off" = trousers rolled to mid-calf, shoes off.
func set_legs_state(state: String) -> void:
	legs_state = state
	if layered:
		_apply_layers()
		return
	var off := state == "off"
	for k in ["trousers", "shoes"]:
		if _wear.has(k):
			_wear[k].visible = not off
	for k in ["rolled", "skin_legs"]:
		if _wear.has(k):
			_wear[k].visible = off


# --- Layered characters (21 Nov rebuild) --------------------------------------
# A complete body in underwear with clothes as separate layers. Skin under a
# worn garment is hidden in the skin shader; taking a garment off just hides
# it; lifting the top or rolling the trousers cuts the garment away below a
# height (garment.gdshader). See docs/character-pipeline.md.

var layered := false
var _gmats := {}        # "top"/"trousers"/"shoes" -> [ShaderMaterial]
var _lift_z := 0.0      # rest height the top is lifted to (just under the bust)
var _roll_z := 0.0      # rest height the trousers are rolled to (mid-calf)
const GARMENT_SHADER := preload("res://shaders/garment.gdshader")


static func _rest_height(mi: MeshInstance3D) -> float:
	var uv2 = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	if uv2 == null or (uv2 as PackedVector2Array).is_empty():
		return 0.0
	var t := 0.0
	for u in uv2:
		t += 1.0 - u.y
	return t / uv2.size()


func _setup_layers() -> void:
	var suits := []
	var body: MeshInstance3D = null
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower()
		if n.contains("suit"):
			suits.append(mi)
		elif n.contains("shoes"):
			_wear["shoes"] = mi
		elif n.ends_with("_bra"):
			_wear["bra"] = mi
		elif n.ends_with("_briefs"):
			_wear["briefs"] = mi
		elif n.ends_with("_export") and not (n.contains("eye") or n.contains("teeth") or n.contains("tongue")
				or n.contains("poly") or _is_strands(n)):
			if body == null or mi.mesh.surface_get_array_len(0) > body.mesh.surface_get_array_len(0):
				body = mi
	suits.sort_custom(func(a, b): return _rest_height(a) > _rest_height(b))
	if suits.size() > 0:
		_wear["top"] = suits[0]
	if suits.size() > 1:
		_wear["trousers"] = suits[1]
	for k in ["top", "trousers", "shoes"]:
		if not _wear.has(k):
			continue
		var mi: MeshInstance3D = _wear[k]
		var list := []
		for si in mi.mesh.get_surface_count():
			var src := mi.get_active_material(si) as BaseMaterial3D
			var m := ShaderMaterial.new()
			m.shader = GARMENT_SHADER
			if src:
				m.set_shader_parameter("albedo_color", src.albedo_color)
				m.set_shader_parameter("use_texture", src.albedo_texture != null)
				if src.albedo_texture:
					m.set_shader_parameter("albedo_texture", src.albedo_texture)
				if src.normal_enabled and src.normal_texture:
					m.set_shader_parameter("normal_texture", src.normal_texture)
					m.set_shader_parameter("use_normal", true)
			m.set_shader_parameter("torso_only", k == "top")
			mi.set_surface_override_material(si, m)
			list.append(m)
		_gmats[k] = list
	# Lift line: just under the bust, found on the skin the top covers.
	_lift_z = 1.0
	if body:
		var a: Array = body.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uv2 = a[Mesh.ARRAY_TEX_UV2]
		if uv2 != null and not (uv2 as PackedVector2Array).is_empty():
			var lo := INF
			var hi := -INF
			for i in verts.size():
				var b := int(round(uv2[i].x))
				if b & 1 and b & 8:
					lo = minf(lo, verts[i].y); hi = maxf(hi, verts[i].y)
			var apex := Vector3(0, 0, -INF)
			for i in verts.size():
				var b := int(round(uv2[i].x))
				if b & 1 and b & 8 and verts[i].y > (lo + hi) / 2.0 and verts[i].z > apex.z:
					apex = verts[i]
			if apex.z > -INF:
				_lift_z = apex.y - 0.07
	var ki := skeleton.find_bone("lowerleg01.L")
	_roll_z = (skeleton.get_bone_global_rest(ki).origin.y - 0.15) if ki >= 0 else 0.3
	_apply_layers()


## Push the current top/legs state to the garments and the skin shader.
func _apply_layers() -> void:
	if not layered:
		return
	var top_mode: int = {"on": 1, "lifted": 2, "off": 0}.get(top_state, 1)
	var lower_mode := 2 if legs_state == "off" else 1
	if _wear.has("top"):
		_wear["top"].visible = top_mode != 0
	for m in _gmats.get("top", []):
		m.set_shader_parameter("mode", top_mode)
		m.set_shader_parameter("cut_z", _lift_z)
	for m in _gmats.get("trousers", []):
		m.set_shader_parameter("mode", lower_mode)
		m.set_shader_parameter("cut_z", _roll_z)
	if _wear.has("shoes"):
		_wear["shoes"].visible = legs_state != "off"
	# Trousers only ever roll up (never come off), so the briefs would only
	# show as slivers through the fly: hide them while trousers are worn.
	if _wear.has("briefs"):
		_wear["briefs"].visible = not _wear.has("trousers")
	# Bra only with the top off (otherwise it shows through the blouse).
	if _wear.has("bra"):
		_wear["bra"].visible = top_mode == 0
	if signs and signs.mat:
		signs.mat.set_shader_parameter("top_mode", top_mode)
		signs.mat.set_shader_parameter("top_cut", _lift_z)
		signs.mat.set_shader_parameter("lower_mode", lower_mode)
		signs.mat.set_shader_parameter("lower_cut", _roll_z)
		signs.mat.set_shader_parameter("shoes_on", legs_state != "off")


## Plain colours for clothes (e.g. to hide a printed logo): {"name part": "#rrggbb"}.
func tint_clothes(colours: Dictionary) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower()
		for key in colours:
			if n.contains(String(key).to_lower()):
				# "#rrggbb" = plain colour (hides prints/logos); "*#rrggbb" = tint
				# that keeps the fabric texture.
				var spec := String(colours[key])
				for s in mi.mesh.get_surface_count():
					var m: Material = mi.get_active_material(s)
					if m is ShaderMaterial:
						if spec.begins_with("*"):
							m.set_shader_parameter("albedo_color", Color(spec.substr(1)))
						else:
							m.set_shader_parameter("use_texture", false)
							m.set_shader_parameter("albedo_color", Color(spec))
					elif m is BaseMaterial3D:
						m = m.duplicate()
						if spec.begins_with("*"):
							m.albedo_color = Color(spec.substr(1))
						else:
							m.albedo_texture = null
							m.albedo_color = Color(spec)
						mi.set_surface_override_material(s, m)


## Wide open for looking in the mouth (tongue, lips): 0..1 on top of speech.
var mouth_open := 0.0


## Mouth opening while speaking, 0..1 (rotates the jaw down from its pose).
func set_jaw(open: float) -> void:
	if skeleton == null:
		return
	var b := _first("jaw")
	if b < 0:
		return
	skeleton.set_bone_pose_rotation(b, _base_local[b])
	var ang := deg_to_rad(8.0) * clampf(open, 0.0, 1.0) + deg_to_rad(22.0) * mouth_open
	if ang > 0.001:
		_rotate_global(b, Basis(Vector3(1, 0, 0), ang))


func apply_breath(breath: float, depth: float, accessory: float) -> void:
	if skeleton == null:
		return
	var e := breath * depth
	if _chest >= 0:
		skeleton.set_bone_pose_scale(_chest, Vector3(1.0 + 0.05 * e, 1.0, 1.0 + 0.09 * e))
	var lift := deg_to_rad(7.0) * breath * accessory
	_lift_clavicle(_clav[0], lift)
	_lift_clavicle(_clav[1], -lift)
	_keep_hands()


# --- Hands stay planted while the shoulders breathe (Tom, 20 Nov) -------------

var _hand_targets: Array = []   # wrist positions (skeleton space) for the current posture


## Remember where the hands are in the posture (call when a posture settles).
func _capture_hands() -> void:
	_hand_targets.clear()
	if _hand_mode == "":
		return
	if _chest >= 0:
		skeleton.set_bone_pose_scale(_chest, Vector3.ONE)
	for side in 2:
		var hand := _first("hand", side)
		_hand_targets.append(_gpose(hand).origin if hand >= 0 else Vector3.INF)


## After the breathing lift, bend the elbows so the wrists stay where they were:
## two-joint IK that keeps the current bend plane (no jumps).
func _keep_hands() -> void:
	if _hand_targets.size() != 2 or _blend_t < 1.0:
		return
	for side in 2:
		var ups := _chain("upperarm", side)
		var los := _chain("lowerarm", side)
		var hand := _first("hand", side)
		var t: Vector3 = _hand_targets[side]
		if ups.is_empty() or los.is_empty() or hand < 0 or t == Vector3.INF:
			continue
		for b in ups + los:
			skeleton.set_bone_pose_rotation(b, _base_local[b])
		var sh := _gpose(ups[0]).origin
		var el := _gpose(los[0]).origin
		var wr := _gpose(hand).origin
		var l1 := sh.distance_to(el)
		var l2 := el.distance_to(wr)
		var to_t := t - sh
		var d := clampf(to_t.length(), 0.05, l1 + l2 - 0.001)
		var axis := to_t.normalized()
		var bend := el - sh
		var perp := (bend - axis * bend.dot(axis))
		if perp.length() < 1e-5:
			continue
		perp = perp.normalized()
		var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
		var el_new := sh + axis * a + perp * h
		_rotate_global(ups[0], Basis(Quaternion((el - sh).normalized(), (el_new - sh).normalized())))
		var el2 := _gpose(los[0]).origin
		var wr2 := _gpose(hand).origin
		_rotate_global(los[0], Basis(Quaternion((wr2 - el2).normalized(), (sh + axis * d - el2).normalized())))


# --- Bone lookup -------------------------------------------------------------

## Bone indices for a logical limb; side 0 = left, 1 = right.
func _chain(limb: String, side := 0) -> Array[int]:
	var out: Array[int] = []
	for pattern in _map.get(limb, []):
		var name := String(pattern)
		if name.contains("%s"):
			name = name % _map["side"][side]
		var b := skeleton.find_bone(name)
		if b >= 0:
			out.append(b)
	return out


func _first(limb: String, side := 0) -> int:
	var c := _chain(limb, side)
	return c[0] if c.size() > 0 else -1


# --- Posture -----------------------------------------------------------------

func _reset_to_rest() -> void:
	for b in skeleton.get_bone_count():
		skeleton.set_bone_pose_rotation(b, skeleton.get_bone_rest(b).basis.get_rotation_quaternion())
		_base_local[b] = skeleton.get_bone_pose_rotation(b)


## The elbow's hinge axis, from the slight bend of the rest pose, stored in
## the upper arm's own frame so it can be found again after the arm moves.
func _rest_hinge(side: int) -> Vector3:
	var ups := _chain("upperarm", side)
	var los := _chain("lowerarm", side)
	var hand := _first("hand", side)
	if ups.is_empty() or los.is_empty() or hand < 0:
		return Vector3.ZERO
	var s := _gpose(ups[0]).origin
	var e := _gpose(los[0]).origin
	var w := _gpose(hand).origin
	var h := (e - s).cross(w - e).normalized()
	return _gpose(ups[-1]).basis.orthonormalized().inverse() * h


func _apply_limbs(limbs: Dictionary) -> void:
	for side in 2:
		var sgn := 1.0 if side == 0 else -1.0
		for limb in ["thigh", "calf", "foot", "upperarm", "lowerarm", "hand"]:
			if limbs.has(limb):
				var d: Vector3 = limbs[limb]
				_point_chain(_chain(limb, side), Vector3(d.x * sgn, d.y, d.z).normalized())


func _point_chain(bones: Array[int], dir: Vector3) -> void:
	for b in bones:
		_point_bone(b, dir)
		_base_local[b] = skeleton.get_bone_pose_rotation(b)


## Lean the trunk forward; the neck follows part way and the head tips back
## so the eyes look ahead rather than at the floor.
func _lean(angle: float) -> void:
	_point_chain(_chain("spine"), Vector3(0.0, cos(angle), sin(angle)))
	var neck_ang := angle * 0.35
	_point_chain(_chain("neck"), Vector3(0.0, cos(neck_ang), sin(neck_ang)))
	var head_ang := -angle * 0.15
	_point_chain(_chain("head"), Vector3(0.0, cos(head_ang), sin(head_ang)))


## Shoulders hunched up (accessory muscle use).
func _shrug(angle: float) -> void:
	for side in 2:
		var b: int = _first("clavicle", side)
		if b < 0:
			continue
		var sgn := 1.0 if side == 0 else -1.0
		_rotate_global(b, Basis(Vector3(0, 0, 1), angle * sgn))
		_base_local[b] = skeleton.get_bone_pose_rotation(b)


var _hand_mode := "knee"


## Where the wrist goes: on top of the lower thigh just above the knee, or on
## the seat beside the hip ("beside").
func _wrist_target(side: int) -> Vector3:
	var knee := _gpose(_first("calf", side)).origin
	var hip := _gpose(_first("thigh", side)).origin
	if _hand_mode == "beside":
		var sgn := 1.0 if side == 0 else -1.0
		return hip + Vector3(sgn * 0.21, -0.03, 0.06)
	var along := (knee - hip).normalized()
	var back := 0.09 + _hand_back
	var lift := lerpf(_hand_lift, _hand_lift_far, clampf(_hand_back / 0.12, 0.0, 1.0))
	# More upright: hands rest a little further out on the thighs, not in the lap.
	var out := (1.0 if side == 0 else -1.0) * _hand_back * 0.3
	return knee - along * back + Vector3(out, lift, 0)


## How high the wrist sits above the thigh bone: the front of the thigh (or
## trousers) measured on this model in its build pose, plus palm thickness.
## Fixed 0.115 m suited Joan but sank into fuller thighs (Maureen, 21 Nov).
var _hand_lift := 0.123
var _hand_lift_far := 0.135   # same, 21 cm up from the knee (upright tripod)


func _measure_thigh() -> void:
	var near := _thigh_front(0.09)
	if near > 0.0:
		_hand_lift = near + 0.022
	var far := _thigh_front(0.21)
	_hand_lift_far = far + 0.022 if far > 0.0 else _hand_lift + 0.012


func _thigh_front(from_knee: float) -> float:
	var ki := skeleton.find_bone("lowerleg01.L")
	var hi := skeleton.find_bone("upperleg01.L")
	if ki < 0 or hi < 0:
		return -1.0
	var knee := skeleton.get_bone_global_rest(ki).origin
	var hip := skeleton.get_bone_global_rest(hi).origin
	var p := knee - (knee - hip).normalized() * from_knee
	var front := -1.0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower()
		if mi.mesh == null or n.ends_with("_rolled") or n.contains("skin_") or n.ends_with("_briefs") or n.ends_with("_bra"):
			continue
		for v in (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if absf(v.y - p.y) < 0.03 and absf(v.x - p.x) < 0.08:
				front = maxf(front, v.z - p.z)
	return front


## Hand on knee, like a real arm:
## 1. place the elbow (two-joint reach, elbow flared out and back);
## 2. roll the upper arm so the elbow's hinge lines up with the bend needed,
##    so the forearm swings into place as a pure hinge (no wrench at the elbow);
## 3. turn the palm down by spreading the remaining forearm twist across both
##    forearm bones and the wrist, as pronation does in a real forearm.
func _hand_on_knee(side: int) -> void:
	var sgn := 1.0 if side == 0 else -1.0
	var ups := _chain("upperarm", side)
	var los := _chain("lowerarm", side)
	var hand := _first("hand", side)
	if ups.is_empty() or los.is_empty() or hand < 0:
		return
	var s := _gpose(ups[0]).origin
	var l1 := s.distance_to(_gpose(los[0]).origin)
	var l2 := _gpose(los[0]).origin.distance_to(_gpose(hand).origin)
	var t := _wrist_target(side)
	var to_t := t - s
	var d := clampf(to_t.length(), 0.05, l1 + l2 - 0.001)
	var axis := to_t.normalized()
	t = s + axis * d
	var pole := Vector3(sgn, 0.15, -0.35)
	var perp := (pole - axis * pole.dot(axis)).normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var elbow := s + axis * a + perp * h

	# 1. upper arm at the elbow
	var u := (elbow - s).normalized()
	_point_chain(ups, u)

	# 2. roll so the hinge matches the bend we need
	if _hinge[side] != Vector3.ZERO:
		var want_h := u.cross(t - elbow).normalized()
		var have_h: Vector3 = _gpose(ups[-1]).basis.orthonormalized() * _hinge[side]
		var phi := _flat(have_h, u).signed_angle_to(_flat(want_h, u), u)
		_spread_roll(ups, phi, [0.5, 0.5])

	# 3. forearm to the wrist, then palm down with the twist spread out
	_point_chain(los, (t - _gpose(los[0]).origin).normalized())
	var finger_dir := Vector3(-sgn * 0.3, -0.45, 1.0).normalized()
	var palm_want := Vector3(-sgn * 0.3, -1.0, 0.0).normalized()
	var idx := _first("index1", side)
	var pky := _first("pinky1", side)
	for _i in 4:
		_point_bone(hand, finger_dir)
		if idx < 0 or pky < 0:
			break
		var fa := _gpose(los[-1]).basis.orthonormalized().y
		var theta := _flat(_palm(side, hand, idx, pky), fa).signed_angle_to(_flat(palm_want, fa), fa)
		if absf(theta) < 0.01:
			break
		var shares := [0.35, 0.35] if los.size() == 2 else [0.7]
		_spread_roll(los, theta, shares)
		_roll(hand, theta * 0.3)
	for b in los + [hand]:
		_base_local[b] = skeleton.get_bone_pose_rotation(b)
	# Residual roll on the wrist only, so the palm sits flat.
	for _j in 3:
		var hy := _gpose(hand).basis.orthonormalized().y
		var r := _flat(_palm(side, hand, idx, pky), hy).signed_angle_to(_flat(palm_want, hy), hy)
		if absf(r) < 0.01:
			break
		_roll(hand, r)
	_base_local[hand] = skeleton.get_bone_pose_rotation(hand)


## Palm normal measured from the knuckles (the hand bone's own axes sit at an
## angle to the palm in these rigs).
func _palm(side: int, hand: int, idx: int, pky: int) -> Vector3:
	var sgn := 1.0 if side == 0 else -1.0
	var hy := _gpose(hand).basis.orthonormalized().y
	return (hy.cross(_gpose(idx).origin - _gpose(pky).origin) * sgn).normalized()


func _flat(v: Vector3, axis: Vector3) -> Vector3:
	return (v - axis * v.dot(axis)).normalized()


## Roll a chain about its length by a total angle, shared out bone by bone.
func _spread_roll(bones: Array[int], total: float, shares: Array) -> void:
	for i in bones.size():
		_roll(bones[i], total * float(shares[mini(i, shares.size() - 1)]))
		_base_local[bones[i]] = skeleton.get_bone_pose_rotation(bones[i])


## Rotate a bone about its own length axis.
func _roll(b: int, angle: float) -> void:
	_rotate_global(b, Basis(_gpose(b).basis.orthonormalized().y, angle))


func _rotate_global(b: int, rot: Basis) -> void:
	var parent := skeleton.get_bone_parent(b)
	var pb := _gpose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var cur := (pb * Basis(skeleton.get_bone_pose_rotation(b))).orthonormalized()
	skeleton.set_bone_pose_rotation(b, (pb.inverse() * (rot * cur).orthonormalized()).get_rotation_quaternion())


## Bone pose in skeleton space, computed from the local poses we've set.
## (Skeleton3D's own global-pose cache can lag behind set_bone_pose_rotation.)
func _gpose(b: int) -> Transform3D:
	var t := Transform3D(Basis(skeleton.get_bone_pose_rotation(b)) * Basis.from_scale(skeleton.get_bone_pose_scale(b)),
		skeleton.get_bone_pose_position(b))
	var parent := skeleton.get_bone_parent(b)
	return _gpose(parent) * t if parent >= 0 else t


## Rotate a bone (in skeleton space) so its length axis (+Y) points along dir,
## by the smallest turn.
func _point_bone(b: int, dir: Vector3) -> void:
	var cur_y := _gpose(b).basis.orthonormalized().y
	if cur_y.dot(dir) > 0.9999:
		return
	_rotate_global(b, Basis(Quaternion(cur_y, dir)))


func _lift_clavicle(b: int, angle: float) -> void:
	if b < 0:
		return
	var parent := skeleton.get_bone_parent(b)
	var parent_basis := _gpose(parent).basis.orthonormalized()
	var current := (parent_basis * Basis(_base_local[b])).orthonormalized()
	# Shrug: rotate about the forward axis (+Z); sign differs per side.
	var wanted := (Basis(Vector3(0, 0, 1), angle) * current).orthonormalized()
	skeleton.set_bone_pose_rotation(b, (parent_basis.inverse() * wanted).get_rotation_quaternion())


# --- Looks -------------------------------------------------------------------

## MakeHuman exports every material as alpha-blended and double-sided. Blended
## surfaces aren't depth-sorted per pixel, so on Quest the skin under the
## clothes, and the eyes and mouth inside the head, showed through in patches.
## Make solid things opaque and strand-like things (hair, brows, lashes) cut-out.
func _fix_materials() -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower()
		var strands := _is_strands(n) or n.contains("eyebrow") or n.contains("eyelash") \
				or n.contains("high-poly") or n.contains("low-poly")
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			var m := src.duplicate() as BaseMaterial3D
			if strands:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.4
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
			else:
				m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				# The lifted top's gathered folds are seen from inside at the
				# sides, so draw both faces of that one.
				m.cull_mode = BaseMaterial3D.CULL_DISABLED if n.ends_with("_lifted") else BaseMaterial3D.CULL_BACK
			# Inside the mouth there is no ambient occlusion, so stark white
			# teeth and a bright tongue glow. Age the teeth and shade both.
			if n.contains("teeth"):
				m.albedo_color = m.albedo_color * Color(0.86, 0.81, 0.72)
				m.roughness = 0.55
			elif n.contains("tongue"):
				m.albedo_color = m.albedo_color * Color(0.6, 0.5, 0.5)
				m.roughness = 0.6
			mi.set_surface_override_material(s, m)


func _is_strands(n: String) -> bool:
	for k in ["hair", "bob", "short0", "long0", "ponytail", "braid", "afro"]:
		if n.contains(k):
			return true
	return false


# --- Clinical signs (see signs.gd) ---------------------------------------------

const SIGNS := preload("res://scripts/patient/signs.gd")
var signs  # signs.gd controller


## MakeHuman hair textures are coloured; grey them for older characters.
func _tint_hair(tint: Color) -> void:
	var shader := load("res://shaders/hair_grey.gdshader")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower()
		if not (_is_strands(n) or n.contains("eyebrow")):
			continue
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			var m := ShaderMaterial.new()
			m.shader = shader
			m.set_shader_parameter("hair_texture", src.albedo_texture)
			m.set_shader_parameter("tint", tint)
			mi.set_surface_override_material(s, m)


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null
