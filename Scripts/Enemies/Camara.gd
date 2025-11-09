# CamaraSeguridad.gd
# ¡YA NO ES Node2D, ahora es una HackableEntity!
extends HackableEntity

# --- Referencias a Nodos ---
# (Asegúrate de que los nombres coincidan con tu escena)
@onready var vision_area: Area2D = $Vision_Area2D
@onready var raycast: RayCast2D = $RayCast2D
@onready var vision_visual = $Vision_Area2D/VisionConeVisual # Opcional, si lo tienes

func _ready():
	# Solo conectamos el área de visión (la de Game Over)
	vision_area.body_entered.connect(_on_vision_area_body_entered)
	
	# Asignamos el nodo visual por código si no se hizo en el editor
	if visual_node == null:
		visual_node = $Sprite2D

# --- LÓGICA 1: DETECCIÓN (GAME OVER) ---
# Esto se mantiene igual.
func _on_vision_area_body_entered(body: Node2D) -> void:
	# Si la cámara está 'is_hacked', está desactivada
	if is_hacked:
		return

	# Si es el jugador, comprobar RayCast y reiniciar
	if body.is_in_group("player"):
		raycast.target_position = body.global_position - global_position
		raycast.force_raycast_update()
		
		if not raycast.is_colliding() or raycast.get_collider() == body:
			print("¡JUGADOR DETECTADO! Reiniciando nivel...")
			get_tree().reload_current_scene()
		else:
			pass # Falsa alarma (detrás de pared)

# --- LÓGICA 2: HACKEO (¡LA PARTE NUEVA!) ---
# Sobrescribimos la función de la clase base HackableEntity
func take_control(player_node) -> void:
	# 1. Llama a la función base para poner is_hacked = true
	super.take_control(player_node) 
	
	# 2. Llama a la función de desactivación
	disable_camera()

# --- FUNCIÓN DE DESACTIVACIÓN ---
# Esta función apaga la cámara permanentemente
func disable_camera():
	print("¡Cámara hackeada y desactivada!")
	
	# Apagamos el cono de visión (ya no detecta)
	vision_area.monitoring = false 
	raycast.enabled = false
	
	# Ocultamos el cono visual
	if vision_visual:
		vision_visual.visible = false
	
	# Cambiamos el color de la cámara (además del 'select')
	if has_node("Sprite2D"):
		$Sprite2D.modulate = Color.GRAY
		
	# Nos aseguramos de quitar el resaltado rojo
	deselect()

# --- NOTA IMPORTANTE ---
# Ya no necesitamos _process(), _on_interaction_body_entered(), 
# ni _on_interaction_body_exited() porque la detección y
# la llamada a take_control() la hace el JUGADOR.
