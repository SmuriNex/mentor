class_name AimCameraController
extends Node3D

## Converte deslocamento normalizado do dedo em yaw/pitch. Não contém qualquer
## análise de tentativa ou regra estatística.

@export_category("Camera experimental")
@export var camera_distance: float = 3.2
@export var camera_height: float = 1.65
@export var camera_side_offset: float = 0.32
## FOV experimental do simulador Mentor. Não representa valor confirmado do Free Fire.
@export_range(40.0, 100.0, 1.0) var camera_fov: float = 70.0
@export_range(-89.0, 0.0, 1.0) var pitch_min: float = -80.0
@export_range(0.0, 89.0, 1.0) var pitch_max: float = 80.0

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var camera: Camera3D = $YawPivot/PitchPivot/Camera3D

var yaw: float = 0.0
var pitch: float = 0.0
var virtual_sensitivity: float = 100.0
var curve_gain: float = 0.5
var angular_gain_rad_per_screen: float = 0.0


func _ready() -> void:
	_apply_camera_geometry()
	_apply_rotation()


func configure_sensitivity(
	sensitivity: float,
	curve: SensitivityCurve,
	angular_gain_degrees_at_full_scale: float
) -> void:
	virtual_sensitivity = clampf(sensitivity, 0.0, 200.0)
	curve_gain = curve.sample(virtual_sensitivity)
	angular_gain_rad_per_screen = deg_to_rad(
		angular_gain_degrees_at_full_scale * curve_gain
	)


func apply_touch_delta(delta_norm: Vector2) -> void:
	# Coordenadas de tela crescem para baixo. Portanto delta_norm.y negativo é
	# uma puxada para cima e deve AUMENTAR o pitch (olhar para cima).
	# Em Godot, yaw negativo vira a câmera para a direita, por isso o sinal de X.
	yaw -= delta_norm.x * angular_gain_rad_per_screen
	pitch -= delta_norm.y * angular_gain_rad_per_screen
	pitch = clampf(pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))
	_apply_rotation()


func reset_orientation(new_yaw: float = 0.0, new_pitch: float = 0.0) -> void:
	yaw = new_yaw
	pitch = clampf(new_pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))
	_apply_rotation()


func point_at_target(target: Node3D) -> void:
	# A câmera possui offset de ombro e orbita os pivôs. Recalcular algumas vezes
	# compensa a pequena mudança de posição da própria câmera após cada rotação.
	for iteration: int in range(4):
		var direction: Vector3 = (target.global_position - camera.global_position).normalized()
		yaw = atan2(-direction.x, -direction.z)
		var horizontal_length: float = Vector2(direction.x, direction.z).length()
		pitch = atan2(direction.y, horizontal_length)
		pitch = clampf(pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))
		_apply_rotation()


func get_camera() -> Camera3D:
	return camera


func get_rotation_state() -> Vector2:
	return Vector2(yaw, pitch)


func _apply_camera_geometry() -> void:
	pitch_pivot.position.y = camera_height
	camera.position = Vector3(camera_side_offset, 0.0, camera_distance)
	camera.fov = camera_fov


func _apply_rotation() -> void:
	yaw_pivot.rotation.y = yaw
	pitch_pivot.rotation.x = pitch
