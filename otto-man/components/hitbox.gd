extends Area2D

signal hit(area)

@export var damage: int = 10
@export var is_player: bool = false
@onready var collision_shape = $CollisionShape2D
var is_active: bool = false

func _ready() -> void:
	# Start with monitoring off
	monitoring = false
	monitorable = false
	
	add_to_group("hitbox")
	area_entered.connect(_on_area_entered)
	
	# Make sure collision shape is disabled
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox"):
		print("[Hitbox] Hit hurtbox: ", area.get_parent().name)
		hit.emit(area)

func get_damage() -> int:
	return damage

func enable(duration: float = 0.0) -> void:
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	is_active = true
	
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		disable()

func disable() -> void:
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	is_active = false

func is_enabled() -> bool:
	return is_active
