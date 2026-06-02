extends Node
## Zindan başına tamamlama sayısı — aynı zindanda farm yerine diğerlerini keşfetmeyi teşvik eder.
## Her tamamlama, o zindanın bir sonraki run'ında +1 başlangıç zorluğu verir.

const VILLAGE_DUNGEON_ID: String = "village_portal"
const BOSS_HP_PER_CLEAR: float = 50.0

var active_dungeon_id: String = VILLAGE_DUNGEON_ID
var _clears_by_id: Dictionary = {}  # dungeon_id (String) -> int


func id_from_hex(q: int, r: int) -> String:
	return "%d,%d" % [q, r]


func set_active_dungeon_from_payload(payload: Dictionary) -> void:
	var id: String = String(payload.get("dungeon_id", "")).strip_edges()
	if id.is_empty():
		active_dungeon_id = VILLAGE_DUNGEON_ID
	else:
		active_dungeon_id = id


func get_clear_count(dungeon_id: String = "") -> int:
	var key: String = dungeon_id if not dungeon_id.is_empty() else active_dungeon_id
	return maxi(0, int(_clears_by_id.get(key, 0)))


func record_clear(dungeon_id: String = "") -> void:
	var key: String = dungeon_id if not dungeon_id.is_empty() else active_dungeon_id
	if key.is_empty():
		return
	_clears_by_id[key] = get_clear_count(key) + 1


func get_boss_max_health(base_hp: float, clear_count: int) -> float:
	return base_hp + float(maxi(0, clear_count)) * BOSS_HP_PER_CLEAR


func get_save_data() -> Dictionary:
	return _clears_by_id.duplicate(true)


func load_save_data(data: Variant) -> void:
	_clears_by_id.clear()
	if not data is Dictionary:
		return
	for key in (data as Dictionary).keys():
		_clears_by_id[str(key)] = maxi(0, int((data as Dictionary)[key]))
