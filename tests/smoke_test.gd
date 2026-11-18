extends SceneTree
## Headless smoke test: loads the main scene and pokes the menu, teleport and
## settings without a headset. Run with:
##   godot --headless -s res://tests/smoke_test.gd

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures += 1


func _initialize() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var room := main.get_node("Room")
	check(room.get_child_count() > 40, "room built (%d nodes)" % room.get_child_count())
	check(room.find_child("PatientSeat", true, false) != null, "patient seat marker exists")
	check(room.find_child("Sun", true, false) is DirectionalLight3D, "sun light exists")

	var player = main.get_node("XROrigin3D")
	var menu = main.get_node("Menu")
	check(not menu.visible, "menu hidden at start")
	player.menu_toggle_requested.emit()
	check(menu.visible and not player.input_enabled, "menu opens and freezes movement")

	var before_move: bool = player.smooth_move_enabled
	menu.get_node("Button_movement").interact()
	check(player.smooth_move_enabled != before_move, "movement toggle works")
	var before_turn: int = player.turn_mode
	menu.get_node("Button_turning").interact()
	check(player.turn_mode == (before_turn + 1) % 3, "turning cycles")
	menu.get_node("Button_vignette").interact()
	check(player.vignette_enabled == false, "vignette toggles off")
	check(FileAccess.file_exists("user://settings.cfg"), "settings saved")
	menu.get_node("Button_resume").interact()
	check(not menu.visible and player.input_enabled, "resume closes menu")

	var cam: Node3D = player.get_node("XRCamera3D")
	player.teleport_to(Vector3(1.0, 0.0, -0.5))
	await create_timer(0.6).timeout
	check(absf(cam.global_position.x - 1.0) < 0.05 and absf(cam.global_position.z + 0.5) < 0.05, "teleport moves head to target")
	check(player.is_inside_room(Vector3(0, 0, 0)) and not player.is_inside_room(Vector3(5, 0, 0)), "room bounds check")

	# Restore defaults so the test leaves no odd settings behind.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	print("FAILURES: ", failures)
	quit(failures)
