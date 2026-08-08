class_name CalibrationHitRegion
extends Area3D

## Região lógica atingida pelo raycast central. O controller usa este enum em
## vez de depender de nomes de Nodes.

enum Region {
	NONE,
	BODY,
	CHEST,
	HEAD,
}

@export var region: Region = Region.BODY


static func region_name(value: Region) -> String:
	return Region.keys()[value]
