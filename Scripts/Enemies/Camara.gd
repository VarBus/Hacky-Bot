extends HackableEntity

# ============================================
# CONFIGURACIÓN
# ============================================
## Duración del slow motion al detectar al jugador
@export var slow_motion_duration: float = 1.0
## Escala de tiempo durante el slow motion
@export var slow_motion_scale: float = 0.5

# ============================================
# NODOS
# ============================================
@onready var vision_area: Area2D = $Vision_Area2D
@onready var raycast: RayCast2D = $RayCast2D
@onready var vision_visual: Node2D = $Vision_Area2D/VisionConeVisual
@onready var sprite: Sprite2D = $Sprite2D
@onready var scanner: AudioStreamPlayer2D = $Scanner
@onready var death_timer: Timer = $Muerte

# ============================================
# VARIABLES
# ============================================
var player_detected: Node2D = null
var _is_active: bool = true

# ============================================
# CICLO DE VIDA
# ============================================
func _ready() -> void:
	# Configurar tipo de hackeo
	hack_type = HackType.DISABLE
	disable_duration = 5.0  # Desactivada por 5 segundos
	
	super._ready()
	
	_setup_visual_node()
	_connect_signals()

func _setup_visual_node() -> void:
	if visual_node == null:
		visual_node = sprite

func _connect_signals() -> void:
	vision_area.body_entered.connect(_on_vision_area_body_entered)
	vision_area.body_exited.connect(_on_vision_area_body_exited)
	death_timer.timeout.connect(_on_death_timeout)

# ============================================
# HOOKS DE HACKEO (heredados de HackableEntity)
# ============================================
func _on_disabled() -> void:
	print("[Cámara] Desactivando sistemas...")
	_deactivate_camera()

func _on_reactivated() -> void:
	print("[Cámara] Reactivando sistemas...")
	_activate_camera()

# ============================================
# ACTIVACIÓN/DESACTIVACIÓN
# ============================================
func _activate_camera() -> void:
	_is_active = true
	_set_detection_enabled(true)
	_set_appearance(COLOR_NORMAL)

func _deactivate_camera() -> void:
	_is_active = false
	_set_detection_enabled(false)
	_set_appearance(COLOR_DISABLED)
	_stop_scanner_sound()
	player_detected = null

func _set_detection_enabled(enabled: bool) -> void:
	vision_area.monitoring = enabled
	raycast.enabled = enabled
	
	if vision_visual:
		vision_visual.visible = enabled

func _set_appearance(color: Color) -> void:
	if sprite:
		sprite.modulate = color

# ============================================
# DETECCIÓN DEL JUGADOR
# ============================================
func _on_vision_area_body_entered(body: Node2D) -> void:
	if not _is_active or not body.is_in_group("player"):
		return
	
	if _has_line_of_sight_to(body):
		_detect_player(body)

func _has_line_of_sight_to(target: Node2D) -> bool:
	raycast.target_position = target.global_position - global_position
	raycast.force_raycast_update()
	
	return not raycast.is_colliding() or raycast.get_collider() == target

func _detect_player(body: Node2D) -> void:
	if player_detected == body:
		return  # Ya detectado
	
	player_detected = body
	
	print("[Cámara] ¡Jugador detectado!")
	
	# Efectos de detección
	_play_scanner_sound()
	_trigger_death_sequence(body)

func _trigger_death_sequence(body: Node2D) -> void:
	# Slow motion
	Engine.time_scale = slow_motion_scale
	death_timer.start(slow_motion_duration)
	
	# Matar al jugador
	if body.has_method("die"):
		body.die()

func _on_vision_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and player_detected == body:
		player_detected = null
		_stop_scanner_sound()

# ============================================
# AUDIO
# ============================================
func _play_scanner_sound() -> void:
	if not scanner or scanner.playing:
		return
	
	scanner.play()

func _stop_scanner_sound() -> void:
	if scanner and scanner.playing:
		scanner.stop()

# ============================================
# TIMERS
# ============================================
func _on_death_timeout() -> void:
	Engine.time_scale = 1.0
	print("[Cámara] Reiniciando nivel...")
	_reload_level()

# ============================================
# UTILIDADES
# ============================================
func _reload_level() -> void:
	get_tree().reload_current_scene()

## Debug info
func _to_string() -> String:
	return "[Camera] Active: %s | Hacked: %s | Player detected: %s" % [
		_is_active,
		is_hacked,
		player_detected != null
	]
