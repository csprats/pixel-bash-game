extends Control

## Pantalla de selección de nivel. De momento solo existe el nivel 1; en el futuro
## habrá hasta 5 niveles (añadir un botón por nivel apuntando a su constante de ruta
## en GameManager, p.ej. GameManager.LEVEL_2_SCENE, y lanzarlo con with_ui = true).

@export var button_first: Button

func _ready() -> void:
	# El primer botón queda seleccionado al arrancar (navegación con mando).
	button_first.grab_focus()

func _on_button_level_1_pressed() -> void:
	# with_ui = true: los niveles de combate llevan la HUD del juego.
	GameManager.change_scene(GameManager.LEVEL_1_SCENE, true)

func _on_button_level_2_pressed() -> void:
	GameManager.change_scene(GameManager.LEVEL_2_SCENE, true)

func _on_button_back_pressed() -> void:
	GameManager.change_scene(GameManager.CHARACTER_SELECT_SCENE)
