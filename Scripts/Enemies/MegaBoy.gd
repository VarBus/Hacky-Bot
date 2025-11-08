extends CharacterBody2D

# Físicas
var gravity = 900.0
var speed = 60.0

# Estado
var active = false
var direction = -1 # -1 = izquierda, 1 = derecha

func _physics_process(delta):
	# Si no está activo, no hace nada (ni gravedad ni movimiento)
	if not active:
		velocity = Vector2.ZERO
		return

	# Aplicar gravedad
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# Movimiento horizontal
	velocity.x = direction * speed

	# Mover con colisiones
	move_and_slide()

	# Si choca con pared, cambia de dirección
	if is_on_wall():
		direction *= -1
		$Sprite2D.flip_h = direction > 0

# --- ACTIVAR DESDE TECLADO ---
func _input(event):
	if event.is_action_pressed("accion"):
		activate()

func activate():
	if not active:
		active = true
		$Sprite2D.modulate = Color(1, 0.4, 0.4) # cambia de color al activarse
		print("⚠️ Enemigo activado por teclado")
