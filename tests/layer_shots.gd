extends SceneTree
# Layered character check: the patient in her scenario posture in every
# exposure state, front and side, full figure. SCEN=<json>. Writes
# /tmp/layers_<state>_<view>.png and a contact sheet is made outside.
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
	var sk: Skeleton3D = ch._rig.skeleton
	var cam := Camera3D.new(); cam.fov = 45; root.add_child(cam); cam.current = true
	var states := [["dressed", "on", "on"], ["lifted", "lifted", "on"], ["off", "off", "on"], ["legs", "on", "off"], ["all", "off", "off"]]
	for st in states:
		ch.set_exposure(st[1])
		ch.set_legs(st[2])
		for f in 60: await process_frame   # blend into sit-back / back to tripod
		var fwd: Vector3 = sk.global_basis.z.normalized()
		var right: Vector3 = fwd.cross(Vector3.UP).normalized()
		var hips: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("spine05")).origin
		var views := [
			[hips + fwd * 1.5 + Vector3(0, 0.35, 0), hips + Vector3(0, 0.05, 0)],
			[hips + right * 1.4 + fwd * 0.5 + Vector3(0, 0.3, 0), hips + Vector3(0, 0.05, 0)],
			[hips + fwd * 0.6 + Vector3(0, 0.15, 0), hips + Vector3(0, 0.0, 0) + fwd * 0.1],
		]
		for i in views.size():
			cam.global_position = views[i][0]
			cam.look_at(views[i][1])
			for f in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("/tmp/layers_%s_%d.png" % [st[0], i])
	quit()
