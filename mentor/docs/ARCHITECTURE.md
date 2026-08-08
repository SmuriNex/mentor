# Arquitetura

O Mentor separa captura, dados, análise, apresentação e armazenamento.

- `TouchManager`: autoload responsável por finger IDs, timestamps em microssegundos, normalização e ownership.
- `TouchSample`: ponto bruto de um gesto; nunca recebe smoothing.
- `GestureAttempt`: agrupa samples de um único dedo e registra viewport/DPI.
- `GestureAnalyzer`: cálculos matemáticos executados depois do gesto.
- `TouchLab`: apresentação e ferramenta de inspeção; não contém as fórmulas.
- `LocalStorage`: única camada que conhece `user://` e JSON.

O desenho usa um único `Control` e uma `PackedVector2Array`, evitando um Node para cada sample.
