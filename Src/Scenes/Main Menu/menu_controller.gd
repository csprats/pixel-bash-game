extends Control

@export var button_play: Button

func _ready() -> void:
	# Hace que el botón de Jugar esté seleccionado al arrancar con el mando
	button_play.grab_focus()

func _on_button_start_pressed() -> void:
	GameManager.change_scene(GameManager.COMBAT_SCENE_TEST)


func _on_button_quit_pressed() -> void:
	get_tree().quit()
