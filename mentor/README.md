# Mentor

Aplicativo mobile independente para análise de gestos de mira. O Mentor não abre, modifica, automatiza nem lê dados de jogos; todos os movimentos são realizados e analisados dentro do próprio aplicativo.

## Estado atual

- Projeto Godot 4.6 em Compatibility/OpenGL 3 e landscape.
- Menu principal responsivo.
- `TouchManager` multitouch com ownership por dedo e debug por mouse.
- Touch Lab com samples brutos, trajetória e métricas.
- Analisador matemático e testes sintéticos.
- Fluxo completo Preparação → Warmup → Perfil Natural → buscas Geral/Red Dot → Resultado.
- Calibration Arena 3D com câmera livre, FIRE drag, joystick, pulo e multitouch por ownership.
- TargetDummy com strafe esquerdo/direito, continuous, reversal e patterns determinísticos.
- Tracking normalizado, endpoint móvel, time-to-head, time-on-head, bias e direction delay.
- Busca adaptativa coarse/fine, score configurável, faixa, confiança e validação final.
- Persistência da sessão em `user://sessions/`; samples brutos somente em Developer Mode.

## Executar

Abra `project.godot` no Godot 4.6 e rode o projeto. `INICIAR ANÁLISE` abre a preparação e pergunta, opcionalmente, os valores atuais. `TOUCH LAB` mantém a ferramenta técnica anterior. No desktop, mouse controla câmera/FIRE e WASD auxilia o movimento; em Android, o fluxo usa multitouch nativo e ownership por dedo.

Testes matemáticos pela linha de comando:

```text
godot --headless --path . --script res://tests/run_math_tests.gd
```

Teste de integração da cadeia multitouch:

```text
godot --headless --path . --script res://tests/run_touch_integration.gd
```

Suíte completa:

```text
godot --headless --path . --script res://tests/run_calibration_arena_tests.gd
godot --headless --path . --script res://tests/run_target_motion_tests.gd
godot --headless --path . --script res://tests/run_tracking_tests.gd
godot --headless --path . --script res://tests/run_player_movement_tests.gd
godot --headless --path . --script res://tests/run_drag_profile_tests.gd
godot --headless --path . --script res://tests/run_sensitivity_search_tests.gd
godot --headless --path . --script res://tests/run_analysis_runner_tests.gd
godot --headless --path . --script res://tests/run_navigation_tests.gd
```

Consulte também [Arquitetura](docs/ARCHITECTURE.md), [Modelo de sensibilidade](docs/SENSITIVITY_MODEL.md), [Sistema de testes](docs/TEST_SYSTEM.md) e [Exportação mobile](docs/MOBILE_EXPORT.md).
