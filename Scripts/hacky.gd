extends CharacterBody2D

const SPEED: float = 300.0
const JUMP_VELOCITY: float = -400.0

@export var max_launch_speed: float = 1200.0        # Velocidad máx tras impulso
@export var launch_lock_time: float = 0.12          # Bloqueo de control tras launch
@export var launch_horizontal_drag: float = 1400.0  # Freno horizontal durante bloqueo

var _launch_timer: float = 0.0

func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Salto (bloqueado si estamos en ventana de launch)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and _launch_timer <= 0.0:
		velocity.y = JUMP_VELOCITY

	# Movimiento lateral (con drag si hay launch lock)
	var direction := Input.get_axis("ui_left", "ui_right")
	if _launch_timer > 0.0:
		_launch_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, launch_horizontal_drag * delta)
	else:
		if direction != 0.0:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()

func launch(force: Vector2) -> void:
	if force == Vector2.ZERO:
		return
	_launch_timer = launch_lock_time
	velocity += force
	if velocity.length() > max_launch_speed:
		velocity = velocity.normalized() * max_launch_speed

# Conecta este método al signal `vector_created` del VectorCreator en el editor
func _on_vector_creator_vector_created(vector: Variant) -> void:
	if vector is Vector2 and vector.length() > 0.0:
		launch(vector * 4.0)  # escala libre
