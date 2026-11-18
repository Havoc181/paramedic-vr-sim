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
	check(player.turn_mode == 2, "smooth turning is the default")
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


	# Scenario: characters, props and the interaction panel.
	await process_frame
	var runner = main.get_node("Scenario")
	check(runner.characters.has("joan") and runner.characters.has("ken"), "Joan and Ken spawned")
	var joan = runner.characters.get("joan")
	check(joan != null and joan.global_position.distance_to(Vector3(-0.3, 0.42, -1.42)) < 0.05, "Joan is on the sofa")
	check(runner.find_child("MedicinesBox", true, false) != null, "medicines box placed")
	var panel = runner.get_node("InteractionPanel")
	joan.interact()
	check(panel.visible and not player.input_enabled, "pointing at Joan opens the panel")
	panel._on_item(0)
	await create_timer(0.1).timeout
	check(panel._asked.has("events"), "first question asked")
	check(joan._subtitle.visible, "Joan answers with a subtitle")
	panel._on_tab("assess")
	panel._on_item(7)
	check(panel._result.text.length() > 10, "assessment finding shown")
	# Asking about medications: Ken hands over the medicines box.
	panel._on_tab("ask")
	panel._speaking = false
	var meds_idx := -1
	for i in panel._items.size():
		if panel._items[i].get("id", "") == "meds":
			meds_idx = i
	panel._page = meds_idx / panel.PER_PAGE
	panel._refresh()
	panel._on_item(meds_idx % panel.PER_PAGE)
	await create_timer(0.1).timeout
	var box = runner.find_child("MedicinesBox", true, false)
	check(box._open and box.global_position.distance_to(cam.global_position) < 0.7, "Ken hands over the medicines box")
	panel._on_tab("close")
	check(not panel.visible and player.input_enabled, "panel closes")

	# Restore defaults so the test leaves no odd settings behind.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	print("FAILURES: ", failures)
	quit(failures)
