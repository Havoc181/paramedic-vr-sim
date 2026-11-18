extends RayCast3D
## Laser pointer on a controller (or tracked hand). Pull the trigger, or pinch,
## while pointing at anything with an interact() method to use it.
## Things that have hover_enter()/hover_exit() light up while pointed at.

@onready var controller: XRController3D = get_parent()
@onready var beam: MeshInstance3D = $Beam

var _was_pressed := false
var _hovered: Object = null


func _physics_process(_delta: float) -> void:
	var length := absf(target_position.z)
	var target: Object = null
	if is_colliding():
		length = global_position.distance_to(get_collision_point())
		target = get_collider()
	beam.scale.z = length
	beam.position.z = -length / 2.0

	if target != _hovered:
		if is_instance_valid(_hovered) and _hovered.has_method("hover_exit"):
			_hovered.hover_exit()
		if target and target.has_method("hover_enter"):
			target.hover_enter()
			controller.trigger_haptic_pulse("haptic", 0.0, 0.15, 0.02, 0.0)
		_hovered = target

	var pressed := controller.is_button_pressed("trigger_click")
	if pressed and not _was_pressed and target and target.has_method("interact"):
		target.interact()
		controller.trigger_haptic_pulse("haptic", 0.0, 0.4, 0.08, 0.0)
	_was_pressed = pressed
