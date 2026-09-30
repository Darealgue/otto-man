# alan_parrysi.gd
# RARE - Perfect parry, sadece saldırganı değil 100px içindeki HERKESİ de
# sersemletir (kısa süreli stagger + küçük hasar).

extends ItemEffect

const AREA_RADIUS := 100.0
const AREA_DAMAGE := 5.0

var _player: CharacterBody2D = null

func _init():
	item_id = "alan_parrysi"
	item_name = tr("item.alan_parrysi.name")
	description = tr("item.alan_parrysi.description")
	flavor_text = "Parry tek bir düşmanla sınırlı değil"
	rarity = ItemRarity.RARE
	category = ItemCategory.PARRY
	affected_stats = ["parry_area"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("perfect_parry"):
		if not player.is_connected("perfect_parry", _on_perfect_parry):
			player.connect("perfect_parry", _on_perfect_parry)
	print("[Alan Parry'si] ✅ Perfect parry alan etkili oldu")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("perfect_parry"):
		if _player.is_connected("perfect_parry", _on_perfect_parry):
			_player.disconnect("perfect_parry", _on_perfect_parry)
	_player = null
	print("[Alan Parry'si] ❌ Kaldırıldı")

func _on_perfect_parry() -> void:
	if not is_instance_valid(_player):
		return
	var tree = get_tree()
	if not tree:
		return
	var im = get_node_or_null("/root/ItemManager")
	var specialist_mult: float = im.get_specialist_multiplier("savunma") if im else 1.0
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if _player.global_position.distance_to(node.global_position) > AREA_RADIUS:
			continue
		if node.has_method("take_damage"):
			node.take_damage(AREA_DAMAGE * specialist_mult, 120.0, 80.0, true)
