extends Area2D

signal hurt(hitbox: Area2D)

@export var is_player: bool = false

func _ready() -> void:
	add_to_group("hurtbox")
	area_entered.connect(_on_area_entered)

func _on_area_entered(hitbox: Area2D) -> void:
	if hitbox.is_in_group("hitbox"):
		print("[Hurtbox] Hit by hitbox: ", hitbox.get_parent().name)
		hurt.emit(hitbox)
