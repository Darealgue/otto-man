extends Area2D

signal hurt(area: Area2D)

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	add_to_group("hurtbox")
	monitorable = true

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hitbox"):
		hurt.emit(area)

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if get_parent() and get_parent().has_method("take_damage"):
		get_parent().take_damage(amount, knockback_dir)
