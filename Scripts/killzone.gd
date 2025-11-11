extends Area2D

@export var camera_to_shake: Camera2D  
@export var shake_strength: float = 1.0
@onready var timer: Timer = $Timer
var _is_shaking := false
var _original_camera_offset := Vector2.ZERO

func _ready() -> void:
	# Guarda la posición/offset inicial de la cámara fija
	if camera_to_shake:
		_original_camera_offset = camera_to_shake.offset

func _physics_process(delta: float) -> void:
	# Aplica la vibración si está activo
	if _is_shaking and camera_to_shake:
		var rand_offset = Vector2( \
			randf_range(-shake_strength, shake_strength), \
			randf_range(-shake_strength, shake_strength) \
		)
		# Mueve la cámara alrededor de su punto fijo original
		camera_to_shake.offset = _original_camera_offset + rand_offset

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("die"):
		
		body.die()
		_is_shaking = true
		Engine.time_scale = 0.5
		timer.start()

func _on_timer_timeout() -> void:
	_is_shaking = false
	if camera_to_shake:
		camera_to_shake.offset = _original_camera_offset
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
