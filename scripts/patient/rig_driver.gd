extends RefCounted
## Drives a MakeHuman (MPFB "game engine" rig) model: posture presets and
## breathing applied as offsets on top of the bones' rest pose.
## Bone names: pelvis, spine_01-03, neck_01, head, clavicle_l/r,
## upperarm_l/r, lowerarm_l/r, hand_l/r, thigh_l/r, calf_l/r, foot_l/r.
##
## Rotations are in degrees, in each bone's local space. These are first
## guesses and are tuned once the exported model has been looked at.

const POSTURES := {
	"standing": {},
	"seated": {
		"thigh_l": Vector3(-90, 0, 0), "thigh_r": Vector3(-90, 0, 0),
		"calf_l": Vector3(90, 0, 0), "calf_r": Vector3(90, 0, 0),
		"upperarm_l": Vector3(0, 0, 70), "upperarm_r": Vector3(0, 0, -70),
	},
	"tripod": {
		"thigh_l": Vector3(-90, 0, -8), "thigh_r": Vector3(-90, 0, 8),
		"calf_l": Vector3(90, 0, 0), "calf_r": Vector3(90, 0, 0),
		"spine_01": Vector3(12, 0, 0), "spine_02": Vector3(8, 0, 0),
		"neck_01": Vector3(-12, 0, 0), "head": Vector3(-10, 0, 0),
		"upperarm_l": Vector3(-35, 0, 65), "upperarm_r": Vector3(-35, 0, -65),
		"lowerarm_l": Vector3(0, 0, 10), "lowerarm_r": Vector3(0, 0, -10),
	},
}

var skeleton: Skeleton3D
var _base := {}   # bone index -> posed Quaternion (rest * posture)
var _chest := -1
var _clav_l := -1
var _clav_r := -1


func _init(model_root: Node, posture: String) -> void:
	skeleton = _find_skeleton(model_root)
	if skeleton == null:
		push_warning("Character model has no Skeleton3D; breathing disabled.")
		return
	var pose: Dictionary = POSTURES.get(posture, {})
	for b in skeleton.get_bone_count():
		var rest := skeleton.get_bone_rest(b).basis.get_rotation_quaternion()
		var bone_name := skeleton.get_bone_name(b)
		var q := rest
		if pose.has(bone_name):
			var e: Vector3 = pose[bone_name]
			q = rest * Quaternion.from_euler(e * (PI / 180.0))
		_base[b] = q
		skeleton.set_bone_pose_rotation(b, q)
	_chest = skeleton.find_bone("spine_03")
	_clav_l = skeleton.find_bone("clavicle_l")
	_clav_r = skeleton.find_bone("clavicle_r")


func apply_breath(breath: float, depth: float, accessory: float) -> void:
	if skeleton == null:
		return
	var e := breath * depth
	if _chest >= 0:
		skeleton.set_bone_pose_scale(_chest, Vector3(1.0 + 0.05 * e, 1.0, 1.0 + 0.08 * e))
	var lift := deg_to_rad(6.0) * breath * accessory
	if _clav_l >= 0:
		skeleton.set_bone_pose_rotation(_clav_l, _base[_clav_l] * Quaternion(Vector3.FORWARD, lift))
	if _clav_r >= 0:
		skeleton.set_bone_pose_rotation(_clav_r, _base[_clav_r] * Quaternion(Vector3.FORWARD, -lift))


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null
