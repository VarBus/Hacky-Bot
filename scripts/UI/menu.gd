extends Control
@onready var press: AudioStreamPlayer2D = $Press
@export var wait_seconds: float = 0.5
var finish := true
var _busy := false

func _ready() -> void:
	var music = preload("res://Assets/Sounds/starstream-circuit-370586.ogg")
	MusicManager.music_player.stream = music
	MusicManager.music_player.play()

func _on_play_button_pressed() -> void:
	if _busy: return
	_busy = true
	if finish:
		press.stop()
		press.play()
		press.seek(1)
		
	await get_tree().create_timer(wait_seconds).timeout
	get_tree().change_scene_to_file("res://Scenes/UI/level_selector.tscn")
	_busy = false

func _on_exit_button_pressed() -> void:
	if _busy: return
	_busy = true
	if finish:
		press.stop()
		press.play()
		press.seek(1)
	await get_tree().create_timer(wait_seconds).timeout
	get_tree().quit()
