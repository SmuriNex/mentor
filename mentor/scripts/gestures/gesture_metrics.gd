class_name GestureMetrics
extends RefCounted

var duration_ms: float = 0.0
var time_to_target_ms: float = -1.0
var reaction_time_ms: float = -1.0

var path_length_px: float = 0.0
var path_length_norm: float = 0.0
var net_displacement_px: Vector2 = Vector2.ZERO
var net_displacement_norm: Vector2 = Vector2.ZERO
var vertical_displacement_norm: float = 0.0
var horizontal_displacement_norm: float = 0.0

var mean_speed: float = 0.0
var median_speed: float = 0.0
var peak_speed: float = 0.0
var initial_speed: float = 0.0
var final_speed: float = 0.0
var mean_acceleration: float = 0.0
var peak_acceleration: float = 0.0
var deceleration: float = 0.0

var straightness: float = 0.0
var movement_efficiency: float = 0.0
var principal_angle_deg: float = 0.0
var vertical_bias: float = 0.0
var horizontal_bias: float = 0.0
var direction_changes: int = 0

var overshoot: float = 0.0
var undershoot: float = 0.0
var endpoint_error: float = 0.0
var correction_count: int = 0
var correction_distance: float = 0.0
var tremor_score: float = 0.0
var j_shape_score: float = 0.0
var half_moon_score: float = 0.0


func to_dictionary() -> Dictionary:
	return {
		"duration_ms": duration_ms,
		"time_to_target_ms": time_to_target_ms,
		"reaction_time_ms": reaction_time_ms,
		"path_length_px": path_length_px,
		"path_length_norm": path_length_norm,
		"net_displacement_px": [net_displacement_px.x, net_displacement_px.y],
		"net_displacement_norm": [net_displacement_norm.x, net_displacement_norm.y],
		"vertical_displacement_norm": vertical_displacement_norm,
		"horizontal_displacement_norm": horizontal_displacement_norm,
		"mean_speed_norm_s": mean_speed,
		"median_speed_norm_s": median_speed,
		"peak_speed_norm_s": peak_speed,
		"initial_speed_norm_s": initial_speed,
		"final_speed_norm_s": final_speed,
		"mean_acceleration_norm_s2": mean_acceleration,
		"peak_acceleration_norm_s2": peak_acceleration,
		"deceleration_norm_s2": deceleration,
		"straightness": straightness,
		"movement_efficiency": movement_efficiency,
		"principal_angle_deg": principal_angle_deg,
		"vertical_bias": vertical_bias,
		"horizontal_bias": horizontal_bias,
		"direction_changes": direction_changes,
		"overshoot": overshoot,
		"undershoot": undershoot,
		"endpoint_error": endpoint_error,
		"correction_count": correction_count,
		"correction_distance": correction_distance,
		"tremor_score": tremor_score,
		"j_shape_score": j_shape_score,
		"half_moon_score": half_moon_score,
	}
