extends PowerupEffect

const SPEED_BOOST = 0.5  # 50% speed increase
const BOOST_DURATION = 3.0  # Speed boost lasts 3 seconds

var is_boosted := false
var boost_timer := 0.0
var current_player: CharacterBody2D

func _init() -> void:
	powerup_name = "Speed Demon"
	description = "After using dash, move 50% faster for 3 seconds"
	duration = -1  # Permanent upgrade
	powerup_type = PowerupType.MOVEMENT
	affected_stats = ["movement_speed"]

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	print("[DEBUG] Speed Demon - Starting activation...")
	print("   Player valid:", is_instance_valid(player))
	print("   Player has dash state:", player.has_method("get_dash_state"))
	
	# Store player reference
	current_player = player
	
	# Initial state
	is_boosted = false
	boost_timer = 0.0
	
	print("[DEBUG] Speed Demon - Ready to activate on dash")
	print("   Base Speed:", player_stats.get_stat("movement_speed"))
	print("   Current Speed Multiplier:", player_stats.stat_multipliers["movement_speed"])
	
	# Connect to dash state signals
	var dash_state = player.get_dash_state()
	print("   Dash state:", dash_state)
	print("   Dash state type:", dash_state.get_class() if dash_state else "No dash state")
	
	if dash_state:
		# Connect to the player's dash state signals
		if !player.is_connected("dash_started", _activate_speed_boost):
			player.connect("dash_started", _activate_speed_boost)
			print("   Connected to player's dash_started signal")
		print("   State machine:", dash_state.get_parent())
		print("   Current state:", dash_state.get_parent().current_state.name if dash_state.get_parent().current_state else "None")
		print("   Signal connections:", player.get_signal_list())

func process(player: CharacterBody2D, delta: float) -> void:
	if !player or !is_instance_valid(player):
		return
	
	# Handle boost timer
	if is_boosted:
		boost_timer -= delta
		print("[DEBUG] Speed Demon - Boost active:")
		print("   Remaining time:", boost_timer)
		print("   Current speed multiplier:", player_stats.stat_multipliers["movement_speed"])
		print("   Current movement speed:", player_stats.get_stat("movement_speed"))
		
		if boost_timer <= 0:
			print("[DEBUG] Speed Demon - Boost timer expired, ending boost")
			_end_speed_boost(player)

func _activate_speed_boost() -> void:
	print("\n[DEBUG] Speed Demon - _activate_speed_boost called!")
	print("   Is boosted:", is_boosted)
	print("   Current timer:", boost_timer)
	print("   Player reference valid:", is_instance_valid(current_player))
	print("   Current speed multiplier:", player_stats.stat_multipliers["movement_speed"])
	
	if !current_player or !is_instance_valid(current_player):
		push_error("[Speed Demon] No valid player reference!")
		return
		
	# Start speed boost
	is_boosted = true
	boost_timer = BOOST_DURATION
	
	var old_speed = player_stats.get_stat("movement_speed")
	var old_multiplier = player_stats.stat_multipliers["movement_speed"]
	
	# Remove any existing speed boost first
	if old_multiplier > 1.0:
		player_stats.add_stat_multiplier("movement_speed", 1.0 / old_multiplier)
	
	# Apply new speed boost
	player_stats.add_stat_multiplier("movement_speed", 1.0 + SPEED_BOOST)
	
	print("[DEBUG] Speed Demon - Speed Boost Activated:")
	print("   Old Speed:", old_speed)
	print("   Old Multiplier:", old_multiplier)
	print("   New Speed:", player_stats.get_stat("movement_speed"))
	print("   New Multiplier:", player_stats.stat_multipliers["movement_speed"])
	print("   Duration:", BOOST_DURATION, "seconds")
	print("   Is boosted flag:", is_boosted)
	print("   Boost timer set to:", boost_timer)

func _end_speed_boost(player: CharacterBody2D) -> void:
	if !is_boosted:
		return
		
	print("\n[DEBUG] Speed Demon - Ending speed boost")
	print("   Current boost timer:", boost_timer)
	print("   Current speed multiplier:", player_stats.stat_multipliers["movement_speed"])
	
	is_boosted = false
	
	var old_speed = player_stats.get_stat("movement_speed")
	var old_multiplier = player_stats.stat_multipliers["movement_speed"]
	
	# Remove speed boost by dividing by the boost amount
	player_stats.add_stat_multiplier("movement_speed", 1.0 / (1.0 + SPEED_BOOST))
	
	print("[DEBUG] Speed Demon - Speed Boost Ended:")
	print("   Old Speed:", old_speed)
	print("   Old Multiplier:", old_multiplier)
	print("   New Speed:", player_stats.get_stat("movement_speed"))
	print("   New Multiplier:", player_stats.stat_multipliers["movement_speed"])
	print("   Is boosted flag:", is_boosted)

func deactivate(player: CharacterBody2D) -> void:
	print("\n[DEBUG] Speed Demon - Deactivating...")
	print("   Player valid:", is_instance_valid(player))
	print("   Is boosted:", is_boosted)
	print("   Current speed multiplier:", player_stats.stat_multipliers["movement_speed"])
	
	if is_instance_valid(player):
		if is_boosted:
			_end_speed_boost(player)
		
		# Disconnect dash state signals
		if player.is_connected("dash_started", _activate_speed_boost):
			player.disconnect("dash_started", _activate_speed_boost)
			print("   Successfully disconnected from player's dash_started signal")
	
	current_player = null
	print("   Cleanup complete")
	super.deactivate(player)
