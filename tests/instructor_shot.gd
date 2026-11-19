extends SceneTree
func _initialize() -> void:
	var app = load("res://scenes/instructor.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app._found["192.168.43.17"] = {"scenario":"Acute pulmonary oedema","busy":false,"seen":Time.get_ticks_msec()}
	app._on_message({"t":"hello","scenario":"Acute pulmonary oedema"})
	app._connected_to = "192.168.43.17"
	app._set_status("Connected to 192.168.43.17 - Acute pulmonary oedema")
	app._add_log(12, "checked", "Look at position: Bolt upright on the edge of the sofa, tripod, frightened.")
	app._add_log(31, "asked", "\"What's happened tonight?\"  Joan: Woke up... couldn't breathe... like drowning.")
	app._add_log(48, "asked", "\"Any chest pain?\"  Joan: Tight... not pain. Just... can't get air.")
	app._add_log(60, "instructor", "Patient condition set to +0.5 (worse)")
	app._add_log(75, "instructor", "Event: the phone rings")
	app._add_log(140, "finished", "Impression: Acute pulmonary oedema / acute heart failure. Urgency: Time critical.")
	app._on_message({"t":"pose","x":-0.35,"y":0.95,"z":-0.6,"yaw":PI})
	app._on_message({"t":"state","state":{"paused":false,"severity":0.5}})
	app._notes.text = "Good early recognition of work of breathing. Didn't check the ankles."
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/tmp/instructor.png")
	quit()
