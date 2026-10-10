@tool
class_name StardustIcon
extends Control
## Four-pointed star glyph for the stardust counter (no texture asset).

const POINTS := 4
## Inner vertices sit at this share of the outer radius.
const INNER_RATIO := 0.38

@export var color: Color = Color(1.0, 0.85, 0.4)
@export var outline_color: Color = Color(0.25, 0.15, 0.0, 0.9)


func _draw() -> void:
	var center := size * 0.5
	var outer := minf(size.x, size.y) * 0.5
	var star := PackedVector2Array()
	for i in POINTS * 2:
		var radius := outer if i % 2 == 0 else outer * INNER_RATIO
		var angle := -PI * 0.5 + PI * float(i) / POINTS
		star.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(star, color)
	star.append(star[0])
	draw_polyline(star, outline_color, 2.0, true)
