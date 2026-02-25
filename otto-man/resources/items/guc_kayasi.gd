# guc_kayasi.gd
# COMMON item - Heavy attack hasarı +30%

extends ItemEffect

const DAMAGE_BOOST = 0.3

func _init():
	item_id = "guc_kayasi"
	item_name = "Güç Kayası"
	description = "Heavy attack hasarı +%30"
	flavor_text = "Daha güçlü vuruş"
	rarity = ItemRarity.COMMON
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_damage"]

func activate(player: CharacterBody2D):
	super.activate(player)
	if "heavy_attack_damage_multiplier" in player:
		player.heavy_attack_damage_multiplier = 1.0 + DAMAGE_BOOST
		print("[Güç Kayası] ✅ Heavy attack hasarı +30%")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if "heavy_attack_damage_multiplier" in player:
		player.heavy_attack_damage_multiplier = 1.0
		print("[Güç Kayası] ❌ Heavy attack eski haline döndü")
