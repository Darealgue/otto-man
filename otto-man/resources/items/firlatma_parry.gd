# UNCOMMON - Perfect parry sonrası zıplama tuşu, parrylenen düşmanı havaya fırlatır (juggle)
extends ItemEffect

func _init():
	item_id = "firlatma_parry"
	item_name = tr("item.firlatma_parry.name")
	description = tr("item.firlatma_parry.description")
	flavor_text = "Yere değil, göğe savur"
	category = ItemCategory.PARRY
	affected_stats = ["parry_launch"]

# Davranış player/states/combat/block_state.gd içinde kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
