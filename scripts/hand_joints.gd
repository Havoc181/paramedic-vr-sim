extends Node3D
## Draws a tracked hand as small spheres on each joint.
## Must be a direct child of XROrigin3D (joint positions are in tracking space).

@export var hand_tracker_name: StringName = &"/user/hand_tracker/left"
@export var joint_colour := Color(0.95, 0.8, 0.7)

var _spheres: Array[MeshInstance3D] = []


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.008
	mesh.height = 0.016
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = joint_colour
	mesh.material = mat
	for i in XRHandTracker.HAND_JOINT_MAX:
		var s := MeshInstance3D.new()
		s.mesh = mesh
		s.visible = false
		add_child(s)
		_spheres.append(s)


func _process(_delta: float) -> void:
	var tracker := XRServer.get_tracker(hand_tracker_name) as XRHandTracker
	var tracked := tracker != null and tracker.has_tracking_data
	for i in _spheres.size():
		var s := _spheres[i]
		if not tracked:
			s.visible = false
			continue
		var flags: int = tracker.get_hand_joint_flags(i)
		if flags & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID:
			s.position = tracker.get_hand_joint_transform(i).origin
			s.visible = true
		else:
			s.visible = false
