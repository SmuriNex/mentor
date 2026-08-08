extends SceneTree

const TouchSampleScript = preload("res://scripts/gestures/touch_sample.gd")
const GestureAttemptScript = preload("res://scripts/gestures/gesture_attempt.gd")
const GestureAnalyzerScript = preload("res://scripts/analysis/gesture_analyzer.gd")
const SensitivityCurveScript = preload("res://scripts/sensitivity/sensitivity_curve.gd")

var _failures: int = 0


func _init() -> void:
	_test_straight_line()
	_test_median_and_mad()
	_test_overshoot()
	_test_j_shape()
	_test_sensitivity_curve()
	if _failures == 0:
		print("[Mentor][Tests] Todos os testes matemáticos passaram.")
		quit(0)
	else:
		push_error("[Mentor][Tests] %d teste(s) falharam." % _failures)
		quit(1)


func _test_straight_line() -> void:
	var attempt: GestureAttempt = _make_attempt([
		Vector2(0.5, 0.7),
		Vector2(0.5, 0.6),
		Vector2(0.5, 0.5),
		Vector2(0.5, 0.4),
		Vector2(0.5, 0.3),
	])
	var metrics: GestureMetrics = GestureAnalyzerScript.analyze(attempt)
	_expect_near(metrics.path_length_norm, 0.4, 0.0001, "path length da linha")
	_expect_near(metrics.straightness, 1.0, 0.0001, "straightness da linha")
	_expect_near(metrics.principal_angle_deg, -90.0, 0.001, "ângulo vertical")


func _test_median_and_mad() -> void:
	var values: Array[float] = [1.0, 2.0, 3.0, 100.0]
	_expect_near(GestureAnalyzerScript.median(values), 2.5, 0.0001, "mediana robusta")
	_expect_near(GestureAnalyzerScript.median_absolute_deviation(values), 1.0, 0.0001, "MAD robusto")


func _test_overshoot() -> void:
	var attempt: GestureAttempt = _make_attempt([
		Vector2(0.5, 0.7),
		Vector2(0.5, 0.45),
		Vector2(0.5, 0.25),
	])
	attempt.metadata["target_norm"] = Vector2(0.5, 0.3)
	attempt.metadata["target_radius"] = 0.03
	var metrics: GestureMetrics = GestureAnalyzerScript.analyze(attempt)
	_expect_near(metrics.overshoot, 0.05, 0.0001, "overshoot normalizado")
	_expect_near(metrics.undershoot, 0.0, 0.0001, "undershoot ausente")


func _test_j_shape() -> void:
	var line: GestureAttempt = _make_attempt([
		Vector2(0.5, 0.7), Vector2(0.5, 0.6), Vector2(0.5, 0.5), Vector2(0.5, 0.4)
	])
	var j_gesture: GestureAttempt = _make_attempt([
		Vector2(0.38, 0.70),
		Vector2(0.44, 0.70),
		Vector2(0.50, 0.67),
		Vector2(0.54, 0.57),
		Vector2(0.55, 0.42),
	])
	var line_score: float = GestureAnalyzerScript.analyze(line).j_shape_score
	var j_score: float = GestureAnalyzerScript.analyze(j_gesture).j_shape_score
	_expect_true(j_score > line_score, "J deve pontuar acima da linha reta")


func _test_sensitivity_curve() -> void:
	var curve: SensitivityCurve = SensitivityCurveScript.load_from_json()
	_expect_near(curve.sample(100.0), 0.5, 0.0001, "interpolação da LUT")
	_expect_near(curve.sample(250.0), 1.0, 0.0001, "clamp superior da LUT")


func _make_attempt(normalized_points: Array[Vector2]) -> GestureAttempt:
	var attempt := GestureAttemptScript.new()
	attempt.viewport_size = Vector2(1000.0, 1000.0)
	var timestamp_usec: int = 1_000_000
	var previous: Vector2 = normalized_points[0]
	for point: Vector2 in normalized_points:
		var delta_norm: Vector2 = point - previous
		var sample := TouchSampleScript.create(
			timestamp_usec,
			point * attempt.viewport_size,
			point,
			delta_norm * attempt.viewport_size,
			delta_norm,
			delta_norm.length() * 10_000.0,
			delta_norm.length() * 10.0
		)
		attempt.add_sample(sample)
		previous = point
		timestamp_usec += 100_000
	return attempt


func _expect_near(actual: float, expected: float, tolerance: float, label: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures += 1
		push_error("[Mentor][Tests] %s: esperado %.6f, recebido %.6f" % [label, expected, actual])


func _expect_true(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("[Mentor][Tests] %s" % label)
