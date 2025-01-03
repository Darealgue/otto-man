class_name BaseEnemy
extends CharacterBody2D

# Core components
@export var stats: EnemyStats
@export var debug_enabled: bool = false

# Node references
@onready var sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox

# Basic state tracking
var current_behavior: String = "idle"
var target: Node2D = null
var can_attack: bool = true
var attack_timer: float = 0.0
var health: float
var direction: int = 1

# Constants
const GRAVITY: float = 980.0
const FLOOR_SNAP: float = 32.0

func _ready() -> void:
    add_to_group("enemies")
    if stats:
        health = stats.max_health
    else:
        push_warning("No stats resource assigned to enemy!")
        health = 100.0  # Default value

func _physics_process(delta: float) -> void:
    # Update attack cooldown
    if attack_timer > 0:
        attack_timer -= delta
        if attack_timer <= 0:
            can_attack = true
    
    # Apply gravity
    if not is_on_floor():
        velocity.y += GRAVITY * delta
    
    # Cap fall speed
    velocity.y = minf(velocity.y, GRAVITY)
    
    # Handle behavior
    handle_behavior(delta)
    
    # Apply movement
    move_and_slide()
    
    if debug_enabled:
        print_debug_info()

func handle_behavior(_delta: float) -> void:
    # Override in child classes
    pass

func get_nearest_player() -> Node2D:
    var players = get_tree().get_nodes_in_group("player")
    var nearest_player = null
    var min_distance = stats.detection_range if stats else 300.0
    
    for player in players:
        var distance = global_position.distance_to(player.global_position)
        if distance < min_distance:
            min_distance = distance
            nearest_player = player
    
    return nearest_player

func start_attack_cooldown() -> void:
    attack_timer = stats.attack_cooldown if stats else 2.0
    can_attack = false

func take_damage(amount: float) -> void:
    health -= amount
    if debug_enabled:
        print("[Enemy] Taking damage:", amount)
        print("- Health remaining:", health)
    
    # Spawn damage number
    var damage_number = preload("res://effects/damage_number.tscn").instantiate()
    get_parent().add_child(damage_number)
    damage_number.global_position = global_position + Vector2(0, -30)  # Offset above enemy
    damage_number.setup(int(amount))
    
    # Spawn hit effect
    var hit_effect = preload("res://effects/hit_effect.tscn").instantiate()
    get_parent().add_child(hit_effect)
    hit_effect.global_position = global_position
    hit_effect.setup(Color(1, 0.9, 0.2))  # Yellow hit effect
    
    # Flash the sprite
    if sprite:
        var tween = create_tween()
        tween.tween_property(sprite, "modulate", Color(10, 10, 10), 0.1)  # Bright flash
        tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)  # Back to normal
    
    if health <= 0:
        handle_death()
    else:
        handle_hurt()

func handle_hurt() -> void:
    if sprite and sprite.has_animation("hurt"):
        sprite.play("hurt")
    current_behavior = "hurt"

func handle_death() -> void:
    if sprite and sprite.has_animation("dead"):
        sprite.play("dead")
    current_behavior = "dead"
    # Disable collision and physics
    set_physics_process(false)
    set_collision_layer_value(1, false)
    set_collision_mask_value(1, false)
    # Queue free after animation
    if sprite:
        await sprite.animation_finished
    queue_free()

func print_debug_info() -> void:
    if Engine.get_physics_frames() % 60 == 0:  # Print every ~1 second
        print("[Enemy] Debug Info:")
        print("- Position:", global_position)
        print("- Velocity:", velocity)
        print("- Behavior:", current_behavior)
        print("- Health:", health)
        print("- Can Attack:", can_attack)
        print("- Attack Timer:", attack_timer) 