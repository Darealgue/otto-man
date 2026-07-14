# UNCOMMON - Tüm patlamaların yarıçapı +%30; her patlama oyuncuya %3 max can tepme hasarı verir
# (Barut Zırhı aktifse tepme hasarı da uygulanmaz)
extends ItemEffect

func _init():
	item_id = "kara_barut"
	item_name = "Kara Barut"
	description = "Patlama yarıçapı +%30, ama her patlama sana da az tepme hasarı verir"
	flavor_text = "Daha çok barut, daha çok tehlike"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.SPECIAL
	affected_stats = ["explosion_radius"]

# Davranış effects/explosion_modifiers.gd üzerinden kontrol edilir
# (ExplosionModifiers.radius_mult() / apply_recoil()). Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Kara Barut] ✅ Patlama yarıçapı +%30")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Kara Barut] ❌ Kaldırıldı")
