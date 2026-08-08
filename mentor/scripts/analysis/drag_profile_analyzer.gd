class_name DragProfileAnalyzer
extends RefCounted

## Agrega 8–10 puxadas naturais por mediana/MAD. As classificações são apenas
## rótulos de interface; o pipeline de recomendação consome os scores contínuos.


static func build(metrics_list: Array[GestureMetrics]) -> DragProfile:
	var profile := DragProfile.new()
	profile.sample_count = metrics_list.size()
	if metrics_list.is_empty():
		return profile

	var durations: Array[float] = []
	var lengths: Array[float] = []
	var speeds: Array[float] = []
	var peaks: Array[float] = []
	var initial_speeds: Array[float] = []
	var accelerations: Array[float] = []
	var angles: Array[float] = []
	var tremors: Array[float] = []
	var straightness: Array[float] = []
	var efficiency: Array[float] = []
	var verticality: Array[float] = []
	var corrections: Array[float] = []
	for metrics: GestureMetrics in metrics_list:
		durations.append(metrics.duration_ms)
		lengths.append(metrics.path_length_norm)
		speeds.append(metrics.median_speed)
		peaks.append(metrics.peak_speed)
		initial_speeds.append(metrics.initial_speed)
		accelerations.append(metrics.mean_acceleration)
		angles.append(metrics.principal_angle_deg)
		tremors.append(metrics.tremor_score)
		straightness.append(metrics.straightness)
		efficiency.append(metrics.movement_efficiency)
		verticality.append(metrics.vertical_bias)
		corrections.append(float(metrics.correction_count))

	profile.median_duration_ms = GestureAnalyzer.median(durations)
	profile.median_path_length_norm = GestureAnalyzer.median(lengths)
	profile.median_speed = GestureAnalyzer.median(speeds)
	profile.median_peak_speed = GestureAnalyzer.median(peaks)
	profile.median_initial_speed = GestureAnalyzer.median(initial_speeds)
	profile.median_acceleration = GestureAnalyzer.median(accelerations)
	profile.median_principal_angle_deg = GestureAnalyzer.median(angles)
	profile.drag_length_score = clampf(profile.median_path_length_norm / 0.20, 0.0, 1.0)
	profile.drag_speed_score = clampf(profile.median_speed / 2.5, 0.0, 1.0)
	profile.stability_score = clampf(1.0 - GestureAnalyzer.median(tremors), 0.0, 1.0)
	profile.verticality_score = clampf(GestureAnalyzer.median(verticality), 0.0, 1.0)
	profile.correction_tendency = clampf(GestureAnalyzer.median(corrections) / 4.0, 0.0, 1.0)
	profile.control_score = clampf((
		GestureAnalyzer.median(straightness)
		+ GestureAnalyzer.median(efficiency)
		+ profile.stability_score
		+ (1.0 - profile.correction_tendency)
	) * 0.25, 0.0, 1.0)
	profile.consistency_score = _consistency([lengths, durations, speeds, straightness])
	profile.length_classification = _length_label(profile.median_path_length_norm)
	profile.speed_classification = _speed_label(profile.median_speed)
	profile.control_classification = _control_label(profile.control_score)
	return profile


static func _consistency(series: Array[Array]) -> float:
	var relative_mads: Array[float] = []
	for raw_values: Array in series:
		var values: Array[float] = []
		for value: Variant in raw_values:
			values.append(float(value))
		var center: float = absf(GestureAnalyzer.median(values))
		relative_mads.append(
			GestureAnalyzer.median_absolute_deviation(values) / maxf(center, 0.000001)
		)
	var mean_relative_mad: float = 0.0
	for value: float in relative_mads:
		mean_relative_mad += value
	mean_relative_mad /= float(maxi(relative_mads.size(), 1))
	return clampf(1.0 / (1.0 + mean_relative_mad), 0.0, 1.0)


static func _length_label(value: float) -> StringName:
	if value < 0.045: return &"MUITO CURTA"
	if value < 0.085: return &"CURTA"
	if value < 0.145: return &"MÉDIA"
	if value < 0.22: return &"LONGA"
	return &"MUITO LONGA"


static func _speed_label(value: float) -> StringName:
	if value < 0.45: return &"LENTA"
	if value < 1.15: return &"MÉDIA"
	if value < 2.25: return &"RÁPIDA"
	return &"MUITO RÁPIDA"


static func _control_label(value: float) -> StringName:
	if value < 0.4: return &"BAIXO"
	if value < 0.72: return &"MÉDIO"
	return &"ALTO"
