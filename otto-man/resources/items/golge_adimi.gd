# RARE - Perfect parry sonrası eğilme tuşu, parrylenen düşmanın arkasına ışınlar
extends ItemEffect

func _init():
	item_id = "golge_adimi"
	item_name = "Gölge Adımı"
	description = "Parry sonrası eğilme tuşu, düşmanın arkasına ışınlar"
	flavor_text = "Gölgeler asla önden gelmez"
	rarity = ItemRarity.RARE
	category = ItemCategory.PARRY
	affected_stats = ["parry_teleport"]

# Davranış player/states/combat/block_state.gd içinde kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Gölge Adımı] ✅ Parry sonrası eğilme = ışınlanma")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Gölge Adımı] ❌ Kaldırıldı")
