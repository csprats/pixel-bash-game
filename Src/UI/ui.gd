extends CanvasLayer

# Hacemos referencia al Label de la pantalla
@export var damage_label: Label

func _ready() -> void:
	# Esperamos un microsegundo para asegurarnos de que todo se ha cargado en el mapa
	await get_tree().process_frame
	
	# Buscamos en el escenario al nodo que tenga la etiqueta "jugador"
	var jugadores = get_tree().get_nodes_in_group("player")
	
	if jugadores.size() > 0:
		var player = jugadores[0] # Agarramos al primer jugador que encuentre
		
		# ¡CONEXIÓN MÁGICA!: Conectamos la señal del jugador con la UI
		player.damage_changed.connect(_on_player_damage_changed)
		
		print("UI asignada con éxito al personaje: ", player.name)
		
		#damage_label.text = '0%'

# Esta función se activa sola cuando el jugador grita que ha cambiado su daño
func _on_player_damage_changed(new_damage: int) -> void:
	damage_label.text = str(new_damage) + "%"
