extends Camera2D

## Cámara estilo brawl: sigue a todos los luchadores del grupo "player" y ajusta
## el zoom dinámicamente para mantenerlos a todos encuadrados. Vive en el shell
## persistente (main_scene), por lo que sobrevive a los cambios de escena; cuando
## no hay jugadores (p.ej. en el menú) se queda quieta.

## Margen (en px de mundo) alrededor del grupo de jugadores al encuadrar.
@export var margin: float = 48.0
## Zoom mínimo (más alejado). En Godot, zoom mayor = más cerca.
@export var min_zoom: float = 0.6
## Zoom máximo (más cercano).
@export var max_zoom: float = 1.0
## Velocidad de interpolación del zoom (mayor = más rápido).
@export var zoom_speed: float = 5.0

var initial_position: Vector2 = global_position
var initial_zoom: Vector2 = zoom

func _physics_process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		# Si no hay jugadores, devolvemos la cámara hacia su posición inicial
		global_position = global_position.lerp(initial_position, 1.0 - exp(-zoom_speed * delta))
		zoom = zoom.lerp(initial_zoom, 1.0 - exp(-zoom_speed * delta))
		return

	# 1. AABB que contiene a todos los jugadores.
	var min_pos := (players[0] as Node2D).global_position
	var max_pos := min_pos
	for p in players:
		var pos := (p as Node2D).global_position
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)

	var center := (min_pos + max_pos) * 0.5
	var span := max_pos - min_pos

	# 2. Seguimiento: position_smoothing_enabled suaviza la transición por nosotros.
	global_position = center

	# 3. Zoom dinámico: encajamos el AABB (+ margen) en el viewport.
	var viewport := get_viewport_rect().size
	var desired := span + Vector2(margin, margin) * 2.0
	desired.x = maxf(desired.x, 1.0)
	desired.y = maxf(desired.y, 1.0)
	var zoom_fit := minf(viewport.x / desired.x, viewport.y / desired.y)
	zoom_fit = clampf(zoom_fit, min_zoom, max_zoom)

	# Interpolación suave e independiente del framerate.
	var target_zoom := Vector2(zoom_fit, zoom_fit)
	zoom = zoom.lerp(target_zoom, 1.0 - exp(-zoom_speed * delta))
