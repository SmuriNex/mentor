extends Node

## Rastreador central de multitouch. Tempo, delta e velocidade são derivados de
## Time.get_ticks_usec(), portanto não dependem da taxa de quadros.

signal touch_started(finger_id: int, sample: TouchSample)
signal touch_sampled(finger_id: int, sample: TouchSample)
signal touch_ended(finger_id: int, sample: TouchSample, cancelled: bool)
signal all_touches_cancelled()

const MOUSE_FINGER_ID: int = -1000


class ActiveTouch extends RefCounted:
	var finger_id: int = -1
	var start_position_px: Vector2 = Vector2.ZERO
	var current_position_px: Vector2 = Vector2.ZERO
	var previous_position_px: Vector2 = Vector2.ZERO
	var start_timestamp_usec: int = 0
	var current_timestamp_usec: int = 0
	var total_distance_px: float = 0.0
	var total_distance_norm: float = 0.0
	var start_zone: StringName = &"UNKNOWN"
	var active: bool = true


var active_touches: Dictionary[int, ActiveTouch] = {}
var _touch_owners: Dictionary[int, StringName] = {}
var _mouse_down: bool = false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_begin_touch(touch.index, touch.position)
		else:
			_end_touch(touch.index, touch.position, touch.canceled)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_update_touch(drag.index, drag.position)
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = mouse_button.pressed
			if mouse_button.pressed:
				_begin_touch(MOUSE_FINGER_ID, mouse_button.position)
			else:
				_end_touch(MOUSE_FINGER_ID, mouse_button.position, false)
	elif event is InputEventMouseMotion and _mouse_down:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_touch(MOUSE_FINGER_ID, mouse_motion.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_every_touch()


func claim_touch(finger_id: int, owner: StringName) -> bool:
	if not active_touches.has(finger_id):
		return false
	var current_owner: StringName = _touch_owners.get(finger_id, &"")
	if current_owner != &"" and current_owner != owner:
		return false
	_touch_owners[finger_id] = owner
	return true


func release_touch(finger_id: int, owner: StringName) -> void:
	if _touch_owners.get(finger_id, &"") == owner:
		_touch_owners.erase(finger_id)


func get_touch_owner(finger_id: int) -> StringName:
	return _touch_owners.get(finger_id, &"")


func get_active_finger_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	for finger_id: int in active_touches:
		ids.append(finger_id)
	return ids


func get_active_touch(finger_id: int) -> ActiveTouch:
	return active_touches.get(finger_id) as ActiveTouch


func _begin_touch(finger_id: int, position: Vector2) -> void:
	# Eventos duplicados do mesmo dedo são finalizados antes de reiniciar o track.
	if active_touches.has(finger_id):
		_end_touch(finger_id, position, true)

	var timestamp_usec: int = Time.get_ticks_usec()
	var viewport_size: Vector2 = _safe_viewport_size()
	var normalized_position: Vector2 = position / viewport_size
	var track := ActiveTouch.new()
	track.finger_id = finger_id
	track.start_position_px = position
	track.current_position_px = position
	track.previous_position_px = position
	track.start_timestamp_usec = timestamp_usec
	track.current_timestamp_usec = timestamp_usec
	track.start_zone = _zone_from_position(normalized_position)
	active_touches[finger_id] = track

	var sample := TouchSample.create(
		timestamp_usec,
		position,
		normalized_position,
		Vector2.ZERO,
		Vector2.ZERO,
		0.0,
		0.0
	)
	touch_started.emit(finger_id, sample)


func _update_touch(finger_id: int, position: Vector2) -> void:
	if not active_touches.has(finger_id):
		# Recuperação defensiva para eventos de drag cujo press foi perdido pelo SO.
		_begin_touch(finger_id, position)
		return

	var track: ActiveTouch = active_touches[finger_id]
	var timestamp_usec: int = Time.get_ticks_usec()
	var elapsed_seconds: float = maxf(
		float(timestamp_usec - track.current_timestamp_usec) / 1_000_000.0,
		0.000001
	)
	var viewport_size: Vector2 = _safe_viewport_size()
	var delta_px: Vector2 = position - track.current_position_px
	var delta_norm: Vector2 = delta_px / viewport_size

	track.previous_position_px = track.current_position_px
	track.current_position_px = position
	track.current_timestamp_usec = timestamp_usec
	track.total_distance_px += delta_px.length()
	track.total_distance_norm += delta_norm.length()

	var sample := TouchSample.create(
		timestamp_usec,
		position,
		position / viewport_size,
		delta_px,
		delta_norm,
		delta_px.length() / elapsed_seconds,
		delta_norm.length() / elapsed_seconds
	)
	touch_sampled.emit(finger_id, sample)


func _end_touch(finger_id: int, position: Vector2, cancelled: bool) -> void:
	if not active_touches.has(finger_id):
		return

	# Registra a posição final se ela mudou desde o último drag.
	var track: ActiveTouch = active_touches[finger_id]
	if not position.is_equal_approx(track.current_position_px):
		_update_touch(finger_id, position)
		track = active_touches[finger_id]

	var viewport_size: Vector2 = _safe_viewport_size()
	var final_sample := TouchSample.create(
		Time.get_ticks_usec(),
		track.current_position_px,
		track.current_position_px / viewport_size,
		Vector2.ZERO,
		Vector2.ZERO,
		0.0,
		0.0
	)
	track.active = false
	touch_ended.emit(finger_id, final_sample, cancelled)
	_touch_owners.erase(finger_id)
	active_touches.erase(finger_id)


func _cancel_every_touch() -> void:
	var finger_ids: Array[int] = []
	for finger_id: int in active_touches:
		finger_ids.append(finger_id)
	for finger_id: int in finger_ids:
		var track: ActiveTouch = active_touches[finger_id]
		_end_touch(finger_id, track.current_position_px, true)
	_mouse_down = false
	all_touches_cancelled.emit()


func _safe_viewport_size() -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(maxf(viewport_size.x, 1.0), maxf(viewport_size.y, 1.0))


func _zone_from_position(position_norm: Vector2) -> StringName:
	if position_norm.x < 0.5:
		return &"LEFT"
	return &"RIGHT"
