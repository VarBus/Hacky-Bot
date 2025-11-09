extends Label
signal time_up 

@onready var cronometro: Timer = $"../Cronometro"

@export var start_minutes: int
@export var start_seconds: int

var remaining: int = 0
var running: bool = false

func _ready() -> void:
	set_mm_ss(start_minutes, start_seconds)
	_update_text()
	start()

func set_mm_ss(m: int, s: int) -> void:
	s = clamp(s, 0, 59)
	remaining = max(m, 0) * 60 + s
	_update_text()

func add_time(sec: int) -> void:
	remaining = max(remaining + sec, 0)
	_update_text()

func start() -> void:
	if running: return
	if remaining <= 0:
		time_up.emit()
		return
	running = true
	$"../Cronometro".start()

func stop() -> void:
	running = false
	$"../Cronometro".stop()

func reset() -> void:
	stop()
	set_mm_ss(start_minutes, start_seconds)

func _update_text() -> void:
	var m := remaining / 60
	var s := remaining % 60
	text = "%02d:%02d" % [m, s]

func _on_cronometro_timeout() -> void:
	if not running: return
	if remaining > 0:
		remaining -= 1
		_update_text()
	if remaining <= 0:
		running = false
		$"../UI/LostScreen".visible = true
		$"../Cronometro".stop()
		_update_text()
		time_up.emit()
