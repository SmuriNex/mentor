# Mentor

Aplicativo mobile independente para análise de gestos de mira. O Mentor não abre, modifica, automatiza nem lê dados de jogos; todos os movimentos são realizados e analisados dentro do próprio aplicativo.

## Estado atual

- Projeto Godot 4.6 em Compatibility/OpenGL 3 e landscape.
- Menu principal responsivo.
- `TouchManager` multitouch com ownership por dedo e debug por mouse.
- Touch Lab com samples brutos, trajetória e métricas.
- Analisador matemático e testes sintéticos.
- Persistência local de amostras em `user://samples/`.

## Executar

Abra `project.godot` no Godot 4.6 e rode o projeto. No desktop, pressione e arraste o botão esquerdo do mouse dentro do Touch Lab. Em Android, use toque e arraste normalmente.

Testes matemáticos pela linha de comando:

```text
godot --headless --path . --script res://tests/run_math_tests.gd
```

Teste de integração da cadeia multitouch:

```text
godot --headless --path . --script res://tests/run_touch_integration.gd
```

Consulte também [Arquitetura](docs/ARCHITECTURE.md), [Modelo de sensibilidade](docs/SENSITIVITY_MODEL.md), [Sistema de testes](docs/TEST_SYSTEM.md) e [Exportação mobile](docs/MOBILE_EXPORT.md).
