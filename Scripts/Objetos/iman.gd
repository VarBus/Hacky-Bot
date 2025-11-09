# ImanLevitar.gd (nodo que contiene el Area2D "GravityArea" y Timer "GravityTimer")
extends HackableEntity

var active: bool = false
@export var target_group: StringName = &"player"

@export var hover_height: float = 120.0  
@export var ascend_speed: float = 320.0  
@export var hover_gain: float = 16.0     
@export var hover_damp: float = 8.0      

var _inside: Array[CharacterBody2D] = []

func _physics_process(delta: float) -> void:
	if not active: return

	for t in _inside:
		if not is_instance_valid(t): continue

		if t.is_on_floor():
			if not t.has_meta("prev_snap"): t.set_meta("prev_snap", t.floor_snap_length)
			t.floor_snap_length = 0.0
			t.global_position.y -= 1.0
			t.velocity.y = -ascend_speed
		t.velocity -= t.get_gravity() * delta
		var target_y := global_position.y - hover_height
		var error := target_y - t.global_position.y
		var v_des = clamp(error * hover_gain, -ascend_speed, ascend_speed)
		t.velocity.y = lerp(t.velocity.y, v_des, clamp(hover_damp * delta, 0.0, 1.0))

# Esta función es llamada por el jugador cuando está hackeando este objeto
func _handle_hacked_input(delta: float) -> void:
	# No hacemos nada con 'delta', solo nos importa el input
	
	# Si el jugador pulsa "shoot", activamos el imán
	if Input.is_action_just_pressed("shoot"):
		activate()

func activate() -> void:
	if active: return
	active = true
	if visual_node:
		visual_node.modulate = Color(1, 0.4, 0.4) # Color "activo"
	$GravityTimer.start()

func deactivate() -> void:
	if not active: return
	active = false
	if visual_node:
		# Al desactivar, comprobamos si el jugador SIGUE apuntándonos/hackeándonos.
		# Si 'is_hacked' es true, volvemos al color de selección (CRIMSON).
		# Si es false, volvemos al color normal (WHITE).
		# La clase base 'HackableEntity' maneja los colores de selección,
		# así que podemos llamar a sus funciones.
		if is_hacked:
			select() # Llama a la función de la base (pone CRIMSON)
		else:
			deselect() # Llama a la función de la base (pone WHITE)
	for t in _inside:
		if is_instance_valid(t) and t.has_meta("prev_snap"):
			t.floor_snap_length = t.get_meta("prev_snap")
			t.remove_meta("prev_snap")

func _on_gravity_area_player_body_entered(body: Node2D) -> void:
	if body.is_in_group(target_group) and body is CharacterBody2D:
		_inside.append(body as CharacterBody2D)

func _on_gravity_area_player_body_exited(body: Node2D) -> void:
	_inside.erase(body)
	if body is CharacterBody2D and body.has_meta("prev_snap"):
		var t := body as CharacterBody2D
		t.floor_snap_length = t.get_meta("prev_snap")
		t.remove_meta("prev_snap")

func _on_gravity_timer_timeout() -> void:
	deactivate()
