# zehirli_sekme.gd
# RARE - Dodge/takla sırasında içinden geçtiğin her düşmana bir kez temas hasarı.
# Element sabit değil: o an aktif olan element(ler) varsa (zehir/ateş/buz/şimşek)
# onlar da uygulanır (bkz. ItemManager.get_active_elements/apply_element_to_enemy,
# docs/ITEM_SYNERGY_DESIGN.md §10). Element item'ı yoksa saf fiziksel hasar kalır.

extends ItemEffect

func _init():
	item_id = "zehirli_sekme"
	item_name = tr("item.zehirli_sekme.name")
	description = tr("item.zehirli_sekme.description")
	flavor_text = "Değdiği yerde çürüme başlar"
	rarity = ItemRarity.RARE
	category = ItemCategory.DODGE
	affected_stats = ["dodge_contact_damage"]

# Davranış player/states/dodge_state.gd içinde kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Zehirli Sekme] ✅ Dodge düşmanlara temas hasarı + aktif element(ler) verir")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Zehirli Sekme] ❌ Kaldırıldı")
