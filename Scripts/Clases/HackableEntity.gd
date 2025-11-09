# HackableEntity.gd
extends CharacterBody2D
class_name HackableEntity

@export var visual_node: CanvasItem

# Señal que el jugador puede usar para saber cuándo se libera el control
signal control_released

# Variable para saber quién nos está controlando
var controller = null
var is_hacked: bool = false

# Esta función es llamada por el jugador para aplicar el feedback visual
func select() -> void:
	if visual_node:
		visual_node.modulate = Color.CRIMSON

# Llamada por el jugador para quitar el feedback visual
func deselect() -> void:
	if visual_node:
		visual_node.modulate = Color.WHITE

# El jugador llama a esta función para tomar el control
# Pasamos 'player_node' para que la entidad sepa quién la controla
func take_control(player_node) -> void:
	if is_hacked: return
	
	controller = player_node
	is_hacked = true
	print(self.name + " ha sido hackeado.")
	# Aquí podrías añadir un sonido o efecto visual de hackeo exitoso

# El jugador llama a esta función para devolver el control
func release_control() -> void:
	if not is_hacked: return
	
	controller = null
	is_hacked = false
	deselect() # Nos aseguramos de quitar el modulate rojo
	print(self.name + " ha perdido el control del jugador.")
	emit_signal("control_released")
	# Aquí podrías tener lógica para que la IA se reinicie

# ESTA ES LA FUNCIÓN MÁS IMPORTANTE.
# Cada enemigo la implementará de forma diferente para definir
# cómo se comporta cuando es controlado por el jugador.
# El guion bajo indica que es una función "virtual" que debe ser sobreescrita.
func _handle_hacked_input(delta: float) -> void:
	# Por defecto, una entidad hackeada no hace nada.
	# Los enemigos específicos sobreescribirán esta función.
	pass
