extends Control
@onready var background_pt_1: ColorRect = $BackgroundPt1
@onready var background_pt_2: ColorRect = $BackgroundPt2
@onready var buttons_container: VBoxContainer = $VBoxContainer
@onready var effect_sound: AudioStreamPlayer2D = $EffectSound



# Called when the node enters the scene tree for the first time.
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	effect_sound.play(1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 1. Creación del Tween en Godot 4
	var tween1 = create_tween()
	var tween2 = create_tween()

	# 2. Esta es la sintaxis CORRECTA para Godot 4
	# Le dice al tween que ignore la pausa del juego
	#tween1.set_pause_mode(Tween.TWEEN_PAUSE_MODE_PROCESS)
	#tween2.set_pause_mode(Tween.TWEEN_PAUSE_MODE_PROCESS)

	# 3. Tus animaciones
	tween1.tween_property(background_pt_1, "position", Vector2(0,0), 0.5)
	tween2.tween_property(background_pt_2, "position", Vector2(160,0), 0.5)
	
	# 4. Los awaits
	await tween1.finished
	await tween2.finished
	
	buttons_container.visible = true
	
	buttons_container.visible = true
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_retry_button_pressed():
	PauseManager.retry_scene()

func _on_continue_button_pressed():
	PauseManager.resume_game()

func _on_exit_button_pressed():
	PauseManager.resume_game()
	get_tree().change_scene_to_file("res://scenes/UI/menu.tscn")
