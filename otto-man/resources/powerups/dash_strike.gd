@tool
extends PowerupEffect

@export var dash_damage_multiplier: float = 1.5  # 150% of base damage
@export var cooldown_reduction: float = 0.2  # 20% faster dash cooldown

func _init() -> void:
	powerup_name = "Dash Strike"
	description = "Dash deals {damage}% of base damage and cooldown reduced by {cooldown}%".format({
		"damage": dash_damage_multiplier * 100,
		"cooldown": cooldown_reduction * 100
	})
	duration = -1  # Permanent until death
	powerup_type = PowerupType.MOVEMENT

func apply(player: CharacterBody2D) -> void:
	modify_stat("dash_cooldown", 1.0 - cooldown_reduction, true)  # Reduce cooldown
	
	if player.has_method("enable_dash_damage"):
		var damage = get_stat_value("base_damage") * dash_damage_multiplier
		player.enable_dash_damage(damage)

func remove(player: CharacterBody2D) -> void:
	modify_stat("dash_cooldown", 1.0, true)  # Reset cooldown
	
	if player.has_method("disable_dash_damage"):
		player.disable_dash_damage()

func update(player: CharacterBody2D, _delta: float) -> void:
	# Update dash damage based on current damage multipliers
	if player.has_method("enable_dash_damage"):
		var damage = get_stat_value("base_damage") * dash_damage_multiplier
		player.enable_dash_damage(damage)

# Synergize with damage and movement powerups
func has_synergy_with(other: PowerupEffect) -> bool:
	return other.powerup_type == PowerupType.DAMAGE or other.affects_stat("movement_speed") 