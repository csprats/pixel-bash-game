extends Control

## Pantalla de selección de modo de juego: jugador vs jugador o jugador vs CPU.
## Guarda el modo elegido en el GameManager y salta a la selección de nivel.

@export var button_first: Button

func _ready() -> void:
	# El primer botón queda seleccionado al arrancar (navegación con mando).
	button_first.grab_focus()

func _on_button_pvp_pressed() -> void:
	GameManager.game_mode = GameManager.GameMode.PVP
	GameManager.change_scene(GameManager.CHARACTER_SELECT_SCENE)

func _on_button_pvc_pressed() -> void:
	GameManager.game_mode = GameManager.GameMode.PVC
	GameManager.change_scene(GameManager.CHARACTER_SELECT_SCENE)

func _on_button_back_pressed() -> void:
	GameManager.change_scene(GameManager.MENU_SCENE)
