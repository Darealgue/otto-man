# RARE - Cevher Dili / Yıkım Mührü staminadan yoksun kalırsa, bedel candan kesilerek devam eder
# Önkoşul (VEYA): cevher_dili veya yikim_muhru (ITEM_REQUIREMENTS_ANY)
extends ItemEffect

func _init():
	item_id = "kan_bedeli"
	item_name = "Kan Bedeli"
	description = "Stamina bittiğinde, güç asla reddedilmez — bedel candan kesilir"
	flavor_text = "Nefesin bitse de kanın akar"
	rarity = ItemRarity.RARE
	category = ItemCategory.STAMINA
	affected_stats = ["stamina_health_fallback"]

# Davranış Cevher Dili / Yıkım Mührü item script'lerinde kontrol edilir. Bu item pasif bir işarettir.

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Kan Bedeli] ✅ Stamina bitince bedel candan kesilir")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Kan Bedeli] ❌ Kaldırıldı")
