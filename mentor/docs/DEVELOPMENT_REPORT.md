# Relatório final de desenvolvimento — MENTOR 0.2

## Estado anterior

O repositório possuía menu, Touch Lab, infraestrutura de samples normalizados e uma Calibration Arena V1 exclusivamente estática. A câmera só se movia quando o toque começava no FIRE; não havia player móvel, tracking, busca adaptativa nem resultado Geral/Red Dot.

## Arquivos reutilizados

Foram preservados `TouchManager`, `GestureAttempt`, `GestureAnalyzer`, `SensitivityCurve`, `LocalStorage`, a cena base da arena, o dummy primitivo, o tema e todos os testes anteriores.

## Arquivos criados

Foram adicionados módulos independentes em `scripts/targets`, `scripts/movement`, `scripts/runner`, `scripts/sensitivity` e `scripts/analysis`; cenas de preparação/resultado; quatro JSONs de configuração; e seis suítes novas de testes.

## Arquivos modificados

A arena passou a consumir o runner e owners separados. O rig virou `CharacterBody3D`. O menu abre a preparação. A tentativa passou a persistir tracking e pattern. `LocalStorage` passou a salvar sessões completas.

## Camera

`CAMERA_LOOK` gira sem FIRE e não cria headshot attempt. `FIRE_AIM` continua rotacionando a mesma câmera. Yaw/pitch usam delta normalizado, pitch limitado e curva de sensibilidade configurável. O modo Red Dot tem overlay e FOV experimental próprios; não afirma equivalência oficial com Free Fire.

## Target

`TargetMotionController` oferece stationary, left, right, continuous, reversal e variable strafe. `TargetMovementPattern` integra segmentos por tempo absoluto, garantindo reprodução equivalente em 60/90/120 FPS. Visual, colisores e markers permanecem na mesma hierarquia móvel.

## Tracking

O erro é `ChestTarget projetado - centro da tela`, normalizado pelo viewport. São calculados média, mediana, pico, tempo próximo, MAD/estabilidade, bias horizontal, correções e atraso após reversão. O endpoint usa sempre o `HeadTarget` atual.

## Player Movement

O rig é um `CharacterBody3D` com gravidade, joystick esquerdo, movimento relativo ao yaw, WASD opcional e pulo. Os owners `JOYSTICK`, `CAMERA_LOOK`, `FIRE_AIM` e `JUMP` coexistem por finger ID.

## General Search

A busca Geral usa candidates coarse configuráveis, ou uma vizinhança do valor atual informado. Candidates promissores recebem fine search por midpoint e passos configuráveis. O valor candidato fica oculto fora do Developer Mode.

## Red Dot Search

Red Dot executa busca própria depois da Geral validada. Não é calculado por offset fixo da Geral e usa candidates, métricas, faixa e validação independentes.

## Scoring

`SensitivityCandidateResult` agrega as métricas exigidas por mediana e marca outliers por MAD. O score combina moving headshot, player+target, tracking, static, reversal e camera control com pesos JSON, priorizando equilíbrio entre precisão, rapidez, controle e consistência.

## Confidence

A confiança 0–1 considera quantidade, consistência, outliers, separação de score e largura da região estatisticamente equivalente. A validação aumenta confiança quando reproduz o resultado; em falha, o runner testa uma alternativa promissora uma vez.

## Testes

Dez suítes headless cobrem matemática, Touch Lab, arena, target/patterns, tracking, movimento/pulo, perfil natural, scoring/search, runner/persistência/tela final e navegação. O projeto também foi importado e suas cenas principais executadas no Godot 4.6 oficial.

## Limitações

O Mentor não acessa o Free Fire e não conhece sua transformação interna de sensibilidade. A LUT, FOVs, velocidades e pesos são experimentais e versionados. As recomendações são produzidas apenas a partir do comportamento observado dentro da arena; a calibração manual futura pode melhorar a equivalência absoluta.
