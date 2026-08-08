class_name CameraLookRegion
extends Control

## Área invisível destinada exclusivamente à rotação livre da câmera.
## A decisão de prioridade (FIRE antes de CAMERA_LOOK) fica na arena, pois ela
## conhece todos os botões específicos que podem ocupar esta área.


func contains_viewport_point(point: Vector2) -> bool:
	return get_global_rect().has_point(point)
