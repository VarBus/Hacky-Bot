extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/UI/level_selector.tscn")


func _on_level_selector_1_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Niveles/Niveles GameJam/Nivel1.tscn")


func _on_level_selector_2_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Niveles/Niveles GameJam/Nivel2.tscn")


func _on_level_selector_3_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Niveles/Niveles GameJam/Nivel3.tscn")
