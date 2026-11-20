extends SceneTree
# Renders the interaction panel to check paging visuals.
func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await process_frame
	var panel = main.find_child("InteractionPanel", true, false)
	panel.open()
	for i in 10:
		await process_frame
	var cam := Camera3D.new()
	cam.fov = 60
	root.add_child(cam)
	cam.current = true
	cam.global_position = panel.global_position + panel.global_basis.z * 0.9
	cam.look_at(panel.global_position)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/tmp/panel_p1.png")
	panel._change_page(1)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/tmp/panel_p2.png")
	quit()
