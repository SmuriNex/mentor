class_name GestureAnalyzer
extends RefCounted

## Análise puramente matemática. Nenhum filtro altera GestureAttempt.samples.

const DIRECTION_CHANGE_DEGREES: float = 35.0
const TARGET_RADIUS_DEFAULT: float = 0.035
const TREMOR_REFERENCE_RATIO: float = 0.10
const EPSILON: float = 0.000001


static func analyze(attempt: GestureAttempt) -> GestureMetrics:
	var metrics := GestureMetrics.new()
	if attempt.samples.size() < 2:
		return metrics

	var first: TouchSample = attempt.samples[0]
	var last: TouchSample = attempt.samples[-1]
	metrics.duration_ms = float(last.timestamp_usec - first.timestamp_usec) / 1000.0
	metrics.net_displacement_px = last.position_px - first.position_px
	metrics.net_displacement_norm = last.position_norm - first.position_norm
	metrics.horizontal_displacement_norm = metrics.net_displacement_norm.x
	metrics.vertical_displacement_norm = metrics.net_displacement_norm.y

	var speeds: Array[float] = []
	var accelerations: Array[float] = []
	var previous_speed: float = 0.0
	var previous_direction: Vector2 = Vector2.ZERO
	var net_direction: Vector2 = metrics.net_displacement_norm.normalized()
	var previous_projection_sign: float = 0.0
	var perpendicular_deviation_sum: float = 0.0
	var signed_turn_sum: float = 0.0
	var absolute_turn_sum: float = 0.0

	for index: int in range(1, attempt.samples.size()):
		var sample: TouchSample = attempt.samples[index]
		var previous_sample: TouchSample = attempt.samples[index - 1]
		var delta_px: Vector2 = sample.position_px - previous_sample.position_px
		var delta_norm: Vector2 = sample.position_norm - previous_sample.position_norm
		metrics.path_length_px += delta_px.length()
		metrics.path_length_norm += delta_norm.length()

		var elapsed_seconds: float = maxf(
			float(sample.timestamp_usec - previous_sample.timestamp_usec) / 1_000_000.0,
			EPSILON
		)
		var speed: float = delta_norm.length() / elapsed_seconds
		if delta_norm.length_squared() > EPSILON:
			speeds.append(speed)

		if index > 1:
			var acceleration: float = (speed - previous_speed) / elapsed_seconds
			accelerations.append(acceleration)
			metrics.peak_acceleration = maxf(metrics.peak_acceleration, absf(acceleration))

		var direction: Vector2 = delta_norm.normalized()
		if not previous_direction.is_zero_approx() and not direction.is_zero_approx():
			var turn_radians: float = previous_direction.angle_to(direction)
			var turn_degrees: float = absf(rad_to_deg(turn_radians))
			if turn_degrees >= DIRECTION_CHANGE_DEGREES:
				metrics.direction_changes += 1
			signed_turn_sum += turn_radians
			absolute_turn_sum += absf(turn_radians)

		if not net_direction.is_zero_approx() and not delta_norm.is_zero_approx():
			var projection: float = delta_norm.dot(net_direction)
			var projection_sign: float = signf(projection)
			if previous_projection_sign != 0.0 and projection_sign != previous_projection_sign:
				metrics.correction_count += 1
				metrics.correction_distance += delta_norm.length()
			previous_projection_sign = projection_sign

		perpendicular_deviation_sum += _distance_to_gesture_axis(
			sample.position_norm,
			first.position_norm,
			last.position_norm
		)
		previous_speed = speed
		if not direction.is_zero_approx():
			previous_direction = direction

	var direct_distance: float = metrics.net_displacement_norm.length()
	metrics.straightness = clampf(
		direct_distance / maxf(metrics.path_length_norm, EPSILON),
		0.0,
		1.0
	)
	metrics.movement_efficiency = metrics.straightness
	metrics.principal_angle_deg = rad_to_deg(metrics.net_displacement_norm.angle())
	var axis_total: float = absf(metrics.net_displacement_norm.x) + absf(metrics.net_displacement_norm.y)
	metrics.horizontal_bias = absf(metrics.net_displacement_norm.x) / maxf(axis_total, EPSILON)
	metrics.vertical_bias = absf(metrics.net_displacement_norm.y) / maxf(axis_total, EPSILON)

	if not speeds.is_empty():
		metrics.mean_speed = _mean(speeds)
		metrics.median_speed = median(speeds)
		metrics.peak_speed = _maximum(speeds)
		metrics.initial_speed = speeds[0]
		metrics.final_speed = speeds[-1]
	if not accelerations.is_empty():
		metrics.mean_acceleration = _mean(accelerations)
		var negative_accelerations: Array[float] = []
		for acceleration: float in accelerations:
			if acceleration < 0.0:
				negative_accelerations.append(absf(acceleration))
		metrics.deceleration = _mean(negative_accelerations)

	var sample_divisor: float = float(maxi(attempt.samples.size() - 2, 1))
	var mean_deviation: float = perpendicular_deviation_sum / sample_divisor
	metrics.tremor_score = clampf(
		mean_deviation / maxf(direct_distance * TREMOR_REFERENCE_RATIO, EPSILON),
		0.0,
		1.0
	)

	# Curvas coerentes acumulam rotação assinada em um sentido. Mudanças que se
	# anulam indicam zigue-zague/tremor e reduzem o score de forma natural.
	var curve_consistency: float = absf(signed_turn_sum) / maxf(absolute_turn_sum, EPSILON)
	var curve_amount: float = clampf(absolute_turn_sum / PI, 0.0, 1.0)
	metrics.half_moon_score = clampf(curve_consistency * curve_amount, 0.0, 1.0)
	metrics.j_shape_score = _calculate_j_score(
		attempt,
		curve_consistency,
		metrics.vertical_bias,
		metrics.horizontal_bias
	)

	_apply_target_metrics(attempt, metrics)
	return metrics


static func median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	var middle: int = sorted_values.size() / 2
	if sorted_values.size() % 2 == 0:
		return (sorted_values[middle - 1] + sorted_values[middle]) * 0.5
	return sorted_values[middle]


static func median_absolute_deviation(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var center: float = median(values)
	var deviations: Array[float] = []
	for value: float in values:
		deviations.append(absf(value - center))
	return median(deviations)


static func _apply_target_metrics(attempt: GestureAttempt, metrics: GestureMetrics) -> void:
	if not attempt.metadata.has("target_norm"):
		return
	var target_value: Variant = attempt.metadata["target_norm"]
	if not target_value is Vector2:
		return
	var target: Vector2 = target_value as Vector2
	var radius: float = float(attempt.metadata.get("target_radius", TARGET_RADIUS_DEFAULT))
	var endpoint: Vector2 = attempt.samples[-1].position_norm
	metrics.endpoint_error = endpoint.distance_to(target)
	metrics.overshoot = maxf(target.y - endpoint.y, 0.0)
	metrics.undershoot = maxf(endpoint.y - target.y, 0.0)

	for sample: TouchSample in attempt.samples:
		if sample.position_norm.distance_to(target) <= radius:
			metrics.time_to_target_ms = float(
				sample.timestamp_usec - attempt.samples[0].timestamp_usec
			) / 1000.0
			break


static func _distance_to_gesture_axis(point: Vector2, start: Vector2, end: Vector2) -> float:
	var axis: Vector2 = end - start
	var axis_length_squared: float = axis.length_squared()
	if axis_length_squared <= EPSILON:
		return point.distance_to(start)
	var projection: float = clampf((point - start).dot(axis) / axis_length_squared, 0.0, 1.0)
	return point.distance_to(start + axis * projection)


static func _calculate_j_score(
	attempt: GestureAttempt,
	curve_consistency: float,
	vertical_bias: float,
	horizontal_bias: float
) -> float:
	if attempt.samples.size() < 4:
		return 0.0
	var split_index: int = maxi(attempt.samples.size() * 2 / 3, 1)
	var start: Vector2 = attempt.samples[0].position_norm
	var split: Vector2 = attempt.samples[split_index].position_norm
	var finish: Vector2 = attempt.samples[-1].position_norm
	var early_horizontal: float = absf(split.x - start.x)
	var late_vertical: float = absf(finish.y - split.y)
	var phase_balance: float = minf(early_horizontal, late_vertical) / maxf(
		maxf(early_horizontal, late_vertical),
		EPSILON
	)
	var axis_mix: float = 1.0 - absf(vertical_bias - horizontal_bias)
	return clampf(curve_consistency * phase_balance * axis_mix, 0.0, 1.0)


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


static func _maximum(values: Array[float]) -> float:
	var result: float = 0.0
	for value: float in values:
		result = maxf(result, value)
	return result
