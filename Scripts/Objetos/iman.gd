extends HackableEntity

# ============================================
# CONFIGURACIÓN
# ============================================
## Grupo de las plataformas que serán afectadas
@export var target_group: StringName = &"platform"

# ============================================
# SEÑALES
# ============================================
## Emitida para activar/desactivar plataformas conectadas
signal platform_auto(active: bool, source: Node)

# ============================================
# NODOS
# ============================================
@onready var gravity_area_player: Area2D = get_node_or_null("GravityAreaPlayer")

# ============================================
# VARIABLES
# ============================================
var _inside_platforms: Array[Node] = []
var _is_active: bool = false

# ============================================
# CICLO DE VIDA
# ============================================
func _ready() -> void:
	# Configurar tipo de hackeo
	hack_type = HackType.DISABLE
	disable_duration = 1.0  # Activado por 2 segundos
	
	super._ready()
	
	if gravity_area_player:
		gravity_area_player.body_entered.connect(_on_gravity_area_player_body_entered)
		gravity_area_player.body_exited.connect(_on_gravity_area_player_body_exited)
	else:
		push_error("[Imán] No se encontró el nodo GravityAreaPlayer")

# ============================================
# HOOKS DE HACKEO
# ============================================
func _on_disabled() -> void:
	# Cuando se "desactiva" (hackea), en realidad se ACTIVA el imán
	print("[Imán] Activando campo magnético...")
	_activate_magnet()

func _on_reactivated() -> void:
	# Cuando se reactiva, apagar el imán
	print("[Imán] Desactivando campo magnético...")
	_deactivate_magnet()

# ============================================
# CONTROL DEL IMÁN
# ============================================
func _activate_magnet() -> void:
	_is_active = true
	_emit_platform_signal(true)

func _deactivate_magnet() -> void:
	_is_active = false
	_emit_platform_signal(false)

func _emit_platform_signal(active: bool) -> void:
	if _inside_platforms.size() > 0:
		print("[Imán] Enviando señal platform_auto=%s a %d plataformas" % [active, _inside_platforms.size()])
		platform_auto.emit(active, self)
	else:
		print("[Imán] No hay plataformas en rango")

# ============================================
# DETECCIÓN DE PLATAFORMAS
# ============================================
func _on_gravity_area_player_body_entered(body: Node2D) -> void:
	if not body.is_in_group(target_group):
		return
	
	print("[Imán] Plataforma detectada: ", body.name)
	
	# Agregar a lista
	if not _inside_platforms.has(body):
		_inside_platforms.append(body)
	
	# Conectar señal si tiene el método
	if body.has_method("_on_magnet_platform_auto"):
		var cb := Callable(body, "_on_magnet_platform_auto")
		if not is_connected("platform_auto", cb):
			var err := platform_auto.connect(cb)
			if err == OK:
				print("[Imán] ✓ Conectado a: ", body.name)
			else:
				push_warning("[Imán] ✗ Error al conectar con %s (código: %d)" % [body.name, err])
		
		# Enviar estado actual
		body.call("_on_magnet_platform_auto", _is_active, self)
	else:
		push_warning("[Imán] La plataforma '%s' no tiene _on_magnet_platform_auto()" % body.name)

func _on_gravity_area_player_body_exited(body: Node2D) -> void:
	if not body.is_in_group(target_group):
		return
	
	print("[Imán] Plataforma salió: ", body.name)
	
	# Remover de lista
	if _inside_platforms.has(body):
		_inside_platforms.erase(body)
	
	# Desconectar señal
	var cb := Callable(body, "_on_magnet_platform_auto")
	if is_connected("platform_auto", cb):
		platform_auto.disconnect(cb)
	
	# Apagar plataforma al salir
	if body.has_method("_on_magnet_platform_auto"):
		body.call("_on_magnet_platform_auto", false, self)

# ============================================
# UTILIDADES
# ============================================
## Debug info
func _to_string() -> String:
	return "[Imán] Active: %s | Hacked: %s | Platforms: %d | Time left: %.1fs" % [
		_is_active,
		is_hacked,
		_inside_platforms.size(),
		get_remaining_disable_time()
	]
