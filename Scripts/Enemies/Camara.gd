extends HackableEntity

# ============================================
# NODOS
# ============================================
@onready var vision_area: Area2D = $Vision_Area2D
@onready var raycast: RayCast2D = $RayCast2D
@onready var vision_visual: Node2D = $Vision_Area2D/VisionConeVisual
@onready var sprite: Sprite2D = $Sprite2D
@onready var scanner: AudioStreamPlayer2D = $Scanner
@onready var cooldown_timer: Timer = $Cooldown
@onready var death_timer: Timer = $Muerte

# ============================================
# CONSTANTES
# ============================================
const HACKED_COLOR := Color.GRAY
const SLOW_MOTION_SCALE := 0.5
const NORMAL_TIME_SCALE := 1.0

# ============================================
# VARIABLES
# ============================================
var player_detected: Node2D = null

# ============================================
# CICLO DE VIDA
# ============================================
func _ready() -> void:
	_setup_visual_node()
	_connect_signals()

func _setup_visual_node() -> void:
	if visual_node == null:
		visual_node = sprite

func _connect_signals() -> void:
	vision_area.body_entered.connect(_on_vision_area_body_entered)
	vision_area.body_exited.connect(_on_vision_area_body_exited)
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	death_timer.timeout.connect(_on_death_timeout)

# ============================================
# HACKEO
# ============================================
func take_control(player_node: Node) -> void:
	super.take_control(player_node)
	_disable_camera()
	cooldown_timer.start()

func _disable_camera() -> void:
	print("¡Cámara hackeada y desactivada!")
	
	# Desactivar detección
	_set_detection_enabled(false)
	
	# Cambiar apariencia
	_set_hacked_appearance()
	
	# Detener sonido
	_stop_scanner_sound()
	
	# Deseleccionar
	deselect()

func _set_detection_enabled(enabled: bool) -> void:
	vision_area.monitoring = enabled
	raycast.enabled = enabled
	
	if vision_visual:
		vision_visual.visible = enabled

func _set_hacked_appearance() -> void:
	if sprite:
		sprite.modulate = HACKED_COLOR

# ============================================
# DETECCIÓN DEL JUGADOR
# ============================================
func _on_vision_area_body_entered(body: Node2D) -> void:
	if is_hacked or not body.is_in_group("player"):
		return
	
	if _has_line_of_sight_to(body):
		_detect_player(body)

func _has_line_of_sight_to(target: Node2D) -> bool:
	raycast.target_position = target.global_position - global_position
	raycast.force_raycast_update()
	
	var can_see := not raycast.is_colliding() or raycast.get_collider() == target
	return can_see

func _detect_player(body: Node2D) -> void:
	player_detected = body
	
	# Reproducir sonido de alerta
	_play_scanner_sound()
	
	# Iniciar secuencia de muerte
	_trigger_death_sequence(body)

func _trigger_death_sequence(body: Node2D) -> void:
	Engine.time_scale = SLOW_MOTION_SCALE
	death_timer.start()
	
	if body.has_method("die"):
		body.die()

func _on_vision_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_detected = null
		_stop_scanner_sound()

# ============================================
# AUDIO
# ============================================
func _play_scanner_sound() -> void:
	if not scanner:
		return
	
	scanner.stop()
	scanner.play()

func _stop_scanner_sound() -> void:
	if scanner and scanner.playing:
		scanner.stop()

# ============================================
# TIMERS
# ============================================
func _on_death_timeout() -> void:
	Engine.time_scale = NORMAL_TIME_SCALE
	print("¡JUGADOR DETECTADO! Reiniciando nivel...")
	_reload_level()

func _on_cooldown_timeout() -> void:
	print("Cámara reactivada")
	_set_detection_enabled(true)
	
	if sprite:
		sprite.modulate = Color.WHITE

# ============================================
# UTILIDADES
# ============================================
func _reload_level() -> void:
	get_tree().reload_current_scene()
