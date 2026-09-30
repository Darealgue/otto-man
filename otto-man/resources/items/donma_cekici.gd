# donma_cekici.gd
# UNCOMMON - Heavy attack donma AoE (yavaşlatma + frost stack); tetiklemek 1 stamina hücresi harcar.

extends ItemEffect

const FROST_RADIUS := 100.0
const FROST_STACKS := 4
const FROST_DAMAGE := 2.0

var _player: CharacterBody2D = null

func _init():
	item_id = "donma_cekici"
	item_name = tr("item.donma_cekici.name")
	description = tr("item.donma_cekici.description")
	flavor_text = "Buz dalgası"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.HEAVY_ATTACK
	tags = ["elemental_ice"]
	affected_stats = ["heavy_frost"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Donma Çekici] ✅ Heavy attack donma AoE (1 stamina hücresi)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Donma Çekici] ❌ Kaldırıldı")

func _on_heavy_attack_impact(_attack_name: String = "") -> void:
	if not _player or not is_instance_valid(_player):
		return
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if not stamina_bar or not stamina_bar.use_charge():
		return
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var pos: Vector2 = _player.global_position + Vector2(_player.facing_direction * 45, 0)
	var hitbox = _player.get_node_or_null("Hitbox")
	if hitbox:
		var cs = hitbox.get_node_or_null("CollisionShape2D")
		if cs:
			pos = hitbox.to_global(cs.position)
	var enemies = tree.get_nodes_in_group("enemies")
	for node in enemies:
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if pos.distance_to(node.global_position) <= FROST_RADIUS:
			if node.has_method("take_damage"):
				node.take_damage(FROST_DAMAGE, 0.0, 0.0, true)
			if node.has_method("add_frost_stack"):
				node.add_frost_stack(FROST_STACKS)
