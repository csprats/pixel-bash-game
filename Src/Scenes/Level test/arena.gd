extends Node2D

## Gestiona los límites de "muerte" (blast zones) y el respawn de los jugadores.
## Cuando un luchador sale de estos límites (cae por un agujero del nivel o lo
## empujan fuera del escenario), reaparece en su punto de spawn inicial.

## Margen (en px de mundo) más allá del tilemap antes de considerar KO (x = lados,
## y = arriba/abajo).
@export var blast_margin: Vector2 = Vector2(120, 160)
## Límites manuales opcionales; si su tamaño es cero se calculan desde el TileMapLayer.
@export var blast_bounds: Rect2 = Rect2()

@onready var _tilemap: TileMapLayer = $TileMapLayer

# Punto de spawn inicial de cada jugador (jugador -> Vector2).
var _spawn_points: Dictionary = {}

func _ready() -> void:
	# Calculamos los límites desde el tilemap si no se han fijado a mano.
	if blast_bounds.size == Vector2.ZERO:
		blast_bounds = _compute_bounds_from_tilemap()

	# Guardamos el punto de spawn inicial de cada jugador.
	for p in get_tree().get_nodes_in_group("player"):
		_spawn_points[p] = (p as Node2D).global_position

# Deriva los límites de muerte a partir del área ocupada por el tilemap,
# expandida por blast_margin en los cuatro lados.
func _compute_bounds_from_tilemap() -> Rect2:
	var used := _tilemap.get_used_rect()
	var cell := Vector2(_tilemap.tile_set.tile_size)
	var top_left := _tilemap.to_global(Vector2(used.position) * cell)
	var world_rect := Rect2(top_left, Vector2(used.size) * cell)
	return world_rect.grow_individual(
		blast_margin.x, blast_margin.y, blast_margin.x, blast_margin.y)

func _physics_process(_delta: float) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		var node := p as Node2D
		if not blast_bounds.has_point(node.global_position):
			if _spawn_points.has(p) and node.has_method("respawn"):
				node.respawn(_spawn_points[p])
