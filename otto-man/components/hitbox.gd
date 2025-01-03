extends Area2D

@export var damage: float = 10.0
@export var knockback_force: float = 0.0
@export var knockback_up_force: float = 0.0
@export var is_player: bool = false
@export var debug_enabled: bool = false

var is_active: bool = false

func _ready():
	if debug_enabled:
		print("[Hitbox] Updated for", get_parent().name, "- Is player:", is_player)
		print("[Hitbox] Collision layer:", collision_layer)
		print("[Hitbox] Collision mask:", collision_mask)

func enable():
	monitoring = true
	monitorable = true
	$CollisionShape2D.set_deferred("disabled", false)
	is_active = true
	if debug_enabled:
		print("[Hitbox] Enabled hitbox for", get_parent().name, "with damage:", damage)

func disable():
	monitoring = false
	monitorable = false
	$CollisionShape2D.set_deferred("disabled", true)
	is_active = false
	if debug_enabled:
		print("[Hitbox] Disabled hitbox for", get_parent().name)

func is_enabled() -> bool:
	return is_active

func get_damage() -> float:
	return damage

func get_knockback_data() -> Dictionary:
	return {
		"force": knockback_force,
		"up_force": knockback_up_force
	}
