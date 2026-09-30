# koz_tutan.gd
# COMMON - Yanan bir düşman öldüğünde alev en yakın düşmana sıçrar.
# Ateş zindanının giriş item'ı: yanma uygulayan itemlere ilk kez bir amaç verir.

extends ItemEffect

const SPREAD_RADIUS := 220.0

func _init():
	item_id = "koz_tutan"
	item_name = tr("item.koz_tutan.name")
	description = tr("item.koz_tutan.description")
	flavor_text = "Kor, sahibini arar"
	rarity = ItemRarity.COMMON
	category = ItemCategory.SPECIAL
	tags = ["elemental_fire"]
	affected_stats = ["burn_spread"]

func on_enemy_killed(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	# Ölen düşman yanıyor muydu? (burn_remaining_ticks ölümde temizlenmiyor)
	var ticks = enemy.get("burn_remaining_ticks")
	if ticks == null or int(ticks) <= 0:
		return
	var tree = get_tree()
	if not tree:
		return
	var origin: Vector2 = enemy.global_position
	var nearest: Node2D = null
	var nearest_dist := SPREAD_RADIUS
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node == enemy:
			continue
		if node.get("current_behavior") == "dead":
			continue
		if not node.has_method("add_burn_stack"):
			continue
		var d: float = origin.distance_to(node.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = node
	if nearest:
		nearest.add_burn_stack()
