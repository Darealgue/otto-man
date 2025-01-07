class_name EnemyHurtbox
extends BaseHurtbox

var slam_hit_cooldown := 0.5  # Longer cooldown for slam attacks

func _ready():
    super._ready()
    collision_layer = 32  # Layer 6 (Enemy hurtbox)
    collision_mask = 16   # Layer 5 (Player hitbox)

func _on_area_entered(hitbox: Area2D):
    if not hitbox is PlayerHitbox:
        return
        
    if is_on_cooldown(hitbox):
        return
    
    # Store hit data
    store_hit_data(hitbox)
    
    # Use longer cooldown for slam attacks
    var cooldown = slam_hit_cooldown if hitbox.get_parent().name.contains("HeavyEnemy") else hit_cooldown
    start_cooldown(hitbox, cooldown)
    
    # Emit hurt signal
    hurt.emit(hitbox) 