extends Control

const ResourceType = preload("res://resources/resource_types.gd")

@onready var wood_label: Label = $VBoxContainer/WoodLabel
@onready var stone_label: Label = $VBoxContainer/StoneLabel
@onready var water_label: Label = $VBoxContainer/WaterLabel
@onready var food_label: Label = $VBoxContainer/FoodLabel

var _player_stats: Node = null

func _ready() -> void:
	_player_stats = get_node_or_null("/root/PlayerStats")
	if _player_stats:
		_player_stats.carried_resources_changed.connect(_on_resources_changed)
		_update_display()
	else:
		print("[CarriedResourcesDisplay] ERROR: PlayerStats not found!")

func _on_resources_changed(new_totals: Dictionary) -> void:
	_update_display()

func _update_display() -> void:
	if not _player_stats:
		return
	
	var resources: Dictionary = _player_stats.get_carried_resources()
	
	# Sadece 0'dan büyük kaynakları göster
	var has_any_resources := false
	
	if wood_label:
		var wood_amount: int = int(resources.get(ResourceType.WOOD, 0))
		if wood_amount > 0:
			wood_label.text = "Odun: " + str(wood_amount)
			wood_label.visible = true
			has_any_resources = true
		else:
			wood_label.visible = false
	
	if stone_label:
		var stone_amount: int = int(resources.get(ResourceType.STONE, 0))
		if stone_amount > 0:
			stone_label.text = "Taş: " + str(stone_amount)
			stone_label.visible = true
			has_any_resources = true
		else:
			stone_label.visible = false
	
	if water_label:
		var water_amount: int = int(resources.get(ResourceType.WATER, 0))
		if water_amount > 0:
			water_label.text = "Su: " + str(water_amount)
			water_label.visible = true
			has_any_resources = true
		else:
			water_label.visible = false
	
	if food_label:
		var food_amount: int = int(resources.get(ResourceType.FOOD, 0))
		if food_amount > 0:
			food_label.text = "Yemek: " + str(food_amount)
			food_label.visible = true
			has_any_resources = true
		else:
			food_label.visible = false
	
	# Eğer hiç kaynak yoksa tüm UI'ı gizle
	visible = has_any_resources
