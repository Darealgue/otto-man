# zehir_delirmesi.gd
# LEGENDARY - Zehir katmanları sonuna kadar dolan düşmanın aklı karışır: 3 sn oyuncuyu bırakıp en
# yakın başka düşmana yürür ve ona vurur. Düşman başına 8 sn bekleme. Boss ve miniboss etkilenmez.
# Hedef değişimi base_enemy.gd (start_delirium / get_nearest_player), vuruş hasarı burada.

extends ItemEffect

const DELIRIUM_DURATION := 3.0
const DELIRIUM_COOLDOWN := 8.0
const HIT_RANGE := 90.0
const HIT_INTERVAL := 0.8
const HIT_DAMAGE := 8.0
const POLL_INTERVAL := 0.1
const COOLDOWN_META := "zehir_delirmesi_ready_at"
const NEXT_HIT_META := "zehir_delirmesi_next_hit"

var _poll_left: float = 0.0

func _init():
	item_id = "zehir_delirmesi"
	item_name = tr("item.zehir_delirmesi.name")
	description = tr("item.zehir_delirmesi.description")
	flavor_text = "Zehir aklı da yer"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["poison_madness"]

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
	var max_stacks: int = im.get_poison_max_stacks()
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if not node.has_method("is_delirious"):
			continue
		if node.is_delirious():
			_delirium_hit(node, im, now)
		elif node.get("poison_stacks") != null and int(node.poison_stacks) >= max_stacks and _can_go_mad(node, now):
			node.start_delirium(DELIRIUM_DURATION)
			node.set_meta(COOLDOWN_META, now + int((DELIRIUM_DURATION + DELIRIUM_COOLDOWN) * 1000.0))
			node.set_meta(NEXT_HIT_META, now)
			im.spawn_element_hit_flash(node, "poison")

func _can_go_mad(node: Node, now: int) -> bool:
	if node.has_meta(COOLDOWN_META) and int(node.get_meta(COOLDOWN_META)) > now:
		return false
	var path := ""
	if node.get_script() != null:
		path = String(node.get_script().resource_path)
	return not (path.contains("boss") or path.contains("miniboss"))

func _delirium_hit(madman: Node, im: Node, now: int) -> void:
	if madman.has_meta(NEXT_HIT_META) and int(madman.get_meta(NEXT_HIT_META)) > now:
		return
	var tree := get_tree()
	var victim: Node2D = null
	var best := HIT_RANGE
	for node in tree.get_nodes_in_group("enemies"):
		if node == madman or not is_instance_valid(node) or not (node is Node2D):
			continue
		if node.get("current_behavior") == "dead" or not node.has_method("take_damage"):
			continue
		var d: float = madman.global_position.distance_to((node as Node2D).global_position)
		if d < best:
			best = d
			victim = node as Node2D
	if victim == null:
		return
	madman.set_meta(NEXT_HIT_META, now + int(HIT_INTERVAL * 1000.0))
	victim.take_damage(HIT_DAMAGE, 150.0, 60.0, true)
	im.spawn_element_hit_flash(victim, "poison")
