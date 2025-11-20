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
@onready var vision_polygon: CollisionPolygon2D = $Vision_Area2D/CollisionPolygon2D 

# ============================================
# CONFIGURACIÓN DE FORMAS
# ============================================
@export var vision_shape: String = "CONE_NORMAL"

var SHAPES: Dictionary = {}

# ============================================
# ÁNGULOSs
# =============================================
@export_group("Angulo de la camara")
## Ángulo inicial del cono de visión (en grados)
@export var initial_angle: float = 0.0
## Rango de rotación (0 para estático, 90 para un barrido de 90 grados)
@export var rotation_range: float = 0.0
## Velocidad de rotación (grados por segundo)
@export var rotation_speed: float = 30.0

# ============================================
# VARIABLES
# ============================================
var player_detected: Node2D = null
var _is_active: bool = true

# ============================================
# CICLO DE VIDA
# ============================================
func _ready() -> void:
	#Inicializar el diccionario SHAPES aquí
	_initialize_shapes()
	
	# Configurar tipo de hackeo
	hack_type = HackType.DISABLE
	disable_duration = 5.0  # Desactivada por 5 segundos
	
	super._ready()
	
	_setup_visual_node()
	_connect_signals()
	
	# NUEVO: Establece la forma de visión al inicio
	_set_vision_shape(vision_shape)
	
	if vision_area:
		# Convertir el ángulo inicial de grados a radianes
		vision_area.rotation = deg_to_rad(initial_angle)


func _process(delta: float) -> void:
	if _is_active and not is_hacked and rotation_range > 0.0:
		_rotate_vision_cone(delta)

# Nueva función para la rotación del cono
func _rotate_vision_cone(delta: float) -> void:
	# Define los límites del movimiento de barrido
	var min_angle = deg_to_rad(initial_angle - rotation_range / 2.0)
	var max_angle = deg_to_rad(initial_angle + rotation_range / 2.0)
	
	# Usamos un seno para el movimiento suave de lado a lado (ping-pong)
	var time = Time.get_ticks_msec() / 1000.0 * rotation_speed
	var current_angle = min_angle + (max_angle - min_angle) * (sin(time) * 0.5 + 0.5)
	
	vision_area.rotation = current_angle
	
	# Asegurarse de que el RayCast2D esté rotado con el cono
	# (El RayCast2D es hijo de la cámara, por lo que su 'target_position' es relativo a la cámara.
	# Necesitamos ajustarlo si no es hijo de vision_area).
	# Si RayCast2D NO es hijo de Vision_Area2D:
	raycast.rotation = current_angle
	# Si RayCast2D SÍ es hijo de Vision_Area2D:
	# No necesitas esta línea ya que se mueve automáticamente.


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

# EhRobotCamara.gd

# ============================================
# UTILIDADES
# ============================================

func _set_vision_shape(shape_name: String) -> void:
	if vision_polygon == null:
		push_warning("CollisionPolygon2D 'vision_polygon' no encontrado.")
		return
		
	if SHAPES.has(shape_name):
		# Aplica los nuevos puntos de colisión
		vision_polygon.polygon = SHAPES[shape_name]
		
		# Opcional: Actualizar el visual del cono (VisionConeVisual)
		# Si VisionConeVisual es un Polygon2D, puedes sincronizar su forma:
		if vision_visual is Polygon2D:
			(vision_visual as Polygon2D).polygon = SHAPES[shape_name]
			
		print("[Cámara] Forma de visión cambiada a: ", shape_name)
	else:
		push_error("Forma de visión '%s' no definida." % shape_name)
		
# NUEVA FUNCIÓN: Para definir el diccionario de formas
func _initialize_shapes() -> void:
	SHAPES = {
		"CONE_NORMAL": PackedVector2Array([
			Vector2(-89.19, 24.97),
			Vector2(54.81, 131.97),
			Vector2(-72.19, 131.97),
			Vector2(-121.19, 11.97),
			Vector2(-122.19, -0.03)
		]),
		"LONG_RECTANGLE": PackedVector2Array([
			Vector2(0, -50),
			Vector2(800, -50),
			Vector2(800, 50),
			Vector2(0, 50)
		]),
		"WIDE_SHORT": PackedVector2Array([
			Vector2(0, 0),
			Vector2(200, -200),
			Vector2(200, 200)
		])
	}
