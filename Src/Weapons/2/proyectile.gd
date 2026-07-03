extends Area2D

@export var SPEED: float = 300.0
var direction: float = 1.0
var creator: Node2D = null

func _ready() -> void:
	# Creamos un temporizador de 3 segundos para que se destuya automáticamente 
	get_tree().create_timer(3.0).timeout.connect(queue_free) # La función queue_free lo destruye

func _physics_process(delta: float) -> void:
	# Multiplicamos por delta para que se mueva fluido a los mismos fps en cualquier PC.
	position.x += direction * SPEED * delta

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	
	# Si el que tocamos es nuestro creador, lo ignoramos por completo
	if parent == creator:
		return
		
	# Si no es nuestro creador, tiene el método de daño y no es invencible... ¡FUEGO!
	if parent.has_method("receive_damage") and not parent._is_invincible:
		# Empujamos a la víctima en la dirección de vuelo del proyectil.
		parent.receive_damage(5, direction)
		queue_free() # Borramos el proyectil al impactar contra el enemigo
