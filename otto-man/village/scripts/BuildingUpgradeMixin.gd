class_name BuildingUpgradeMixin
extends RefCounted
## Ortak bina yükseltme akışı — maliyet SSOT: BuildingUpgradeConfig + VillageManager.


static func get_next_cost(building: Node) -> Dictionary:
	if not is_instance_valid(building):
		return {}
	if VillageManager.has_method("get_building_upgrade_cost"):
		return VillageManager.get_building_upgrade_cost(building)
	return {}


static func can_start(building: Node) -> bool:
	if not is_instance_valid(building):
		return false
	if "is_upgrading" in building and bool(building.is_upgrading):
		return false
	var max_lvl := _max_level(building)
	var lvl := int(building.level) if "level" in building else 1
	if lvl >= max_lvl:
		return false
	var cost := get_next_cost(building)
	if cost.is_empty():
		return false
	return VillageManager.can_pay_village_cost(cost)


static func start(building: Node) -> bool:
	if not can_start(building):
		return false
	var cost := get_next_cost(building)
	if not VillageManager.try_pay_village_cost(cost):
		return false
	if VillageManager.has_method("prepare_building_upgrade"):
		VillageManager.prepare_building_upgrade(building)
	building.is_upgrading = true
	if "upgrade_timer" in building and building.upgrade_timer:
		var wait := float(building.upgrade_time_seconds) if "upgrade_time_seconds" in building else 10.0
		building.upgrade_timer.wait_time = wait
		building.upgrade_timer.start()
	if building.has_signal("upgrade_started"):
		building.upgrade_started.emit()
	if building.has_signal("state_changed"):
		building.state_changed.emit()
	return true


static func _max_level(building: Node) -> int:
	var path := String(building.scene_file_path) if "scene_file_path" in building else ""
	var config_max := BuildingUpgradeConfig.get_max_level(path) if not path.is_empty() else 1
	if "max_level" in building:
		return maxi(int(building.max_level), config_max)
	return config_max
