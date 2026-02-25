# kalkan_ustasi.gd
# COMMON item - Block %90 hasar engeller (normal %50 yerine)

extends ItemEffect

const BLOCK_DAMAGE_REDUCTION = 0.9  # 90% damage reduction

func _init():
	item_id = "kalkan_ustasi"
	item_name = "Kalkan Ustası"
	description = "Block %90 hasar engeller"
	flavor_text = "Güçlü savunma"
	rarity = ItemRarity.COMMON
	category = ItemCategory.BLOCK
	affected_stats = ["block_damage_reduction"]

func activate(player: CharacterBody2D):
	super.activate(player)
	
	# Set block damage reduction to 90%
	var block_state = player.get_node_or_null("StateMachine/Block")
	if block_state:
		if not block_state.has_meta("original_block_reduction"):
			block_state.set_meta("original_block_reduction", block_state.BLOCK_DAMAGE_REDUCTION)
		block_state.BLOCK_DAMAGE_REDUCTION = BLOCK_DAMAGE_REDUCTION
		print("[Kalkan Ustası] ✅ Block %90 hasar engeller")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	
	var block_state = player.get_node_or_null("StateMachine/Block")
	if block_state and block_state.has_meta("original_block_reduction"):
		block_state.BLOCK_DAMAGE_REDUCTION = block_state.get_meta("original_block_reduction")
		block_state.remove_meta("original_block_reduction")
		print("[Kalkan Ustası] ❌ Block eski haline döndü (%50)")
