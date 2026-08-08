class_name TargetDummy
extends Node3D

## Preparação mínima para etapas futuras. A Arena V1 usa STATIONARY; STRAFE é
## apenas um modo declarado e não executa IA ou movimento nesta fase.

enum MotionMode {
	STATIONARY,
	STRAFE,
}

@export var motion_mode: MotionMode = MotionMode.STATIONARY
