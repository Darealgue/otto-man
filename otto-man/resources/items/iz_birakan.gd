# iz_birakan.gd
# RARE - Dodge/dash'in geçtiği yol, dodge biter bitmez bir hasar taraması yapar
# (yol boyunca birkaç noktada). Davranış ItemManager.apply_movement_trail_if_active()
# içinde kontrol edilir, bu item pasif bir işarettir.

extends ItemEffect

func _init():
	item_id = "iz_birakan"
	item_name = tr("item.iz_birakan.name")
	description = tr("item.iz_birakan.description")
	flavor_text = "Geçtiğin yer boş kalmaz"
	rarity = ItemRarity.RARE
	category = ItemCategory.DODGE
	affected_stats = ["dodge_trail_damage"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[İz Bırakan] ✅ Dodge/dash yolu hasar veriyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[İz Bırakan] ❌ Kaldırıldı")
