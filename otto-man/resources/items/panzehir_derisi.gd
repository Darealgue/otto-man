# RARE - Zehir tuzaklarına ve tüm zehir bulutlarına %100 bağışıklık
extends ItemEffect

func _init():
	item_id = "panzehir_derisi"
	item_name = tr("item.panzehir_derisi.name")
	description = tr("item.panzehir_derisi.description")
	flavor_text = "Zehir artık sana su gibi gelir"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["poison_immunity"]

# Davranış player/status_effects/status_effect_manager.gd::apply_poison() içinde kontrol edilir.
# Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Panzehir Derisi] ✅ Zehire bağışıklık")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Panzehir Derisi] ❌ Kaldırıldı")
