@tool
extends PowerupEffect

const HEALTH_MULTIPLIER = 1.5  # 50% health increase

func _init() -> void:
	powerup_name = "Health Upgrade"
	description = "Permanently increases max health by 50%"
	duration = -1  # -1 means permanent until death
	powerup_type = PowerupType.DEFENSE

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	if player.has_method("modify_max_health"):
		player.modify_max_health(HEALTH_MULTIPLIER)
		print("[DEBUG] Health Upgrade: Applied x", HEALTH_MULTIPLIER, " health multiplier")

func deactivate(player: CharacterBody2D) -> void:
	# Only deactivate if player dies
	if !is_instance_valid(player):
		super.deactivate(player)
		print("[DEBUG] Health Upgrade: Reset due to player death")

# Synergize with other defensive upgrades
func conflicts_with(other: PowerupEffect) -> bool:
	return false  # Allow stacking health upgrades 