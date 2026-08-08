class_name TargetMotionController
extends Node

const CONFIG_PATH: String = "res://data/target_motion_config.json"

signal direction_changed(
	elapsed_seconds: float,
	previous_direction: Vector3,
	new_direction: Vector3
)

enum MotionMode {
	STATIONARY,
	STRAFE_LEFT,
	STRAFE_RIGHT,
	STRAFE_CONTINUOUS,
	STRAFE_REVERSAL,
	VARIABLE_STRAFE,
}

enum SpeedLevel { SLOW, MEDIUM, FAST }

@export var motion_mode: MotionMode = MotionMode.STATIONARY
@export_range(0.1, 5.0, 0.05) var movement_speed: float = 1.0
@export_range(0.25, 5.0, 0.05) var horizontal_limit: float = 1.5
@export var auto_start: bool = false

var active_pattern: TargetMovementPattern
var elapsed_seconds: float = 0.0
var running: bool = false
var loop_pattern: bool = false
var _origin: Vector3 = Vector3.ZERO
var _last_direction: Vector3 = Vector3.ZERO

@onready var target: Node3D = get_parent() as Node3D


func _ready() -> void:
	_origin = target.global_position
	if auto_start and motion_mode != MotionMode.STATIONARY:
		start_mode(motion_mode)


func _physics_process(delta: float) -> void:
	if running:
		seek(elapsed_seconds + delta)


func start_mode(mode: MotionMode) -> void:
	motion_mode = mode
	var should_loop: bool = mode in [
		MotionMode.STRAFE_CONTINUOUS,
		MotionMode.STRAFE_REVERSAL,
		MotionMode.VARIABLE_STRAFE,
	]
	start_pattern(_build_mode_pattern(mode), should_loop)


func set_speed_level(level: SpeedLevel) -> void:
	var speed_names: Array[String] = ["SLOW", "MEDIUM", "FAST"]
	var config: Dictionary = _load_motion_config()
	var speeds: Dictionary = config.get("speeds", {}) as Dictionary
	movement_speed = float(speeds.get(speed_names[level], movement_speed))


func start_pattern(pattern: TargetMovementPattern, should_loop: bool = false) -> void:
	active_pattern = pattern.duplicate_pattern()
	loop_pattern = should_loop
	elapsed_seconds = 0.0
	_last_direction = Vector3.ZERO
	running = active_pattern.duration > 0.0 and not active_pattern.segments.is_empty()
	target.global_position = _origin + active_pattern.sample_offset(0.0, loop_pattern)
	_update_direction_signal()


func stop(reset_position: bool = true) -> void:
	running = false
	elapsed_seconds = 0.0
	_last_direction = Vector3.ZERO
	if reset_position:
		target.global_position = _origin


func seek(time_seconds: float) -> void:
	if active_pattern == null:
		return
	elapsed_seconds = maxf(time_seconds, 0.0)
	target.global_position = _origin + active_pattern.sample_offset(elapsed_seconds, loop_pattern)
	_update_direction_signal()
	if not loop_pattern and elapsed_seconds >= active_pattern.duration:
		running = false


func set_origin(new_origin: Vector3) -> void:
	_origin = new_origin
	if active_pattern != null:
		target.global_position = _origin + active_pattern.sample_offset(elapsed_seconds, loop_pattern)


func get_origin() -> Vector3:
	return _origin


func _update_direction_signal() -> void:
	var new_direction: Vector3 = active_pattern.direction_at(elapsed_seconds, loop_pattern)
	if not new_direction.is_equal_approx(_last_direction):
		direction_changed.emit(elapsed_seconds, _last_direction, new_direction)
		_last_direction = new_direction


func _build_mode_pattern(mode: MotionMode) -> TargetMovementPattern:
	var pattern := TargetMovementPattern.new()
	pattern.pattern_id = MotionMode.keys()[mode]
	var crossing_duration: float = (horizontal_limit * 2.0) / maxf(movement_speed, 0.001)
	match mode:
		MotionMode.STRAFE_LEFT:
			pattern.start_position = Vector3.RIGHT * horizontal_limit
			pattern.duration = crossing_duration
			pattern.segments.append(TargetMovementPattern.Segment.create(
				0.0, Vector3.LEFT, movement_speed, crossing_duration
			))
		MotionMode.STRAFE_RIGHT:
			pattern.start_position = Vector3.LEFT * horizontal_limit
			pattern.duration = crossing_duration
			pattern.segments.append(TargetMovementPattern.Segment.create(
				0.0, Vector3.RIGHT, movement_speed, crossing_duration
			))
		MotionMode.STRAFE_CONTINUOUS, MotionMode.STRAFE_REVERSAL:
			pattern.start_position = Vector3.LEFT * horizontal_limit
			pattern.duration = crossing_duration * 2.0
			pattern.segments.append(TargetMovementPattern.Segment.create(
				0.0, Vector3.RIGHT, movement_speed, crossing_duration
			))
			pattern.segments.append(TargetMovementPattern.Segment.create(
				crossing_duration, Vector3.LEFT, movement_speed, crossing_duration
			))
		MotionMode.VARIABLE_STRAFE:
			pattern.pattern_id = &"VARIABLE_A"
			pattern.start_position = Vector3(-0.7, 0.0, 0.0)
			pattern.duration = 3.0
			pattern.segments = [
				TargetMovementPattern.Segment.create(0.0, Vector3.RIGHT, movement_speed, 0.7),
				TargetMovementPattern.Segment.create(0.7, Vector3.LEFT, movement_speed, 0.7),
				TargetMovementPattern.Segment.create(1.4, Vector3.RIGHT, movement_speed * 0.8, 0.8),
				TargetMovementPattern.Segment.create(2.2, Vector3.LEFT, movement_speed * 1.2, 0.8),
			]
		_:
			pattern.duration = 0.0
	return pattern


func _load_motion_config() -> Dictionary:
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
