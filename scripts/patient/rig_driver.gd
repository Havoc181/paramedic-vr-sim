extends RefCounted
## Poses and breathes a MakeHuman (MPFB "game engine" rig) character.
##
## Postures are described as the direction each bone should point, in the
## character's own space (+Y up, +Z the way they face, +X their left), rather
## than as raw bone rotations. That keeps them readable and independent of the
## rig's internal bone axes. "hands_on_knees" places the hands with a simple
## two-joint reach (shoulder-elbow-wrist) so the palms rest on top of the knees.

const POSTURES := {
	"standing": {
		"bones": {
			"upperarm_l": Vector3(0.12, -1.0, 0.04), "upperarm_r": Vector3(-0.12, -1.0, 0.04),
			"lowerarm_l": Vector3(0.04, -1.0, 0.12), "lowerarm_r": Vector3(-0.04, -1.0, 0.12),
			"hand_l": Vector3(0.0, -1.0, 0.1), "hand_r": Vector3(0.0, -1.0, 0.1),
		},
		"offset": Vector3.ZERO,
	},
	# Tripod: sitting forward on the edge of the seat, knees apart, trunk
	# leaning well forward and held up on straight, braced arms with the hands
	# gripping the lower thighs just above the knees; shoulders hunched up,
	# head up looking ahead. (The lean is solved so the arms just reach.)
	"tripod": {
		"bones": {
			"thigh_l": Vector3(0.2, -0.06, 1.0), "thigh_r": Vector3(-0.2, -0.06, 1.0),
			"calf_l": Vector3(0.05, -1.0, 0.1), "calf_r": Vector3(-0.05, -1.0, 0.1),
			"foot_l": Vector3(0.1, -0.45, 0.9), "foot_r": Vector3(-0.1, -0.45, 0.9),
		},
		"lean_to_reach": true,
		"shrug_deg": 12.0,
		"hands_on_knees": true,
		# Model origin relative to the seat marker (seat surface).
		"offset": Vector3(0.0, -0.67, 0.02),
	},
	"seated": {
		"bones": {
			"thigh_l": Vector3(0.1, -0.05, 1.0), "thigh_r": Vector3(-0.1, -0.05, 1.0),
			"calf_l": Vector3(0.0, -1.0, 0.1), "calf_r": Vector3(0.0, -1.0, 0.1),
			"foot_l": Vector3(0.05, -0.45, 0.9), "foot_r": Vector3(-0.05, -0.45, 0.9),
			"upperarm_l": Vector3(0.15, -1.0, 0.25), "upperarm_r": Vector3(-0.15, -1.0, 0.25),
			"lowerarm_l": Vector3(0.0, -0.3, 1.0), "lowerarm_r": Vector3(0.0, -0.3, 1.0),
		},
		"offset": Vector3(0.0, -0.67, -0.05),
	},
}

const LEAN_DEG := 42

var skeleton: Skeleton3D
var model: Node3D
var _base_local := {}   # bone index -> posed local rotation (Quaternion)
var _chest := -1
var _clav_l := -1
var _clav_r := -1


func _init(model_root: Node3D, posture: String) -> void:
	model = model_root
	skeleton = _find_skeleton(model_root)
	if skeleton == null:
		push_warning("Character model has no Skeleton3D; posture and breathing disabled.")
		return
	var p: Dictionary = POSTURES.get(posture, POSTURES["standing"])
	model.position = p.get("offset", Vector3.ZERO)
	_apply_posture(p["bones"])
	if p.get("lean_to_reach", false):
		_lean_to_reach()
	if p.has("shrug_deg"):
		_shrug(deg_to_rad(p["shrug_deg"]))
	if p.get("hands_on_knees", false):
		_hands_on_knees()
	if p.get("seated_clothes", false):
		_seat_clothes()
	_chest = skeleton.find_bone("spine_03")
	_clav_l = skeleton.find_bone("clavicle_l")
	_clav_r = skeleton.find_bone("clavicle_r")
	_fix_materials()
	_tint_hair(Color(0.78, 0.76, 0.74))


func apply_breath(breath: float, depth: float, accessory: float) -> void:
	if skeleton == null:
		return
	var e := breath * depth
	if _chest >= 0:
		skeleton.set_bone_pose_scale(_chest, Vector3(1.0 + 0.05 * e, 1.0, 1.0 + 0.09 * e))
	var lift := deg_to_rad(7.0) * breath * accessory
	_lift_clavicle(_clav_l, lift)
	_lift_clavicle(_clav_r, -lift)


# --- Posture -----------------------------------------------------------------

func _apply_posture(bones: Dictionary) -> void:
	# Start from the rest pose.
	for b in skeleton.get_bone_count():
		skeleton.set_bone_pose_rotation(b, skeleton.get_bone_rest(b).basis.get_rotation_quaternion())
		_base_local[b] = skeleton.get_bone_pose_rotation(b)
	# Bones are stored parents-first, so each parent is posed before its children.
	for b in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(b)
		if bones.has(bone_name):
			_point_bone(b, (bones[bone_name] as Vector3).normalized())
			_base_local[b] = skeleton.get_bone_pose_rotation(b)


## Where each wrist goes: on top of the lower thigh, just above the knee.
func _wrist_target(side: String) -> Vector3:
	var knee := _gpose(skeleton.find_bone("calf_" + side)).origin
	var thigh := _gpose(skeleton.find_bone("thigh_" + side)).origin
	var along := (knee - thigh).normalized()
	return knee - along * 0.09 + Vector3(0, 0.085, 0)


func _arm_ratio(side: String) -> float:
	var up := skeleton.find_bone("upperarm_" + side)
	var lo := skeleton.find_bone("lowerarm_" + side)
	var hand := skeleton.find_bone("hand_" + side)
	var s := _gpose(up).origin
	var reach := s.distance_to(_gpose(lo).origin) + _gpose(lo).origin.distance_to(_gpose(hand).origin)
	return s.distance_to(_wrist_target(side)) / reach


## Lean the trunk well forward; the arms then brace on the knees with the
## elbows flaring out (MakeHuman arms are long enough to reach even upright).
func _lean_to_reach() -> void:
	var chain := ["spine_01", "spine_02", "spine_03", "neck_01", "head"]
	var share := [1.0, 1.0, 0.9, 0.5, -0.15]   # head tips back to look ahead
	for lean_deg in [LEAN_DEG]:
		for i in chain.size():
			var b: int = skeleton.find_bone(chain[i])
			if b < 0:
				continue
			var ang: float = deg_to_rad(lean_deg) * share[i]
			_point_bone(b, Vector3(0.0, cos(ang), sin(ang)))
			_base_local[b] = skeleton.get_bone_pose_rotation(b)


## Shoulders hunched up (accessory muscle use).
func _shrug(angle: float) -> void:
	for side in ["l", "r"]:
		var b := skeleton.find_bone("clavicle_" + side)
		if b < 0:
			continue
		var sgn := 1.0 if side == "l" else -1.0
		var parent_basis := _gpose(skeleton.get_bone_parent(b)).basis.orthonormalized()
		var current := (parent_basis * Basis(skeleton.get_bone_pose_rotation(b))).orthonormalized()
		var wanted := (Basis(Vector3(0, 0, 1), angle * sgn) * current).orthonormalized()
		skeleton.set_bone_pose_rotation(b, (parent_basis.inverse() * wanted).get_rotation_quaternion())
		_base_local[b] = skeleton.get_bone_pose_rotation(b)


## Two-joint reach: wrists on the lower thighs, elbows nearly straight and
## pointing slightly out, forearms turned so the palms face down onto the legs,
## fingers wrapping forward over the knees.
func _hands_on_knees() -> void:
	for side in ["l", "r"]:
		var sgn := 1.0 if side == "l" else -1.0
		var up := skeleton.find_bone("upperarm_" + side)
		var lo := skeleton.find_bone("lowerarm_" + side)
		var hand := skeleton.find_bone("hand_" + side)
		if up < 0 or lo < 0 or hand < 0:
			continue
		var s := _gpose(up).origin
		var l1 := s.distance_to(_gpose(lo).origin)
		var l2 := _gpose(lo).origin.distance_to(_gpose(hand).origin)
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
		_point_bone(up, (elbow - s).normalized())
		_base_local[up] = skeleton.get_bone_pose_rotation(up)
		var e := _gpose(lo).origin
		_point_bone(lo, (t - e).normalized())
		var finger_dir := Vector3(-sgn * 0.3, -0.45, 1.0).normalized()
		_point_bone(hand, finger_dir)
		# Pronate: twist the forearm about its own axis until the palm (+Z of
		# the hand bone in this rig) faces down onto the thigh.
		for _i in 3:
			var hb := _gpose(hand).basis.orthonormalized()
			var fa := _gpose(lo).basis.orthonormalized().y
			var down := Vector3.DOWN - fa * Vector3.DOWN.dot(fa)
			var palm := hb.z - fa * hb.z.dot(fa)
			if down.length() < 0.01 or palm.length() < 0.01:
				break
			var twist := palm.normalized().signed_angle_to(down.normalized(), fa)
			var lparent := _gpose(up).basis.orthonormalized()
			var cur := (lparent * Basis(skeleton.get_bone_pose_rotation(lo))).orthonormalized()
			var wanted := (Basis(fa, twist) * cur).orthonormalized()
			skeleton.set_bone_pose_rotation(lo, (lparent.inverse() * wanted).get_rotation_quaternion())
			_point_bone(hand, finger_dir)
		_base_local[lo] = skeleton.get_bone_pose_rotation(lo)
		_base_local[hand] = skeleton.get_bone_pose_rotation(hand)


## Bone pose in skeleton space, computed from the local poses we've set.
## (Skeleton3D's own global-pose cache can lag behind set_bone_pose_rotation.)
func _gpose(b: int) -> Transform3D:
	var t := Transform3D(Basis(skeleton.get_bone_pose_rotation(b)), skeleton.get_bone_pose_position(b))
	var parent := skeleton.get_bone_parent(b)
	return _gpose(parent) * t if parent >= 0 else t


## Rotate a bone (in skeleton space) so its length axis (+Y) points along dir.
func _point_bone(b: int, dir: Vector3) -> void:
	var parent := skeleton.get_bone_parent(b)
	var parent_basis := Basis.IDENTITY
	if parent >= 0:
		parent_basis = _gpose(parent).basis.orthonormalized()
	var current := (parent_basis * Basis(skeleton.get_bone_pose_rotation(b))).orthonormalized()
	var from := current.y.normalized()
	if from.dot(dir) > 0.9999:
		return
	var turn := Quaternion(from, dir)
	var wanted := (Basis(turn) * current).orthonormalized()
	var local := (parent_basis.inverse() * wanted).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(b, local)


func _lift_clavicle(b: int, angle: float) -> void:
	if b < 0:
		return
	var parent := skeleton.get_bone_parent(b)
	var parent_basis := _gpose(parent).basis.orthonormalized()
	var current := (parent_basis * Basis(_base_local[b])).orthonormalized()
	# Shrug: rotate about the forward axis (+Z); sign differs per side.
	var wanted := (Basis(Vector3(0, 0, 1), angle) * current).orthonormalized()
	skeleton.set_bone_pose_rotation(b, (parent_basis.inverse() * wanted).get_rotation_quaternion())


# --- Clothes when sitting -----------------------------------------------------

## MakeHuman skirts are weighted to the hips between the legs, so when the
## thighs come up the middle of the skirt hangs down as a flap. Re-weight
## clothing below the hip joints onto the thighs (blended across the middle)
## so it lies across the lap.
func _seat_clothes() -> void:
	var tl := skeleton.find_bone("thigh_l")
	var tr := skeleton.find_bone("thigh_r")
	if tl < 0 or tr < 0:
		return
	var hip_y := skeleton.get_bone_rest(tl).origin.y
	if skeleton.get_bone_parent(tl) >= 0:
		hip_y = (skeleton.get_bone_global_rest(tl)).origin.y
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower()
		if not n.contains("suit") or mi.skin == null:
			continue
		var bind_l := -1
		var bind_r := -1
		for i in mi.skin.get_bind_count():
			var bn: String = String(mi.skin.get_bind_name(i))
			var bb: int = mi.skin.get_bind_bone(i)
			if bn == "thigh_l" or bb == tl:
				bind_l = i
			elif bn == "thigh_r" or bb == tr:
				bind_r = i
		if bind_l < 0 or bind_r < 0:
			continue
		var src: Mesh = mi.mesh
		var out := ArrayMesh.new()
		for si in src.get_surface_count():
			var arrays := src.surface_get_arrays(si)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if bones.is_empty():
				out.add_surface_from_arrays(src.surface_get_primitive_type(si), arrays)
				out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(si))
				continue
			var stride := bones.size() / verts.size()
			for v in verts.size():
				var p := verts[v]
				if p.y > hip_y - 0.03:
					continue
				var wl := smoothstep(-0.06, 0.06, p.x)  # +X is the character's left
				for k in stride:
					bones[v * stride + k] = 0
					weights[v * stride + k] = 0.0
				bones[v * stride] = bind_l
				weights[v * stride] = wl
				bones[v * stride + 1] = bind_r
				weights[v * stride + 1] = 1.0 - wl
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if stride == 8 else 0
			out.add_surface_from_arrays(src.surface_get_primitive_type(si), arrays, [], {}, flags)
			out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(si))
		mi.mesh = out


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
				m.cull_mode = BaseMaterial3D.CULL_BACK
			mi.set_surface_override_material(s, m)


func _is_strands(n: String) -> bool:
	for k in ["hair", "bob", "short0", "long0", "ponytail", "braid", "afro"]:
		if n.contains(k):
			return true
	return false


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
