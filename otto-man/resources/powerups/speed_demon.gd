extends PowerupEffect

const SPEED_BOOST = 1.5  # 50% speed increase
const BOOST_DURATION = 3.0  # Speed boost lasts 3 seconds

var is_boosted := false
var boost_timer := 0.0

func _init() -> void:
	powerup_name = "Speed Demon"
	description = "Wall jumps grant temporary speed boost"
	duration = -1  # Permanent upgrade
	powerup_type = PowerupType.MOVEMENT

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	# We'll check for wall jumps in process

func deactivate(player: CharacterBody2D) -> void:
	# Only deactivate if player dies
	if !is_instance_valid(player):
		super.deactivate(player)
		if is_boosted and player.has_method("modify_speed"):
			player.modify_speed(1.0)  # Reset speed
		print("[DEBUG] Speed Demon: Reset due to player death")

func process(player: CharacterBody2D, delta: float) -> void:
	# Check for wall jump (you might need to adjust this based on your player implementation)
	if player.is_on_wall() and player.velocity.y < 0:  # Moving up while on wall = wall jump
		if !is_boosted:
			is_boosted = true
			boost_timer = BOOST_DURATION
			if player.has_method("modify_speed"):
				player.modify_speed(SPEED_BOOST)
				print("[DEBUG] Speed Demon: Speed boost activated")
	
	# Handle boost timer
	if is_boosted:
		boost_timer -= delta
		if boost_timer <= 0:
			is_boosted = false
			if player.has_method("modify_speed"):
				player.modify_speed(1.0)  # Reset speed
				print("[DEBUG] Speed Demon: Speed boost expired") 