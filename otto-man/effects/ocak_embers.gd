# Ocak: yanarak ölen düşmanın yere bıraktığı kor.
# İçine giren düşman yanar; oyuncu üstünden geçerse bir kez stamina kazanır.
extends Node2D

const LIFETIME := 3.0
const RECT_SIZE := Vector2(72, 56)
const PLAYER_STAMINA_REWARD := 0.5
const EMBER_COLOR := Color(1.0, 0.42, 0.12, 0.75)

var _timer := 0.0
var _player_rewarded := false
var _burned: Dictionary = {}  # instance_id -> true

func _ready() -> void:
	z_index = 2
	process_priority = -100

func _get_world_rect() -> Rect2:
	return Rect2(global_position - RECT_SIZE * 0.5, RECT_SIZE)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= LIFETIME:
		queue_free()
		return
	queue_redraw()
	var tree := get_tree()
	if not tree:
		return
	var rect := _get_world_rect()

	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if not node.has_method("add_burn_stack"):
			continue
		if not rect.has_point(node.global_position):
			continue
		var eid := node.get_instance_id()
		if _burned.has(eid):
			continue
		_burned[eid] = true
		node.add_burn_stack()

	if not _player_rewarded:
		var player := tree.get_first_node_in_group("player")
		if is_instance_valid(player) and rect.has_point(player.global_position):
			_player_rewarded = true
			var bar := tree.get_first_node_in_group("stamina_bar")
			if bar and bar.has_method("restore_partial_charge"):
				bar.restore_partial_charge(PLAYER_STAMINA_REWARD)

func _draw() -> void:
	var fade: float = clampf(1.0 - (_timer / LIFETIME), 0.0, 1.0)
	var col := EMBER_COLOR
	col.a *= fade
	draw_rect(Rect2(-RECT_SIZE * 0.5, RECT_SIZE), col, true)
