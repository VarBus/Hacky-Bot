extends CharacterBody2D

const Movement2DScript = preload("res://Scripts/Clases/MovementCharacters.gd")
var mover := Movement2DScript.new()

# ============================================
# VARIABLES DE HACKING
# ============================================
@export var hack_distance_max: float = 300.0
var hack_targets: Array[HackableEntity] = []
var current_hack_index: int = -1
var hacked_entity: HackableEntity = null
var is_hacking: bool = false

# ============================================
# NODOS
# ============================================
@onready var hacking_line: Line2D = $HackingLine
@onready var anim_sprite: AnimatedSprite2D = $Sprite2D

# Sonidos
@onready var SfxWalk: AudioStreamPlayer2D = $Sfx2/SfxWalk
@onready var SfxJump: AudioStreamPlayer2D = $Sfx2/SfxJump
@onready var SfxHack: AudioStreamPlayer2D = $Sfx2/SfxHack
@onready var SfxIdle: AudioStreamPlayer2D = $SfxIdle
@onready var SfxDeath: AudioStreamPlayer2D = $Sfx2/SfxDeath

# ============================================
# CONFIGURACIÓN DE AUDIO
# ============================================
@export_group("Sound Pitches")
@export var pitch_variations_walk: Array[float] = [0.95, 1.0, 1.05]
@export var pitch_variations_jump: Array[float] = [0.9, 1.0, 1.1]
@export var pitch_variations_hack: Array[float] = [0.9, 1.0, 1.1]
@export var pitch_variations_idle: Array[float] = [1.0]

# ============================================
# WALL JUMP
# ============================================
@export_group("Wall Jump")
@export var wall_jump_speed: float = 300.0
@export var wall_push_speed: float = 100.0
@export var wall_slide_gravity: float = 200.0

# ============================================
# VARIABLES DE ESTADO
# ============================================
var is_landing: bool = false
var was_in_air: bool = false
var is_dead := false

# Control de SFX
var _jump_sfx_next_time: float = 0.0
const JUMP_SFX_COOLDOWN := 0.10

# ============================================
# INICIALIZACIÓN
# ============================================
func _ready() -> void:
	randomize()

	$HackDetectionArea.body_entered.connect(_on_hack_area_body_entered)
	$HackDetectionArea.body_exited.connect(_on_hack_area_body_exited)

	hacking_line.hide()
	hacking_line.add_point(Vector2.ZERO)
	hacking_line.add_point(Vector2.ZERO)

	anim_sprite.animation_finished.connect(_on_animation_finished)

	if SfxHack:
		SfxHack.finished.connect(_on_sfx_hack_finished)

# ============================================
# LOOP PRINCIPAL
# ============================================
func _physics_process(delta: float) -> void:
	# -------- HACKEO ACTIVO (CONTROL) --------
	if is_hacking and _is_controlling_entity():
		_handle_control_hack(delta)
		return

	# -------- MOVIMIENTO NORMAL --------
	_handle_normal_movement(delta)

	# -------- LÍNEA + INPUTS HACKEO --------
	update_hacking_line_target()
	handle_hacking_inputs()

# ============================================
# HACKEO MODO CONTROL
# ============================================
func _is_controlling_entity() -> bool:
	return is_instance_valid(hacked_entity) and hacked_entity.hack_type == HackableEntity.HackType.CONTROL

func _handle_control_hack(delta: float) -> void:
	# Soltar hackeo
	if Input.is_action_just_pressed("hack"):
		stop_hacking()
		was_in_air = false
		return

	# Animación
	if not is_on_floor():
		anim_sprite.play("jump")
	else:
		anim_sprite.play("hack")

	# Delegar control a la entidad
	if is_instance_valid(hacked_entity):
		hacked_entity._handle_hacked_input(delta)
	else:
		stop_hacking()
		return

	# Jugador permanece estático (gravedad aplicada)
	mover.begin_frame(is_on_floor(), delta)
	velocity = mover.step(velocity, 0.0, is_on_floor(), delta)
	was_in_air = not is_on_floor()

	move_and_slide()

	# Gestión de audio
	_stop_loop(SfxWalk)
	_stop_loop(SfxIdle)
	play_loop_sfx_random(SfxHack, pitch_variations_hack)

	update_hacking_line_target()

# ============================================
# MOVIMIENTO NORMAL
# ============================================
func _handle_normal_movement(delta: float) -> void:
	var is_on_floor_now := is_on_floor()
	var is_on_wall_now := is_on_wall() and not is_on_floor_now

	mover.begin_frame(is_on_floor_now, delta)
	var dir := Input.get_axis("ui_left", "ui_right")

	# Desliz por pared
	if is_on_wall_now and velocity.y > 0.0:
		velocity = mover.step(velocity, dir, is_on_floor_now, delta)
		velocity.y = min(velocity.y, wall_slide_gravity)
	else:
		if Input.is_action_just_pressed("ui_accept") and not is_on_wall_now:
			mover.buffer_jump()
		velocity = mover.step(velocity, dir, is_on_floor_now, delta)

	# Wall jump
	if is_on_wall_now and Input.is_action_just_pressed("ui_accept"):
		var wall_normal := get_wall_normal()
		velocity.y = -wall_jump_speed
		velocity.x = wall_normal.x * wall_push_speed
		_try_play_jump_sfx()

	# Salto de altura variable
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= 0.45

	# Animación + SFX
	_update_animation_and_audio(is_on_floor_now, is_on_wall_now, dir)

	was_in_air = not is_on_floor_now

	# Voltear sprite
	if is_on_wall_now:
		anim_sprite.flip_h = get_wall_normal().x > 0
	elif dir < 0:
		anim_sprite.flip_h = true
	elif dir > 0:
		anim_sprite.flip_h = false

	move_and_slide()

func _update_animation_and_audio(is_on_floor_now: bool, is_on_wall_now: bool, dir: float) -> void:
	if is_landing:
		return
	
	if not is_on_floor_now:
		anim_sprite.play("jump")
		_stop_loop(SfxWalk)
		_stop_loop(SfxIdle)
		if was_in_air == false:
			_try_play_jump_sfx()
	elif was_in_air and is_on_floor_now:
		is_landing = true
		anim_sprite.play("aterrizaje")
	elif dir != 0:
		anim_sprite.play("walk")
		_stop_loop(SfxIdle)
		play_loop_sfx_random(SfxWalk, pitch_variations_walk)
	else:
		anim_sprite.play("default")
		_stop_loop(SfxWalk)
		play_loop_sfx_random(SfxIdle, pitch_variations_idle)

# ============================================
# SISTEMA DE HACKEO
# ============================================
func handle_hacking_inputs() -> void:
	# Cambiar objetivo
	if Input.is_action_just_pressed("change_hack_target") and not hack_targets.is_empty():
		current_hack_index = (current_hack_index + 1) % hack_targets.size()
		update_target_selection()

	# Hackear
	if Input.is_action_just_pressed("hack") and current_hack_index != -1:
		start_hacking()

func update_target_selection() -> void:
	# Deseleccionar todos
	for i in range(hack_targets.size()):
		if is_instance_valid(hack_targets[i]):
			hack_targets[i].deselect()

	# Seleccionar actual
	if current_hack_index != -1 and is_instance_valid(hack_targets[current_hack_index]):
		hack_targets[current_hack_index].select()
		update_hacking_line(hack_targets[current_hack_index])
	else:
		hacking_line.hide()

func start_hacking() -> void:
	if hack_targets.is_empty() or current_hack_index == -1:
		return

	hacked_entity = hack_targets[current_hack_index]
	
	# Conectar señal
	hacked_entity.control_released.connect(stop_hacking, CONNECT_ONE_SHOT)
	
	# Hackear entidad
	hacked_entity.take_control(self)
	
	# Determinar si congelar jugador según tipo de hackeo
	match hacked_entity.hack_type:
		HackableEntity.HackType.CONTROL:
			# Jugador queda estático, toma control total
			is_hacking = true
			velocity = Vector2.ZERO
			play_loop_sfx_random(SfxHack, pitch_variations_hack)
			print("[Player] Modo CONTROL - Jugador congelado")
		
		HackableEntity.HackType.DISABLE:
			# Jugador sigue libre, entidad se desactiva sola
			is_hacking = false  # No entrar en modo hackeo
			play_sfx_random(SfxHack, pitch_variations_hack)  # Solo un sfx breve
			print("[Player] Modo DISABLE - Jugador libre")
			# La entidad se encarga de desactivarse sola

	update_hacking_line(hacked_entity)

func stop_hacking() -> void:
	if not is_hacking:
		return

	is_hacking = false
	_stop_loop(SfxHack)

	if is_instance_valid(hacked_entity):
		if hacked_entity.is_connected("control_released", stop_hacking):
			hacked_entity.control_released.disconnect(stop_hacking)
		if hacked_entity.is_hacked:
			hacked_entity.release_control()

	hacked_entity = null

	if current_hack_index != -1 and is_instance_valid(hack_targets[current_hack_index]):
		update_hacking_line(hack_targets[current_hack_index])
	else:
		hacking_line.hide()

# ============================================
# DETECCIÓN DE OBJETIVOS
# ============================================
func _on_hack_area_body_entered(body: Node) -> void:
	if body is HackableEntity and not hack_targets.has(body):
		hack_targets.append(body)
		if current_hack_index == -1:
			current_hack_index = 0
			update_target_selection()

func _on_hack_area_body_exited(body: Node) -> void:
	if body is HackableEntity and hack_targets.has(body):
		var exited_index := hack_targets.find(body)

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

# ============================================
# LÍNEA DE HACKEO
# ============================================
func update_hacking_line(target_entity: Node2D) -> void:
	if not hacking_line or not is_instance_valid(target_entity):
		hacking_line.hide()
		return

	var entity_global_pos := target_entity.global_position

	hacking_line.set_point_position(0, Vector2.ZERO)
	hacking_line.set_point_position(1, hacking_line.to_local(entity_global_pos))

	if not hacking_line.is_visible():
		hacking_line.show()

func update_hacking_line_target() -> void:
	var target_entity: HackableEntity = null
	
	if is_hacking and is_instance_valid(hacked_entity):
		target_entity = hacked_entity
	elif not is_hacking and current_hack_index != -1 and is_instance_valid(hack_targets[current_hack_index]):
		target_entity = hack_targets[current_hack_index]

	if target_entity:
		update_hacking_line(target_entity)
	else:
		if hacking_line:
			hacking_line.hide()

# ============================================
# AUDIO
# ============================================
func _try_play_jump_sfx() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now < _jump_sfx_next_time:
		return
	_jump_sfx_next_time = now + JUMP_SFX_COOLDOWN
	play_sfx_random(SfxJump, pitch_variations_jump)

func play_sfx_random(audio_player: AudioStreamPlayer2D, pitches: Array[float]) -> void:
	if audio_player == null or audio_player.stream == null:
		return
	
	var pitch := 1.0
	if not pitches.is_empty():
		pitch = float(pitches[randi_range(0, pitches.size() - 1)])
	
	audio_player.pitch_scale = pitch
	audio_player.stop()
	audio_player.play()

func play_loop_sfx_random(audio_player: AudioStreamPlayer2D, pitches: Array[float]) -> void:
	if audio_player == null or audio_player.stream == null:
		return
	
	if audio_player.playing:
		return
	
	var pitch := 1.0
	if not pitches.is_empty():
		pitch = float(pitches[randi_range(0, pitches.size() - 1)])
	
	audio_player.pitch_scale = pitch
	audio_player.play()

func _stop_loop(audio_player: AudioStreamPlayer2D) -> void:
	if audio_player != null and audio_player.playing:
		audio_player.stop()

func _on_sfx_hack_finished() -> void:
	if is_hacking and SfxHack != null and not SfxHack.playing:
		SfxHack.play()

# ============================================
# MUERTE
# ============================================
func _on_animation_finished() -> void:
	if anim_sprite.animation == "aterrizaje":
		is_landing = false

func die() -> void:
	if is_dead:
		return
	
	is_dead = true
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	
	if anim_sprite:
		anim_sprite.hide()
	
	if has_node("ExplosionParticles"):
		$ExplosionParticles.emitting = true
	
	# Detener sonidos
	_stop_loop(SfxWalk)
	_stop_loop(SfxIdle)
	_stop_loop(SfxHack)
	play_loop_sfx_random(SfxDeath, pitch_variations_idle)
