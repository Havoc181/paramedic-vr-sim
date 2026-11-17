extends RayCast3D
## Laser pointer on a controller. Pull the trigger while pointing at
## anything with an interact() method to use it.

@onready var controller: XRController3D = get_parent()
@onready var beam: MeshInstance3D = $Beam

var _was_pressed := false


func _physics_process(_delta: float) -> void:
	var length := absf(target_position.z)
	var target: Object = null
	if is_colliding():
		length = global_position.distance_to(get_collision_point())
		target = get_collider()
	beam.scale.z = length
	beam.position.z = -length / 2.0

	var pressed := controller.is_button_pressed("trigger_click")
	if pressed and not _was_pressed and target and target.has_method("interact"):
		target.interact()
		controller.trigger_haptic_pulse("haptic", 0.0, 0.4, 0.08, 0.0)
	_was_pressed = pressed
