extends CharacterBody2D

const Movement2DScript = preload("res://Scripts/Clases/MovementCharacters.gd")
var mover := Movement2DScript.new()

# --- Variables de Hacking ---
@export var hack_distance_max: float = 300.0 # Distancia máxima para mantener el control

var hack_targets: Array[HackableEntity] = [] # Array de enemigos en el rango de hackeo
var current_hack_index: int = -1
var hacked_entity: HackableEntity = null
var is_hacking: bool = false

@onready var hacking_line: Line2D = $HackingLine 

@onready var anim_sprite: AnimatedSprite2D = $Sprite2D
var is_landing: bool = false
var was_in_air: bool = false

func _ready() -> void:
	$HackDetectionArea.body_entered.connect(_on_hack_area_body_entered)
	$HackDetectionArea.body_exited.connect(_on_hack_area_body_exited)
	
	# Asegurarse de que la línea esté oculta al inicio
	hacking_line.hide()
	# Pre-añadir los puntos para que no dé error al setear la posición
	hacking_line.add_point(Vector2.ZERO)
	hacking_line.add_point(Vector2.ZERO)
	
	anim_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	
	# --- LÓGICA DE HACKEO ACTIVO ---
	if is_hacking:
		# --- ¡ARREGLO DE CONTROLES! ---
		# Añadimos la comprobación para salir del hackeo
		if Input.is_action_just_pressed("hack"):
			stop_hacking()
			was_in_air = false
			# No usamos 'return' aquí para que la lógica de la línea se actualice
			return
		# Pasamos el input al enemigo controlado
		if not is_on_floor():
			# Si estás en el aire, reproduce "jump" (o crea una "hack_air" si quieres)
			anim_sprite.play("jump") 
		else:
			# Si estás en el suelo, reproduce "hack"
			anim_sprite.play("hack")
		if is_instance_valid(hacked_entity):
			hacked_entity._handle_hacked_input(delta)
		else:
			stop_hacking() # El objetivo fue destruido o es inválido
		# No seteamos velocity a CERO ni hacemos un 'return' vacío.
		# En su lugar, procesamos la física SIN input horizontal
		# para que la gravedad siga afectando al jugador.
		
		mover.begin_frame(is_on_floor(), delta)
		
		# Forzamos 'dir' a 0, pero dejamos que mover.step() aplique gravedad
		velocity = mover.step(velocity, 0.0, is_on_floor(), delta) 
		
		was_in_air = not is_on_floor() # Actualizar estado de aire
		
		# Aplicar el movimiento (caída)
		move_and_slide()
		
		# --- LÓGICA DE LÍNEA VISUAL (mientras se hackea) ---
		update_hacking_line_target()
		
		# Salimos para no ejecutar la lógica de movimiento normal
		return
	
	# --- 2. LÓGICA DE MOVIMIENTO NORMAL (SI NO ESTAMOS HACKEANDO) ---
	
	# Lógica de Movimiento (Inputs)
	mover.begin_frame(is_on_floor(), delta)
	var dir = Input.get_axis("ui_left", "ui_right")
	if Input.is_action_just_pressed("ui_accept"):
		mover.buffer_jump()
	velocity = mover.step(velocity, dir, is_on_floor(), delta)
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= 0.45

	# --- LÓGICA DE ANIMACIÓN ---
	var is_on_floor_now = is_on_floor()

	if is_landing:
		pass 
	elif not is_on_floor_now:
		anim_sprite.play("jump")
	elif was_in_air and is_on_floor_now:
		is_landing = true 
		anim_sprite.play("aterrizaje")
	elif dir != 0:
		anim_sprite.play("walk")
	else:
		anim_sprite.play("default")

	was_in_air = not is_on_floor_now
	
	# --- Voltear el Sprite ---
	if dir < 0:
		anim_sprite.flip_h = true
	elif dir > 0:
		anim_sprite.flip_h = false

	# --- Ejecutar Movimiento ---
	move_and_slide()
	
	# --- 3. LÓGICA DE LÍNEA Y INPUTS DE HACKEO (SI NO ESTAMOS HACKEANDO) ---
	
	# Lógica de la línea (apuntando)
	update_hacking_line_target()
	
	# Manejar inputs de hackeo (solo si no estamos hackeando)
	handle_hacking_inputs()

# --- NUEVA FUNCIÓN ---
# Una función dedicada para actualizar la línea
func update_hacking_line(target_entity: Node2D) -> void:
	if not hacking_line or not is_instance_valid(target_entity):
		hacking_line.hide()
		return
		
	var player_global_pos = global_position
	var entity_global_pos = target_entity.global_position
			
	hacking_line.set_point_position(0, to_local(player_global_pos))
	hacking_line.set_point_position(1, to_local(entity_global_pos))
			
	if not hacking_line.is_visible():
		hacking_line.show()

# --- MODIFICADA ---
func handle_hacking_inputs():
	# Cambiar de objetivo
	if Input.is_action_just_pressed("change_hack_target") and not hack_targets.is_empty():
		current_hack_index = (current_hack_index + 1) % hack_targets.size()
		update_target_selection()
		
	# Iniciar el hackeo
	if Input.is_action_just_pressed("hack") and current_hack_index != -1:
		start_hacking()
		
# --- Funciones de Gestión del Hacking (MODIFICADAS) ---

func update_target_selection():
	# Deseleccionar todos los objetivos primero
	for i in range(hack_targets.size()):
		if is_instance_valid(hack_targets[i]):
			hack_targets[i].deselect()
	
	# Seleccionar el nuevo objetivo actual
	if current_hack_index != -1 and is_instance_valid(hack_targets[current_hack_index]):
		hack_targets[current_hack_index].select()
		# --- LÍNEA AÑADIDA ---
		# Mostramos la línea apuntando al objetivo seleccionado
		update_hacking_line(hack_targets[current_hack_index])
	else:
		# --- LÍNEA AÑADIDA ---
		# Si no hay objetivo válido, ocultamos la línea
		hacking_line.hide()


func start_hacking():
	if hack_targets.is_empty() or current_hack_index == -1: return

	hacked_entity = hack_targets[current_hack_index]
	
	hacked_entity.control_released.connect(stop_hacking, CONNECT_ONE_SHOT)
	hacked_entity.take_control(self)
	is_hacking = true
	velocity = Vector2.ZERO
	
	# La línea ya debería estar visible, pero nos aseguramos
	update_hacking_line(hacked_entity)

func stop_hacking():
	if not is_hacking: return

	is_hacking = false
	if is_instance_valid(hacked_entity):
		if hacked_entity.is_connected("control_released", stop_hacking):
			hacked_entity.control_released.disconnect(stop_hacking)
		if hacked_entity.is_hacked:
			hacked_entity.release_control()

	hacked_entity = null
	print("El jugador ha recuperado el control.")
	
	# --- LÓGICA DE LÍNEA MODIFICADA ---
	# Al parar de hackear, comprobamos si seguimos apuntando a algo
	if current_hack_index != -1 and is_instance_valid(hack_targets[current_hack_index]):
		# Si sí, actualizamos la línea para que apunte a ese algo
		update_hacking_line(hack_targets[current_hack_index])
	else:
		# Si no, ocultamos la línea
		hacking_line.hide()
	
# --- Manejo de la Detección de Área (MODIFICADO) ---

func _on_hack_area_body_entered(body: Node) -> void:
	if body is HackableEntity and not hack_targets.has(body):
		hack_targets.append(body)
		if current_hack_index == -1:
			current_hack_index = 0
			update_target_selection() # Esto ya se encarga de mostrar la línea

func _on_hack_area_body_exited(body: Node) -> void:
	if body is HackableEntity and hack_targets.has(body):
		var exited_index = hack_targets.find(body)
		
		if hacked_entity == body:
			stop_hacking()
		
		body.deselect()
		hack_targets.erase(body)
		
		if hack_targets.is_empty():
			current_hack_index = -1
			# --- LÍNEA AÑADIDA ---
			# Si no quedan objetivos, ocultamos la línea
			hacking_line.hide()
		else:
			if current_hack_index >= exited_index:
				current_hack_index = max(0, current_hack_index - 1)
		
		# Actualizamos la selección (esto mostrará la línea al nuevo objetivo)
		update_target_selection()
# --- AÑADIR ESTA NUEVA FUNCIÓN AL FINAL DEL SCRIPT ---

# Esta función se llama automáticamente cuando cualquier animación en $Sprite2D termina
func _on_animation_finished():
	# Si la animación que terminó es "aterrizaje"
	if anim_sprite.animation == "aterrizaje":
		# Desbloqueamos el estado para que la lógica de "walk" o "default"
		# pueda ejecutarse en el próximo frame de _physics_process.
		is_landing = false

# --- NUEVA FUNCIÓN HELPER PARA LA LÍNEA ---
# Esta función decide a qué debe apuntar la línea (o si debe ocultarse)
func update_hacking_line_target():
	var target_entity: HackableEntity = null
	
	if is_hacking and is_instance_valid(hacked_entity):
		# 1. Si estamos hackeando, el objetivo es la entidad hackeada
		target_entity = hacked_entity
	elif not is_hacking and current_hack_index != -1 and is_instance_valid(hack_targets[current_hack_index]):
		# 2. Si NO estamos hackeando, pero SÍ tenemos un objetivo seleccionado
		target_entity = hack_targets[current_hack_index]
	
	# Actualizar la línea si tenemos un objetivo, ocultarla si no
	if target_entity:
		update_hacking_line(target_entity) # La función que ya tenías
	else:
		if hacking_line: hacking_line.hide()
