extends AnimatableBody2D # <-- ¡IMPORTANTE!

@export var speed: float = 150.0
@export var top_offset_y: float = -160.0 # Cuánto sube (negativo es arriba)

# Estado interno
var _start_y: float
var _top_y: float
var _magnet_active: bool = false

func _ready() -> void:
	# 1. Asegurarse de que el Imán pueda encontrarla
	add_to_group("platform")
	
	# 2. Guardar posiciones
	_start_y = global_position.y
	_top_y = _start_y + top_offset_y

func _physics_process(delta: float) -> void:
	var target_y = _start_y
	
	# 1. Decidir a dónde ir (ARRIBA o ABAJO)
	if _magnet_active:
		target_y = _top_y
	else:
		target_y = _start_y

	# --- Lógica de movimiento para AnimatableBody2D ---
	# Ya no usamos velocity, movemos la posición directamente.
	var target_pos = Vector2(global_position.x, target_y)
	
	# Movernos hacia el objetivo a una velocidad constante
	global_position = global_position.move_toward(target_pos, speed * delta)
	# ------------------------------------------------

# --- Esta es la única función que le importa al Imán ---
func _on_magnet_platform_auto(active: bool, source: Node) -> void:
	_magnet_active = active
