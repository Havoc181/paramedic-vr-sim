extends SceneTree
# Renders the patient with top on / lifted / off, and the belly in and out.
func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	for n in main.find_children("*", "Label3D", true, false):
		n.visible = false
	var cam := Camera3D.new(); cam.fov = 50; root.add_child(cam); cam.current = true
	var ch = null
	for c in main.find_children("*", "", true, false):
		if c.has_method("set_exposure") and c.data.get("role", "") == "patient":
			ch = c
	print("CAN EXPOSE ", ch.can_expose())
	if OS.get_environment("HIDE_BODY") == "1":
		for mi in main.find_children("Joan_export", "MeshInstance3D", true, false):
			mi.visible = false
	if OS.get_environment("HIDE_JEANS") == "1":
		for mi in main.find_children("*casualsuit*", "MeshInstance3D", true, false):
			mi.visible = false
	var sk: Skeleton3D = ch._rig.skeleton
	var fwd: Vector3 = sk.global_basis.z.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var k := 0
	for state in ["on", "lifted", "off"]:
		ch.set_exposure(state)
		for f in 100:
			await process_frame
		var chest: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("spine03"))).origin
		for view in [0, 1]:
			cam.global_position = chest + fwd * 0.95 + right * (0.0 if view == 0 else 0.55) + Vector3(0, 0.05, 0)
			cam.look_at(chest + Vector3(0, -0.02, 0))
			ch.set_process(false)
			for b in [0.0, 1.0]:
				ch._rig.abdominal_paradox = true
				ch._rig.apply_breath(b, 0.6, 0.0)
				for f in 3:
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png("/tmp/exp_%s_%d_%d.png" % [state, view, int(b)])
			ch.set_process(true)
		k += 1
	quit()
