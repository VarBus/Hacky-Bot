# En PauseManager.gd
extends Node

var pause_menu_scene: PackedScene = preload("res://Scenes/UI/pause_menu.tscn")
var pause_menu_instance: Control = null
var pause_layer: CanvasLayer = null # <-- AÑADE ESTO

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if can_pause_in_current_scene():
			toggle_pause()

func toggle_pause():
	if get_tree().paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	if pause_menu_instance == null:
		# 1. Crear el CanvasLayer
		pause_layer = CanvasLayer.new()
		pause_layer.name = "PauseLayer"
		# Importante: El layer también debe procesar siempre
		pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS 

		# 2. Instanciar tu escena de menú
		pause_menu_instance = pause_menu_scene.instantiate()

		# 3. Añadir el menú AL LAYER
		pause_layer.add_child(pause_menu_instance)
		
		# 4. Añadir el LAYER AL ROOT
		get_tree().root.add_child(pause_layer)

	get_tree().paused = true

func resume_game():
	get_tree().paused = false
	
	# Ahora debemos liberar el LAYER, no la instancia
	if pause_layer: # Comprueba si el layer existe
		pause_layer.queue_free() # Esto libera el layer Y todos sus hijos (tu menú)
		pause_menu_instance = null
		pause_layer = null # Limpia la referencia

func retry_scene():
	get_tree().paused = false
	
	# Igual que en resume_game, libera el LAYER
	if pause_layer:
		pause_layer.queue_free()
		pause_menu_instance = null
		pause_layer = null

	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_path = current_scene.scene_file_path
		get_tree().change_scene_to_file(scene_path)

func can_pause_in_current_scene() -> bool:
	var scene_name = get_tree().current_scene.name
	var non_pausable_scenes =  ["Menu", "LevelSelector", "levels_selector", "WinScreen", "LostScreen"]
	return not scene_name in non_pausable_scenes
