class_name TouchSample
extends RefCounted

## Um sample imutável por convenção. Os dados brutos nunca recebem smoothing;
## trajetórias suavizadas devem ser derivadas em outra estrutura.

var timestamp_usec: int = 0
var position_px: Vector2 = Vector2.ZERO
var position_norm: Vector2 = Vector2.ZERO
var delta_px: Vector2 = Vector2.ZERO
var delta_norm: Vector2 = Vector2.ZERO
var instant_speed_px_s: float = 0.0
var instant_speed_norm_s: float = 0.0


static func create(
	p_timestamp_usec: int,
	p_position_px: Vector2,
	p_position_norm: Vector2,
	p_delta_px: Vector2,
	p_delta_norm: Vector2,
	p_speed_px_s: float,
	p_speed_norm_s: float
) -> TouchSample:
	var sample := TouchSample.new()
	sample.timestamp_usec = p_timestamp_usec
	sample.position_px = p_position_px
	sample.position_norm = p_position_norm
	sample.delta_px = p_delta_px
	sample.delta_norm = p_delta_norm
	sample.instant_speed_px_s = p_speed_px_s
	sample.instant_speed_norm_s = p_speed_norm_s
	return sample


func to_dictionary() -> Dictionary:
	return {
		"timestamp_usec": timestamp_usec,
		"position_px": [position_px.x, position_px.y],
		"position_norm": [position_norm.x, position_norm.y],
		"delta_px": [delta_px.x, delta_px.y],
		"delta_norm": [delta_norm.x, delta_norm.y],
		"instant_speed_px_s": instant_speed_px_s,
		"instant_speed_norm_s": instant_speed_norm_s,
	}
