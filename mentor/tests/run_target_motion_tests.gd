extends SceneTree

var _failures: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_pattern_determinism()
	var packed: PackedScene = load("res://scenes/calibration/target_dummy.tscn") as PackedScene
	var target: TargetDummy = packed.instantiate() as TargetDummy
	root.add_child(target)
	await process_frame
	_test_controller_directions(target)
	_test_markers_follow_target(target)
	target.queue_free()
	await process_frame
	if _failures == 0:
		print("[Mentor][Tests] Target motion e patterns determinísticos passaram.")
		quit(0)
	else:
		push_error("[Mentor][Tests] Target motion falhou em %d ponto(s)." % _failures)
		quit(1)


func _test_pattern_determinism() -> void:
	var pattern := _make_pattern()
	var direct: Vector3 = pattern.sample_offset(1.75)
	var repeated: Vector3 = Vector3.ZERO
	for _step: int in range(8):
		repeated = pattern.sample_offset(1.75)
	_expect(direct.is_equal_approx(repeated), "mesmo tempo deve reproduzir posição idêntica")
	_expect(is_equal_approx(direct.x, 0.14), "integração dos segmentos deve ser exata")
	_expect(pattern.direction_at(0.2) == Vector3.RIGHT, "primeiro segmento deve andar à direita")
	_expect(pattern.direction_at(0.9) == Vector3.LEFT, "reversal deve trocar para esquerda")
	var endpoints: Array[Vector3] = []
	for fps: float in [60.0, 90.0, 120.0]:
		var elapsed: float = 0.0
		while elapsed < 1.75:
			elapsed = minf(elapsed + 1.0 / fps, 1.75)
		endpoints.append(pattern.sample_offset(elapsed))
	_expect(endpoints[0].distance_to(endpoints[1]) < 0.00001, "pattern deve ser igual em 60/90 FPS")
	_expect(endpoints[1].distance_to(endpoints[2]) < 0.00001, "pattern deve ser igual em 90/120 FPS")


func _test_controller_directions(target: TargetDummy) -> void:
	var controller: TargetMotionController = target.motion_controller
	var origin: Vector3 = target.global_position
	controller.start_mode(TargetMotionController.MotionMode.STRAFE_LEFT)
	var left_start: float = target.global_position.x
	controller.seek(0.5)
	_expect(target.global_position.x < left_start, "STRAFE_LEFT deve reduzir X")
	controller.stop()
	controller.start_mode(TargetMotionController.MotionMode.STRAFE_RIGHT)
	var right_start: float = target.global_position.x
	controller.seek(0.5)
	_expect(target.global_position.x > right_start, "STRAFE_RIGHT deve aumentar X")
	controller.stop()
	_expect(target.global_position.is_equal_approx(origin), "stop deve restaurar origem")


func _test_markers_follow_target(target: TargetDummy) -> void:
	var controller: TargetMotionController = target.motion_controller
	var head: Marker3D = target.get_node("HeadTarget") as Marker3D
	var local_head: Vector3 = head.position
	controller.start_mode(TargetMotionController.MotionMode.STRAFE_CONTINUOUS)
	controller.seek(0.65)
	_expect(head.global_position.is_equal_approx(target.global_position + local_head), "HeadTarget deve acompanhar movimento")
	controller.stop()


func _make_pattern() -> TargetMovementPattern:
	var pattern := TargetMovementPattern.new()
	pattern.pattern_id = &"TEST_REVERSAL"
	pattern.duration = 2.0
	pattern.start_position = Vector3.ZERO
	pattern.segments = [
		TargetMovementPattern.Segment.create(0.0, Vector3.RIGHT, 1.0, 0.7),
		TargetMovementPattern.Segment.create(0.7, Vector3.LEFT, 1.2, 0.7),
		TargetMovementPattern.Segment.create(1.4, Vector3.RIGHT, 0.8, 0.6),
	]
	return pattern


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("[Mentor][Tests] %s" % message)
