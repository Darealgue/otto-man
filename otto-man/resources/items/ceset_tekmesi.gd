# UNCOMMON - Dodge ile elit düşman cesedinin içinden geçince ceset fırlar, ilk çarptığı düşmana hasar verir
extends ItemEffect

func _init():
	item_id = "ceset_tekmesi"
	item_name = tr("item.ceset_tekmesi.name")
	description = tr("item.ceset_tekmesi.description")
	flavor_text = "Ölü de olsa bir işe yarasın"
	category = ItemCategory.DODGE
	affected_stats = ["corpse_kick"]

# Ceset spawn'ı ItemManager._try_spawn_elite_corpse() içinde, davranışı
# effects/elite_corpse.gd içinde kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
