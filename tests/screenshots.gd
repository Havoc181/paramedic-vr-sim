extends SceneTree
# Renders pitch screenshots of the scenario from fixed camera positions.
# xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 -s res://tests/_shot.gd

const SHOTS := [
	["shot_kneel.png", Vector3(-0.35, 0.95, -0.35), Vector3(-0.3, 0.75, -1.4)],
	["shot_door.png", Vector3(-1.4, 1.65, 1.4), Vector3(-0.2, 0.8, -1.2)],
	["shot_ken.png", Vector3(0.0, 1.6, 0.6), Vector3(0.95, 1.45, -0.55)],
	["shot_side.png", Vector3(1.3, 1.0, -1.0), Vector3(-0.3, 0.8, -1.4)],
]

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var cam := Camera3D.new()
	cam.fov = 75
	root.add_child(cam)
	cam.current = true
	for n in main.find_children("*", "Label3D", true, false):
		if n.name == "Instructions":
			n.visible = false
	for i in 60:
		await process_frame
	for s in SHOTS:
		cam.position = s[1]
		cam.look_at(s[2])
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("/tmp/" + s[0])
	quit()
