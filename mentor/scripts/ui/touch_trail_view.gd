class_name TouchTrailView
extends Control

const GRID_COLOR: Color = Color(0.15, 0.18, 0.23, 0.45)
const TRAIL_COLOR: Color = Color(0.13, 0.68, 0.88, 1.0)
const START_COLOR: Color = Color(0.24, 0.82, 0.48, 1.0)
const END_COLOR: Color = Color(0.96, 0.66, 0.18, 1.0)
const PEAK_COLOR: Color = Color(0.92, 0.28, 0.35, 1.0)

var _points: PackedVector2Array = PackedVector2Array()
var _speeds: PackedFloat32Array = PackedFloat32Array()


func set_trajectory(points: PackedVector2Array, speeds: PackedFloat32Array) -> void:
	_points = points
	_speeds = speeds
	queue_redraw()


func clear_trajectory() -> void:
	_points.clear()
	_speeds.clear()
	queue_redraw()


func _draw() -> void:
	_draw_grid()
	if _points.is_empty():
		_draw_empty_hint()
		return
	if _points.size() >= 2:
		draw_polyline(_points, TRAIL_COLOR, 4.0, true)
	draw_circle(_points[0], 8.0, START_COLOR)
	draw_circle(_points[-1], 8.0, END_COLOR)
	var peak_index: int = _find_peak_speed_index()
	if peak_index >= 0 and peak_index < _points.size():
		draw_circle(_points[peak_index], 5.0, PEAK_COLOR)


func _draw_grid() -> void:
	for column: int in range(1, 10):
		var x: float = size.x * float(column) / 10.0
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRID_COLOR, 1.0)
	for row: int in range(1, 6):
		var y: float = size.y * float(row) / 6.0
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID_COLOR, 1.0)


func _draw_empty_hint() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, 42.0, Color(0.13, 0.16, 0.20, 0.65), false, 2.0, true)
	draw_line(center - Vector2(22, 0), center + Vector2(22, 0), GRID_COLOR, 2.0)
	draw_line(center - Vector2(0, 22), center + Vector2(0, 22), GRID_COLOR, 2.0)


func _find_peak_speed_index() -> int:
	if _speeds.is_empty():
		return -1
	var peak_index: int = 0
	var peak_speed: float = _speeds[0]
	for index: int in range(1, _speeds.size()):
		if _speeds[index] > peak_speed:
			peak_speed = _speeds[index]
			peak_index = index
	return peak_index
