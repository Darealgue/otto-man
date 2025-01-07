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
	
	# Store player reference
	current_player = player
	
	# Initial state
	is_boosted = false
	boost_timer = 0.0
	
	
	# Connect to dash state signals
	var dash_state = player.get_dash_state()
	
	if dash_state:
		# Connect to the player's dash state signals
		if !player.is_connected("dash_started", _activate_speed_boost):
			player.connect("dash_started", _activate_speed_boost)

func process(player: CharacterBody2D, delta: float) -> void:
	if !player or !is_instance_valid(player):
		return
	
	# Handle boost timer
	if is_boosted:
		boost_timer -= delta
		
		if boost_timer <= 0:
			_end_speed_boost(player)

func _activate_speed_boost() -> void:
	
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
	

func _end_speed_boost(player: CharacterBody2D) -> void:
	if !is_boosted:
		return
		
	
	is_boosted = false
	
	var old_speed = player_stats.get_stat("movement_speed")
	var old_multiplier = player_stats.stat_multipliers["movement_speed"]
	
	# Remove speed boost by dividing by the boost amount
	player_stats.add_stat_multiplier("movement_speed", 1.0 / (1.0 + SPEED_BOOST))
	

func deactivate(player: CharacterBody2D) -> void:
	
	if is_instance_valid(player):
		if is_boosted:
			_end_speed_boost(player)
		
		# Disconnect dash state signals
		if player.is_connected("dash_started", _activate_speed_boost):
			player.disconnect("dash_started", _activate_speed_boost)
	
	current_player = null
	super.deactivate(player)
