# uzayan_golge.gd
# UNCOMMON - Bıraktığın gölgeler 2 kat uzun süre kalır. Süreyi gölge doğarken ItemManager okur
# (get_shadow_lifetime_mult), item pasif bir işarettir.

extends ItemEffect

const LIFETIME_MULT := 2.0

func _init():
	item_id = "uzayan_golge"
	item_name = tr("item.uzayan_golge.name")
	description = tr("item.uzayan_golge.description")
	flavor_text = "Akşam olunca gölgeler uzar"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.SPECIAL
	affected_stats = ["shadow_lifetime"]

func get_shadow_lifetime_mult() -> float:
	return LIFETIME_MULT
