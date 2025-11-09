extends CharacterBody2D

const Movement2DScript = preload("res://Scripts/Clases/MovementCharacters.gd")
var mover := Movement2DScript.new()

func _physics_process(delta: float) -> void:
	mover.begin_frame(is_on_floor(), delta)
	var dir := Input.get_axis("ui_left", "ui_right")
	if Input.is_action_just_pressed("ui_accept"):
		mover.buffer_jump()
	velocity = mover.step(velocity, dir, is_on_floor(), delta)
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= 0.45
	move_and_slide()
