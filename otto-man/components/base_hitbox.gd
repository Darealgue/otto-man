class_name BaseHitbox
extends Area2D

@export var damage: float = 0.0
@export var knockback_force: float = 0.0
@export var knockback_up_force: float = 0.0
@export var debug_enabled: bool = false

var is_active: bool = false

func _ready():
	# Ensure hitbox starts disabled
	disable()
	# Make collision shape visible in editor but hidden in game
	if get_node_or_null("CollisionShape2D"):
		get_node("CollisionShape2D").debug_color = Color(0.7, 0, 0, 0.4)

func enable():
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", false)
	is_active = true

func disable():
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", true)
	is_active = false

func is_enabled() -> bool:
	return is_active

func get_damage() -> float:
	return damage

func get_knockback_data() -> Dictionary:
	return {
		"force": knockback_force,
		"up_force": knockback_up_force
	} 
