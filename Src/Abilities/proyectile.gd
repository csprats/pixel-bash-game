extends Ability

class_name Proyectile
# 1. Cargamos la escena del proyectil directamente desde la habilidad
@export var projectile_scene: PackedScene = preload("res://Weapons/2/Proyectile.tscn")
var input_action: String = 'proyectile'

func activate(player: CharacterBody2D) -> void:
	# Comprobamos que tengamos la escena del proyectil asignada
	if not projectile_scene:
		print("Error: No has asignado la escena del proyectil en el Resource de la habilidad")
		return
	
	# 2. Fabricamos (instanciamos) el proyectil
	var new_projectile = projectile_scene.instantiate()
	
	# 3. Lo posicionamos en el mapa donde esté el jugador en ese instante
	new_projectile.global_position = player.global_position
	
	# Le pasamos el jugador actual como creador del proyectil
	new_projectile.creator = player
	
	# 4. Le pasamos la dirección del jugador usando la escala de su sprite
	if "direction" in new_projectile:
		new_projectile.direction = player._body.scale.x
		
	# 5. Lo soltamos en el escenario principal para que no se mueva con el jugador
	player.get_tree().current_scene.add_child(new_projectile)
