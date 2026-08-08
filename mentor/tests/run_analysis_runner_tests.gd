extends SceneTree

var _failures: int = 0
var _runner: MentorAnalysisRunner


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_runner = root.get_node("AnalysisRunner") as MentorAnalysisRunner
	_runner.begin_analysis(150, 160)
	_runner.set("_config", {
		"warmup_attempts": 1,
		"natural_profile_attempts": 1,
		"baseline_attempts": 1,
		"attempts_per_candidate": 1,
		"validation_attempts": 1,
	})
	var visited: Dictionary = {}
	var guard: int = 0
	while _runner.current_phase != MentorAnalysisRunner.Phase.RESULTS and guard < 100:
		visited[_runner.get_phase_name()] = true
		var optimum: int = 160 if _runner.current_test.scope_mode == &"RED_DOT" else 145
		_runner.submit_attempt(_attempt_for_candidate(_runner.candidate_sensitivity, optimum))
		guard += 1
	_expect(guard < 100, "runner deve alcançar RESULTS sem loop infinito")
	for required: String in [
		"WARMUP", "NATURAL_PROFILE", "STATIC_BASELINE", "GENERAL_COARSE",
		"GENERAL_FINE", "GENERAL_VALIDATION", "RED_DOT_COARSE", "RED_DOT_FINE",
		"RED_DOT_VALIDATION"
	]:
		_expect(visited.has(required), "runner deve visitar fase %s" % required)
	_expect(_runner.general_recommendation != null, "runner deve gerar recomendação Geral")
	_expect(_runner.red_dot_recommendation != null, "runner deve gerar recomendação Red Dot independente")
	_expect(_runner.general_recommendation.validated, "Geral deve passar pela bateria de validação")
	_expect(_runner.red_dot_recommendation.validated, "Red Dot deve passar pela bateria de validação")
	_expect(not _runner.saved_session_path.is_empty(), "sessão final deve ser persistida")
	_expect(FileAccess.file_exists(_runner.saved_session_path), "JSON de sessão deve existir")
	var payload: Dictionary = _runner.build_session_payload()
	_expect(payload.has("all_candidates"), "sessão deve conter todos os candidates")
	_expect(payload.has("drag_profile"), "sessão deve conter perfil motor")
	var results_scene: PackedScene = load("res://scenes/analysis/analysis_results.tscn") as PackedScene
	var results_view: Control = results_scene.instantiate() as Control
	root.add_child(results_view)
	await process_frame
	_expect((results_view.get_node("%GeneralValue") as Label).text != "—", "tela final deve renderizar Geral")
	_expect((results_view.get_node("%RedDotValue") as Label).text != "—", "tela final deve renderizar Red Dot")
	results_view.queue_free()
	await process_frame
	await _test_red_dot_arena_mode()
	if _failures == 0:
		print("[Mentor][Tests] Runner General/Red Dot, validação e persistência passaram.")
		quit(0)
	else:
		push_error("[Mentor][Tests] Analysis runner falhou em %d ponto(s)." % _failures)
		quit(1)


func _attempt_for_candidate(candidate: int, optimum: int) -> CalibrationAttempt:
	var error: float = 0.008 + absf(float(candidate - optimum)) / 850.0
	var attempt := CalibrationAttempt.new()
	attempt.gesture = GestureAttempt.new()
	attempt.gesture.add_sample(TouchSample.create(0, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.0, 0.0))
	attempt.gesture.add_sample(TouchSample.create(200_000, Vector2(0, -80), Vector2(0.5, 0.4), Vector2(0, -80), Vector2(0, -0.1), 0.5, 0.5))
	attempt.metrics = GestureAnalyzer.analyze(attempt.gesture)
	attempt.metrics.straightness = 0.94
	attempt.metrics.movement_efficiency = 0.94
	attempt.metrics.tremor_score = 0.05
	attempt.metrics.peak_speed = 1.5
	attempt.endpoint_error_length_norm = error
	attempt.endpoint_error_norm = Vector2(error * 0.25, error * 0.75)
	attempt.entered_head = error < 0.05
	attempt.time_to_head_ms = 155.0 + error * 300.0
	attempt.time_on_head_ms = 70.0
	attempt.classification = CalibrationAttempt.Classification.GOOD
	attempt.tracking_metrics = TrackingMetrics.new()
	attempt.tracking_metrics.tracking_error_median = error
	attempt.tracking_metrics.time_near_chest_ratio = clampf(1.0 - error * 8.0, 0.0, 1.0)
	attempt.tracking_metrics.direction_change_delay_ms = 130.0 + error * 1000.0
	return attempt


func _test_red_dot_arena_mode() -> void:
	var definition := MentorTestDefinition.new()
	definition.test_type = &"MOVING_HEADSHOT"
	definition.scope_mode = &"RED_DOT"
	definition.candidate_sensitivity = 120
	definition.target_motion = TargetMotionController.MotionMode.STRAFE_CONTINUOUS
	_runner.active = true
	_runner.current_phase = MentorAnalysisRunner.Phase.RED_DOT_COARSE
	_runner.current_test = definition
	_runner.candidate_sensitivity = 120
	var packed: PackedScene = load("res://scenes/calibration/calibration_arena.tscn") as PackedScene
	var arena: Node = packed.instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var overlay: RedDotOverlay = arena.get_node("HUDLayer/HUD/RedDotOverlay") as RedDotOverlay
	var camera: Camera3D = (arena.get_node("PlayerCalibrationRig") as AimCameraController).get_camera()
	_expect(overlay.visible, "fase RED_DOT deve ativar visual próprio")
	_expect(is_equal_approx(camera.fov, 55.0), "fase RED_DOT deve usar FOV experimental próprio")
	_expect(float(arena.get("virtual_sensitivity")) == 120.0, "Red Dot deve aplicar candidate realmente testado")
	arena.queue_free()
	_runner.cancel_analysis()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("[Mentor][Tests] %s" % message)
