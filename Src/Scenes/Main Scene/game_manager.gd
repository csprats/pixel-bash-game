extends Node

# Guardaremos una referencia al contenedor donde se inyectan las escenas
var _container: Node = null

# Rutas de las pantallas del juego (navegación manual a través del contenedor).
const MENU_SCENE = "res://Scenes/Main Menu/main_menu.tscn"
const MODE_SELECT_SCENE = "res://Scenes/Mode Select/mode_select.tscn"
const CHARACTER_SELECT_SCENE = "res://Scenes/Character Select/character_select.tscn"
const LEVEL_SELECT_SCENE = "res://Scenes/Level Select/level_select.tscn"
const LEVEL_1_SCENE = "res://Scenes/Levels/level_1.tscn"
const LEVEL_2_SCENE = "res://Scenes/Levels/level_2.tscn"
const LEVEL_3_SCENE = "res://Scenes/Levels/level_3.tscn"
const UI_SCENE = "res://UI/Game UI/ui.tscn"
const WIN_INDICATOR = "res://Scenes/Win indicator/win_indicator.tscn"
const TITLE_SCREEN = "res://Scenes/Title Screen/title_screen.tscn"
const GUIDE = "res://Scenes/Guide/guide.tscn"

# Rutas de las canciones:

const MAIN_MENU_SONG = "res://Music/Intro.mp3"
const LEVEL_1_SONG = "res://Music/For What Remains.mp3"
const LEVEL_2_SONG = "res://Music/For The Fallen Ones.mp3"
const LEVEL_3_SONG = "res://Music/For Vengeance.mp3"

var audio_stream_player: AudioStreamPlayer2D
var current_music_path: String

# Aquí se almacena el ganador de la última partida
var winner: int = 0 # Ponemos algo para que el juego no crashee
var winner_data_path: String

# Modo de juego elegido en el menú: jugador vs jugador o jugador vs CPU.
enum GameMode { PVP, PVC }
var game_mode: GameMode = GameMode.PVP

# Personaje elegido en el menú para cada slot. Por defecto Punk (P1) y Cyborg (P2),
# el emparejamiento clásico. character.gd los lee en su _ready al cargar el nivel.
var p1_character: CharacterData = preload("res://Character/Punk/punk.tres")
var p2_character: CharacterData = preload("res://Character/Cyborg/cyborg.tres")

# Devuelve el personaje elegido para un slot (1 o 2), o null si no aplica.
func get_selected_character(pid: int) -> CharacterData:
	if pid == 1:
		return p1_character
	elif pid == 2:
		return p2_character
	return null

func register_container(container_node: Node) -> void:
	# La escena principal usará esto para decirle al GameManager dónde meter los mapas
	_container = container_node

# with_ui: solo los niveles de combate necesitan la HUD; las pantallas de menú no.
func change_scene(scene_path: String, with_ui: bool = false) -> void:
	if not _container:
		print("Error: El SceneContainer no ha sido registrado en el GameManager.")
		return
		
	# 1. Limpiamos la escena que se esté reproduciendo actualmente
	for child in _container.get_children():
		child.queue_free()
		
	# 2. Cargamos el archivo de la nueva escena (.tscn)
	var new_scene_resource = load(scene_path)
	if not new_scene_resource:
		print("Error: No se pudo encontrar la ruta de la escena: ", scene_path)
		return
		
	# 3. Instanciamos la nueva escena en la memoria
	var new_scene_instance = new_scene_resource.instantiate()
	
	# 4. ¡La metemos dentro del contenedor!
	_container.add_child(new_scene_instance)
	print("Escena cambiada con éxito a: ", scene_path)
	
	# 5. Solo los niveles de combate llevan la UI; las pantallas de menú no.
	if with_ui:
		var new_ui_resource = load(UI_SCENE)
		
		if not new_ui_resource:
			print("Error: No se pudo encontrar la ruta de la escena de la UI: ", scene_path)
			return
			
		var new_ui_instance = new_ui_resource.instantiate()
		
		_container.add_child(new_ui_instance)
		print("UI añadida con éxito. Ruta: ", scene_path)
		
func play_music(music: String) -> void:
	# 1. Si es la misma canción que ya suena, no hacemos nada
	if music == current_music_path:
		return
		
	# 2. Verificar si el recurso existe usando ResourceLoader (funciona exportado)
	if not ResourceLoader.exists(music):
		print("Error: The music file does not exist in resources: ", music)
		return
		
	# 3. Cargar el recurso correctamente usando load()
	# Godot ya sabe internamente si es un MP3, OGG o WAV optimizado
	var stream = load(music)
	
	# 4. Asignar y reproducir
	if stream and audio_stream_player:
		current_music_path = music
		audio_stream_player.stream = stream
		audio_stream_player.play()
	else:
		print("Error: The music file cannot be played or audio_stream_player is null.")
