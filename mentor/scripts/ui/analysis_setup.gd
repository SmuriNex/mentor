extends Control

@onready var general_value: SpinBox = %GeneralValue
@onready var red_dot_value: SpinBox = %RedDotValue
@onready var general_unknown: CheckBox = %GeneralUnknown
@onready var red_dot_unknown: CheckBox = %RedDotUnknown


func _ready() -> void:
	AppState.current_screen = &"analysis_setup"
	var settings: Dictionary = LocalStorage.load_settings()
	general_value.value = float(settings.get("current_general", 100))
	red_dot_value.value = float(settings.get("current_red_dot", 100))
	general_unknown.button_pressed = bool(settings.get("general_unknown", true))
	red_dot_unknown.button_pressed = bool(settings.get("red_dot_unknown", true))
	general_unknown.toggled.connect(_update_fields)
	red_dot_unknown.toggled.connect(_update_fields)
	%BeginButton.pressed.connect(_begin)
	%BackButton.pressed.connect(_back)
	_update_fields(false)


func _update_fields(_pressed: bool) -> void:
	general_value.editable = not general_unknown.button_pressed
	red_dot_value.editable = not red_dot_unknown.button_pressed


func _begin() -> void:
	var current_general: int = -1 if general_unknown.button_pressed else roundi(general_value.value)
	var current_red_dot: int = -1 if red_dot_unknown.button_pressed else roundi(red_dot_value.value)
	var settings: Dictionary = LocalStorage.load_settings()
	settings["current_general"] = roundi(general_value.value)
	settings["current_red_dot"] = roundi(red_dot_value.value)
	settings["general_unknown"] = general_unknown.button_pressed
	settings["red_dot_unknown"] = red_dot_unknown.button_pressed
	LocalStorage.save_settings(settings)
	AnalysisRunner.begin_analysis(current_general, current_red_dot)
	get_tree().change_scene_to_file("res://scenes/calibration/calibration_arena.tscn")


func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
