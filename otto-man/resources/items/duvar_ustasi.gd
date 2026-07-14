# RARE - Duvara temas edince bir süre yerçekimi askıya alınır (duvarda koşma hissi)
extends ItemEffect

func _init():
	item_id = "duvar_ustasi"
	item_name = "Duvar Ustası"
	description = "Duvarda bir süre yerçekimine karşı durabilirsin"
	flavor_text = "Taş da senin yolunu tutamaz"
	rarity = ItemRarity.RARE
	category = ItemCategory.WALL_SLIDE
	affected_stats = ["wall_run"]

# Davranış player/states/air/wall_slide_state.gd içinde kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Duvar Ustası] ✅ Duvarda yerçekimi askıya alınıyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Duvar Ustası] ❌ Kaldırıldı")
