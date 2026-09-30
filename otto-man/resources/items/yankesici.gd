# yankesici.gd
# RARE - Zehirli bir düşmanın yanından dodge ile geçtiğinde ondan altın çalarsın;
# miktar zehir stack'i başına artar.
# Eksi: çalmak o düşmandan 1 zehir stack'i tüketir — hem soyup hem zehirle
# öldürmek verimsizdir, seçim yapman gerekir.
# Akrobat hırsız fantezisini doğrudan mekanikleştirir (docs/ITEM_UNLOCK_SISTEMI.md bölüm 3).

extends ItemEffect

const STEAL_RADIUS := 90.0
const GOLD_PER_STACK := 4
const GOLD_BASE := 2

func _init():
	item_id = "yankesici"
	item_name = tr("item.yankesici.name")
	description = tr("item.yankesici.description")
	flavor_text = "Cebi delen, kılıç değildir"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["dodge_steal_gold"]

func _on_player_dodged(_direction: int, start_pos: Vector2, end_pos: Vector2) -> void:
	var tree = get_tree()
	if not tree:
		return
	var total_gold := 0
	var last_pos: Vector2 = end_pos
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		var stacks_val = node.get("poison_stacks")
		if stacks_val == null:
			continue
		var stacks := int(stacks_val)
		if stacks <= 0:
			continue
		# Dodge yolunun herhangi bir ucuna yeterince yaklaştıysak cebini boşalt
		var pos: Vector2 = node.global_position
		if pos.distance_to(start_pos) > STEAL_RADIUS and pos.distance_to(end_pos) > STEAL_RADIUS:
			continue
		total_gold += GOLD_BASE + stacks * GOLD_PER_STACK
		# Bedeli: çalınan düşmanın zehri bir kademe zayıflar
		node.set("poison_stacks", maxi(0, stacks - 1))
		last_pos = pos
	if total_gold <= 0:
		return
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	if gpd and gpd.has_method("credit_run_loot_gold"):
		gpd.credit_run_loot_gold(total_gold, last_pos)
	elif gpd and gpd.has_method("add_dungeon_gold"):
		gpd.add_dungeon_gold(total_gold)
	print("[Yankesici] 💰 %d altın çalındı" % total_gold)
