# Modelo de sensibilidade

A relação exata entre os valores de sensibilidade do Free Fire e a rotação real da câmera não é conhecida. O Mentor não apresenta sua LUT como oficial nem promete uma “sensibilidade perfeita”.

`data/sensitivity_curve.json` contém atualmente uma curva linear neutra e explicitamente provisória. `SensitivityCurve` interpola essa LUT, permitindo substituí-la no futuro sem alterar o analisador de gestos.

Recomendações futuras usarão faixas, confiança, tentativas agrupadas e mediana/MAD. Uma tentativa isolada não deverá causar uma alteração grande.
