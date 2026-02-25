# parry_ustasi.gd
# COMMON item - Perfect parry penceresi +40%

extends ItemEffect

const PARRY_WINDOW_BOOST = 0.4

func _init():
	item_id = "parry_ustasi"
	item_name = "Parry Ustası"
	description = "Perfect parry penceresi +%40"
	flavor_text = "Daha kolay parry"
	rarity = ItemRarity.COMMON
	category = ItemCategory.PARRY
	affected_stats = ["parry_window"]

func activate(player: CharacterBody2D):
	super.activate(player)
	var block_state = player.get_node_or_null("StateMachine/Block")
	if block_state:
		if not block_state.has_meta("original_parry_window_parry"):
			block_state.set_meta("original_parry_window_parry", block_state.PARRY_WINDOW)
		var orig = block_state.get_meta("original_parry_window_parry")
		block_state.PARRY_WINDOW = orig * (1.0 + PARRY_WINDOW_BOOST)
		print("[Parry Ustası] ✅ Parry penceresi +40%")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	var block_state = player.get_node_or_null("StateMachine/Block")
	if block_state and block_state.has_meta("original_parry_window_parry"):
		block_state.PARRY_WINDOW = block_state.get_meta("original_parry_window_parry")
		block_state.remove_meta("original_parry_window_parry")
		print("[Parry Ustası] ❌ Parry penceresi eski haline döndü")
