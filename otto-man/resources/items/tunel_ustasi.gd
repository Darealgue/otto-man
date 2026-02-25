# tunel_ustasi.gd
# COMMON item - Crawl hızı +%50

extends ItemEffect

const SPEED_BOOST = 0.5  # %50 artış

func _init():
	item_id = "tunel_ustasi"
	item_name = "Tünel Ustası"
	description = "Crawl hızı +%50"
	flavor_text = "Daha hızlı sürünme"
	rarity = ItemRarity.COMMON
	category = ItemCategory.CROUCH
	affected_stats = ["crawl_speed"]

func activate(player: CharacterBody2D):
	super.activate(player)
	var crouch_state = player.get_node_or_null("StateMachine/Crouch")
	if crouch_state:
		if not crouch_state.has_meta("original_crawl_speed_tunel"):
			crouch_state.set_meta("original_crawl_speed_tunel", crouch_state.DEFAULT_CRAWL_SPEED)
		var orig = crouch_state.get_meta("original_crawl_speed_tunel")
		crouch_state.CRAWL_SPEED = orig * (1.0 + SPEED_BOOST)
		print("[Tünel Ustası] ✅ Crawl hızı +%50 (", crouch_state.CRAWL_SPEED, ")")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	var crouch_state = player.get_node_or_null("StateMachine/Crouch")
	if crouch_state and crouch_state.has_meta("original_crawl_speed_tunel"):
		crouch_state.CRAWL_SPEED = crouch_state.get_meta("original_crawl_speed_tunel")
		crouch_state.remove_meta("original_crawl_speed_tunel")
		print("[Tünel Ustası] ❌ Crawl hızı eski haline döndü (", crouch_state.CRAWL_SPEED, ")")
