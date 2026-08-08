extends SceneTree

var _failures: int = 0
var _touch_manager: Node
const STATE_READY: int = 1
const STATE_AIMING: int = 2
const STATE_PREPARING: int = 0
const STATE_FINISHED: int = 5


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/calibration/calibration_arena.tscn") as PackedScene
	var arena: Node = packed.instantiate()
	root.add_child(arena)
	_touch_manager = root.get_node("TouchManager")
	await process_frame
	await physics_frame
	await physics_frame

	await _test_target_regions(arena)
	_test_classifier_boundaries()
	_test_motor_speed_and_correction()
	_test_ten_attempt_summary()
	await _test_fire_aim_flow(arena)

	arena.queue_free()
	await process_frame
	if _failures == 0:
		print("[Mentor][Tests] Calibration Arena: regiões, câmera e touch passaram.")
		quit(0)
	else:
		push_error("[Mentor][Tests] Calibration Arena falhou em %d ponto(s)." % _failures)
		quit(1)


func _test_target_regions(arena: Node) -> void:
	var head: Marker3D = arena.get_node("TargetDummy/HeadTarget") as Marker3D
	var chest: Marker3D = arena.get_node("TargetDummy/ChestTarget") as Marker3D
	var body: Marker3D = arena.get_node("TargetDummy/BodyTarget") as Marker3D
	var camera_controller: AimCameraController = arena.get_node("PlayerCalibrationRig") as AimCameraController

	arena.call("point_aim_at", chest)
	await physics_frame
	_expect_region(int(arena.call("get_current_target_region")), CalibrationHitRegion.Region.CHEST, "raycast no peito")
	arena.call("point_aim_at", head)
	await physics_frame
	_expect_region(int(arena.call("get_current_target_region")), CalibrationHitRegion.Region.HEAD, "raycast na cabeça")
	var camera: Camera3D = camera_controller.get_camera()
	var projected_head: Vector2 = camera.unproject_position(head.global_position)
	var center: Vector2 = camera.get_viewport().get_visible_rect().size * 0.5
	_expect(projected_head.distance_to(center) < 3.0, "HeadTarget deve projetar no centro após point_at_target")
	arena.call("point_aim_at", body)
	await physics_frame
	_expect_region(int(arena.call("get_current_target_region")), CalibrationHitRegion.Region.BODY, "raycast no corpo")
	camera_controller.reset_orientation(deg_to_rad(28.0), 0.0)
	await physics_frame
	_expect_region(int(arena.call("get_current_target_region")), CalibrationHitRegion.Region.NONE, "raycast fora do alvo")
	arena.call("reset_aim_to_chest")
	await physics_frame
	_expect_region(int(arena.call("get_current_target_region")), CalibrationHitRegion.Region.CHEST, "reset automático para peito")


func _test_classifier_boundaries() -> void:
	var thresholds: Dictionary = {
		"perfect_radius_norm": 0.012,
		"good_radius_norm": 0.030,
		"vertical_band_norm": 0.035,
		"lateral_threshold_norm": 0.045,
	}
	_expect_classification(
		_make_classification_attempt(Vector2(0.005, 0.004), false),
		thresholds,
		CalibrationAttempt.Classification.PERFECT,
		"classificação PERFECT"
	)
	_expect_classification(
		_make_classification_attempt(Vector2(0.0, 0.06), false),
		thresholds,
		CalibrationAttempt.Classification.UNDERSHOOT,
		"classificação UNDERSHOOT"
	)
	_expect_classification(
		_make_classification_attempt(Vector2(0.0, -0.06), true),
		thresholds,
		CalibrationAttempt.Classification.OVERSHOOT,
		"classificação OVERSHOOT"
	)
	_expect_classification(
		_make_classification_attempt(Vector2(0.07, 0.01), false),
		thresholds,
		CalibrationAttempt.Classification.LATERAL_MISS,
		"classificação LATERAL_MISS"
	)


func _test_motor_speed_and_correction() -> void:
	var slow: GestureAttempt = _make_timed_gesture(200_000)
	var fast: GestureAttempt = _make_timed_gesture(20_000)
	var slow_metrics: GestureMetrics = GestureAnalyzer.analyze(slow)
	var fast_metrics: GestureMetrics = GestureAnalyzer.analyze(fast)
	_expect(fast_metrics.peak_speed > slow_metrics.peak_speed * 5.0, "flick rápido deve elevar peak speed")

	var correction := GestureAttempt.new()
	var points: Array[Vector2] = [
		Vector2(0.5, 0.72), Vector2(0.5, 0.50),
		Vector2(0.5, 0.28), Vector2(0.5, 0.37),
	]
	var timestamp: int = 1_000_000
	var previous: Vector2 = points[0]
	for point: Vector2 in points:
		var delta: Vector2 = point - previous
		correction.add_sample(TouchSample.create(
			timestamp, point * Vector2(1280, 720), point,
			delta * Vector2(1280, 720), delta, delta.length() * 10_000.0, delta.length() * 10.0
		))
		previous = point
		timestamp += 100_000
	_expect(GestureAnalyzer.analyze(correction).correction_count >= 1, "passar e voltar deve registrar correção")


func _test_ten_attempt_summary() -> void:
	var attempts: Array[CalibrationAttempt] = []
	for index: int in range(10):
		var attempt := CalibrationAttempt.new()
		attempt.gesture = GestureAttempt.new()
		attempt.metrics = GestureMetrics.new()
		attempt.metrics.duration_ms = 180.0 + float(index % 3) * 5.0
		attempt.metrics.path_length_norm = 0.10 + float(index % 2) * 0.004
		attempt.metrics.peak_speed = 2.0 + float(index % 3) * 0.1
		attempt.metrics.straightness = 0.92 + float(index % 2) * 0.02
		attempt.metrics.correction_count = index % 2
		attempt.endpoint_error_length_norm = 0.02 + float(index % 2) * 0.003
		attempt.endpoint_error_norm = Vector2(0.004, 0.018)
		attempt.time_to_head_ms = 125.0 + float(index % 3) * 4.0
		attempt.classification = CalibrationAttempt.Classification.GOOD
		if index == 0:
			attempt.classification = CalibrationAttempt.Classification.PERFECT
		elif index == 8:
			attempt.classification = CalibrationAttempt.Classification.OVERSHOOT
		elif index == 9:
			attempt.classification = CalibrationAttempt.Classification.UNDERSHOOT
		attempts.append(attempt)
	var summary: CalibrationSessionSummary = CalibrationSessionSummary.from_attempts(attempts)
	_expect(summary.valid_attempts == 10, "resumo deve agregar 10 tentativas válidas")
	_expect(int(summary.classification_counts["GOOD"]) == 7, "resumo deve contar classificações")
	_expect(is_equal_approx(summary.overshoot_rate, 0.1), "taxa de overshoot deve ser robusta")
	_expect(summary.consistency_score > 0.8, "tentativas consistentes devem gerar score alto")
	_expect(summary.median_duration_ms >= 180.0 and summary.median_duration_ms <= 190.0, "duração mediana deve ser calculada")


func _test_fire_aim_flow(arena: Node) -> void:
	arena.call("reset_aim_to_chest")
	arena.call("_set_state", STATE_READY)
	var fire: FireAimRegion = arena.get_node("HUDLayer/HUD/FireRegion") as FireAimRegion
	var start: Vector2 = fire.global_position + fire.size * 0.5
	_send_touch(true, 22, Vector2(20.0, 300.0))
	await process_frame
	_expect(int(arena.get("state")) == STATE_READY, "toque fora do FIRE não pode iniciar tentativa")
	_expect(TouchManagerProxy.owner(_touch_manager, 22) == &"", "toque externo não pode receber ownership")
	_send_touch(false, 22, Vector2(20.0, 300.0))
	_send_touch(true, 23, start)
	await process_frame
	_expect(int(arena.get("state")) == STATE_AIMING, "FIRE deve capturar e iniciar AIMING")
	_expect(TouchManagerProxy.owner(_touch_manager, 23) == &"FIRE_AIM", "ownership deve ser FIRE_AIM")

	var position: Vector2 = start
	var reached_head: bool = false
	for step: int in range(1, 21):
		var next_position: Vector2 = start + Vector2(0.0, -float(step) * 5.0)
		_send_drag(23, next_position, next_position - position)
		position = next_position
		await physics_frame
		if int(arena.call("get_current_target_region")) == CalibrationHitRegion.Region.HEAD:
			reached_head = true
			break
	_expect(reached_head, "arrasto vertical deve alcançar HEAD")
	_send_touch(false, 23, position)
	await process_frame
	var attempts: Array = arena.get("_all_attempts") as Array
	_expect(attempts.size() == 1, "release deve finalizar exatamente uma tentativa")
	if attempts.size() == 1:
		var attempt: CalibrationAttempt = attempts[0] as CalibrationAttempt
		_expect(attempt.gesture.samples.size() >= 3, "samples do gesture devem ser preservados")
		_expect(attempt.metrics.path_length_norm > 0.005, "distância normalizada deve ser calculada")
		_expect(attempt.entered_head, "first head contact deve ser registrado")
		_expect(attempt.time_to_head_ms >= 0.0, "time_to_head deve ser calculado")
		_expect(attempt.classification != CalibrationAttempt.Classification.INVALID, "gesto válido não pode ser INVALID")
	_expect(not TouchManagerProxy.active(_touch_manager, 23), "finger deve ser liberado após release")

	# Força apenas os deadlines, mantendo a transição real SHOWING_RESULT →
	# PREPARING → READY, e comprova o reset automático no ChestTarget.
	arena.set("_state_deadline_usec", 0)
	await process_frame
	_expect(int(arena.get("state")) == STATE_PREPARING, "resultado deve preparar automaticamente a próxima tentativa")
	arena.set("_state_deadline_usec", 0)
	await process_frame
	await physics_frame
	_expect(int(arena.get("state")) == STATE_READY, "preparação deve voltar ao estado READY")
	_expect_region(int(arena.call("get_current_target_region")), CalibrationHitRegion.Region.CHEST, "reset entre tentativas deve mirar CHEST")

	await _perform_mouse_attempt(arena, fire, start)
	for attempt_index: int in range(2, 10):
		arena.call("reset_aim_to_chest")
		arena.call("_set_state", STATE_READY)
		var reached: bool = await _perform_screen_attempt(arena, 100 + attempt_index, start)
		_expect(reached, "tentativa %d deve alcançar HEAD" % (attempt_index + 1))

	var valid_attempts: Array = arena.get("_valid_attempts") as Array
	_expect(valid_attempts.size() == 10, "arena deve acumular exatamente 10 tentativas válidas")
	arena.set("_state_deadline_usec", 0)
	await process_frame
	_expect(int(arena.get("state")) == STATE_FINISHED, "dez tentativas devem finalizar a sessão")
	var summary_panel: PanelContainer = arena.get_node("HUDLayer/HUD/SummaryPanel") as PanelContainer
	_expect(summary_panel.visible, "sessão finalizada deve mostrar painel de resumo")


func _perform_mouse_attempt(arena: Node, fire: FireAimRegion, start: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	_touch_manager.call("_input", press)
	await process_frame
	_expect(int(arena.get("state")) == STATE_AIMING, "mouse down no FIRE deve iniciar AIMING")
	_expect(TouchManagerProxy.owner(_touch_manager, -1000) == &"FIRE_AIM", "mouse deve usar ownership FIRE_AIM")
	var previous: Vector2 = start
	for step: int in range(1, 21):
		var position: Vector2 = start + Vector2(0.0, -float(step) * 5.0)
		var motion := InputEventMouseMotion.new()
		motion.position = position
		motion.relative = position - previous
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		_touch_manager.call("_input", motion)
		previous = position
		await physics_frame
		if int(arena.call("get_current_target_region")) == CalibrationHitRegion.Region.HEAD:
			break
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = previous
	_touch_manager.call("_input", release)
	await process_frame
	_expect(not TouchManagerProxy.active(_touch_manager, -1000), "mouse finger deve ser liberado")


func _perform_screen_attempt(arena: Node, finger_id: int, start: Vector2) -> bool:
	_send_touch(true, finger_id, start)
	await process_frame
	var previous: Vector2 = start
	var reached_head: bool = false
	for step: int in range(1, 21):
		var position: Vector2 = start + Vector2(0.0, -float(step) * 5.0)
		_send_drag(finger_id, position, position - previous)
		previous = position
		await physics_frame
		if int(arena.call("get_current_target_region")) == CalibrationHitRegion.Region.HEAD:
			reached_head = true
			break
	_send_touch(false, finger_id, previous)
	await process_frame
	return reached_head


func _make_classification_attempt(error_norm: Vector2, entered_head: bool) -> CalibrationAttempt:
	var attempt := CalibrationAttempt.new()
	attempt.gesture = GestureAttempt.new()
	attempt.gesture.add_sample(TouchSample.create(1, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.0, 0.0))
	attempt.gesture.add_sample(TouchSample.create(2, Vector2.ONE, Vector2.ONE, Vector2.ONE, Vector2.ONE, 1.0, 1.0))
	attempt.endpoint_error_norm = error_norm
	attempt.endpoint_error_length_norm = error_norm.length()
	attempt.entered_head = entered_head
	return attempt


func _make_timed_gesture(interval_usec: int) -> GestureAttempt:
	var gesture := GestureAttempt.new()
	var points: Array[Vector2] = [
		Vector2(0.5, 0.72), Vector2(0.5, 0.62),
		Vector2(0.5, 0.52), Vector2(0.5, 0.42),
	]
	var timestamp: int = 1_000_000
	var previous: Vector2 = points[0]
	for point: Vector2 in points:
		var delta: Vector2 = point - previous
		var seconds: float = float(interval_usec) / 1_000_000.0
		gesture.add_sample(TouchSample.create(
			timestamp, point * Vector2(1280, 720), point,
			delta * Vector2(1280, 720), delta,
			delta.length() / maxf(seconds, 0.000001),
			delta.length() / maxf(seconds, 0.000001)
		))
		previous = point
		timestamp += interval_usec
	return gesture


func _expect_classification(
	attempt: CalibrationAttempt,
	thresholds: Dictionary,
	expected: CalibrationAttempt.Classification,
	message: String
) -> void:
	var actual: CalibrationAttempt.Classification = CalibrationClassifier.classify(attempt, thresholds)
	_expect(actual == expected, "%s: esperado %s, recebido %s" % [
		message,
		CalibrationAttempt.Classification.keys()[expected],
		CalibrationAttempt.Classification.keys()[actual],
	])


func _expect_region(
	actual: CalibrationHitRegion.Region,
	expected: CalibrationHitRegion.Region,
	message: String
) -> void:
	_expect(actual == expected, "%s: esperado %s, recebido %s" % [
		message,
		CalibrationHitRegion.region_name(expected),
		CalibrationHitRegion.region_name(actual),
	])


func _send_touch(pressed: bool, finger_id: int, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger_id
	event.position = position
	event.pressed = pressed
	_touch_manager.call("_input", event)


func _send_drag(finger_id: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger_id
	event.position = position
	event.relative = relative
	event.screen_relative = relative
	_touch_manager.call("_input", event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("[Mentor][Tests] %s" % message)


class TouchManagerProxy:
	static func owner(manager: Node, finger_id: int) -> StringName:
		return manager.call("get_touch_owner", finger_id) as StringName

	static func active(manager: Node, finger_id: int) -> bool:
		var touches: Dictionary = manager.get("active_touches")
		return touches.has(finger_id)
