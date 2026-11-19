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
	# Sitting forward on the edge of the seat, leaning on straight arms.
	"tripod": {
		"bones": {
			"thigh_l": Vector3(0.05, -0.08, 1.0), "thigh_r": Vector3(-0.05, -0.08, 1.0),
			"calf_l": Vector3(0.06, -1.0, 0.12), "calf_r": Vector3(-0.06, -1.0, 0.12),
			"foot_l": Vector3(0.05, -0.45, 0.9), "foot_r": Vector3(-0.05, -0.45, 0.9),
			"spine_01": Vector3(0.0, 0.8, 0.6), "spine_02": Vector3(0.0, 0.82, 0.57),
			"spine_03": Vector3(0.0, 0.85, 0.52),
			"neck_01": Vector3(0.0, 0.95, 0.3), "head": Vector3(0.0, 1.0, 0.02),
		},
		"hands_on_knees": true,
		"seated_clothes": true,
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
		"seated_clothes": true,
	},
}

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


## Two-joint reach: put each wrist just above and behind its knee, elbow
## bent outwards, palm resting on the thigh with fingers over the kneecap.
func _hands_on_knees() -> void:
	for side in ["l", "r"]:
		var sgn := 1.0 if side == "l" else -1.0
		var up := skeleton.find_bone("upperarm_" + side)
		var lo := skeleton.find_bone("lowerarm_" + side)
		var hand := skeleton.find_bone("hand_" + side)
		var knee := skeleton.find_bone("calf_" + side)
		if up < 0 or lo < 0 or hand < 0 or knee < 0:
			continue
		var s := _gpose(up).origin
		var l1 := s.distance_to(_gpose(lo).origin)
		var l2 := _gpose(lo).origin.distance_to(_gpose(hand).origin)
		var t := _gpose(knee).origin + Vector3(-sgn * 0.03, 0.1, -0.04)
		var to_t := t - s
		var d := clampf(to_t.length(), 0.05, l1 + l2 - 0.001)
		var axis := to_t.normalized()
		t = s + axis * d
		var pole := Vector3(sgn, 0.0, -0.6)
		var perp := (pole - axis * pole.dot(axis)).normalized()
		var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
		var elbow := s + axis * a + perp * h
		_point_bone(up, (elbow - s).normalized())
		_base_local[up] = skeleton.get_bone_pose_rotation(up)
		var e := _gpose(lo).origin
		_point_bone(lo, (t - e).normalized())
		_base_local[lo] = skeleton.get_bone_pose_rotation(lo)
		_point_bone(hand, Vector3(-sgn * 0.15, -0.5, 1.0).normalized())
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
