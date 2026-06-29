extends Ability

var shield_duration: float

func activate(player: CharacterBody2D) -> void:
	shield_duration = player.character_data.shield_duration
	
	player.modulate = Color(0, 0.5, 1, 1) # Brillo azul de escudo
	player._is_invincible = true # Activar la invencibilidad
	
	var timer = player.get_tree().create_timer(shield_duration)
	await timer.timeout
	
	player.modulate = Color(1, 1, 1, 1) # Vuelve a su color normal
	player._is_invincible = false # Desactivar la invencibilidad
