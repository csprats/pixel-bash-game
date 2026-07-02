extends CharacterBody2D

signal damage_changed(new_damage: float)

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
var _is_invincible: bool = false

var _current_damage: int = 0

var _instanced_abilities: Array[Node] = []

func _ready() -> void:
	# Las acciones de este slot deben existir en el Input Map.
	for a in ["jump", "left", "right", "attack", "dash", "shield", "proyectile"]:
		assert(InputMap.has_action(_action(a)), "Falta accion de input: " + _action(a))

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
	'''if _attack_finished and _dash_finished and is_on_floor() and Input.is_action_just_pressed("dash"):
		if character_data.special_abilities.size() > 0:
			var ability_script = character_data.special_abilities[0]
			if ability_script:
				var new_ability = ability_script.new()
				add_child(new_ability)
				new_ability.activate(self)
	if _attack_finished and _dash_finished and is_on_floor() and Input.is_action_just_pressed("shield"):
		if character_data.special_abilities.size() > 0:
			var ability_script = character_data.special_abilities[1]
			if ability_script:
				var new_ability = ability_script.new()
				add_child(new_ability)
				new_ability.activate(self)'''
	if _attack_finished and _dash_finished and is_on_floor():
		for ability in _instanced_abilities:
			if _pressed(ability.input_action):
				ability.activate(self)
				break

	# 2. MOVIMIENTO Y FÍSICAS
	if _attack_finished and _dash_finished:
		if not is_on_floor():
			velocity += get_gravity() * delta * character_data.gravity_scale
			
		if _pressed("jump") and is_on_floor():
			velocity.y = character_data.jump_force

		velocity.x = _axis() * character_data.walk_speed
	else:
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
				
	# 3. DETECTAR ATAQUES NORMALES (Solo si no estamos en mitad de un dash)
	if _dash_finished:
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
	if control_mode == ControlMode.HUMAN and player_id == 1 and Input.is_key_pressed(KEY_P):
		receive_damage(1) # Suma 0.5% por cada frame que la pulses

	# 4. CONTROL DE ANIMACIONES DE MOVIMIENTO
	if _attack_finished and _dash_finished:
		if (velocity.x < 0 or velocity.x > 0):
			_body.play("Run")
			_weapon.play("Run")
		elif velocity.y == 0:
			_body.play("Idle")
			_weapon.play("Idle")
	
	# 5. DIRECCIÓN DEL SPRITE (No permitimos girar en mitad del dash)
	if _dash_finished:
		var direccion := _axis()
		if direccion != 0:
			_body.scale.x = direccion
			_weapon.scale.x = direccion
	
	# 6. APLICAR MOVIMIENTO
	move_and_slide()

	# 7. WRAP-AROUND: reaparecer por la pared opuesta
	_wrap_around_screen()

# Si el personaje cruza un borde lateral, reaparece por el borde opuesto.
func _wrap_around_screen() -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return

	# Ancho visible en unidades de mundo (tiene en cuenta el zoom de la cámara)
	var view_width := get_viewport_rect().size.x / camera.zoom.x
	var center_x := camera.get_screen_center_position().x
	var left := center_x - view_width / 2.0
	var right := center_x + view_width / 2.0

	# Desplazamos exactamente un ancho de pantalla: sin parpadeo, el personaje
	# reaparece a la misma profundidad por el lado contrario.
	if global_position.x < left:
		global_position.x += view_width
	elif global_position.x > right:
		global_position.x -= view_width

func _on_body_animation_finished() -> void:
	if _body.animation == "Attack" or _body.animation == "Run_Attack":
		_attack_finished = true
		
# Esta función procesará el daño que nos hagan
func receive_damage(amount: int) -> void:
	_current_damage += amount

	damage_changed.emit(_current_damage)
	_play_hit_flash()
	_apply_hitstop()

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

func _on_hurtbox_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	print('hurtbox: area entered')
	print(area)


func _on_hitbox_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	if area.owner == self:
		return # Ignoramos nuestro propio cuerpo
	
	print('hitbox: area entered')
	if (not _attack_finished):
		# Si el objeto de la sala tiene un script con esta función, le restamos vida/daño
		if area.get_parent().has_method("receive_damage") and not area.get_parent()._is_invincible:
			area.get_parent().receive_damage(5)
