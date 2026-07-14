# LEGENDARY - Her 4. isabetli vuruşta (3+ farklı element item'ın varsa), aktif elementlerden
# rastgele biri 3 kat güçte bir alan patlaması tetikler.
extends ItemEffect

const TRIGGER_EVERY := 4
const DAMAGE_MULT := 3.0
const AOE_RADIUS := 90.0

var _player: CharacterBody2D = null
var _hit_counter := 0

func _init():
	item_id = "element_degisimi"
	item_name = "Element Değişimi"
	description = "Her 4. vuruşta aktif elementlerinden biri 3 kat güçte patlar"
	flavor_text = "Hiçbir element yalnız kalmaz"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.SYNERGY
	affected_stats = ["element_combo_burst"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_hit_counter = 0
	print("[Element Değişimi] ✅ Her 4. vuruşta element patlaması")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Element Değişimi] ❌ Kaldırıldı")

func _on_player_attack_landed(_attack_type: String, damage: float, _targets: Array, position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter == "physical_only" or not is_instance_valid(_player):
		return
	_hit_counter += 1
	if _hit_counter < TRIGGER_EVERY:
		return
	_hit_counter = 0
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return
	var elements: Array[String] = []
	if im.has_active_item("zehirli_tirnak") or im.has_active_item("zehirli_dev"):
		elements.append("poison")
	if im.has_active_item("atesli_yumruk") or im.has_active_item("lav_cekici"):
		elements.append("fire")
	if im.has_active_item("buzlu_kilic") or im.has_active_item("donma_cekici"):
		elements.append("frost")
	if im.has_active_item("simsek_parmagi") or im.has_active_item("gok_gurultusu"):
		elements.append("lightning")
	if elements.size() < 2:
		return
	var picked: String = elements[randi() % elements.size()]
	_trigger_explosion(position, damage, picked)

func _trigger_explosion(position: Vector2, base_damage: float, element: String) -> void:
	var tree = _player.get_tree()
	if not tree:
		return
	var dmg: float = base_damage * DAMAGE_MULT
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if position.distance_to(node.global_position) > AOE_RADIUS:
			continue
		if node.has_method("take_damage"):
			node.take_damage(dmg, 150.0, 100.0, true)
		match element:
			"poison":
				if node.has_method("add_poison_stack"):
					node.add_poison_stack(5, 2.0, 1.0)
			"fire":
				if node.has_method("add_burn_stack"):
					node.add_burn_stack()
			"frost":
				if node.has_method("add_frost_stack"):
					node.add_frost_stack(3)
