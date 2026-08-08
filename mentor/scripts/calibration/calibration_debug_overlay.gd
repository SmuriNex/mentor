class_name CalibrationDebugOverlay
extends Control

var head_position: Vector2 = Vector2.ZERO
var endpoint_center: Vector2 = Vector2.ZERO
var show_endpoint_error: bool = false
var trail_points: PackedVector2Array = PackedVector2Array()


func update_projection(head: Vector2, center: Vector2, show_error: bool) -> void:
	head_position = head
	endpoint_center = center
	show_endpoint_error = show_error
	queue_redraw()


func append_trail_point(point: Vector2) -> void:
	trail_points.append(point)
	queue_redraw()


func clear_trail() -> void:
	trail_points.clear()
	queue_redraw()


func _draw() -> void:
	if trail_points.size() >= 2:
		draw_polyline(trail_points, Color(0.20, 0.72, 0.92, 0.65), 2.0, true)
	draw_circle(head_position, 8.0, Color(0.96, 0.24, 0.34, 0.85), false, 2.0, true)
	draw_circle(endpoint_center, 4.0, Color(0.25, 0.86, 0.55, 0.9))
	if show_endpoint_error:
		draw_line(endpoint_center, head_position, Color(1.0, 0.72, 0.18, 0.9), 2.0, true)
