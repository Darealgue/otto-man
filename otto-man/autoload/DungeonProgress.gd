extends Node
## Zindan başına tamamlama sayısı — aynı zindanda farm yerine diğerlerini keşfetmeyi teşvik eder.
## Her tamamlama, o zindanın bir sonraki run'ında +1 başlangıç zorluğu verir.

const VILLAGE_DUNGEON_ID: String = "village_portal"
const BOSS_HP_PER_CLEAR: float = 50.0
const STEALTH_SKIP_ENEMY_PENALTY: int = 1

var active_dungeon_id: String = VILLAGE_DUNGEON_ID
var _clears_by_id: Dictionary = {}  # dungeon_id (String) -> int
var _stealth_skip_penalty_by_id: Dictionary = {}  # dungeon_id -> bekleyen düşman sayısı cezası


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


func record_stealth_skip(dungeon_id: String = "") -> void:
	var key: String = dungeon_id if not dungeon_id.is_empty() else active_dungeon_id
	if key.is_empty():
		return
	var pending: int = int(_stealth_skip_penalty_by_id.get(key, 0))
	_stealth_skip_penalty_by_id[key] = pending + STEALTH_SKIP_ENEMY_PENALTY
	print("[DungeonProgress] Stealth skip cezası kaydedildi: %s -> +%d düşman (sonraki run)" % [key, STEALTH_SKIP_ENEMY_PENALTY])


func consume_stealth_skip_penalty(dungeon_id: String = "") -> int:
	var key: String = dungeon_id if not dungeon_id.is_empty() else active_dungeon_id
	if key.is_empty():
		return 0
	var pending: int = int(_stealth_skip_penalty_by_id.get(key, 0))
	if pending > 0:
		_stealth_skip_penalty_by_id.erase(key)
	return pending


func get_boss_max_health(base_hp: float, clear_count: int) -> float:
	return base_hp + float(maxi(0, clear_count)) * BOSS_HP_PER_CLEAR


func get_save_data() -> Dictionary:
	return {
		"clears": _clears_by_id.duplicate(true),
		"stealth_skip_penalties": _stealth_skip_penalty_by_id.duplicate(true),
	}


func load_save_data(data: Variant) -> void:
	_clears_by_id.clear()
	_stealth_skip_penalty_by_id.clear()
	if not data is Dictionary:
		return
	var d: Dictionary = data as Dictionary
	if d.has("clears") and d.clears is Dictionary:
		for key in (d.clears as Dictionary).keys():
			_clears_by_id[str(key)] = maxi(0, int((d.clears as Dictionary)[key]))
	elif not d.has("stealth_skip_penalties"):
		for key in d.keys():
			_clears_by_id[str(key)] = maxi(0, int(d[key]))
	if d.has("stealth_skip_penalties") and d.stealth_skip_penalties is Dictionary:
		for key in (d.stealth_skip_penalties as Dictionary).keys():
			_stealth_skip_penalty_by_id[str(key)] = maxi(0, int((d.stealth_skip_penalties as Dictionary)[key]))
