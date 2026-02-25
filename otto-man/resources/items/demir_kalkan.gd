# demir_kalkan.gd
# COMMON item - Block hasar azaltma %50 → %90

extends ItemEffect

const DAMAGE_REDUCTION_BOOST = 0.9  # %90 hasar azaltma

func _init():
	item_id = "demir_kalkan"
	item_name = "Demir Kalkan"
	description = "Block hasar azaltma %90"
	flavor_text = "Güçlü savunma"
	rarity = ItemRarity.COMMON
	category = ItemCategory.BLOCK
	affected_stats = ["block_damage_reduction"]

func activate(player: CharacterBody2D):
	super.activate(player)
	var block_state = player.get_node_or_null("StateMachine/Block")
	if block_state:
		if not block_state.has_meta("original_block_damage_reduction"):
			block_state.set_meta("original_block_damage_reduction", block_state.DEFAULT_BLOCK_DAMAGE_REDUCTION)
		block_state.BLOCK_DAMAGE_REDUCTION = DAMAGE_REDUCTION_BOOST
		print("[Demir Kalkan] ✅ Block hasar azaltma %90")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	var block_state = player.get_node_or_null("StateMachine/Block")
	if block_state and block_state.has_meta("original_block_damage_reduction"):
		block_state.BLOCK_DAMAGE_REDUCTION = block_state.get_meta("original_block_damage_reduction")
		block_state.remove_meta("original_block_damage_reduction")
		print("[Demir Kalkan] ❌ Block hasar azaltma eski haline döndü")
