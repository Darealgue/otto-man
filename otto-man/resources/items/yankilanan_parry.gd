# yankilanan_parry.gd
# LEGENDARY - Parry, çevredeki tüm düşmanlara parry'lenen vuruşun hasarının yarısını yansıtır
# ve yakındaki düşman mermilerini yok eder.

extends ItemEffect

const RADIUS := 220.0
const REFLECT_RATIO := 0.5
const KNOCKBACK := 200.0
const KNOCKBACK_UP := 120.0

var _player: CharacterBody2D = null

func _init():
	item_id = "yankilanan_parry"
	item_name = tr("item.yankilanan_parry.name")
	description = tr("item.yankilanan_parry.description")
	flavor_text = "Tek darbe, her yöne yankılanır"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.PARRY
	affected_stats = ["parry_echo"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Yankılanan Parry] ✅ Parry çevreye yankılanır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Yankılanan Parry] ❌ Kaldırıldı")

func _on_perfect_parry() -> void:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	var tree := _player.get_tree()
	var dmg: float = _player.last_parried_damage * REFLECT_RATIO
	var fx_scene: PackedScene = preload("res://effects/parry_effect.tscn")
	if dmg > 0.0:
		for node in tree.get_nodes_in_group("enemies"):
			if not is_instance_valid(node) or node.get("current_behavior") == "dead":
				continue
			if _player.global_position.distance_to(node.global_position) > RADIUS or not node.has_method("take_damage"):
				continue
			node.take_damage(dmg, KNOCKBACK, KNOCKBACK_UP, true)
			var fx = fx_scene.instantiate()
			tree.current_scene.add_child(fx)
			fx.global_position = node.global_position
	# Düşman mermileri: düşman hitbox'ı olup sahibi düşman olmayanlar (top, bomba vb.)
	for hb in tree.get_nodes_in_group("enemy_hitbox"):
		if not is_instance_valid(hb) or not (hb is Node2D):
			continue
		var owner_node: Node = hb.get_parent()
		if owner_node == null or owner_node.is_in_group("enemies") or owner_node == _player:
			continue
		if _player.global_position.distance_to((hb as Node2D).global_position) <= RADIUS:
			owner_node.queue_free()
