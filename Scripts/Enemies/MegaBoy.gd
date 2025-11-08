extends CharacterBody2D

# Físicas
<<<<<<< HEAD:Scripts/MegaBoy.gd
@export var gravity: float = 900.0
@export var speed: float = 120.0
=======
var gravity = 900.0
var speed = 60.0
>>>>>>> ZtanQ:Scripts/Enemies/MegaBoy.gd

# Estado
var active := false
var direction := -1 # -1 = izquierda, 1 = derecha

func _ready() -> void:
	# IMPORTANTE: grupo exacto en minúsculas
	add_to_group("hack")

func _physics_process(delta: float) -> void:
	# Si no está activo, no hace nada (ni gravedad ni movimiento)
	if not active:
		velocity = Vector2.ZERO
		return

	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	# Movimiento horizontal
	velocity.x = direction * speed

	# Mover con colisiones
	move_and_slide()

	# Si choca con pared, cambia de dirección y voltea sprite
	if is_on_wall():
		direction *= -1
		if has_node("Sprite2D"):
			$Sprite2D.flip_h = direction > 0

# --- ACTIVAR DESDE TECLADO (opcional) ---
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("accion"):
		activate()

func activate() -> void:
	if not active:
		active = true
<<<<<<< HEAD
<<<<<<< HEAD:Scripts/MegaBoy.gd
		print("Enemigo activado")
=======
=======
		$Sprite2D.modulate = Color(1, 0.4, 0.4) # cambia de color al activarse
>>>>>>> ZtanQ
		print("⚠️ Enemigo activado por teclado")
>>>>>>> ZtanQ:Scripts/Enemies/MegaBoy.gd
