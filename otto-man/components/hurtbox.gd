extends Area2D

signal hurt(hitbox: Area2D)

@export var is_player: bool = false

func _ready() -> void:
	add_to_group("hurtbox")
	area_entered.connect(_on_area_entered)
	
	# Debug info
	print("Hurtbox setup for: ", get_parent().name)
	print("- Layer: ", collision_layer)
	print("- Mask: ", collision_mask)
	print("- Monitorable: ", monitorable)
	
	# Verify collision shape
	var shape = get_node_or_null("CollisionShape2D")
	if shape:
		print("- Shape found: ", shape.shape)
		print("- Shape enabled: ", !shape.disabled)
	else:
		print("WARNING: No collision shape found!")

func _on_area_entered(hitbox: Area2D) -> void:
	if hitbox.is_in_group("hitbox"):
		hurt.emit(hitbox)
