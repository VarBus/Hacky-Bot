extends CharacterBody2D

# ---- Movimiento base / carry ----
@export var vertical_speed: float = 220.0
@export var vertical_drag: float = 1400.0
@export var carry_bodies_on_top: bool = true
@export var push_only_when_going_up: bool = true

# ---- Auto (ping-pong) ----
@export var auto_enabled: bool = true
@export var auto_requires_magnet: bool = true   # << SOLO se mueve si el imán lo permite
@export var auto_use_markers: bool = false
@export var top_marker_path: NodePath
@export var bottom_marker_path: NodePath
@export var auto_top_offset: float = -160.0     # relativo al Y inicial (negativo = arriba)
@export var auto_bottom_offset: float = 0.0
@export var auto_pause_top: float = 0.25
@export var auto_pause_bottom: float = 0.25
@export var auto_start_moving_up: bool = true   # up = -1, down = +1

# ---- Gravedad según estado ----
@export var ignore_gravity_when_auto: bool = true
@export var ignore_gravity_when_static: bool = true

# Estado interno
var _riders: Array[CharacterBody2D] = []
var _base_y: float
var _auto_top_y: float
var _auto_bottom_y: float
var _auto_dir: int = -1
var _auto_pause_timer: float = 0.0
var _auto_gate: bool = false   # << Lo pone/quita el imán

@onready var top_sensor: Area2D = get_node_or_null("TopSensor")
@onready var _top_marker: Node2D = (get_node_or_null(top_marker_path) as Node2D) if (auto_use_markers and top_marker_path != NodePath("")) else null
@onready var _bottom_marker: Node2D = (get_node_or_null(bottom_marker_path) as Node2D) if (auto_use_markers and bottom_marker_path != NodePath("")) else null

func _ready() -> void:
	add_to_group("platform")

	if top_sensor:
		top_sensor.body_entered.connect(_on_top_sensor_body_entered)
		top_sensor.body_exited.connect(_on_top_sensor_body_exited)

	# Límites de auto
	_base_y = global_position.y
	if auto_use_markers and _top_marker and _bottom_marker:
		_auto_top_y = min(_top_marker.global_position.y, _bottom_marker.global_position.y)
		_auto_bottom_y = max(_top_marker.global_position.y, _bottom_marker.global_position.y)
	else:
		_auto_top_y = min(_base_y + auto_top_offset, _base_y + auto_bottom_offset)
		_auto_bottom_y = max(_base_y + auto_top_offset, _base_y + auto_bottom_offset)

	_auto_dir = -1 if auto_start_moving_up else 1

func _physics_process(delta: float) -> void:
	# Suaviza deriva X
	velocity.x = move_toward(velocity.x, 0.0, vertical_drag * delta)

	var moving_this_frame := false

	# ¿Está permitido el auto? (según gate del imán)
	var auto_ok := auto_enabled and (not auto_requires_magnet or _auto_gate)

	if auto_ok:
		if _auto_pause_timer > 0.0:
			_auto_pause_timer -= delta
			# Sin movimiento -> suelta riders
			_end_carry_all()
		else:
			# Gravedad durante auto
			if ignore_gravity_when_auto:
				if is_on_floor(): velocity.y = 0.0
			else:
				if not is_on_floor(): velocity += get_gravity() * delta
				else: velocity.y = 0.0

			# Calcular desplazamiento sin pasarse del límite
			var desired_motion := float(_auto_dir) * vertical_speed * delta  # - = arriba
			var next_y := global_position.y + desired_motion

			if _auto_dir < 0 and next_y < _auto_top_y:
				desired_motion = _auto_top_y - global_position.y
				_auto_dir = 1
				_auto_pause_timer = auto_pause_top
			elif _auto_dir > 0 and next_y > _auto_bottom_y:
				desired_motion = _auto_bottom_y - global_position.y
				_auto_dir = -1
				_auto_pause_timer = auto_pause_bottom

			velocity.y = (desired_motion / max(delta, 0.000001))
			moving_this_frame = (desired_motion != 0.0)

			# Carry riders
			if carry_bodies_on_top and moving_this_frame:
				var going_up := desired_motion < 0.0
				if going_up or not push_only_when_going_up:
					_begin_carry_all()
					_carry_riders(desired_motion)
	else:
		# Estática: opcionalmente sin gravedad (para que no caiga)
		if ignore_gravity_when_static:
			velocity.y = 0.0
		else:
			if not is_on_floor(): velocity += get_gravity() * delta
			else: velocity.y = 0.0
		_end_carry_all()

	move_and_slide()

# ===== Señales desde el imán =====
# Habilita/deshabilita el auto (se mueve sólo si true)
func _on_magnet_platform_auto(active: bool, source: Node) -> void:
	_auto_gate = active

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
		if is_instance_valid(t):
			remove_collision_exception_with(t)
			t.remove_collision_exception_with(self)

func _begin_carry_all() -> void:
	for i in range(_riders.size() - 1, -1, -1):
		var t := _riders[i]
		if not is_instance_valid(t):
			_riders.remove_at(i)
			continue
		if not t.has_meta("plat_prev_snap"):
			t.set_meta("plat_prev_snap", t.floor_snap_length)
		t.floor_snap_length = 0.0
		add_collision_exception_with(t)
		t.add_collision_exception_with(self)

func _carry_riders(motion_y: float) -> void:
	var going_up := motion_y < 0.0
	for i in range(_riders.size() - 1, -1, -1):
		var t := _riders[i]
		if not is_instance_valid(t):
			_riders.remove_at(i)
			continue
		t.global_position.y += motion_y
		if going_up:
			t.velocity.y = max(t.velocity.y, 0.0)   # evita anim "salto"
		else:
			t.velocity.y = max(velocity.y, t.velocity.y)

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
