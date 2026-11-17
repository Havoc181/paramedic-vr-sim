extends Node3D
## Root of the scene. Switches the viewport into VR if OpenXR started.

func _ready() -> void:
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		print("OpenXR running.")
	else:
		push_warning("OpenXR did not start. Is the Quest connected via Link and Meta Quest Link set as the active OpenXR runtime?")
