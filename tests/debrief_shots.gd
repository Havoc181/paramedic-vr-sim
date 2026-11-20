extends SceneTree
func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40: await process_frame
	var runner = main.find_child("Scenario", true, false)
	var panel = runner._panel
	for id in ["position", "breathing", "speech", "colour", "mental_state"]:
		panel.assessed[id] = true
	for id in ["events", "onset", "pmh", "meds", "chest_pain"]:
		panel.asked_ids()[id] = true
	runner._on_finished("apo", "")
	var deb = runner._debrief
	var xcam: Camera3D = main.find_child("XRCamera3D", true, false)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true; cam.fov = 70
	cam.global_transform = xcam.global_transform
	cam.look_at(deb.global_position)
	print("PAGES ", deb._pages.size())
	for i in deb._pages.size():
		deb._page = i; deb._refresh()
		for k in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("/tmp/deb_%02d.png" % i)
	quit()
