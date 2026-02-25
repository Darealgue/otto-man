# chain_explosion.gd - Patlama Zinciri: ölümden 2 sn sonra patlar, düşman + oyuncuya hasar
# Hasarı bir frame ertede veriyoruz; yoksa _ready içinde ölen düşman -> on_enemy_killed -> await ile deadlock oluyordu
extends Node2D

const EXPLOSION_RADIUS := 100.0
const EXPLOSION_DAMAGE := 8.0  # Düşük tutuldu (hem düşman hem oyuncuya vuruyor)
var _damage_applied := false

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if not _damage_applied:
		_damage_applied = true
		_apply_damage()
		# Bir frame sonra sil (hasar senkron tetiklemesin)
		call_deferred("queue_free")

func _apply_damage() -> void:
	var tree = get_tree()
	if not tree:
		return
	var center = global_position
	# Düşmanlar
	var enemies = tree.get_nodes_in_group("enemies")
	for node in enemies:
		if not is_instance_valid(node):
			continue
		if node.get("current_behavior") == "dead":
			continue
		var dist = center.distance_to(node.global_position)
		if dist <= EXPLOSION_RADIUS and node.has_method("take_damage"):
			node.take_damage(EXPLOSION_DAMAGE, 150.0, -100.0, true)
	# Oyuncu (hem düşmanlara hem oyuncuya vurur)
	var player = tree.get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("take_damage"):
		var dist = center.distance_to(player.global_position)
		if dist <= EXPLOSION_RADIUS:
			player.take_damage(EXPLOSION_DAMAGE, true, null)
