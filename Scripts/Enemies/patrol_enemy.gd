# PatrolEnemy.gd
extends HackableEntity

const Movement2DScript = preload("res://Scripts/Clases/MovementCharacters.gd")
var mover := Movement2DScript.new()
var direction: int = -1

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
