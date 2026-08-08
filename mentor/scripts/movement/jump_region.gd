class_name JumpRegion
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
	var radius: float = minf(size.x, size.y) * 0.47
	draw_circle(center, radius, Color(0.22, 0.29, 0.38, 0.34 if not active else 0.65))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.65, 0.78, 0.9, 0.8), 2.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-20.0, 6.0), "PULO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
