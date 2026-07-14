extends Resource
class_name CharacterData

# --- DATOS DE IDENTIDAD ---
@export_group("Identidad")
@export var character_name: String = "Personaje"
@export var character_icon: Texture2D

# --- ESTADÍSTICAS DE MOVIMIENTO ---
@export_group("Movimiento")
@export var walk_speed: float = 250.0
@export var dash_speed: float = 450.0
@export var dash_duration: float = 0.1
@export var jump_force: float = -550.0
@export var double_jump_force: float = -500.0
@export var weight: float = 1.0  # Influye en el knockback (más alto = más pesado)
@export var gravity_scale: float = 1.0

# --- APARIENCIA VISUAL (SPRITES) ---
@export_group("Animaciones")
@export var body_animations: SpriteFrames
@export var weapon_animations: SpriteFrames

# --- VENTANA DE IMPACTO DEL ATAQUE ---
# Frames (base 0) de la animación de ataque en los que la Hitbox está activa,
# es decir, cuando el arma "conecta". Fuera de esta ventana la Hitbox no hace
# daño, así el golpe registra en el frame del swing y no al empezar la animación.
# Se configura por personaje porque cada SpriteFrames puede tener otro timing.
@export_group("Ataque")
@export var attack_active_frame_start: int = 2
@export var attack_active_frame_end: int = 4
# Geometría de la Hitbox del golpe. Se coloca DELANTE del personaje, en la
# dirección a la que mira (se refleja con _body.scale.x), para que el daño
# coincida con el alcance del arma y no con el propio cuerpo. offset.x es la
# distancia hacia delante; offset.y el ajuste vertical; size el área del golpe.
# Por personaje porque cada arma tiene un alcance distinto.
@export var attack_hitbox_offset: Vector2 = Vector2(14, 4)
@export var attack_hitbox_size: Vector2 = Vector2(22, 34)


@export_group("Habilidades")
@export var shield_duration: float = 1
@export var special_abilities: Array[GDScript] = []

# --- MANÁ ---
# Recurso común que gastan el escudo y el proyectil. La barra arranca llena
# (max_mana) y se regenera al golpear al rival (poco) o al recibir daño (más).
@export_group("Maná")
@export var max_mana: float = 100.0
@export var shield_mana_cost: float = 40.0
@export var projectile_mana_cost: float = 25.0
@export var mana_gain_on_hit: float = 8.0      # al golpear al rival
@export var mana_gain_on_damage: float = 20.0  # al recibir un golpe

# --- EMPUJE AL RECIBIR DAÑO (KNOCKBACK) ---
# Al estilo Smash: cuanto más daño acumulado tiene el luchador, más lejos sale
# despedido. Todo se divide por "weight" (más pesado = menos empuje).
@export_group("Knockback")
@export var knockback_base: float = 130.0  # Empuje horizontal con 0% de daño
@export var knockback_scale: float = 7.0  # Empuje horizontal extra por cada punto de daño acumulado
@export var knockback_pop: float = -170.0  # Componente vertical (negativo = hacia arriba)
@export var knockback_duration: float = 0.15  # Cuánto tiempo controla la velocidad el empuje
