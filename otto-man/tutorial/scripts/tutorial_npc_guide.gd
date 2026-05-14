class_name TutorialNpcGuide
extends Node2D
## Tek sahnede taşınan rehber kökü: sprite, duman, animasyonu alt düğüm olarak sen eklersin.
## Director sadece global_position + visible akışını yönetir; isteğe bağlı gecikmeyi AnimationPlayer ile halledin.

func _ready() -> void:
	visible = false


func appear(at_world: Vector2) -> void:
	global_position = at_world
	visible = true


func disappear() -> void:
	visible = false
