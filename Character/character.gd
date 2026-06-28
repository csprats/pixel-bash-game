extends CharacterBody2D

@export var _velocity: float = 200
@export var _jump_velocity: float = -600
@export var _gravity_multiplier: float = 2
@export var _body: AnimatedSprite2D
@export var _weapon: AnimatedSprite2D

# Iniciamos en true porque al empezar la partida no estamos atacando
var _attack_finished: bool = true

func _physics_process(delta: float) -> void:
	
	# Movement and physics
	if not is_on_floor():
		velocity += get_gravity() * delta * _gravity_multiplier
		
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = _jump_velocity
		
	velocity.x = Input.get_axis("left", "right") * _velocity
	
	# 1. Detectar la pulsación de ataque ANTES que el movimiento
	if _attack_finished and is_on_floor() and Input.is_action_just_pressed("attack"):
		_attack_finished = false  # Bloqueamos otras animaciones
		_body.play("Attack")
		_weapon.play("Attack")
		print('attack iniciado')

	# 2. Control del resto de animaciones (Solo si NO estamos en mitad de un ataque)
	if _attack_finished:
		# Corregido el uso de paréntesis para que la lógica del aire y suelo funcione bien
		if not is_on_floor() or (velocity.x < 0 or velocity.x > 0):
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
	if _body.animation == "Attack":
		_attack_finished = true
		print('_attack_finished = true')
