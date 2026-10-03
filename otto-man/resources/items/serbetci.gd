# serbetci.gd
# RARE - Zehirli bir düşman öldüğünde zehir stack'leri en yakın düşmana geçer;
# her geçişte 1 azalır (sönümlü zincir).
# Patlama Zinciri'nin zehir kardeşi ama daha stratejik: bir hedefte stack
# biriktirip öldürerek sürüye yayarsın.

extends ItemEffect

const TRANSFER_RADIUS := 260.0
const POISON_MAX_STACKS := 5

func _init():
	item_id = "serbetci"
	item_name = tr("item.serbetci.name")
	description = tr("item.serbetci.description")
	flavor_text = "Bir tas şerbet, elden ele"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	tags = ["elemental_poison"]
	affected_stats = ["poison_transfer"]

func on_enemy_killed(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	var stacks_val = enemy.get("poison_stacks")
	if stacks_val == null:
		return
	var carried := int(stacks_val) - 1  # Her geçişte 1 azalır
	if carried <= 0:
		return
	var tree = get_tree()
	if not tree:
		return
	var dmg: float = float(enemy.get("poison_damage_per_stack"))
	var interval: float = float(enemy.get("poison_tick_interval"))
	var origin: Vector2 = enemy.global_position
	var nearest: Node2D = null
	var nearest_dist := TRANSFER_RADIUS
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node == enemy:
			continue
		if node.get("current_behavior") == "dead":
			continue
		if not node.has_method("add_poison_stack"):
			continue
		var d: float = origin.distance_to(node.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = node
	if not nearest:
		return
	for _i in range(carried):
		nearest.add_poison_stack(POISON_MAX_STACKS, dmg, interval)
	var im = get_node_or_null("/root/ItemManager")
	if im and im.has_method("spawn_element_hit_flash"):
		im.spawn_element_hit_flash(nearest, "poison")
	print("[Şerbetçi] ☠ %d zehir stack'i devredildi" % carried)
