extends Node

var music_player: AudioStreamPlayer

func _ready():
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.bus = "Music"  
	music_player.autoplay = false
func _play_sound_effect(stream :AudioStreamPlayer2D, pitch: float =1.0):
	stream.stop()
	stream.pitch_scale =pitch
	stream.play()
