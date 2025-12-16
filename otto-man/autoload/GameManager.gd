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
		print("[GameManager] ⚠️ PlayerStats not found, cannot transfer resources")
		return {}
	
	var carried = player_stats.get_carried_resources()
	print("[GameManager] 📦 Carried resources: %s" % carried)
	
	if carried.is_empty():
		print("[GameManager] ℹ️ No carried resources to transfer")
		return {}
	
	var transferred := {}
	for type in carried.keys():
		var amount: int = int(carried[type])
		if amount > 0:
			print("[GameManager] ➕ Adding %d %s to village resources" % [amount, type])
			add_resource(type, amount)
			transferred[type] = amount
			
			# Also add to VillageManager.resource_levels for UI display
			var village_manager = get_node_or_null("/root/VillageManager")
			if village_manager:
				var current = village_manager.resource_levels.get(type, 0)
				village_manager.resource_levels[type] = current + amount
				print("[GameManager] ➕ Also added %d %s to VillageManager.resource_levels (total: %d)" % [amount, type, village_manager.resource_levels[type]])
		else:
			print("[GameManager] ⏭️ Skipping %s (amount: %d)" % [type, amount])
	
	print("[GameManager] 🧹 Clearing carried resources from PlayerStats")
	player_stats.clear_carried_resources()
	
	print("[GameManager] ✅ Transfer complete. Transferred: %s" % transferred)
	return transferred