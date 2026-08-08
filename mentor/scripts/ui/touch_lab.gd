extends Control

const TOUCH_OWNER: StringName = &"TOUCH_LAB"

@onready var trail_view: TouchTrailView = %TrailView
@onready var status_label: Label = %StatusLabel
@onready var live_label: Label = %LiveLabel
@onready var metrics_label: Label = %MetricsLabel
@onready var developer_label: Label = %DeveloperLabel

var _active_finger_id: int = -1
var _current_attempt: GestureAttempt
var _last_attempt: GestureAttempt
var _last_metrics: GestureMetrics
var _trail_points: PackedVector2Array = PackedVector2Array()
var _trail_speeds: PackedFloat32Array = PackedFloat32Array()
var _developer_refresh: float = 0.0


func _ready() -> void:
	AppState.current_screen = &"touch_lab"
	%AppNameLabel.text = "%s • Touch Lab" % AppState.app_name
	%BackButton.pressed.connect(_go_back)
	%ClearButton.pressed.connect(_clear_lab)
	%AnalyzeButton.pressed.connect(_analyze_last_attempt)
	%SaveButton.pressed.connect(_save_last_attempt)
	TouchManager.touch_started.connect(_on_touch_started)
	TouchManager.touch_sampled.connect(_on_touch_sampled)
	TouchManager.touch_ended.connect(_on_touch_ended)
	developer_label.visible = AppState.developer_mode
	status_label.text = "Arraste dentro da área para registrar um gesto."
	metrics_label.text = _empty_metrics_text()


func _exit_tree() -> void:
	if _active_finger_id != -1:
		TouchManager.release_touch(_active_finger_id, TOUCH_OWNER)


func _process(delta: float) -> void:
	if not AppState.developer_mode:
		return
	_developer_refresh -= delta
	if _developer_refresh > 0.0:
		return
	_developer_refresh = 0.25
	var viewport_size: Vector2 = get_viewport_rect().size
	developer_label.text = "FPS %d  |  viewport %dx%d  |  DPI %.0f  |  fingers %s" % [
		Engine.get_frames_per_second(),
		int(viewport_size.x),
		int(viewport_size.y),
		_valid_screen_dpi(),
		str(TouchManager.get_active_finger_ids()),
	]


func _on_touch_started(finger_id: int, sample: TouchSample) -> void:
	if _active_finger_id != -1 or not _is_inside_trail(sample.position_px):
		return
	if not TouchManager.claim_touch(finger_id, TOUCH_OWNER):
		return

	_active_finger_id = finger_id
	_current_attempt = GestureAttempt.new()
	_current_attempt.gesture_type = &"RAW_MOTOR_TEST"
	_current_attempt.finger_id = finger_id
	_current_attempt.viewport_size = get_viewport_rect().size
	_current_attempt.screen_dpi = _valid_screen_dpi()
	_current_attempt.start_zone = &"TOUCH_LAB"
	_current_attempt.add_sample(sample)
	_trail_points = PackedVector2Array([_to_trail_local(sample.position_px)])
	_trail_speeds = PackedFloat32Array([0.0])
	trail_view.set_trajectory(_trail_points, _trail_speeds)
	status_label.text = "Capturando finger %d…" % finger_id
	_update_live_values(sample)


func _on_touch_sampled(finger_id: int, sample: TouchSample) -> void:
	if finger_id != _active_finger_id or _current_attempt == null:
		return
	_current_attempt.add_sample(sample)
	_trail_points.append(_to_trail_local(sample.position_px))
	_trail_speeds.append(sample.instant_speed_norm_s)
	trail_view.set_trajectory(_trail_points, _trail_speeds)
	_update_live_values(sample)


func _on_touch_ended(finger_id: int, sample: TouchSample, cancelled: bool) -> void:
	if finger_id != _active_finger_id or _current_attempt == null:
		return
	if _current_attempt.samples.is_empty() or sample.timestamp_usec > _current_attempt.samples[-1].timestamp_usec:
		_current_attempt.add_sample(sample)
	_current_attempt.was_cancelled = cancelled
	if cancelled:
		_current_attempt.is_valid = false
		_current_attempt.invalid_reason = &"TOUCH_CANCELLED"
		status_label.text = "Gesto interrompido. Tente novamente."
	else:
		_validate_attempt(_current_attempt)
		_last_attempt = _current_attempt
		_analyze_last_attempt()
	SessionManager.register_gesture()
	TouchManager.release_touch(finger_id, TOUCH_OWNER)
	_active_finger_id = -1
	_current_attempt = null


func _analyze_last_attempt() -> void:
	if _last_attempt == null:
		status_label.text = "Faça um gesto antes de analisar."
		return
	_last_metrics = GestureAnalyzer.analyze(_last_attempt)
	metrics_label.text = _format_metrics(_last_metrics)
	if _last_attempt.is_valid:
		status_label.text = "Análise concluída • %d samples brutos" % _last_attempt.samples.size()
	else:
		status_label.text = "Tentativa inválida: %s" % String(_last_attempt.invalid_reason)


func _save_last_attempt() -> void:
	if _last_attempt == null or _last_metrics == null:
		status_label.text = "Analise um gesto antes de salvar."
		return
	var saved_path: String = LocalStorage.save_touch_sample(_last_attempt, _last_metrics)
	if saved_path.is_empty():
		status_label.text = "Não foi possível salvar a amostra."
	else:
		status_label.text = "Amostra salva localmente em %s" % saved_path


func _clear_lab() -> void:
	_last_attempt = null
	_last_metrics = null
	_trail_points.clear()
	_trail_speeds.clear()
	trail_view.clear_trajectory()
	live_label.text = "X/Y —  |  Δ —  |  velocidade —"
	metrics_label.text = _empty_metrics_text()
	status_label.text = "Área limpa. Faça um novo gesto."


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _validate_attempt(attempt: GestureAttempt) -> void:
	if attempt.samples.size() < 3:
		attempt.is_valid = false
		attempt.invalid_reason = &"POUCOS_SAMPLES"
		return
	var displacement: float = attempt.samples[0].position_norm.distance_to(attempt.samples[-1].position_norm)
	if displacement < 0.005:
		attempt.is_valid = false
		attempt.invalid_reason = &"MOVIMENTO_MUITO_CURTO"


func _update_live_values(sample: TouchSample) -> void:
	live_label.text = "X %.0f  Y %.0f  |  ΔX %.1f  ΔY %.1f  |  %.3f tela/s" % [
		sample.position_px.x,
		sample.position_px.y,
		sample.delta_px.x,
		sample.delta_px.y,
		sample.instant_speed_norm_s,
	]


func _format_metrics(metrics: GestureMetrics) -> String:
	return (
		"DURAÇÃO\n%.1f ms\n\n" % metrics.duration_ms
		+ "DISTÂNCIA\n%.1f px  •  %.4f norm\n\n" % [metrics.path_length_px, metrics.path_length_norm]
		+ "VELOCIDADE\nmediana %.3f  •  pico %.3f tela/s\n\n" % [metrics.median_speed, metrics.peak_speed]
		+ "DIREÇÃO\n%.1f°  •  %d mudanças\n\n" % [metrics.principal_angle_deg, metrics.direction_changes]
		+ "CONTROLE\nretidão %.1f%%  •  eficiência %.1f%%\n\n" % [metrics.straightness * 100.0, metrics.movement_efficiency * 100.0]
		+ "ESTABILIDADE\ntremor %.1f%%  •  %d correções" % [metrics.tremor_score * 100.0, metrics.correction_count]
	)


func _empty_metrics_text() -> String:
	return "DURAÇÃO\n—\n\nDISTÂNCIA\n—\n\nVELOCIDADE\n—\n\nDIREÇÃO\n—\n\nCONTROLE\n—\n\nESTABILIDADE\n—"


func _is_inside_trail(viewport_position: Vector2) -> bool:
	return Rect2(trail_view.global_position, trail_view.size).has_point(viewport_position)


func _to_trail_local(viewport_position: Vector2) -> Vector2:
	return viewport_position - trail_view.global_position


func _valid_screen_dpi() -> float:
	var dpi: float = float(DisplayServer.screen_get_dpi())
	if dpi < 50.0 or dpi > 1000.0:
		return 0.0
	return dpi
