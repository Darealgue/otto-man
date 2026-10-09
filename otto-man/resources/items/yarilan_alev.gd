# yarilan_alev.gd
# RARE - Dodge ile yanan düşmanın içinden geçersen yanma katmanları patlar ve kalan yanma hasarının
# 1.5 katı anında vurulur. Dodge bir saldırıya dönüşür. player_dodged dodge/dash BİTİŞİNDE ateşlenir;
# başlangıç-bitiş doğrusuna 45 px yakınlıktaki yanan düşmanlar "içinden geçilmiş" sayılır.

extends ItemEffect

const PATH_RADIUS := 45.0
const DAMAGE_PER_TICK := 1.0
const PAYOFF_MULT := 1.5
const RING_COLOR := Color(1.0, 0.5, 0.15, 0.8)
const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")

func _init():
	item_id = "yarilan_alev"
	item_name = tr("item.yarilan_alev.name")
	description = tr("item.yarilan_alev.description")
	flavor_text = "Alevi yararak geç"
	rarity = ItemRarity.RARE
	category = ItemCategory.DODGE
	affected_stats = ["dodge_burn_detonate"]

func _on_player_dodged(_direction, start_pos: Vector2, end_pos: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var im := get_node_or_null("/root/ItemManager")
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if node.get("burn_remaining_ticks") == null or int(node.burn_remaining_ticks) <= 0:
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(node.global_position, start_pos, end_pos)
		if closest.distance_to(node.global_position) > PATH_RADIUS:
			continue
		var ticks: int = int(node.burn_remaining_ticks)
		node.burn_remaining_ticks = 0
		node.set("burn_tick_timer", 0.0)
		if node.has_method("take_damage"):
			node.take_damage(float(ticks) * DAMAGE_PER_TICK * PAYOFF_MULT, 0.0, 0.0, true)
		if im:
			im.spawn_element_hit_flash(node, "fire")
		if tree.current_scene:
			var ring := Node2D.new()
			ring.set_script(_AoeBurstRingScript)
			tree.current_scene.add_child(ring)
			ring.setup(node.global_position, 50.0, RING_COLOR)
