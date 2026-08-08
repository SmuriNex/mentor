# Sistema de testes

O primeiro instrumento é o Touch Lab. Ele registra posição em pixels e normalizada, delta, velocidade independente de FPS, trajetória, duração, retidão, eficiência e tremor.

Os testes sintéticos em `tests/run_math_tests.gd` cobrem linha reta, mediana, MAD, overshoot, forma em J e interpolação/clamp da LUT.

Testes gameplay-like e assistência experimental permanecerão separados dos testes motores crus. O perfil em `data/aim_assist_profile.json` começa desabilitado.
