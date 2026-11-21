extends SceneTree
# The awkward angles from headset testing (21 Nov): back of the knee from low
# down, the neckline from a front-side angle close up, the lifted top from the
# side, and the bystander's shoes. SCEN=<json>. Writes /tmp/angle_<n>.png.
func _initialize() -> void:
	if OS.get_environment("SCEN") != "":
		load("res://scripts/scenario_runner.gd").next_path = OS.get_environment("SCEN")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40: await process_frame
	for n in main.find_children("*", "Label3D", true, false): n.visible = false
	var pt = null
	var other = null
	for c in main.find_children("*", "", true, false):
		if c.has_method("set_sign") and c._rig:
			if c.data.get("role","") == "patient": pt = c
			else: other = c
	var cam := Camera3D.new(); cam.fov = 40; root.add_child(cam); cam.current = true
	var sk: Skeleton3D = pt._rig.skeleton
	var P := func(bone: String) -> Vector3: return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
	var fwd: Vector3 = sk.global_basis.z.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var shots := []
	var knee: Vector3 = P.call("lowerleg01.L")
	var kneeR: Vector3 = P.call("lowerleg01.R")
	shots.append([knee + fwd * 0.35 - right * 0.55 + Vector3(0, 0.55, 0), knee - fwd * 0.05])      # knee from standing beside her
	shots.append([kneeR + fwd * 0.35 + right * 0.55 + Vector3(0, 0.55, 0), kneeR - fwd * 0.05])
	var neck: Vector3 = P.call("neck01")
	shots.append([neck + fwd * 0.42 + right * 0.28 + Vector3(0, 0.02, 0), neck + fwd * 0.06 - Vector3(0, 0.1, 0)])  # neckline 3/4
	shots.append([neck + fwd * 0.42 - right * 0.28 + Vector3(0, 0.02, 0), neck + fwd * 0.06 - Vector3(0, 0.1, 0)])
	var chest: Vector3 = P.call("spine04")
	for s in shots.size():
		cam.global_position = shots[s][0]; cam.look_at(shots[s][1])
		await _shot("/tmp/angle_%d.png" % s)
	pt.set_exposure("lifted")
	for f in 60: await process_frame
	chest = P.call("spine04")
	cam.global_position = chest + right * 0.55 + fwd * 0.35 + Vector3(0, 0.0, 0); cam.look_at(chest + fwd * 0.05 - Vector3(0, 0.08, 0))
	await _shot("/tmp/angle_6.png")
	cam.global_position = chest + fwd * 0.45 - right * 0.25 + Vector3(0, 0.1, 0); cam.look_at(chest + fwd * 0.1)
	await _shot("/tmp/angle_7.png")
	if other:
		var osk: Skeleton3D = other._rig.skeleton
		var foot: Vector3 = osk.global_transform * osk.get_bone_global_pose(osk.find_bone("foot.L")).origin
		cam.global_position = foot + other.global_basis.z * 0.6 + Vector3(0, 0.35, 0); cam.look_at(foot)
		await _shot("/tmp/angle_8.png")
		var ofoot: Vector3 = foot
		cam.global_position = ofoot - other.global_basis.z * 0.6 + other.global_basis.x * 0.3 + Vector3(0, 0.3, 0); cam.look_at(ofoot)
		await _shot("/tmp/angle_9.png")
	quit()

func _shot(path: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
