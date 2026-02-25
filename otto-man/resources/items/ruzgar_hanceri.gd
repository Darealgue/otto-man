# ruzgar_hanceri.gd
# UNCOMMON item - Dodge → Dash, havada kullanılabilir

extends ItemEffect

func _init():
	item_id = "ruzgar_hanceri"
	item_name = "Rüzgar Hançeri"
	description = "Dodge roll → Dash'e dönüşür, havada kullanılabilir"
	flavor_text = "Rüzgar gibi geç"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = []

func activate(player: CharacterBody2D):
	super.activate(player)
	
	# Enable dash state to be used instead of dodge, and allow air usage
	var dash_state = player.get_node_or_null("StateMachine/Dash")
	if dash_state:
		# Allow dash to be used in air
		dash_state.set_meta("allow_air_dash", true)
		print("[Rüzgar Hançeri] ✅ Dash aktif (havada kullanılabilir)")
	else:
		push_warning("[Rüzgar Hançeri] Dash state bulunamadı!")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	
	var dash_state = player.get_node_or_null("StateMachine/Dash")
	if dash_state:
		dash_state.remove_meta("allow_air_dash")
		print("[Rüzgar Hançeri] ❌ Dash restored")
