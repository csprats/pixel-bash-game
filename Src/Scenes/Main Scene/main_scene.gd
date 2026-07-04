extends Node

@export var scene_container: Node

func _ready() -> void:
	# Le damos nuestro contenedor al GameManager global
	GameManager.register_container(scene_container)
	
	# Cargamos la primera pantalla del juego (por ejemplo, el menú principal)
	GameManager.change_scene(GameManager.MENU_SCENE)
