# suru_oku.gd
# RARE - Mermiler artık 3'e ayrılır (dar bir yelpaze), her biri %40 hasar.
# Önkoşul (VEYA): uzun_menzil veya ok_yagmuru (ITEM_REQUIREMENTS_ANY)
# Etki ItemManager.spawn_upgraded_projectile()'da uygulanır — bu item pasif
# bir işarettir, diğer mermi item'ları has_active_item ile kontrol eder.

extends ItemEffect

func _init():
	item_id = "suru_oku"
	item_name = tr("item.suru_oku.name")
	description = tr("item.suru_oku.description")
	flavor_text = "Tek ok değil, bir sürü"
	rarity = ItemRarity.RARE
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["projectile_split"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Sürü Oku] ✅ Mermiler 3'e ayrılıyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Sürü Oku] ❌ Kaldırıldı")
