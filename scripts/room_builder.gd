@tool
extends Node3D
## Builds the placeholder living room from simple shapes and procedural
## materials, so there are no art assets to buy or manage yet.
## Runs in the editor too (@tool), so the room is visible while editing.
##
## Layout (looking from above, north = -Z):
##   north wall: sofa (patient seat), floor lamp, side table, pictures
##   east wall:  window with sunlight, radiator, curtains, bookcase
##   south wall: door (south-west), TV unit
##   west wall:  armchair, plant

const WIDTH := 4.6   # X, west to east
const DEPTH := 4.0   # Z, north to south
const HEIGHT := 2.4
const WALL := 0.12

const WINDOW_Z_MIN := -1.3
const WINDOW_Z_MAX := 0.1
const WINDOW_Y_MIN := 0.9
const WINDOW_Y_MAX := 2.1

## Tick in the Inspector to rebuild the room after editing this script.
@export var rebuild := false:
	set(value):
		if value and is_inside_tree():
			_build()

var _mat := {}


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_make_materials()
	_shell()
	_window()
	_door()
	_lighting()
	_sofa()
	_side_table_and_lamp()
	_coffee_table_and_rug()
	_armchair()
	_tv_unit()
	_bookcase()
	_pictures()
	_plant()
	_outside()


# --- Materials -------------------------------------------------------------

func _make_materials() -> void:
	_mat.clear()
	_mat.floor = _shader_mat("res://shaders/floor_planks.gdshader", {})
	_mat.wall = _std(Color(0.87, 0.85, 0.8), 0.95)
	_mat.ceiling = _std(Color(0.95, 0.95, 0.94), 1.0)
	_mat.trim = _std(Color(0.96, 0.96, 0.95), 0.4)
	_mat.wood = _shader_mat("res://shaders/wood.gdshader", {})
	_mat.wood_light = _shader_mat("res://shaders/wood.gdshader", {"base_colour": Color(0.62, 0.47, 0.32)})
	_mat.sofa = _shader_mat("res://shaders/fabric.gdshader", {})
	_mat.sofa_cushion = _shader_mat("res://shaders/fabric.gdshader", {"base_colour": Color(0.34, 0.4, 0.42)})
	_mat.armchair = _shader_mat("res://shaders/fabric.gdshader", {"base_colour": Color(0.55, 0.42, 0.3)})
	_mat.curtain = _shader_mat("res://shaders/fabric.gdshader", {"base_colour": Color(0.72, 0.66, 0.55), "weave_scale": 60.0})
	_mat.shade = _shader_mat("res://shaders/fabric.gdshader", {"base_colour": Color(0.95, 0.9, 0.78)})
	_mat.rug = _shader_mat("res://shaders/rug.gdshader", {})
	_mat.blob = _shader_mat("res://shaders/blob_shadow.gdshader", {})
	_mat.sky = _shader_mat("res://shaders/sky_window.gdshader", {})
	_mat.metal = _std(Color(0.7, 0.7, 0.72), 0.3, 0.8)
	_mat.black = _std(Color(0.04, 0.04, 0.05), 0.25)
	_mat.screen = _std(Color(0.02, 0.02, 0.03), 0.1)
	_mat.radiator = _std(Color(0.94, 0.94, 0.93), 0.35)
	_mat.grass = _std(Color(0.3, 0.45, 0.2), 1.0)
	_mat.hedge = _std(Color(0.18, 0.32, 0.15), 1.0)
	_mat.fence = _std(Color(0.45, 0.33, 0.22), 0.9)
	_mat.pot = _std(Color(0.75, 0.42, 0.28), 0.8)
	_mat.leaf = _std(Color(0.2, 0.42, 0.2), 0.8)
	_mat.mug = _std(Color(0.85, 0.3, 0.25), 0.3)
	var bulb := StandardMaterial3D.new()
	bulb.albedo_color = Color(1.0, 0.92, 0.75)
	bulb.emission_enabled = true
	bulb.emission = Color(1.0, 0.85, 0.6)
	bulb.emission_energy_multiplier = 3.0
	_mat.bulb = bulb


func _std(colour: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = roughness
	m.metallic = metallic
	return m


func _shader_mat(path: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for key in params:
		m.set_shader_parameter(key, params[key])
	return m


# --- Helpers ---------------------------------------------------------------

## Adds a box. `pos` is the centre. Optional Y rotation in degrees and collision.
func _box(node_name: String, size: Vector3, pos: Vector3, mat: Material,
		collide := false, rot_y := 0.0, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees.y = rot_y
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		mi.add_child(body)
	return mi


func _cylinder(node_name: String, radius_top: float, radius_bottom: float, height: float,
		pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_top
	mesh.bottom_radius = radius_bottom
	mesh.height = height
	mesh.radial_segments = 24
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Soft dark patch on the floor under furniture.
func _blob(size: Vector2, pos: Vector3, rot_y := 0.0, strength := 0.45) -> void:
	var mesh := QuadMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = "ContactShadow"
	mi.mesh = mesh
	var m := (_mat.blob as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter("strength", strength)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(pos.x, 0.003, pos.z)
	mi.rotation_degrees = Vector3(-90.0, rot_y, 0.0)
	add_child(mi)


## A group node so furniture can be moved or rotated as one piece.
func _group(node_name: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var g := Node3D.new()
	g.name = node_name
	g.position = pos
	g.rotation_degrees.y = rot_y
	add_child(g)
	return g


# --- Room shell ------------------------------------------------------------

func _shell() -> void:
	var hx := WIDTH / 2.0
	var hz := DEPTH / 2.0
	_box("Floor", Vector3(WIDTH + WALL * 2.0, 0.1, DEPTH + WALL * 2.0), Vector3(0, -0.05, 0), _mat.floor, true)
	_box("Ceiling", Vector3(WIDTH + WALL * 2.0, 0.1, DEPTH + WALL * 2.0), Vector3(0, HEIGHT + 0.05, 0), _mat.ceiling)

	var wall_h := HEIGHT
	_box("WallNorth", Vector3(WIDTH + WALL * 2.0, wall_h, WALL), Vector3(0, wall_h / 2.0, -hz - WALL / 2.0), _mat.wall, true)
	_box("WallSouth", Vector3(WIDTH + WALL * 2.0, wall_h, WALL), Vector3(0, wall_h / 2.0, hz + WALL / 2.0), _mat.wall, true)
	_box("WallWest", Vector3(WALL, wall_h, DEPTH), Vector3(-hx - WALL / 2.0, wall_h / 2.0, 0), _mat.wall, true)

	# East wall is built around the window opening.
	var ex := hx + WALL / 2.0
	var north_len := WINDOW_Z_MIN + hz
	var south_len := hz - WINDOW_Z_MAX
	var win_len := WINDOW_Z_MAX - WINDOW_Z_MIN
	var win_mid := (WINDOW_Z_MIN + WINDOW_Z_MAX) / 2.0
	_box("WallEastNorth", Vector3(WALL, wall_h, north_len), Vector3(ex, wall_h / 2.0, -hz + north_len / 2.0), _mat.wall, true)
	_box("WallEastSouth", Vector3(WALL, wall_h, south_len), Vector3(ex, wall_h / 2.0, hz - south_len / 2.0), _mat.wall, true)
	_box("WallEastBelowWindow", Vector3(WALL, WINDOW_Y_MIN, win_len), Vector3(ex, WINDOW_Y_MIN / 2.0, win_mid), _mat.wall, true)
	var above_h := HEIGHT - WINDOW_Y_MAX
	_box("WallEastAboveWindow", Vector3(WALL, above_h, win_len), Vector3(ex, WINDOW_Y_MAX + above_h / 2.0, win_mid), _mat.wall, true)

	# Skirting boards.
	var sk_h := 0.1
	var sk_d := 0.015
	_box("SkirtingNorth", Vector3(WIDTH, sk_h, sk_d), Vector3(0, sk_h / 2.0, -hz + sk_d / 2.0), _mat.trim)
	_box("SkirtingSouth", Vector3(WIDTH, sk_h, sk_d), Vector3(0, sk_h / 2.0, hz - sk_d / 2.0), _mat.trim)
	_box("SkirtingWest", Vector3(sk_d, sk_h, DEPTH), Vector3(-hx + sk_d / 2.0, sk_h / 2.0, 0), _mat.trim)
	_box("SkirtingEast", Vector3(sk_d, sk_h, DEPTH), Vector3(hx - sk_d / 2.0, sk_h / 2.0, 0), _mat.trim)


func _window() -> void:
	var hx := WIDTH / 2.0
	var win_len := WINDOW_Z_MAX - WINDOW_Z_MIN
	var win_mid := (WINDOW_Z_MIN + WINDOW_Z_MAX) / 2.0
	var win_h := WINDOW_Y_MAX - WINDOW_Y_MIN
	var fx := hx + 0.02
	var f := 0.05
	_box("WindowFrameTop", Vector3(0.08, f, win_len), Vector3(fx, WINDOW_Y_MAX - f / 2.0, win_mid), _mat.trim)
	_box("WindowFrameBottom", Vector3(0.08, f, win_len), Vector3(fx, WINDOW_Y_MIN + f / 2.0, win_mid), _mat.trim)
	_box("WindowFrameNorth", Vector3(0.08, win_h, f), Vector3(fx, WINDOW_Y_MIN + win_h / 2.0, WINDOW_Z_MIN + f / 2.0), _mat.trim)
	_box("WindowFrameSouth", Vector3(0.08, win_h, f), Vector3(fx, WINDOW_Y_MIN + win_h / 2.0, WINDOW_Z_MAX - f / 2.0), _mat.trim)
	_box("WindowMullion", Vector3(0.06, win_h, 0.04), Vector3(fx, WINDOW_Y_MIN + win_h / 2.0, win_mid), _mat.trim)
	_box("WindowSill", Vector3(0.2, 0.03, win_len + 0.1), Vector3(hx - 0.06, WINDOW_Y_MIN - 0.015, win_mid), _mat.trim)

	# Radiator under the window.
	var rad := _box("Radiator", Vector3(0.08, 0.55, 1.1), Vector3(hx - 0.07, 0.42, win_mid), _mat.radiator)
	for i in 10:
		var z := -0.5 + i * 0.111
		_box("Fin%d" % i, Vector3(0.012, 0.5, 0.012), Vector3(-0.045, 0.0, z), _mat.radiator, false, 0.0, rad)

	# Curtains and rail.
	_cylinder("CurtainRail", 0.012, 0.012, win_len + 0.7, Vector3(hx - 0.1, WINDOW_Y_MAX + 0.15, win_mid), _mat.metal).rotation_degrees.x = 90.0
	var cur_h := WINDOW_Y_MAX + 0.12
	_box("CurtainNorth", Vector3(0.06, cur_h, 0.38), Vector3(hx - 0.12, cur_h / 2.0 + 0.02, WINDOW_Z_MIN - 0.12), _mat.curtain)
	_box("CurtainSouth", Vector3(0.06, cur_h, 0.38), Vector3(hx - 0.12, cur_h / 2.0 + 0.02, WINDOW_Z_MAX + 0.12), _mat.curtain)


func _door() -> void:
	var hz := DEPTH / 2.0
	var door_x := -1.55
	_box("Door", Vector3(0.84, 2.0, 0.04), Vector3(door_x, 1.0, hz - 0.03), _mat.trim)
	_box("DoorPanelTop", Vector3(0.6, 0.8, 0.01), Vector3(door_x, 1.45, hz - 0.055), _mat.ceiling)
	_box("DoorPanelBottom", Vector3(0.6, 0.7, 0.01), Vector3(door_x, 0.5, hz - 0.055), _mat.ceiling)
	_box("DoorFrameWest", Vector3(0.06, 2.06, 0.03), Vector3(door_x - 0.45, 1.03, hz - 0.015), _mat.trim)
	_box("DoorFrameEast", Vector3(0.06, 2.06, 0.03), Vector3(door_x + 0.45, 1.03, hz - 0.015), _mat.trim)
	_box("DoorFrameTop", Vector3(0.96, 0.06, 0.03), Vector3(door_x, 2.03, hz - 0.015), _mat.trim)
	_box("DoorHandle", Vector3(0.12, 0.02, 0.03), Vector3(door_x + 0.3, 1.0, hz - 0.08), _mat.metal)
	_box("LightSwitch", Vector3(0.08, 0.08, 0.01), Vector3(door_x + 0.62, 1.2, hz - 0.005), _mat.trim)


# --- Lighting --------------------------------------------------------------

func _lighting() -> void:
	# Sunlight coming in through the east window, casting shadows.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 10.0
	add_child(sun)
	sun.look_at_from_position(Vector3(6.0, 4.5, -1.6), Vector3(0.6, 0.0, -0.3), Vector3.UP)

	# Ceiling pendant.
	var pendant_y := HEIGHT - 0.45
	_cylinder("PendantCord", 0.005, 0.005, 0.35, Vector3(0, HEIGHT - 0.175, 0), _mat.black)
	_cylinder("PendantShade", 0.06, 0.2, 0.18, Vector3(0, pendant_y, 0), _mat.shade)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	bulb.mesh = sphere
	bulb.material_override = _mat.bulb
	bulb.position = Vector3(0, pendant_y - 0.06, 0)
	add_child(bulb)
	var ceiling_light := OmniLight3D.new()
	ceiling_light.name = "CeilingLight"
	ceiling_light.light_color = Color(1.0, 0.88, 0.72)
	ceiling_light.light_energy = 1.1
	ceiling_light.omni_range = 6.0
	ceiling_light.position = Vector3(0, pendant_y - 0.12, 0)
	add_child(ceiling_light)


# --- Furniture -------------------------------------------------------------

func _sofa() -> void:
	# Three-seater against the north wall. The patient will sit here.
	var g := _group("Sofa", Vector3(-0.3, 0.0, -DEPTH / 2.0 + 0.48))
	var w := 2.1
	_box("Plinth", Vector3(w, 0.22, 0.9), Vector3(0, 0.16, 0), _mat.sofa, true, 0.0, g)
	_box("Back", Vector3(w, 0.5, 0.22), Vector3(0, 0.52, -0.34), _mat.sofa, true, 0.0, g)
	_box("ArmWest", Vector3(0.2, 0.6, 0.9), Vector3(-w / 2.0 + 0.1, 0.35, 0), _mat.sofa, true, 0.0, g)
	_box("ArmEast", Vector3(0.2, 0.6, 0.9), Vector3(w / 2.0 - 0.1, 0.35, 0), _mat.sofa, true, 0.0, g)
	var seat_w := (w - 0.4) / 3.0
	for i in 3:
		var x := -w / 2.0 + 0.2 + seat_w * (i + 0.5)
		_box("SeatCushion%d" % i, Vector3(seat_w - 0.02, 0.15, 0.64), Vector3(x, 0.345, 0.08), _mat.sofa_cushion, true, 0.0, g)
		var back := _box("BackCushion%d" % i, Vector3(seat_w - 0.02, 0.42, 0.16), Vector3(x, 0.66, -0.17), _mat.sofa_cushion, false, 0.0, g)
		back.rotation_degrees.x = -10.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box("Leg", Vector3(0.05, 0.05, 0.05), Vector3(sx * (w / 2.0 - 0.08), 0.025, sz * 0.38), _mat.wood, false, 0.0, g)
	_blob(Vector2(w + 0.4, 1.3), g.position + Vector3(0, 0, 0.05))

	# Where the patient will sit (used from V0.03 onwards).
	var seat := Marker3D.new()
	seat.name = "PatientSeat"
	seat.position = Vector3(0, 0.42, 0.1)
	g.add_child(seat)


func _side_table_and_lamp() -> void:
	var hz := DEPTH / 2.0
	var t := _group("SideTable", Vector3(1.1, 0.0, -hz + 0.3))
	_box("Top", Vector3(0.45, 0.03, 0.45), Vector3(0, 0.55, 0), _mat.wood, true, 0.0, t)
	_box("Shelf", Vector3(0.41, 0.02, 0.41), Vector3(0, 0.2, 0), _mat.wood, false, 0.0, t)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box("Leg", Vector3(0.03, 0.55, 0.03), Vector3(sx * 0.2, 0.275, sz * 0.2), _mat.wood, false, 0.0, t)
	_cylinder("Mug", 0.04, 0.04, 0.1, Vector3(0.08, 0.615, 0.05), _mat.mug, t)
	_blob(Vector2(0.7, 0.7), t.position)

	# Floor lamp in the north-west corner beside the sofa.
	var lamp := _group("FloorLamp", Vector3(-1.75, 0.0, -hz + 0.3))
	_cylinder("Base", 0.15, 0.16, 0.03, Vector3(0, 0.015, 0), _mat.black, lamp)
	_cylinder("Pole", 0.012, 0.012, 1.45, Vector3(0, 0.75, 0), _mat.metal, lamp)
	_cylinder("Shade", 0.14, 0.22, 0.28, Vector3(0, 1.55, 0), _mat.shade, lamp)
	var light := OmniLight3D.new()
	light.name = "LampLight"
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 0.7
	light.omni_range = 3.0
	light.position = Vector3(0, 1.45, 0)
	lamp.add_child(light)
	_blob(Vector2(0.5, 0.5), lamp.position)


func _coffee_table_and_rug() -> void:
	# Deliberately leaves ~0.9 m in front of the sofa, so there's room to kneel by the patient.
	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	var rug_mesh := BoxMesh.new()
	rug_mesh.size = Vector3(2.4, 0.01, 1.7)
	rug.mesh = rug_mesh
	rug.material_override = _mat.rug
	rug.position = Vector3(-0.3, 0.005, -0.2)
	add_child(rug)

	var t := _group("CoffeeTable", Vector3(-0.3, 0.0, 0.25))
	_box("Top", Vector3(1.0, 0.04, 0.55), Vector3(0, 0.42, 0), _mat.wood_light, true, 0.0, t)
	_box("Shelf", Vector3(0.9, 0.02, 0.45), Vector3(0, 0.12, 0), _mat.wood_light, false, 0.0, t)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box("Leg", Vector3(0.04, 0.4, 0.04), Vector3(sx * 0.46, 0.2, sz * 0.24), _mat.wood_light, false, 0.0, t)
	_blob(Vector2(1.3, 0.85), t.position)


func _armchair() -> void:
	var g := _group("Armchair", Vector3(-WIDTH / 2.0 + 0.5, 0.0, 0.35), 90.0)
	_box("Plinth", Vector3(0.85, 0.22, 0.85), Vector3(0, 0.16, 0), _mat.armchair, true, 0.0, g)
	_box("Back", Vector3(0.85, 0.55, 0.2), Vector3(0, 0.55, -0.33), _mat.armchair, true, 0.0, g)
	_box("ArmA", Vector3(0.16, 0.58, 0.85), Vector3(-0.345, 0.34, 0), _mat.armchair, true, 0.0, g)
	_box("ArmB", Vector3(0.16, 0.58, 0.85), Vector3(0.345, 0.34, 0), _mat.armchair, true, 0.0, g)
	_box("Cushion", Vector3(0.52, 0.14, 0.6), Vector3(0, 0.34, 0.08), _mat.sofa_cushion, false, 0.0, g)
	_blob(Vector2(1.1, 1.1), g.position)


func _tv_unit() -> void:
	var hz := DEPTH / 2.0
	var g := _group("TVUnit", Vector3(0.6, 0.0, hz - 0.25), 180.0)
	_box("Cabinet", Vector3(1.5, 0.45, 0.42), Vector3(0, 0.25, 0), _mat.wood, true, 0.0, g)
	_box("Kick", Vector3(1.46, 0.03, 0.38), Vector3(0, 0.015, 0), _mat.black, false, 0.0, g)
	_box("TVStand", Vector3(0.3, 0.02, 0.2), Vector3(0, 0.485, 0), _mat.black, false, 0.0, g)
	_box("TVNeck", Vector3(0.06, 0.12, 0.04), Vector3(0, 0.55, -0.02), _mat.black, false, 0.0, g)
	_box("TV", Vector3(1.12, 0.65, 0.04), Vector3(0, 0.93, 0), _mat.black, true, 0.0, g)
	_box("Screen", Vector3(1.08, 0.61, 0.005), Vector3(0, 0.93, 0.021), _mat.screen, false, 0.0, g)
	_blob(Vector2(1.8, 0.7), g.position)


func _bookcase() -> void:
	var hx := WIDTH / 2.0
	var g := _group("Bookcase", Vector3(hx - 0.18, 0.0, 1.35), -90.0)
	var w := 0.9
	var h := 1.8
	var d := 0.3
	_box("SideA", Vector3(0.02, h, d), Vector3(-w / 2.0 + 0.01, h / 2.0, 0), _mat.wood, true, 0.0, g)
	_box("SideB", Vector3(0.02, h, d), Vector3(w / 2.0 - 0.01, h / 2.0, 0), _mat.wood, true, 0.0, g)
	_box("BackPanel", Vector3(w, h, 0.01), Vector3(0, h / 2.0, -d / 2.0 + 0.005), _mat.wood, false, 0.0, g)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var book_colours := [Color(0.55, 0.15, 0.12), Color(0.15, 0.3, 0.5), Color(0.2, 0.4, 0.25),
			Color(0.8, 0.7, 0.4), Color(0.3, 0.25, 0.35), Color(0.85, 0.85, 0.8)]
	for s in 5:
		var y := 0.04 + s * 0.42
		_box("Shelf%d" % s, Vector3(w - 0.04, 0.02, d - 0.02), Vector3(0, y, 0), _mat.wood, false, 0.0, g)
		if s == 4:
			break
		var x := -w / 2.0 + 0.04
		while x < w / 2.0 - 0.08:
			var bw := rng.randf_range(0.025, 0.05)
			var bh := rng.randf_range(0.2, 0.32)
			var m := _std(book_colours[rng.randi() % book_colours.size()], 0.7)
			_box("Book", Vector3(bw, bh, rng.randf_range(0.17, 0.22)), Vector3(x + bw / 2.0, y + 0.01 + bh / 2.0, 0.0), m, false, 0.0, g)
			x += bw + 0.003
			if rng.randf() < 0.08:
				x += 0.08
	_blob(Vector2(1.0, 0.5), g.position, -90.0)


func _pictures() -> void:
	var hz := DEPTH / 2.0
	var canvas := [Color(0.35, 0.5, 0.6), Color(0.75, 0.55, 0.35), Color(0.4, 0.55, 0.4)]
	var xs := [-0.95, -0.3, 0.35]
	for i in 3:
		var y := 1.55 if i != 1 else 1.6
		var size := Vector2(0.4, 0.5) if i != 1 else Vector2(0.5, 0.6)
		_box("PictureFrame%d" % i, Vector3(size.x, size.y, 0.03), Vector3(xs[i], y, -hz + 0.02), _mat.black)
		_box("Picture%d" % i, Vector3(size.x - 0.06, size.y - 0.06, 0.005), Vector3(xs[i], y, -hz + 0.037), _std(canvas[i], 0.9))


func _plant() -> void:
	var g := _group("Plant", Vector3(-WIDTH / 2.0 + 0.3, 0.0, -0.85))
	_cylinder("Pot", 0.16, 0.12, 0.32, Vector3(0, 0.16, 0), _mat.pot, g)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 7:
		var leaf := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = rng.randf_range(0.12, 0.18)
		s.height = s.radius * 2.0
		s.radial_segments = 12
		s.rings = 6
		leaf.mesh = s
		leaf.material_override = _mat.leaf
		leaf.position = Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(0.45, 0.85), rng.randf_range(-0.12, 0.12))
		g.add_child(leaf)
	_blob(Vector2(0.55, 0.55), g.position)


# --- Outside ---------------------------------------------------------------

func _outside() -> void:
	# Just enough to make the window look like a window: garden, fence, sky.
	var ox := WIDTH / 2.0 + WALL
	var garden := _box("Garden", Vector3(8.0, 0.1, 14.0), Vector3(ox + 4.0, -0.08, 0), _mat.grass)
	garden.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box("Fence", Vector3(0.05, 1.1, 14.0), Vector3(ox + 7.0, 0.55, 0), _mat.fence)
	_box("Hedge", Vector3(0.8, 1.6, 14.0), Vector3(ox + 7.6, 0.8, 0), _mat.hedge)
	var sky := MeshInstance3D.new()
	sky.name = "Sky"
	var q := QuadMesh.new()
	q.size = Vector2(30.0, 14.0)
	sky.mesh = q
	sky.material_override = _mat.sky
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.position = Vector3(ox + 9.0, 4.0, 0)
	sky.rotation_degrees.y = -90.0
	add_child(sky)
