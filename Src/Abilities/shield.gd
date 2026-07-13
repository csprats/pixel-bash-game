extends Ability

var input_action: String = 'shield'

func activate(player: CharacterBody2D) -> void:
	if player._is_invincible:
		return

	# El escudo cuesta maná: si no hay suficiente, no se activa (feedback visual).
	if not player.has_mana(player.character_data.shield_mana_cost):
		player._play_no_mana_flash()
		return
	player.spend_mana(player.character_data.shield_mana_cost)

	player.modulate = Color(0, 0.5, 1, 1) # Brillo azul de escudo
	player._is_invincible = true          # Activar la invencibilidad
	await player.get_tree().create_timer(player.character_data.shield_duration).timeout

	player.modulate = Color(1, 1, 1, 1)   # Vuelve a su color normal
	player._is_invincible = false         # La proteccion TERMINA aqui
