extends Node
## Köy Mucit Odası: sefer loot stoku + kalıcı karakter upgrade'leri.

signal meta_data_changed
signal upgrade_purchased(track_id: String, new_level: int)

const _MetaUpgradeConfig = preload("res://village/scripts/MetaUpgradeConfig.gd")
const _ExpeditionLootType = preload("res://resources/expedition_loot_types.gd")

var upgrade_levels: Dictionary = {
	MetaUpgradeConfig.TRACK_DAMAGE: 0,
	MetaUpgradeConfig.TRACK_HEALTH: 0,
	MetaUpgradeConfig.TRACK_STAMINA: 0,
}

## Köye teslim edilmiş sefer malzemeleri (kalıcı stok).
var village_loot: Dictionary = {
	ExpeditionLootType.RUSTY_WEAPON: 0,
	ExpeditionLootType.SKY_FEATHER: 0,
	ExpeditionLootType.HERB_BUNDLE: 0,
}

var _applied_stat_totals: Dictionary = {}


func _ready() -> void:
	for tid in _MetaUpgradeConfig.get_track_ids():
		if not upgrade_levels.has(tid):
			upgrade_levels[tid] = 0
	for lid in _ExpeditionLootType.all():
		if not village_loot.has(lid):
			village_loot[lid] = 0


func get_track_level(track_id: String) -> int:
	return int(upgrade_levels.get(track_id, 0))


func get_village_loot(loot_id: String) -> int:
	return int(village_loot.get(loot_id, 0))


func get_village_loot_snapshot() -> Dictionary:
	return village_loot.duplicate(true)


func deposit_village_loot(amounts: Dictionary) -> Dictionary:
	var deposited: Dictionary = {}
	for k in amounts.keys():
		var key := String(k)
		var amt := int(amounts[k])
		if amt <= 0 or not village_loot.has(key):
			continue
		village_loot[key] = int(village_loot.get(key, 0)) + amt
		deposited[key] = amt
	if not deposited.is_empty():
		meta_data_changed.emit()
	return deposited


func can_purchase_next(track_id: String) -> bool:
	var next_lvl := get_track_level(track_id) + 1
	if next_lvl > _MetaUpgradeConfig.get_max_level(track_id):
		return false
	var cost := _MetaUpgradeConfig.get_level_cost(track_id, next_lvl)
	return _can_afford_cost(cost)


func get_next_cost(track_id: String) -> Dictionary:
	var next_lvl := get_track_level(track_id) + 1
	return _MetaUpgradeConfig.get_level_cost(track_id, next_lvl)


func try_purchase_upgrade(track_id: String) -> bool:
	if not can_purchase_next(track_id):
		return false
	var next_lvl := get_track_level(track_id) + 1
	var cost := _MetaUpgradeConfig.get_level_cost(track_id, next_lvl)
	if not _pay_cost(cost):
		return false
	upgrade_levels[track_id] = next_lvl
	reapply_all_track_bonuses()
	upgrade_purchased.emit(track_id, next_lvl)
	meta_data_changed.emit()
	return true


func _can_afford_cost(cost: Dictionary) -> bool:
	for k in cost.keys():
		var key := String(k)
		var need := int(cost[k])
		if need <= 0:
			continue
		if _ExpeditionLootType.is_valid(key):
			if int(village_loot.get(key, 0)) < need:
				return false
		elif _is_village_resource(key):
			if int(VillageManager.resource_levels.get(key, 0)) < need:
				return false
		else:
			return false
	return true


func _pay_cost(cost: Dictionary) -> bool:
	if not _can_afford_cost(cost):
		return false
	for k in cost.keys():
		var key := String(k)
		var need := int(cost[k])
		if need <= 0:
			continue
		if _ExpeditionLootType.is_valid(key):
			village_loot[key] = int(village_loot.get(key, 0)) - need
		elif _is_village_resource(key):
			VillageManager.resource_levels[key] = int(VillageManager.resource_levels.get(key, 0)) - need
	VillageManager.emit_signal("village_data_changed")
	return true


func _is_village_resource(key: String) -> bool:
	return key in ["metal", "weapon", "medicine", "lumber", "brick"]


func _apply_track_bonus(track_id: String) -> void:
	var track: Dictionary = _MetaUpgradeConfig.TRACKS.get(track_id, {})
	var stat_name: String = String(track.get("stat", ""))
	var bonus: float = float(track.get("bonus_per_level", 0.0))
	if stat_name.is_empty() or bonus == 0.0:
		return
	var ps := get_node_or_null("/root/PlayerStats")
	if ps == null:
		return
	if ps.has_method("add_stat_bonus"):
		ps.add_stat_bonus(stat_name, bonus)
	_applied_stat_totals[stat_name] = float(_applied_stat_totals.get(stat_name, 0.0)) + bonus
	if stat_name == "max_health" and ps.has_method("_clamp_current_health_to_max"):
		ps._clamp_current_health_to_max()


func reapply_all_track_bonuses() -> void:
	_reset_meta_stat_bonuses()
	for tid in _MetaUpgradeConfig.get_track_ids():
		var lvl := get_track_level(tid)
		if lvl <= 0:
			continue
		var track: Dictionary = _MetaUpgradeConfig.TRACKS.get(tid, {})
		var stat_name: String = String(track.get("stat", ""))
		var bonus: float = float(track.get("bonus_per_level", 0.0))
		if stat_name.is_empty() or bonus == 0.0:
			continue
		var total: float = bonus * float(lvl)
		var ps := get_node_or_null("/root/PlayerStats")
		if ps and ps.has_method("add_stat_bonus"):
			ps.add_stat_bonus(stat_name, total)
			_applied_stat_totals[stat_name] = float(_applied_stat_totals.get(stat_name, 0.0)) + total
	if get_node_or_null("/root/PlayerStats") and get_node("/root/PlayerStats").has_method("_clamp_current_health_to_max"):
		get_node("/root/PlayerStats")._clamp_current_health_to_max()


func get_meta_stat_bonus_totals() -> Dictionary:
	var totals: Dictionary = {}
	for tid in _MetaUpgradeConfig.get_track_ids():
		var lvl := get_track_level(tid)
		if lvl <= 0:
			continue
		var track: Dictionary = _MetaUpgradeConfig.TRACKS.get(tid, {})
		var stat_name: String = String(track.get("stat", ""))
		var bonus: float = float(track.get("bonus_per_level", 0.0))
		if stat_name.is_empty() or bonus == 0.0:
			continue
		totals[stat_name] = float(totals.get(stat_name, 0.0)) + bonus * float(lvl)
	return totals


func _reset_meta_stat_bonuses() -> void:
	var ps := get_node_or_null("/root/PlayerStats")
	if ps == null:
		_applied_stat_totals.clear()
		return
	for stat_name in _applied_stat_totals.keys():
		var total: float = float(_applied_stat_totals[stat_name])
		if total != 0.0 and ps.has_method("add_stat_bonus"):
			ps.add_stat_bonus(String(stat_name), -total)
	_applied_stat_totals.clear()


func serialize_for_save() -> Dictionary:
	return {
		"upgrade_levels": upgrade_levels.duplicate(true),
		"village_loot": village_loot.duplicate(true),
	}


func load_from_save(data: Dictionary) -> void:
	_reset_meta_stat_bonuses()
	if data.has("upgrade_levels") and data["upgrade_levels"] is Dictionary:
		for k in (data["upgrade_levels"] as Dictionary).keys():
			upgrade_levels[String(k)] = int(data["upgrade_levels"][k])
	if data.has("village_loot") and data["village_loot"] is Dictionary:
		for k in (data["village_loot"] as Dictionary).keys():
			var key := String(k)
			if village_loot.has(key):
				village_loot[key] = maxi(0, int(data["village_loot"][k]))
	reapply_all_track_bonuses()
	meta_data_changed.emit()


func reset_for_new_game() -> void:
	_reset_meta_stat_bonuses()
	upgrade_levels = {
		MetaUpgradeConfig.TRACK_DAMAGE: 0,
		MetaUpgradeConfig.TRACK_HEALTH: 0,
		MetaUpgradeConfig.TRACK_STAMINA: 0,
	}
	village_loot = {
		ExpeditionLootType.RUSTY_WEAPON: 0,
		ExpeditionLootType.SKY_FEATHER: 0,
		ExpeditionLootType.HERB_BUNDLE: 0,
	}
	meta_data_changed.emit()
