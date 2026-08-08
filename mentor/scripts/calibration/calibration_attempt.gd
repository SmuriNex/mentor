class_name CalibrationAttempt
extends RefCounted

## Contexto gameplay-like composto sobre GestureAttempt. Os samples motores
## continuam genéricos e compatíveis com Touch Lab.

enum Classification {
	INVALID,
	PERFECT,
	GOOD,
	UNDERSHOOT,
	OVERSHOOT,
	LATERAL_MISS,
}

var gesture: GestureAttempt
var metrics: GestureMetrics
var test_type: StringName = &"VERTICAL_HEADSHOT"
var virtual_sensitivity: float = 100.0
var start_camera_yaw: float = 0.0
var start_camera_pitch: float = 0.0
var end_camera_yaw: float = 0.0
var end_camera_pitch: float = 0.0
var started_target_region: CalibrationHitRegion.Region = CalibrationHitRegion.Region.NONE
var ended_target_region: CalibrationHitRegion.Region = CalibrationHitRegion.Region.NONE
var entered_head: bool = false
var first_head_contact_usec: int = -1
var time_on_head_ms: float = 0.0
var head_screen_position_px: Vector2 = Vector2.ZERO
## Erro = centro da mira - posição projetada da cabeça.
## Y positivo: mira abaixo da cabeça. Y negativo: mira acima da cabeça.
var endpoint_error_px: Vector2 = Vector2.ZERO
var endpoint_error_norm: Vector2 = Vector2.ZERO
var endpoint_error_length_px: float = 0.0
var endpoint_error_length_norm: float = 0.0
var time_to_head_ms: float = -1.0
var classification: Classification = Classification.INVALID


func classification_name() -> String:
	return Classification.keys()[classification]


func to_dictionary(include_raw_samples: bool = true) -> Dictionary:
	return {
		"test_type": String(test_type),
		"virtual_sensitivity": virtual_sensitivity,
		"start_camera_yaw": start_camera_yaw,
		"start_camera_pitch": start_camera_pitch,
		"end_camera_yaw": end_camera_yaw,
		"end_camera_pitch": end_camera_pitch,
		"started_target_region": CalibrationHitRegion.region_name(started_target_region),
		"ended_target_region": CalibrationHitRegion.region_name(ended_target_region),
		"entered_head": entered_head,
		"first_head_contact_usec": first_head_contact_usec,
		"time_on_head_ms": time_on_head_ms,
		"time_to_head_ms": time_to_head_ms,
		"head_screen_position_px": [head_screen_position_px.x, head_screen_position_px.y],
		"endpoint_error_px": [endpoint_error_px.x, endpoint_error_px.y],
		"endpoint_error_norm": [endpoint_error_norm.x, endpoint_error_norm.y],
		"endpoint_error_length_px": endpoint_error_length_px,
		"endpoint_error_length_norm": endpoint_error_length_norm,
		"classification": classification_name(),
		"gesture": gesture.to_dictionary(include_raw_samples) if gesture != null else {},
		"metrics": metrics.to_dictionary() if metrics != null else {},
	}
