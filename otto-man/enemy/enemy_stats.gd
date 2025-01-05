@tool
extends Resource
class_name EnemyStats

# Base stats
@export var max_health: float = 100.0
@export var movement_speed: float = 100.0
@export var attack_damage: float = 10.0
@export var detection_range: float = 300.0
@export var attack_range: float = 50.0

# Combat stats
@export var attack_cooldown: float = 2.0
@export var knockback_resistance: float = 1.0

# Scaling factors
@export var health_scale: float = 1.2
@export var damage_scale: float = 1.15
@export var speed_scale: float = 1.1

@export var can_drop_powerup: bool = false  # Whether this enemy can drop powerups when killed
@export var powerup_drop_chance: float = 0.5  # Chance to drop a powerup (0.0 to 1.0)

func scale_to_level(level: int) -> void:
    max_health *= pow(health_scale, level)
    attack_damage *= pow(damage_scale, level)
    movement_speed *= pow(speed_scale, level) 