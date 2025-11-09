extends Control
@onready var animation_player: AnimationPlayer = $AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("new_animation")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_exit_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/UI/menu.tscn")
