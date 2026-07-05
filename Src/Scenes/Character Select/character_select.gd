extends Control

## Pantalla de selección de personaje. Cada slot tiene un botón que rota entre los
## personajes disponibles; el elegido se guarda en el GameManager y lo lee
## character.gd al cargar el nivel. En modo jugador vs CPU, el slot 2 es la CPU.

# Orden de rotación de los personajes disponibles.
const ROSTER: Array[CharacterData] = [
	preload("res://Character/Biker/biker.tres"),
	preload("res://Character/Cyborg/cyborg.tres"),
	preload("res://Character/Punk/punk.tres"),
]

@export var button_p1: Button
@export var button_p2: Button

func _ready() -> void:
	_refresh()
	# El primer botón queda seleccionado al arrancar (navegación con mando).
	button_p1.grab_focus()

# Devuelve el siguiente personaje de la lista (vuelve al principio al terminar).
func _next(current: CharacterData) -> CharacterData:
	var i := ROSTER.find(current)
	return ROSTER[(i + 1) % ROSTER.size()]

# Actualiza el texto de los botones con la selección actual de cada slot.
func _refresh() -> void:
	button_p1.text = "p1: " + GameManager.p1_character.character_name.to_lower()
	var slot := "cpu" if GameManager.game_mode == GameManager.GameMode.PVC else "p2"
	button_p2.text = slot + ": " + GameManager.p2_character.character_name.to_lower()

func _on_button_p1_pressed() -> void:
	GameManager.p1_character = _next(GameManager.p1_character)
	_refresh()

func _on_button_p2_pressed() -> void:
	GameManager.p2_character = _next(GameManager.p2_character)
	_refresh()

func _on_button_next_pressed() -> void:
	GameManager.change_scene(GameManager.LEVEL_SELECT_SCENE)

func _on_button_back_pressed() -> void:
	GameManager.change_scene(GameManager.MODE_SELECT_SCENE)
