# RARE - Sonraki item seçeneklerinden biri, aktif item'larınla aynı kategoriden gelme eğilimi kazanır
extends ItemEffect

func _init():
	item_id = "falci_kadin"
	item_name = tr("item.falci_kadin.name")
	description = tr("item.falci_kadin.description")
	flavor_text = "Fal, kader değil ihtimaldir"
	category = ItemCategory.SYNERGY
	affected_stats = ["item_pool_weighting"]

# Davranış ItemManager.get_random_items() içinde kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
