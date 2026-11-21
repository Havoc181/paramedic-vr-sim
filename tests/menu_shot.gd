extends SceneTree
# Renders the main menu (MENU=1 forces it outside the headset).
func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 80:
		await process_frame
	var menu = main.find_child("StartMenu", true, false)
	var cam := Camera3D.new()
	cam.fov = 60
	root.add_child(cam)
	cam.current = true
	cam.global_position = menu.global_position + menu.global_basis.z * 1.05
	cam.look_at(menu.global_position + Vector3(0, -0.12, 0))
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/tmp/menu.png")
	quit()
