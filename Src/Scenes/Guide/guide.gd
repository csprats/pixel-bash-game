extends Control

@export var button: Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button.grab_focus()

func _on_button_pressed() -> void:
	GameManager.change_scene(GameManager.MENU_SCENE)
