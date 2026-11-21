extends SceneTree
# Close-ups of the patient in her scenario posture from several viewpoints, for
# clipping checks. Env: SCEN=<scenario json>, LEGS=off to roll trousers.
func _initialize() -> void:
	if OS.get_environment("SCEN") != "":
		load("res://scripts/scenario_runner.gd").next_path = OS.get_environment("SCEN")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40: await process_frame
	for n in main.find_children("*", "Label3D", true, false): n.visible = false
	var ch = null
	for c in main.find_children("*", "", true, false):
		if c.has_method("set_sign") and c._rig and c.data.get("role","") == "patient": ch = c
	if OS.get_environment("LEGS") == "off": ch.set_legs("off")
	for f in 10: await process_frame
	var sk: Skeleton3D = ch._rig.skeleton
	var fwd: Vector3 = sk.global_basis.z.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var knee: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("lowerleg01.L")).origin
	var kneeR: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("lowerleg01.R")).origin
	var mid := (knee + kneeR) * 0.5
	var cam := Camera3D.new(); cam.fov = 40; root.add_child(cam); cam.current = true
	var views := [
		[mid + fwd * 0.9 + Vector3(0, 0.6, 0), mid],                         # standing in front
		[mid + fwd * 0.55 + Vector3(0, 0.15, 0), mid],                       # kneeling in front
		[knee + right * 0.45 + fwd * 0.2 + Vector3(0, 0.15, 0), knee],        # her left side, low
		[kneeR - right * 0.45 + fwd * 0.2 + Vector3(0, 0.15, 0), kneeR],      # her right side, low
		[knee + fwd * 0.25 + Vector3(0, 0.25, 0), knee],                      # close on left hand
		[mid + fwd * 0.05 + Vector3(0, 0.9, 0), mid + fwd * 0.05],             # from above
	]
	for i in views.size():
		cam.global_position = views[i][0]
		cam.look_at(views[i][1])
		for f in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("/tmp/clip_%d.png" % i)
	quit()
