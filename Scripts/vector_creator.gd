extends Area2D

signal vector_created(vector: Vector2) # Vector en MUNDO

@export var maximum_length: float = 200.0
@export var min_length: float = 8.0

# Máscara de colisión para qué capas puede golpear (enemigos, etc.)
@export var ray_collision_mask: int = 1
@export var collide_with_areas: bool = false

# Margen visual del "ray hit"
@export var ray_hit_margin: float = 2.0

# Grosor del trazo "sólido" para detectar a los del grupo "hack"
@export var collision_thickness: float = 18.0
@export var max_results: int = 64

@onready var cam: Camera2D = get_viewport().get_camera_2d()

var dragging := false
var start_ws := Vector2.ZERO
var end_ws := Vector2.ZERO
var vec_ws := Vector2.ZERO
var _hit_info: Dictionary = {}

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_touch"):
		var p := _pointer_screen_pos(event)
		dragging = true
		start_ws = _screen_to_world(p)
		end_ws = start_ws
		_update_to(_screen_to_world(p))
		queue_redraw()
		return

	if dragging:
		var is_move := event is InputEventMouseMotion or event is InputEventScreenDrag
		if is_move:
			var p := _pointer_screen_pos(event)
			_update_to(_screen_to_world(p))
			queue_redraw()
			return

		if event.is_action_released("ui_touch"):
			dragging = false
			if vec_ws.length() >= min_length:
				# 1) Emitimos el vector para el launch del player
				vector_created.emit(vec_ws)
				# 2) Activamos a los del grupo "hack" que toque el trazo
				_activate_hacks_between(start_ws, end_ws)
			_clear()
			queue_redraw()

func _pointer_screen_pos(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton: return event.position
	if event is InputEventScreenTouch: return event.position
	if event is InputEventMouseMotion: return event.position
	if event is InputEventScreenDrag:  return event.position
	return get_viewport().get_mouse_position()

func _screen_to_world(p: Vector2) -> Vector2:
	if cam != null:
		return cam.screen_to_world(p)
	return get_global_mouse_position()

func _update_to(desired_end_ws: Vector2) -> void:
	var raw := desired_end_ws - start_ws
	if raw == Vector2.ZERO:
		end_ws = start_ws
		vec_ws = Vector2.ZERO
		return

	var dir := raw.normalized()
	var raw_len := raw.length()
	var limited_len = min(raw_len, maximum_length)
	var target_ws = start_ws + dir * limited_len

	# RAY para recortar contra paredes (opcional, visual)
	var params := PhysicsRayQueryParameters2D.new()
	params.from = start_ws + dir * 0.001
	params.to = target_ws
	params.collision_mask = ray_collision_mask
	params.collide_with_bodies = true
	params.collide_with_areas = collide_with_areas
	params.exclude = [self]

	_hit_info = get_world_2d().direct_space_state.intersect_ray(params)
	if _hit_info:
		var hit_pos: Vector2 = _hit_info.position
		end_ws = hit_pos - dir * ray_hit_margin
	else:
		end_ws = target_ws

	# Vector final (estilo gomita: invertido)
	var final := end_ws - start_ws
	vec_ws = -final

func _draw() -> void:
	if not dragging:
		return
	var lstart := to_local(start_ws)
	var lend := to_local(end_ws)
	draw_line(lstart, lend, Color.RED, 8.0)
	if _hit_info:
		var p := to_local(_hit_info.position)
		draw_circle(p, 5.0, Color(1, 0.5, 0.2, 1.0))

func _clear() -> void:
	start_ws = Vector2.ZERO
	end_ws = Vector2.ZERO
	vec_ws = Vector2.ZERO
	_hit_info.clear()

func _activate_hacks_between(a_ws: Vector2, b_ws: Vector2) -> void:
	var seg := b_ws - a_ws
	var length := seg.length()
	if length < 1.0:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, collision_thickness)
	var center := (a_ws + b_ws) * 0.5
	var rot := seg.angle()

	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = rect
	q.transform = Transform2D(rot, center)
	q.collision_mask = ray_collision_mask
	q.collide_with_bodies = true
	q.collide_with_areas = collide_with_areas
	q.exclude = [self]

	var hits := get_world_2d().direct_space_state.intersect_shape(q, max_results)
	for h in hits:
		var col = h.get("collider")
		if col and col.is_in_group("hack") and col.has_method("activate"):
			col.activate()
