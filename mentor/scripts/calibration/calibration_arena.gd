class_name CalibrationArena
extends Node3D

enum AttemptState {
	PREPARING,
	READY,
	AIMING,
	ANALYZING,
	SHOWING_RESULT,
	FINISHED,
}

enum TargetDistance {
	NEAR,
	MEDIUM,
	FAR,
}

const CONFIG_PATH: String = "res://data/calibration_arena.json"
const FIRE_TOUCH_OWNER: StringName = &"FIRE_AIM"
const CAMERA_TOUCH_OWNER: StringName = &"CAMERA_LOOK"
const JOYSTICK_TOUCH_OWNER: StringName = &"JOYSTICK"
const JUMP_TOUCH_OWNER: StringName = &"JUMP"

@onready var camera_controller: AimCameraController = $PlayerCalibrationRig
@onready var target_dummy: Node3D = $TargetDummy
@onready var target_motion: TargetMotionController = $TargetDummy/MotionController
@onready var head_target: Marker3D = $TargetDummy/HeadTarget
@onready var chest_target: Marker3D = $TargetDummy/ChestTarget
@onready var body_target: Marker3D = $TargetDummy/BodyTarget
@onready var crosshair: CalibrationCrosshair = %Crosshair
@onready var fire_region: FireAimRegion = %FireRegion
@onready var camera_look_region: CameraLookRegion = %CameraLookRegion
@onready var joystick_region: VirtualJoystickRegion = %JoystickRegion
@onready var red_dot_overlay: RedDotOverlay = %RedDotOverlay
@onready var jump_region: JumpRegion = %JumpRegion
@onready var instruction_label: Label = %InstructionLabel
@onready var attempt_label: Label = %AttemptCounter
@onready var feedback_label: Label = %ResultFeedback
@onready var metrics_label: Label = %MetricsLabel
@onready var developer_label: Label = %DeveloperLabel
@onready var debug_overlay: CalibrationDebugOverlay = %DebugOverlay
@onready var summary_panel: PanelContainer = %SummaryPanel
@onready var summary_label: Label = %SummaryLabel
@onready var analysis_progress: ProgressBar = %AnalysisProgress

var state: AttemptState = AttemptState.PREPARING
var current_region: CalibrationHitRegion.Region = CalibrationHitRegion.Region.NONE
var virtual_sensitivity: float = 100.0
var _config: Dictionary = {}
var _curve: SensitivityCurve
var _active_finger_id: int = -1
var _camera_look_finger_id: int = -1
var _joystick_finger_id: int = -1
var _jump_finger_id: int = -1
var _current: CalibrationAttempt
var _all_attempts: Array[CalibrationAttempt] = []
var _valid_attempts: Array[CalibrationAttempt] = []
var _state_deadline_usec: int = 0
var _developer_deadline_usec: int = 0
var _last_touch_position: Vector2 = Vector2.ZERO
var _last_touch_delta: Vector2 = Vector2.ZERO
var _last_touch_speed: float = 0.0
var _last_endpoint_center: Vector2 = Vector2.ZERO
var _pre_attempt_tracking_samples: Array[TrackingSample] = []


func _ready() -> void:
	AppState.current_screen = &"calibration_arena"
	_config = _load_config()
	_apply_target_distance()
	virtual_sensitivity = float(_config.get("virtual_sensitivity", 100.0))
	_curve = SensitivityCurve.load_from_json()
	camera_controller.configure_sensitivity(
		virtual_sensitivity,
		_curve,
		float(_config.get("angular_gain_degrees_at_full_scale", 240.0))
	)
	%BackButton.pressed.connect(_go_back)
	%RestartButton.pressed.connect(_restart_session)
	%SummaryMenuButton.pressed.connect(_go_back)
	TouchManager.touch_started.connect(_on_touch_started)
	TouchManager.touch_sampled.connect(_on_touch_sampled)
	TouchManager.touch_ended.connect(_on_touch_ended)
	developer_label.visible = AppState.developer_mode
	debug_overlay.visible = AppState.developer_mode
	summary_panel.visible = false
	analysis_progress.visible = AnalysisRunner.has_active_analysis()
	metrics_label.text = ""
	if SessionManager.active_session_id.is_empty():
		SessionManager.start_session()
	_prepare_next_attempt.call_deferred()


func _exit_tree() -> void:
	if _active_finger_id != -1:
		TouchManager.release_touch(_active_finger_id, FIRE_TOUCH_OWNER)
	if _camera_look_finger_id != -1:
		TouchManager.release_touch(_camera_look_finger_id, CAMERA_TOUCH_OWNER)
	if _joystick_finger_id != -1:
		TouchManager.release_touch(_joystick_finger_id, JOYSTICK_TOUCH_OWNER)
	if _jump_finger_id != -1:
		TouchManager.release_touch(_jump_finger_id, JUMP_TOUCH_OWNER)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if state == AttemptState.PREPARING and now >= _state_deadline_usec:
		_set_state(AttemptState.READY)
		instruction_label.text = (
			AnalysisRunner.get_instruction() if AnalysisRunner.has_active_analysis()
			else "Pressione FIRE e puxe do peito até a cabeça"
		)
	elif state == AttemptState.SHOWING_RESULT and now >= _state_deadline_usec:
		if AnalysisRunner.current_phase == MentorAnalysisRunner.Phase.RESULTS:
			_set_state(AttemptState.FINISHED)
			get_tree().change_scene_to_file("res://scenes/analysis/analysis_results.tscn")
		elif AnalysisRunner.has_active_analysis():
			_prepare_next_attempt()
		elif _valid_attempts.size() >= int(_config.get("valid_attempts", 10)):
			_finish_session()
		else:
			_prepare_next_attempt()

	_update_projected_head()
	if AppState.developer_mode and now >= _developer_deadline_usec:
		_developer_deadline_usec = now + 150_000
		_update_developer_overlay()


func _physics_process(delta: float) -> void:
	current_region = _query_center_region()
	crosshair.target_region = current_region
	if target_motion.running and state in [AttemptState.READY, AttemptState.AIMING]:
		_record_tracking_sample()
	if state == AttemptState.AIMING and _current != null \
	and current_region == CalibrationHitRegion.Region.HEAD:
		if not _current.entered_head:
			_current.entered_head = true
			_current.first_head_contact_usec = Time.get_ticks_usec()
		_current.time_on_head_ms += delta * 1000.0


func reset_aim_to_chest() -> void:
	camera_controller.point_at_target(chest_target)
	current_region = _query_center_region()
	crosshair.target_region = current_region


func point_aim_at(marker: Marker3D) -> void:
	## Método público para validação automatizada das regiões.
	camera_controller.point_at_target(marker)


func get_current_target_region() -> CalibrationHitRegion.Region:
	current_region = _query_center_region()
	return current_region


func start_target_motion(mode: TargetMotionController.MotionMode) -> void:
	## Entrada pública usada pelo runner: inicia tracking antes do FIRE e mantém o
	## mesmo controller ativo durante toda a puxada.
	target_motion.start_mode(mode)
	_pre_attempt_tracking_samples.clear()
	reset_aim_to_chest()


func stop_target_motion(reset_position: bool = true) -> void:
	target_motion.stop(reset_position)
	_pre_attempt_tracking_samples.clear()


func get_target_motion_controller() -> TargetMotionController:
	return target_motion


func _prepare_next_attempt() -> void:
	_set_state(AttemptState.PREPARING)
	if AnalysisRunner.has_active_analysis():
		_apply_runner_test()
	feedback_label.text = ""
	metrics_label.text = ""
	fire_region.active = false
	debug_overlay.clear_trail()
	debug_overlay.show_endpoint_error = false
	reset_aim_to_chest()
	_update_attempt_counter()
	instruction_label.text = (
		AnalysisRunner.get_instruction() if AnalysisRunner.has_active_analysis()
		else "Preparando mira no peito…"
	)
	_state_deadline_usec = Time.get_ticks_usec() + int(
		float(_config.get("preparing_seconds", 0.45)) * 1_000_000.0
	)


func _on_touch_started(finger_id: int, sample: TouchSample) -> void:
	# Regiões específicas sempre têm prioridade sobre a área ampla de câmera.
	# Mesmo fora de READY, um toque sobre FIRE nunca é reclassificado como look.
	if fire_region.contains_viewport_point(sample.position_px):
		if state == AttemptState.READY and _active_finger_id == -1:
			_start_fire_aim(finger_id, sample)
		return
	if jump_region.contains_viewport_point(sample.position_px):
		if state in [AttemptState.READY, AttemptState.AIMING] and _jump_finger_id == -1 \
		and TouchManager.claim_touch(finger_id, JUMP_TOUCH_OWNER):
			_jump_finger_id = finger_id
			jump_region.active = true
			camera_controller.request_jump()
		return
	if _is_point_over_priority_button(sample.position_px):
		return

	if state in [AttemptState.READY, AttemptState.AIMING] \
	and _joystick_finger_id == -1 \
	and joystick_region.contains_viewport_point(sample.position_px):
		if TouchManager.claim_touch(finger_id, JOYSTICK_TOUCH_OWNER):
			_joystick_finger_id = finger_id
			joystick_region.begin(sample.position_px)
			camera_controller.set_movement_input(Vector2.ZERO)
		return

	if state != AttemptState.READY or _camera_look_finger_id != -1:
		return
	if not camera_look_region.contains_viewport_point(sample.position_px):
		return
	if not TouchManager.claim_touch(finger_id, CAMERA_TOUCH_OWNER):
		return
	_camera_look_finger_id = finger_id
	_last_touch_position = sample.position_px
	_last_touch_delta = Vector2.ZERO
	_last_touch_speed = 0.0


func _start_fire_aim(finger_id: int, sample: TouchSample) -> void:
	if not TouchManager.claim_touch(finger_id, FIRE_TOUCH_OWNER):
		return
	_active_finger_id = finger_id
	fire_region.active = true
	_current = CalibrationAttempt.new()
	_current.gesture = GestureAttempt.new()
	_current.gesture.gesture_type = &"VERTICAL_HEADSHOT"
	_current.gesture.finger_id = finger_id
	_current.gesture.viewport_size = get_viewport().get_visible_rect().size
	_current.gesture.screen_dpi = _valid_screen_dpi()
	_current.gesture.start_zone = &"FIRE"
	_current.gesture.add_sample(sample)
	_current.virtual_sensitivity = virtual_sensitivity
	if AnalysisRunner.has_active_analysis() and AnalysisRunner.current_test != null:
		_current.test_type = AnalysisRunner.current_test.test_type
	var rotation_state: Vector2 = camera_controller.get_rotation_state()
	_current.start_camera_yaw = rotation_state.x
	_current.start_camera_pitch = rotation_state.y
	_current.started_target_region = _query_center_region()
	if target_motion.active_pattern != null:
		_current.target_pattern_id = target_motion.active_pattern.pattern_id
	_current.tracking_samples.assign(_pre_attempt_tracking_samples)
	_last_touch_position = sample.position_px
	_last_touch_delta = Vector2.ZERO
	_last_touch_speed = 0.0
	debug_overlay.clear_trail()
	debug_overlay.append_trail_point(sample.position_px)
	_set_state(AttemptState.AIMING)
	instruction_label.text = "Mantenha o controle e solte ao finalizar"


func _on_touch_sampled(finger_id: int, sample: TouchSample) -> void:
	if finger_id == _joystick_finger_id:
		camera_controller.set_movement_input(joystick_region.update_drag(sample.position_px))
		return

	if finger_id == _camera_look_finger_id:
		camera_controller.apply_touch_delta(sample.delta_norm)
		_last_touch_position = sample.position_px
		_last_touch_delta = sample.delta_px
		_last_touch_speed = sample.instant_speed_norm_s
		return

	if state != AttemptState.AIMING or finger_id != _active_finger_id or _current == null:
		return
	_current.gesture.add_sample(sample)
	camera_controller.apply_touch_delta(sample.delta_norm)
	_last_touch_position = sample.position_px
	_last_touch_delta = sample.delta_px
	_last_touch_speed = sample.instant_speed_norm_s
	if AppState.developer_mode:
		debug_overlay.append_trail_point(sample.position_px)


func _on_touch_ended(finger_id: int, sample: TouchSample, cancelled: bool) -> void:
	if finger_id == _jump_finger_id:
		TouchManager.release_touch(finger_id, JUMP_TOUCH_OWNER)
		_jump_finger_id = -1
		jump_region.active = false
		return

	if finger_id == _joystick_finger_id:
		TouchManager.release_touch(finger_id, JOYSTICK_TOUCH_OWNER)
		_joystick_finger_id = -1
		joystick_region.finish()
		camera_controller.set_movement_input(Vector2.ZERO)
		return

	if finger_id == _camera_look_finger_id:
		TouchManager.release_touch(finger_id, CAMERA_TOUCH_OWNER)
		_camera_look_finger_id = -1
		_last_touch_position = sample.position_px
		_last_touch_delta = Vector2.ZERO
		_last_touch_speed = 0.0
		return

	if state != AttemptState.AIMING or finger_id != _active_finger_id or _current == null:
		return
	if _current.gesture.samples.is_empty() \
	or sample.timestamp_usec > _current.gesture.samples[-1].timestamp_usec:
		_current.gesture.add_sample(sample)
	_current.gesture.was_cancelled = cancelled
	TouchManager.release_touch(finger_id, FIRE_TOUCH_OWNER)
	_active_finger_id = -1
	fire_region.active = false
	_finalize_current_attempt(cancelled)


func _finalize_current_attempt(cancelled: bool) -> void:
	_set_state(AttemptState.ANALYZING)
	_current.metrics = GestureAnalyzer.analyze(_current.gesture)
	_current.tracking_metrics = TrackingAnalyzer.analyze(
		_current.tracking_samples,
		float(_config.get("tracking_near_chest_radius_norm", 0.035))
	)
	_validate_gesture(_current.gesture, _current.metrics, cancelled)
	var rotation_state: Vector2 = camera_controller.get_rotation_state()
	_current.end_camera_yaw = rotation_state.x
	_current.end_camera_pitch = rotation_state.y
	_current.ended_target_region = _query_center_region()
	if _current.first_head_contact_usec >= 0:
		_current.time_to_head_ms = float(
			_current.first_head_contact_usec - _current.gesture.started_usec
		) / 1000.0
	_current.metrics.time_to_target_ms = _current.time_to_head_ms
	_calculate_endpoint_error(_current)
	_current.classification = CalibrationClassifier.classify(
		_current,
		_config.get("classification", {}) as Dictionary
	)
	_all_attempts.append(_current)
	SessionManager.register_gesture()
	if _current.classification != CalibrationAttempt.Classification.INVALID:
		_valid_attempts.append(_current)
		if AnalysisRunner.has_active_analysis():
			AnalysisRunner.submit_attempt(_current)
	_show_attempt_result(_current)
	_current = null
	_pre_attempt_tracking_samples.clear()
	_set_state(AttemptState.SHOWING_RESULT)
	_state_deadline_usec = Time.get_ticks_usec() + int(
		float(_config.get("result_seconds", 0.85)) * 1_000_000.0
	)


func _validate_gesture(gesture: GestureAttempt, metrics: GestureMetrics, cancelled: bool) -> void:
	if cancelled:
		gesture.is_valid = false
		gesture.invalid_reason = &"TOUCH_CANCELLED"
	elif gesture.samples.size() < int(_config.get("minimum_samples", 3)):
		gesture.is_valid = false
		gesture.invalid_reason = &"POUCOS_SAMPLES"
	elif metrics.path_length_norm < float(_config.get("minimum_drag_length_norm", 0.005)):
		gesture.is_valid = false
		gesture.invalid_reason = &"MOVIMENTO_MUITO_CURTO"
	elif metrics.duration_ms > float(_config.get("maximum_duration_ms", 3000.0)):
		gesture.is_valid = false
		gesture.invalid_reason = &"DURACAO_EXCESSIVA"


func _calculate_endpoint_error(attempt: CalibrationAttempt) -> void:
	var camera: Camera3D = camera_controller.get_camera()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var viewport_center: Vector2 = viewport_size * 0.5
	attempt.head_screen_position_px = camera.unproject_position(head_target.global_position)
	attempt.endpoint_error_px = viewport_center - attempt.head_screen_position_px
	attempt.endpoint_error_norm = attempt.endpoint_error_px / Vector2(
		maxf(viewport_size.x, 1.0),
		maxf(viewport_size.y, 1.0)
	)
	attempt.endpoint_error_length_px = attempt.endpoint_error_px.length()
	attempt.endpoint_error_length_norm = attempt.endpoint_error_norm.length()
	_last_endpoint_center = viewport_center
	debug_overlay.update_projection(
		attempt.head_screen_position_px,
		viewport_center,
		AppState.developer_mode
	)


func _query_center_region() -> CalibrationHitRegion.Region:
	var camera: Camera3D = camera_controller.get_camera()
	if camera == null or not camera.is_inside_tree():
		return CalibrationHitRegion.Region.NONE
	var origin: Vector3 = camera.global_position
	var ray_end: Vector3 = origin + (-camera.global_transform.basis.z) * float(
		_config.get("ray_distance", 50.0)
	)
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		ray_end,
		int(_config.get("ray_collision_mask", 2))
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return CalibrationHitRegion.Region.NONE
	var collider: Object = hit.get("collider") as Object
	if collider is CalibrationHitRegion:
		return (collider as CalibrationHitRegion).region
	return CalibrationHitRegion.Region.NONE


func _record_tracking_sample() -> void:
	var camera: Camera3D = camera_controller.get_camera()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = viewport_size * 0.5
	var chest_screen: Vector2 = camera.unproject_position(chest_target.global_position)
	var error_norm: Vector2 = (chest_screen - center) / Vector2(
		maxf(viewport_size.x, 1.0), maxf(viewport_size.y, 1.0)
	)
	var direction_x: float = 0.0
	if target_motion.active_pattern != null:
		direction_x = target_motion.active_pattern.direction_at(
			target_motion.elapsed_seconds,
			target_motion.loop_pattern
		).x
	var sample := TrackingSample.create(Time.get_ticks_usec(), error_norm, direction_x)
	if state == AttemptState.AIMING and _current != null:
		_current.tracking_samples.append(sample)
	else:
		_pre_attempt_tracking_samples.append(sample)
		# Limita o pre-roll a dois segundos a 120 Hz, evitando crescimento sem fim.
		if _pre_attempt_tracking_samples.size() > 240:
			_pre_attempt_tracking_samples.pop_front()


func _is_point_over_priority_button(point: Vector2) -> bool:
	var buttons: Array[BaseButton] = [%BackButton, %RestartButton, %SummaryMenuButton]
	for button: BaseButton in buttons:
		if button.visible and button.get_global_rect().has_point(point):
			return true
	return false


func _update_projected_head() -> void:
	var camera: Camera3D = camera_controller.get_camera()
	if camera == null or not camera.is_inside_tree():
		return
	var viewport_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	debug_overlay.update_projection(
		camera.unproject_position(head_target.global_position),
		viewport_center,
		state == AttemptState.SHOWING_RESULT
	)


func _show_attempt_result(attempt: CalibrationAttempt) -> void:
	if AnalysisRunner.has_active_analysis() \
	or AnalysisRunner.current_phase == MentorAnalysisRunner.Phase.RESULTS:
		feedback_label.text = "TENTATIVA REGISTRADA"
		metrics_label.text = ""
		_update_attempt_counter()
		return
	var feedbacks: Dictionary = {
		CalibrationAttempt.Classification.INVALID: "VAMOS TENTAR NOVAMENTE",
		CalibrationAttempt.Classification.PERFECT: "PERFEITO",
		CalibrationAttempt.Classification.GOOD: "BOM",
		CalibrationAttempt.Classification.UNDERSHOOT: "FICOU ABAIXO",
		CalibrationAttempt.Classification.OVERSHOOT: "PASSOU DA CABEÇA",
		CalibrationAttempt.Classification.LATERAL_MISS: "DESVIO LATERAL",
	}
	feedback_label.text = str(feedbacks[attempt.classification])
	metrics_label.text = _format_attempt_metrics(attempt)
	_update_attempt_counter()


func _format_attempt_metrics(attempt: CalibrationAttempt) -> String:
	var time_to_head_text: String = "—"
	if attempt.time_to_head_ms >= 0.0:
		time_to_head_text = "%.0f ms" % attempt.time_to_head_ms
	return (
		"Puxada %.0f ms  •  cabeça %s\n" % [attempt.metrics.duration_ms, time_to_head_text]
		+ "Dedo %.1f%% da tela  •  mediana %.2f  •  pico %.2f tela/s\n" % [
			attempt.metrics.path_length_norm * 100.0,
			attempt.metrics.median_speed,
			attempt.metrics.peak_speed,
		]
		+ "Retidão %.0f%%  •  erro X %+.2f%%  Y %+.2f%%  •  correções %d" % [
			attempt.metrics.straightness * 100.0,
			attempt.endpoint_error_norm.x * 100.0,
			attempt.endpoint_error_norm.y * 100.0,
			attempt.metrics.correction_count,
		]
	)


func _finish_session() -> void:
	_set_state(AttemptState.FINISHED)
	instruction_label.text = "Sessão concluída"
	feedback_label.text = ""
	var summary: CalibrationSessionSummary = CalibrationSessionSummary.from_attempts(_valid_attempts)
	summary_label.text = _format_summary(summary)
	summary_panel.visible = true


func _format_summary(summary: CalibrationSessionSummary) -> String:
	return (
		"%d TENTATIVAS VÁLIDAS\n\n" % summary.valid_attempts
		+ "PERFECT %d   GOOD %d   ABAIXO %d   ACIMA %d   LATERAL %d\n\n" % [
			summary.classification_counts.get("PERFECT", 0),
			summary.classification_counts.get("GOOD", 0),
			summary.classification_counts.get("UNDERSHOOT", 0),
			summary.classification_counts.get("OVERSHOOT", 0),
			summary.classification_counts.get("LATERAL_MISS", 0),
		]
		+ "Duração mediana %.0f ms  •  cabeça %.0f ms\n" % [
			summary.median_duration_ms,
			summary.median_time_to_head_ms,
		]
		+ "Distância %.1f%%  •  pico %.2f tela/s  •  erro %.2f%%\n" % [
			summary.median_drag_distance_norm * 100.0,
			summary.median_peak_speed,
			summary.median_endpoint_error_norm * 100.0,
		]
		+ "Retidão %.0f%%  •  consistência %.0f%%  •  correções %d" % [
			summary.median_straightness * 100.0,
			summary.consistency_score * 100.0,
			summary.total_corrections,
		]
	)


func _update_developer_overlay() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var rotation_state: Vector2 = camera_controller.get_rotation_state()
	var endpoint_error: Vector2 = Vector2.ZERO
	if not _all_attempts.is_empty():
		endpoint_error = _all_attempts[-1].endpoint_error_norm
	var runner_debug: String = ""
	if AnalysisRunner.has_active_analysis():
		var pattern_name: String = "STATIONARY"
		if target_motion.active_pattern != null:
			pattern_name = String(target_motion.active_pattern.pattern_id)
		var tracking_error: Vector2 = Vector2.ZERO
		if not _pre_attempt_tracking_samples.is_empty():
			tracking_error = _pre_attempt_tracking_samples[-1].error_norm
		runner_debug = "\nphase %s | test %s | candidate %d | pattern %s | track %s" % [
			AnalysisRunner.get_phase_name(), String(AnalysisRunner.current_test.test_type),
			AnalysisRunner.candidate_sensitivity, pattern_name, tracking_error]
	developer_label.text = (
		"FPS %d | viewport %dx%d | DPI %.0f | fingers %s\n" % [
			Engine.get_frames_per_second(), int(viewport_size.x), int(viewport_size.y),
			_valid_screen_dpi(), str(TouchManager.get_active_finger_ids())]
		+ "fire %d | look %d | stick %d | jump %d | pos %s | delta %s | speed %.3f\n" % [
			_active_finger_id, _camera_look_finger_id, _joystick_finger_id, _jump_finger_id, _last_touch_position.round(),
			_last_touch_delta.round(), _last_touch_speed]
		+ "sensi %.0f | curve %.3f | angular %.2f rad/screen\n" % [
			virtual_sensitivity, camera_controller.curve_gain,
			camera_controller.angular_gain_rad_per_screen]
		+ "yaw %.2f° | pitch %.2f° | TARGET %s | state %s | %d/%d\n" % [
			rad_to_deg(rotation_state.x), rad_to_deg(rotation_state.y),
			CalibrationHitRegion.region_name(current_region), AttemptState.keys()[state],
			_valid_attempts.size(), int(_config.get("valid_attempts", 10))]
		+ "head %s | endpoint error %s" % [
			camera_controller.get_camera().unproject_position(head_target.global_position).round(),
			endpoint_error]
		+ runner_debug
	)


func _update_attempt_counter() -> void:
	if AnalysisRunner.has_active_analysis():
		attempt_label.text = "%s  •  %.0f%%" % [
			AnalysisRunner.get_step_label(), AnalysisRunner.progress * 100.0]
		analysis_progress.value = AnalysisRunner.progress * 100.0
		return
	attempt_label.text = "Tentativa %d/%d" % [
		mini(_valid_attempts.size() + 1, int(_config.get("valid_attempts", 10))),
		int(_config.get("valid_attempts", 10)),
	]


func _set_state(new_state: AttemptState) -> void:
	state = new_state


func _restart_session() -> void:
	_all_attempts.clear()
	_valid_attempts.clear()
	summary_panel.visible = false
	if AnalysisRunner.current_phase != MentorAnalysisRunner.Phase.INTRO:
		AnalysisRunner.begin_analysis(AnalysisRunner.current_general, AnalysisRunner.current_red_dot)
	else:
		SessionManager.start_session()
	_prepare_next_attempt()


func _go_back() -> void:
	if _active_finger_id != -1:
		TouchManager.release_touch(_active_finger_id, FIRE_TOUCH_OWNER)
	if _camera_look_finger_id != -1:
		TouchManager.release_touch(_camera_look_finger_id, CAMERA_TOUCH_OWNER)
	if _joystick_finger_id != -1:
		TouchManager.release_touch(_joystick_finger_id, JOYSTICK_TOUCH_OWNER)
	if _jump_finger_id != -1:
		TouchManager.release_touch(_jump_finger_id, JUMP_TOUCH_OWNER)
	if AnalysisRunner.has_active_analysis():
		AnalysisRunner.cancel_analysis()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _apply_runner_test() -> void:
	var definition: MentorTestDefinition = AnalysisRunner.current_test
	if definition == null:
		return
	virtual_sensitivity = float(definition.candidate_sensitivity)
	camera_controller.configure_sensitivity(
		virtual_sensitivity,
		_curve,
		float(_config.get("angular_gain_degrees_at_full_scale", 240.0))
	)
	camera_controller.reset_player_translation()
	stop_target_motion(true)
	if definition.target_motion != TargetMotionController.MotionMode.STATIONARY:
		target_motion.start_mode(definition.target_motion)
		_pre_attempt_tracking_samples.clear()
	var is_red_dot: bool = definition.scope_mode == &"RED_DOT"
	camera_controller.set_scope_mode(is_red_dot)
	red_dot_overlay.visible = is_red_dot
	analysis_progress.visible = true
	analysis_progress.value = AnalysisRunner.progress * 100.0


func _load_config() -> Dictionary:
	var defaults: Dictionary = {
		"virtual_sensitivity": 100.0,
		"target_distance_mode": "MEDIUM",
		"target_positions_z": {"NEAR": -3.8, "MEDIUM": -5.8, "FAR": -9.0},
		"angular_gain_degrees_at_full_scale": 240.0,
		"valid_attempts": 10,
		"minimum_samples": 3,
		"minimum_drag_length_norm": 0.005,
		"maximum_duration_ms": 3000.0,
		"preparing_seconds": 0.45,
		"result_seconds": 0.85,
		"ray_distance": 50.0,
		"ray_collision_mask": 2,
		"classification": {},
	}
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("[Mentor][Calibration] Config ausente; usando defaults seguros.")
		return defaults
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return defaults
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("[Mentor][Calibration] JSON inválido; usando defaults.")
		return defaults
	return parsed as Dictionary


func _apply_target_distance() -> void:
	var mode: String = str(_config.get("target_distance_mode", "MEDIUM")).to_upper()
	var positions: Dictionary = _config.get("target_positions_z", {}) as Dictionary
	if not positions.has(mode):
		mode = "MEDIUM"
	# Distâncias internas experimentais do Mentor; não equivalem a metros/FOV do Free Fire.
	target_dummy.position.z = float(positions.get(mode, -5.8))


func _valid_screen_dpi() -> float:
	var dpi: float = float(DisplayServer.screen_get_dpi())
	return dpi if dpi >= 50.0 and dpi <= 1000.0 else 0.0
