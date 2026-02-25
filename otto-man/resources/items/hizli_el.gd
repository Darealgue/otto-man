# hizli_el.gd
# COMMON item - Light attack speed +25%

extends ItemEffect

const SPEED_BOOST = 0.25  # +25% attack speed

func _init():
	item_id = "hizli_el"
	item_name = "Hızlı El"
	description = "Light attack hızı +%25"
	flavor_text = "Daha hızlı vuruşlar"
	rarity = ItemRarity.COMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["attack_speed"]

func activate(player: CharacterBody2D):
	super.activate(player)
	
	# Modify attack_state's ANIMATION_SPEED
	var attack_state = player.get_node_or_null("StateMachine/Attack")
	if attack_state:
		# Store original value if not already stored
		if not attack_state.has_meta("original_animation_speed"):
			attack_state.set_meta("original_animation_speed", attack_state.DEFAULT_ANIMATION_SPEED)
		
		# Increase animation speed
		var original_speed = attack_state.get_meta("original_animation_speed")
		attack_state.ANIMATION_SPEED = original_speed * (1.0 + SPEED_BOOST)
		print("[Hızlı El] ✅ Attack speed +25%")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	
	var attack_state = player.get_node_or_null("StateMachine/Attack")
	if attack_state and attack_state.has_meta("original_animation_speed"):
		attack_state.ANIMATION_SPEED = attack_state.get_meta("original_animation_speed")
		attack_state.remove_meta("original_animation_speed")
		print("[Hızlı El] ❌ Attack speed restored")
