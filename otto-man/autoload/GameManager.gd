extends Node

const ResourceType = preload("res://resources/resource_types.gd")

signal resource_updated(resource_type: String, new_amount: int)
signal village_level_updated(new_level: int)

var village_data = {
	"level": 1,
	"villagers": [],
	"resources": {
		ResourceType.WOOD: 0,
		ResourceType.FOOD: 0,
		ResourceType.STONE: 0,
		ResourceType.WATER: 0,
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

func add_resources_bulk(amounts: Dictionary) -> void:
	for type in amounts.keys():
		if !village_data.resources.has(type):
			push_warning("[GameManager] add_resources_bulk unknown type: %s" % type)
			continue
		var delta := int(amounts[type])
		if delta == 0:
			continue
		village_data.resources[type] += delta
		resource_updated.emit(type, village_data.resources[type])

func get_resources_snapshot() -> Dictionary:
	return village_data.resources.duplicate()

func get_village_level() -> int:
	return village_data.level

func upgrade_village() -> bool:
	var wood_cost = village_data.level * 100
	var stone_cost = village_data.level * 50
	
	if village_data.resources[ResourceType.WOOD] >= wood_cost and village_data.resources[ResourceType.STONE] >= stone_cost:
		village_data.resources[ResourceType.WOOD] -= wood_cost
		village_data.resources[ResourceType.STONE] -= stone_cost
		village_data.level += 1
		
		village_level_updated.emit(village_data.level)
		resource_updated.emit(ResourceType.WOOD, village_data.resources[ResourceType.WOOD])
		resource_updated.emit(ResourceType.STONE, village_data.resources[ResourceType.STONE])
		return true
	return false

func transfer_carried_resources_to_village() -> Dictionary:
	"""Transfer all carried resources from PlayerStats to village resources.
	Returns the transferred amounts."""
	var player_stats = get_node_or_null("/root/PlayerStats")
	if !player_stats:
		return {}
	var carried = player_stats.get_carried_resources()
	if carried.is_empty():
		return {}
	var transferred := {}
	for type in carried.keys():
		var amount: int = int(carried[type])
		if amount > 0:
			add_resource(type, amount)
			transferred[type] = amount
	player_stats.clear_carried_resources()
	return transferred