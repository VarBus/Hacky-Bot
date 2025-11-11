extends HackableEntity

@onready var vision_area: Area2D = $Vision_Area2D
@onready var raycast: RayCast2D = $RayCast2D
@onready var vision_visual = $Vision_Area2D/VisionConeVisual
@onready var scanner: AudioStreamPlayer2D = $Scanner   # tu nodo de sonido
@onready var timer: Timer = $Cooldown

func _ready():
	if visual_node == null:
		visual_node = $Sprite2D

func take_control(player_node) -> void:
	super.take_control(player_node)
	timer.start()
	disable_camera()

func disable_camera():
	print("¡Cámara hackeada y desactivada!")
	vision_area.monitoring = false
	raycast.enabled = false
	if vision_visual:
		vision_visual.visible = false
	if has_node("Sprite2D"):
		$Sprite2D.modulate = Color.GRAY
	# cortar cualquier sonido activo
	if scanner and scanner.playing:
		scanner.stop()
	deselect()

func _on_vision_area_2d_body_entered(body: Node2D) -> void:
	if is_hacked:
		return
	if body.is_in_group("player"):
		# reproducir simple: reinicia por si ya estaba sonando
		if scanner:
			scanner.stop()
			scanner.play()

		raycast.target_position = body.global_position - global_position
		raycast.force_raycast_update()

		if not raycast.is_colliding() or raycast.get_collider() == body:
			print("¡JUGADOR DETECTADO! Reiniciando nivel...")
			get_tree().reload_current_scene()

func _on_vision_area_2d_body_exited(body: Node2D) -> void:
	# al salir el player, corta el sonido
	if body.is_in_group("player") and scanner and scanner.playing:
		scanner.stop()


func _on_cooldown_timeout() -> void:
	vision_area.monitoring = true
	raycast.enabled = true
	if vision_visual:
		vision_visual.visible = true
