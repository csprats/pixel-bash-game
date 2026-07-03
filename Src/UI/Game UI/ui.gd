extends CanvasLayer

# Hacemos referencia al Label de la pantalla
@export var damage_label: Array[Label]
@export var player_icon: Array[TextureRect]

func _ready() -> void:
	# Esperamos un microsegundo para asegurarnos de que todo se ha cargado en el mapa
	await get_tree().process_frame
	
	# Buscamos en el escenario al nodo que tenga la etiqueta "jugador"
	var jugadores = get_tree().get_nodes_in_group("player")
	
	if jugadores.size() > 0 and damage_label.size() > 0 and player_icon.size() > 0:
		for i in range(jugadores.size()):
			var player = jugadores[i]
			var text = damage_label[i]
			var icon = player_icon[i]
		
			# Conectamos la señal del jugador con la UI
			#player.damage_changed.connect(_on_player_damage_changed)
			player.damage_changed.connect(_on_player_damage_changed.bind(text))
			
			print("UI asignada con éxito al personaje: ", player.character_data.character_name)
			
			icon.texture = player.character_data.character_icon

#func _on_player_damage_changed(new_damage: int) -> void:
	#damage_label.text = str(new_damage) + "%"
	
func _on_player_damage_changed(new_damage: int, label: Label) -> void:
	if label:
		label.text = str(new_damage) + "%"
