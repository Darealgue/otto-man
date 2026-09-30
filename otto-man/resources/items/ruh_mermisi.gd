# ruh_mermisi.gd
# LEGENDARY - Bir mermi bir düşmanı öldürürse, anında en yakın başka düşmana
# yönelip yoluna devam eder — ölüm zincirledikçe mermi hiç durmaz.
# Önkoşul (VEYA): uzun_menzil veya ok_yagmuru (ITEM_REQUIREMENTS_ANY)
# Etki ItemManager.spawn_upgraded_projectile()'da uygulanır (light_attack_projectile.gd'nin
# soul_chain alanı) — bu item pasif bir işarettir.

extends ItemEffect

func _init():
	item_id = "ruh_mermisi"
	item_name = tr("item.ruh_mermisi.name")
	description = tr("item.ruh_mermisi.description")
	flavor_text = "Bir can biter, mermi bitmez"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["projectile_soul_chain"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Ruh Mermisi] ✅ Öldüren mermi bir sonraki hedefe geçiyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Ruh Mermisi] ❌ Kaldırıldı")
