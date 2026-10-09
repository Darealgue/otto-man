# fitil_hatti.gd
# RARE - Beklemedeki barut nesneleri (Dodge Bombası, Lağımcı izi, uçan Ateş Bombası) komşu bir patlamaya
# yakınsa fitilini beklemeden hemen patlar; patlamalar birbirini zincirler. Barut itemlerini birbirine
# bağlayan köprü. Olay: ExplosionModifiers.announce -> ItemManager.notify_explosion -> `_on_explosion`.

extends ItemEffect

const REACH_BONUS := 50.0
const CHAIN_DELAY := 0.15

func _init():
	item_id = "fitil_hatti"
	item_name = tr("item.fitil_hatti.name")
	description = tr("item.fitil_hatti.description")
	flavor_text = "Fitil fitili bulur"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["fuse_chain"]

func _on_explosion(pos: Vector2, radius: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var reach: float = radius + REACH_BONUS
	for node in tree.get_nodes_in_group("barut_fuse"):
		if not is_instance_valid(node) or not node.has_method("detonate_now") or node.has_meta("fitil_scheduled"):
			continue
		if pos.distance_to(node.global_position) > reach:
			continue
		node.set_meta("fitil_scheduled", true)
		tree.create_timer(CHAIN_DELAY).timeout.connect(func():
			if is_instance_valid(node):
				node.detonate_now())
	var im := get_node_or_null("/root/ItemManager")
	if im == null:
		return
	for item in im.active_items:
		if is_instance_valid(item) and item.has_method("detonate_pending_near"):
			var bomb_item = item
			tree.create_timer(CHAIN_DELAY).timeout.connect(func():
				if is_instance_valid(bomb_item):
					bomb_item.detonate_pending_near(pos, reach))
