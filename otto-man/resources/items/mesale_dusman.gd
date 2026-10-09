# mesale_dusman.gd
# RARE - Havaya fırlatılan yanan düşman arkasında alev bırakır ve yere düştüğü yerde kor birikintisi açar.
# Havaya Fırlatma hattının ateş köprüsü. Uçan düşmanlar (sürekli havada) etkilenmez.

extends ItemEffect

const POLL_INTERVAL := 0.1
const TRAIL_INTERVAL_MSEC := 150
const TRAIL_RADIUS := 28.0
const TRAIL_DURATION := 1.2
const LANDING_RADIUS := 90.0
const LANDING_DURATION := 3.0
const AIR_META := "mesale_dusman_air"
const TRAIL_META := "mesale_dusman_next_trail"

var _poll_left: float = 0.0

func _init():
	item_id = "mesale_dusman"
	item_name = tr("item.mesale_dusman.name")
	description = tr("item.mesale_dusman.description")
	flavor_text = "Yanan düşman yürüyen meşaledir"
	rarity = ItemRarity.RARE
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["air_fire_trail"]

func process(_player_node: CharacterBody2D, delta: float) -> void:
	_poll_left -= delta
	if _poll_left > 0.0:
		return
	_poll_left = POLL_INTERVAL
	var im := get_node_or_null("/root/ItemManager")
	var tree := get_tree()
	if im == null or tree == null:
		return
	var now := Time.get_ticks_msec()
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if node.get("burn_remaining_ticks") == null or not node.has_method("is_on_floor"):
			continue
		if node.has_method("_is_flying_enemy_runtime") and node._is_flying_enemy_runtime():
			continue
		var burning: bool = int(node.burn_remaining_ticks) > 0
		var airborne: bool = not node.is_on_floor()
		if burning and airborne:
			node.set_meta(AIR_META, true)
			if int(node.get_meta(TRAIL_META, 0)) <= now:
				node.set_meta(TRAIL_META, now + TRAIL_INTERVAL_MSEC)
				im.spawn_fire_patch(node.global_position, TRAIL_RADIUS, TRAIL_DURATION)
		elif not airborne and node.has_meta(AIR_META):
			node.remove_meta(AIR_META)
			if burning:
				im.spawn_fire_patch(node.global_position + Vector2(0.0, -6.0), LANDING_RADIUS, LANDING_DURATION)
