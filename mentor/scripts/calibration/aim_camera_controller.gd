class_name AimCameraController
extends CharacterBody3D

## Converte deslocamento normalizado do dedo em yaw/pitch. Não contém qualquer
## análise de tentativa ou regra estatística.

@export_category("Camera experimental")
@export var camera_distance: float = 3.2
@export var camera_height: float = 1.65
@export var camera_side_offset: float = 0.32
## FOV experimental do simulador Mentor. Não representa valor confirmado do Free Fire.
@export_range(40.0, 100.0, 1.0) var camera_fov: float = 70.0
@export_range(35.0, 90.0, 1.0) var red_dot_fov: float = 55.0
@export_range(-89.0, 0.0, 1.0) var pitch_min: float = -80.0
@export_range(0.0, 89.0, 1.0) var pitch_max: float = 80.0
@export_category("Movimento experimental")
@export_range(0.5, 12.0, 0.1) var movement_speed: float = 4.2
@export_range(1.0, 12.0, 0.1) var jump_velocity: float = 5.2

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var camera: Camera3D = $YawPivot/PitchPivot/Camera3D

var yaw: float = 0.0
var pitch: float = 0.0
var virtual_sensitivity: float = 100.0
var curve_gain: float = 0.5
var angular_gain_rad_per_screen: float = 0.0
var movement_input: Vector2 = Vector2.ZERO
var _initial_global_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_initial_global_position = global_position
	_apply_camera_geometry()
	_apply_rotation()


func _physics_process(delta: float) -> void:
	var combined_input: Vector2 = movement_input + _keyboard_input()
	combined_input = combined_input.limit_length(1.0)
	var right: Vector3 = yaw_pivot.global_transform.basis.x
	var forward: Vector3 = -yaw_pivot.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()
	var desired: Vector3 = right * combined_input.x + forward * -combined_input.y
	velocity.x = desired.x * movement_speed
	velocity.z = desired.z * movement_speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y <= 0.0:
		velocity.y = 0.0
	move_and_slide()


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


func set_movement_input(input_value: Vector2) -> void:
	movement_input = input_value.limit_length(1.0)


func set_scope_mode(red_dot_enabled: bool) -> void:
	camera.fov = red_dot_fov if red_dot_enabled else camera_fov


func reset_player_translation() -> void:
	global_position = _initial_global_position
	velocity = Vector3.ZERO
	movement_input = Vector2.ZERO


func request_jump() -> bool:
	# Aceita também a pequena janela de contato inicial/coyote time. Em alguns
	# frames o body está encostado no chão antes de is_on_floor() ser atualizado.
	var near_ground: bool = global_position.y <= _initial_global_position.y + 0.05 \
	and velocity.y <= 0.0
	if not is_on_floor() and not near_ground:
		return false
	velocity.y = jump_velocity
	return true


func _apply_camera_geometry() -> void:
	pitch_pivot.position.y = camera_height
	camera.position = Vector3(camera_side_offset, 0.0, camera_distance)
	camera.fov = camera_fov


func _apply_rotation() -> void:
	yaw_pivot.rotation.y = yaw
	pitch_pivot.rotation.x = pitch


func _keyboard_input() -> Vector2:
	var input_value := Vector2.ZERO
	input_value.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	input_value.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	return input_value
