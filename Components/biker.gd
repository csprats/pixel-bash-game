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
@export var jump_force: float = -550.0
@export var double_jump_force: float = -500.0
@export var weight: float = 1.0  # Influye en el knockback (más alto = más pesado)
@export var gravity_scale: float = 1.0

# --- APARIENCIA VISUAL (SPRITES) ---
@export_group("Animaciones")
@export var body_animations: SpriteFrames
@export var weapon_animations: SpriteFrames
