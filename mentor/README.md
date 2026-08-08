# Mentor

Aplicativo mobile independente para análise de gestos de mira. O Mentor não abre, modifica, automatiza nem lê dados de jogos; todos os movimentos são realizados e analisados dentro do próprio aplicativo.

## Estado atual

- Projeto Godot 4.6 em Compatibility/OpenGL 3 e landscape.
- Menu principal responsivo.
- `TouchManager` multitouch com ownership por dedo e debug por mouse.
- Touch Lab com samples brutos, trajetória e métricas.
- Analisador matemático e testes sintéticos.
- Calibration Arena 3D V1 com camera rig, TargetDummy e mira central.
- Regiões lógicas `HEAD`, `CHEST` e `BODY` detectadas por raycast central.
- Teste `VERTICAL_HEADSHOT` com 10 tentativas, feedback e resumo robusto.
- Persistência local de amostras em `user://samples/`.

## Executar

Abra `project.godot` no Godot 4.6 e rode o projeto. `INICIAR ANÁLISE` abre a Calibration Arena; `TOUCH LAB` mantém a ferramenta técnica anterior. No desktop, pressione FIRE com o botão esquerdo, arraste e solte. Em Android, o mesmo fluxo usa `InputEventScreenTouch`/`InputEventScreenDrag` e finger ownership.

Testes matemáticos pela linha de comando:

```text
godot --headless --path . --script res://tests/run_math_tests.gd
```

Teste de integração da cadeia multitouch:

```text
godot --headless --path . --script res://tests/run_touch_integration.gd
```

Arena e navegação:

```text
godot --headless --path . --script res://tests/run_calibration_arena_tests.gd
godot --headless --path . --script res://tests/run_navigation_tests.gd
```

Consulte também [Arquitetura](docs/ARCHITECTURE.md), [Modelo de sensibilidade](docs/SENSITIVITY_MODEL.md), [Sistema de testes](docs/TEST_SYSTEM.md) e [Exportação mobile](docs/MOBILE_EXPORT.md).
