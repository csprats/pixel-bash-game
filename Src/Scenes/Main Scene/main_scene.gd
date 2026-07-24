extends Node

@export var scene_container: Node
@export var music_container: AudioStreamPlayer2D

func _ready() -> void:	
	# Le damos nuestro contenedor al GameManager global
	GameManager.register_container(scene_container)
	
	# Cargamos el menú principal
	GameManager.change_scene(GameManager.TITLE_SCREEN)
	
	# Declaramos el AudioStreamPlayer
	GameManager.audio_stream_player = music_container
