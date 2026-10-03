# zincirleme_vurus.gd
# RARE - Bir vuruş bir düşmanı öldürürse, 60px içindeki başka bir düşman da
# hemen hasar alır — art arda duran düşmanları zincirleme biçebilirsin.

extends ItemEffect

const CHAIN_RADIUS := 60.0
const CHAIN_DAMAGE := 8.0
const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const IMPACT_COLOR := Color(1.0, 0.9, 0.6, 0.8)

var _player: CharacterBody2D = null

func _init():
	item_id = "zincirleme_vurus"
	item_name = tr("item.zincirleme_vurus.name")
	description = tr("item.zincirleme_vurus.description")
	flavor_text = "Biri düşerse yanındaki de düşer"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["kill_chain_target"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Zincirleme Vuruş] ✅ Öldürme yakındaki düşmana da sıçrar")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Zincirleme Vuruş] ❌ Kaldırıldı")

func on_enemy_killed(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	var tree = get_tree()
	if not tree:
		return
	var origin: Vector2 = enemy.global_position
	var nearest: Node2D = null
	var nearest_dist := CHAIN_RADIUS
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node == enemy:
			continue
		if node.get("current_behavior") == "dead":
			continue
		if not node.has_method("take_damage"):
			continue
		var d: float = origin.distance_to(node.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = node
	if nearest:
		nearest.take_damage(CHAIN_DAMAGE, 0.0, 0.0, true)
		if tree.current_scene:
			var burst = Node2D.new()
			burst.set_script(_AoeBurstRingScript)
			tree.current_scene.add_child(burst)
			burst.setup(origin, CHAIN_RADIUS, IMPACT_COLOR)
