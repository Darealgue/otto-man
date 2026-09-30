# element_izi.gd
# UNCOMMON - Dodge/dash, zıplama ve slide sırasında aktif elementinin izini bırakır.
# Eskiden dört ayrı item (element_izi/dodge_zehiri/ziplama_zehiri/slide_simsegi)
# dört ayrı hareket fiiline bağlıydı, çoğu tek elemente sabitti. Artık hepsi bu
# TEK item'da birleşti (bkz. docs/ITEM_PIPELINE_DESIGN.md §8.2 madde 1).
# Davranış player/states/{dodge,dash,air/jump,ground/slide}_state.gd içinde
# ItemManager.spawn_element_trail_if_active() çağrılarak kontrol edilir — bu
# item pasif bir işarettir.

extends ItemEffect

func _init():
	item_id = "element_izi"
	item_name = tr("item.element_izi.name")
	description = tr("item.element_izi.description")
	flavor_text = "Yürüdüğün yol seni hatırlar"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = ["movement_element_trail"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Element İzi] ✅ Hareket ederken aktif elementinin izini bırakır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Element İzi] ❌ Kaldırıldı")
