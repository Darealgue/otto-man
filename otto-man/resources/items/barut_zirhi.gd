# RARE - Patlama kaynaklı tüm hasara %100 bağışıklık (kendi patlayıcı itemlerin dahil)
extends ItemEffect

func _init():
	item_id = "barut_zirhi"
	item_name = "Barut Zırhı"
	description = "Patlama kaynaklı tüm hasara bağışıklık"
	flavor_text = "Kendi ateşin seni yakmaz"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["explosion_immunity"]

# Davranış effects/explosion_modifiers.gd üzerinden tüm patlama efektlerinde kontrol edilir
# (ExplosionModifiers.player_immune_to_explosions()). Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Barut Zırhı] ✅ Patlamalara bağışıklık")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Barut Zırhı] ❌ Kaldırıldı")
