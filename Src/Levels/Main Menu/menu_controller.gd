extends Control

@export var button_play: Button

func _ready() -> void:
	# Hace que el botón de Jugar esté seleccionado al arrancar con el mando
	button_play.grab_focus()

func _on_button_play_pressed() -> void:
	print('play')

func _on_button_exit_pressed() -> void:
	# Cierra el juego
	get_tree().quit()
