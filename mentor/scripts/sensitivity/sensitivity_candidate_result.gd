class_name SensitivityCandidateResult
extends RefCounted

var sensitivity: int = 100
var attempt_count: int = 0
var median_endpoint_error: float = 0.0
var median_vertical_error: float = 0.0
var median_horizontal_error: float = 0.0
var overshoot_rate: float = 0.0
var undershoot_rate: float = 0.0
var head_contact_rate: float = 0.0
var median_time_to_head: float = -1.0
var median_time_on_head: float = 0.0
var median_tracking_error: float = 0.0
var time_near_chest_ratio: float = 0.0
var direction_change_delay: float = -1.0
var median_corrections: float = 0.0
var median_drag_distance: float = 0.0
var median_peak_speed: float = 0.0
var consistency: float = 0.0
var outlier_count: int = 0
var overall_score: float = 0.0
var scenario_scores: Dictionary = {}
var eliminated: bool = false


static func from_attempts(
	new_sensitivity: int,
	attempts: Array[CalibrationAttempt]
) -> SensitivityCandidateResult:
	var result := SensitivityCandidateResult.new()
	result.sensitivity = clampi(new_sensitivity, 0, 200)
	result.attempt_count = attempts.size()
	if attempts.is_empty():
		return result

	var endpoint: Array[float] = []
	var vertical: Array[float] = []
	var horizontal: Array[float] = []
	var times_to_head: Array[float] = []
	var times_on_head: Array[float] = []
	var tracking_errors: Array[float] = []
	var near_ratios: Array[float] = []
	var direction_delays: Array[float] = []
	var corrections: Array[float] = []
	var drag_distances: Array[float] = []
	var peak_speeds: Array[float] = []
	var valid_attempts: Array[CalibrationAttempt] = []
	var overshoots: int = 0
	var undershoots: int = 0
	var head_contacts: int = 0
	for attempt: CalibrationAttempt in attempts:
		if attempt.classification == CalibrationAttempt.Classification.INVALID or attempt.metrics == null:
			result.outlier_count += 1
			continue
		valid_attempts.append(attempt)
		endpoint.append(attempt.endpoint_error_length_norm)
		vertical.append(absf(attempt.endpoint_error_norm.y))
		horizontal.append(absf(attempt.endpoint_error_norm.x))
		corrections.append(float(attempt.metrics.correction_count))
		drag_distances.append(attempt.metrics.path_length_norm)
		peak_speeds.append(attempt.metrics.peak_speed)
		times_on_head.append(attempt.time_on_head_ms)
		if attempt.time_to_head_ms >= 0.0:
			times_to_head.append(attempt.time_to_head_ms)
		if attempt.entered_head:
			head_contacts += 1
		if attempt.classification == CalibrationAttempt.Classification.OVERSHOOT:
			overshoots += 1
		elif attempt.classification == CalibrationAttempt.Classification.UNDERSHOOT:
			undershoots += 1
		if attempt.tracking_metrics != null:
			tracking_errors.append(attempt.tracking_metrics.tracking_error_median)
			near_ratios.append(attempt.tracking_metrics.time_near_chest_ratio)
			if attempt.tracking_metrics.direction_change_delay_ms >= 0.0:
				direction_delays.append(attempt.tracking_metrics.direction_change_delay_ms)

	var valid_count: int = valid_attempts.size()
	if valid_count == 0:
		return result
	result.median_endpoint_error = GestureAnalyzer.median(endpoint)
	result.median_vertical_error = GestureAnalyzer.median(vertical)
	result.median_horizontal_error = GestureAnalyzer.median(horizontal)
	result.overshoot_rate = float(overshoots) / float(valid_count)
	result.undershoot_rate = float(undershoots) / float(valid_count)
	result.head_contact_rate = float(head_contacts) / float(valid_count)
	result.median_time_to_head = GestureAnalyzer.median(times_to_head) if not times_to_head.is_empty() else -1.0
	result.median_time_on_head = GestureAnalyzer.median(times_on_head)
	result.median_tracking_error = GestureAnalyzer.median(tracking_errors)
	result.time_near_chest_ratio = GestureAnalyzer.median(near_ratios)
	result.direction_change_delay = GestureAnalyzer.median(direction_delays) if not direction_delays.is_empty() else -1.0
	result.median_corrections = GestureAnalyzer.median(corrections)
	result.median_drag_distance = GestureAnalyzer.median(drag_distances)
	result.median_peak_speed = GestureAnalyzer.median(peak_speeds)
	result.consistency = CalibrationSessionSummary.from_attempts(valid_attempts).consistency_score
	result.outlier_count += _count_robust_outliers(endpoint)
	return result


func to_dictionary() -> Dictionary:
	return {
		"sensitivity": sensitivity,
		"attempt_count": attempt_count,
		"median_endpoint_error": median_endpoint_error,
		"median_vertical_error": median_vertical_error,
		"median_horizontal_error": median_horizontal_error,
		"overshoot_rate": overshoot_rate,
		"undershoot_rate": undershoot_rate,
		"head_contact_rate": head_contact_rate,
		"median_time_to_head": median_time_to_head,
		"median_time_on_head": median_time_on_head,
		"median_tracking_error": median_tracking_error,
		"time_near_chest_ratio": time_near_chest_ratio,
		"direction_change_delay": direction_change_delay,
		"median_corrections": median_corrections,
		"median_drag_distance": median_drag_distance,
		"median_peak_speed": median_peak_speed,
		"consistency": consistency,
		"outlier_count": outlier_count,
		"overall_score": overall_score,
		"scenario_scores": scenario_scores.duplicate(true),
		"eliminated": eliminated,
	}


static func _count_robust_outliers(values: Array[float]) -> int:
	if values.size() < 4:
		return 0
	var center: float = GestureAnalyzer.median(values)
	var mad: float = GestureAnalyzer.median_absolute_deviation(values)
	if mad <= 0.000001:
		return 0
	var count: int = 0
	for value: float in values:
		if absf(value - center) > mad * 3.5:
			count += 1
	return count
