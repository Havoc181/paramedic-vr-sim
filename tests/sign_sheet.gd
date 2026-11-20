extends SceneTree
# Renders every clinical sign on its own on the patient: one image per sign
# (moving signs: breath out | breath in), into /tmp/signs/. Run:
#   xvfb-run godot --rendering-driver opengl3 -s res://tests/sign_sheet.gd
# Env: SIGN=<id> to render one; WHO=<character id> for another character.

const LIB := preload("res://scripts/patient/sign_library.gd")

const VIEW := {
	"pallor": "face", "grey": "face", "flushing": "face", "clammy": "face", "drowsy": "face",
	"cyanosis_lips": "mouth", "cyanosis_tongue": "mouth", "pursed_lips": "mouth",
	"cyanosis_peripheral": "hand", "capillary_refill": "hand",
	"prolonged_expiration": "face", "recession_suprasternal": "notch",
	"recession_intercostal": "side", "hoovers_sign": "front_chest", "recession_subcostal": "abdomen",
	"abdominal_paradox": "abdomen_side", "jvp": "neck_right", "mottling": "knee", "oedema_ankle": "ankle",
}
const MOVING := ["recession_suprasternal", "recession_intercostal", "recession_subcostal", "hoovers_sign",
	"abdominal_paradox", "pursed_lips", "jvp", "drowsy", "capillary_refill"]


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	for n in main.find_children("*", "Label3D", true, false):
		n.visible = false
	var cam := Camera3D.new(); cam.fov = 38; root.add_child(cam); cam.current = true
	var who := OS.get_environment("WHO")
	var ch = null
	for c in main.find_children("*", "", true, false):
		if c.has_method("set_sign") and c._rig:
			if (who == "" and c.data.get("role", "") == "patient") or (who != "" and c.character_id == who):
				ch = c
	ch.set_process(false)
	var rig = ch._rig
	var sg = rig.signs
	var sk: Skeleton3D = rig.skeleton
	DirAccess.make_dir_recursive_absolute("/tmp/signs")
	var only := OS.get_environment("SIGN")
	var ids: Array = [only] if only != "" else LIB.ORDER
	for id in ids:
		var all := {}; all[id] = 0.9
		sg.set_all(all)
		var need: String = LIB.SIGNS[id].get("exposure", "")
		if ch.can_expose():
			ch.set_exposure({"abdomen": "lifted", "chest": "off"}.get(need, "on"))
			for f in 90:
				rig.update(1.0 / 60.0)
		ch.set_legs("off" if need == "legs" else "on")
		var frames := []
		for b in ([0.0, 1.0] if id in MOVING else [0.6]):
			_frame(sg, rig, id, b)
			_aim(cam, sk, String(VIEW.get(id, "face")))
			for f in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			frames.append(root.get_viewport().get_texture().get_image())
		var w: int = frames[0].get_width()
		var h: int = frames[0].get_height()
		var out := Image.create(w * frames.size(), h, false, frames[0].get_format())
		for k in frames.size():
			out.blit_rect(frames[k], Rect2i(0, 0, w, h), Vector2i(k * w, 0))
		out.save_png("/tmp/signs/%s.png" % id)
		print("SIGN ", id)
	quit()


func _frame(sg, rig, id: String, b: float) -> void:
	rig.apply_breath(b, 0.6, 0.0)
	if id == "capillary_refill":
		sg.press_nail(b > 0.5)
		for k in 30:
			sg.update(1.0 / 30.0, b, true)
		return
	if id == "drowsy":
		sg._drowsy_t = 5.5 if b > 0.5 else 0.2
		sg._nod = 1.0 if b > 0.5 else 0.0
	for k in 20:
		sg.update(0.05, b, b > 0.5)
	if id == "jvp":
		sg._beat_t = 0.06 if b > 0.5 else 0.35
		sg.update(0.0, b, b > 0.5)


func _bone(sk: Skeleton3D, n: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n)).origin


func _aim(cam: Camera3D, sk: Skeleton3D, view: String) -> void:
	var fwd: Vector3 = sk.global_basis.z.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()   # towards the patient's left
	var head := _bone(sk, "head")
	var target := head
	var from := head + fwd * 0.6
	match view:
		"face":
			target = head + Vector3(0, 0.03, 0) + fwd * 0.07
			from = target + fwd * 0.55 + right * 0.12
		"mouth":
			target = _bone(sk, "oris01") + Vector3(0, 0.01, 0)
			from = target + fwd * 0.3 + Vector3(0, -0.02, 0)
		"hand":
			target = _bone(sk, "finger3-2.L")
			from = target + fwd * 0.25 + Vector3(0, 0.25, 0)
		"notch":
			target = (_bone(sk, "clavicle.L") + _bone(sk, "clavicle.R")) * 0.5 + fwd * 0.05
			from = target + fwd * 0.4 + Vector3(0, 0.08, 0)
		"neck_right":
			target = _bone(sk, "neck01") + Vector3(0, 0.0, 0)
			from = target - right * 0.3 + fwd * 0.32 + Vector3(0, 0.03, 0)
		"side":
			target = _bone(sk, "spine02") + Vector3(0, 0.06, 0)
			from = target - right * 0.75 + fwd * 0.2
		"front_chest":
			target = _bone(sk, "spine02") + fwd * 0.08
			from = target + fwd * 0.8 + Vector3(0, 0.1, 0)
		"abdomen":
			target = _bone(sk, "spine03") + fwd * 0.12 + Vector3(0, 0.05, 0)
			from = target + fwd * 0.75 + Vector3(0, 0.15, 0)
		"abdomen_side":
			target = _bone(sk, "spine03") + fwd * 0.1 + Vector3(0, 0.05, 0)
			from = target - right * 0.7 + fwd * 0.35
		"knee":
			target = _bone(sk, "lowerleg01.L")
			from = target + fwd * 0.6 + Vector3(0, 0.3, 0)
		"ankle":
			target = _bone(sk, "foot.L") + Vector3(0, 0.06, 0)
			from = target + fwd * 0.6 + Vector3(0, 0.2, 0)
	cam.global_position = from
	cam.look_at(target)
