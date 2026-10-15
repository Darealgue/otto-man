# kavis_adimi.gd
# UNCOMMON - Dodge/dash'in temas alanı genişler (yarıçap %60 artar). Davranış
# ItemManager.get_movement_contact_radius() içinde kontrol edilir, bu item
# pasif bir işarettir.

extends ItemEffect

func _init():
	item_id = "kavis_adimi"
	item_name = tr("item.kavis_adimi.name")
	description = tr("item.kavis_adimi.description")
	flavor_text = "Geniş bir yay çizer"
	category = ItemCategory.DODGE
	affected_stats = ["dodge_contact_radius"]

func activate(player: CharacterBody2D):
	super.activate(player)

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
