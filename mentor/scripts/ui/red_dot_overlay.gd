class_name RedDotOverlay
extends Control


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.34
	# Vinheta experimental para diferenciar o teste de Ponto Vermelho. Não tenta
	# reproduzir uma ótica ou FOV oficial de nenhum jogo.
	draw_circle(center, radius + 18.0, Color(0.01, 0.015, 0.02, 0.58))
	draw_circle(center, radius, Color(0.02, 0.03, 0.04, 0.04))
	draw_arc(center, radius, 0.0, TAU, 96, Color(0.58, 0.65, 0.72, 0.7), 4.0)
	draw_circle(center, 3.5, Color(1.0, 0.12, 0.10, 0.95))
