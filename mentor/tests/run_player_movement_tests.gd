extends SceneTree

var _failures: int = 0
var _touch_manager: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/calibration/calibration_arena.tscn") as PackedScene
	var arena: Node = packed.instantiate()
	root.add_child(arena)
	_touch_manager = root.get_node("TouchManager")
	await process_frame
	await physics_frame
	arena.call("_set_state", 1)
	await _test_joystick_and_camera(arena)
	await _test_joystick_and_fire_with_moving_target(arena)
	arena.queue_free()
	await process_frame
	if _failures == 0:
		print("[Mentor][Tests] Player movement e multitouch passaram.")
		quit(0)
	else:
		push_error("[Mentor][Tests] Player movement falhou em %d ponto(s)." % _failures)
		quit(1)


func _test_joystick_and_camera(arena: Node) -> void:
	var player: AimCameraController = arena.get_node("PlayerCalibrationRig") as AimCameraController
	var viewport: Vector2 = arena.get_viewport().get_visible_rect().size
	var stick_start := Vector2(viewport.x * 0.2, viewport.y * 0.72)
	var look_start := Vector2(viewport.x * 0.72, viewport.y * 0.38)
	_send_touch(true, 31, stick_start)
	_send_drag(31, stick_start + Vector2(70.0, 0.0))
	_send_touch(true, 32, look_start)
	_send_drag(32, look_start + Vector2(45.0, -20.0))
	await process_frame
	_expect(_owner(31) == &"JOYSTICK", "dedo esquerdo deve manter JOYSTICK")
	_expect(_owner(32) == &"CAMERA_LOOK", "segundo dedo deve manter CAMERA_LOOK")
	var start_position: Vector3 = player.global_position
	var rotation: Vector2 = player.get_rotation_state()
	for _frame: int in range(5):
		await physics_frame
	_expect(player.global_position.distance_to(start_position) > 0.01, "joystick deve mover CharacterBody3D")
	_expect(not rotation.is_equal_approx(Vector2.ZERO), "câmera deve girar simultaneamente")
	_send_touch(false, 32, look_start + Vector2(45.0, -20.0))
	_send_touch(false, 31, stick_start + Vector2(70.0, 0.0))
	await process_frame


func _test_joystick_and_fire_with_moving_target(arena: Node) -> void:
	arena.call("_set_state", 1)
	arena.call("start_target_motion", TargetMotionController.MotionMode.STRAFE_REVERSAL)
	var viewport: Vector2 = arena.get_viewport().get_visible_rect().size
	var stick_start := Vector2(viewport.x * 0.18, viewport.y * 0.72)
	var fire: FireAimRegion = arena.get_node("HUDLayer/HUD/FireRegion") as FireAimRegion
	var fire_start: Vector2 = fire.global_position + fire.size * 0.5
	_send_touch(true, 41, stick_start)
	_send_drag(41, stick_start + Vector2(-65.0, 0.0))
	_send_touch(true, 42, fire_start)
	await physics_frame
	_expect(_owner(41) == &"JOYSTICK", "JOYSTICK deve coexistir com FIRE")
	_expect(_owner(42) == &"FIRE_AIM", "FIRE deve manter ownership específico")
	_expect((arena.call("get_target_motion_controller") as TargetMotionController).running, "target deve mover com player + FIRE")
	var jump: JumpRegion = arena.get_node("HUDLayer/HUD/JumpRegion") as JumpRegion
	var jump_start: Vector2 = jump.global_position + jump.size * 0.5
	var player: AimCameraController = arena.get_node("PlayerCalibrationRig") as AimCameraController
	_send_touch(true, 43, jump_start)
	await physics_frame
	_expect(_owner(43) == &"JUMP", "terceiro dedo deve acionar JUMP sem roubar FIRE/JOYSTICK")
	_expect(player.velocity.y > 0.0, "pulo deve aplicar velocidade vertical positiva")
	_send_drag(42, fire_start + Vector2(0.0, -25.0))
	await physics_frame
	_send_touch(false, 43, jump_start)
	_send_touch(false, 42, fire_start + Vector2(0.0, -25.0))
	_send_touch(false, 41, stick_start + Vector2(-65.0, 0.0))
	await process_frame


func _send_touch(pressed: bool, finger_id: int, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger_id
	event.position = position
	event.pressed = pressed
	_touch_manager.call("_input", event)


func _send_drag(finger_id: int, position: Vector2) -> void:
	var active: Variant = _touch_manager.call("get_active_touch", finger_id)
	var previous: Vector2 = active.current_position_px if active != null else position
	var event := InputEventScreenDrag.new()
	event.index = finger_id
	event.position = position
	event.relative = position - previous
	event.screen_relative = event.relative
	_touch_manager.call("_input", event)


func _owner(finger_id: int) -> StringName:
	return _touch_manager.call("get_touch_owner", finger_id) as StringName


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("[Mentor][Tests] %s" % message)
