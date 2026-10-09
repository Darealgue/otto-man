# gercek_golge.gd
# RARE - Gölgelerin saldırıları ve mermileri yarım değil TAM hasarla taklit edilir. Oranı gölge
# vururken ItemManager okur (get_shadow_damage_ratio), item pasif bir işarettir.

extends ItemEffect

const DAMAGE_RATIO := 1.0

func _init():
	item_id = "gercek_golge"
	item_name = tr("item.gercek_golge.name")
	description = tr("item.gercek_golge.description")
	flavor_text = "Gölge de senin kadar gerçek"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["shadow_damage"]

func get_shadow_damage_ratio() -> float:
	return DAMAGE_RATIO
