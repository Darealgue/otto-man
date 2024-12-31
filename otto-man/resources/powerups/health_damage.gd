@tool
extends PowerupEffect

@export var health_to_damage_ratio: float = 0.1  # 10% of max health as bonus damage

func _init() -> void:
	powerup_name = "Vitality Strike"
	description = "Gain bonus damage equal to {ratio}% of your maximum health".format({"ratio": health_to_damage_ratio * 100})
	duration = -1  # Permanent until death
	powerup_type = PowerupType.DAMAGE

func apply(player: CharacterBody2D) -> void:
	update_damage_bonus()

func remove(player: CharacterBody2D) -> void:
	modify_stat("base_damage", 0)  # Reset the bonus

func update(_player: CharacterBody2D, _delta: float) -> void:
	update_damage_bonus()

func update_damage_bonus() -> void:
	var max_health = get_stat_value("max_health")
	var bonus_damage = max_health * health_to_damage_ratio
	modify_stat("base_damage", bonus_damage)

# This powerup synergizes with health-boosting powerups
func has_synergy_with(other: PowerupEffect) -> bool:
	return other.affects_stat("max_health")

func apply_synergy(player: CharacterBody2D, other: PowerupEffect) -> void:
	update_damage_bonus()  # Recalculate damage when max health changes

func remove_synergy(player: CharacterBody2D, other: PowerupEffect) -> void:
	update_damage_bonus()  # Recalculate damage when max health changes 