class_name CalibrationSessionSummary
extends RefCounted

var valid_attempts: int = 0
var classification_counts: Dictionary = {}
var median_duration_ms: float = 0.0
var median_time_to_head_ms: float = -1.0
var median_drag_distance_norm: float = 0.0
var median_peak_speed: float = 0.0
var median_endpoint_error_norm: float = 0.0
var median_vertical_error_norm: float = 0.0
var median_horizontal_error_norm: float = 0.0
var median_straightness: float = 0.0
var total_corrections: int = 0
var consistency_score: float = 0.0
var overshoot_rate: float = 0.0
var undershoot_rate: float = 0.0


static func from_attempts(attempts: Array[CalibrationAttempt]) -> CalibrationSessionSummary:
	var summary := CalibrationSessionSummary.new()
	var durations: Array[float] = []
	var times_to_head: Array[float] = []
	var distances: Array[float] = []
	var peaks: Array[float] = []
	var endpoint_errors: Array[float] = []
	var vertical_errors: Array[float] = []
	var horizontal_errors: Array[float] = []
	var straightness_values: Array[float] = []

	for classification_name: String in CalibrationAttempt.Classification.keys():
		summary.classification_counts[classification_name] = 0

	for attempt: CalibrationAttempt in attempts:
		if attempt.classification == CalibrationAttempt.Classification.INVALID or attempt.metrics == null:
			continue
		summary.valid_attempts += 1
		var name: String = attempt.classification_name()
		summary.classification_counts[name] = int(summary.classification_counts.get(name, 0)) + 1
		durations.append(attempt.metrics.duration_ms)
		distances.append(attempt.metrics.path_length_norm)
		peaks.append(attempt.metrics.peak_speed)
		endpoint_errors.append(attempt.endpoint_error_length_norm)
		vertical_errors.append(absf(attempt.endpoint_error_norm.y))
		horizontal_errors.append(absf(attempt.endpoint_error_norm.x))
		straightness_values.append(attempt.metrics.straightness)
		summary.total_corrections += attempt.metrics.correction_count
		if attempt.time_to_head_ms >= 0.0:
			times_to_head.append(attempt.time_to_head_ms)

	if summary.valid_attempts == 0:
		return summary
	summary.median_duration_ms = GestureAnalyzer.median(durations)
	summary.median_time_to_head_ms = GestureAnalyzer.median(times_to_head) if not times_to_head.is_empty() else -1.0
	summary.median_drag_distance_norm = GestureAnalyzer.median(distances)
	summary.median_peak_speed = GestureAnalyzer.median(peaks)
	summary.median_endpoint_error_norm = GestureAnalyzer.median(endpoint_errors)
	summary.median_vertical_error_norm = GestureAnalyzer.median(vertical_errors)
	summary.median_horizontal_error_norm = GestureAnalyzer.median(horizontal_errors)
	summary.median_straightness = GestureAnalyzer.median(straightness_values)
	summary.overshoot_rate = float(summary.classification_counts["OVERSHOOT"]) / float(summary.valid_attempts)
	summary.undershoot_rate = float(summary.classification_counts["UNDERSHOOT"]) / float(summary.valid_attempts)

	# Cada feature contribui pela dispersão robusta relativa MAD/mediana. A média
	# dessas dispersões é convertida para 0..1 por 1/(1+d): zero dispersão gera
	# consistência 1 e valores muito dispersos se aproximam de zero.
	var dispersions: Array[float] = [
		_relative_mad(endpoint_errors),
		_relative_mad(distances),
		_relative_mad(durations),
		_relative_mad(peaks),
	]
	if not times_to_head.is_empty():
		dispersions.append(_relative_mad(times_to_head))
	var mean_dispersion: float = 0.0
	for dispersion: float in dispersions:
		mean_dispersion += dispersion
	mean_dispersion /= float(maxi(dispersions.size(), 1))
	summary.consistency_score = clampf(1.0 / (1.0 + mean_dispersion), 0.0, 1.0)
	return summary


func to_dictionary() -> Dictionary:
	return {
		"valid_attempts": valid_attempts,
		"classification_counts": classification_counts.duplicate(true),
		"median_duration_ms": median_duration_ms,
		"median_time_to_head_ms": median_time_to_head_ms,
		"median_drag_distance_norm": median_drag_distance_norm,
		"median_peak_speed": median_peak_speed,
		"median_endpoint_error_norm": median_endpoint_error_norm,
		"median_vertical_error_norm": median_vertical_error_norm,
		"median_horizontal_error_norm": median_horizontal_error_norm,
		"median_straightness": median_straightness,
		"total_corrections": total_corrections,
		"consistency_score": consistency_score,
		"overshoot_rate": overshoot_rate,
		"undershoot_rate": undershoot_rate,
	}


static func _relative_mad(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var center: float = absf(GestureAnalyzer.median(values))
	return GestureAnalyzer.median_absolute_deviation(values) / maxf(center, 0.000001)
