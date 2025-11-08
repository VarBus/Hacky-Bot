extends Control
@onready var background_pt_1: ColorRect = $BackgroundPt1
@onready var background_pt_2: ColorRect = $BackgroundPt2
@onready var buttons_container: VBoxContainer = $VBoxContainer



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var tween1 = get_tree().create_tween()
	var tween2 = get_tree().create_tween()
	tween1.tween_property(background_pt_1, "position", Vector2(0,0), 0.5)
	tween2.tween_property(background_pt_2, "position", Vector2(160,0), 0.5)
	await tween1.finished
	await tween2.finished
	buttons_container.visible = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_exit_button_pressed():
	get_tree().change_scene_to_file("res://scenes/UI/menu.tscn")
