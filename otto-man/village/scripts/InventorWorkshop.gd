extends Node2D
## Mucit Odası — yükseltilemez, kalıcı karakter geliştirmeleri sunar.

var building_name: String = "Mucit Odası"
var level: int = 1

const _INTERACT_SCRIPT := preload("res://village/scripts/InventorWorkshopInteractable.gd")


func _ready() -> void:
	add_to_group("WorkBuildings")
	_ensure_interact_area()


func _ensure_interact_area() -> void:
	if has_node("InteractArea"):
		return
	var area := Area2D.new()
	area.name = "InteractArea"
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = true
	area.set_script(_INTERACT_SCRIPT)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(140, 90)
	col.shape = shape
	col.position = Vector2(0, -50)
	area.add_child(col)
	add_child(area)
