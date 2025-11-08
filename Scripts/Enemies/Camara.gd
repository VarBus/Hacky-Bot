# CamaraSeguridad.gd
extends Node2D

# ¡Creamos nuestra propia señal!
# Cualquiera podrá escuchar cuando esta cámara detecte al jugador.
signal player_detected

# Conectamos la señal del Area2D desde el editor.
# Selecciona VisionConeArea, ve al panel "Nodo" > "Señales" y
# haz doble clic en "body_entered". Conéctalo a este script.
func _on_vision_area_2d_body_entered(body: Node2D) -> void:
# Comprobamos si el cuerpo que entró está en el grupo "player"
	if body.is_in_group("player"):
		
		# --- OPCIONAL PERO RECOMENDADO: Comprobar Línea de Visión ---
		# Si la cámara puede ver a través de las paredes, es un mal juego.
		# ¡Usaremos el RayCast2D!
		
		# Apunta el RayCast al centro del jugador
		$RayCast2D.target_position = body.global_position - global_position
		# Actualiza el raycast (solo es necesario en un frame)
		$RayCast2D.force_raycast_update()
		
		# Si el rayo NO está colisionando con nada (o si lo que golpea es el jugador)
		# (Aquí asumimos que las paredes son StaticBody2D)
		if not $RayCast2D.is_colliding() or $RayCast2D.get_collider() == body:
			# ¡Te vemos!
			print("¡JUGADOR DETECTADO!")
			
			# Emitimos nuestra señal personalizada
			player_detected.emit()
			
			# O, para una acción simple (como pediste):
			# get_tree().reload_current_scene() # Reinicia el nivel
		else:
			# Hay una pared en medio. Falsa alarma.
			pass
		# -----------------------------------------------------------
		
		# Si no usas el RayCast (versión simple), solo haz esto:
		# print("¡JUGADOR DETECTADO!")
		# player_detected.emit()
		# get_tree().reload_current_scene()
