class_name TargetDummy
extends Node3D

## O visual, as áreas de colisão e os Markers permanecem filhos deste nó. Assim,
## todos acompanham automaticamente a trajetória aplicada pelo controller.

@onready var motion_controller: TargetMotionController = $MotionController


func start_motion(mode: TargetMotionController.MotionMode) -> void:
	motion_controller.start_mode(mode)


func stop_motion(reset_position: bool = true) -> void:
	motion_controller.stop(reset_position)
