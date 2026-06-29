extends CharacterBody2D

@export var character_data: CharacterData
@onready var _body: AnimatedSprite2D = $Body
@onready var _weapon: AnimatedSprite2D = $Weapon

# Iniciamos en true porque al empezar la partida no estamos atacando
var _attack_finished: bool = true

func _ready() -> void:
	# Nos aseguramos de que haya un .tres cargado
	if character_data:
		# Le pasamos el paquete de animaciones del .tres a los nodos de la escena
		if character_data.body_animations:
			_body.sprite_frames = character_data.body_animations
		if character_data.weapon_animations:
			_weapon.sprite_frames = character_data.weapon_animations
		# Opcional: Reproducir la animación por defecto al empezar
		_body.play("Idle")
		_weapon.play("Idle")
		# CONEXIÓN POR CÓDIGO: Asegura que Godot detecte el final de la animación del .tres
		if not _body.animation_finished.is_connected(_on_body_animation_finished):
			_body.animation_finished.connect(_on_body_animation_finished)

func _physics_process(delta: float) -> void:
	
	# SEGURO: Si no hay un archivo .tres puesto, el personaje se frena aquí y no hace nada
	if not character_data:
		return
	
	# Movement and physics (Ahora usan los datos de tu .tres)
	if not is_on_floor():
		velocity += get_gravity() * delta * character_data.gravity_scale
		
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = character_data.jump_force
		
	velocity.x = Input.get_axis("left", "right") * character_data.walk_speed
	
	# 1. Detectar la pulsación de ataque ANTES que el movimiento
	if (velocity.x < 0 or velocity.x > 0) and is_on_floor() and Input.is_action_just_pressed("attack"):
		_attack_finished = false
		_body.play('Run_Attack')
		_weapon.play('Run_Attack')
	elif _attack_finished and is_on_floor() and Input.is_action_just_pressed("attack"):
		_attack_finished = false  # Bloqueamos otras animaciones
		_body.play("Attack")
		_weapon.play("Attack")

	# 2. Control del resto de animaciones (Solo si NO estamos en mitad de un ataque)
	if _attack_finished:
		if (velocity.x < 0 or velocity.x > 0):
			_body.play("Run")
			_weapon.play("Run")
		elif velocity.y == 0:
			_body.play("Idle")
			_weapon.play("Idle")
	
	# Dirección de la escala (Voltear personaje)
	var direccion := Input.get_axis("left", "right")
	if direccion != 0:
		_body.scale.x = direccion
		_weapon.scale.x = direccion
	
	move_and_slide()

# Recuerda tener esta señal conectada en la pestaña "Nodo" de tu _body
func _on_body_animation_finished() -> void:
	if _body.animation == "Attack" or _body.animation == "Run_Attack":
		_attack_finished = true
