# heavy_explosion.gd - Patlama Topuzu: sadece düşmanlara hasar, oyuncuya değil + placeholder görsel
extends Node2D

const EXPLOSION_RADIUS := 110.0
const EXPLOSION_DAMAGE := 10.0
const VISUAL_DURATION := 0.35
const VISUAL_MAX_RADIUS := 95.0

var _damage_applied := false
var _visual_t := 0.0

func _process(delta: float) -> void:
	if not _damage_applied:
		_damage_applied = true
		_apply_damage()
	_visual_t += delta
	if _visual_t >= VISUAL_DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := _visual_t / VISUAL_DURATION
	var r := VISUAL_MAX_RADIUS * t
	var alpha := 1.0 - t
	if r < 1.0 or alpha <= 0.0:
		return
	var col := Color(1.0, 0.55, 0.15, alpha * 0.85)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, max(12, int(r * 0.2)), col)
	draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, max(8, int(r * 0.15)), Color(1.0, 0.75, 0.3, alpha * 0.5))

func _apply_damage() -> void:
	var tree = get_tree()
	if not tree:
		return
	var center = global_position
	var enemies = tree.get_nodes_in_group("enemies")
	for node in enemies:
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if center.distance_to(node.global_position) <= EXPLOSION_RADIUS and node.has_method("take_damage"):
			node.take_damage(EXPLOSION_DAMAGE, 120.0, -80.0, true)
