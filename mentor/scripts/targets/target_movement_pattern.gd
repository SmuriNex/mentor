class_name TargetMovementPattern
extends RefCounted

## Descreve uma trajetória lateral independente de FPS. A posição em qualquer
## instante é obtida integrando os segmentos anteriores, nunca acumulando delta
## de frames; por isso o mesmo pattern produz exatamente o mesmo resultado.


class Segment extends RefCounted:
	var start_time: float = 0.0
	var direction: Vector3 = Vector3.ZERO
	var speed: float = 0.0
	var duration: float = 0.0

	static func create(
		new_start_time: float,
		new_direction: Vector3,
		new_speed: float,
		new_duration: float
	) -> Segment:
		var segment := Segment.new()
		segment.start_time = maxf(new_start_time, 0.0)
		segment.direction = new_direction.normalized()
		segment.speed = maxf(new_speed, 0.0)
		segment.duration = maxf(new_duration, 0.0)
		return segment


var pattern_id: StringName = &"STATIONARY"
var duration: float = 0.0
var start_position: Vector3 = Vector3.ZERO
var segments: Array[Segment] = []


func sample_offset(elapsed_seconds: float, loop: bool = false) -> Vector3:
	var sample_time: float = _normalize_time(elapsed_seconds, loop)
	var result: Vector3 = start_position
	for segment: Segment in segments:
		var active_time: float = clampf(
			sample_time - segment.start_time,
			0.0,
			segment.duration
		)
		result += segment.direction * segment.speed * active_time
	return result


func direction_at(elapsed_seconds: float, loop: bool = false) -> Vector3:
	var sample_time: float = _normalize_time(elapsed_seconds, loop)
	for segment: Segment in segments:
		if sample_time >= segment.start_time \
		and sample_time < segment.start_time + segment.duration:
			return segment.direction
	return Vector3.ZERO


func duplicate_pattern() -> TargetMovementPattern:
	var copy := TargetMovementPattern.new()
	copy.pattern_id = pattern_id
	copy.duration = duration
	copy.start_position = start_position
	for segment: Segment in segments:
		copy.segments.append(Segment.create(
			segment.start_time, segment.direction, segment.speed, segment.duration
		))
	return copy


func _normalize_time(elapsed_seconds: float, loop: bool) -> float:
	var safe_time: float = maxf(elapsed_seconds, 0.0)
	if duration <= 0.0:
		return 0.0
	if loop:
		return fmod(safe_time, duration)
	return minf(safe_time, duration)
