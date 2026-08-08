class_name TrackingMetrics
extends RefCounted

var tracking_error_mean: float = 0.0
var tracking_error_median: float = 0.0
var tracking_error_peak: float = 0.0
var time_near_chest_ratio: float = 0.0
var tracking_stability: float = 0.0
var horizontal_bias: float = 0.0
var correction_count: int = 0
var direction_change_delay_ms: float = -1.0
var direction_change_count: int = 0
var sample_count: int = 0


func to_dictionary() -> Dictionary:
	return {
		"tracking_error_mean": tracking_error_mean,
		"tracking_error_median": tracking_error_median,
		"tracking_error_peak": tracking_error_peak,
		"time_near_chest_ratio": time_near_chest_ratio,
		"tracking_stability": tracking_stability,
		"horizontal_bias": horizontal_bias,
		"correction_count": correction_count,
		"direction_change_delay_ms": direction_change_delay_ms,
		"direction_change_count": direction_change_count,
		"sample_count": sample_count,
	}
