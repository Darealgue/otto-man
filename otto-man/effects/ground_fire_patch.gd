# Kayma sırasında yere bırakılan ateş; dikdörtgen içine giren düşman 1 burn stack alır, ateşteyken 1 altına inemez
extends Area2D

const LIFETIME := 3.0
const RECT_SIZE := Vector2(56, 64)
const MIN_BURN_TICKS := 3
var _timer := 0.0
var _enemies_inside: Dictionary = {}  # id -> true

func _ready() -> void:
	monitoring = true
	monitorable = false
	process_priority = -100

func _get_world_rect() -> Rect2:
	return Rect2(global_position + Vector2(-28, -48), RECT_SIZE)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= LIFETIME:
		_clear_all()
		queue_free()
		return
	var tree = get_tree()
	if not tree:
		return
	var rect = _get_world_rect()
	var currently_inside := {}
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if not node.has_method("add_burn_stack"):
			continue
		if not rect.has_point(node.global_position):
			continue
		var eid = node.get_instance_id()
		currently_inside[eid] = node
		if node.has_method("set_standing_on_fire_ground"):
			node.set_standing_on_fire_ground(true)
		var ticks = node.get("burn_remaining_ticks")
		if ticks == null or int(ticks) < MIN_BURN_TICKS:
			node.add_burn_stack()
	for eid in _enemies_inside.keys():
		if not currently_inside.has(eid):
			var node = instance_from_id(eid)
			if is_instance_valid(node) and node.has_method("set_standing_on_fire_ground"):
				node.set_standing_on_fire_ground(false)
	_enemies_inside.clear()
	for eid in currently_inside:
		_enemies_inside[eid] = true

func _clear_all() -> void:
	for eid in _enemies_inside:
		var node = instance_from_id(eid)
		if is_instance_valid(node) and node.has_method("set_standing_on_fire_ground"):
			node.set_standing_on_fire_ground(false)
