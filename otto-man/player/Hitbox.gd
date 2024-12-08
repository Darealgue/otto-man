extends Area2D

signal hit(area: Area2D)

@export var damage: int = 10

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	monitoring = false
	add_to_group("hitbox")

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox"):
		hit.emit(area)

func get_damage() -> int:
	return damage

func enable() -> void:
	monitoring = true
	monitorable = true
	if get_node_or_null("CollisionShape2D"):
		$CollisionShape2D.disabled = false

func disable() -> void:
	monitoring = false
	monitorable = false
	if get_node_or_null("CollisionShape2D"):
		$CollisionShape2D.disabled = true 
