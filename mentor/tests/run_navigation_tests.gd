extends SceneTree

var _failures: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _open_menu()
	var start_button: Button = current_scene.get_node("%StartButton") as Button
	start_button.pressed.emit()
	await process_frame
	await process_frame
	_expect(current_scene != null and current_scene.name == "AnalysisSetup", "INICIAR ANÁLISE deve abrir preparação")
	var begin_button: Button = current_scene.get_node("%BeginButton") as Button
	begin_button.pressed.emit()
	await process_frame
	await process_frame
	_expect(current_scene != null and current_scene.name == "CalibrationArena", "preparação deve iniciar CalibrationArena")
	var runner: MentorAnalysisRunner = root.get_node("AnalysisRunner") as MentorAnalysisRunner
	_expect(runner.current_phase == MentorAnalysisRunner.Phase.WARMUP, "arena deve iniciar pelo WARMUP")
	runner.cancel_analysis()

	await _open_menu()
	var lab_button: Button = current_scene.get_node("%TouchLabButton") as Button
	lab_button.pressed.emit()
	await process_frame
	await process_frame
	_expect(current_scene != null and current_scene.name == "TouchLab", "TOUCH LAB deve continuar abrindo TouchLab")

	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	if _failures == 0:
		print("[Mentor][Tests] Navegação Menu → Preparação → Arena/Touch Lab passou.")
		quit(0)
	else:
		push_error("[Mentor][Tests] Navegação falhou em %d ponto(s)." % _failures)
		quit(1)


func _open_menu() -> void:
	var error: Error = change_scene_to_file("res://scenes/menu/main_menu.tscn")
	_expect(error == OK, "Menu deve carregar")
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("[Mentor][Tests] %s" % message)
