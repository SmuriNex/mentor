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
const TOUCH_OWNER: StringName = &"FIRE_AIM"

@onready var camera_controller: AimCameraController = $PlayerCalibrationRig
@onready var target_dummy: Node3D = $TargetDummy
@onready var head_target: Marker3D = $TargetDummy/HeadTarget
@onready var chest_target: Marker3D = $TargetDummy/ChestTarget
@onready var body_target: Marker3D = $TargetDummy/BodyTarget
@onready var crosshair: CalibrationCrosshair = %Crosshair
@onready var fire_region: FireAimRegion = %FireRegion
@onready var instruction_label: Label = %InstructionLabel
@onready var attempt_label: Label = %AttemptCounter
@onready var feedback_label: Label = %ResultFeedback
@onready var metrics_label: Label = %MetricsLabel
@onready var developer_label: Label = %DeveloperLabel
@onready var debug_overlay: CalibrationDebugOverlay = %DebugOverlay
@onready var summary_panel: PanelContainer = %SummaryPanel
@onready var summary_label: Label = %SummaryLabel

var state: AttemptState = AttemptState.PREPARING
var current_region: CalibrationHitRegion.Region = CalibrationHitRegion.Region.NONE
var virtual_sensitivity: float = 100.0
var _config: Dictionary = {}
var _curve: SensitivityCurve
var _active_finger_id: int = -1
var _current: CalibrationAttempt
var _all_attempts: Array[CalibrationAttempt] = []
var _valid_attempts: Array[CalibrationAttempt] = []
var _state_deadline_usec: int = 0
var _developer_deadline_usec: int = 0
var _last_touch_position: Vector2 = Vector2.ZERO
var _last_touch_delta: Vector2 = Vector2.ZERO
var _last_touch_speed: float = 0.0
var _last_endpoint_center: Vector2 = Vector2.ZERO


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
	metrics_label.text = ""
	if SessionManager.active_session_id.is_empty():
		SessionManager.start_session()
	_prepare_next_attempt.call_deferred()


func _exit_tree() -> void:
	if _active_finger_id != -1:
		TouchManager.release_touch(_active_finger_id, TOUCH_OWNER)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if state == AttemptState.PREPARING and now >= _state_deadline_usec:
		_set_state(AttemptState.READY)
		instruction_label.text = "Pressione FIRE e puxe do peito até a cabeça"
	elif state == AttemptState.SHOWING_RESULT and now >= _state_deadline_usec:
		if _valid_attempts.size() >= int(_config.get("valid_attempts", 10)):
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


func _prepare_next_attempt() -> void:
	_set_state(AttemptState.PREPARING)
	feedback_label.text = ""
	metrics_label.text = ""
	fire_region.active = false
	debug_overlay.clear_trail()
	debug_overlay.show_endpoint_error = false
	reset_aim_to_chest()
	_update_attempt_counter()
	instruction_label.text = "Preparando mira no peito…"
	_state_deadline_usec = Time.get_ticks_usec() + int(
		float(_config.get("preparing_seconds", 0.45)) * 1_000_000.0
	)


func _on_touch_started(finger_id: int, sample: TouchSample) -> void:
	if state != AttemptState.READY or not fire_region.contains_viewport_point(sample.position_px):
		return
	if not TouchManager.claim_touch(finger_id, TOUCH_OWNER):
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
	var rotation_state: Vector2 = camera_controller.get_rotation_state()
	_current.start_camera_yaw = rotation_state.x
	_current.start_camera_pitch = rotation_state.y
	_current.started_target_region = _query_center_region()
	_last_touch_position = sample.position_px
	_last_touch_delta = Vector2.ZERO
	_last_touch_speed = 0.0
	debug_overlay.clear_trail()
	debug_overlay.append_trail_point(sample.position_px)
	_set_state(AttemptState.AIMING)
	instruction_label.text = "Mantenha o controle e solte ao finalizar"


func _on_touch_sampled(finger_id: int, sample: TouchSample) -> void:
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
	if state != AttemptState.AIMING or finger_id != _active_finger_id or _current == null:
		return
	if _current.gesture.samples.is_empty() \
	or sample.timestamp_usec > _current.gesture.samples[-1].timestamp_usec:
		_current.gesture.add_sample(sample)
	_current.gesture.was_cancelled = cancelled
	TouchManager.release_touch(finger_id, TOUCH_OWNER)
	_active_finger_id = -1
	fire_region.active = false
	_finalize_current_attempt(cancelled)


func _finalize_current_attempt(cancelled: bool) -> void:
	_set_state(AttemptState.ANALYZING)
	_current.metrics = GestureAnalyzer.analyze(_current.gesture)
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
	_show_attempt_result(_current)
	_current = null
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
	developer_label.text = (
		"FPS %d | viewport %dx%d | DPI %.0f | fingers %s\n" % [
			Engine.get_frames_per_second(), int(viewport_size.x), int(viewport_size.y),
			_valid_screen_dpi(), str(TouchManager.get_active_finger_ids())]
		+ "aim finger %d | pos %s | delta %s | speed %.3f\n" % [
			_active_finger_id, _last_touch_position.round(), _last_touch_delta.round(), _last_touch_speed]
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
	)


func _update_attempt_counter() -> void:
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
	SessionManager.start_session()
	_prepare_next_attempt()


func _go_back() -> void:
	if _active_finger_id != -1:
		TouchManager.release_touch(_active_finger_id, TOUCH_OWNER)
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


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
