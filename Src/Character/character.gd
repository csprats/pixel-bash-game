extends CharacterBody2D

signal damage_changed(new_damage: int, current_lives: int)
## Maná actual y máximo del luchador (recurso común de escudo y proyectil).
signal mana_changed(current: float, maximum: float)

@export var character_data: CharacterData

enum ControlMode { HUMAN, AI }

## Quién controla este luchador: un humano con teclado o la IA.
@export var control_mode: ControlMode = ControlMode.HUMAN
## Número de jugador (1-4). Selecciona el keyset: las acciones de este slot
## son "<accion>_p" + player_id (p.ej. player_id 2 -> jump_p2, left_p2...).
@export_range(1, 4) var player_id: int = 1

@onready var _body: AnimatedSprite2D = $Body
@onready var _weapon: AnimatedSprite2D = $Weapon

# Estados de control
var _attack_finished: bool = true
var _dash_finished: bool = true
# Pestillo de empuje: mientras es false, el knockback controla la velocidad y
# el jugador no puede moverse/atacar (como el dash).
var _knockback_finished: bool = true
var _is_invincible: bool = false
# Doble salto: disponible una vez por vuelo; se recupera al pisar el suelo.
var _double_jump_available: bool = true
# Maná actual del luchador (recurso común de escudo y proyectil). Empieza lleno
# en _ready y se gasta/regenera vía spend_mana()/gain_mana().
var _current_mana: float = 0.0

var _current_damage: int = 0
var lives: int = 3

var _instanced_abilities: Array[Node] = []

# Offset horizontal base del Hurtbox y del collider del cuerpo (los de la
# escena, calibrados mirando a la derecha). Se reflejan con el giro para que las
# cajas no se descoloquen al mirar a la izquierda.
var _hurtbox_base_x: float = 0.0
var _body_col_base_x: float = 0.0

# --- IA (modo CPU) ---
# Intención de movimiento/pulsaciones que la IA fabrica cada frame; _axis()/
# _pressed() las leen en modo AI para reutilizar toda la máquina de estados.
var _ai_axis: float = 0.0
var _ai_pressed: Dictionary = {}          # base -> true si "se pulsa" este frame
var _ai_attack_cooldown: float = 0.0
var _ai_jump_cooldown: float = 0.0
var _ai_special_cooldown: float = 0.0

const AI_ATTACK_RANGE := 70.0             # distancia horizontal para golpear
const AI_VERTICAL_TOLERANCE := 45.0       # mismo "nivel" para atacar
const AI_JUMP_TRIGGER := 40.0             # rival por encima -> saltar
const AI_ATTACK_INTERVAL := 0.45          # cadencia de golpes
const AI_JUMP_INTERVAL := 0.8
const AI_SPECIAL_INTERVAL := 1.2          # cada cuánto reconsidera un especial
# Sensor de borde: sonda hacia abajo por delante del pie de avance.
const AI_LEDGE_PROBE_X := 22.0            # half-width(16) + margen, delante
const AI_FOOT_Y := 24.0                   # pie ≈ y local +24 del cuerpo
const AI_GAP_JUMP_MAX := 130.0            # gap "saltable" hacia el rival
const AI_PROJECTILE_RANGE := 250.0        # rango medio para lanzar proyectil

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
		# El maná arranca lleno al comenzar la partida.
		_current_mana = character_data.max_mana
		mana_changed.emit(_current_mana, character_data.max_mana)

		if character_data.body_animations:
			_body.sprite_frames = character_data.body_animations
		if character_data.weapon_animations:
			_weapon.sprite_frames = character_data.weapon_animations
		
		_body.play("Idle")
		_weapon.play("Idle")

		# La Hitbox arranca apagada: solo se enciende en los frames de impacto
		# del ataque (ver _on_body_frame_changed), no al empezar la animación.
		$Hitbox.monitoring = false

		# Los SubResource de una escena se comparten entre instancias, así que
		# duplicamos la forma para que cada luchador tenga la suya. El tamaño se
		# aplica en cada golpe (ver _on_body_frame_changed), no aquí, para poder
		# afinarlo en caliente editando el .tres con el juego en marcha.
		var _hb_shape := $Hitbox/CollisionShape2D
		_hb_shape.shape = _hb_shape.shape.duplicate()
		# La colocamos ya con su tamaño/posición reales (no la geometría de la
		# escena) para que no se vea una caja "vieja" hasta el primer golpe.
		_place_hitbox()

		# Guardamos los offsets del Hurtbox y del collider del cuerpo para poder
		# reflejarlos al girar.
		_hurtbox_base_x = $Hurtbox/CollisionShape2D.position.x
		_body_col_base_x = $CollisionShape2D.position.x

		if not _body.animation_finished.is_connected(_on_body_animation_finished):
			_body.animation_finished.connect(_on_body_animation_finished)
		# Escuchamos el avance de frames para activar la Hitbox solo en la
		# ventana de impacto de la animación de ataque.
		if not _body.frame_changed.is_connected(_on_body_frame_changed):
			_body.frame_changed.connect(_on_body_frame_changed)
		
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

# Devuelve si se acaba de pulsar la acción de este slot. En modo IA leemos las
# pulsaciones que fabrica _ai_think() (válidas solo durante este frame físico).
func _pressed(base: String) -> bool:
	if control_mode == ControlMode.AI:
		return _ai_pressed.get(base, false)
	return Input.is_action_just_pressed(_action(base))

# Eje horizontal de este slot (-1..1). En modo IA devolvemos la intención de
# movimiento calculada por _ai_think().
func _axis() -> float:
	if control_mode == ControlMode.AI:
		return _ai_axis
	# Usamos signf() para que solo devuelve 1, -1 o 0
	return signf(Input.get_axis(_action("left"), _action("right")))

func _physics_process(delta: float) -> void:
	if not character_data:
		return

	# 0. CEREBRO DE LA IA: decide movimiento y pulsaciones de este frame antes de
	# que el resto del proceso lea _axis()/_pressed().
	if control_mode == ControlMode.AI:
		_ai_think(delta)

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
			# La Hitbox la encenderá _on_body_frame_changed en la ventana de impacto.

		elif _attack_finished and is_on_floor() and _pressed("attack"):
			_attack_finished = false
			_body.play("Attack")
			_weapon.play("Attack")
			# La Hitbox la encenderá _on_body_frame_changed en la ventana de impacto.

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
			# Reflejamos los offsets del Hurtbox y del collider del cuerpo con el
			# giro para que las cajas sigan cuadradas con el sprite también
			# mirando a la izquierda.
			var _lado := signf(_body.scale.x)
			$Hurtbox/CollisionShape2D.position.x = _hurtbox_base_x * _lado
			$CollisionShape2D.position.x = _body_col_base_x * _lado
			# La Hitbox también se refleja para que no muestre una caja
			# descolocada al girar antes de atacar.
			_place_hitbox()
	
	# 6. APLICAR MOVIMIENTO
	move_and_slide()

# --- IA (modo CPU) ---
# Localiza al rival reutilizando el grupo "player" (igual que hace arena.gd).
func _find_opponent() -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if p != self:
			return p
	return null

# ¿Hay suelo sólido un poco por delante en la dirección dir (+1/-1)?
# Sonda hacia abajo desde el pie de avance contra la capa "Collision" (1).
# Evita que la IA camine hacia un hueco y caiga a la zona de muerte.
func _has_ground_ahead(dir: float) -> bool:
	if dir == 0.0:
		return true
	var foot := global_position + Vector2(dir * AI_LEDGE_PROBE_X, AI_FOOT_Y - 4.0)
	var to := foot + Vector2(0, 24.0)
	var q := PhysicsRayQueryParameters2D.create(foot, to, 1)  # máscara 1 = "Collision"
	q.exclude = [self]
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()

# Cerebro básico de la CPU. No lee el teclado: fabrica _ai_axis y _ai_pressed,
# que _axis()/_pressed() devuelven en modo IA, de modo que toda la máquina de
# estados (mover, saltar, atacar, habilidades, giro) funciona sin cambios.
func _ai_think(delta: float) -> void:
	# Intenciones nuevas cada frame: una pulsación dura un solo frame físico,
	# igual que la semántica "just pressed" que espera el resto del proceso.
	_ai_axis = 0.0
	_ai_pressed.clear()

	var target := _find_opponent()
	if target == null:
		return

	# Enfriamientos (no bajan de 0).
	_ai_attack_cooldown = maxf(_ai_attack_cooldown - delta, 0.0)
	_ai_jump_cooldown = maxf(_ai_jump_cooldown - delta, 0.0)
	_ai_special_cooldown = maxf(_ai_special_cooldown - delta, 0.0)

	var dx: float = target.global_position.x - global_position.x
	var dy: float = target.global_position.y - global_position.y
	var adx := absf(dx)
	var dir := signf(dx)

	# Mirar hacia el rival (mismas condiciones que el giro de la sección 5), para
	# que dash/proyectil salgan en la dirección correcta aunque estemos quietos.
	# Reflejamos también las cajas, como hace la sección 5 al girar.
	if _dash_finished and _knockback_finished and dir != 0.0:
		_body.scale.x = dir
		_weapon.scale.x = dir
		$Hurtbox/CollisionShape2D.position.x = _hurtbox_base_x * dir
		$CollisionShape2D.position.x = _body_col_base_x * dir
		_place_hitbox()

	# ACERCARSE (con conciencia de bordes).
	if adx > AI_ATTACK_RANGE:
		if is_on_floor() and not _has_ground_ahead(dir):
			# Hueco por delante: no nos tiramos. Si el rival está al otro lado y a
			# tiro de salto, saltamos hacia él; si no, nos paramos en el borde.
			if dy < AI_VERTICAL_TOLERANCE and adx <= AI_GAP_JUMP_MAX and _ai_jump_cooldown <= 0.0:
				_ai_pressed["jump"] = true
				_ai_jump_cooldown = AI_JUMP_INTERVAL
				_ai_axis = dir
			# else: _ai_axis se queda en 0 (parados en el borde).
		else:
			_ai_axis = dir

		# Saltar si el rival está claramente por encima.
		if dy < -AI_JUMP_TRIGGER and is_on_floor() and _ai_jump_cooldown <= 0.0:
			_ai_pressed["jump"] = true
			_ai_jump_cooldown = AI_JUMP_INTERVAL

	# ATACAR en rango y al mismo nivel.
	if adx <= AI_ATTACK_RANGE and absf(dy) < AI_VERTICAL_TOLERANCE and _ai_attack_cooldown <= 0.0:
		_ai_pressed["attack"] = true
		_ai_attack_cooldown = AI_ATTACK_INTERVAL

	# ESPECIALES (variedad). Solo tienen efecto si el personaje posee la habilidad
	# correspondiente; pulsar una base sin habilidad es inofensivo.
	if _ai_special_cooldown <= 0.0:
		var used_special := false
		if adx < AI_ATTACK_RANGE and not target._attack_finished and randf() < 0.6:
			# Rival pegado y atacando: nos protegemos.
			_ai_pressed["shield"] = true
			used_special = true
		elif adx > AI_ATTACK_RANGE and adx < AI_PROJECTILE_RANGE and randf() < 0.7:
			# Rango medio: disparamos un proyectil.
			_ai_pressed["proyectile"] = true
			used_special = true
		elif adx >= AI_PROJECTILE_RANGE and _has_ground_ahead(dir) and randf() < 0.5:
			# Lejos y con suelo por delante: dash para acortar distancia sin caer.
			_ai_pressed["dash"] = true
			used_special = true
		if used_special:
			_ai_special_cooldown = AI_SPECIAL_INTERVAL

# Reaparece en el punto indicado (lo llama el gestor de la arena cuando el
# luchador sale de los límites por un agujero o lo empujan fuera del escenario).
func respawn(pos: Vector2) -> void:
	lives -= 1
	damage_changed.emit(_current_damage, lives)
	if (lives <= 0): 
		var players := get_tree().get_nodes_in_group("player")
		
		for p in players:
			if p != self and p.lives > 0:
				GameManager.winner = p.player_id
				# 🌟 NUEVO: Guardamos la ruta física del archivo .tres del ganador
				if p.character_data:
					GameManager.winner_data_path = p.character_data.resource_path
				break
		
		GameManager.change_scene(GameManager.WIN_INDICATOR)
		queue_free()
		return
	global_position = pos
	velocity = Vector2.ZERO
	_knockback_finished = true  # cancela cualquier empuje en curso
	_double_jump_available = true
	# Al morir, el porcentaje de daño acumulado se reinicia (estilo stock).
	_current_damage = 0

# --- MANÁ (recurso común de escudo y proyectil) ---
# ¿Hay maná suficiente para pagar 'cost'? Lo consultan las habilidades antes de
# activarse (ver shield.gd y proyectile.gd).
func has_mana(cost: float) -> bool:
	return _current_mana >= cost

# Gasta maná (no baja de 0) y refresca la barra de la UI.
func spend_mana(cost: float) -> void:
	_current_mana = maxf(_current_mana - cost, 0.0)
	mana_changed.emit(_current_mana, character_data.max_mana)

# Regenera maná (no supera max_mana) y refresca la barra de la UI.
func gain_mana(amount: float) -> void:
	_current_mana = minf(_current_mana + amount, character_data.max_mana)
	mana_changed.emit(_current_mana, character_data.max_mana)

func _on_body_animation_finished() -> void:
	if _body.animation == "Attack" or _body.animation == "Run_Attack":
		_attack_finished = true
		# El ataque acabó: nos aseguramos de dejar la Hitbox apagada.
		$Hitbox.monitoring = false

# Activa la Hitbox solo durante la ventana de impacto del ataque (los frames en
# que el arma conecta). Así el daño se aplica en el frame del swing y no al
# empezar la animación, y las comprobaciones (escudo, alcance) se hacen en vivo.
func _on_body_frame_changed() -> void:
	if _attack_finished:
		return
	if _body.animation != "Attack" and _body.animation != "Run_Attack":
		return
	var frame := _body.frame
	if frame == character_data.attack_active_frame_start:
		# Colocamos la Hitbox delante según la dirección de giro y entramos en la
		# ventana: apagar+encender fuerza a Godot a escanear el área de inmediato
		# aunque la víctima ya esté solapada.
		_place_hitbox()
		$Hitbox.monitoring = false
		$Hitbox.monitoring = true
	elif frame < character_data.attack_active_frame_start or frame > character_data.attack_active_frame_end:
		$Hitbox.monitoring = false

# Coloca la Hitbox DELANTE del personaje, en la dirección a la que mira
# (reflejando la x con _body.scale.x), y le aplica el tamaño del personaje.
# Se llama al arrancar, al girar y en cada golpe; leemos posición y tamaño cada
# vez para poder afinarlos en caliente editando el .tres.
func _place_hitbox() -> void:
	var cs := $Hitbox/CollisionShape2D
	cs.shape.size = character_data.attack_hitbox_size
	cs.position = Vector2(
		character_data.attack_hitbox_offset.x * signf(_body.scale.x),
		character_data.attack_hitbox_offset.y)
		
# Esta función procesará el daño que nos hagan.
# knockback_dir: dirección horizontal del empuje (+1 derecha, -1 izquierda).
# 0.0 (por defecto) significa sin empuje (p.ej. el daño de depuración con P).
func receive_damage(amount: int, knockback_dir: float = 0.0) -> void:
	_current_damage += amount

	# Recibir un golpe regenera maná (más que al atacar). Nota: esto tambien se
	# aplica al daño de depuracion con la tecla P (solo P1), aceptable por ser debug.
	gain_mana(character_data.mana_gain_on_damage)

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

func _play_no_mana_flash() -> void:
	# Destello gris-azulado breve: se intentó usar una habilidad sin maná suficiente.
	modulate = Color(0.4, 0.4, 0.55, 1)
	await get_tree().create_timer(0.15, true, false, true).timeout
	modulate = Color(1, 1, 1, 1)

func _on_hitbox_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	if area.owner == self:
		return # Ignoramos nuestro propio cuerpo

	if (not _attack_finished):
		# Si el objeto de la sala tiene un script con esta función, le restamos vida/daño
		if area.get_parent().has_method("receive_damage") and not area.get_parent()._is_invincible:
			# Empujamos a la víctima hacia donde mira el atacante (self).
			area.get_parent().receive_damage(5, _body.scale.x)
			# Golpear al rival regenera algo de maná (menos que al recibir daño).
			gain_mana(character_data.mana_gain_on_hit)
