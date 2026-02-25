# third_jump_explosion.gd - Çift Zıplama 3. zıplama patlaması (düşmanlara hasar)
extends Node2D

const RADIUS := 70.0
const DAMAGE := 8.0
const VISUAL_DURATION := 0.25
const VISUAL_MAX_R := 55.0
var _t := 0.0
var _damage_done := false

func _process(delta: float) -> void:
	if not _damage_done:
		_damage_done = true
		var tree = get_tree()
		if tree:
			for node in tree.get_nodes_in_group("enemies"):
				if not is_instance_valid(node) or node.get("current_behavior") == "dead":
					continue
				if global_position.distance_to(node.global_position) <= RADIUS and node.has_method("take_damage"):
					node.take_damage(DAMAGE, 80.0, -60.0, true)
	_t += delta
	if _t >= VISUAL_DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var p := _t / VISUAL_DURATION
	var r := VISUAL_MAX_R * p
	var a := 1.0 - p
	if r < 1.0 or a <= 0.0:
		return
	draw_arc(Vector2.ZERO, r, 0.0, TAU, max(10, int(r * 0.2)), Color(1.0, 0.6, 0.2, a * 0.8))
