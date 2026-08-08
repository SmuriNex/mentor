class_name CandidateScorer
extends RefCounted

const CONFIG_PATH: String = "res://data/recommendation_weights.json"


static func score(
	result: SensitivityCandidateResult,
	attempts: Array[CalibrationAttempt]
) -> float:
	var config: Dictionary = _load_config()
	var internal: Dictionary = config.get("headshot_internal", {}) as Dictionary
	var endpoint_score: float = 1.0 - clampf(result.median_endpoint_error / 0.08, 0.0, 1.0)
	var time_score: float = 0.0
	if result.median_time_to_head >= 0.0:
		time_score = 1.0 - clampf((result.median_time_to_head - 90.0) / 510.0, 0.0, 1.0)
	var correction_score: float = 1.0 - clampf(result.median_corrections / 4.0, 0.0, 1.0)
	var straightness_score: float = _median_attempt_value(attempts, &"straightness")
	var stability_score: float = 1.0 - _median_attempt_value(attempts, &"tremor_score")
	var internal_score: float = _weighted({
		"endpoint_accuracy": endpoint_score,
		"consistency": result.consistency,
		"time_to_head": time_score,
		"overshoot_control": 1.0 - result.overshoot_rate,
		"corrections": correction_score,
		"straightness": straightness_score,
		"stability": stability_score,
	}, internal)

	var tracking_score: float = 1.0 - clampf(result.median_tracking_error / 0.12, 0.0, 1.0)
	var reversal_score: float = 0.5
	if result.direction_change_delay >= 0.0:
		reversal_score = 1.0 - clampf(result.direction_change_delay / 650.0, 0.0, 1.0)
	var moving_bonus: float = clampf((
		tracking_score + result.time_near_chest_ratio + result.head_contact_rate
	) / 3.0, 0.0, 1.0)

	var grouped: Dictionary = {}
	for attempt: CalibrationAttempt in attempts:
		var scenario: String = String(attempt.test_type)
		if not grouped.has(scenario):
			grouped[scenario] = []
		(grouped[scenario] as Array).append(_attempt_accuracy(attempt))
	result.scenario_scores = {
		"STATIC_HEADSHOT": _group_or_default(grouped, "STATIC_HEADSHOT", internal_score),
		"MOVING_HEADSHOT": _group_or_default(grouped, "MOVING_HEADSHOT", (internal_score + moving_bonus) * 0.5),
		"PLAYER_TARGET_MOVING": _group_or_default(grouped, "PLAYER_TARGET_MOVING", (internal_score + moving_bonus) * 0.5),
		"TRACKING": tracking_score,
		"REVERSAL": reversal_score,
		"CAMERA_CONTROL": _group_or_default(grouped, "CAMERA_FLICK_TEST", internal_score),
	}
	result.overall_score = _weighted(
		result.scenario_scores,
		config.get("scenario_weights", {}) as Dictionary
	)
	return result.overall_score


static func _attempt_accuracy(attempt: CalibrationAttempt) -> float:
	if attempt.classification == CalibrationAttempt.Classification.INVALID:
		return 0.0
	return 1.0 - clampf(attempt.endpoint_error_length_norm / 0.08, 0.0, 1.0)


static func _median_attempt_value(attempts: Array[CalibrationAttempt], property: StringName) -> float:
	var values: Array[float] = []
	for attempt: CalibrationAttempt in attempts:
		if attempt.metrics != null:
			values.append(float(attempt.metrics.get(property)))
	return GestureAnalyzer.median(values)


static func _group_or_default(grouped: Dictionary, key: String, fallback: float) -> float:
	if not grouped.has(key):
		return fallback
	var values: Array[float] = []
	for value: Variant in grouped[key] as Array:
		values.append(float(value))
	return GestureAnalyzer.median(values)


static func _weighted(scores: Dictionary, weights: Dictionary) -> float:
	var total: float = 0.0
	var weight_total: float = 0.0
	for key: String in weights:
		var weight: float = float(weights[key])
		total += float(scores.get(key, 0.0)) * weight
		weight_total += weight
	return clampf(total / maxf(weight_total, 0.000001), 0.0, 1.0)


static func _load_config() -> Dictionary:
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
