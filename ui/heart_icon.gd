@tool
class_name HeartIcon
extends Control
## A heart drawn from the classic parametric curve (no texture asset).

const CURVE_POINTS := 48
## The parametric heart spans x in [-16, 16] and y in [-17, 12].
const CURVE_HALF_WIDTH := 16.0
const CURVE_TOP := 12.0
const CURVE_BOTTOM := -17.0

@export var filled: bool = true:
	set(value):
		filled = value
		queue_redraw()
@export var fill_color: Color = Color(1.0, 0.32, 0.4)
@export var empty_color: Color = Color(1.0, 1.0, 1.0, 0.22)
@export var outline_color: Color = Color(0.15, 0.05, 0.08, 0.9)
@export var outline_width: float = 2.0


func _draw() -> void:
	var points := PackedVector2Array()
	var scale_x := size.x * 0.5 / CURVE_HALF_WIDTH
	var scale_y := size.y / (CURVE_TOP - CURVE_BOTTOM)
	for i in CURVE_POINTS:
		var t := TAU * float(i) / CURVE_POINTS
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		points.append(Vector2(size.x * 0.5 + x * scale_x, (CURVE_TOP - y) * scale_y))
	draw_colored_polygon(points, fill_color if filled else empty_color)
	points.append(points[0])
	draw_polyline(points, outline_color, outline_width, true)
