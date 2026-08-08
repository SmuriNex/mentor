class_name SensitivitySearchController
extends RefCounted

enum Scope { GENERAL, RED_DOT }

const CONFIG_PATH: String = "res://data/sensitivity_search.json"

var scope: Scope = Scope.GENERAL
var results: Dictionary[int, SensitivityCandidateResult] = {}
var config: Dictionary = {}


func _init(new_scope: Scope = Scope.GENERAL) -> void:
	scope = new_scope
	config = _load_config()


func build_coarse_candidates(current_sensitivity: int = -1) -> PackedInt32Array:
	var candidates := PackedInt32Array()
	if current_sensitivity >= 0:
		var offsets: Array = config.get("current_offsets", [-30, -15, 0, 15, 30]) as Array
		for offset: Variant in offsets:
			_append_unique(candidates, clampi(current_sensitivity + int(offset), 0, 200))
	else:
		var key: String = "general_coarse" if scope == Scope.GENERAL else "red_dot_coarse"
		for candidate: Variant in config.get(key, [50, 90, 130, 170, 200]) as Array:
			_append_unique(candidates, clampi(int(candidate), 0, 200))
	return candidates


func register_result(result: SensitivityCandidateResult) -> void:
	results[result.sensitivity] = result
	result.eliminated = should_eliminate_early(result)


func should_eliminate_early(result: SensitivityCandidateResult) -> bool:
	var minimum: int = int(config.get("early_elimination_min_attempts", 3))
	if result.attempt_count < minimum:
		return false
	var extreme_rate: float = float(config.get("extreme_miss_rate", 0.9))
	if result.overshoot_rate >= extreme_rate or result.undershoot_rate >= extreme_rate:
		return true
	if result.median_endpoint_error >= float(config.get("extreme_endpoint_error", 0.11)):
		return true
	return false


func build_fine_candidates() -> PackedInt32Array:
	var ranked: Array[SensitivityCandidateResult] = _ranked_results(false)
	var candidates := PackedInt32Array()
	if ranked.is_empty():
		return candidates
	var step: int = int(config.get("fine_step", 5))
	var centers: Array[int] = [ranked[0].sensitivity]
	if ranked.size() > 1:
		centers.append(ranked[1].sensitivity)
		_append_if_untested(candidates, roundi((ranked[0].sensitivity + ranked[1].sensitivity) * 0.5))
	for center: int in centers:
		_append_if_untested(candidates, center - step)
		_append_if_untested(candidates, center + step)
	return candidates


func finalize_recommendation() -> SensitivityRecommendation:
	var recommendation := SensitivityRecommendation.new()
	recommendation.scope = &"GENERAL" if scope == Scope.GENERAL else &"RED_DOT"
	var ranked: Array[SensitivityCandidateResult] = _ranked_results(false)
	if ranked.is_empty():
		return recommendation
	var best_score: float = ranked[0].overall_score
	var tolerance: float = float(config.get("equivalent_score_tolerance", 0.035))
	var equivalent: Array[SensitivityCandidateResult] = []
	for result: SensitivityCandidateResult in ranked:
		if best_score - result.overall_score <= tolerance:
			equivalent.append(result)
	var sensitivities: Array[int] = []
	for result: SensitivityCandidateResult in equivalent:
		sensitivities.append(result.sensitivity)
	sensitivities.sort()
	recommendation.range_min = sensitivities[0]
	recommendation.range_max = sensitivities[-1]
	recommendation.recommended = sensitivities[sensitivities.size() / 2]
	recommendation.confidence = _calculate_confidence(ranked, equivalent)
	return recommendation


func validate_recommendation(
	recommendation: SensitivityRecommendation,
	validation_result: SensitivityCandidateResult
) -> bool:
	var baseline: SensitivityCandidateResult = results.get(recommendation.recommended)
	if baseline == null:
		return false
	recommendation.validation_score = validation_result.overall_score
	var minimum_ratio: float = float(config.get("validation_min_score_ratio", 0.9))
	recommendation.validated = validation_result.overall_score >= baseline.overall_score * minimum_ratio
	if recommendation.validated:
		recommendation.confidence = minf(recommendation.confidence + 0.1, 1.0)
	else:
		recommendation.confidence *= 0.75
	return recommendation.validated


func best_alternative(excluded_sensitivity: int) -> int:
	for result: SensitivityCandidateResult in _ranked_results(false):
		if result.sensitivity != excluded_sensitivity:
			return result.sensitivity
	return excluded_sensitivity


func _ranked_results(include_eliminated: bool) -> Array[SensitivityCandidateResult]:
	var ranked: Array[SensitivityCandidateResult] = []
	for result: SensitivityCandidateResult in results.values():
		if include_eliminated or not result.eliminated:
			ranked.append(result)
	ranked.sort_custom(func(a: SensitivityCandidateResult, b: SensitivityCandidateResult) -> bool:
		return a.overall_score > b.overall_score
	)
	return ranked


func _calculate_confidence(
	ranked: Array[SensitivityCandidateResult],
	equivalent: Array[SensitivityCandidateResult]
) -> float:
	var best: SensitivityCandidateResult = ranked[0]
	var quantity: float = clampf(float(best.attempt_count) / 12.0, 0.0, 1.0)
	var outlier_ratio: float = float(best.outlier_count) / float(maxi(best.attempt_count, 1))
	var separation: float = 0.0
	if ranked.size() > equivalent.size():
		separation = clampf(
			(best.overall_score - ranked[equivalent.size()].overall_score) / 0.15,
			0.0, 1.0
		)
	var range_penalty: float = clampf(float(equivalent.size() - 1) / 4.0, 0.0, 1.0)
	return clampf(
		quantity * 0.25 + best.consistency * 0.35 + separation * 0.25
		+ (1.0 - outlier_ratio) * 0.15 - range_penalty * 0.12,
		0.0, 1.0
	)


func _append_if_untested(candidates: PackedInt32Array, candidate: int) -> void:
	var safe: int = clampi(candidate, 0, 200)
	if not results.has(safe):
		_append_unique(candidates, safe)


func _append_unique(candidates: PackedInt32Array, value: int) -> void:
	if not candidates.has(value):
		candidates.append(value)


func _load_config() -> Dictionary:
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
