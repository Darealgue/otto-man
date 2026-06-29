extends Node
## Zindan başına tamamlama sayısı — aynı zindanda farm yerine diğerlerini keşfetmeyi teşvik eder.
## Her tamamlama, o zindanın bir sonraki run'ında +1 başlangıç zorluğu verir.
## Mastery relic: aynı zindanda artan clear sayısı kalıcı run bonusları açar.

const VILLAGE_DUNGEON_ID: String = "village_portal"
const BOSS_HP_PER_CLEAR: float = 50.0
const STEALTH_SKIP_ENEMY_PENALTY: int = 1

const RELIC_UNLOCK_ORDER: Array[String] = ["steady_heart", "lucky_pouch", "iron_will"]

const RELICS: Dictionary = {
	"steady_heart": {
		"name": "Sağlam Kalp",
		"clears_required": 1,
		"desc": "Run boyunca +10 maksimum can.",
	},
	"lucky_pouch": {
		"name": "Uğurlu Kese",
		"clears_required": 2,
		"desc": "Run boyunca çıkış altını +%12.",
	},
	"iron_will": {
		"name": "Demir İrade",
		"clears_required": 3,
		"desc": "Run başında bir düşman grubu daha az.",
	},
}

var active_dungeon_id: String = VILLAGE_DUNGEON_ID
var _clears_by_id: Dictionary = {}  # dungeon_id (String) -> int
var _stealth_skip_penalty_by_id: Dictionary = {}  # dungeon_id -> bekleyen düşman sayısı cezası
var _unlocked_relics: Array[String] = []


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
	_try_unlock_relics_for_dungeon(key)


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


func get_relic_display_name(relic_id: String) -> String:
	if RELICS.has(relic_id):
		return String(RELICS[relic_id].get("name", relic_id))
	return relic_id


func get_unlocked_relics() -> Array[String]:
	return _unlocked_relics.duplicate()


func pick_run_relic() -> String:
	if _unlocked_relics.is_empty():
		return ""
	return _unlocked_relics[_unlocked_relics.size() - 1]


func apply_run_start_bonuses(drs: Node) -> void:
	if not is_instance_valid(drs):
		return
	var relic_id: String = pick_run_relic()
	if relic_id.is_empty():
		return
	if "run_active_relic_id" in drs:
		drs.run_active_relic_id = relic_id
	match relic_id:
		"steady_heart":
			if drs.has_method("_apply_relic_max_hp_bonus"):
				drs.call("_apply_relic_max_hp_bonus", 10.0)
		"lucky_pouch":
			if "gold_multiplier_accumulated" in drs:
				drs.gold_multiplier_accumulated = float(drs.gold_multiplier_accumulated) + 0.12
		"iron_will":
			if "enemy_count_offset" in drs:
				drs.enemy_count_offset = int(drs.enemy_count_offset) - 1
	print("[DungeonProgress] Mastery relic aktif: %s" % get_relic_display_name(relic_id))


func _try_unlock_relics_for_dungeon(dungeon_id: String) -> void:
	var count: int = get_clear_count(dungeon_id)
	for relic_id in RELIC_UNLOCK_ORDER:
		if relic_id in _unlocked_relics:
			continue
		var req: int = int(RELICS.get(relic_id, {}).get("clears_required", 99))
		if count >= req:
			_unlock_relic(relic_id, dungeon_id)


func _unlock_relic(relic_id: String, dungeon_id: String) -> void:
	if relic_id in _unlocked_relics:
		return
	_unlocked_relics.append(relic_id)
	var relic_name: String = get_relic_display_name(relic_id)
	var desc: String = String(RELICS.get(relic_id, {}).get("desc", ""))
	print("[DungeonProgress] Mastery relic açıldı: %s (zindan %s)" % [relic_name, dungeon_id])
	var mm: Node = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("post_news"):
		mm.call(
			"post_news",
			"Zindan",
			"Mastery: %s" % relic_name,
			desc,
			Color(0.85, 0.75, 1.0),
			"info"
		)


func get_save_data() -> Dictionary:
	return {
		"clears": _clears_by_id.duplicate(true),
		"stealth_skip_penalties": _stealth_skip_penalty_by_id.duplicate(true),
		"unlocked_relics": _unlocked_relics.duplicate(),
	}


func load_save_data(data: Variant) -> void:
	_clears_by_id.clear()
	_stealth_skip_penalty_by_id.clear()
	_unlocked_relics.clear()
	if not data is Dictionary:
		return
	var d: Dictionary = data as Dictionary
	if d.has("clears") and d.clears is Dictionary:
		for key in (d.clears as Dictionary).keys():
			_clears_by_id[str(key)] = maxi(0, int((d.clears as Dictionary)[key]))
	elif not d.has("stealth_skip_penalties"):
		for key in d.keys():
			if key == "unlocked_relics":
				continue
			_clears_by_id[str(key)] = maxi(0, int(d[key]))
	if d.has("stealth_skip_penalties") and d.stealth_skip_penalties is Dictionary:
		for key in (d.stealth_skip_penalties as Dictionary).keys():
			_stealth_skip_penalty_by_id[str(key)] = maxi(0, int((d.stealth_skip_penalties as Dictionary)[key]))
	if d.has("unlocked_relics") and d.unlocked_relics is Array:
		for rid in d.unlocked_relics:
			var relic_id: String = String(rid).strip_edges()
			if not relic_id.is_empty() and relic_id not in _unlocked_relics:
				_unlocked_relics.append(relic_id)
	_backfill_relics_from_clears()


func _backfill_relics_from_clears() -> void:
	var best_clear: int = 0
	for key in _clears_by_id.keys():
		best_clear = maxi(best_clear, int(_clears_by_id[key]))
	for relic_id in RELIC_UNLOCK_ORDER:
		if relic_id in _unlocked_relics:
			continue
		var req: int = int(RELICS.get(relic_id, {}).get("clears_required", 99))
		if best_clear >= req:
			_unlocked_relics.append(relic_id)
