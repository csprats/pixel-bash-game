extends CharacterBody2D

signal damage_changed(new_damage: int, current_lives: int)
## Progreso de recarga del escudo (0 = recien gastado, 100 = listo de nuevo).
signal shield_cooldown_changed(progress: float)

@export var character_data: CharacterData

enum ControlMode { HUMAN, AI }

## Quién controla este luchador: un humano con teclado o la IA.
@export var control_mode: ControlMode = ControlMode.HUMAN
## Número de jugador (1-4). Selecciona el keyset: las acciones de este slot
## son "<accion>_p" + player_id (p.ej. player_id 2 -> jump_p2, left_p2...).
@export_range(1, 4) var player_id: int = 1

@onready var _body: AnimatedSprite2D = $Body
@onready var _weapon: AnimatedSprite2D = $Weapon
@export var attack_delay: float = 0.5
# Estados de control
var _attack_finished: bool = true
var _dash_finished: bool = true
# Pestillo de empuje: mientras es false, el knockback controla la velocidad y
# el jugador no puede moverse/atacar (como el dash).
var _knockback_finished: bool = true
var _is_invincible: bool = false
# Doble salto: disponible una vez por vuelo; se recupera al pisar el suelo.
var _double_jump_available: bool = true
var _shield_on_cooldown: bool = false
# Seguimiento del cooldown del escudo para alimentar el indicador de la UI.
# shield.gd conmuta _shield_on_cooldown; aqui medimos el tiempo transcurrido.
var _was_on_cooldown: bool = false
var _shield_cooldown_elapsed: float = 0.0

var _current_damage: int = 0
var lives: int = 3

var _instanced_abilities: Array[Node] = []

func _ready() -> void:
	# Las acciones de este slot deben existir en el Input Map.
	for a in ["jump", "left", "right", "attack", "dash", "shield", "proyectile"]:
		assert(InputMap.has_action(_action(a)), "Falta accion de input: " + _action(a))

	# Si el menú ha elegido un personaje para este slot, tiene prioridad sobre el
	# character_data que traiga la instancia en la escena del nivel.
	var chosen: CharacterData = GameManager.get_selected_character(player_id)
	if chosen:
		character_data = chosen

	if character_data:
		if character_data.body_animations:
			_body.sprite_frames = character_data.body_animations
		if character_data.weapon_animations:
			_weapon.sprite_frames = character_data.weapon_animations
		
		_body.play("Idle")
		_weapon.play("Idle")
		
		if not _body.animation_finished.is_connected(_on_body_animation_finished):
			_body.animation_finished.connect(_on_body_animation_finished)
		
		if character_data and character_data.special_abilities:
			for ability_script in character_data.special_abilities:
				if ability_script:
					var new_ability = ability_script.new()
					add_child(new_ability)
					_instanced_abilities.append(new_ability)

# Marca este luchador como controlado por la CPU (modo jugador vs CPU).
# La arena lo llama al cargar el nivel según el modo elegido en el menú.
func set_as_cpu() -> void:
	control_mode = ControlMode.AI

# --- LECTURA DE INPUT (parametrizada por slot) ---
# Traduce una acción base al keyset de este slot ("jump" -> "jump_p2").
func _action(base: String) -> String:
	return base + "_p" + str(player_id)

# Devuelve si se acaba de pulsar la acción de este slot. La IA nunca "pulsa".
func _pressed(base: String) -> bool:
	if control_mode == ControlMode.AI:
		return false
	return Input.is_action_just_pressed(_action(base))

# Eje horizontal de este slot (-1..1). La IA no aporta input de movimiento.
func _axis() -> float:
	if control_mode == ControlMode.AI:
		return 0.0
	return Input.get_axis(_action("left"), _action("right"))

func _physics_process(delta: float) -> void:
	if not character_data:
		return
	
	# 1. DETECTAR ATAQUE ESPECIAL (DASH)
	# Comprobamos que no estemos atacando ni haciendo otro dash
	if _attack_finished and _dash_finished and _knockback_finished and is_on_floor():
		for ability in _instanced_abilities:
			if _pressed(ability.input_action):
				ability.activate(self)
				break

	# 2. MOVIMIENTO Y FÍSICAS
	if _attack_finished and _dash_finished and _knockback_finished:
		if not is_on_floor():
			velocity += get_gravity() * delta * character_data.gravity_scale
		else:
			# En el suelo se recupera el doble salto.
			_double_jump_available = true

		if _pressed("jump"):
			if is_on_floor():
				velocity.y = character_data.jump_force
			elif _double_jump_available:
				# Doble salto (estilo Smash): un impulso extra en el aire.
				velocity.y = character_data.double_jump_force
				_double_jump_available = false

		velocity.x = _axis() * character_data.walk_speed
	else:
		# Durante el empuje seguimos aplicando gravedad en el aire para que el
		# pequeño salto del knockback describa un arco y caiga de forma natural,
		# sin quedarse flotando. No leemos input de movimiento aquí.
		if not _knockback_finished and not is_on_floor():
			velocity += get_gravity() * delta * character_data.gravity_scale
		if is_on_floor():
			# Leemos los botones de caminar en tiempo real
			var direccion_actual := _axis()
			
			# Si dejas de pulsar el botón de caminar MIENTRAS atacas en carrera...
			if _body.animation == "Run_Attack" and direccion_actual == 0:
				# Lo frenamos en seco (o puedes usar velocity.x *= 0.7 para que decelere rápido)
				velocity.x = 0
				_body.play("Idle")
				_weapon.play("Idle")
				_attack_finished = true
				
	# 3. DETECTAR ATAQUES NORMALES (Solo si no estamos en mitad de un dash o empuje)
	if _dash_finished and _knockback_finished:
		if _attack_finished and (velocity.x < 0 or velocity.x > 0) and is_on_floor() and _pressed("attack"):
			_attack_finished = false
			_body.play('Run_Attack')
			_weapon.play('Run_Attack')
			
			# Despierta la colisión en movimiento
			$Hitbox.monitoring = false
			$Hitbox.monitoring = true
			
		elif _attack_finished and is_on_floor() and _pressed("attack"):
			_attack_finished = false  
			_body.play("Attack")
			_weapon.play("Attack")
			
			# Apagamos y encendemos el monitoreo de la Hitbox. 
			# Esto obliga a Godot a escanear el área inmediatamente aunque estés quieto.
			$Hitbox.monitoring = false
			$Hitbox.monitoring = true
			
	# Debug: la tecla P es física y global, así que solo la aplicamos al slot de P1
	# para no dañar a todos los luchadores a la vez.
	# Respeta la invencibilidad (p.ej. escudo) igual que el dano real, para que
	# sirva como prueba: mientras el escudo este activo, P no debe hacer dano.
	if control_mode == ControlMode.HUMAN and player_id == 1 and Input.is_key_pressed(KEY_P) and not _is_invincible:
		receive_damage(1) # Suma 0.5% por cada frame que la pulses

	# 4. CONTROL DE ANIMACIONES DE MOVIMIENTO
	if _attack_finished and _dash_finished and _knockback_finished:
		if (velocity.x < 0 or velocity.x > 0):
			_body.play("Run")
			_weapon.play("Run")
		elif velocity.y == 0:
			_body.play("Idle")
			_weapon.play("Idle")
	
	# 5. DIRECCIÓN DEL SPRITE (No permitimos girar en mitad del dash ni del empuje)
	if _dash_finished and _knockback_finished:
		var direccion := _axis()
		if direccion != 0:
			_body.scale.x = direccion
			_weapon.scale.x = direccion
	
	# 6. APLICAR MOVIMIENTO
	move_and_slide()

	# 7. INDICADOR DE COOLDOWN DEL ESCUDO
	_update_shield_cooldown(delta)

# Reaparece en el punto indicado (lo llama el gestor de la arena cuando el
# luchador sale de los límites por un agujero o lo empujan fuera del escenario).
func respawn(pos: Vector2) -> void:
	if (lives <= 0): 
		# Aquí podemos llamar a una función de la UI que 
		# muestre un mensaje de que el otro jugador a ganado
		queue_free()
		return
	lives -= 1
	global_position = pos
	velocity = Vector2.ZERO
	_knockback_finished = true  # cancela cualquier empuje en curso
	_double_jump_available = true
	# Al morir, el porcentaje de daño acumulado se reinicia (estilo stock).
	_current_damage = 0
	damage_changed.emit(_current_damage, lives)

# Alimenta el indicador de escudo de la UI. Fases (shield.gd conmuta los flags):
#   escudo activo (_is_invincible)   -> barra vacia (0)
#   recarga (_shield_on_cooldown)    -> se rellena de 0 a 100 con el tiempo
#   listo de nuevo                   -> barra llena (100)
func _update_shield_cooldown(delta: float) -> void:
	if _is_invincible:
		# Escudo activo: la barra se vacia en cuanto se levanta y sigue vacia.
		_was_on_cooldown = false
		shield_cooldown_changed.emit(0.0)
	elif _shield_on_cooldown:
		if not _was_on_cooldown:
			# Flanco de subida: la recarga acaba de empezar.
			_was_on_cooldown = true
			_shield_cooldown_elapsed = 0.0
		_shield_cooldown_elapsed += delta
		var total := character_data.shield_cooldown
		var progress := 100.0
		if total > 0.0:
			progress = clampf(_shield_cooldown_elapsed / total * 100.0, 0.0, 100.0)
		shield_cooldown_changed.emit(progress)
	elif _was_on_cooldown:
		# Flanco de bajada: el escudo vuelve a estar listo.
		_was_on_cooldown = false
		shield_cooldown_changed.emit(100.0)

func _on_body_animation_finished() -> void:
	if _body.animation == "Attack" or _body.animation == "Run_Attack":
		_attack_finished = true
		
# Esta función procesará el daño que nos hagan.
# knockback_dir: dirección horizontal del empuje (+1 derecha, -1 izquierda).
# 0.0 (por defecto) significa sin empuje (p.ej. el daño de depuración con P).
func receive_damage(amount: int, knockback_dir: float = 0.0) -> void:
	_current_damage += amount

	damage_changed.emit(_current_damage, lives)
	_play_hit_flash()
	_apply_hitstop()
	if knockback_dir != 0.0:
		_apply_knockback(knockback_dir)

# Empuje al recibir daño (estilo Smash): la magnitud crece con el daño ya
# acumulado y se divide por el peso del personaje. Reutiliza el patrón del dash:
# ponemos un pestillo, escribimos la velocidad, esperamos y liberamos.
func _apply_knockback(dir: float) -> void:
	_knockback_finished = false
	var w := maxf(character_data.weight, 0.1)
	var magnitude := (character_data.knockback_base + _current_damage * character_data.knockback_scale) / w
	velocity.x = signf(dir) * magnitude
	velocity.y = character_data.knockback_pop / w
	# Timer normal (no ignora time_scale): no empieza a contar hasta que acaba
	# el hitstop de 0.08s, así el empuje arranca justo al descongelarse el golpe.
	await get_tree().create_timer(character_data.knockback_duration).timeout
	_knockback_finished = true

# --- EFECTOS VISUALES ---
func _play_hit_flash() -> void:
	# Destello rojo breve al recibir un golpe (visible sobre cualquier sprite).
	# Asignación directa de modulate (como shield.gd) para no depender de un tween,
	# que no interpola con el time_scale = 0 del hitstop.
	modulate = Color(1, 0.25, 0.25, 1)
	# ignore_time_scale = true para que el timer avance aunque el juego esté congelado.
	await get_tree().create_timer(0.15, true, false, true).timeout
	modulate = Color(1, 1, 1, 1)

func _apply_hitstop(duration: float = 0.08) -> void:
	# Micro-congelación global para dar peso al impacto.
	Engine.time_scale = 0.0
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func _play_ready_flash() -> void:
	# Destello verde breve: una habilidad vuelve a estar disponible
	modulate = Color(0.5, 1.0, 0.5, 1)
	await get_tree().create_timer(0.25, true, false, true).timeout
	modulate = Color(1, 1, 1, 1)

func _on_hitbox_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	if area.owner == self:
		return # Ignoramos nuestro propio cuerpo
	
	print('hitbox: area entered')
	if (not _attack_finished):
		# Si el objeto de la sala tiene un script con esta función, le restamos vida/daño
		if area.get_parent().has_method("receive_damage") and not area.get_parent()._is_invincible:
			# Empujamos a la víctima hacia donde mira el atacante (self).
			if (not _body.animation == "Run_Attack"):
				await get_tree().create_timer(attack_delay).timeout
			area.get_parent().receive_damage(5, _body.scale.x)
