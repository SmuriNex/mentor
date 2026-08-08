class_name MentorAnalysisRunner
extends Node

signal phase_changed(phase: Phase)
signal test_changed(definition: MentorTestDefinition)
signal analysis_completed()

enum Phase {
	INTRO,
	WARMUP,
	NATURAL_PROFILE,
	STATIC_BASELINE,
	GENERAL_COARSE,
	GENERAL_FINE,
	GENERAL_VALIDATION,
	RED_DOT_COARSE,
	RED_DOT_FINE,
	RED_DOT_VALIDATION,
	RESULTS,
}

const CONFIG_PATH: String = "res://data/analysis_flow.json"

var current_phase: Phase = Phase.INTRO
var current_test: MentorTestDefinition
var candidate_sensitivity: int = 100
var attempt_count: int = 0
var progress: float = 0.0
var current_general: int = -1
var current_red_dot: int = -1
var drag_profile: DragProfile
var general_recommendation: SensitivityRecommendation
var red_dot_recommendation: SensitivityRecommendation
var active: bool = false
var saved_session_path: String = ""

var _config: Dictionary = {}
var _general_search: SensitivitySearchController
var _red_dot_search: SensitivitySearchController
var _candidate_order := PackedInt32Array()
var _candidate_index: int = 0
var _attempt_in_candidate: int = 0
var _phase_attempts: Array[CalibrationAttempt] = []
var _natural_metrics: Array[GestureMetrics] = []
var _all_attempts: Array[CalibrationAttempt] = []
var _all_results: Array[SensitivityCandidateResult] = []
var _validation_retry_count: int = 0


func _ready() -> void:
	_config = _load_config()


func begin_analysis(new_current_general: int = -1, new_current_red_dot: int = -1) -> void:
	_config = _load_config()
	current_general = clampi(new_current_general, -1, 200)
	current_red_dot = clampi(new_current_red_dot, -1, 200)
	_general_search = SensitivitySearchController.new(SensitivitySearchController.Scope.GENERAL)
	_red_dot_search = SensitivitySearchController.new(SensitivitySearchController.Scope.RED_DOT)
	_natural_metrics.clear()
	_all_attempts.clear()
	_all_results.clear()
	general_recommendation = null
	red_dot_recommendation = null
	saved_session_path = ""
	active = true
	_session_manager().call("start_session")
	_enter_simple_phase(Phase.WARMUP)


func has_active_analysis() -> bool:
	return active and current_phase != Phase.RESULTS


func cancel_analysis() -> void:
	active = false
	current_phase = Phase.INTRO
	current_test = null


func submit_attempt(attempt: CalibrationAttempt) -> bool:
	if not active or current_phase in [Phase.INTRO, Phase.RESULTS]:
		return false
	if attempt.classification == CalibrationAttempt.Classification.INVALID:
		return false
	attempt.test_type = current_test.test_type
	attempt.virtual_sensitivity = float(candidate_sensitivity)
	_all_attempts.append(attempt)
	attempt_count += 1
	match current_phase:
		Phase.WARMUP:
			if attempt_count >= int(_config.get("warmup_attempts", 5)):
				_enter_simple_phase(Phase.NATURAL_PROFILE)
		Phase.NATURAL_PROFILE:
			_natural_metrics.append(attempt.metrics)
			if attempt_count >= int(_config.get("natural_profile_attempts", 10)):
				drag_profile = DragProfileAnalyzer.build(_natural_metrics)
				_enter_simple_phase(Phase.STATIC_BASELINE)
		Phase.STATIC_BASELINE:
			if attempt_count >= int(_config.get("baseline_attempts", 5)):
				_start_search_phase(Phase.GENERAL_COARSE)
		Phase.GENERAL_COARSE, Phase.GENERAL_FINE, Phase.RED_DOT_COARSE, Phase.RED_DOT_FINE:
			_register_search_attempt(attempt)
		Phase.GENERAL_VALIDATION, Phase.RED_DOT_VALIDATION:
			_register_validation_attempt(attempt)
		_:
			pass
	_update_progress()
	return true


func get_phase_name() -> String:
	return Phase.keys()[current_phase]


func get_step_label() -> String:
	var visible_steps: Dictionary = {
		Phase.WARMUP: "Aquecimento",
		Phase.NATURAL_PROFILE: "Perfil natural",
		Phase.STATIC_BASELINE: "Linha de base",
		Phase.GENERAL_COARSE: "Análise Geral 1/3",
		Phase.GENERAL_FINE: "Análise Geral 2/3",
		Phase.GENERAL_VALIDATION: "Validação Geral",
		Phase.RED_DOT_COARSE: "Análise Ponto Vermelho 1/3",
		Phase.RED_DOT_FINE: "Análise Ponto Vermelho 2/3",
		Phase.RED_DOT_VALIDATION: "Validação Ponto Vermelho",
		Phase.RESULTS: "Concluído",
	}
	return str(visible_steps.get(current_phase, "Preparação"))


func get_instruction() -> String:
	if current_test == null:
		return "Prepare-se"
	match current_test.test_type:
		&"NATURAL_DRAG_PROFILE": return "Faça a puxada naturalmente, sem tentar corrigir o teste"
		&"TRACKING": return "Acompanhe o peito e faça a puxada quando estiver confortável"
		&"MOVING_HEADSHOT": return "Acompanhe o alvo em movimento e puxe para a cabeça"
		&"PLAYER_TARGET_MOVING": return "Use o joystick, acompanhe o alvo e faça a puxada"
		&"REVERSAL": return "Acompanhe as trocas de direção e puxe para a cabeça"
		_: return "Mire no peito, pressione FIRE e puxe para a cabeça"


func build_session_payload() -> Dictionary:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var candidate_payload: Array[Dictionary] = []
	for result: SensitivityCandidateResult in _all_results:
		candidate_payload.append(result.to_dictionary())
	var payload: Dictionary = {
		"session_id": str(_session_manager().get("active_session_id")),
		"date": Time.get_datetime_string_from_system(true),
		"app_version": str(_app_state().get("app_version")),
		"algorithm_version": str(_app_state().get("algorithm_version")),
		"sensitivity_curve_version": "provisional-linear-1",
		"device": {"os": OS.get_name(), "model": OS.get_model_name()},
		"viewport": [viewport_size.x, viewport_size.y],
		"dpi": DisplayServer.screen_get_dpi(),
		"current_general": current_general,
		"current_red_dot": current_red_dot,
		"drag_profile": drag_profile.to_dictionary() if drag_profile != null else {},
		"all_candidates": candidate_payload,
		"general_recommendation": general_recommendation.to_dictionary() if general_recommendation != null else {},
		"red_dot_recommendation": red_dot_recommendation.to_dictionary() if red_dot_recommendation != null else {},
		"validation_results": {
			"general": general_recommendation.validation_score if general_recommendation != null else 0.0,
			"red_dot": red_dot_recommendation.validation_score if red_dot_recommendation != null else 0.0,
		},
	}
	if bool(_app_state().get("developer_mode")):
		var raw_attempts: Array[Dictionary] = []
		for attempt: CalibrationAttempt in _all_attempts:
			raw_attempts.append(attempt.to_dictionary(true))
		payload["raw_attempts"] = raw_attempts
	return payload


func _enter_simple_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	attempt_count = 0
	_phase_attempts.clear()
	candidate_sensitivity = current_general if current_general >= 0 else 100
	if new_phase == Phase.NATURAL_PROFILE:
		current_test = _definition(&"NATURAL_DRAG_PROFILE", TargetMotionController.MotionMode.STATIONARY, &"GENERAL")
	elif new_phase == Phase.STATIC_BASELINE:
		current_test = _definition(&"STATIC_HEADSHOT", TargetMotionController.MotionMode.STATIONARY, &"GENERAL")
	else:
		current_test = _definition(&"WARMUP", TargetMotionController.MotionMode.STATIONARY, &"GENERAL")
	phase_changed.emit(current_phase)
	test_changed.emit(current_test)
	_update_progress()


func _start_search_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	attempt_count = 0
	_attempt_in_candidate = 0
	_candidate_index = 0
	_phase_attempts.clear()
	var search: SensitivitySearchController = _search_for_phase(new_phase)
	if new_phase in [Phase.GENERAL_COARSE, Phase.RED_DOT_COARSE]:
		var current: int = current_general if new_phase == Phase.GENERAL_COARSE else current_red_dot
		_candidate_order = search.build_coarse_candidates(current)
	else:
		_candidate_order = search.build_fine_candidates()
	if _candidate_order.is_empty():
		_finish_search_phase()
		return
	_blind_shuffle(_candidate_order)
	_configure_current_candidate_test()
	phase_changed.emit(current_phase)


func _register_search_attempt(attempt: CalibrationAttempt) -> void:
	_phase_attempts.append(attempt)
	_attempt_in_candidate += 1
	var per_candidate: int = int(_config.get("attempts_per_candidate", 3))
	if _attempt_in_candidate < per_candidate:
		_configure_current_candidate_test()
		return
	var result := SensitivityCandidateResult.from_attempts(candidate_sensitivity, _phase_attempts)
	CandidateScorer.score(result, _phase_attempts)
	_search_for_phase(current_phase).register_result(result)
	_all_results.append(result)
	_phase_attempts.clear()
	_attempt_in_candidate = 0
	_candidate_index += 1
	if _candidate_index >= _candidate_order.size():
		_finish_search_phase()
	else:
		_configure_current_candidate_test()


func _finish_search_phase() -> void:
	match current_phase:
		Phase.GENERAL_COARSE: _start_search_phase(Phase.GENERAL_FINE)
		Phase.GENERAL_FINE:
			general_recommendation = _general_search.finalize_recommendation()
			_start_validation_phase(Phase.GENERAL_VALIDATION, general_recommendation)
		Phase.RED_DOT_COARSE: _start_search_phase(Phase.RED_DOT_FINE)
		Phase.RED_DOT_FINE:
			red_dot_recommendation = _red_dot_search.finalize_recommendation()
			_start_validation_phase(Phase.RED_DOT_VALIDATION, red_dot_recommendation)


func _start_validation_phase(new_phase: Phase, recommendation: SensitivityRecommendation) -> void:
	current_phase = new_phase
	attempt_count = 0
	_attempt_in_candidate = 0
	_phase_attempts.clear()
	_validation_retry_count = 0
	candidate_sensitivity = recommendation.recommended
	_configure_validation_test()
	phase_changed.emit(current_phase)


func _register_validation_attempt(attempt: CalibrationAttempt) -> void:
	_phase_attempts.append(attempt)
	_attempt_in_candidate += 1
	if _attempt_in_candidate < int(_config.get("validation_attempts", 4)):
		_configure_validation_test()
		return
	var result := SensitivityCandidateResult.from_attempts(candidate_sensitivity, _phase_attempts)
	CandidateScorer.score(result, _phase_attempts)
	_all_results.append(result)
	if current_phase == Phase.GENERAL_VALIDATION:
		var general_passed: bool = _general_search.validate_recommendation(general_recommendation, result)
		if not general_passed and _retry_validation(_general_search, general_recommendation):
			return
		_start_search_phase(Phase.RED_DOT_COARSE)
	else:
		var red_dot_passed: bool = _red_dot_search.validate_recommendation(red_dot_recommendation, result)
		if not red_dot_passed and _retry_validation(_red_dot_search, red_dot_recommendation):
			return
		_complete_analysis()


func _retry_validation(
	search: SensitivitySearchController,
	recommendation: SensitivityRecommendation
) -> bool:
	if _validation_retry_count >= int(_config.get("validation_max_retries", 1)):
		return false
	var alternative: int = search.best_alternative(recommendation.recommended)
	if alternative == recommendation.recommended:
		return false
	_validation_retry_count += 1
	recommendation.recommended = alternative
	recommendation.range_min = mini(recommendation.range_min, alternative)
	recommendation.range_max = maxi(recommendation.range_max, alternative)
	candidate_sensitivity = alternative
	attempt_count = 0
	_attempt_in_candidate = 0
	_phase_attempts.clear()
	_configure_validation_test()
	return true


func _configure_current_candidate_test() -> void:
	candidate_sensitivity = _candidate_order[_candidate_index]
	var scenarios: Array[StringName] = []
	if current_phase in [Phase.GENERAL_COARSE, Phase.RED_DOT_COARSE]:
		scenarios.append(&"STATIC_HEADSHOT")
		scenarios.append(&"MOVING_HEADSHOT")
		scenarios.append(&"TRACKING")
	else:
		scenarios.append(&"MOVING_HEADSHOT")
		scenarios.append(&"PLAYER_TARGET_MOVING")
		scenarios.append(&"REVERSAL")
	var scenario: StringName = scenarios[_attempt_in_candidate % scenarios.size()]
	current_test = _definition_for_scenario(scenario, _scope_name())
	test_changed.emit(current_test)


func _configure_validation_test() -> void:
	var scenarios: Array[StringName] = [
		&"STATIC_HEADSHOT", &"MOVING_HEADSHOT", &"REVERSAL", &"PLAYER_TARGET_MOVING"
	]
	current_test = _definition_for_scenario(
		scenarios[_attempt_in_candidate % scenarios.size()], _scope_name()
	)
	test_changed.emit(current_test)


func _definition_for_scenario(scenario: StringName, scope_name: StringName) -> MentorTestDefinition:
	var motion: TargetMotionController.MotionMode = TargetMotionController.MotionMode.STATIONARY
	if scenario in [&"MOVING_HEADSHOT", &"PLAYER_TARGET_MOVING", &"TRACKING"]:
		motion = TargetMotionController.MotionMode.STRAFE_CONTINUOUS
	elif scenario == &"REVERSAL":
		motion = TargetMotionController.MotionMode.STRAFE_REVERSAL
	var definition: MentorTestDefinition = _definition(scenario, motion, scope_name)
	definition.tracking_enabled = motion != TargetMotionController.MotionMode.STATIONARY
	definition.player_motion = &"USER_JOYSTICK" if scenario == &"PLAYER_TARGET_MOVING" else &"STATIC"
	definition.candidate_sensitivity = candidate_sensitivity
	return definition


func _definition(
	type: StringName,
	motion: TargetMotionController.MotionMode,
	scope_name: StringName
) -> MentorTestDefinition:
	var definition := MentorTestDefinition.new()
	definition.test_type = type
	definition.target_motion = motion
	definition.scope_mode = scope_name
	definition.candidate_sensitivity = candidate_sensitivity
	return definition


func _scope_name() -> StringName:
	return &"RED_DOT" if current_phase in [
		Phase.RED_DOT_COARSE, Phase.RED_DOT_FINE, Phase.RED_DOT_VALIDATION
	] else &"GENERAL"


func _search_for_phase(phase: Phase) -> SensitivitySearchController:
	return _red_dot_search if phase in [Phase.RED_DOT_COARSE, Phase.RED_DOT_FINE] else _general_search


func _complete_analysis() -> void:
	current_phase = Phase.RESULTS
	progress = 1.0
	active = false
	saved_session_path = str(_local_storage().call("save_analysis_session", build_session_payload()))
	phase_changed.emit(current_phase)
	analysis_completed.emit()


func _update_progress() -> void:
	var phase_index: int = clampi(current_phase - Phase.WARMUP, 0, 9)
	var local_progress: float = 0.0
	var expected: int = 1
	match current_phase:
		Phase.WARMUP: expected = int(_config.get("warmup_attempts", 5))
		Phase.NATURAL_PROFILE: expected = int(_config.get("natural_profile_attempts", 10))
		Phase.STATIC_BASELINE: expected = int(_config.get("baseline_attempts", 5))
		Phase.GENERAL_COARSE, Phase.GENERAL_FINE, Phase.RED_DOT_COARSE, Phase.RED_DOT_FINE:
			expected = maxi(_candidate_order.size() * int(_config.get("attempts_per_candidate", 3)), 1)
		Phase.GENERAL_VALIDATION, Phase.RED_DOT_VALIDATION:
			expected = int(_config.get("validation_attempts", 4))
	local_progress = clampf(float(attempt_count) / float(maxi(expected, 1)), 0.0, 1.0)
	progress = clampf((float(phase_index) + local_progress) / 10.0, 0.0, 1.0)


func _blind_shuffle(values: PackedInt32Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(_session_manager().get("active_session_id")) + Phase.keys()[current_phase])
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: int = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


func _load_config() -> Dictionary:
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _session_manager() -> Node:
	return get_node("/root/SessionManager")


func _app_state() -> Node:
	return get_node("/root/AppState")


func _local_storage() -> Node:
	return get_node("/root/LocalStorage")
