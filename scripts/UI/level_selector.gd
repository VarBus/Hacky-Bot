extends Control
@onready var animation_player: AnimationPlayer = $AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_button_level_pressed():
	animation_player.play("select_level")

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "select_level":
		get_tree().change_scene_to_file("res://Scenes/UI/levels_selector.tscn")

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/UI/menu.tscn")
