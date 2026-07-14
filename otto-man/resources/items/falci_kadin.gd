# RARE - Sonraki item seçeneklerinden biri, aktif item'larınla aynı kategoriden gelme eğilimi kazanır
extends ItemEffect

func _init():
	item_id = "falci_kadin"
	item_name = "Falcı Kadın"
	description = "İtem seçeneklerinden biri build'ine yakın kategoriden gelme eğilimi kazanır"
	flavor_text = "Fal, kader değil ihtimaldir"
	rarity = ItemRarity.RARE
	category = ItemCategory.SYNERGY
	affected_stats = ["item_pool_weighting"]

# Davranış ItemManager.get_random_items() içinde kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Falcı Kadın] ✅ Seçenekler build'ine yöneliyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Falcı Kadın] ❌ Kaldırıldı")
