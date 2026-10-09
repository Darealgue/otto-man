# yangin_yayilimi.gd
# RARE - Yanan bir düşman başka bir düşmana değerse yanma ona da geçer. Kalabalıkta zincirleme yangın.
# Aynı düşman çifti için kısa bekleme yok; hedef zaten yanıyorsa dokunulmaz (yanma yenilenmez).

extends ItemEffect

const CONTACT_RADIUS := 55.0
const POLL_INTERVAL := 0.2

var _poll_left: float = 0.0

func _init():
	item_id = "yangin_yayilimi"
	item_name = tr("item.yangin_yayilimi.name")
	description = tr("item.yangin_yayilimi.description")
	flavor_text = "Bir kıvılcım yeter"
	rarity = ItemRarity.RARE
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["fire_spread"]

func process(_player_node: CharacterBody2D, delta: float) -> void:
	_poll_left -= delta
	if _poll_left > 0.0:
		return
	_poll_left = POLL_INTERVAL
	var im := get_node_or_null("/root/ItemManager")
	var tree := get_tree()
	if im == null or tree == null:
		return
	var enemies: Array = tree.get_nodes_in_group("enemies")
	var burning: Array = []
	for node in enemies:
		if is_live_enemy(node) and node.get("burn_remaining_ticks") != null and int(node.burn_remaining_ticks) > 0:
			burning.append(node)
	if burning.is_empty():
		return
	for node in enemies:
		if not is_live_enemy(node) or not node.has_method("add_burn_stack"):
			continue
		if node.get("burn_remaining_ticks") == null or int(node.burn_remaining_ticks) > 0:
			continue
		for src in burning:
			if src != node and src.global_position.distance_to(node.global_position) <= CONTACT_RADIUS:
				node.add_burn_stack()
				im.spawn_element_hit_flash(node, "fire")
				break
