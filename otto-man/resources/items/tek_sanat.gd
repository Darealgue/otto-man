# tek_sanat.gd
# LEGENDARY - Uzmanı ödüllendirir. Item'ların SADECE bir boru hattına
# yığılmışsa (başka hiçbir hatta item yok) ve o hatta 5+ item varsa, o
# hattın numeric çıktısı (hasar/iade miktarı) 1.5x güçlenir. Pasif bir
# işarettir; gerçek çarpan ItemManager.get_specialist_multiplier() üzerinden
# her hattın kendi hasar/etki hesaplamasında okunur (player_hitbox.gd,
# alan_parrysi/emici_kalkan/karsi_mermi.gd, item_manager.gd'nin Kaçınma/
# Hareket/Mermi merkezi fonksiyonları). Bkz. docs/ITEM_PIPELINE_DESIGN.md §7.

extends ItemEffect

func _init():
	item_id = "tek_sanat"
	item_name = tr("item.tek_sanat.name")
	description = tr("item.tek_sanat.description")
	flavor_text = "Tek bir yolda ustalaşan, o yolda yenilmez"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.SYNERGY
	affected_stats = ["pipeline_specialist_bonus"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Tek Sanat] ✅ Tek bir boru hattına odaklanmak o hattı 1.5x güçlendiriyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Tek Sanat] ❌ Kaldırıldı")
