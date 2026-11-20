extends SceneTree
# Close-ups of the patient's face at several cyanosis / clammy levels.
func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	for n in main.find_children("*", "Label3D", true, false):
		n.visible = false
	var cam := Camera3D.new(); cam.fov = 26; root.add_child(cam); cam.current = true
	var ch = null
	for c in main.find_children("*", "", true, false):
		if c.has_method("say") and c._rig and c.data.get("role", "") == "patient":
			ch = c
	if ch == null:
		for c in main.find_children("*", "", true, false):
			if c.has_method("say") and c._rig: ch = c
	ch.set_process(false)
	var rig = ch._rig
	var sk: Skeleton3D = rig.skeleton
	var head: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("head"))).origin
	var fwd: Vector3 = sk.global_basis.z.normalized()
	var face := head + Vector3(0, 0.04, 0) + fwd * 0.08
	var levels := [[0.0, 0.0], [0.4, 0.3], [0.7, 0.3], [0.4, 0.6], [0.0, 0.0]]
	for i in levels.size():
		rig.set_cyanosis(levels[i][0]); rig.set_clammy(levels[i][1])
		cam.global_position = face + fwd * 0.55 + Vector3(0.12, 0.05, 0)
		cam.look_at(face)
		for f in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("/tmp/skin_%d.png" % i)
	quit()
