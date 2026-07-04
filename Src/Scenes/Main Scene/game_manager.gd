extends Node

# Guardaremos una referencia al contenedor donde se inyectan las escenas
var _container: Node = null

const MENU_SCENE = "res://Scenes/Main Menu/main_menu.tscn"
const COMBAT_SCENE = "res://Scenes/Level test/level_test.tscn"

func register_container(container_node: Node) -> void:
	# La escena principal usará esto para decirle al GameManager dónde meter los mapas
	_container = container_node

func change_scene(scene_path: String) -> void:
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
