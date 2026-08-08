class_name GestureAttempt
extends RefCounted

## Conjunto bruto de samples pertencentes a um único finger_id.

var gesture_type: StringName = &"UNCLASSIFIED"
var finger_id: int = -1
var started_usec: int = 0
var ended_usec: int = 0
var viewport_size: Vector2 = Vector2.ONE
var screen_dpi: float = 0.0
var start_zone: StringName = &"UNKNOWN"
var samples: Array[TouchSample] = []
var was_cancelled: bool = false
var is_valid: bool = true
var invalid_reason: StringName = &""
var metadata: Dictionary = {}


func add_sample(sample: TouchSample) -> void:
	if samples.is_empty():
		started_usec = sample.timestamp_usec
	samples.append(sample)
	ended_usec = sample.timestamp_usec


func duration_seconds() -> float:
	if samples.size() < 2:
		return 0.0
	return float(ended_usec - started_usec) / 1_000_000.0


func to_dictionary(include_raw_samples: bool = true) -> Dictionary:
	var result: Dictionary = {
		"gesture_type": String(gesture_type),
		"finger_id": finger_id,
		"started_usec": started_usec,
		"ended_usec": ended_usec,
		"viewport": [viewport_size.x, viewport_size.y],
		"screen_dpi": screen_dpi,
		"start_zone": String(start_zone),
		"was_cancelled": was_cancelled,
		"is_valid": is_valid,
		"invalid_reason": String(invalid_reason),
		"metadata": metadata.duplicate(true),
	}
	if include_raw_samples:
		var raw_samples: Array[Dictionary] = []
		for sample: TouchSample in samples:
			raw_samples.append(sample.to_dictionary())
		result["samples"] = raw_samples
	return result
