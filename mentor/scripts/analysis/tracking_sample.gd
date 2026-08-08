class_name TrackingSample
extends RefCounted

var timestamp_usec: int = 0
## ChestTarget projetado menos o centro da tela, dividido pelo viewport.
var error_norm: Vector2 = Vector2.ZERO
var target_direction_x: float = 0.0


static func create(
	new_timestamp_usec: int,
	new_error_norm: Vector2,
	new_target_direction_x: float
) -> TrackingSample:
	var sample := TrackingSample.new()
	sample.timestamp_usec = new_timestamp_usec
	sample.error_norm = new_error_norm
	sample.target_direction_x = signf(new_target_direction_x)
	return sample


func to_dictionary() -> Dictionary:
	return {
		"timestamp_usec": timestamp_usec,
		"error_norm": [error_norm.x, error_norm.y],
		"target_direction_x": target_direction_x,
	}
