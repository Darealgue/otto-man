# zeytinyagi.gd
# COMMON item - Slide mesafesi +80%

extends ItemEffect

const SLIDE_DISTANCE_MULTIPLIER = 1.8  # +80%

func _init():
	item_id = "zeytinyagi"
	item_name = "Zeytinyağı"
	description = "Slide mesafesi +%80"
	flavor_text = "Kaygan zemin"
	rarity = ItemRarity.COMMON
	category = ItemCategory.SLIDE
	affected_stats = ["slide_distance"]

func activate(player: CharacterBody2D):
	super.activate(player)
	
	# Modify slide state parameters to increase slide distance
	var slide_state = player.get_node_or_null("StateMachine/Slide")
	if slide_state:
		# Store original values if not already stored
		if not slide_state.has_meta("original_slide_duration"):
			slide_state.set_meta("original_slide_duration", slide_state.DEFAULT_SLIDE_DURATION)
			slide_state.set_meta("original_slide_friction", slide_state.DEFAULT_SLIDE_FRICTION)
		
		# Increase slide duration and reduce friction for longer slide distance
		var original_duration = slide_state.get_meta("original_slide_duration")
		var original_friction = slide_state.get_meta("original_slide_friction")
		slide_state.SLIDE_DURATION = original_duration * SLIDE_DISTANCE_MULTIPLIER  # Longer duration
		slide_state.SLIDE_FRICTION = original_friction * 0.6  # Less friction = slides further before stopping
		print("[Zeytinyağı] ✅ Slide süresi ve mesafesi +80%")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	
	var slide_state = player.get_node_or_null("StateMachine/Slide")
	if slide_state and slide_state.has_meta("original_slide_duration"):
		slide_state.SLIDE_DURATION = slide_state.get_meta("original_slide_duration")
		slide_state.SLIDE_FRICTION = slide_state.get_meta("original_slide_friction")
		slide_state.remove_meta("original_slide_duration")
		slide_state.remove_meta("original_slide_friction")
		print("[Zeytinyağı] ❌ Slide restored")
