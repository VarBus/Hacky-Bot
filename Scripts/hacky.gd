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

# --- NUEVO: Variables de Sonido ---
@onready var SfxWalk: AudioStreamPlayer2D = $SfxWalk
@onready var SfxJump: AudioStreamPlayer2D = $SfxJump
@onready var SfxHack: AudioStreamPlayer2D = $SfxHack
@onready var SfxIdle: AudioStreamPlayer2D = $SfxIdle # Descomenta si lo usas

@export_group("Sound Pitches")
@export var pitch_variations_walk: Array[float] = [0.95, 1.0, 1.05]
@export var pitch_variations_jump: Array[float] = [0.9, 1.0, 1.1]
@export var pitch_variations_hack: Array[float] = [0.9, 1.0, 1.1]
@export var pitch_variations_idle: Array[float] = [1.0] # Descomenta si lo usas

# --- NUEVAS VARIABLES ---
@export_group("Wall Jump")
@export var wall_jump_speed: float = 400.0 # Fuerza vertical del salto
@export var wall_push_speed: float = 400.0 # Fuerza horizontal (para alejarte)
@export var wall_slide_gravity: float = 200.0 # Gravedad reducida al deslizarte
# --- FIN NUEVAS VARIABLES ---

func _ready() -> void:
	$HackDetectionArea.body_entered.connect(_on_hack_area_body_entered)
	$HackDetectionArea.body_exited.connect(_on_hack_area_body_exited)
	
	hacking_line.hide()
	hacking_line.add_point(Vector2.ZERO)
	hacking_line.add_point(Vector2.ZERO)
	
	anim_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	
	# --- 1. LÓGICA DE HACKEO ACTIVO ---
	if is_hacking:
		# Añadimos la comprobación para salir del hackeo
		if Input.is_action_just_pressed("hack"):
			stop_hacking()
			was_in_air = false
			return # Usamos return para que la lógica de la línea no se actualice
		
		# Animaciones mientras se hackea
		if not is_on_floor():
			anim_sprite.play("jump")
		else:
			anim_sprite.play("hack")
		
		# Pasamos el input al enemigo controlado
		if is_instance_valid(hacked_entity):
			hacked_entity._handle_hacked_input(delta)
		else:
			stop_hacking() # El objetivo fue destruido o es inválido
		
		mover.begin_frame(is_on_floor(), delta)
		
		# Forzamos 'dir' a 0, pero dejamos que mover.step() aplique gravedad
		velocity = mover.step(velocity, 0.0, is_on_floor(), delta)
		
		was_in_air = not is_on_floor() # Actualizar estado de aire
		
		# Aplicar el movimiento (caída)
		move_and_slide()
		
		# Lógica de línea visual (mientras se hackea)
		update_hacking_line_target()
		
		# Salimos para no ejecutar la lógica de movimiento normal
		return
	
	# --- 2. LÓGICA DE MOVIMIENTO NORMAL (SI NO ESTAMOS HACKEANDO) ---
	
	var is_on_floor_now = is_on_floor()
	# Variable para wall jump
	var is_on_wall_now = is_on_wall() and not is_on_floor_now
	
	# Lógica de Movimiento (Inputs)
	mover.begin_frame(is_on_floor_now, delta)
	var dir = Input.get_axis("ui_left", "ui_right")

	# --- MODIFICADO: Lógica de movimiento y salto ---
	
	# Si te deslizas por la pared y estás cayendo, reduce la gravedad
	if is_on_wall_now and velocity.y > 0:
		# Aplicamos la lógica de movimiento base (gravedad, etc.)
		velocity = mover.step(velocity, dir, is_on_floor_now, delta)
		# Pero limitamos la velocidad de caída a 'wall_slide_gravity'
		velocity.y = min(velocity.y, wall_slide_gravity)
	
	# Si no estamos deslizando
	else:
		# Solo buffereamos el salto normal si NO estamos en una pared
		if Input.is_action_just_pressed("ui_accept") and not is_on_wall_now:
			mover.buffer_jump()
		
		# Aplicamos la lógica de movimiento normal de tu clase 'mover'
		velocity = mover.step(velocity, dir, is_on_floor_now, delta)

	# --- NUEVO: Lógica de Wall Jump ---
	# Esto se ejecuta DESPUÉS de mover.step() para anular la velocidad
	if is_on_wall_now and Input.is_action_just_pressed("ui_accept"):
		var wall_normal = get_wall_normal()
		
		# Aplicamos la fuerza vertical
		velocity.y = -wall_jump_speed 
		# Aplicamos la fuerza horizontal para empujarte LEJOS de la pared
		velocity.x = wall_normal.x * wall_push_speed
		play_sfx_random(SfxJump, pitch_variations_jump)

	# Salto de altura variable (sin cambios)
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= 0.45

	# --- LÓGICA DE ANIMACIÓN ---
	if is_landing:
		pass
	# Opcional: Descomenta si creas una animación de "wall_slide"
	# elif is_on_wall_now and velocity.y > 0:
	# 	anim_sprite.play("wall_slide")
	elif not is_on_floor_now:
		anim_sprite.play("jump")
		SfxWalk.stop()
		SfxIdle.stop()
		if was_in_air == false:
			play_sfx_random(SfxJump, pitch_variations_jump) # AÑADIDO
	elif was_in_air and is_on_floor_now:
		is_landing = true
		anim_sprite.play("aterrizaje")
	elif dir != 0:
		anim_sprite.play("walk")
		SfxIdle.stop()
		play_loop_sfx_random(SfxWalk, pitch_variations_walk)
	else:
		anim_sprite.play("default")
		SfxWalk.stop()
		play_loop_sfx_random(SfxIdle, pitch_variations_idle)

	was_in_air = not is_on_floor_now
	
	# --- MODIFICADO: Voltear el Sprite ---
	# No volteamos el sprite si el jugador está contra la pared
	if is_on_wall_now:
		# Al estar en la pared, siempre miramos hacia afuera
		anim_sprite.flip_h = get_wall_normal().x > 0
	elif dir < 0:
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

func handle_hacking_inputs():
	# Cambiar de objetivo
	if Input.is_action_just_pressed("change_hack_target") and not hack_targets.is_empty():
		current_hack_index = (current_hack_index + 1) % hack_targets.size()
		update_target_selection()
		
	# Iniciar el hackeo
	if Input.is_action_just_pressed("hack") and current_hack_index != -1:
		start_hacking()
		
func update_target_selection():
	# Deseleccionar todos los objetivos primero
	for i in range(hack_targets.size()):
		if is_instance_valid(hack_targets[i]):
			hack_targets[i].deselect()
	
	# Seleccionar el nuevo objetivo actual
	if current_hack_index != -1 and is_instance_valid(hack_targets[current_hack_index]):
		hack_targets[current_hack_index].select()
		# Mostramos la línea apuntando al objetivo seleccionado
		update_hacking_line(hack_targets[current_hack_index])
	else:
		# Si no hay objetivo válido, ocultamos la línea
		hacking_line.hide()


func start_hacking():
	if hack_targets.is_empty() or current_hack_index == -1: return

	hacked_entity = hack_targets[current_hack_index]
	
	hacked_entity.control_released.connect(stop_hacking, CONNECT_ONE_SHOT)
	hacked_entity.take_control(self)
	is_hacking = true
	velocity = Vector2.ZERO
	
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
	
	if current_hack_index != -1 and is_instance_valid(hack_targets[current_hack_index]):
		update_hacking_line(hack_targets[current_hack_index])
	else:
		hacking_line.hide()
	
func _on_hack_area_body_entered(body: Node) -> void:
	if body is HackableEntity and not hack_targets.has(body):
		hack_targets.append(body)
		if current_hack_index == -1:
			current_hack_index = 0
			update_target_selection()

func _on_hack_area_body_exited(body: Node) -> void:
	if body is HackableEntity and hack_targets.has(body):
		var exited_index = hack_targets.find(body)
		
		if hacked_entity == body:
			stop_hacking()
		
		body.deselect()
		hack_targets.erase(body)
		
		if hack_targets.is_empty():
			current_hack_index = -1
			hacking_line.hide()
		else:
			if current_hack_index >= exited_index:
				current_hack_index = max(0, current_hack_index - 1)
		
		update_target_selection()

func _on_animation_finished():
	if anim_sprite.animation == "aterrizaje":
		is_landing = false

func update_hacking_line_target():
	var target_entity: HackableEntity = null
	
	if is_hacking and is_instance_valid(hacked_entity):
		target_entity = hacked_entity
	elif not is_hacking and current_hack_index != -1 and is_instance_valid(hack_targets[current_hack_index]):
		target_entity = hack_targets[current_hack_index]
	
	if target_entity:
		update_hacking_line(target_entity)
	else:
		if hacking_line: hacking_line.hide()

func play_sfx_random(audio_player: AudioStreamPlayer2D, pitches: Array[float]):
	if pitches.is_empty():
		audio_player.play() # Tocar con pitch normal si no hay array
		return
	
	var random_pitch = pitches[randi() % pitches.size()]
	audio_player.pitch_scale = random_pitch
	audio_player.play() # 'play()' reinicia el sonido

func play_loop_sfx_random(audio_player: AudioStreamPlayer2D, pitches: Array[float]):
	if audio_player.is_playing():
		return # Si ya está sonando, no hacer nada

	if pitches.is_empty():
		audio_player.play()
		return

	var random_pitch = pitches[randi() % pitches.size()]
	audio_player.pitch_scale = random_pitch
	audio_player.play()
