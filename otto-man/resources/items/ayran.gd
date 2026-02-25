# ayran.gd
# COMMON item - Stamina regen +30%

extends ItemEffect

const REGEN_BOOST = 0.5  # +50% faster regen

func _init():
	item_id = "ayran"
	item_name = "Ayran"
	description = "Stamina regen +%50"
	flavor_text = "Serinletici ve ferahlatıcı"
	rarity = ItemRarity.COMMON
	category = ItemCategory.STAMINA
	affected_stats = ["stamina_regen"]

func activate(player: CharacterBody2D):
	super.activate(player)
	
	# Increase stamina regen speed (reduce recharge time)
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar:
		# Store original value if not already stored
		if not stamina_bar.has_meta("original_recharge_rate"):
			stamina_bar.set_meta("original_recharge_rate", stamina_bar.DEFAULT_RECHARGE_RATE)
		
		# Reduce recharge time (faster regen)
		# Apply multiplier to current rate (stack with other regen items)
		var current_rate = stamina_bar.RECHARGE_RATE
		stamina_bar.RECHARGE_RATE = current_rate / (1.0 + REGEN_BOOST)
		print("[Ayran] ✅ Stamina regen +50%")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar and stamina_bar.has_meta("original_recharge_rate"):
		# Restore to original rate (other items will reapply their bonuses)
		var original_rate = stamina_bar.get_meta("original_recharge_rate")
		stamina_bar.RECHARGE_RATE = original_rate
		# Reapply other regen bonuses if any
		if stamina_bar.has_meta("original_recharge_rate_simit"):
			stamina_bar.RECHARGE_RATE = stamina_bar.RECHARGE_RATE / 1.2  # Simit's boost
		stamina_bar.remove_meta("original_recharge_rate")
		print("[Ayran] ❌ Stamina regen restored")
