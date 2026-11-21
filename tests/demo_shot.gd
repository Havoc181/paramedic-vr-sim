extends SceneTree
# Demo panel, open mouth (tongue), and tripod levels, scenario 02 (Maureen).
# SCEN=apo_01 for Joan.
func _initialize() -> void:
	var scen := OS.get_environment("SCEN")
	load("res://scripts/scenario_runner.gd").next_path = "res://scenarios/%s.json" % (scen if scen != "" else "copd_02")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await process_frame
	var pause = main.find_child("PauseMenu", true, false)
	if pause == null:
		for n in main.find_children("*", "Node3D", true, false):
			if n.has_method("_refresh_labels"):
				pause = n
	pause._on_pressed("signs")
	var demo = main.find_child("DemoMenu", true, false)
	var pt = null
	for c in main.find_children("*", "", true, false):
		if c.has_method("reset_skin_signs") and c.data.get("role", "") == "patient":
			pt = c
	var cam := Camera3D.new()
	cam.fov = 70
	root.add_child(cam)
	cam.current = true
	cam.global_position = demo.global_position + demo.global_basis.z * 0.75 + Vector3(0, -0.1, 0)
	cam.look_at(demo.global_position + Vector3(0, -0.25, 0))
	await _shot("/tmp/demo_panel.png")
	demo._pick("cyanosis_tongue")
	demo._pick("grey")
	demo._pick("clammy")
	demo._pick("cyanosis_lips")
	await create_timer(1.2).timeout
	var head: Vector3 = pt._rig.skeleton.to_global(pt._rig.skeleton.get_bone_global_pose(pt._rig.skeleton.find_bone("head")).origin)
	var fwd: Vector3 = pt.global_basis.z
	cam.fov = 35
	cam.global_position = head + fwd * 0.55 + Vector3(0, -0.05, 0)
	cam.look_at(head + Vector3(0, -0.02, 0) + fwd * 0.05)
	await _shot("/tmp/demo_mouth.png")
	demo._pick("")
	cam.fov = 55
	for lvl in [0.0, 0.5, 1.0]:
		pt._rig.set_tripod_level(lvl, 0.0)
		await create_timer(0.3).timeout
		var side: Vector3 = pt.global_basis.x
		cam.global_position = pt.global_position + side * 1.6 + fwd * 0.4 + Vector3(0, 0.9, 0)
		cam.look_at(pt.global_position + Vector3(0, 0.6, 0) + fwd * 0.2)
		await _shot("/tmp/tripod_%d_side.png" % int(lvl * 10))
		cam.global_position = pt.global_position + fwd * 0.7 + side * 0.25 + Vector3(0, 0.9, 0)
		cam.look_at(pt.global_position + Vector3(0, 0.5, 0) + fwd * 0.3)
		await _shot("/tmp/tripod_%d_hands.png" % int(lvl * 10))
	quit()

func _shot(path: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
