class_name DragProfile
extends RefCounted

var sample_count: int = 0
var drag_length_score: float = 0.0
var drag_speed_score: float = 0.0
var stability_score: float = 0.0
var control_score: float = 0.0
var verticality_score: float = 0.0
var consistency_score: float = 0.0
var correction_tendency: float = 0.0

var median_duration_ms: float = 0.0
var median_path_length_norm: float = 0.0
var median_speed: float = 0.0
var median_peak_speed: float = 0.0
var median_initial_speed: float = 0.0
var median_acceleration: float = 0.0
var median_principal_angle_deg: float = 0.0

var length_classification: StringName = &"MÉDIA"
var speed_classification: StringName = &"MÉDIA"
var control_classification: StringName = &"MÉDIO"


func to_dictionary() -> Dictionary:
	return {
		"sample_count": sample_count,
		"drag_length_score": drag_length_score,
		"drag_speed_score": drag_speed_score,
		"stability_score": stability_score,
		"control_score": control_score,
		"verticality_score": verticality_score,
		"consistency_score": consistency_score,
		"correction_tendency": correction_tendency,
		"median_duration_ms": median_duration_ms,
		"median_path_length_norm": median_path_length_norm,
		"median_speed": median_speed,
		"median_peak_speed": median_peak_speed,
		"median_initial_speed": median_initial_speed,
		"median_acceleration": median_acceleration,
		"median_principal_angle_deg": median_principal_angle_deg,
		"length_classification": String(length_classification),
		"speed_classification": String(speed_classification),
		"control_classification": String(control_classification),
	}
