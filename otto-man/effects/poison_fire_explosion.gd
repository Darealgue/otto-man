# Zehir + ateş patlaması: zehirli düşmana ateş değince AoE patlama, düşmanlar + oyuncu hasar alabilir
extends Node2D

const EXPLOSION_RADIUS := 90.0
const EXPLOSION_DAMAGE := 10.0
var _damage_applied := false

func _process(_delta: float) -> void:
	if not _damage_applied:
		_damage_applied = true
		_apply_damage()
		call_deferred("queue_free")

func _apply_damage() -> void:
	var tree = get_tree()
	if not tree:
		return
	var center = global_position
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		if node.get("current_behavior") == "dead":
			continue
		if center.distance_to(node.global_position) <= EXPLOSION_RADIUS and node.has_method("take_damage"):
			node.take_damage(EXPLOSION_DAMAGE, 120.0, -80.0, true)
	var player = tree.get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("take_damage"):
		if center.distance_to(player.global_position) <= EXPLOSION_RADIUS:
			player.take_damage(EXPLOSION_DAMAGE, true, null)
