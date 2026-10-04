# donus_darbesi.gd
# UNCOMMON - Gölge Dönüşü ile geri ışınlanırken geçtiğin yoldaki düşmanlar senin vuruşunun
# kadar hasar alır. İz Bırakan yol taramasını ve Element İzi'ni de aynı yola uygular.
# Ön koşul: Gölge Dönüşü.

extends ItemEffect

const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const PATH_RADIUS := 55.0
const SAMPLES := 6
const FALLBACK_DAMAGE := 8.0
const RING_COLOR := Color(0.55, 0.3, 0.9, 0.7)

var _player: CharacterBody2D = null

func _init():
	item_id = "donus_darbesi"
	item_name = tr("item.donus_darbesi.name")
	description = tr("item.donus_darbesi.description")
	flavor_text = "Dönerken geride bir yara bırakır"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = ["return_strike"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Dönüş Darbesi] ✅ Gölge dönüşü yol boyunca hasar verir")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Dönüş Darbesi] ❌ Kaldırıldı")

# golge_donusu.gd -> ItemManager.notify_item_event
func _on_shadow_return(from_pos: Vector2, to_pos: Vector2) -> void:
	var tree := get_tree()
	if not tree or not is_instance_valid(_player):
		return
	var dmg: float = FALLBACK_DAMAGE
	var hb = _player.get_node_or_null("Hitbox")
	if hb and hb.get("damage") != null:
		dmg = float(hb.damage)
	var hit_ids: Array = []
	for i in range(SAMPLES + 1):
		var sample: Vector2 = from_pos.lerp(to_pos, float(i) / float(SAMPLES))
		for node in tree.get_nodes_in_group("enemies"):
			if not is_instance_valid(node) or node.get("current_behavior") == "dead":
				continue
			if hit_ids.has(node.get_instance_id()):
				continue
			if sample.distance_to(node.global_position) > PATH_RADIUS or not node.has_method("take_damage"):
				continue
			hit_ids.append(node.get_instance_id())
			node.take_damage(dmg, 100.0, 40.0, true)
	var im := get_node_or_null("/root/ItemManager")
	if im:
		im.apply_movement_trail_if_active(hit_ids, from_pos, to_pos)
		im.spawn_element_trail_if_active(from_pos)
	if tree.current_scene:
		var ring := Node2D.new()
		ring.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(ring)
		ring.setup(to_pos, 50.0, RING_COLOR)
