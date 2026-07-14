# RARE - Dodge sırasında eğilme: dodge iptal, sahte kopya bırak, geriye ışınlan
extends ItemEffect

func _init():
	item_id = "hayalet_adim"
	item_name = "Hayalet Adım"
	description = "Dodge sırasında eğilme, sahte kopya bırakıp geriye ışınlar"
	flavor_text = "Düşman gölgeyle dövüşür"
	rarity = ItemRarity.RARE
	category = ItemCategory.DODGE
	affected_stats = ["dodge_feint"]

# Davranış player/states/dodge_state.gd içinde kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Hayalet Adım] ✅ Dodge sırasında eğilme = feint")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Hayalet Adım] ❌ Kaldırıldı")
