# HackableEntity.gd
extends CharacterBody2D
class_name HackableEntity

## Clase base para entidades que pueden ser hackeadas por el jugador.
## Soporta dos modos: control completo (jugador estático) o desactivación temporal (jugador libre).

## Nodo visual que cambia de color según el estado
@export var visual_node: CanvasItem

## Tipo de hackeo que usa esta entidad
@export_enum("Control:0", "Disable:1") var hack_type: int = 0

## Duración de la desactivación en segundos (solo para hack_type = Disable)
@export var disable_duration: float = 5.0

## Emitida cuando el jugador libera el control de esta entidad
signal control_released

## Emitida cuando se desactiva temporalmente (hack_type = Disable)
signal disabled(duration: float)

## Emitida cuando se reactiva después de estar desactivada
signal reactivated

## Referencia al nodo del jugador que controla esta entidad
var controller: Node = null

## Estado de hackeo actual
var is_hacked: bool = false

## Timer interno para desactivación temporal
var _disable_timer: Timer = null

# Colores para estados visuales
const COLOR_NORMAL := Color.WHITE
const COLOR_SELECTED := Color.CRIMSON
const COLOR_HACKED := Color.AQUA
const COLOR_DISABLED := Color.GRAY

# Tipos de hackeo
enum HackType {
	CONTROL = 0,  ## El jugador toma control (queda estático)
	DISABLE = 1   ## Solo desactiva la entidad (jugador sigue libre)
}

## ============================================================================
## INICIALIZACIÓN
## ============================================================================

func _ready() -> void:
	# Crear timer para desactivaciones temporales
	if hack_type == HackType.DISABLE:
		_disable_timer = Timer.new()
		_disable_timer.one_shot = true
		_disable_timer.timeout.connect(_on_disable_timer_timeout)
		add_child(_disable_timer)

## ============================================================================
## MÉTODOS PÚBLICOS - Interfaz para el jugador
## ============================================================================

## Resalta visualmente la entidad cuando el jugador la está apuntando
func select() -> void:
	if is_hacked:
		return
	
	if visual_node:
		visual_node.modulate = COLOR_SELECTED

## Quita el resaltado visual cuando el jugador deja de apuntar
func deselect() -> void:
	if is_hacked:
		return
	
	if visual_node:
		visual_node.modulate = COLOR_NORMAL

## Transfiere el control o desactiva la entidad según su tipo
func take_control(player_node: Node) -> void:
	if is_hacked:
		push_warning("[%s] Ya está siendo controlada/desactivada" % name)
		return
	
	if not player_node:
		push_error("[%s] player_node es null" % name)
		return
	
	controller = player_node
	is_hacked = true
	
	match hack_type:
		HackType.CONTROL:
			_apply_control_hack(player_node)
		HackType.DISABLE:
			_apply_disable_hack(player_node)

## Aplica hackeo de control (jugador toma control)
func _apply_control_hack(player_node: Node) -> void:
	if visual_node:
		visual_node.modulate = COLOR_HACKED
	
	print("[%s] Controlada por %s" % [name, player_node.name])
	_on_control_taken()

## Aplica hackeo de desactivación (solo apaga temporalmente)
func _apply_disable_hack(player_node: Node) -> void:
	if visual_node:
		visual_node.modulate = COLOR_DISABLED
	
	print("[%s] Desactivada por %.1fs" % [name, disable_duration])
	
	# Iniciar timer de reactivación
	if _disable_timer:
		_disable_timer.start(disable_duration)
	
	# Emitir señal para que la entidad se desactive
	disabled.emit(disable_duration)
	
	# Llamar hook virtual
	_on_disabled()
	
	# Liberar al jugador inmediatamente (no queda estático)
	_release_player_immediately()

## Libera al jugador sin afectar el estado de desactivación
func _release_player_immediately() -> void:
	# Solo limpiamos la referencia al controlador
	# pero mantenemos is_hacked = true hasta que expire el timer
	controller = null

## Devuelve el control de esta entidad y restaura su estado normal
func release_control() -> void:
	if not is_hacked:
		return
	
	# Para hack tipo DISABLE, esto se llama desde el timer
	if hack_type == HackType.DISABLE and _disable_timer and not _disable_timer.is_stopped():
		# Todavía está desactivada, no hacer nada
		return
	
	_cleanup_hack_state()

## Limpia el estado de hackeo
func _cleanup_hack_state() -> void:
	var previous_controller := controller
	controller = null
	is_hacked = false
	
	if visual_node:
		visual_node.modulate = COLOR_NORMAL
	
	print("[%s] Control liberado" % name)
	
	control_released.emit()
	_on_control_released()

## Callback cuando expira el timer de desactivación
func _on_disable_timer_timeout() -> void:
	print("[%s] Reactivada" % name)
	
	is_hacked = false
	
	if visual_node:
		visual_node.modulate = COLOR_NORMAL
	
	reactivated.emit()
	_on_reactivated()

## ============================================================================
## MÉTODOS VIRTUALES - Para sobrescribir en clases hijas
## ============================================================================

## Procesa el input del jugador cuando la entidad está hackeada (solo CONTROL)
func _handle_hacked_input(delta: float) -> void:
	pass

## Hook llamado cuando se toma control (solo CONTROL)
func _on_control_taken() -> void:
	pass

## Hook llamado cuando se desactiva temporalmente (solo DISABLE)
func _on_disabled() -> void:
	pass

## Hook llamado cuando se reactiva después de desactivación (solo DISABLE)
func _on_reactivated() -> void:
	pass

## Hook llamado cuando se libera el control
func _on_control_released() -> void:
	pass

## ============================================================================
## UTILIDADES
## ============================================================================

## Verifica si esta entidad está siendo controlada por un jugador específico
func is_controlled_by(player_node: Node) -> bool:
	return is_hacked and controller == player_node and hack_type == HackType.CONTROL

## Verifica si está desactivada temporalmente
func is_disabled() -> bool:
	return is_hacked and hack_type == HackType.DISABLE

## Obtiene el tiempo restante de desactivación
func get_remaining_disable_time() -> float:
	if is_disabled() and _disable_timer:
		return _disable_timer.time_left
	return 0.0

## Fuerza la liberación del control sin emitir señales
func force_release(silent: bool = false) -> void:
	if not is_hacked:
		return
	
	# Detener timer si existe
	if _disable_timer and not _disable_timer.is_stopped():
		_disable_timer.stop()
	
	controller = null
	is_hacked = false
	
	if visual_node:
		visual_node.modulate = COLOR_NORMAL
	
	if not silent:
		control_released.emit()
	
	_on_control_released()
