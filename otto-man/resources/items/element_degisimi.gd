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
	item_name = tr("item.element_degisimi.name")
	description = tr("item.element_degisimi.description")
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
	# Merkezi tag registry (bkz. docs/ITEM_SYNERGY_DESIGN.md §10) — element
	# üreten item'lardan otomatik türer, elle ID listesi tutmaya gerek yok.
	var elements: Array[String] = im.get_active_elements()
	if elements.size() < 2:
		return
	var picked: String = elements[randi() % elements.size()]
	_trigger_explosion(position, damage, picked, im)

func _trigger_explosion(position: Vector2, base_damage: float, element: String, im) -> void:
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
		# "lightning" dahil dört element de artık tek yerden uygulanıyor —
		# önceki match bloğunda şimşek case'i unutulmuştu, bu yüzden şimşek
		# seçildiğinde patlamanın elemental kısmı hiç uygulanmıyordu.
		im.apply_element_to_enemy(node, element)
