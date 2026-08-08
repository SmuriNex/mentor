extends Node

## Mantém apenas a sessão em andamento. Persistência fica isolada em
## LocalStorage para que testes e telas não conheçam detalhes de arquivos.

var active_session_id: String = ""
var session_started_usec: int = 0
var gesture_count: int = 0


func start_session() -> String:
	session_started_usec = Time.get_ticks_usec()
	active_session_id = "%s_%d" % [Time.get_datetime_string_from_system().replace(":", "-"), session_started_usec]
	gesture_count = 0
	return active_session_id


func register_gesture() -> void:
	gesture_count += 1


func clear_session() -> void:
	active_session_id = ""
	session_started_usec = 0
	gesture_count = 0
