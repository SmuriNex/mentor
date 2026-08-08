extends Control

@onready var title_label: Label = %TitleLabel
@onready var version_label: Label = %VersionLabel
@onready var info_label: Label = %InfoLabel
@onready var developer_toggle: CheckBox = %DeveloperToggle


func _ready() -> void:
	AppState.current_screen = &"menu"
	var saved_settings: Dictionary = LocalStorage.load_settings({"developer_mode": false})
	AppState.developer_mode = bool(saved_settings.get("developer_mode", false))
	title_label.text = AppState.app_name
	version_label.text = "Analisador independente de gestos • v%s" % AppState.app_version
	info_label.text = AppState.privacy_message
	developer_toggle.button_pressed = AppState.developer_mode
	%StartButton.pressed.connect(_open_calibration_arena)
	%TouchLabButton.pressed.connect(_open_touch_lab)
	%TrainingButton.pressed.connect(_show_milestone_message.bind("Treino Livre"))
	%ResultsButton.pressed.connect(_show_milestone_message.bind("Resultados"))
	%HistoryButton.pressed.connect(_show_milestone_message.bind("Histórico"))
	%SettingsButton.pressed.connect(_show_milestone_message.bind("Configurações"))
	developer_toggle.toggled.connect(_on_developer_mode_toggled)


func _open_touch_lab() -> void:
	get_tree().change_scene_to_file("res://scenes/tests/touch_lab.tscn")


func _open_calibration_arena() -> void:
	get_tree().change_scene_to_file("res://scenes/calibration/calibration_arena.tscn")


func _show_milestone_message(feature_name: String) -> void:
	info_label.text = "%s será habilitado nos próximos milestones. O Touch Lab já está funcional." % feature_name


func _on_developer_mode_toggled(enabled: bool) -> void:
	AppState.developer_mode = enabled
	var settings: Dictionary = LocalStorage.load_settings()
	settings["developer_mode"] = enabled
	LocalStorage.save_settings(settings)
