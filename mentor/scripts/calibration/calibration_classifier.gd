class_name CalibrationClassifier
extends RefCounted


static func classify(attempt: CalibrationAttempt, thresholds: Dictionary) -> CalibrationAttempt.Classification:
	if attempt.gesture == null or not attempt.gesture.is_valid:
		return CalibrationAttempt.Classification.INVALID

	var perfect_radius: float = float(thresholds.get("perfect_radius_norm", 0.012))
	var good_radius: float = float(thresholds.get("good_radius_norm", 0.030))
	var vertical_band: float = float(thresholds.get("vertical_band_norm", 0.035))
	var lateral_threshold: float = float(thresholds.get("lateral_threshold_norm", 0.045))
	var error_x: float = attempt.endpoint_error_norm.x
	var error_y: float = attempt.endpoint_error_norm.y

	if attempt.endpoint_error_length_norm <= perfect_radius:
		return CalibrationAttempt.Classification.PERFECT
	if attempt.ended_target_region == CalibrationHitRegion.Region.HEAD \
	or attempt.endpoint_error_length_norm <= good_radius:
		return CalibrationAttempt.Classification.GOOD
	if absf(error_x) >= lateral_threshold and absf(error_y) <= vertical_band:
		return CalibrationAttempt.Classification.LATERAL_MISS
	if attempt.entered_head and error_y < -good_radius:
		return CalibrationAttempt.Classification.OVERSHOOT
	if error_y < -good_radius:
		return CalibrationAttempt.Classification.OVERSHOOT
	if error_y > good_radius:
		return CalibrationAttempt.Classification.UNDERSHOOT
	if absf(error_x) >= lateral_threshold:
		return CalibrationAttempt.Classification.LATERAL_MISS
	return CalibrationAttempt.Classification.GOOD
