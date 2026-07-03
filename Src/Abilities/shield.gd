extends Ability

var input_action: String = 'shield'

func activate(player: CharacterBody2D) -> void:
	if player._is_invincible or player._shield_on_cooldown:
		return

	player.modulate = Color(0, 0.5, 1, 1) # Brillo azul de escudo
	player._is_invincible = true          # Activar la invencibilidad
	await player.get_tree().create_timer(player.character_data.shield_duration).timeout

	player.modulate = Color(1, 1, 1, 1)   # Vuelve a su color normal
	player._is_invincible = false         # La proteccion TERMINA aqui
	player._shield_on_cooldown = true     # Empieza el tiempo muerto

	await player.get_tree().create_timer(player.character_data.shield_cooldown).timeout
	player._shield_on_cooldown = false
	player._play_ready_flash()            # Aviso visual: escudo listo de nuevo
