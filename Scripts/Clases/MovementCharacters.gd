extends Node
class_name Movement2D

@export var speed: float = 260.0
@export var accel: float = 1400.0
@export var deccel: float = 1600.0
@export var gravity: float = 1200.0
@export var jump_velocity: float = -420.0
@export var air_control: float = 0.6

@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

var _coyote: float = 0.0
var _jump_buffer: float = 0.0

func begin_frame(on_floor: bool, delta: float) -> void:
	if on_floor:
		_coyote = coyote_time
	else:
		_coyote = max(0.0, _coyote - delta)
	_jump_buffer = max(0.0, _jump_buffer - delta)

func buffer_jump() -> void:
	_jump_buffer = jump_buffer_time

func step(vel: Vector2, dir: float, on_floor: bool, delta: float) -> Vector2:
	var v := vel
	if not on_floor:
		v.y += gravity * delta
	if dir != 0.0:
		var target := dir * speed
		var rate := accel if on_floor else accel * air_control
		v.x = move_toward(v.x, target, rate * delta)
	else:
		var rate2 := deccel if on_floor else deccel * 0.25
		v.x = move_toward(v.x, 0.0, rate2 * delta)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		v.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
	return v
