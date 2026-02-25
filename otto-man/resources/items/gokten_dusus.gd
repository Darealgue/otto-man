# gokten_dusus.gd
# COMMON item - Fall attack hasarı +30%

extends ItemEffect

const DAMAGE_BOOST = 0.3

func _init():
	item_id = "gokten_dusus"
	item_name = "Gökten Düşüş"
	description = "Fall attack hasarı +%30"
	flavor_text = "Daha güçlü düşüş"
	rarity = ItemRarity.COMMON
	category = ItemCategory.FALL_ATTACK
	affected_stats = ["fall_attack_damage"]

func activate(player: CharacterBody2D):
	super.activate(player)
	player.fall_attack_damage_multiplier = 1.0 + DAMAGE_BOOST
	print("[Gökten Düşüş] ✅ Fall attack hasarı +30% (multiplier: ", player.fall_attack_damage_multiplier, ")")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	player.fall_attack_damage_multiplier = 1.0
	print("[Gökten Düşüş] ❌ Fall attack eski haline döndü")
