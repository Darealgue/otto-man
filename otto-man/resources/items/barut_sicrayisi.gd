# barut_sicrayisi.gd
# UNCOMMON - Hava zıplamasında (çift zıplama) altına patlama düşer; yakındaki düşmanları havaya fırlatır
# (gerçek fırlatma, yani hava kombolarına köprü). Oyuncuya zarar vermez. Hareket hattının barut köprüsü.
# Olay: jump_state.gd çift zıplamada `_on_air_jump(pos)` yayar.

extends ItemEffect

const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const RADIUS := 90.0
const DAMAGE := 10.0
const LAUNCH_UP_FORCE := 220.0
const KNOCKBACK := 60.0
const RING_COLOR := Color(1.0, 0.6, 0.2, 0.85)

func _init():
	item_id = "barut_sicrayisi"
	item_name = tr("item.barut_sicrayisi.name")
	description = tr("item.barut_sicrayisi.description")
	flavor_text = "Havada fitil tutuşur"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.JUMP
	affected_stats = ["air_jump_blast"]

func _on_air_jump(pos: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var radius: float = RADIUS * ExplosionModifiers.radius_mult()
	var dmg: float = DAMAGE * ExplosionModifiers.damage_mult()
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead" or not node.has_method("take_damage"):
			continue
		if pos.distance_to(node.global_position) <= radius:
			node.take_damage(dmg, KNOCKBACK, LAUNCH_UP_FORCE, true)
	if tree.current_scene:
		var ring := Node2D.new()
		ring.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(ring)
		ring.setup(pos, radius, RING_COLOR)
	ExplosionModifiers.announce(pos, radius)
