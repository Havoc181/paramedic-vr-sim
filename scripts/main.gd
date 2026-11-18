extends Node3D
## Root of the scene. Starts VR.
##
## Note: foveated rendering and the 90 Hz switch were removed while tracking
## down a grey-screen problem on the Quest (2026-11-18). Re-add one at a time
## once the cause is confirmed.

func _ready() -> void:
	var xr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr and xr.is_initialized():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		print("OpenXR running.")
	else:
		push_warning("OpenXR did not start. Is the Quest connected via Link and Meta Quest Link set as the active OpenXR runtime?")
