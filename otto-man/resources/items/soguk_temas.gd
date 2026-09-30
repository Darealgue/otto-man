# soguk_temas.gd
# COMMON - Dodge/dash sırasında temas ettiğin düşmanlar hafifçe donar (1 frost
# stack). Element item'ın olmasa bile çalışır — Kaçınma boru hattının öğretmen
# item'ı. Davranış ItemManager.apply_movement_contact_tick() içinde kontrol
# edilir, bu item pasif bir işarettir.

extends ItemEffect

func _init():
	item_id = "soguk_temas"
	item_name = tr("item.soguk_temas.name")
	description = tr("item.soguk_temas.description")
	flavor_text = "Değdiği yer üşür"
	rarity = ItemRarity.COMMON
	category = ItemCategory.DODGE
	affected_stats = ["dodge_frost"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Soğuk Temas] ✅ Dodge/dash temas ettiği düşmanları donduruyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Soğuk Temas] ❌ Kaldırıldı")
