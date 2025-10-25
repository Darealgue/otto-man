@tool
extends Resource
class_name EnemyStats

# Base stats
@export var max_health: float = 100.0
@export var movement_speed: float = 100.0
@export var chase_speed: float = 150.0  # Speed when chasing player
@export var attack_damage: float = 10.0
@export var detection_range: float = 300.0
@export var attack_range: float = 50.0

# Combat stats
@export var attack_cooldown: float = 2.0
@export var knockback_resistance: float = 1.0

# Summoner stats
@export var max_summon_count: int = 3  # Maximum number of birds that can be summoned
@export var summon_cooldown: float = 5.0  # Time between summons

# Scaling factors (reduced for more balanced gameplay)
@export var health_scale: float = 1.1  # Reduced from 1.2
@export var damage_scale: float = 1.08  # Reduced from 1.15
@export var speed_scale: float = 1.05  # Reduced from 1.1

@export var can_drop_powerup: bool = false  # Whether this enemy can drop powerups when killed
@export var powerup_drop_chance: float = 0.5  # Chance to drop a powerup (0.0 to 1.0)

func scale_to_level(level: int) -> void:
    print("[EnemyStats] Scaling stats to level ", level)
    print("[EnemyStats] Before scaling - Movement Speed:", movement_speed, " Chase Speed:", chase_speed)
    
    # Store original values to prevent multiple scaling
    if not has_meta("original_health"):
        set_meta("original_health", max_health)
        set_meta("original_damage", attack_damage)
        set_meta("original_movement_speed", movement_speed)
        set_meta("original_chase_speed", chase_speed)
    
    # Get original values
    var orig_health = get_meta("original_health")
    var orig_damage = get_meta("original_damage")
    var orig_movement_speed = get_meta("original_movement_speed")
    var orig_chase_speed = get_meta("original_chase_speed")
    
    # Apply scaling from original values
    max_health = orig_health * (1.0 + (health_scale - 1.0) * level)
    attack_damage = orig_damage * (1.0 + (damage_scale - 1.0) * level)
    movement_speed = orig_movement_speed * (1.0 + (speed_scale - 1.0) * level)
    chase_speed = orig_chase_speed * (1.0 + (speed_scale - 1.0) * level)
    
    print("[EnemyStats] After scaling - Movement Speed:", movement_speed, " Chase Speed:", chase_speed) 