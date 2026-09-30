# agir_mermi.gd
# COMMON - Mermiler artık fırlatma da verir (Uzun Menzil/Ok Yağmuru'nun
# sildiği knockback'i opsiyonel geri getirir).
# Önkoşul (VEYA): uzun_menzil veya ok_yagmuru (ITEM_REQUIREMENTS_ANY)
# Etki ItemManager.spawn_upgraded_projectile()'da uygulanır (light_attack_projectile.gd'nin
# knockback_force/knockback_up_force alanları) — bu item pasif bir işarettir.

extends ItemEffect

func _init():
	item_id = "agir_mermi"
	item_name = tr("item.agir_mermi.name")
	description = tr("item.agir_mermi.description")
	flavor_text = "Hafif bir ok değil, bir yumruk"
	rarity = ItemRarity.COMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["projectile_knockback"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Ağır Mermi] ✅ Mermiler artık fırlatma da veriyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Ağır Mermi] ❌ Kaldırıldı")
