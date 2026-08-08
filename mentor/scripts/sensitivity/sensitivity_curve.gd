class_name SensitivityCurve
extends RefCounted

const DEFAULT_PATH: String = "res://data/sensitivity_curve.json"

var version: String = "fallback-linear"
var provisional: bool = true
var points: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(200.0, 1.0)]


static func load_from_json(path: String = DEFAULT_PATH) -> SensitivityCurve:
	var curve := SensitivityCurve.new()
	if not FileAccess.file_exists(path):
		push_warning("[Mentor][Sensitivity] LUT ausente; usando fallback linear provisório.")
		return curve
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[Mentor][Sensitivity] Falha ao abrir LUT.")
		return curve
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("[Mentor][Sensitivity] LUT corrompida; usando fallback.")
		return curve
	var data: Dictionary = parsed as Dictionary
	var raw_points: Variant = data.get("points", [])
	if not raw_points is Array or (raw_points as Array).size() < 2:
		push_error("[Mentor][Sensitivity] LUT sem pontos suficientes; usando fallback.")
		return curve

	var loaded_points: Array[Vector2] = []
	for raw_point: Variant in raw_points as Array:
		if not raw_point is Dictionary:
			continue
		var point_data: Dictionary = raw_point as Dictionary
		loaded_points.append(Vector2(
			float(point_data.get("sensitivity", 0.0)),
			float(point_data.get("normalized_gain", 0.0))
		))
	if loaded_points.size() < 2:
		return curve
	loaded_points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	curve.points = loaded_points
	curve.version = str(data.get("version", curve.version))
	curve.provisional = bool(data.get("provisional", true))
	return curve


func sample(sensitivity: float) -> float:
	var clamped_sensitivity: float = clampf(sensitivity, points[0].x, points[-1].x)
	for index: int in range(1, points.size()):
		var right: Vector2 = points[index]
		if clamped_sensitivity <= right.x:
			var left: Vector2 = points[index - 1]
			var weight: float = inverse_lerp(left.x, right.x, clamped_sensitivity)
			return lerpf(left.y, right.y, weight)
	return points[-1].y
