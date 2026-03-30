extends Node
class_name ChallengeDoorGenerator

## Challenge kapıları için prosedürel veri üretir.
## Çıktı: Array[Dictionary] – her dict bir kapının challenge_data'sını ve label_short'unu içerir.

const MIN_EXTRA_DOORS: int = 2
const MAX_EXTRA_DOORS: int = 4

func generate_doors(is_initial: bool) -> Array[Dictionary]:
	var doors: Array[Dictionary] = []

	# 0: Normal kapı (sabit)
	doors.append(_make_normal_door())

	# Kaç adet ekstra prosedürel kapı?
	var extra_count := randi_range(MIN_EXTRA_DOORS, MAX_EXTRA_DOORS)
	if is_initial:
		extra_count = 2

	for i in range(extra_count):
		var data := _make_procedural_door()
		# Aynı kamp içinde birebir aynı kapı olmasın
		var retries := 0
		while _exists_same_challenge(doors, data) and retries < 5:
			data = _make_procedural_door()
			retries += 1
		doors.append(data)

	return doors

func _make_normal_door() -> Dictionary:
	var data: Dictionary = {
		"enemy_level_delta": 1,
		"enemy_count_delta": 1,
		"trap_level_delta": 1,
		"trap_count_delta": 1,
		"gold_multiplier_delta": 0.0,
		"dungeon_size_delta": 0,
		"guaranteed_rescue": false,
		"is_normal": true,
	}
	data["label_short"] = "Normal (standart artan zorluk)"
	return data

func _make_procedural_door() -> Dictionary:
	var risk_keys: Array = ["enemy_level_delta", "enemy_count_delta", "trap_level_delta", "trap_count_delta", "dungeon_size_delta"]
	var risk_pool: Array = risk_keys.duplicate()
	risk_pool.shuffle()

	# En az 2 ceza + her zaman ödül: kapıda hem kırmızı hem yeşil görünsün
	var risk_count := randi_range(2, 3)
	var data: Dictionary = {
		"enemy_level_delta": 0,
		"enemy_count_delta": 0,
		"trap_level_delta": 0,
		"trap_count_delta": 0,
		"gold_multiplier_delta": 0.0,
		"dungeon_size_delta": 0,
		"guaranteed_rescue": false,
		"is_normal": false,
	}

	for i in range(risk_count):
		if i >= risk_pool.size():
			break
		var key: String = risk_pool[i]
		match key:
			"enemy_level_delta", "enemy_count_delta", "trap_level_delta":
				data[key] = randi_range(1, 3)
			"trap_count_delta":
				data[key] = randi_range(0, 2)
			"dungeon_size_delta":
				data[key] = randi_range(0, 1)

	# Ödüller
	var total_risk: int = int(data["enemy_level_delta"]) + int(data["enemy_count_delta"]) \
		+ int(data["trap_level_delta"]) + int(data["trap_count_delta"]) + int(data["dungeon_size_delta"])

	# Prosedürel kapıda en az bir ödül olsun (yeşil yazı görünsün)
	var reward_count := randi_range(1, 2)
	var use_rescue := false
	if reward_count > 0 and randf() < 0.45:
		use_rescue = true
		data["guaranteed_rescue"] = true

	var gold_delta := 0.0
	if total_risk <= 2:
		gold_delta = _pick_from([0.25, 0.5])
	elif total_risk <= 4:
		gold_delta = _pick_from([0.25, 0.5, 0.75])
	else:
		gold_delta = _pick_from([0.5, 0.75, 1.0])
	data["gold_multiplier_delta"] = gold_delta

	data["label_short"] = _build_label_for_data(data, use_rescue)
	return data

func _build_label_for_data(data: Dictionary, use_rescue: bool) -> String:
	var parts: Array = []
	if int(data["enemy_level_delta"]) > 0:
		parts.append("+%d düşman seviyesi" % int(data["enemy_level_delta"]))
	if int(data["enemy_count_delta"]) > 0:
		parts.append("+%d düşman yoğunluğu" % int(data["enemy_count_delta"]))
	if int(data["trap_level_delta"]) > 0:
		parts.append("+%d tuzak seviyesi" % int(data["trap_level_delta"]))
	if int(data["trap_count_delta"]) > 0:
		parts.append("+%d tuzak yoğunluğu" % int(data["trap_count_delta"]))
	if int(data["dungeon_size_delta"]) > 0:
		parts.append("+%d zindan boyutu" % int(data["dungeon_size_delta"]))
	if float(data["gold_multiplier_delta"]) > 0.0:
		parts.append("altın x+%.2f" % float(data["gold_multiplier_delta"]))
	if bool(data["guaranteed_rescue"]):
		parts.append("garanti kurtarma odası")

	if parts.is_empty():
		return "Hafif risk"
	var s := ""
	for i in range(parts.size()):
		if i > 0:
			s += ", "
		s += str(parts[i])
	return s

func _exists_same_challenge(existing: Array, candidate: Dictionary) -> bool:
	for e in existing:
		if not (e is Dictionary):
			continue
		if _compare_challenge_dicts(e, candidate):
			return true
	return false

func _compare_challenge_dicts(a: Dictionary, b: Dictionary) -> bool:
	var keys := [
		"enemy_level_delta", "enemy_count_delta", "trap_level_delta",
		"trap_count_delta", "gold_multiplier_delta", "dungeon_size_delta",
		"guaranteed_rescue", "is_normal"
	]
	for k in keys:
		if a.get(k) != b.get(k):
			return false
	return true

func _pick_from(values: Array) -> float:
	if values.is_empty():
		return 0.0
	return float(values[randi() % values.size()])
