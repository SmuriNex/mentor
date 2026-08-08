class_name ResultExplainer
extends RefCounted


static func reason_codes(
	profile: DragProfile,
	general: SensitivityRecommendation,
	results: Array[SensitivityCandidateResult]
) -> PackedStringArray:
	var codes := PackedStringArray()
	if profile != null:
		if profile.consistency_score >= 0.8: codes.append("HIGH_CONSISTENCY")
		elif profile.consistency_score < 0.55: codes.append("LOW_CONSISTENCY")
		if profile.drag_length_score < 0.5 and profile.drag_speed_score > 0.55:
			codes.append("FAST_SHORT_DRAG")
		if profile.control_score > 0.75 and profile.drag_length_score >= 0.6:
			codes.append("LONG_CONTROLLED_DRAG")
	var best: SensitivityCandidateResult
	for result: SensitivityCandidateResult in results:
		if result.sensitivity == general.recommended:
			best = result
			break
	if best != null:
		if best.overshoot_rate > 0.45: codes.append("HIGH_OVERSHOOT")
		if best.undershoot_rate > 0.45: codes.append("HIGH_UNDERSHOOT")
		if best.time_near_chest_ratio >= 0.7: codes.append("GOOD_TRACKING")
		if best.direction_change_delay > 420.0: codes.append("TRACKING_LAG")
		if best.median_corrections >= 2.0: codes.append("HIGH_CORRECTION_COUNT")
		if best.head_contact_rate >= 0.75: codes.append("GOOD_MOVING_ACCURACY")
	return codes


static func explanation(codes: PackedStringArray, general: int) -> String:
	var sentences: Array[String] = []
	if codes.has("FAST_SHORT_DRAG"):
		sentences.append("Você apresenta uma puxada curta e rápida.")
	elif codes.has("LONG_CONTROLLED_DRAG"):
		sentences.append("Sua puxada é mais longa e controlada.")
	if codes.has("HIGH_OVERSHOOT"):
		sentences.append("Nos valores mais altos houve mais overshoot e necessidade de correção.")
	elif codes.has("HIGH_UNDERSHOOT"):
		sentences.append("Nos valores mais baixos a mira demorou mais para alcançar a cabeça.")
	if codes.has("GOOD_TRACKING") or codes.has("GOOD_MOVING_ACCURACY"):
		sentences.append("A faixa escolhida equilibrou melhor tracking e precisão em alvos móveis.")
	if codes.has("LOW_CONSISTENCY"):
		sentences.append("Como seus gestos variaram, a faixa recomendada é mais ampla.")
	if sentences.is_empty():
		sentences.append("A recomendação equilibra rapidez, precisão, controle, consistência e tracking.")
	sentences.append("Por isso recomendamos começar com Geral %d." % general)
	return " ".join(sentences)
