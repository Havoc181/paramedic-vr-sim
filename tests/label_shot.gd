extends SceneTree
# Renders the wall instructions and the scenario 02 prop cards (open, close up).
func _initialize() -> void:
	load("res://scripts/scenario_runner.gd").next_path = "res://scenarios/copd_02.json"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await process_frame
	var cam := Camera3D.new()
	cam.fov = 75
	root.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(-0.6, 1.6, 0.1)
	cam.look_at(Vector3(-2.28, 1.5, 0.1))
	await _shot("/tmp/wall.png")
	for id in ["inhalers", "MedicinesBox"]:
		var b = main.find_child(id, true, false)
		b.interact()
		var p: Vector3 = b.global_position
		cam.global_position = p + Vector3(-0.45, 0.45, 0.35)
		cam.look_at(p + Vector3(0, 0.15, 0))
		await _shot("/tmp/card_%s.png" % id)
		b.interact()
	quit()

func _shot(path: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
