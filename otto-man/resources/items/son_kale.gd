# RARE - Blok sırasında stamina biterse gard kırılması yerine şok dalgası patlar
extends ItemEffect

func _init():
	item_id = "son_kale"
	item_name = "Son Kale"
	description = "Blok sırasında stamina biterse gard kırılması yerine şok dalgası patlar"
	flavor_text = "Duvar yıkılınca gürler"
	rarity = ItemRarity.RARE
	category = ItemCategory.BLOCK
	affected_stats = ["guard_break_shockwave"]

# Davranış player/states/combat/block_state.gd::_on_stamina_depleted_son_kale() içinde
# kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Son Kale] ✅ Gard kırılması artık şok dalgası")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Son Kale] ❌ Kaldırıldı")
