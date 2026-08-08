class_name SensitivityRecommendation
extends RefCounted

var scope: StringName = &"GENERAL"
var recommended: int = 100
var range_min: int = 90
var range_max: int = 110
var confidence: float = 0.0
var validated: bool = false
var validation_score: float = 0.0


func to_dictionary() -> Dictionary:
	return {
		"scope": String(scope),
		"recommended": recommended,
		"range_min": range_min,
		"range_max": range_max,
		"confidence": confidence,
		"validated": validated,
		"validation_score": validation_score,
	}
