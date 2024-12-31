extends PowerupEffect

const DAMAGE_BOOST = 20.0  # Flat damage increase

func _init() -> void:
	powerup_name = "Damage Upgrade"
	description = "Permanently increases damage by {damage}".format({"damage": DAMAGE_BOOST})
	duration = -1  # -1 means permanent until death
	powerup_type = PowerupType.DAMAGE

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	if player.has_method("modify_damage"):
		player.modify_damage(DAMAGE_BOOST)
		print("[DEBUG] Damage Upgrade: Applied +", DAMAGE_BOOST, " damage")

func deactivate(player: CharacterBody2D) -> void:
	# Only deactivate if player dies
	if !is_instance_valid(player):
		super.deactivate(player)
		print("[DEBUG] Damage Upgrade: Reset due to player death")
