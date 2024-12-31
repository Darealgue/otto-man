extends PowerupEffect

const TIME_SLOW_SCALE = 0.3  # Slow time to 30% speed
const SLOW_DURATION = 2.0    # Slow for 2 seconds

func _init() -> void:
	powerup_name = "Perfect Guard"
	description = "When shield breaks, temporarily slow down time"
	duration = -1  # Permanent upgrade
	powerup_type = PowerupType.DEFENSE

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	# Connect to shield break signal if player has it
	if player.has_signal("shield_broken"):
		player.shield_broken.connect(_on_shield_broken)
		print("[DEBUG] Perfect Guard: Connected to shield break signal")

func deactivate(player: CharacterBody2D) -> void:
	# Only deactivate if player dies
	if !is_instance_valid(player):
		super.deactivate(player)
		print("[DEBUG] Perfect Guard: Reset due to player death")

func _on_shield_broken() -> void:
	print("[DEBUG] Perfect Guard: Shield broken, slowing time")
	Engine.time_scale = TIME_SLOW_SCALE
	
	# Create timer to restore normal time
	var timer = get_tree().create_timer(SLOW_DURATION * TIME_SLOW_SCALE)  # Adjust for slowed time
	await timer.timeout
	
	Engine.time_scale = 1.0
	print("[DEBUG] Perfect Guard: Time restored to normal") 