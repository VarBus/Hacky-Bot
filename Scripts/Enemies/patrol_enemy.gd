# PatrolEnemy.gd
extends HackableEntity

const Movement2DScript = preload("res://Scripts/Clases/MovementCharacters.gd")
var mover := Movement2DScript.new()
var direction: int = 0

@onready var death_timer:Timer = $Muerte
@export var slow_motion_duration: float = 0.5
## Escala de tiempo durante el slow motion
@export var slow_motion_scale: float = 0.5

@onready var hurtbox: Area2D = $Hurtbox 


func _on_hurtbox_body_entered(body: Node2D) -> void:
	# Solo infligimos daño si NO estamos hackeados.
	if is_hacked:
		return
		
	if body.is_in_group("player"):
		Engine.time_scale = slow_motion_scale
		death_timer.start(slow_motion_duration)

		# Llama a la función de daño/muerte del jugador.
		# Asegúrate de que tu clase de jugador tiene una función para manejar su muerte.
		# Por ejemplo, una función 'die()' o 'take_damage()'.
		print("¡El enemigo ha chocado con el jugador y lo va a matar!")
		# Ejemplo: body.die() o get_tree().reload_current_scene()
		body.die() # <- Asume que el script del jugador tiene esta función.
		


func _physics_process(delta: float) -> void:
	# Si estamos hackeados, la lógica de control la maneja el jugador
	# a través de _handle_hacked_input.
	if is_hacked:
		return

	# --- IA de movimiento autónomo (cuando no está hackeado) ---
	mover.begin_frame(is_on_floor(), delta)
	velocity = mover.step(velocity, direction, is_on_floor(), delta)
	move_and_slide()

	if is_on_wall():
		direction *= -1
		if has_node("Sprite2D"):
			if has_node("AnimatedSprite2D"):
				$AnimatedSprite2D.flip_h = direction > 0
			
# --- Implementación de las funciones de HackableEntity ---

# Sobreescribimos la función para definir el control del jugador
func _handle_hacked_input(delta: float) -> void:
	# Aquí ponemos la lógica de control del jugador sobre este enemigo
	mover.begin_frame(is_on_floor(), delta)
	
	var input_dir := Input.get_axis("ui_left", "ui_right")
	
	if Input.is_action_just_pressed("ui_accept"): # El enemigo puede saltar
		mover.buffer_jump()
		
	# Si presionas la acción de 'disparar' (debes crearla en el Input Map)
	if Input.is_action_just_pressed("shoot"):
		_perform_action()

	velocity = mover.step(velocity, input_dir, is_on_floor(), delta)
	
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= 0.45
		
	move_and_slide()
	
	# Actualizar la dirección del sprite según el input
	if input_dir != 0:
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.flip_h = input_dir > 0

# La acción específica de este enemigo
func _perform_action() -> void:
	print("¡El enemigo patrulla dispara!")
	# Aquí iría tu lógica de disparo (instanciar una bala, etc.)

# Sobreescribimos release_control para que reinicie su patrulla
func release_control() -> void:
	super.release_control() # Llama a la función original de la clase base
	# Al soltar el control, que mire en la dirección que se movía
	direction = -1 if velocity.x <= 0 else 1
	$AnimatedSprite2D.flip_h = direction > 0


func _on_muerte_timeout() -> void:
	Engine.time_scale = 1.0
	print("[Cámara] Reiniciando nivel...")
	_reload_level()
	
	
func _reload_level() -> void:
	get_tree().reload_current_scene()
