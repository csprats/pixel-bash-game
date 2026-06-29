extends Ability

var dash_force: float 
var dash_duration: float

func activate(player: CharacterBody2D) -> void:
	dash_force = player.character_data.dash_speed
	dash_duration = player.character_data.dash_duration
	
	# 1. Bloqueamos el DASH del jugador
	player._dash_finished = false
	
	# 2. Miramos la dirección exacta (1 o -1)
	var direction = player._body.scale.x
	
	# 3. Aplicamos la fuerza directamente a las físicas del personaje
	player.velocity.x = direction * dash_force
	
	# 4. Reproducir animaciones
	if player._body.sprite_frames.has_animation("Dash"):
		player._body.play("Dash")
	if player._weapon.sprite_frames.has_animation("Idle"):
		player._weapon.play("Idle")
		
	# 5. EL TEMPORIZADOR
	var timer = player.get_tree().create_timer(dash_duration)
	await timer.timeout
	
	# 6. Al terminar el tiempo, frenamos y abrimos el pestillo correcto
	player.velocity.x = 0
	player._dash_finished = true
	
	queue_free()
