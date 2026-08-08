# Arquitetura

## Fluxo de análise 0.2

`AnalysisRunner` é o único coordenador de fases. Ele fornece `MentorTestDefinition` à arena, recebe tentativas válidas, agrega candidates e avança por warmup, perfil natural, baseline, coarse/fine/validation de Geral, coarse/fine/validation de Red Dot e resultados. A UI não decide score nem candidate.

O input continua centralizado no `TouchManager`. A arena só roteia cada finger ID para um owner (`JOYSTICK`, `CAMERA_LOOK`, `FIRE_AIM` ou `JUMP`). Movimento do alvo, análise de tracking e busca de sensibilidade são módulos matemáticos separados da cena.

O Mentor separa captura, dados, análise, apresentação e armazenamento.

- `TouchManager`: autoload responsável por finger IDs, timestamps em microssegundos, normalização e ownership.
- `TouchSample`: ponto bruto de um gesto; nunca recebe smoothing.
- `GestureAttempt`: agrupa samples de um único dedo e registra viewport/DPI.
- `GestureAnalyzer`: cálculos matemáticos executados depois do gesto.
- `TouchLab`: apresentação e ferramenta de inspeção; não contém as fórmulas.
- `LocalStorage`: única camada que conhece `user://` e JSON.

## Calibration Arena

- `TargetDummy`: cena reutilizável feita com primitivas; cada `Area3D` possui um `CalibrationHitRegion` tipado.
- `AimCameraController`: converte delta normalizado → LUT → ganho angular → yaw/pitch, sem conter análise.
- `CalibrationArena`: state machine `PREPARING/READY/AIMING/ANALYZING/SHOWING_RESULT/FINISHED`.
- `CalibrationAttempt`: composição sobre `GestureAttempt`, guardando câmera, raycast, contato com cabeça e erro projetado.
- `CalibrationClassifier`: thresholds normalizados vindos de JSON.
- `CalibrationSessionSummary`: agrega dez tentativas usando mediana e MAD.

A crosshair nunca acompanha o dedo: ela permanece no centro, enquanto o gesto gira a câmera. O raycast parte do centro óptico da `Camera3D` e só aceita `CalibrationHitRegion`, evitando comparações frágeis com nomes de Nodes.

O desenho usa um único `Control` e uma `PackedVector2Array`, evitando um Node para cada sample.
