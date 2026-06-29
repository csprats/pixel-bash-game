
extends Ability

@export var dash_force: float # Usamos una fuerza fija para el impulso
@export var dash_duration: float = 0

func activate(player: CharacterBody2D) -> void:
	dash_force = player.character_data.dash_speed
	# 1. Bloqueamos al jugador para que no use sus físicas normales mientras dure el dash
	player._attack_finished = false
	
	# 2. Miramos la dirección exacta (1 o -1)
	var direction = player._body.scale.x
	
	# 3. Aplicamos la fuerza directamente a las físicas del personaje
	player.velocity.x = direction * dash_force
	
	# 4. Reproducir animaciones
	if player._body.sprite_frames.has_animation("Dash"):
		player._body.play("Dash")
	if player._weapon.sprite_frames.has_animation("Idle"):
		player._weapon.play("Idle")
		
	# 5. EL TEMPORIZADOR: Ahora el await funcionará perfectamente
	var timer = player.get_tree().create_timer(dash_duration)
	await timer.timeout
	
	# 6. Al terminar el tiempo, frenamos al personaje y le devolvemos el control
	player.velocity.x = 0
	player._attack_finished = true
	print('ataque supuestamente detenido')
	
	print('impulso detenido')
	queue_free() # Borramos la habilidad de la memoria al terminar
