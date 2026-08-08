extends Node

## Estado global pequeno e deliberado. O nome exibido e as versões ficam no
## app_config.json para não serem repetidos pelas telas.

const CONFIG_PATH: String = "res://data/app_config.json"

var app_name: String = "Mentor"
var app_version: String = "0.1.0"
var algorithm_version: String = "1.0.0-dev"
var privacy_message: String = "Seus testes ficam armazenados apenas neste dispositivo."
var developer_mode: bool = false
var current_screen: StringName = &"menu"


func _ready() -> void:
	_load_app_config()


func _load_app_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("[Mentor][App] app_config.json ausente; usando valores seguros.")
		return

	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("[Mentor][App] Não foi possível abrir app_config.json.")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("[Mentor][App] app_config.json inválido; usando defaults.")
		return

	var config: Dictionary = parsed as Dictionary
	app_name = str(config.get("app_name", app_name))
	app_version = str(config.get("app_version", app_version))
	algorithm_version = str(config.get("algorithm_version", algorithm_version))
	privacy_message = str(config.get("privacy_message", privacy_message))
