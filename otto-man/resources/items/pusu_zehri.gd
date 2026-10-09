# pusu_zehri.gd
# RARE - Görünmezlikten çıkış vuruşu (Görünmezlik Pelerini'nin 3x ilk vuruşu) hedefin zehir
# katmanlarını maksimuma tamamlar. Olay DamageModifiers'tan gelir (_on_stealth_opener_hit).

extends ItemEffect

func _init():
	item_id = "pusu_zehri"
	item_name = tr("item.pusu_zehri.name")
	description = tr("item.pusu_zehri.description")
	flavor_text = "Gölgeden gelen zehir"
	rarity = ItemRarity.RARE
	category = ItemCategory.DODGE
	affected_stats = ["stealth_poison"]

func _on_stealth_opener_hit(enemy: Node) -> void:
	var im := get_node_or_null("/root/ItemManager")
	if im:
		im.max_out_poison(enemy)
