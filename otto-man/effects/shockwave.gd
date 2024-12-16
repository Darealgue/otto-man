extends Area2D

var direction = Vector2.RIGHT
var speed = 300
var damage = 25
var lifetime = 2.0

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
    # Start lifetime timer
    var timer = get_tree().create_timer(lifetime)
    timer.timeout.connect(queue_free)
    
    # Set up collision
    collision_layer = 256  # Layer 9 (Enemy Projectiles)
    collision_mask = 8    # Layer 4 (Player Hurtbox)
    
    # Fix rotation based on direction
    if direction.x < 0:
        # If going left, flip the sprite and collision shape
        if animated_sprite:
            animated_sprite.flip_h = true
    else:
        # If going right, keep normal orientation
        if animated_sprite:
            animated_sprite.flip_h = false
    
    # Start animation
    if animated_sprite:
        animated_sprite.play("default")  # Or whatever your animation name is

func _physics_process(delta):
    position += direction * speed * delta

func _on_area_entered(area: Area2D):
    if area.is_in_group("hurtbox") and area.get_parent().is_in_group("player"):
        var player = area.get_parent()
        if player.has_method("take_damage"):
            player.take_damage(damage, direction)