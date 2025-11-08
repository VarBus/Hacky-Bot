extends Node2D

@export var puerta_cerrada: Texture
@export var puerta_abierta: Texture

var is_open = false

func _ready():
	$Sprite2D.texture = puerta_cerrada
	# Conectamos la señal del Area2D
	$StaticBody2D.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Verificar si el que entra es el enemigo
	if body.is_in_group("enemies"):
		open_door()

func open_door():
	if not is_open:
		is_open = true
		$Sprite2D.texture = puerta_abierta
		print("🚪 Puerta abierta por enemigo")
