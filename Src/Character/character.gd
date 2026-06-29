extends CharacterBody2D

@export var character_data: CharacterData
@onready var _body: AnimatedSprite2D = $Body
@onready var _weapon: AnimatedSprite2D = $Weapon

# Estados de control
var _attack_finished: bool = true
var _dash_finished: bool = true

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
	if _attack_finished and _dash_finished and is_on_floor() and Input.is_action_just_pressed("special_attack"):
		if character_data.special_abilities.size() > 0:
			var ability_script = character_data.special_abilities[0]
			if ability_script:
				var new_ability = ability_script.new()
				add_child(new_ability)
				new_ability.activate(self)
				# ¡Fíjate!: NO ponemos queue_free() aquí. La habilidad se destruye sola al terminar el timer.

	# 2. MOVIMIENTO Y FÍSICAS (Solo si NO estamos atacando Y NO estamos en mitad de un dash)
	if _attack_finished and _dash_finished:
		if not is_on_floor():
			velocity += get_gravity() * delta * character_data.gravity_scale
			
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = character_data.jump_force
			
		velocity.x = Input.get_axis("left", "right") * character_data.walk_speed	

	# 3. DETECTAR ATAQUES NORMALES (Solo si no estamos en mitad de un dash)
	if _dash_finished:
		if _attack_finished and (velocity.x < 0 or velocity.x > 0) and is_on_floor() and Input.is_action_just_pressed("attack"):
			_attack_finished = false
			_body.play('Run_Attack')
			_weapon.play('Run_Attack')
		elif _attack_finished and is_on_floor() and Input.is_action_just_pressed("attack"):
			_attack_finished = false  
			_body.play("Attack")
			_weapon.play("Attack")

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
	# Quitado el "Dash" de aquí. El dash lo maneja única y exclusivamente el tiempo.
	if _body.animation == "Attack" or _body.animation == "Run_Attack":
		_attack_finished = true
