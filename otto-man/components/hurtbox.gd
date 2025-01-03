extends Area2D

signal hurt(hitbox: Area2D)

@export var is_player: bool = false:
	set(value):
		is_player = value
		_update_collision_layers()

func _ready() -> void:
	add_to_group("hurtbox")
	area_entered.connect(_on_area_entered)
	_update_collision_layers()

func _update_collision_layers() -> void:
	if is_player:
		# Player hurtbox: Layer 4, can be hit by enemy hitbox (layer 7)
		collision_layer = 8   # 4th bit
		collision_mask = 64   # 7th bit
	else:
		# Enemy hurtbox: Layer 6, can be hit by player hitbox (layer 5)
		collision_layer = 32  # 6th bit
		collision_mask = 16   # 5th bit
	
	print("[Hurtbox] Updated for ", get_parent().name if get_parent() else "unknown", " - Is player: ", is_player)
	print("[Hurtbox] Collision layer:", collision_layer)
	print("[Hurtbox] Collision mask:", collision_mask)

func _on_area_entered(hitbox: Area2D) -> void:
	print("[Hurtbox] Area entered: ", hitbox.name, " from ", hitbox.get_parent().name)
	print("[Hurtbox] Is in hitbox group: ", hitbox.is_in_group("hitbox"))
	print("[Hurtbox] Parent is: ", get_parent().name)
	print("[Hurtbox] Hitbox monitoring: ", hitbox.monitoring)
	print("[Hurtbox] Hitbox monitorable: ", hitbox.monitorable)
	
	if hitbox.is_in_group("hitbox") and hitbox.monitoring and hitbox.monitorable:
		print("[Hurtbox] Hit by hitbox: ", hitbox.get_parent().name)
		if hitbox.has_method("get_damage"):
			var damage = hitbox.get_damage()
			print("[Hurtbox] Hitbox damage: ", damage)
			hurt.emit(hitbox)
			print("[Hurtbox] Emitted hurt signal with damage: ", damage)
