extends SceneTree
# Renders close-ups of each character's mouth closed and open (teeth/tongue check).
func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	var cam := Camera3D.new(); cam.fov = 30; root.add_child(cam); cam.current = true
	for n in main.find_children("*", "Label3D", true, false):
		n.visible = false
	for c in main.find_children("*", "", true, false):
		if c.has_method("say"):
			c.set_process(false)
	var k := 0
	for sk in main.find_children("*", "Skeleton3D", true, false):
		var hb := -1
		for i in sk.get_bone_count():
			if sk.get_bone_name(i) == "head":
				hb = i
		if hb < 0:
			continue
		var rig = null
		for c in main.find_children("*", "", true, false):
			if c.has_method("say") and c._rig and c._rig.skeleton == sk:
				rig = c._rig
		print("RIG ", rig, " jaw ", sk.find_bone("jaw"), " skel ", sk.name)
		var head: Vector3 = (sk.global_transform * sk.get_bone_global_pose(hb)).origin
		var fwd: Vector3 = sk.global_basis.z.normalized()
		for open in [0.0, 1.0]:
			for f in 6:
				if rig: rig.set_jaw(open)
				var mouth := head + Vector3(0, 0.05, 0) + fwd * 0.08
				cam.global_position = mouth + fwd * 0.45 + Vector3(0, -0.03, 0)
				cam.look_at(mouth)
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("/tmp/mouth_%d_%d.png" % [k, int(open)])
		k += 1
	quit()
