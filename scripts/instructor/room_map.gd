extends Control
## Top-down sketch of the living room with the learner, patient and Ken.
## North (the sofa wall) at the top, east (window) on the right.

const W := 4.6
const D := 4.0

var _learner := Vector3(-1.1, 1.6, 1.3)
var _yaw := PI
var _have_learner := false

# Furniture as [centre x, centre z, width x, depth z, name]
const FURNITURE := [
	[-0.3, -1.52, 2.1, 0.9, "Sofa"],
	[-0.3, 0.25, 1.0, 0.55, "Coffee table"],
	[-1.8, 0.35, 0.85, 0.85, "Armchair"],
	[0.6, 1.75, 1.4, 0.4, "TV"],
]
const PEOPLE := [[-0.3, -1.42, "Joan", Color(0.95, 0.55, 0.55)], [0.95, -0.55, "Ken", Color(0.75, 0.75, 0.95)]]


func set_learner(p: Vector3, yaw: float) -> void:
	_learner = p
	_yaw = yaw
	_have_learner = true
	queue_redraw()


func _to_px(x: float, z: float, scale: float, origin: Vector2) -> Vector2:
	return origin + Vector2(x + W / 2.0, z + D / 2.0) * scale


func _draw() -> void:
	var scale := minf((size.x - 20.0) / W, (size.y - 20.0) / D)
	var origin := (size - Vector2(W, D) * scale) / 2.0
	var font := get_theme_default_font()
	# floor and walls
	draw_rect(Rect2(origin, Vector2(W, D) * scale), Color(0.2, 0.18, 0.16))
	draw_rect(Rect2(origin, Vector2(W, D) * scale), Color(0.75, 0.75, 0.75), false, 3.0)
	# window (east) and door (south-west)
	draw_line(_to_px(2.3, -1.2, scale, origin), _to_px(2.3, 0.6, scale, origin), Color(0.6, 0.85, 1.0), 6.0)
	draw_line(_to_px(-1.6, 2.0, scale, origin), _to_px(-0.8, 2.0, scale, origin), Color(0.9, 0.75, 0.4), 6.0)
	draw_string(font, _to_px(1.6, -1.3, scale, origin), "window", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.85, 1.0))
	draw_string(font, _to_px(-1.6, 1.9, scale, origin), "door", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.75, 0.4))
	for f in FURNITURE:
		var r := Rect2(_to_px(f[0] - f[2] / 2.0, f[1] - f[3] / 2.0, scale, origin), Vector2(f[2], f[3]) * scale)
		draw_rect(r, Color(0.32, 0.34, 0.36))
		draw_string(font, r.position + Vector2(4, 14), f[4], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8))
	for p in PEOPLE:
		var c := _to_px(p[0], p[1], scale, origin)
		draw_circle(c, 9.0, p[3])
		draw_string(font, c + Vector2(12, 5), p[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, p[3])
	# learner: dot, facing arrow, crouched marker
	var lp := _to_px(_learner.x, _learner.z, scale, origin)
	var dir := Vector2(sin(_yaw), cos(_yaw))
	draw_line(lp, lp + dir * 34.0, Color(0.5, 1.0, 0.6), 3.0)
	draw_circle(lp, 10.0, Color(0.5, 1.0, 0.6))
	var height := "kneeling/crouched" if _learner.y < 1.15 else "standing"
	draw_string(font, lp + Vector2(14, -10), "Learner (" + height + ")" + ("" if _have_learner else " - waiting"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 1.0, 0.6))
