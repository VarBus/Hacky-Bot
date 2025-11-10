extends Label
signal time_up

@onready var cronometro: Timer = $"../Cronometro"

@export var start_minutes: int = 0
@export var start_seconds: int = 30

@export var warning_threshold: int = 10
@export var normal_color: Color = Color.WHITE
@export var warning_color: Color = Color.RED

@export var pulse_scale: float = 1.18     
@export var pulse_up_time: float = 0.12    
@export var pulse_down_time: float = 0.18  

var remaining: int = 0
var running: bool = false

var _base_scale: Vector2 = Vector2.ONE
var _tween: Tween

func _ready() -> void:
	_base_scale = scale
	set_mm_ss(start_minutes, start_seconds)
	_apply_color()
	_update_text()
	start()

func set_mm_ss(m: int, s: int) -> void:
	s = clamp(s, 0, 59)
	remaining = max(m, 0) * 60 + s
	_apply_color()
	_update_text()

func add_time(sec: int) -> void:
	remaining = max(remaining + sec, 0)
	_apply_color()
	_update_text()

func start() -> void:
	if running: return
	if remaining <= 0:
		time_up.emit()
		return
	running = true
	cronometro.start()

func stop() -> void:
	running = false
	cronometro.stop()
	_reset_visuals()

func reset() -> void:
	stop()
	set_mm_ss(start_minutes, start_seconds)

func _update_text() -> void:
	var m := remaining / 60
	var s := remaining % 60
	text = "%02d:%02d" % [m, s]

func _apply_color() -> void:
	var col := warning_color if remaining <= warning_threshold else normal_color
	add_theme_color_override("font_color", col)
	add_theme_color_override("font_outline_color", col)

func _pulse_once() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	scale = _base_scale
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", _base_scale * Vector2(pulse_scale, pulse_scale), pulse_up_time)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "scale", _base_scale, pulse_down_time)

func _reset_visuals() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	scale = _base_scale
	add_theme_color_override("font_color", normal_color)

func _on_cronometro_timeout() -> void:
	if not running: return
	if remaining > 0:
		remaining -= 1
		_apply_color()
		_update_text()
		if remaining <= warning_threshold and remaining > 0:
			$"../Countdown".play()
			_pulse_once()
	if remaining <= 0:
		running = false
		cronometro.stop()
		_update_text()
		var lost := $"../UI/LostScreen"
		if is_instance_valid(lost):
			lost.visible = true
		_reset_visuals()
		time_up.emit()
