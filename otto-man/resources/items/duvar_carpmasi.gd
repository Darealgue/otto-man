# duvar_carpmasi.gd
# RARE - Bir düşmanı duvara fırlatırsan (darbe sırasında hızla duvara çarparsa) çarptığı yerde patlar:
# çevresindeki düşmanlar ve kendisi hasar alır. Duvarın dibine sıkıştırmak ödüllenir.
# Çarpma tespiti: düşman "hurt" (darbe) durumundayken bir önceki karedeki yatay hız yüksekti ve
# şimdi duvara yaslanıyor. Aynı düşman 1 sn içinde tekrar patlamaz. Uçan düşmanlar etkilenmez.

extends ItemEffect

const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const MIN_IMPACT_SPEED := 220.0
const BLAST_RADIUS := 80.0
const BLAST_DAMAGE := 12.0
const COOLDOWN_MSEC := 1000
const SPEED_META := "duvar_carpmasi_vx"
const COOLDOWN_META := "duvar_carpmasi_until"
const RING_COLOR := Color(1.0, 0.6, 0.2, 0.85)

func _init():
	item_id = "duvar_carpmasi"
	item_name = tr("item.duvar_carpmasi.name")
	description = tr("item.duvar_carpmasi.description")
	flavor_text = "Duvar da barut gibi patlar"
	rarity = ItemRarity.RARE
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["wall_slam_blast"]

func process(_player_node: CharacterBody2D, _delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var now := Time.get_ticks_msec()
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if not node.has_method("is_on_wall") or node.get("velocity") == null:
			continue
		if node.has_method("_is_flying_enemy_runtime") and node._is_flying_enemy_runtime():
			continue
		var prev_speed: float = absf(float(node.get_meta(SPEED_META, 0.0)))
		node.set_meta(SPEED_META, node.velocity.x)
		if node.get("current_behavior") != "hurt":
			continue
		if prev_speed >= MIN_IMPACT_SPEED and node.is_on_wall() and int(node.get_meta(COOLDOWN_META, 0)) <= now:
			node.set_meta(COOLDOWN_META, now + COOLDOWN_MSEC)
			_detonate(node.global_position, tree)

func _detonate(pos: Vector2, tree: SceneTree) -> void:
	var radius: float = BLAST_RADIUS * ExplosionModifiers.radius_mult()
	var dmg: float = BLAST_DAMAGE * ExplosionModifiers.damage_mult()
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead" or not node.has_method("take_damage"):
			continue
		if pos.distance_to(node.global_position) <= radius:
			node.take_damage(dmg, 100.0, 40.0, true)
	if tree.current_scene:
		var ring := Node2D.new()
		ring.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(ring)
		ring.setup(pos, radius, RING_COLOR)
	ExplosionModifiers.announce(pos, radius)
