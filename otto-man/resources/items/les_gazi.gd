# UNCOMMON - Elit düşman cesedine vurunca zehirli gaz bulutu patlar
extends ItemEffect

func _init():
	item_id = "les_gazi"
	item_name = "Leş Gazı"
	description = "Elit düşman cesedine vurunca zehirli gaz bulutu patlar"
	flavor_text = "Ölüm bile bir silahtır"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.SPECIAL
	affected_stats = ["corpse_gas"]

# Ceset spawn'ı ItemManager._try_spawn_elite_corpse() içinde, davranışı
# effects/elite_corpse.gd içinde kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Leş Gazı] ✅ Elit cesetlere vuruş zehirli gaz çıkarır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Leş Gazı] ❌ Kaldırıldı")
