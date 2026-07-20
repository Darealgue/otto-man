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
	# Normal kapı: tek eksende standart artış (düşman+tuzak+sayı aynı anda sıçramasın)
	var data: Dictionary = {
		"enemy_level_delta": 0 if is_initial else 1,
		"enemy_count_delta": 0,
		"trap_level_delta": 0,
		"trap_count_delta": 0,
		"gold_multiplier_delta": 0.0,
		"dungeon_size_delta": 0,
		"guaranteed_rescue": false,
		"is_normal": true,
		"modifiers": [],
	}
	data["risk_score"] = _calc_risk_score(data)
	data["risk_tier"] = _get_risk_tier(data["risk_score"])
	data["label_short"] = _build_minimal_label(data)
	return data

## Kapı üstündeki her ödül sembolü (altın veya kurtarma kalbi) seçilen ekseni +1 daha zorlaştırır.
const GOLD_PER_COIN_SYMBOL: float = 0.35
const RESCUE_SYMBOL_CHANCE: float = 0.35

func _make_procedural_door() -> Dictionary:
	# Tek kapı = tek eksen (düşman VEYA tuzak); harita büyütme kaldırıldı.
	# WYSIWYG: taban +1, kapıda görünen her ödül sembolü aynı ekseni +1 daha artırır.
	var risk_categories: Array = [
		["enemy_level_delta", "enemy_count_delta"],
		["trap_level_delta", "trap_count_delta"],
	]
	var category: Array = risk_categories[randi() % risk_categories.size()]
	var key: String = category[randi() % category.size()]

	var data: Dictionary = {
		"enemy_level_delta": 0,
		"enemy_count_delta": 0,
		"trap_level_delta": 0,
		"trap_count_delta": 0,
		"gold_multiplier_delta": 0.0,
		"dungeon_size_delta": 0,
		"guaranteed_rescue": false,
		"is_normal": false,
		"modifiers": [],
	}

	# Kaç ödül sembolü olacağını önce belirle; kapının zorluk artışı bununla birebir eşleşsin.
	var bonus_symbol_count: int = _roll_bonus_symbol_count()
	var gold_symbol_count: int = bonus_symbol_count
	if bonus_symbol_count > 0 and randf() < RESCUE_SYMBOL_CHANCE:
		data["guaranteed_rescue"] = true
		gold_symbol_count -= 1

	data[key] = 1 + bonus_symbol_count
	if gold_symbol_count > 0:
		data["gold_multiplier_delta"] = GOLD_PER_COIN_SYMBOL * gold_symbol_count

	_apply_random_modifier(data)

	data["risk_score"] = _calc_risk_score(data)
	data["risk_tier"] = _get_risk_tier(data["risk_score"])
	data["label_short"] = _build_minimal_label(data)
	return data

## 0-2 arası ekstra ödül sembolü — her biri seçilen ekseni +1 daha zorlaştırır (taban 1, tavan 3).
func _roll_bonus_symbol_count() -> int:
	var roll := randf()
	if roll < 0.45:
		return 0
	elif roll < 0.8:
		return 1
	else:
		return 2

func _apply_random_modifier(data: Dictionary) -> void:
	if randf() > MODIFIER_ROLL_CHANCE:
		return
	var mod_id: String = MODIFIER_IDS[randi() % MODIFIER_IDS.size()]
	var def: Dictionary = MODIFIER_DEFS.get(mod_id, {})
	if def.is_empty():
		return
	data["modifiers"] = [mod_id]
	data["gold_multiplier_delta"] = float(data.get("gold_multiplier_delta", 0.0)) + float(def.get("gold_bonus", 0.0))
	if bool(def.get("force_rescue", false)):
		data["guaranteed_rescue"] = true
	elif float(def.get("rescue_boost", 0.0)) > 0.0 and randf() < float(def.get("rescue_boost", 0.0)):
		data["guaranteed_rescue"] = true

func _modifier_risk_total(data: Dictionary) -> int:
	var total := 0
	var mods: Variant = data.get("modifiers", [])
	if not (mods is Array):
		return 0
	for m in mods:
		var def: Dictionary = MODIFIER_DEFS.get(String(m), {})
		total += int(def.get("risk_score", 0))
	return total

## Toplam risk puanı: ağırlıklı toplam + modifier risk
func _calc_risk_score(data: Dictionary) -> int:
	return int(data.get("enemy_level_delta", 0)) \
		+ int(data.get("enemy_count_delta", 0)) \
		+ int(data.get("trap_level_delta", 0)) \
		+ int(data.get("trap_count_delta", 0)) \
		+ int(data.get("dungeon_size_delta", 0)) * 2 \
		+ _modifier_risk_total(data)

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

## Kap\u0131 etiketindeki ger\u00e7ek ikon \u00e7izimleri (rescue/trap yeni eklendi, gold zaten vard\u0131).
## D\u00fc\u015fman ekseni i\u00e7in hen\u00fcz kendi ikonu yok \u2014 kurukafa placeholder olarak kal\u0131yor.
const GOLD_ICON_PATH := "res://assets/Icons/gold_icon.png"
const RESCUE_ICON_PATH := "res://assets/Icons/rescue_icon.png"
const TRAP_ICON_PATH := "res://assets/Icons/trap_icon.png"
const DOOR_ICON_PX := 25

func _icon_bbcode(path: String) -> String:
	return "[img=%dx%d]%s[/img]" % [DOOR_ICON_PX, DOOR_ICON_PX, path]

## Segment modifier havuzu — risk karşılığı altın / kurtarma bonusu
const MODIFIER_DEFS: Dictionary = {
	"no_parry": {
		"risk_score": 1,
		"gold_bonus": 0.35,
		"label": "[color=#ff8866]Parry yok[/color]",
	},
	"no_heal": {
		"risk_score": 1,
		"gold_bonus": 0.4,
		"rescue_boost": 0.35,
		"label": "[color=#66aaff]İyileşme yok[/color]",
	},
	"night_mode": {
		"risk_score": 1,
		"gold_bonus": 0.25,
		"label": "[color=#8888cc]Gece[/color]",
	},
	"light_only": {
		"risk_score": 2,
		"gold_bonus": 0.55,
		"force_rescue": true,
		"label": "[color=#ffcc44]Sadece hafif[/color]",
	},
}
const MODIFIER_IDS: Array[String] = ["no_parry", "no_heal", "night_mode", "light_only"]
const MODIFIER_ROLL_CHANCE: float = 0.48

## Oyuncuya gösterilecek etiket: üst satır hangi ekseni ne kadar zorlaştırdığı (WYSIWYG —
## ikon sayısı = eklenen miktar), alt satır ödül ikonları (altın/kurtarma) + varsa modifier.
func _build_minimal_label(data: Dictionary) -> String:
	var tier: int = int(data.get("risk_tier", RiskTier.SAFE))
	var tier_color: String = RISK_TIER_COLORS.get(tier, "white")

	var trap_amount: int = int(data.get("trap_level_delta", 0)) + int(data.get("trap_count_delta", 0))
	var enemy_amount: int = int(data.get("enemy_level_delta", 0)) + int(data.get("enemy_count_delta", 0))

	var axis_text: String
	if trap_amount > 0:
		axis_text = "[color=%s]%s[/color]" % [tier_color, _icon_bbcode(TRAP_ICON_PATH).repeat(trap_amount)]
	elif enemy_amount > 0:
		axis_text = "[color=%s]%s[/color]" % [tier_color, SKULL.repeat(enemy_amount)]
	else:
		axis_text = "[color=%s]Güvenli[/color]" % tier_color

	var reward_parts: Array = []
	if float(data.get("gold_multiplier_delta", 0.0)) > 0.0:
		var gold_icons: int = 1
		var gd_val: float = float(data.get("gold_multiplier_delta", 0.0))
		if gd_val >= 0.75:
			gold_icons = 3
		elif gd_val >= 0.5:
			gold_icons = 2
		reward_parts.append(_icon_bbcode(GOLD_ICON_PATH).repeat(gold_icons))
	if bool(data.get("guaranteed_rescue", false)):
		reward_parts.append(_icon_bbcode(RESCUE_ICON_PATH))

	var mods: Variant = data.get("modifiers", [])
	if mods is Array:
		for m in mods:
			var def: Dictionary = MODIFIER_DEFS.get(String(m), {})
			var mod_label: String = String(def.get("label", String(m)))
			if not mod_label.is_empty():
				reward_parts.append(mod_label)

	if reward_parts.is_empty():
		return axis_text
	return axis_text + "  " + "  ".join(reward_parts)

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
		"guaranteed_rescue", "is_normal", "modifiers"
	]
	for k in keys:
		if a.get(k) != b.get(k):
			return false
	return true
