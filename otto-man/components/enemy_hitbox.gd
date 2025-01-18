class_name EnemyHitbox
extends BaseHitbox

signal hit_player(player: Node)

# Enemy-specific properties
var attack_type: String = ""
var can_be_parried: bool = true
var stun_duration: float = 0.0
var is_parried: bool = false  # Track if the hitbox has been parried

func _ready():
    super._ready()
    collision_layer = 64  # Layer 7 (Enemy hitbox)
    collision_mask = 8    # Layer 4 (Player hurtbox)

func setup_attack(type: String, parryable: bool = true, stun: float = 0.0):
    attack_type = type
    can_be_parried = parryable
    stun_duration = stun

# Override to include stun information
func get_knockback_data() -> Dictionary:
    var data = super.get_knockback_data()
    data["stun_duration"] = stun_duration
    return data

# Called when hitting the player
func _on_area_entered(area: Area2D) -> void:
    if area.is_in_group("player_hurtbox"):
        var player = area.get_parent()
        if player:
            hit_player.emit(player) 