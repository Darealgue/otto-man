# bulasici_darbe.gd
# RARE - Havadaki zehirli düşmana yapılan her vuruş, yakındaki en fazla 3 düşmana birer zehir katmanı
# bulaştırır. Havaya Fırlatma hattının zehir köprüsü (Zıplatan Yumruk, Toplu Kaldırma ile birleşir).

extends ItemEffect

const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const SPREAD_RADIUS := 140.0   # yatay erişim
const MAX_VERTICAL := 280.0    # dikey erişim: juggle'daki düşmanın altındaki yer düşmanları da kapsansın
const MAX_TARGETS := 3
const RING_COLOR := Color(0.45, 0.95, 0.35, 0.8)
const COOLDOWN_MSEC := 250
const COOLDOWN_META := "bulasici_darbe_until"

func _init():
	item_id = "bulasici_darbe"
	item_name = tr("item.bulasici_darbe.name")
	description = tr("item.bulasici_darbe.description")
	flavor_text = "Havada saçılan zehir"
	rarity = ItemRarity.RARE
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["air_poison_spread"]

func _on_player_attack_landed(_attack_type: String, _damage: float, targets: Array, _position: Vector2, _effect_filter: String = "all") -> void:
	var im := get_node_or_null("/root/ItemManager")
	var tree := get_tree()
	if im == null or tree == null:
		return
	var now := Time.get_ticks_msec()
	for target in targets:
		var enemy := resolve_enemy_target(target)
		if enemy == null or enemy.get("poison_stacks") == null or int(enemy.poison_stacks) <= 0:
			continue
		if enemy.has_method("is_on_floor") and enemy.is_on_floor():
			continue
		if enemy.has_meta(COOLDOWN_META) and int(enemy.get_meta(COOLDOWN_META)) > now:
			continue
		enemy.set_meta(COOLDOWN_META, now + COOLDOWN_MSEC)
		_spread_from(enemy, im, tree)

func _spread_from(source: Node, im: Node, tree: SceneTree) -> void:
	var candidates: Array = []
	for node in tree.get_nodes_in_group("enemies"):
		if node == source or not is_live_enemy(node):
			continue
		if not node.has_method("add_poison_stack"):
			continue
		# Juggle'da kaynak düşman yerden 100-250 px yukarıdadır; komşular altta, yerdedir. Daire yarıçapı
		# bunları kaçırıyordu (arena testi yakaladı): yatay mesafe SPREAD_RADIUS, dikey MAX_VERTICAL.
		var offset: Vector2 = node.global_position - source.global_position
		if absf(offset.x) <= SPREAD_RADIUS and absf(offset.y) <= MAX_VERTICAL:
			candidates.append({"node": node, "d": absf(offset.x) + absf(offset.y) * 0.5})
	candidates.sort_custom(func(a, b): return a["d"] < b["d"])
	for i in range(mini(MAX_TARGETS, candidates.size())):
		im.add_poison_stacks(candidates[i]["node"], 1)
	if tree.current_scene:
		var ring := Node2D.new()
		ring.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(ring)
		ring.setup(source.global_position, SPREAD_RADIUS, RING_COLOR)
