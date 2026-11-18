extends Node3D
## Root of the scene. Starts VR and applies Quest performance settings.

func _ready() -> void:
	var xr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr and xr.is_initialized():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		# Foveated rendering: full detail where you look, less at the edges.
		xr.foveation_level = 3
		xr.foveation_dynamic = true
		xr.session_begun.connect(_on_session_begun.bind(xr))
		print("OpenXR running.")
	else:
		push_warning("OpenXR did not start. Is the Quest connected via Link and Meta Quest Link set as the active OpenXR runtime?")


func _on_session_begun(xr: OpenXRInterface) -> void:
	# Prefer 90 Hz on Quest 3 for smoother, more comfortable motion.
	var rates := xr.get_available_display_refresh_rates()
	if rates.has(90.0):
		xr.display_refresh_rate = 90.0
	var hz := int(xr.display_refresh_rate)
	if hz > 0:
		Engine.physics_ticks_per_second = hz
	print("Display refresh rate: ", xr.display_refresh_rate, " Hz")
