extends HackableEntity

@export var vertical_speed: float = 220.0
@export var vertical_drag: float = 1400.0
@export var ignore_gravity_when_hacked: bool = true
@export var carry_bodies_on_top: bool = true
@export var push_only_when_going_up: bool = true

var _riders: Array[CharacterBody2D] = []

@onready var top_sensor: Area2D = get_node_or_null("TopSensor")

func _ready() -> void:
	add_to_group("platform")
	if top_sensor:
		top_sensor.body_entered.connect(_on_top_sensor_body_entered)
		top_sensor.body_exited.connect(_on_top_sensor_body_exited)

func _physics_process(delta: float) -> void:
	if is_hacked:
		return

	velocity.x = move_toward(velocity.x, 0.0, vertical_drag * delta)

	if has_meta("prev_snap"):
		# imán manda
		pass
	else:
		if not is_on_floor():
			velocity += get_gravity() * delta
		else:
			velocity.y = 0.0

	move_and_slide()

# --- Control hackeado: velocidad vertical constante, sin frenarse por el player ---
func _handle_hacked_input(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, vertical_drag * delta)

	if has_meta("prev_snap"):
		move_and_slide()
		return

	if not ignore_gravity_when_hacked:
		if not is_on_floor():
			velocity += get_gravity() * delta
		else:
			velocity.y = 0.0
	else:
		if is_on_floor():
			velocity.y = 0.0

	var v_axis := Input.get_axis("ui_up", "ui_down")  # -1 arriba, +1 abajo
	if v_axis != 0.0:
		velocity.y = v_axis * vertical_speed
	else:
		velocity.y = move_toward(velocity.y, 0.0, vertical_drag * delta)

	# === Truco clave: mover riders primero y desactivar colisiones con ellos ===
	var motion_y := velocity.y * delta
	if carry_bodies_on_top and motion_y != 0.0:
		var going_up := motion_y < 0.0
		if going_up or not push_only_when_going_up:
			_begin_carry_all()      # excepciones de colisión + quitar snap
			_carry_riders(motion_y) # desplazar riders exactamente igual

	move_and_slide()

	# Si dejaste de moverte, restablece estado
	if v_axis == 0.0:
		_end_carry_all()

func release_control() -> void:
	super.release_control()
	_end_carry_all()

# ---------- Riders ----------
func _on_top_sensor_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body != self:
		var t := body as CharacterBody2D
		if not _riders.has(t):
			_riders.append(t)

func _on_top_sensor_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		var t := body as CharacterBody2D
		_riders.erase(t)
		_restore_snap(t)
		# quitar excepción por si quedó activa
		if is_instance_valid(t):
			remove_collision_exception_with(t)
			t.remove_collision_exception_with(self)

func _begin_carry_all() -> void:
	for i in range(_riders.size() - 1, -1, -1):
		var t := _riders[i]
		if not is_instance_valid(t):
			_riders.remove_at(i)
			continue
		# quitar floor snap para que no “empuje”
		if not t.has_meta("plat_prev_snap"):
			t.set_meta("plat_prev_snap", t.floor_snap_length)
		t.floor_snap_length = 0.0
		# EXCEPCIÓN DE COLISIÓN bidireccional: evita que la plataforma choque con el player
		add_collision_exception_with(t)
		t.add_collision_exception_with(self)

func _carry_riders(motion_y: float) -> void:
	for i in range(_riders.size() - 1, -1, -1):
		var t := _riders[i]
		if not is_instance_valid(t):
			_riders.remove_at(i)
			continue
		# moverlos exactamente igual que la plataforma
		t.global_position.y += motion_y
		# igualar velocidad para que su física no “resista”
		t.velocity.y = velocity.y

func _end_carry_all() -> void:
	for i in range(_riders.size() - 1, -1, -1):
		var t := _riders[i]
		if not is_instance_valid(t):
			_riders.remove_at(i)
			continue
		_restore_snap(t)
		remove_collision_exception_with(t)
		t.remove_collision_exception_with(self)

func _restore_snap(t: CharacterBody2D) -> void:
	if not is_instance_valid(t):
		return
	if t.has_meta("plat_prev_snap"):
		t.floor_snap_length = t.get_meta("plat_prev_snap")
		t.remove_meta("plat_prev_snap")
