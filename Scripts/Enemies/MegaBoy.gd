extends CharacterBody2D
const Movement2DScript = preload("res://Scripts/Clases/MovementCharacters.gd")
var mover := Movement2DScript.new()
var active := false
var direction := -1 

func _ready() -> void:
	$Cooldown.start()

func _physics_process(delta: float) -> void:
	if not active:
		velocity = Vector2.ZERO
		return
	mover.begin_frame(is_on_floor(), delta)
	velocity = mover.step(velocity, direction, is_on_floor(), delta)
	move_and_slide()
	if is_on_wall():
		direction *= -1
		if has_node("Sprite2D"):
			$Sprite2D.flip_h = direction > 0

func activate() -> void:
	if not active:
		active = true
		print("Enemigo activado")
		$Sprite2D.modulate = Color(1, 0.4, 0.4) 

func _on_cooldown_timeout() -> void:
	activate()
	active = false
	$Sprite2D.modulate = Color(1.0, 1.0, 1.0, 1.0)
