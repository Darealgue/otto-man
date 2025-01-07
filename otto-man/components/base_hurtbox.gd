class_name BaseHurtbox
extends Area2D

signal hurt(hitbox: Area2D)

var last_damage := 0.0
var last_hitbox = null
var debug_enabled := true
var hit_cooldown := 0.1
var recent_hits := {}

func _ready():
    area_entered.connect(_on_area_entered)

func _process(delta: float):
    # Update cooldowns and remove expired entries
    var expired_hits := []
    for hitbox in recent_hits:
        recent_hits[hitbox] -= delta
        if recent_hits[hitbox] <= 0:
            expired_hits.append(hitbox)
    
    for hitbox in expired_hits:
        recent_hits.erase(hitbox)

func _on_area_entered(_hitbox: Area2D):
    # To be implemented by child classes
    pass

func start_cooldown(hitbox: Area2D, duration: float = 0.1):
    recent_hits[hitbox] = duration

func is_on_cooldown(hitbox: Area2D) -> bool:
    return hitbox in recent_hits

func store_hit_data(hitbox: Area2D):
    last_hitbox = hitbox
    last_damage = hitbox.get_damage() 