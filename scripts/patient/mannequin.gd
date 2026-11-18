extends Node3D
## Placeholder person built from capsules, used until the MakeHuman model is
## available. Seated (tripod) or standing. Shows breathing: chest expansion,
## shoulder lift with accessory muscle use. Local +Z is the way they face.

var seated := true
var skin := Color(0.86, 0.76, 0.7)
var clothing := Color(0.55, 0.62, 0.75)
var lean_deg := 25.0          ## forward lean of the trunk (tripod)
var ankle_swelling := 0.0     ## 0 = none, 1 = marked

var _skin_mat: StandardMaterial3D
var _cloth_mat: StandardMaterial3D
var _torso: Node3D
var _chest: MeshInstance3D
var _shoulders: Node3D
var _arm_parts: Array[MeshInstance3D] = []
var _hand_targets: Array[Vector3] = []


func build() -> void:
	_skin_mat = _mat(skin)
	_cloth_mat = _mat(clothing)
	if seated:
		_build_seated()
	else:
		_build_standing()


## breath 0..1, depth 0..1, accessory 0..1
func apply_breath(breath: float, depth: float, accessory: float) -> void:
	var e := breath * depth
	_chest.scale = Vector3(1.0 + 0.06 * e, 1.0 + 0.02 * e, 1.0 + 0.1 * e)
	_shoulders.position.y = 0.46 + 0.035 * breath * accessory
	_update_arms()


func _build_seated() -> void:
	# Origin = seat surface centre. Floor is 0.42 m below.
	_capsule("Pelvis", 0.15, 0.36, Vector3(0, 0.1, -0.02), Vector3(0, 0, 90), _cloth_mat, self)
	for side in [-1.0, 1.0]:
		var hip := Vector3(side * 0.1, 0.1, 0.0)
		var knee := Vector3(side * 0.12, 0.12, 0.44)
		var ankle := Vector3(side * 0.12, -0.34, 0.5)
		_limb("Thigh", hip, knee, 0.075, _cloth_mat, self)
		_limb("Shin", knee, ankle, 0.05 + 0.015 * ankle_swelling, _skin_mat, self)
		var ank := _sphere("Ankle", 0.055 + 0.02 * ankle_swelling, ankle, _skin_mat, self)
		ank.scale = Vector3(1.0, 0.9, 1.1)
		_box("Foot", Vector3(0.09, 0.06, 0.22), ankle + Vector3(0, -0.05, 0.06), _skin_mat, self)
		_hand_targets.append(knee + Vector3(side * 0.02, 0.07, -0.02))

	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.15, -0.04)
	_torso.rotation_degrees.x = lean_deg
	add_child(_torso)
	_chest = _capsule("Chest", 0.17, 0.5, Vector3(0, 0.25, 0), Vector3.ZERO, _cloth_mat, _torso)
	_chest.scale = Vector3(1.0, 1.0, 0.75)
	_shoulders = Node3D.new()
	_shoulders.position = Vector3(0, 0.46, 0)
	_torso.add_child(_shoulders)
	_capsule("ShoulderBar", 0.07, 0.42, Vector3.ZERO, Vector3(0, 0, 90), _cloth_mat, _shoulders)
	_capsule("Neck", 0.05, 0.14, Vector3(0, 0.08, 0.01), Vector3.ZERO, _skin_mat, _shoulders)
	_sphere("Head", 0.1, Vector3(0, 0.22, 0.03), _skin_mat, _shoulders).scale = Vector3(0.9, 1.1, 1.0)
	for i in 2:
		var arm := _capsule("Arm", 0.045, 0.5, Vector3.ZERO, Vector3.ZERO, _skin_mat, self)
		_arm_parts.append(arm)
	_update_arms()


func _build_standing() -> void:
	# Origin = floor between the feet.
	for side in [-1.0, 1.0]:
		_limb("Leg", Vector3(side * 0.1, 0.92, 0), Vector3(side * 0.11, 0.08, 0.02), 0.075, _cloth_mat, self)
		_box("Foot", Vector3(0.1, 0.07, 0.26), Vector3(side * 0.11, 0.035, 0.07), _mat(Color(0.25, 0.2, 0.18)), self)
	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.95, 0)
	add_child(_torso)
	_chest = _capsule("Chest", 0.19, 0.62, Vector3(0, 0.27, 0), Vector3.ZERO, _cloth_mat, _torso)
	_chest.scale = Vector3(1.0, 1.0, 0.8)
	_shoulders = Node3D.new()
	_shoulders.position = Vector3(0, 0.46, 0)
	_torso.add_child(_shoulders)
	_capsule("ShoulderBar", 0.075, 0.46, Vector3.ZERO, Vector3(0, 0, 90), _cloth_mat, _shoulders)
	_capsule("Neck", 0.055, 0.14, Vector3(0, 0.08, 0), Vector3.ZERO, _skin_mat, _shoulders)
	_sphere("Head", 0.105, Vector3(0, 0.23, 0.01), _skin_mat, _shoulders).scale = Vector3(0.9, 1.1, 1.0)
	for side in [-1.0, 1.0]:
		var arm := _capsule("Arm", 0.045, 0.62, Vector3(side * 0.24, -0.3, 0), Vector3(0, 0, side * 4.0), _cloth_mat, _shoulders)
		_arm_parts.append(arm)
		_sphere("Hand", 0.045, Vector3(side * 0.26, -0.63, 0.02), _skin_mat, _shoulders)


## Seated: straight arms from the shoulders, braced on the knees.
func _update_arms() -> void:
	if not seated or _arm_parts.size() < 2:
		return
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var shoulder := to_local(_shoulders.to_global(Vector3(side * 0.19, 0, 0)))
		_place_between(_arm_parts[i], shoulder, _hand_targets[i], 0.045)


# --- Small mesh helpers ----------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


func _capsule(n: String, radius: float, height: float, pos: Vector3, rot_deg: Vector3,
		mat: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 16
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _sphere(n: String, radius: float, pos: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _box(n: String, size: Vector3, pos: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _limb(n: String, a: Vector3, b: Vector3, radius: float, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mi := _capsule(n, radius, 0.1, Vector3.ZERO, Vector3.ZERO, mat, parent)
	_place_between(mi, a, b, radius)
	return mi


## Stretch a capsule between two points (in this node's local space).
func _place_between(mi: MeshInstance3D, a: Vector3, b: Vector3, radius: float) -> void:
	var mesh := mi.mesh as CapsuleMesh
	var length := a.distance_to(b)
	mesh.height = maxf(length + radius * 2.0, radius * 2.0)
	var mid := (a + b) * 0.5
	var up := (b - a).normalized()
	var helper := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := up.cross(helper).normalized()
	var z := x.cross(up).normalized()
	mi.transform = Transform3D(Basis(x, up, z), mid)
