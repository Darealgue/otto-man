# RARE - Perfect parry sonrası eğilme tuşu, parrylenen düşmanın arkasına ışınlar
extends ItemEffect

func _init():
	item_id = "golge_adimi"
	item_name = tr("item.golge_adimi.name")
	description = tr("item.golge_adimi.description")
	flavor_text = "Gölgeler asla önden gelmez"
	category = ItemCategory.PARRY
	affected_stats = ["parry_teleport"]

# Davranış player/states/combat/block_state.gd içinde kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
