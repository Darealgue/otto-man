# RARE - Zindan tuzakları (ateş, diken, zehir) artık düşmanlara da hasar verir
extends ItemEffect

func _init():
	item_id = "tuzak_fisildayan"
	item_name = tr("item.tuzak_fisildayan.name")
	description = tr("item.tuzak_fisildayan.description")
	flavor_text = "Taş da, ateş de senin dilinden anlar"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["traps_hurt_enemies"]

# Davranış traps_v2/trap_enemy_damage.gd üzerinden her tuzak script'inde kontrol edilir
# (TrapEnemyDamage.is_active()). Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Tuzak Fısıldayan] ✅ Tuzaklar düşmanlara da hasar veriyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Tuzak Fısıldayan] ❌ Kaldırıldı")
