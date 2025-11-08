extends CharacterBody2D

# Velocidad de movimiento del jugador
@export var speed: float = 200.0

# Gravedad y salto (opcional si el juego tiene plataformas)
@export var gravity: float = 600.0
@export var jump_force: float = -400.0

# Detecta si hay salto
var is_jumping: bool = false

func _physics_process(delta: float) -> void:
	# Aplicar gravedad
	if not is_on_floor():
		velocity.y += gravity * delta

	# Movimiento lateral (izquierda / derecha)
	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed

	# Salto
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_force
		is_jumping = true

	# Mover al jugador
	move_and_slide()

	# Opcional: voltear sprite según dirección
	if $Sprite2D:
		if direction < 0:
			$Sprite2D.flip_h = true
		elif direction > 0:
			$Sprite2D.flip_h = false
