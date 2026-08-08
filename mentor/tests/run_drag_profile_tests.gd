extends SceneTree

var _failures: int = 0


func _init() -> void:
	var metrics_list: Array[GestureMetrics] = []
	for index: int in range(10):
		var gesture := _vertical_gesture(index)
		metrics_list.append(GestureAnalyzer.analyze(gesture))
	var profile: DragProfile = DragProfileAnalyzer.build(metrics_list)
	_expect(profile.sample_count == 10, "perfil deve agregar 10 puxadas")
	_expect(profile.verticality_score > 0.95, "puxadas verticais devem gerar verticalidade alta")
	_expect(profile.control_score > 0.75, "puxadas retas devem indicar controle alto")
	_expect(profile.consistency_score > 0.9, "série consistente deve manter score robusto")
	_expect(profile.length_classification == &"MÉDIA", "comprimento deve ter rótulo visual")
	_expect(profile.control_classification == &"ALTO", "controle deve ter rótulo visual")
	if _failures == 0:
		print("[Mentor][Tests] Natural Drag Profile passou.")
		quit(0)
	else:
		push_error("[Mentor][Tests] Drag profile falhou em %d ponto(s)." % _failures)
		quit(1)


func _vertical_gesture(variant: int) -> GestureAttempt:
	var gesture := GestureAttempt.new()
	var start := Vector2(0.5, 0.72)
	var distance: float = 0.105 + float(variant % 3) * 0.002
	var timestamp: int = 1_000_000
	var previous: Vector2 = start
	for step: int in range(6):
		var progress: float = float(step) / 5.0
		var point: Vector2 = start + Vector2(0.001 * sin(float(step)), -distance * progress)
		var delta: Vector2 = point - previous
		gesture.add_sample(TouchSample.create(
			timestamp, point * Vector2(1280.0, 720.0), point,
			delta * Vector2(1280.0, 720.0), delta, delta.length() * 10.0, delta.length() * 10.0
		))
		previous = point
		timestamp += 50_000 + variant * 200
	return gesture


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("[Mentor][Tests] %s" % message)
