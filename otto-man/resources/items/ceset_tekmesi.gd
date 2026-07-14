# UNCOMMON - Dodge ile elit düşman cesedinin içinden geçince ceset fırlar, ilk çarptığı düşmana hasar verir
extends ItemEffect

func _init():
	item_id = "ceset_tekmesi"
	item_name = "Ceset Tekmesi"
	description = "Dodge ile cesedin içinden geçince ceset fırlar, çarptığı düşmana hasar verir"
	flavor_text = "Ölü de olsa bir işe yarasın"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = ["corpse_kick"]

# Ceset spawn'ı ItemManager._try_spawn_elite_corpse() içinde, davranışı
# effects/elite_corpse.gd içinde kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Ceset Tekmesi] ✅ Dodge ile cesetleri tekmeleyebilirsin")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Ceset Tekmesi] ❌ Kaldırıldı")
