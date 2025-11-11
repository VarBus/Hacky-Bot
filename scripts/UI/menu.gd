extends Control

@export var wait_seconds: float = 1.1
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
		$Press.stop()
		$Press.play()
	await get_tree().create_timer(wait_seconds).timeout
	get_tree().change_scene_to_file("res://Scenes/UI/level_selector.tscn")
	_busy = false

func _on_exit_button_pressed() -> void:
	if _busy: return
	_busy = true
	if finish:
		$Press.stop()
		$Press.play()
	await get_tree().create_timer(wait_seconds).timeout
	get_tree().quit()
