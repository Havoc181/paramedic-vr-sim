extends RefCounted
## Poses and breathes a MakeHuman (MPFB "game engine" rig) character.
##
## Postures are described as the direction each bone should point, in the
## character's own space (+Y up, +Z the way they face, +X their left), rather
## than as raw bone rotations. That keeps them readable and independent of the
## rig's internal bone axes. A direction can also be "knee_l"/"knee_r": the
## bone then points at that knee (used to rest hands on the knees).

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
			"upperarm_l": "knee_l", "upperarm_r": "knee_r",
			"lowerarm_l": "knee_l", "lowerarm_r": "knee_r",
			"hand_l": Vector3(0.1, -0.9, 0.45), "hand_r": Vector3(-0.1, -0.9, 0.45),
		},
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
	# Pass 0 poses direction targets; pass 1 the "knee" targets, once legs are posed.
	for pass_i in 2:
		for b in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(b)
			var late: bool = bones.get(bone_name) is String or bone_name.begins_with("hand")
			if bones.has(bone_name) and late == (pass_i == 1):
				_pose_bone(b, bones[bone_name])


func _pose_bone(b: int, target) -> void:
	var dir: Vector3
	if target is String:
		var knee := skeleton.find_bone(String(target).replace("knee", "calf"))
		var from := skeleton.get_bone_global_pose(b).origin
		dir = (skeleton.get_bone_global_pose(knee).origin + Vector3(0, 0.05, -0.06)) - from
	else:
		dir = target
	_point_bone(b, dir.normalized())
	_base_local[b] = skeleton.get_bone_pose_rotation(b)


## Rotate a bone (in skeleton space) so its length axis (+Y) points along dir.
func _point_bone(b: int, dir: Vector3) -> void:
	var parent := skeleton.get_bone_parent(b)
	var parent_basis := Basis.IDENTITY
	if parent >= 0:
		parent_basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized()
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
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized()
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
