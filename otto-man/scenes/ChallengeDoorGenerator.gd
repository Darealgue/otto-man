extends Node
class_name ChallengeDoorGenerator

## Challenge kapıları için prosedürel veri üretir.
## Çıktı: Array[Dictionary] – her dict bir kapının challenge_data'sını ve label_short'unu içerir.

const MIN_EXTRA_DOORS: int = 2
const MAX_EXTRA_DOORS: int = 4

## Risk kademe eşikleri (toplam risk puanına göre)
enum RiskTier { SAFE, LOW, MEDIUM, HIGH, EXTREME }

const RISK_TIER_NAMES: Dictionary = {
	RiskTier.SAFE: "Güvenli",
	RiskTier.LOW: "Düşük Risk",
	RiskTier.MEDIUM: "Orta Risk",
	RiskTier.HIGH: "Yüksek Risk",
	RiskTier.EXTREME: "Aşırı Risk",
}

const RISK_TIER_COLORS: Dictionary = {
	RiskTier.SAFE: "white",
	RiskTier.LOW: "green",
	RiskTier.MEDIUM: "yellow",
	RiskTier.HIGH: "orange",
	RiskTier.EXTREME: "red",
}

func generate_doors(is_initial: bool) -> Array[Dictionary]:
	var doors: Array[Dictionary] = []

	# İlk kapı: Güvenli giriş (delta yok, ekstra zorluk eklemez)
	doors.append(_make_safe_door(is_initial))

	var extra_count := randi_range(MIN_EXTRA_DOORS, MAX_EXTRA_DOORS)
	if is_initial:
		extra_count = 2

	for i in range(extra_count):
		var data := _make_procedural_door()
		var retries := 0
		while _exists_same_challenge(doors, data) and retries < 5:
			data = _make_procedural_door()
			retries += 1
		doors.append(data)

	return doors

func _make_safe_door(is_initial: bool) -> Dictionary:
	var data: Dictionary = {
		"enemy_level_delta": 0 if is_initial else 1,
		"enemy_count_delta": 0 if is_initial else 1,
		"trap_level_delta": 0 if is_initial else 1,
		"trap_count_delta": 0 if is_initial else 1,
		"gold_multiplier_delta": 0.0,
		"dungeon_size_delta": 0,
		"guaranteed_rescue": false,
		"is_normal": true,
	}
	data["risk_score"] = _calc_risk_score(data)
	data["risk_tier"] = _get_risk_tier(data["risk_score"])
	data["label_short"] = _build_minimal_label(data)
	return data

func _make_procedural_door() -> Dictionary:
	var risk_keys: Array = ["enemy_level_delta", "enemy_count_delta", "trap_level_delta", "trap_count_delta", "dungeon_size_delta"]
	var risk_pool: Array = risk_keys.duplicate()
	risk_pool.shuffle()

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

	var total_risk: int = _calc_risk_score(data)

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

	data["risk_score"] = total_risk
	data["risk_tier"] = _get_risk_tier(total_risk)
	data["label_short"] = _build_minimal_label(data)
	return data

## Toplam risk puanı: ağırlıklı toplam
func _calc_risk_score(data: Dictionary) -> int:
	return int(data.get("enemy_level_delta", 0)) \
		+ int(data.get("enemy_count_delta", 0)) \
		+ int(data.get("trap_level_delta", 0)) \
		+ int(data.get("trap_count_delta", 0)) \
		+ int(data.get("dungeon_size_delta", 0)) * 2

## Risk puanını kademeye çevir
func _get_risk_tier(score: int) -> int:
	if score <= 0:
		return RiskTier.SAFE
	elif score <= 2:
		return RiskTier.LOW
	elif score <= 4:
		return RiskTier.MEDIUM
	elif score <= 7:
		return RiskTier.HIGH
	else:
		return RiskTier.EXTREME

const SKULL := "\u2620"
const COIN := "\u2742"
const HEART := "\u2665"

## Oyuncuya gösterilecek minimal etiket: kurukafalar (risk) + semboller (ödül)
func _build_minimal_label(data: Dictionary) -> String:
	var tier: int = int(data.get("risk_tier", RiskTier.SAFE))
	var tier_color: String = RISK_TIER_COLORS.get(tier, "white")

	var skull_count: int = tier
	var skull_text := ""
	if skull_count <= 0:
		skull_text = "[color=%s]Güvenli[/color]" % tier_color
	else:
		skull_text = "[color=%s]%s[/color]" % [tier_color, SKULL.repeat(skull_count)]

	var reward_parts: Array = []
	if float(data.get("gold_multiplier_delta", 0.0)) > 0.0:
		var gold_icons: int = 1
		var gd_val: float = float(data.get("gold_multiplier_delta", 0.0))
		if gd_val >= 0.75:
			gold_icons = 3
		elif gd_val >= 0.5:
			gold_icons = 2
		reward_parts.append("[color=yellow]%s[/color]" % COIN.repeat(gold_icons))
	if bool(data.get("guaranteed_rescue", false)):
		reward_parts.append("[color=green]%s[/color]" % HEART)

	if reward_parts.is_empty():
		return skull_text
	return skull_text + "  " + "  ".join(reward_parts)

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
