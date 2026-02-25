# RARE - Light attack vurduğunda yakındaki diğer düşmanlara %40 hasar (cleave)
extends ItemEffect

const CLEAVE_RADIUS := 85.0
const CLEAVE_RATIO := 0.4
var _player: CharacterBody2D = null

func _init():
	item_id = "genis_darbe"
	item_name = "Geniş Darbe"
	description = "Light attack vurduğunda yakındaki düşmanlara %40 hasar"
	flavor_text = "Geniş kavis"
	rarity = ItemRarity.RARE
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["light_attack_cleave"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Geniş Darbe] ✅ Light attack cleave")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Geniş Darbe] ❌ Kaldırıldı")

func _on_player_attack_landed(attack_type: String, damage: float, targets: Array, position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter == "elemental_only":
		return  # Karagöz gölgesi: sadece fiziksel; geniş darbe uygulanmasın
	if not _player or attack_type != "normal":
		return
	if targets.is_empty():
		return
	var tree = _player.get_tree()
	if not tree:
		return
	var cleave_damage = damage * CLEAVE_RATIO
	var hit_ids: Array[int] = []
	for t in targets:
		if is_instance_valid(t):
			var n = t if t.has_method("take_damage") else (t.get_parent() if t.get_parent() and t.get_parent().has_method("take_damage") else null)
			if n:
				hit_ids.append(n.get_instance_id())
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if node.get_instance_id() in hit_ids:
			continue
		if position.distance_to(node.global_position) <= CLEAVE_RADIUS and node.has_method("take_damage"):
			node.take_damage(cleave_damage, 40.0, -30.0, true)
