extends Node2D

@export var perfect_color: Color = Color(0.2, 0.9, 0.4, 1.0)
@export var good_color: Color = Color(0.9, 0.8, 0.3, 1.0)
@export var miss_color: Color = Color(0.9, 0.2, 0.2, 1.0)

@onready var _sprite: Sprite2D = $Sprite2D

func set_state(kind: String) -> void:
	match kind:
		"perfect":
			_apply_color(perfect_color)
		"good":
			_apply_color(good_color)
		"miss":
			_apply_color(miss_color)
		_:
			_apply_color(Color.WHITE)

func _apply_color(color: Color) -> void:
	if _sprite:
		_sprite.modulate = color

