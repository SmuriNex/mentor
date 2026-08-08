extends SceneTree

var _failures: int = 0
var _touch_manager: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene: PackedScene = load("res://scenes/tests/touch_lab.tscn") as PackedScene
	var lab: Control = packed_scene.instantiate() as Control
	root.add_child(lab)
	await process_frame
	await process_frame
	_touch_manager = root.get_node("TouchManager")

	var trail: Control = lab.get_node("%TrailView") as Control
	var start: Vector2 = trail.global_position + trail.size * Vector2(0.55, 0.75)
	_send_touch(true, 7, start)
	await process_frame
	_expect(int(lab.get("_active_finger_id")) == 7, "Touch Lab deve capturar o finger dentro da área")

	var previous: Vector2 = start
	for offset: Vector2 in [Vector2(4, -24), Vector2(7, -56), Vector2(9, -94), Vector2(12, -138)]:
		var position: Vector2 = start + offset
		_send_drag(7, position, position - previous)
		previous = position
		await process_frame

	_send_touch(false, 7, previous)
	await process_frame

	var attempt: GestureAttempt = lab.get("_last_attempt") as GestureAttempt
	var metrics: GestureMetrics = lab.get("_last_metrics") as GestureMetrics
	_expect(attempt != null, "Touch Lab deve finalizar uma GestureAttempt")
	_expect(metrics != null, "Touch Lab deve calcular GestureMetrics")
	if attempt != null:
		_expect(attempt.samples.size() >= 5, "A tentativa deve preservar samples brutos")
		_expect(attempt.finger_id == 7, "O finger_id deve permanecer associado ao gesto")
		_expect(attempt.viewport_size.x > 0.0, "A viewport deve ser registrada")
	if metrics != null:
		_expect(metrics.path_length_norm > 0.0, "A distância normalizada deve ser positiva")
		_expect(metrics.duration_ms >= 0.0, "A duração deve ser calculada")
	var active_touches: Dictionary = _touch_manager.get("active_touches")
	_expect(not active_touches.has(7), "O finger deve ser liberado ao final")

	lab.queue_free()
	if _failures == 0:
		print("[Mentor][Tests] Integração TouchManager → Touch Lab passou.")
		quit(0)
	else:
		push_error("[Mentor][Tests] Integração touch falhou em %d ponto(s)." % _failures)
		quit(1)


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
