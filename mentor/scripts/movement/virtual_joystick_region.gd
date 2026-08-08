class_name VirtualJoystickRegion
extends Control

@export_range(30.0, 240.0, 1.0) var radius_px: float = 90.0

var active: bool = false
var origin_px: Vector2 = Vector2.ZERO
var current_px: Vector2 = Vector2.ZERO
var value: Vector2 = Vector2.ZERO


func contains_viewport_point(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


func begin(point: Vector2) -> void:
	active = true
	origin_px = point
	current_px = point
	value = Vector2.ZERO
	queue_redraw()


func update_drag(point: Vector2) -> Vector2:
	current_px = point
	value = ((point - origin_px) / maxf(radius_px, 1.0)).limit_length(1.0)
	queue_redraw()
	return value


func finish() -> void:
	active = false
	value = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var local_origin: Vector2 = origin_px - global_position
	var local_knob: Vector2 = current_px - global_position
	draw_circle(local_origin, radius_px, Color(0.15, 0.35, 0.48, 0.16))
	draw_arc(local_origin, radius_px, 0.0, TAU, 48, Color(0.4, 0.75, 0.9, 0.42), 2.0)
	draw_circle(local_knob, 24.0, Color(0.55, 0.85, 0.98, 0.55))
