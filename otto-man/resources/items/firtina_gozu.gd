# firtina_gozu.gd
# UNCOMMON - Dodge/dash temas hasarı artık gerçek bir fırlatma da veriyor
# (Kaçınma → Havaya Fırlatma köprüsü). Temas hasarının kendisi bu item'a
# bağlı değil — Zehirli Sekme veya restless_body ailesi aktifken anlamlı.
# Davranış ItemManager.apply_movement_contact_tick() içinde kontrol edilir,
# bu item pasif bir işarettir.

extends ItemEffect

func _init():
	item_id = "firtina_gozu"
	item_name = tr("item.firtina_gozu.name")
	description = tr("item.firtina_gozu.description")
	flavor_text = "Dokunduğu her şeyi havaya savurur"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = ["dodge_contact_launch"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Fırtına Gözü] ✅ Dodge/dash temas hasarı artık fırlatıyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Fırtına Gözü] ❌ Kaldırıldı")
