extends Control


func _ready() -> void:
	AppState.current_screen = &"analysis_results"
	%MenuButton.pressed.connect(_menu)
	_render_results()


func _render_results() -> void:
	var general: SensitivityRecommendation = AnalysisRunner.general_recommendation
	var red_dot: SensitivityRecommendation = AnalysisRunner.red_dot_recommendation
	var profile: DragProfile = AnalysisRunner.drag_profile
	if general == null or red_dot == null:
		%Explanation.text = "Não há uma análise concluída nesta sessão."
		return
	%GeneralValue.text = str(general.recommended)
	%GeneralRange.text = "Faixa %d–%d  •  Confiança %.0f%%  •  %s" % [
		general.range_min, general.range_max, general.confidence * 100.0,
		"VALIDADA" if general.validated else "REVISAR"
	]
	%RedDotValue.text = str(red_dot.recommended)
	%RedDotRange.text = "Faixa %d–%d  •  Confiança %.0f%%  •  %s" % [
		red_dot.range_min, red_dot.range_max, red_dot.confidence * 100.0,
		"VALIDADA" if red_dot.validated else "REVISAR"
	]
	if profile != null:
		%Profile.text = (
			"Puxada: %s    Velocidade: %s    Controle: %s\n" % [
				profile.length_classification, profile.speed_classification,
				profile.control_classification]
			+ "Estabilidade %.0f%%    Consistência %.0f%%    Correções %.0f%%" % [
				profile.stability_score * 100.0, profile.consistency_score * 100.0,
				profile.correction_tendency * 100.0]
		)
	var codes: PackedStringArray = ResultExplainer.reason_codes(
		profile, general, AnalysisRunner.get("_all_results") as Array[SensitivityCandidateResult]
	)
	%ReasonCodes.text = "Sinais: %s" % ", ".join(codes)
	%Explanation.text = ResultExplainer.explanation(codes, general.recommended)
	%Comparison.text = _comparison_text(general, red_dot)
	%SavedPath.text = "Resultado salvo localmente: %s" % AnalysisRunner.saved_session_path


func _comparison_text(general: SensitivityRecommendation, red_dot: SensitivityRecommendation) -> String:
	var parts: Array[String] = []
	if AnalysisRunner.current_general >= 0:
		parts.append("Geral atual %d → recomendada %d (%+d)" % [
			AnalysisRunner.current_general, general.recommended,
			general.recommended - AnalysisRunner.current_general])
	if AnalysisRunner.current_red_dot >= 0:
		parts.append("Ponto Vermelho atual %d → recomendado %d (%+d)" % [
			AnalysisRunner.current_red_dot, red_dot.recommended,
			red_dot.recommended - AnalysisRunner.current_red_dot])
	return "\n".join(parts) if not parts.is_empty() else "Valores atuais não informados."


func _menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
