# Sistema de testes

O primeiro instrumento é o Touch Lab. Ele registra posição em pixels e normalizada, delta, velocidade independente de FPS, trajetória, duração, retidão, eficiência e tremor.

Os testes sintéticos em `tests/run_math_tests.gd` cobrem linha reta, mediana, MAD, overshoot, forma em J e interpolação/clamp da LUT.

`run_calibration_arena_tests.gd` instancia a física 3D real e comprova:

- raycast em `CHEST`, `HEAD`, `BODY` e `NONE`;
- reset matemático para `ChestTarget`;
- projeção de `HeadTarget` no centro;
- captura e liberação de finger ownership `FIRE_AIM`;
- gesto vertical chegando à cabeça e cálculo de `time_to_head`;
- classificações PERFECT/GOOD/UNDERSHOOT/OVERSHOOT/LATERAL_MISS;
- diferença entre arrasto lento e rápido, correção após overshoot e resumo de dez tentativas.

`run_navigation_tests.gd` garante que INICIAR ANÁLISE e TOUCH LAB levam a cenas distintas.

Testes gameplay-like e assistência experimental permanecerão separados dos testes motores crus. O perfil em `data/aim_assist_profile.json` começa desabilitado.
