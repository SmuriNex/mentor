extends SceneTree

var _failures: int = 0


func _init() -> void:
	_test_candidate_aggregation_and_score()
	_test_coarse_and_fine_search()
	_test_early_elimination_and_validation()
	if _failures == 0:
		print("[Mentor][Tests] Candidate scoring e busca adaptativa passaram.")
		quit(0)
	else:
		push_error("[Mentor][Tests] Search falhou em %d ponto(s)." % _failures)
		quit(1)


func _test_candidate_aggregation_and_score() -> void:
	var accurate_attempts: Array[CalibrationAttempt] = []
	var inaccurate_attempts: Array[CalibrationAttempt] = []
	for index: int in range(6):
		accurate_attempts.append(_attempt(0.012, 160.0, true, index % 2, &"MOVING_HEADSHOT"))
		inaccurate_attempts.append(_attempt(0.075, 100.0, false, 3, &"MOVING_HEADSHOT"))
	var accurate := SensitivityCandidateResult.from_attempts(145, accurate_attempts)
	var inaccurate := SensitivityCandidateResult.from_attempts(190, inaccurate_attempts)
	CandidateScorer.score(accurate, accurate_attempts)
	CandidateScorer.score(inaccurate, inaccurate_attempts)
	_expect(accurate.attempt_count == 6, "candidate deve agregar grupo de tentativas")
	_expect(accurate.median_endpoint_error < inaccurate.median_endpoint_error, "mediana deve preservar precisão")
	_expect(accurate.overall_score > inaccurate.overall_score, "precisão/controle devem vencer só velocidade")


func _test_coarse_and_fine_search() -> void:
	var search := SensitivitySearchController.new(SensitivitySearchController.Scope.GENERAL)
	_expect(search.build_coarse_candidates() == PackedInt32Array([50, 90, 130, 170, 200]), "coarse sem atual deve vir do JSON")
	_expect(search.build_coarse_candidates(160) == PackedInt32Array([130, 145, 160, 175, 190]), "coarse deve cercar sensibilidade atual")
	search.register_result(_result(140, 0.91, 9, 0.92))
	search.register_result(_result(150, 0.90, 9, 0.91))
	search.register_result(_result(180, 0.62, 9, 0.75))
	var fine: PackedInt32Array = search.build_fine_candidates()
	_expect(fine.has(145), "fine search deve testar midpoint dos melhores")
	_expect(fine.has(135) and fine.has(155), "fine search deve testar vizinhos configuráveis")
	var recommendation: SensitivityRecommendation = search.finalize_recommendation()
	_expect(recommendation.recommended == 150, "scores equivalentes devem escolher centro da faixa")
	_expect(recommendation.range_min == 140 and recommendation.range_max == 150, "faixa deve incluir candidates equivalentes")


func _test_early_elimination_and_validation() -> void:
	var search := SensitivitySearchController.new(SensitivitySearchController.Scope.RED_DOT)
	var bad := _result(200, 0.2, 3, 0.2)
	bad.overshoot_rate = 1.0
	search.register_result(bad)
	_expect(bad.eliminated, "três overshoots extremos podem eliminar cedo")
	var good := _result(120, 0.88, 12, 0.9)
	search.register_result(good)
	var recommendation: SensitivityRecommendation = search.finalize_recommendation()
	var validation := _result(120, 0.84, 4, 0.88)
	_expect(search.validate_recommendation(recommendation, validation), "validação próxima do baseline deve passar")
	_expect(recommendation.validated, "resultado deve guardar status VALIDATED")


func _attempt(
	error: float,
	time_to_head: float,
	head_contact: bool,
	corrections: int,
	test_type: StringName
) -> CalibrationAttempt:
	var attempt := CalibrationAttempt.new()
	attempt.gesture = GestureAttempt.new()
	attempt.metrics = GestureMetrics.new()
	attempt.metrics.duration_ms = 260.0
	attempt.metrics.path_length_norm = 0.11
	attempt.metrics.peak_speed = 1.8
	attempt.metrics.straightness = 0.93
	attempt.metrics.movement_efficiency = 0.93
	attempt.metrics.correction_count = corrections
	attempt.metrics.tremor_score = 0.08
	attempt.endpoint_error_length_norm = error
	attempt.endpoint_error_norm = Vector2(error * 0.25, error * 0.75)
	attempt.entered_head = head_contact
	attempt.time_to_head_ms = time_to_head if head_contact else -1.0
	attempt.time_on_head_ms = 75.0 if head_contact else 0.0
	attempt.classification = CalibrationAttempt.Classification.GOOD if head_contact else CalibrationAttempt.Classification.OVERSHOOT
	attempt.test_type = test_type
	attempt.tracking_metrics = TrackingMetrics.new()
	attempt.tracking_metrics.tracking_error_median = error
	attempt.tracking_metrics.time_near_chest_ratio = 0.85 if head_contact else 0.2
	attempt.tracking_metrics.direction_change_delay_ms = 140.0 if head_contact else 520.0
	return attempt


func _result(sensitivity: int, score: float, attempts: int, consistency: float) -> SensitivityCandidateResult:
	var result := SensitivityCandidateResult.new()
	result.sensitivity = sensitivity
	result.overall_score = score
	result.attempt_count = attempts
	result.consistency = consistency
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("[Mentor][Tests] %s" % message)
