# kazik_darbesi.gd
# RARE - Havada dövülen (fırlatılmış) düşmana aşağı saldırı (düşme vuruşu) ile vurursan düşman yere
# çakılır; indiği yerde alan hasarı olur ve aktif elementlerini taşır. Uçan düşmanlar çakılamaz.
# Havaya Fırlatma hattının barut payoff'u: Zıplatan Yumruk, Bulaşıcı Darbe, Zehir Havuzu ile birleşir.

extends ItemEffect

const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const SLAM_SPEED := 1100.0
const SLAM_WINDOW_MSEC := 2000
const BLAST_RADIUS := 110.0
const BLAST_DAMAGE_RATIO := 0.8
const BLAST_MIN_DAMAGE := 8.0
const POLL_INTERVAL := 0.05
const SLAM_META := "kazik_darbesi_slam"
const RING_COLOR := Color(1.0, 0.55, 0.2, 0.85)

var _poll_left: float = 0.0

func _init():
	item_id = "kazik_darbesi"
	item_name = tr("item.kazik_darbesi.name")
	description = tr("item.kazik_darbesi.description")
	flavor_text = "Kazık gibi çak"
	rarity = ItemRarity.RARE
	category = ItemCategory.FALL_ATTACK
	affected_stats = ["air_slam"]

func _on_player_attack_landed(attack_type: String, damage: float, targets: Array, _position: Vector2, _effect_filter: String = "all") -> void:
	if attack_type != "fall":
		return
	var now := Time.get_ticks_msec()
	for target in targets:
		var enemy := resolve_enemy_target(target)
		if enemy == null or not enemy.has_method("is_on_floor") or enemy.is_on_floor():
			continue  # havada değil: normal düşme vuruşu
		if enemy.has_method("_is_flying_enemy_runtime") and enemy._is_flying_enemy_runtime():
			continue
		if enemy.get("velocity") == null:
			continue
		enemy.velocity.y = SLAM_SPEED
		if enemy.get("air_float_timer") != null:
			enemy.air_float_timer = 0.0
		enemy.set_meta(SLAM_META, {"until": now + SLAM_WINDOW_MSEC, "damage": damage})

func process(_player_node: CharacterBody2D, delta: float) -> void:
	_poll_left -= delta
	if _poll_left > 0.0:
		return
	_poll_left = POLL_INTERVAL
	var tree := get_tree()
	if tree == null:
		return
	var now := Time.get_ticks_msec()
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not node.has_meta(SLAM_META):
			continue
		var info: Dictionary = node.get_meta(SLAM_META)
		if node.get("current_behavior") == "dead" or int(info["until"]) < now:
			node.remove_meta(SLAM_META)
			continue
		if node.has_method("is_on_floor") and node.is_on_floor():
			node.remove_meta(SLAM_META)
			_detonate(node.global_position, float(info["damage"]), tree)

func _detonate(pos: Vector2, fall_damage: float, tree: SceneTree) -> void:
	var im := get_node_or_null("/root/ItemManager")
	var radius: float = BLAST_RADIUS * ExplosionModifiers.radius_mult()
	var dmg: float = maxf(fall_damage * BLAST_DAMAGE_RATIO, BLAST_MIN_DAMAGE) * ExplosionModifiers.damage_mult()
	var elements: Array = im.get_active_elements() if im else []
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead" or not node.has_method("take_damage"):
			continue
		if pos.distance_to(node.global_position) > radius:
			continue
		node.take_damage(dmg, 150.0, 60.0, true)
		for element in elements:
			im.apply_element_to_enemy(node, element)
	if tree.current_scene:
		var ring := Node2D.new()
		ring.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(ring)
		ring.setup(pos, radius, RING_COLOR)
	ExplosionModifiers.announce(pos, radius)
