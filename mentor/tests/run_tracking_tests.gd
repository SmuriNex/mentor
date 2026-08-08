extends SceneTree

var _failures: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_perfect_tracking()
	_test_bias_corrections_and_peak()
	_test_direction_change_delay()
	if _failures == 0:
		print("[Mentor][Tests] Tracking normalizado, bias e reversal delay passaram.")
		quit(0)
	else:
		push_error("[Mentor][Tests] Tracking falhou em %d ponto(s)." % _failures)
		quit(1)


func _test_perfect_tracking() -> void:
	var samples: Array[TrackingSample] = []
	for index: int in range(6):
		samples.append(TrackingSample.create(index * 100_000, Vector2(0.005, 0.002), 1.0))
	var metrics: TrackingMetrics = TrackingAnalyzer.analyze(samples, 0.03)
	_expect(metrics.tracking_error_mean < 0.006, "tracking alinhado deve ter erro médio baixo")
	_expect(is_equal_approx(metrics.time_near_chest_ratio, 1.0), "tracking alinhado deve ficar perto do peito")
	_expect(is_equal_approx(metrics.tracking_stability, 1.0), "erro constante deve ser estável")


func _test_bias_corrections_and_peak() -> void:
	var errors: Array[float] = [0.04, 0.03, -0.02, -0.05, 0.01]
	var samples: Array[TrackingSample] = []
	for index: int in range(errors.size()):
		samples.append(TrackingSample.create(index * 100_000, Vector2(errors[index], 0.0), 1.0))
	var metrics: TrackingMetrics = TrackingAnalyzer.analyze(samples, 0.025)
	_expect(metrics.tracking_error_peak >= 0.05, "peak deve preservar maior erro")
	_expect(metrics.correction_count == 2, "cruzamentos horizontais devem contar correções")
	_expect(metrics.time_near_chest_ratio > 0.0 and metrics.time_near_chest_ratio < 1.0, "near ratio deve usar duração")


func _test_direction_change_delay() -> void:
	var samples: Array[TrackingSample] = [
		TrackingSample.create(0, Vector2(0.00, 0.0), 1.0),
		TrackingSample.create(100_000, Vector2(0.01, 0.0), 1.0),
		TrackingSample.create(200_000, Vector2(0.02, 0.0), -1.0),
		TrackingSample.create(300_000, Vector2(0.025, 0.0), -1.0),
		TrackingSample.create(400_000, Vector2(0.035, 0.0), -1.0),
	]
	var metrics: TrackingMetrics = TrackingAnalyzer.analyze(samples)
	_expect(metrics.direction_change_count == 1, "reversal deve produzir uma reação medida")
	_expect(is_equal_approx(metrics.direction_change_delay_ms, 100.0), "delay deve partir do timestamp da reversão")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("[Mentor][Tests] %s" % message)
