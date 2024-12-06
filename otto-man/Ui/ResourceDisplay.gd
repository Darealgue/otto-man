extends Control

@onready var wood_label: Label = $TopBar/ResourcePanel/MarginContainer/HBoxContainer/WoodContainer/WoodCount
@onready var food_label: Label = $TopBar/ResourcePanel/MarginContainer/HBoxContainer/FoodContainer/FoodCount
@onready var stone_label: Label = $TopBar/ResourcePanel/MarginContainer/HBoxContainer/StoneContainer/StoneCount

func _ready() -> void:
	print("Wood label path: ", $TopBar/ResourcePanel/MarginContainer/HBoxContainer/WoodContainer/WoodCount)
	print("Food label path: ", $TopBar/ResourcePanel/MarginContainer/HBoxContainer/FoodContainer/FoodCount)
	print("Stone label path: ", $TopBar/ResourcePanel/MarginContainer/HBoxContainer/StoneContainer/StoneCount)
	
	if !wood_label or !food_label or !stone_label:
		push_error("Labels not found! Check node paths.")
		return
		
	GameManager.resource_updated.connect(_on_resource_updated)
	_update_all_resources()

func _update_all_resources() -> void:
	if wood_label and food_label and stone_label:
		wood_label.text = "Wood: %d" % GameManager.get_resource("wood")
		food_label.text = "Food: %d" % GameManager.get_resource("food")
		stone_label.text = "Stone: %d" % GameManager.get_resource("stone")

func _on_resource_updated(_resource_type: String, _amount: int) -> void:
	_update_all_resources()
