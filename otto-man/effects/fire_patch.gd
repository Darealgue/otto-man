# fire_patch.gd - Yerde yanan alev/kor birikintisi. Alev Dalgası, Alevli Parry, Meşale Düşman kullanır.
# Placeholder görsel: turuncu daire. Yarıçap, hasarın GERÇEK yarıçapıdır; içine giren düşman yanar.
extends Node2D

const TICK_INTERVAL := 0.5

var radius: float = 40.0
var duration: float = 2.0
## Dalga etkisi: birikinti bu süre sonra belirir (aralarındaki gecikme dalgayı ilerletir).
var delay: float = 0.0

var _elapsed: float = 0.0
var _tick: float = 0.0

func _ready() -> void:
	z_index = 57
	z_as_relative = false
	visible = delay <= 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < delay:
		return
	visible = true
	if _elapsed - delay >= duration:
		queue_free()
		return
	_tick += delta
	if _tick >= TICK_INTERVAL:
		_tick = 0.0
		_burn_nearby()
	queue_redraw()

func _burn_nearby() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for enemy in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("current_behavior") == "dead":
			continue
		if not enemy.has_method("add_burn_stack"):
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			enemy.add_burn_stack()

func _draw() -> void:
	var life: float = clampf(1.0 - (_elapsed - delay) / duration, 0.0, 1.0)
	var flicker: float = 0.85 + 0.15 * sin(_elapsed * 18.0)
	draw_circle(Vector2.ZERO, radius * flicker, Color(1.0, 0.45, 0.1, 0.30 * life))
	draw_arc(Vector2.ZERO, radius * flicker, 0.0, TAU, 24, Color(1.0, 0.65, 0.2, 0.6 * life), 3.0)
