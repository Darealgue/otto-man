extends Area2D

signal hurt(area: Area2D)
signal damaged(amount: int)

@export var is_player: bool = false

func _ready():
	if is_player:
		collision_layer = 8   # Layer 4 (PLAYER HURTBOX)
		collision_mask = 64   # Layer 7 (ENEMY HITBOX)
	else:
		collision_layer = 32  # Layer 6 (ENEMY HURTBOX)
		collision_mask = 16   # Layer 5 (PLAYER HITBOX)
	
	add_to_group("hurtbox")
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if get_parent().has_method("is_dead") and get_parent().is_dead():
		return
		
	if not area.is_in_group("hitbox"):
		return
		
	hurt.emit(area)
