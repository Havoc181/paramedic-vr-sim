extends SceneTree
# Joan sat back for exposure should ask to sit forward after ~12 s, then repeat.
func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await process_frame
	var runner = main.find_child("ScenarioRunner", true, false)
	if runner == null:
		for n in main.find_children("*", "", true, false):
			if n.get("sit_forward_asks") != null:
				runner = n
	var joan = runner.characters["joan"]
	var panel = main.find_child("InteractionPanel", true, false)
	var got := []
	panel.logged.connect(func(k, t): got.append([k, t]))
	joan.set_exposure("off")
	var t := 0.0
	while t < 45.0:
		await create_timer(0.5).timeout
		t += 0.5
	print("asks=", runner.sit_forward_asks)
	for g in got:
		print(g)
	joan.set_exposure("on")
	await create_timer(1.0).timeout
	print("after cover asks counter reset: ", joan._asks)
	quit()
