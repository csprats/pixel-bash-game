extends CanvasLayer

@export var damage_label: Array[Label]
@export var player_icon: Array[TextureRect]
@export var mana_bar: Array[TextureProgressBar]

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
			# player.damage_changed.connect(_on_player_damage_changed)
			player.damage_changed.connect(_on_player_damage_changed.bind(text))

			# Esto se puede activar para que en el LOG salgan los personajes a los que se les ha asignado la UI
			# print("UI asignada con éxito al personaje: ", player.character_data.character_name)

			icon.texture = player.character_data.character_icon

			# Barra de maná (una por jugador, emparejada por índice)
			if i < mana_bar.size():
				var bar = mana_bar[i]
				player.mana_changed.connect(_on_player_mana_changed.bind(bar))

#func _on_player_damage_changed(new_damage: int) -> void:
	#damage_label.text = str(new_damage) + "%"
	
func _on_player_damage_changed(new_damage: int, current_lives: int, label: Label) -> void:
	if label:
		label.text = str(new_damage) + "% " + str(current_lives) + " ♥"

func _on_player_mana_changed(current: float, maximum: float, bar: TextureProgressBar) -> void:
	if bar:
		bar.max_value = maximum
		bar.value = current
