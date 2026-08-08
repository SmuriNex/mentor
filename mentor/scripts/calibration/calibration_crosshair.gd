class_name CalibrationCrosshair
extends Control

var target_region: CalibrationHitRegion.Region = CalibrationHitRegion.Region.NONE:
	set(value):
		target_region = value
		queue_redraw()


func _draw() -> void:
	var color := Color.WHITE
	if target_region == CalibrationHitRegion.Region.HEAD:
		color = Color(0.96, 0.25, 0.30, 1.0)
	elif target_region == CalibrationHitRegion.Region.CHEST \
	or target_region == CalibrationHitRegion.Region.BODY:
		color = Color(1.0, 0.76, 0.20, 1.0)
	var center: Vector2 = size * 0.5
	var gap: float = 5.0
	var length: float = 10.0
	draw_circle(center, 2.2, color)
	draw_line(center + Vector2(gap, 0), center + Vector2(gap + length, 0), color, 2.0, true)
	draw_line(center - Vector2(gap, 0), center - Vector2(gap + length, 0), color, 2.0, true)
	draw_line(center + Vector2(0, gap), center + Vector2(0, gap + length), color, 2.0, true)
	draw_line(center - Vector2(0, gap), center - Vector2(0, gap + length), color, 2.0, true)
