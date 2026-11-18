extends Node3D
## When using hand tracking, a small "Menu" button appears above your left
## wrist while your left palm faces you. Point at it with your right hand and
## pinch to open the menu.

@export var player_path: NodePath

@onready var player = get_node(player_path)

var _button


func _ready() -> void:
	top_level = true
	_button = preload("res://scripts/menu_button.gd").new()
	_button.size = Vector2(0.09, 0.04)
	_button.text = "Menu"
	add_child(_button)
	_button.pressed.connect(func(): player.menu_toggle_requested.emit())
	_show(false)


func _process(_delta: float) -> void:
	var tracker := XRServer.get_tracker(&"/user/hand_tracker/left") as XRHandTracker
	if tracker == null or not tracker.has_tracking_data or not player.input_enabled:
		_show(false)
		return
	var palm_local := tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM)
	var palm: Transform3D = player.global_transform * palm_local
	var cam: Node3D = player.get_node("XRCamera3D")
	var to_cam := (cam.global_position - palm.origin).normalized()
	# The palm faces along the palm joint's -Y axis.
	var facing := (-palm.basis.y).normalized().dot(to_cam)
	if facing < 0.5:
		_show(false)
		return
	var pos := palm.origin + (-palm.basis.y) * 0.06
	global_transform = Transform3D(Basis.looking_at(-to_cam, Vector3.UP), pos)
	_show(true)


func _show(value: bool) -> void:
	visible = value
	_button.collision_layer = 1 if value else 0
