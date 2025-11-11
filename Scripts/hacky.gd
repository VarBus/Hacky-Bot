extends CharacterBody2D

const Movement2DScript = preload("res://Scripts/Clases/MovementCharacters.gd")
var mover := Movement2DScript.new()

# --- Variables de Hacking ---
@export var hack_distance_max: float = 300.0
var hack_targets: Array[HackableEntity] = []
var current_hack_index: int = -1
var hacked_entity: HackableEntity = null
var is_hacking: bool = false

@onready var hacking_line: Line2D = $HackingLine
@onready var anim_sprite: AnimatedSprite2D = $Sprite2D
var is_landing: bool = false
var was_in_air: bool = false

# --- Sonidos (nodos en la escena) ---
@onready var SfxWalk: AudioStreamPlayer2D = $SfxWalk
@onready var SfxJump: AudioStreamPlayer2D = $SfxJump
@onready var SfxHack: AudioStreamPlayer2D = $SfxHack
@onready var SfxIdle: AudioStreamPlayer2D = $SfxIdle

@export_group("Sound Pitches")
@export var pitch_variations_walk: Array[float] = [0.95, 1.0, 1.05]
@export var pitch_variations_jump: Array[float] = [0.9, 1.0, 1.1]
@export var pitch_variations_hack: Array[float] = [0.9, 1.0, 1.1]
@export var pitch_variations_idle: Array[float] = [1.0]

# --- Wall Jump ---
@export_group("Wall Jump")
@export var wall_jump_speed: float = 400.0
@export var wall_push_speed: float = 400.0
@export var wall_slide_gravity: float = 200.0

# --- Control de SFX ---
var _jump_sfx_next_time: float = 0.0       # antirebote de salto (s)
const JUMP_SFX_COOLDOWN := 0.10            # 100 ms

func _ready() -> void:
	randomize()

	$HackDetectionArea.body_entered.connect(_on_hack_area_body_entered)
	$HackDetectionArea.body_exited.connect(_on_hack_area_body_exited)

	hacking_line.hide()
	hacking_line.add_point(Vector2.ZERO)
	hacking_line.add_point(Vector2.ZERO)

	anim_sprite.animation_finished.connect(_on_animation_finished)

	# Si el audio de hack NO está en loop, nos aseguramos de relanzarlo mientras dure el hack.
	if SfxHack:
		SfxHack.finished.connect(_on_sfx_hack_finished)

func _physics_process(delta: float) -> void:
	# -------- 1) HACKEO ACTIVO --------
	if is_hacking:
		if Input.is_action_just_pressed("hack"):
			stop_hacking()
			was_in_air = false
			return

		if not is_on_floor():
			anim_sprite.play("jump")
		else:
			anim_sprite.play("hack")

		if is_instance_valid(hacked_entity):
			hacked_entity._handle_hacked_input(delta)
		else:
			stop_hacking()

		mover.begin_frame(is_on_floor(), delta)
		velocity = mover.step(velocity, 0.0, is_on_floor(), delta)
		was_in_air = not is_on_floor()

		move_and_slide()

		# En hack no deben sonar los loops de caminar/idle
		_stop_loop(SfxWalk)
		_stop_loop(SfxIdle)

		# Asegura que el ambiente/zumbido de hack esté encendido mientras dure
		play_loop_sfx_random(SfxHack, pitch_variations_hack)

		update_hacking_line_target()
		return

	# -------- 2) MOVIMIENTO NORMAL --------
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

	# Wall jump (empuje + sonido con antirebote)
	if is_on_wall_now and Input.is_action_just_pressed("ui_accept"):
		var wall_normal := get_wall_normal()
		velocity.y = -wall_jump_speed
		velocity.x = wall_normal.x * wall_push_speed
		_try_play_jump_sfx()

	# Salto de altura variable
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= 0.45

	# -------- ANIMACIÓN + SFX --------
	if is_landing:
		pass
	elif not is_on_floor_now:
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

	was_in_air = not is_on_floor_now

	# Voltear sprite
	if is_on_wall_now:
		anim_sprite.flip_h = get_wall_normal().x > 0
	elif dir < 0:
		anim_sprite.flip_h = true
	elif dir > 0:
		anim_sprite.flip_h = false

	move_and_slide()

	# -------- 3) LÍNEA + INPUTS HACKEO --------
	update_hacking_line_target()
	handle_hacking_inputs()

# ---------- HACKEO ----------
func update_hacking_line(target_entity: Node2D) -> void:
	if not hacking_line or not is_instance_valid(target_entity):
		hacking_line.hide()
		return

	var player_global_pos := global_position
	var entity_global_pos := target_entity.global_position

	hacking_line.set_point_position(0, to_local(player_global_pos))
	hacking_line.set_point_position(1, to_local(entity_global_pos))

	if not hacking_line.is_visible():
		hacking_line.show()

func handle_hacking_inputs():
	if Input.is_action_just_pressed("change_hack_target") and not hack_targets.is_empty():
		current_hack_index = (current_hack_index + 1) % hack_targets.size()
		update_target_selection()

	if Input.is_action_just_pressed("hack") and current_hack_index != -1:
		start_hacking()

func update_target_selection():
	for i in range(hack_targets.size()):
		if is_instance_valid(hack_targets[i]):
			hack_targets[i].deselect()

	if current_hack_index != -1 and is_instance_valid(hack_targets[current_hack_index]):
		hack_targets[current_hack_index].select()
		update_hacking_line(hack_targets[current_hack_index])
	else:
		hacking_line.hide()

func start_hacking():
	if hack_targets.is_empty() or current_hack_index == -1:
		return

	hacked_entity = hack_targets[current_hack_index]
	hacked_entity.control_released.connect(stop_hacking, CONNECT_ONE_SHOT)
	hacked_entity.take_control(self)
	is_hacking = true
	velocity = Vector2.ZERO

	# Arranca el ambiente de hack (si ya estaba, no reinicia)
	play_loop_sfx_random(SfxHack, pitch_variations_hack)

	update_hacking_line(hacked_entity)

func stop_hacking():
	if not is_hacking:
		return

	is_hacking = false
	# Cortar el sonido de hack inmediatamente
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
		if hacking_line:
			hacking_line.hide()

# ---------- HELPERS DE AUDIO ----------
func _try_play_jump_sfx() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now < _jump_sfx_next_time:
		return
	_jump_sfx_next_time = now + JUMP_SFX_COOLDOWN
	play_sfx_random(SfxJump, pitch_variations_jump)

func play_sfx_random(audio_player: AudioStreamPlayer2D, pitches: Array[float]) -> void:
	if audio_player == null: return
	if audio_player.stream == null:
		push_warning("AudioStreamPlayer2D sin 'stream' asignado: " + str(audio_player.name))
		return
	var pitch := 1.0
	if not pitches.is_empty():
		pitch = float(pitches[randi_range(0, pitches.size() - 1)])
	audio_player.pitch_scale = pitch
	audio_player.stop()  # reinicia el one-shot
	audio_player.play()

func play_loop_sfx_random(audio_player: AudioStreamPlayer2D, pitches: Array[float]) -> void:
	if audio_player == null: return
	if audio_player.stream == null:
		push_warning("AudioStreamPlayer2D (loop) sin 'stream' asignado: " + str(audio_player.name))
		return
	if audio_player.playing:
		return  # ya está sonando
	var pitch := 1.0
	if not pitches.is_empty():
		pitch = float(pitches[randi_range(0, pitches.size() - 1)])
	audio_player.pitch_scale = pitch
	audio_player.play()

func _stop_loop(audio_player: AudioStreamPlayer2D) -> void:
	if audio_player != null and audio_player.playing:
		audio_player.stop()

# Si tu clip de hack NO está en loop, esta función lo relanza mientras esté activo.
func _on_sfx_hack_finished() -> void:
	if is_hacking and SfxHack != null and not SfxHack.playing:
		SfxHack.play()
