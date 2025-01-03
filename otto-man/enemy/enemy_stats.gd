class_name EnemyStats
extends Resource

# Base stats
@export var max_health: float = 100.0
@export var movement_speed: float = 100.0
@export var attack_damage: float = 10.0
@export var detection_range: float = 300.0

# Combat stats
@export var attack_cooldown: float = 2.0
@export var knockback_resistance: float = 0.5

# Scaling factors
@export var health_scale: float = 1.2
@export var damage_scale: float = 1.15
@export var speed_scale: float = 1.1

func scale_to_level(level: int) -> void:
    max_health *= pow(health_scale, level)
    attack_damage *= pow(damage_scale, level)
    movement_speed *= pow(speed_scale, level) 