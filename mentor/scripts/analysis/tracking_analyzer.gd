class_name TrackingAnalyzer
extends RefCounted

const DEFAULT_NEAR_RADIUS_NORM: float = 0.035
const SIGN_DEADZONE_NORM: float = 0.002
const CORRECTION_EPSILON_NORM: float = 0.0002


static func analyze(
	samples: Array[TrackingSample],
	near_radius_norm: float = DEFAULT_NEAR_RADIUS_NORM
) -> TrackingMetrics:
	var result := TrackingMetrics.new()
	result.sample_count = samples.size()
	if samples.is_empty():
		return result

	var error_lengths: Array[float] = []
	var horizontal_errors: Array[float] = []
	var weighted_near_time: float = 0.0
	var total_time: float = 0.0
	for index: int in range(samples.size()):
		var sample: TrackingSample = samples[index]
		error_lengths.append(sample.error_norm.length())
		horizontal_errors.append(sample.error_norm.x)
		if index + 1 < samples.size():
			var interval: float = maxf(
				float(samples[index + 1].timestamp_usec - sample.timestamp_usec) / 1_000_000.0,
				0.0
			)
			total_time += interval
			if sample.error_norm.length() <= near_radius_norm:
				weighted_near_time += interval

	result.tracking_error_mean = _mean(error_lengths)
	result.tracking_error_median = _median(error_lengths)
	result.tracking_error_peak = _maximum(error_lengths)
	result.horizontal_bias = _mean(horizontal_errors)
	result.time_near_chest_ratio = (
		weighted_near_time / total_time if total_time > 0.0
		else float(error_lengths[0] <= near_radius_norm)
	)
	var error_mad: float = _mad(error_lengths, result.tracking_error_median)
	# Estabilidade 1 representa pouca dispersão ao redor do erro mediano. O raio
	# de proximidade vira a escala, mantendo a métrica comparável entre resoluções.
	result.tracking_stability = clampf(
		1.0 - error_mad / maxf(near_radius_norm, 0.000001), 0.0, 1.0
	)
	result.correction_count = _count_horizontal_corrections(horizontal_errors)
	var delay_data: Dictionary = _direction_change_delays(samples)
	result.direction_change_count = int(delay_data.get("count", 0))
	result.direction_change_delay_ms = float(delay_data.get("median_ms", -1.0))
	return result


static func _count_horizontal_corrections(errors: Array[float]) -> int:
	var count: int = 0
	var previous_sign: float = 0.0
	for error: float in errors:
		var current_sign: float = 0.0 if absf(error) <= SIGN_DEADZONE_NORM else signf(error)
		if current_sign != 0.0 and previous_sign != 0.0 and current_sign != previous_sign:
			count += 1
		if current_sign != 0.0:
			previous_sign = current_sign
	return count


static func _direction_change_delays(samples: Array[TrackingSample]) -> Dictionary:
	var delays_ms: Array[float] = []
	for index: int in range(1, samples.size()):
		var previous_direction: float = samples[index - 1].target_direction_x
		var new_direction: float = samples[index].target_direction_x
		if previous_direction == 0.0 or new_direction == 0.0 or previous_direction == new_direction:
			continue
		var change_time: int = samples[index].timestamp_usec
		for response_index: int in range(index + 1, samples.size()):
			var error_delta: float = (
				samples[response_index].error_norm.x
				- samples[response_index - 1].error_norm.x
			)
			# error = alvo - mira. Depois de uma reversão, uma correção adequada
			# move a mira na nova direção e faz o erro variar no sentido oposto.
			# O produto negativo expressa isso sem regras especiais para esquerda
			# e direita. O limiar evita chamar ruído subpixel de reação humana.
			if error_delta * new_direction < -CORRECTION_EPSILON_NORM:
				delays_ms.append(float(
					samples[response_index].timestamp_usec - change_time
				) / 1000.0)
				break
	return {
		"count": delays_ms.size(),
		"median_ms": _median(delays_ms) if not delays_ms.is_empty() else -1.0,
	}


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sum: float = 0.0
	for value: float in values:
		sum += value
	return sum / float(values.size())


static func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var middle: int = sorted.size() / 2
	if sorted.size() % 2 == 0:
		return (sorted[middle - 1] + sorted[middle]) * 0.5
	return sorted[middle]


static func _mad(values: Array[float], median_value: float) -> float:
	var deviations: Array[float] = []
	for value: float in values:
		deviations.append(absf(value - median_value))
	return _median(deviations)


static func _maximum(values: Array[float]) -> float:
	var maximum: float = 0.0
	for value: float in values:
		maximum = maxf(maximum, value)
	return maximum
