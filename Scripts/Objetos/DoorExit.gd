extends Area2D


@export var esta_bloqueada: bool = false

@export var proximo_nivel_path: String

@export var textura_normal: Texture
@export var textura_bloqueada: Texture
@export var textura_abierta: Texture # Cuando un enemigo la abre

var is_open = false

func _ready():
	# Conectamos nuestra propia señal 'body_entered'
	body_entered.connect(_on_body_entered)
	
	# Asignamos la textura inicial correcta
	if esta_bloqueada:
		$Sprite2D.texture = textura_bloqueada
		is_open = false
	else:
		$Sprite2D.texture = textura_normal
		is_open = true # Una puerta normal está "abierta" lógicamente

func _on_body_entered(body):
	# ¿Quién nos tocó?
	
	if body.is_in_group("player"):
		# Si el jugador toca la puerta...
		if is_open:
			# ¡Y la puerta está abierta (sea normal o hackeada)!
			call_deferred("_ir_al_siguiente_nivel")
		else:
			# El jugador tocó una puerta bloqueada
			print("PUERTA BLOQUEADA. Necesitas un hacker.")
			# (Aquí podrías poner un sonido de "bloqueado")

	elif body.is_in_group("hackable"):
		# Si un enemigo hacker toca la puerta...
		if esta_bloqueada and not is_open:
			# ¡Y la puerta ESTÁ bloqueada y no ha sido abierta!
			
			_abrir_puerta_hackeada()

func _abrir_puerta_hackeada():
	print("¡Puerta hackeada por enemigo!")
	is_open = true
	esta_bloqueada = false 
	$Sprite2D.texture = textura_abierta

func _ir_al_siguiente_nivel():
	if proximo_nivel_path.is_empty():
		print("ERROR: No se ha definido un próximo nivel.")
		return

	# ¡Cambiamos a la siguiente escena!
	get_tree().change_scene_to_file(proximo_nivel_path)
