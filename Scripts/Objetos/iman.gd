extends HackableEntity

# Nueva señal: habilita el auto de las plataformas
signal platform_auto(active: bool, source: Node)

@export var target_group: StringName = &"platform"

var _inside_platforms: Array[Node] = []
@onready var gravity_area_player: Area2D = get_node_or_null("GravityAreaPlayer")

var _last_gate := -1  # -1 = sin iniciar, 0 = off, 1 = on

func _ready() -> void:
	if gravity_area_player:
		gravity_area_player.body_entered.connect(_on_gravity_area_player_body_entered)
		gravity_area_player.body_exited.connect(_on_gravity_area_player_body_exited)

func _physics_process(delta: float) -> void:
	# Gate = solo ON mientras está hackeado
	var gate := (1 if is_hacked else 0)

	# Evita spam de señales
	if gate != _last_gate:
		_last_gate = gate
		var active := gate == 1
		print("[Iman] platform_auto=", active)
		if _inside_platforms.size() > 0:
			emit_signal("platform_auto", active, self)

# (Opcional) si quieres controlar algo mientras está hackeado, hazlo aquí
func _handle_hacked_input(delta: float) -> void:
	# p.ej. con "shoot" podrías cambiar color o algo visual, pero el gate ya depende de is_hacked
	pass

# Al soltar el control, forzamos gate OFF por si acaso
func release_control() -> void:
	super.release_control()
	_last_gate = 0
	emit_signal("platform_auto", false, self)

# --- Detección / conexión con plataformas ---
func _on_gravity_area_player_body_entered(body: Node2D) -> void:
	if body.is_in_group(target_group):
		if not _inside_platforms.has(body):
			_inside_platforms.append(body)

		if body.has_method("_on_magnet_platform_auto"):
			var cb := Callable(body, "_on_magnet_platform_auto")
			if not is_connected("platform_auto", cb):
				var err := connect("platform_auto", cb)
				if err != OK:
					push_warning("No se pudo conectar con " + body.name + " err=" + str(err))
			print("[Iman] Conectado a plataforma:", body.name)
		else:
			push_warning(body.name + " no implementa _on_magnet_platform_auto")

		# Al entrar, envía el estado actual del gate (según is_hacked)
		emit_signal("platform_auto", is_hacked, self)

func _on_gravity_area_player_body_exited(body: Node2D) -> void:
	if body.is_in_group(target_group):
		if _inside_platforms.has(body):
			_inside_platforms.erase(body)

		var cb := Callable(body, "_on_magnet_platform_auto")
		if is_connected("platform_auto", cb):
			disconnect("platform_auto", cb)
		print("[Iman] Desconectado de plataforma:", body.name)

		# De cortesía, dejarla en OFF al salir
		if body.has_method("_on_magnet_platform_auto"):
			body.call("_on_magnet_platform_auto", false, self)
