extends Node2D
## Mark of the Ninja tarzı genişleyen gürültü halkası.

var _max_radius: float = 80.0
var _duration: float = 0.45
var _age: float = 0.0


func setup(max_radius: float, duration: float = 0.45) -> void:
	_max_radius = max_radius
	_duration = maxf(0.12, duration)
	z_index = 4
	var sm: Node = get_node_or_null("/root/StealthManager")
	if is_instance_valid(sm) and sm.has_signal("alarm_raised") and not sm.is_connected("alarm_raised", _on_alarm_raised):
		sm.alarm_raised.connect(_on_alarm_raised)


func _on_alarm_raised(_reason: String) -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _get_visual_alpha() <= 0.01 and _is_alarm_faded_out():
		queue_free()
		return
	if _age >= _duration:
		queue_free()
		return
	queue_redraw()


func _is_alarm_faded_out() -> bool:
	var sm: Node = get_node_or_null("/root/StealthManager")
	return is_instance_valid(sm) and bool(sm.get("segment_alarm"))


func _get_visual_alpha() -> float:
	var sm: Node = get_node_or_null("/root/StealthManager")
	if not is_instance_valid(sm) or not sm.has_method("get_perception_draw_alpha"):
		return 1.0
	if not sm.has_method("is_stealth_enabled") or not sm.is_stealth_enabled():
		return 1.0
	if not bool(sm.get("segment_alarm")):
		return 1.0
	return float(sm.get_perception_draw_alpha())


func _draw() -> void:
	var visual_alpha: float = _get_visual_alpha()
	if visual_alpha <= 0.01:
		return
	var t: float = clampf(_age / _duration, 0.0, 1.0)
	var radius: float = _max_radius * t
	var alpha: float = 0.42 * (1.0 - t) * visual_alpha
	var fill_alpha: float = 0.08 * (1.0 - t) * visual_alpha
	draw_circle(Vector2.ZERO, radius, Color(0.45, 0.68, 0.95, fill_alpha))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(0.55, 0.78, 1.0, alpha), 2.5)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(0.85, 0.92, 1.0, alpha * 0.45), 1.0)
