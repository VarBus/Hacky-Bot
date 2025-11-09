extends HackableEntity

var active: bool = false
@export var target_group: StringName = &"platform"

@export var hover_height: float = 120.0
@export var ascend_speed: float = 320.0
@export var hover_gain: float = 16.0
@export var hover_damp: float = 8.0
@export var auto_deactivate_seconds: float = 1.2

var _inside: Array[CharacterBody2D] = []

@onready var gravity_area_player: Area2D = get_node_or_null("GravityAreaPlayer")
@onready var gravity_timer: Timer = get_node_or_null("GravityTimer")

func _ready() -> void:
	# Conecta señales por código para evitar nulls si se desenlaza en el editor.
	if gravity_area_player:
		gravity_area_player.body_entered.connect(_on_gravity_area_player_body_entered)
		gravity_area_player.body_exited.connect(_on_gravity_area_player_body_exited)
	if gravity_timer:
		gravity_timer.one_shot = true
		gravity_timer.timeout.connect(_on_gravity_timer_timeout)

# === Control mientras está hackeado ===
func _handle_hacked_input(delta: float) -> void:
	if Input.is_action_just_pressed("shoot"):
		activate()

func _physics_process(delta: float) -> void:
	if not active:
		return

	# Iteramos al revés porque podemos borrar elementos
	for i in range(_inside.size() - 1, -1, -1):
		var t := _inside[i]
		if not is_instance_valid(t):
			_inside.remove_at(i)
			continue

		# Preparar el “despegue” si estaba en el piso
		if t.is_on_floor():
			if not t.has_meta("prev_snap"):
				t.set_meta("prev_snap", t.floor_snap_length)
			t.floor_snap_length = 0.0

			# Pequeño nudge para separarlo del suelo y dar impulso inicial
			t.global_position.y -= 1.0
			t.velocity.y = -ascend_speed

		# Anular la gravedad propia mientras está agarrado por el imán
		t.velocity -= t.get_gravity() * delta

		# Altura objetivo: hover_height por debajo del imán
		var target_y := global_position.y - hover_height
		var error := target_y - t.global_position.y

		# Velocidad vertical deseada (control proporcional con saturación)
		var v_des = clamp(error * hover_gain, -ascend_speed, ascend_speed)

		# Amortiguación hacia la velocidad deseada
		t.velocity.y = lerp(t.velocity.y, v_des, clamp(hover_damp * delta, 0.0, 1.0))

func activate() -> void:
	if active:
		return
	active = true

	if visual_node:
		visual_node.modulate = Color(1, 0.4, 0.4) # feedback “activo”

	if gravity_timer:
		gravity_timer.stop()
		gravity_timer.wait_time = auto_deactivate_seconds
		gravity_timer.start()

func deactivate() -> void:
	if not active:
		return
	active = false

	# Restaurar color según si sigue hackeado o no
	if visual_node:
		if is_hacked:
			select()
		else:
			deselect()

	# Restablecer floor_snap_length a todos los cuerpos que aún tengamos
	for i in range(_inside.size() - 1, -1, -1):
		var t := _inside[i]
		if is_instance_valid(t):
			_restore_snap(t)

func _on_gravity_area_player_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group(target_group):
		var t := body as CharacterBody2D
		if not _inside.has(t):
			_inside.append(t)

func _on_gravity_area_player_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		var t := body as CharacterBody2D
		_inside.erase(t)
		_restore_snap(t)

func _on_gravity_timer_timeout() -> void:
	deactivate()

func _restore_snap(t: CharacterBody2D) -> void:
	if not is_instance_valid(t):
		return
	if t.has_meta("prev_snap"):
		t.floor_snap_length = t.get_meta("prev_snap")
		t.remove_meta("prev_snap")
