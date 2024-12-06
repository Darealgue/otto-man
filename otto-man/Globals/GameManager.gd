extends Node

signal resource_updated(resource_type: String, new_amount: int)
signal village_level_updated(new_level: int)

var village_data = {
	"level": 1,
	"villagers": [],
	"resources": {
		"wood": 0,
		"food": 0,
		"stone": 0
	}
}

func get_resource(type: String) -> int:
	if village_data.resources.has(type):
		return village_data.resources[type]
	return 0

func add_resource(type: String, amount: int) -> void:
	if village_data.resources.has(type):
		village_data.resources[type] += amount
		resource_updated.emit(type, village_data.resources[type])

func get_village_level() -> int:
	return village_data.level

func upgrade_village() -> bool:
	var wood_cost = village_data.level * 100
	var stone_cost = village_data.level * 50
	
	if village_data.resources.wood >= wood_cost and village_data.resources.stone >= stone_cost:
		village_data.resources.wood -= wood_cost
		village_data.resources.stone -= stone_cost
		village_data.level += 1
		
		village_level_updated.emit(village_data.level)
		resource_updated.emit("wood", village_data.resources.wood)
		resource_updated.emit("stone", village_data.resources.stone)
		return true
	return false
