extends CharacterBody2D

signal damage_changed(new_damage: float)

@export var character_data: CharacterData

@onready var _body: AnimatedSprite2D = $Body
@onready var _weapon: AnimatedSprite2D = $Weapon

# Estados de control
var _attack_finished: bool = true
var _dash_finished: bool = true
var _is_invincible: bool = false

var _current_damage: int = 0

func _ready() -> void:
	if character_data:
		if character_data.body_animations:
			_body.sprite_frames = character_data.body_animations
		if character_data.weapon_animations:
			_weapon.sprite_frames = character_data.weapon_animations
		
		_body.play("Idle")
		_weapon.play("Idle")
		
		if not _body.animation_finished.is_connected(_on_body_animation_finished):
			_body.animation_finished.connect(_on_body_animation_finished)

func _physics_process(delta: float) -> void:
	if not character_data:
		return
	
	# 1. DETECTAR ATAQUE ESPECIAL (DASH)
	# Comprobamos que no estemos atacando ni haciendo otro dash
	if _attack_finished and _dash_finished and is_on_floor() and Input.is_action_just_pressed("dash"):
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
				new_ability.activate(self)

	# 2. MOVIMIENTO Y FÍSICAS
	if _attack_finished and _dash_finished:
		if not is_on_floor():
			velocity += get_gravity() * delta * character_data.gravity_scale
			
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = character_data.jump_force
			
		velocity.x = Input.get_axis("left", "right") * character_data.walk_speed	
	else:
		if is_on_floor():
			# Leemos los botones de caminar en tiempo real
			var direccion_actual := Input.get_axis("left", "right")
			
			# Si dejas de pulsar el botón de caminar MIENTRAS atacas en carrera...
			if _body.animation == "Run_Attack" and direccion_actual == 0:
				# Lo frenamos en seco (o puedes usar velocity.x *= 0.7 para que decelere rápido)
				velocity.x = 0
				_body.play("Idle")
				_weapon.play("Idle")
				_attack_finished = true
				
	# 3. DETECTAR ATAQUES NORMALES (Solo si no estamos en mitad de un dash)
	if _dash_finished:
		if _attack_finished and (velocity.x < 0 or velocity.x > 0) and is_on_floor() and Input.is_action_just_pressed("attack"):
			_attack_finished = false
			_body.play('Run_Attack')
			_weapon.play('Run_Attack')
			
			# Despierta la colisión en movimiento
			$Hitbox.monitoring = false
			$Hitbox.monitoring = true
			
		elif _attack_finished and is_on_floor() and Input.is_action_just_pressed("attack"):
			_attack_finished = false  
			_body.play("Attack")
			_weapon.play("Attack")
			
			# Apagamos y encendemos el monitoreo de la Hitbox. 
			# Esto obliga a Godot a escanear el área inmediatamente aunque estés quieto.
			$Hitbox.monitoring = false
			$Hitbox.monitoring = true
			
	if Input.is_key_pressed(KEY_P):
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
		var direccion := Input.get_axis("left", "right")
		if direccion != 0:
			_body.scale.x = direccion
			_weapon.scale.x = direccion
	
	# 6. APLICAR MOVIMIENTO
	move_and_slide()

func _on_body_animation_finished() -> void:
	if _body.animation == "Attack" or _body.animation == "Run_Attack":
		_attack_finished = true
		
# Esta función procesará el daño que nos hagan
func receive_damage(amount: int) -> void:
	_current_damage += amount
	
	damage_changed.emit(_current_damage)

func _on_hurtbox_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	print('hurtbox: area entered')
	print(area)


func _on_hitbox_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	if area.owner == self:
		return # Ignoramos nuestro propio cuerpo
	
	print('hitbox: area entered')
	if (not _attack_finished):
		# Si el objeto de la sala tiene un script con esta función, le restamos vida/daño
		if area.get_parent().has_method("receive_damage"):
			area.get_parent().receive_damage(5)
