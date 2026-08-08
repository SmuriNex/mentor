class_name MentorTestDefinition
extends RefCounted

var test_type: StringName = &"STATIC_HEADSHOT"
var target_motion: TargetMotionController.MotionMode = TargetMotionController.MotionMode.STATIONARY
var player_motion: StringName = &"STATIC"
var scope_mode: StringName = &"GENERAL"
var candidate_sensitivity: int = 100
var attempt_count: int = 3
var tracking_enabled: bool = false
var fire_required: bool = true
var weight: float = 1.0


func to_dictionary() -> Dictionary:
	return {
		"test_type": String(test_type),
		"target_motion": TargetMotionController.MotionMode.keys()[target_motion],
		"player_motion": String(player_motion),
		"scope_mode": String(scope_mode),
		"candidate_sensitivity": candidate_sensitivity,
		"attempt_count": attempt_count,
		"tracking_enabled": tracking_enabled,
		"fire_required": fire_required,
		"weight": weight,
	}
