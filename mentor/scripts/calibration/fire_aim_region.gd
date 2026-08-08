class_name FireAimRegion
extends Control

var active: bool = false:
	set(value):
		active = value
		queue_redraw()


func contains_viewport_point(point: Vector2) -> bool:
	var center: Vector2 = global_position + size * 0.5
	return center.distance_to(point) <= minf(size.x, size.y) * 0.5


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.48
	var fill := Color(0.10, 0.50, 0.67, 0.36)
	var border := Color(0.25, 0.78, 0.95, 0.9)
	if active:
		fill = Color(0.15, 0.68, 0.86, 0.62)
		border = Color(0.68, 0.94, 1.0, 1.0)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 64, border, 3.0, true)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-18.0, 6.0),
		"FIRE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		15,
		Color.WHITE
	)
