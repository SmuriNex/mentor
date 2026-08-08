extends Node

## Persistência JSON local e tolerante a falhas. Dados corrompidos nunca impedem
## o aplicativo de iniciar.

const SETTINGS_PATH: String = "user://settings.json"
const SAMPLES_DIRECTORY: String = "user://samples"
const SESSIONS_DIRECTORY: String = "user://sessions"


func _ready() -> void:
	_ensure_directory(SAMPLES_DIRECTORY)
	_ensure_directory(SESSIONS_DIRECTORY)


func save_settings(settings: Dictionary) -> Error:
	return _write_json(SETTINGS_PATH, settings)


func load_settings(defaults: Dictionary = {}) -> Dictionary:
	return _read_json(SETTINGS_PATH, defaults)


func save_touch_sample(attempt: GestureAttempt, metrics: GestureMetrics) -> String:
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var file_path: String = "%s/touch_%s_%d.json" % [
		SAMPLES_DIRECTORY,
		timestamp,
		Time.get_ticks_usec(),
	]
	var payload: Dictionary = {
		"app": AppState.app_name,
		"app_version": AppState.app_version,
		"algorithm_version": AppState.algorithm_version,
		"saved_at": Time.get_datetime_string_from_system(true),
		"attempt": attempt.to_dictionary(true),
		"metrics": metrics.to_dictionary(),
	}
	var error: Error = _write_json(file_path, payload)
	if error != OK:
		push_error("[Mentor][Storage] Falha ao salvar amostra: %s" % error_string(error))
		return ""
	return file_path


func save_analysis_session(payload: Dictionary) -> String:
	var session_id: String = str(payload.get("session_id", "session_%d" % Time.get_ticks_usec()))
	var safe_id: String = session_id.replace(":", "-").replace("/", "-").replace("\\", "-")
	var file_path: String = "%s/%s.json" % [SESSIONS_DIRECTORY, safe_id]
	var error: Error = _write_json(file_path, payload)
	if error != OK:
		push_error("[Mentor][Storage] Falha ao salvar sessão: %s" % error_string(error))
		return ""
	return file_path


func _read_json(path: String, defaults: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return defaults.duplicate(true)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[Mentor][Storage] Não foi possível abrir %s." % path)
		return defaults.duplicate(true)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("[Mentor][Storage] JSON inválido em %s; defaults restaurados." % path)
		return defaults.duplicate(true)
	return (parsed as Dictionary).duplicate(true)


func _write_json(path: String, data: Dictionary) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "  "))
	return OK


func _ensure_directory(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var error: Error = DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("[Mentor][Storage] Falha ao criar diretório %s." % path)
