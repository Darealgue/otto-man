# combo_ustasi.gd
# COMMON item - Combo hasarı +20%

extends ItemEffect

const DAMAGE_BOOST = 0.2  # +20% combo damage

func _init():
	item_id = "combo_ustasi"
	item_name = "Combo Ustası"
	description = "Combo hasarı +%20"
	flavor_text = "Kombo gücü"
	rarity = ItemRarity.COMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["combo_damage"]

func activate(player: CharacterBody2D):
	super.activate(player)
	
	# Apply light attack damage bonus on player (used by all light attack states)
	if "light_attack_damage_multiplier" in player:
		player.light_attack_damage_multiplier = 1.0 + DAMAGE_BOOST
		print("[Combo Ustası] ✅ Combo hasarı +20%")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	
	if "light_attack_damage_multiplier" in player:
		player.light_attack_damage_multiplier = 1.0
		print("[Combo Ustası] ❌ Combo hasarı restored")
