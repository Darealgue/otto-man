extends PowerupEffect

const FIRE_TRAIL_DAMAGE = 20.0
const FIRE_TRAIL_DURATION = 10.0
const FIRE_TRAIL_INTERVAL = 0.1

func _init() -> void:
	powerup_name = "Fire Trail"
	description = "Leave a trail of fire behind you while dashing"
	duration = -1  # Permanent upgrade
	powerup_type = PowerupType.DAMAGE

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	if player.has_method("enable_fire_trail"):
		player.enable_fire_trail(FIRE_TRAIL_DAMAGE, FIRE_TRAIL_DURATION, FIRE_TRAIL_INTERVAL)
		print("[DEBUG] Fire Trail: Enabled with damage ", FIRE_TRAIL_DAMAGE, " per second")

func deactivate(player: CharacterBody2D) -> void:
	# Only deactivate if player dies
	if !is_instance_valid(player):
		super.deactivate(player)
		print("[DEBUG] Fire Trail: Reset due to player death")
