extends PowerupEffect

const AIR_CONTROL_BOOST = 1.5  # 50% better air control
const WALL_CLIMB_BOOST = 1.5   # 50% better wall climbing

func _init() -> void:
	powerup_name = "Momentum Master"
	description = "Permanently improves air control and wall climbing"
	duration = -1  # Permanent upgrade
	powerup_type = PowerupType.MOVEMENT

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	if player.has_method("modify_air_control"):
		player.modify_air_control(AIR_CONTROL_BOOST)
		print("[DEBUG] Momentum Master: Improved air control")
	if player.has_method("modify_wall_climb"):
		player.modify_wall_climb(WALL_CLIMB_BOOST)
		print("[DEBUG] Momentum Master: Improved wall climbing")

func deactivate(player: CharacterBody2D) -> void:
	# Only deactivate if player dies
	if !is_instance_valid(player):
		super.deactivate(player)
		print("[DEBUG] Momentum Master: Reset due to player death") 