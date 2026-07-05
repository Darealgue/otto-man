# PlayerStats.gd
# Central singleton for managing all player statistics and modifications.
# 
# This is the SINGLE SOURCE OF TRUTH for all player stats.
# All stat modifications MUST go through this system.
#
# How to use:
# 1. Get stats using get_stat() or helper functions
# 2. Modify stats using add_stat_bonus() or add_stat_multiplier()
# 3. Listen to stat_changed signal to react to changes
#
# Stats are calculated as: (base_value * multiplier) + bonus
# - base_stats: Initial values
# - stat_multipliers: Percentage-based modifications (start at 1.0 = 100%)
# - stat_bonuses: Flat additions/subtractions (start at 0)
#
# Important: 
# - Never modify player stats directly - always use this system
# - Powerups should use add_stat_multiplier() for percentage changes
# - Use add_stat_bonus() for flat value changes
# - Always check get_stat() return value before using
#
# Example:
# var current_max_health = PlayerStats.get_stat("max_health")
# PlayerStats.add_stat_multiplier("max_health", 1.2) # Increase by 20%
# PlayerStats.add_stat_bonus("max_health", 50) # Add flat 50 HP

extends Node

signal stat_changed(stat_name: String, old_value: float, new_value: float)
signal health_changed(new_health: float)
signal player_died()
signal carried_resources_changed(new_totals: Dictionary)
signal carried_resources_lost(losses: Dictionary)
signal expedition_loot_changed(new_totals: Dictionary)
signal world_expedition_supplies_changed(new_totals: Dictionary)
signal death_recovery_updated(state: Dictionary)

const ResourceType = preload("res://resources/resource_types.gd")
const ExpeditionLootType = preload("res://resources/expedition_loot_types.gd")
static var RESOURCE_TYPES := ResourceType.all()

var resource_loss_fraction_on_hit := 0.2
var min_resource_loss_per_hit := 1
## Orman biyomunda hasar: PlayerStats.lose_dungeon_gold_on_damage (zindanda uygulanmaz).
var dungeon_gold_loss_fraction_on_hit := 0.2
const VILLAGE_HEAL_TO_FULL_MINUTES: int = 180
const DEATH_DEBUFF_CHANCE: float = 0.35
const DEATH_DEBUFF_DURATION_DAYS_MIN: int = 1
const DEATH_DEBUFF_DURATION_DAYS_MAX: int = 3

var death_recovery_state := {
	"is_recovering": false,
	"was_recently_dead": false,
	"minutes_until_full_heal": 0,
	"heal_per_minute": 0.0,
	"debuff_minutes_left": 0, # Legacy/summary alan
	"debuff_name": "", # Legacy/summary alan
	"max_health_multiplier": 1.0,
	"stamina_penalty": 0,
	"stamina_regen_multiplier": 1.0,
	"heavy_attack_locked": false,
	"fall_attack_locked": false,
	"active_debuffs": [], # [{name, max_health_multiplier, stamina_penalty, stamina_regen_multiplier, heavy_attack_locked, fall_attack_locked, minutes_left}]
}
var _active_death_debuffs: Array[Dictionary] = []
var _death_run_id: int = 0
var _healed_mentor_brief_pending: bool = false
var _death_max_health_multiplier: float = 1.0
var _death_stamina_penalty: int = 0
var _death_stamina_regen_multiplier: float = 1.0
var _death_heavy_attack_locked: bool = false
var _death_fall_attack_locked: bool = false
const DEATH_DEBUFF_POOL := [
	{
		"name": "Kirik Kaburga",
		"max_health_multiplier": 0.75,
		"stamina_penalty": 0,
		"stamina_regen_multiplier": 1.0,
		"heavy_attack_locked": false,
		"fall_attack_locked": false,
	},
	{
		"name": "Bel Tutulmasi",
		"max_health_multiplier": 1.0,
		"stamina_penalty": 0,
		"stamina_regen_multiplier": 1.0,
		"heavy_attack_locked": true,
		"fall_attack_locked": false,
	},
	{
		"name": "Denge Kaybi",
		"max_health_multiplier": 1.0,
		"stamina_penalty": 0,
		"stamina_regen_multiplier": 1.0,
		"heavy_attack_locked": false,
		"fall_attack_locked": true,
	}
]

# Base stats
var base_stats = {
	"max_health": 100.0,
	"base_damage": 10.0,
	"fall_attack_damage": 10.0,
	"movement_speed": 600.0,
	"jump_force": 600.0,
	"shield_cooldown": 15.0,
	"dash_cooldown": 1.2,
	"block_charges": 3,
	"dash_charges": 1,  # Add dash charges stat
}

# Current health tracking
var current_health: float = 100.0

# Multipliers for each stat (start at 1.0 = 100%)
var stat_multipliers = {
	"max_health": 1.0,
	"base_damage": 1.0,
	"fall_attack_damage": 1.0,
	"movement_speed": 1.0,
	"jump_force": 1.0,
	"shield_cooldown": 1.0,
	"dash_cooldown": 1.0,
	"block_charges": 1.0,
	"dash_charges": 1.0,  # Add dash charges multiplier
}

# Flat bonuses (start at 0)
var stat_bonuses = {
	"max_health": 0.0,
	"base_damage": 0.0,
	"fall_attack_damage": 0.0,
	"movement_speed": 0.0,
	"jump_force": 0.0,
	"shield_cooldown": 0.0,
	"dash_cooldown": 0.0,
	"block_charges": 0.0,
	"dash_charges": 0.0,  # Add dash charges bonus
}

var carried_resources := {
	ResourceType.WOOD: 0,
	ResourceType.STONE: 0,
	ResourceType.FOOD: 0,
}

## Sefer loot'u — ölünce kaybolur; köye güvenli dönüşte Mucit stokuna aktarılır.
var carried_expedition_loot := {
	ExpeditionLootType.RUSTY_WEAPON: 0,
	ExpeditionLootType.SKY_FEATHER: 0,
	ExpeditionLootType.HERB_BUNDLE: 0,
}

## Dunya haritasi seyahati: koy stogundan alinan erzak / cep altini (zindan carried ile karisirma).
var world_expedition_supplies := {
	"food": 0,
	"medicine": 0,
	"world_gold": 0,
}
## Yol cantasi tavanlari (ileride item/upgrade ile artirilacak).
const WORLD_EXP_FOOD_PACK_CAP: int = 1
const WORLD_EXP_MEDICINE_PACK_CAP: int = 24
const WORLD_EXP_GOLD_PACK_CAP: int = 2500
var _world_exp_food_debt: float = 0.0
## Harita seferi tuketim ritmi: yemek (~12 saatte 1 birim).
const WORLD_EXP_FOOD_MINUTES_PER_UNIT: float = 720.0
## Eski: ac/susuzda can kaybi. Artik erzak bitince haritada cokus (olum) tetiklenir.
const WORLD_EXP_STARVATION_HP: float = 2.0


# Get the final value of a stat after all multipliers and bonuses
func get_stat(stat_name: String) -> float:
	if !base_stats.has(stat_name):
		push_error("[PlayerStats] Trying to get invalid stat: " + stat_name)
		return 0.0
		
	var base = base_stats[stat_name]
	var multiplier = stat_multipliers[stat_name]
	var bonus = stat_bonuses[stat_name]
	
	var final_value: float = (base * multiplier) + bonus
	if stat_name == "max_health":
		final_value *= _death_max_health_multiplier
	elif stat_name == "block_charges":
		final_value = maxf(1.0, final_value - float(_death_stamina_penalty))
	return final_value

func _ready() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm and tm.has_signal("minute_changed") and not tm.minute_changed.is_connected(_on_time_minute_changed):
		tm.minute_changed.connect(_on_time_minute_changed)
	if tm and tm.has_signal("time_advanced") and not tm.time_advanced.is_connected(_on_time_advanced_recovery):
		tm.time_advanced.connect(_on_time_advanced_recovery)

func _on_time_minute_changed(_new_minute: int) -> void:
	_process_death_recovery_minute()

func _on_time_advanced_recovery(total_minutes: int, _start_day: int, _start_hour: int, _start_minute: int) -> void:
	process_village_recovery_minutes(total_minutes)

## Zaman atlama (kamp ateşi, yolculuk dönüşü vb.) sırasında biriken iyileşme/debuff süresi.
func process_village_recovery_minutes(total_minutes: int) -> void:
	if total_minutes <= 0:
		return
	if _can_village_health_recover() and current_health < get_max_health() - 0.01:
		if not bool(death_recovery_state.get("is_recovering", false)):
			start_village_health_recovery()
	for _i in range(total_minutes):
		_process_death_recovery_minute()
		if not bool(death_recovery_state.get("is_recovering", false)) and _active_death_debuffs.is_empty():
			break

func _is_in_village_scene() -> bool:
	var sm := get_node_or_null("/root/SceneManager")
	if not sm:
		return false
	var path: String = String(sm.get("current_scene_path"))
	if path.is_empty():
		return false
	return path == "res://village/scenes/VillageScene.tscn" or "village" in path.to_lower()


func _can_village_health_recover() -> bool:
	if not _is_in_village_scene():
		return false
	var sm := get_node_or_null("/root/SceneManager")
	if sm != null and sm.has_method("is_world_map_ui_context_active"):
		if bool(sm.call("is_world_map_ui_context_active")):
			var wm := get_node_or_null("/root/WorldManager")
			if wm != null and wm.has_method("is_player_on_own_village_hex"):
				return bool(wm.call("is_player_on_own_village_hex"))
			return false
	return true

func mark_death_injury() -> void:
	var max_health: float = get_max_health()
	var start_health: float = minf(1.0, max_health)
	current_health = clampf(start_health, 0.0, max_health)
	health_changed.emit(current_health)
	_death_run_id += 1
	_healed_mentor_brief_pending = false
	death_recovery_state["is_recovering"] = true
	death_recovery_state["was_recently_dead"] = true
	death_recovery_state["mentor_brief_pending"] = true
	death_recovery_state["death_run_id"] = _death_run_id
	death_recovery_state["minutes_until_full_heal"] = VILLAGE_HEAL_TO_FULL_MINUTES
	death_recovery_state["heal_per_minute"] = max_health / float(VILLAGE_HEAL_TO_FULL_MINUTES)
	_roll_death_debuff()
	_emit_death_recovery_updated()

func start_village_health_recovery() -> void:
	var max_health: float = get_max_health()
	if max_health <= 0.0:
		return
	var missing: float = maxf(0.0, max_health - current_health)
	if missing <= 0.0:
		death_recovery_state["is_recovering"] = false
		death_recovery_state["minutes_until_full_heal"] = 0
		death_recovery_state["heal_per_minute"] = 0.0
		_emit_death_recovery_updated()
		return
	var heal_per_minute: float = max_health / float(VILLAGE_HEAL_TO_FULL_MINUTES)
	heal_per_minute = maxf(0.01, heal_per_minute)
	var mins_needed: int = int(ceili(missing / heal_per_minute))
	death_recovery_state["is_recovering"] = true
	death_recovery_state["minutes_until_full_heal"] = maxi(1, mins_needed)
	death_recovery_state["heal_per_minute"] = heal_per_minute
	_emit_death_recovery_updated()

func _roll_death_debuff() -> void:
	if randf() > DEATH_DEBUFF_CHANCE:
		return
	var tm := get_node_or_null("/root/TimeManager")
	var minutes_per_day: int = 1440
	if tm and "MINUTES_PER_HOUR" in tm and "HOURS_PER_DAY" in tm:
		minutes_per_day = int(tm.MINUTES_PER_HOUR) * int(tm.HOURS_PER_DAY)
	var duration_days: int = randi_range(DEATH_DEBUFF_DURATION_DAYS_MIN, DEATH_DEBUFF_DURATION_DAYS_MAX)
	var picked: Dictionary = DEATH_DEBUFF_POOL[randi() % DEATH_DEBUFF_POOL.size()]
	var picked_name: String = String(picked.get("name", "Yaralanma"))
	var total_minutes: int = duration_days * minutes_per_day
	var refreshed_existing: bool = false
	for i in range(_active_death_debuffs.size()):
		var active: Dictionary = _active_death_debuffs[i]
		if String(active.get("name", "")) == picked_name:
			active["minutes_left"] = total_minutes
			_active_death_debuffs[i] = active
			refreshed_existing = true
			break
	if not refreshed_existing:
		_active_death_debuffs.append({
			"name": picked_name,
			"max_health_multiplier": float(picked.get("max_health_multiplier", 1.0)),
			"stamina_penalty": int(picked.get("stamina_penalty", 0)),
			"stamina_regen_multiplier": float(picked.get("stamina_regen_multiplier", 1.0)),
			"heavy_attack_locked": bool(picked.get("heavy_attack_locked", false)),
			"fall_attack_locked": bool(picked.get("fall_attack_locked", false)),
			"minutes_left": total_minutes,
		})
	_recalculate_death_debuff_modifiers()
	_clamp_current_health_to_max()
	_emit_penalty_stat_refresh()

func _process_death_recovery_minute() -> void:
	var changed: bool = false
	if _can_village_health_recover() and bool(death_recovery_state.get("is_recovering", false)):
		var heal_amount: float = float(death_recovery_state.get("heal_per_minute", 0.0))
		if heal_amount > 0.0 and current_health < get_max_health():
			current_health = minf(get_max_health(), current_health + heal_amount)
			health_changed.emit(current_health)
			changed = true
		var mins_left: int = max(0, int(death_recovery_state.get("minutes_until_full_heal", 0)) - 1)
		death_recovery_state["minutes_until_full_heal"] = mins_left
		if current_health >= get_max_health() or mins_left <= 0:
			death_recovery_state["is_recovering"] = false
			if bool(death_recovery_state.get("was_recently_dead", false)) and current_health >= get_max_health() - 0.01:
				death_recovery_state["was_recently_dead"] = false
				_healed_mentor_brief_pending = true
		changed = true
	if _active_death_debuffs.size() > 0:
		for i in range(_active_death_debuffs.size() - 1, -1, -1):
			var deb: Dictionary = _active_death_debuffs[i]
			var mins: int = int(deb.get("minutes_left", 0))
			if mins > 0:
				deb["minutes_left"] = mins - 1
				_active_death_debuffs[i] = deb
				changed = true
			if int(deb.get("minutes_left", 0)) <= 0:
				_active_death_debuffs.remove_at(i)
				changed = true
		if changed:
			_recalculate_death_debuff_modifiers()
			_clamp_current_health_to_max()
			_emit_penalty_stat_refresh()
	if changed:
		_emit_death_recovery_updated()

func _clear_death_debuff(emit_refresh: bool) -> void:
	var had_debuff: bool = _active_death_debuffs.size() > 0
	_active_death_debuffs.clear()
	_recalculate_death_debuff_modifiers()
	if emit_refresh and had_debuff:
		_clamp_current_health_to_max()
		_emit_penalty_stat_refresh()

func _recalculate_death_debuff_modifiers() -> void:
	_death_max_health_multiplier = 1.0
	_death_stamina_penalty = 0
	_death_stamina_regen_multiplier = 1.0
	_death_heavy_attack_locked = false
	_death_fall_attack_locked = false
	var longest_minutes: int = 0
	var summary_name: String = ""
	for i in range(_active_death_debuffs.size()):
		_active_death_debuffs[i] = _normalize_single_effect_debuff(_active_death_debuffs[i])
	for deb in _active_death_debuffs:
		_death_max_health_multiplier *= float(deb.get("max_health_multiplier", 1.0))
		_death_stamina_penalty += int(deb.get("stamina_penalty", 0))
		_death_stamina_regen_multiplier *= float(deb.get("stamina_regen_multiplier", 1.0))
		if bool(deb.get("heavy_attack_locked", false)):
			_death_heavy_attack_locked = true
		if bool(deb.get("fall_attack_locked", false)):
			_death_fall_attack_locked = true
		var mins: int = int(deb.get("minutes_left", 0))
		if mins > longest_minutes:
			longest_minutes = mins
			summary_name = String(deb.get("name", ""))
	death_recovery_state["debuff_name"] = summary_name
	death_recovery_state["debuff_minutes_left"] = longest_minutes
	death_recovery_state["max_health_multiplier"] = 1.0
	death_recovery_state["max_health_multiplier"] = _death_max_health_multiplier
	death_recovery_state["stamina_penalty"] = _death_stamina_penalty
	death_recovery_state["stamina_regen_multiplier"] = _death_stamina_regen_multiplier
	death_recovery_state["heavy_attack_locked"] = _death_heavy_attack_locked
	death_recovery_state["fall_attack_locked"] = _death_fall_attack_locked
	death_recovery_state["active_debuffs"] = _active_death_debuffs.duplicate(true)

func _normalize_single_effect_debuff(deb: Dictionary) -> Dictionary:
	var name: String = String(deb.get("name", ""))
	var mins: int = int(deb.get("minutes_left", 0))
	# Bilinen debuff adlarinda havuzdaki canonical tek-etki tanimini zorunlu uygula.
	for d in DEATH_DEBUFF_POOL:
		if String(d.get("name", "")) == name:
			return {
				"name": name,
				"max_health_multiplier": float(d.get("max_health_multiplier", 1.0)),
				"stamina_penalty": int(d.get("stamina_penalty", 0)),
				"stamina_regen_multiplier": float(d.get("stamina_regen_multiplier", 1.0)),
				"heavy_attack_locked": bool(d.get("heavy_attack_locked", false)),
				"fall_attack_locked": bool(d.get("fall_attack_locked", false)),
				"minutes_left": mins,
			}
	# Bilinmeyen/eski bir kayit geldiyse, ilk bulunan etkiyi tutup digerlerini kapat.
	var max_health_multiplier: float = float(deb.get("max_health_multiplier", 1.0))
	var stamina_penalty: int = int(deb.get("stamina_penalty", 0))
	var stamina_regen_multiplier: float = float(deb.get("stamina_regen_multiplier", 1.0))
	var heavy_attack_locked: bool = bool(deb.get("heavy_attack_locked", false))
	var fall_attack_locked: bool = bool(deb.get("fall_attack_locked", false))
	if heavy_attack_locked:
		fall_attack_locked = false
		max_health_multiplier = 1.0
		stamina_penalty = 0
		stamina_regen_multiplier = 1.0
	elif fall_attack_locked:
		max_health_multiplier = 1.0
		stamina_penalty = 0
		stamina_regen_multiplier = 1.0
	elif max_health_multiplier < 1.0:
		stamina_penalty = 0
		stamina_regen_multiplier = 1.0
	elif stamina_penalty > 0:
		max_health_multiplier = 1.0
		stamina_regen_multiplier = 1.0
	elif stamina_regen_multiplier < 1.0:
		max_health_multiplier = 1.0
		stamina_penalty = 0
	return {
		"name": name,
		"max_health_multiplier": max_health_multiplier,
		"stamina_penalty": stamina_penalty,
		"stamina_regen_multiplier": stamina_regen_multiplier,
		"heavy_attack_locked": heavy_attack_locked,
		"fall_attack_locked": fall_attack_locked,
		"minutes_left": mins,
	}

func _clamp_current_health_to_max() -> void:
	current_health = clampf(current_health, 0.0, get_max_health())
	health_changed.emit(current_health)

func _emit_penalty_stat_refresh() -> void:
	var old_max: float = get_max_health()
	stat_changed.emit("max_health", old_max, get_max_health())
	var old_block: float = get_stat("block_charges")
	stat_changed.emit("block_charges", old_block, get_stat("block_charges"))

func is_heavy_attack_locked() -> bool:
	return _death_heavy_attack_locked

func is_fall_attack_locked() -> bool:
	return _death_fall_attack_locked

func get_stamina_regen_multiplier() -> float:
	return _death_stamina_regen_multiplier

func reset_for_new_game() -> void:
	# Yeni oyunda eski run'dan kalan stat/debuff/can state'leri kalmasin.
	reset_stats()
	clear_carried_resources()
	clear_carried_expedition_loot()
	_clear_death_debuff(false)
	death_recovery_state = {
		"is_recovering": false,
		"was_recently_dead": false,
		"mentor_brief_pending": false,
		"death_run_id": 0,
		"minutes_until_full_heal": 0,
		"heal_per_minute": 0.0,
		"debuff_minutes_left": 0,
		"debuff_name": "",
		"max_health_multiplier": 1.0,
		"stamina_penalty": 0,
		"stamina_regen_multiplier": 1.0,
		"heavy_attack_locked": false,
		"fall_attack_locked": false,
		"active_debuffs": [],
	}
	_death_run_id = 0
	_healed_mentor_brief_pending = false
	current_health = get_max_health()
	health_changed.emit(current_health)
	_emit_death_recovery_updated()

func has_active_death_debuff() -> bool:
	return _active_death_debuffs.size() > 0

func clear_active_death_debuff() -> bool:
	if not has_active_death_debuff():
		return false
	_clear_death_debuff(true)
	_emit_death_recovery_updated()
	return true

func debug_apply_death_debuff(debuff_name: String = "", duration_days: int = -1) -> Dictionary:
	var tm := get_node_or_null("/root/TimeManager")
	var minutes_per_day: int = 1440
	if tm and "MINUTES_PER_HOUR" in tm and "HOURS_PER_DAY" in tm:
		minutes_per_day = int(tm.MINUTES_PER_HOUR) * int(tm.HOURS_PER_DAY)
	var applied_days: int = duration_days
	if applied_days <= 0:
		applied_days = randi_range(DEATH_DEBUFF_DURATION_DAYS_MIN, DEATH_DEBUFF_DURATION_DAYS_MAX)
	var picked: Dictionary = {}
	if debuff_name.strip_edges().is_empty():
		picked = DEATH_DEBUFF_POOL[randi() % DEATH_DEBUFF_POOL.size()]
	else:
		var target_name := debuff_name.strip_edges().to_lower()
		for d in DEATH_DEBUFF_POOL:
			if String(d.get("name", "")).to_lower() == target_name:
				picked = d
				break
		if picked.is_empty():
			return {"ok": false, "reason": "unknown_debuff", "available": get_death_debuff_names()}
	var picked_name: String = String(picked.get("name", "Yaralanma"))
	var total_minutes: int = applied_days * minutes_per_day
	var refreshed_existing: bool = false
	for i in range(_active_death_debuffs.size()):
		var active: Dictionary = _active_death_debuffs[i]
		if String(active.get("name", "")) == picked_name:
			active["minutes_left"] = total_minutes
			_active_death_debuffs[i] = active
			refreshed_existing = true
			break
	if not refreshed_existing:
		_active_death_debuffs.append({
			"name": picked_name,
			"max_health_multiplier": float(picked.get("max_health_multiplier", 1.0)),
			"stamina_penalty": int(picked.get("stamina_penalty", 0)),
			"stamina_regen_multiplier": float(picked.get("stamina_regen_multiplier", 1.0)),
			"heavy_attack_locked": bool(picked.get("heavy_attack_locked", false)),
			"fall_attack_locked": bool(picked.get("fall_attack_locked", false)),
			"minutes_left": total_minutes,
		})
	_recalculate_death_debuff_modifiers()
	_clamp_current_health_to_max()
	_emit_penalty_stat_refresh()
	_emit_death_recovery_updated()
	return {"ok": true, "name": picked_name, "days": applied_days, "refreshed": refreshed_existing}

func get_death_debuff_names() -> Array[String]:
	var names: Array[String] = []
	for d in DEATH_DEBUFF_POOL:
		names.append(String(d.get("name", "")))
	return names

func get_death_recovery_state() -> Dictionary:
	return death_recovery_state.duplicate(true)


func take_death_mentor_brief_context() -> Dictionary:
	if not bool(death_recovery_state.get("mentor_brief_pending", false)):
		return {}
	death_recovery_state["mentor_brief_pending"] = false
	var debuff_name: String = ""
	if _active_death_debuffs.size() > 0:
		debuff_name = String(_active_death_debuffs[0].get("name", ""))
	return {
		"run_id": int(death_recovery_state.get("death_run_id", _death_run_id)),
		"minutes_until_full_heal": int(death_recovery_state.get("minutes_until_full_heal", VILLAGE_HEAL_TO_FULL_MINUTES)),
		"debuff_name": debuff_name,
		"has_debuff": _active_death_debuffs.size() > 0,
	}


func take_healed_mentor_brief_run_id() -> int:
	if not _healed_mentor_brief_pending:
		return 0
	_healed_mentor_brief_pending = false
	return int(death_recovery_state.get("death_run_id", _death_run_id))


func has_healed_mentor_brief_pending() -> bool:
	return _healed_mentor_brief_pending

func get_death_recovery_state_for_save() -> Dictionary:
	return {
		"state": death_recovery_state.duplicate(true),
		"active_debuffs": _active_death_debuffs.duplicate(true),
		"max_health_multiplier": _death_max_health_multiplier,
		"stamina_penalty": _death_stamina_penalty,
		"stamina_regen_multiplier": _death_stamina_regen_multiplier,
		"heavy_attack_locked": _death_heavy_attack_locked,
		"fall_attack_locked": _death_fall_attack_locked,
	}

func load_death_recovery_state_from_save(data: Dictionary) -> void:
	if data.is_empty():
		_clear_death_debuff(true)
		death_recovery_state = {
			"is_recovering": false,
			"was_recently_dead": false,
			"minutes_until_full_heal": 0,
			"heal_per_minute": 0.0,
			"debuff_minutes_left": 0,
			"debuff_name": "",
			"max_health_multiplier": 1.0,
			"stamina_penalty": 0,
			"stamina_regen_multiplier": 1.0,
			"heavy_attack_locked": false,
			"fall_attack_locked": false,
			"active_debuffs": [],
		}
		_active_death_debuffs.clear()
		_death_heavy_attack_locked = false
		_death_fall_attack_locked = false
		_emit_death_recovery_updated()
		return
	var state: Dictionary = data.get("state", {})
	if state.is_empty():
		return
	death_recovery_state = state.duplicate(true)
	_death_run_id = int(death_recovery_state.get("death_run_id", 0))
	_healed_mentor_brief_pending = false
	var loaded_active: Variant = data.get("active_debuffs", death_recovery_state.get("active_debuffs", []))
	_active_death_debuffs.clear()
	if loaded_active is Array:
		for v in loaded_active:
			if v is Dictionary:
				_active_death_debuffs.append((v as Dictionary).duplicate(true))
	# Geriye donuk uyumluluk: eski tek-debuff save formati.
	if _active_death_debuffs.is_empty():
		var legacy_name: String = String(death_recovery_state.get("debuff_name", ""))
		var legacy_mins: int = int(death_recovery_state.get("debuff_minutes_left", 0))
		if not legacy_name.is_empty() and legacy_mins > 0:
			_active_death_debuffs.append({
				"name": legacy_name,
				"max_health_multiplier": float(data.get("max_health_multiplier", float(death_recovery_state.get("max_health_multiplier", 1.0)))),
				"stamina_penalty": int(data.get("stamina_penalty", int(death_recovery_state.get("stamina_penalty", 0)))),
				"stamina_regen_multiplier": float(data.get("stamina_regen_multiplier", float(death_recovery_state.get("stamina_regen_multiplier", 1.0)))),
				"heavy_attack_locked": bool(data.get("heavy_attack_locked", bool(death_recovery_state.get("heavy_attack_locked", false)))),
				"fall_attack_locked": bool(data.get("fall_attack_locked", bool(death_recovery_state.get("fall_attack_locked", false)))),
				"minutes_left": legacy_mins,
			})
	_recalculate_death_debuff_modifiers()
	_clamp_current_health_to_max()
	_emit_penalty_stat_refresh()
	_emit_death_recovery_updated()

func _emit_death_recovery_updated() -> void:
	death_recovery_updated.emit(death_recovery_state.duplicate(true))

# Add a flat bonus to a stat
func add_stat_bonus(stat_name: String, amount: float) -> void:
	if !stat_bonuses.has(stat_name):
		push_error("Trying to modify invalid stat: " + stat_name)
		return
		
	var old_value = get_stat(stat_name)
	stat_bonuses[stat_name] += amount
	var new_value = get_stat(stat_name)
	
	if stat_name == "max_health":
		_scale_current_health(old_value, new_value)
		
	stat_changed.emit(stat_name, old_value, new_value)

# Multiply a stat by a factor
func add_stat_multiplier(stat_name: String, factor: float) -> void:
	if !stat_multipliers.has(stat_name):
		push_error("Trying to modify invalid stat: " + stat_name)
		return
		
	var old_value = get_stat(stat_name)
	stat_multipliers[stat_name] *= factor
	var new_value = get_stat(stat_name)
	
	if stat_name == "max_health":
		_scale_current_health(old_value, new_value)
		
	stat_changed.emit(stat_name, old_value, new_value)

# Scale current health when max health changes
func _scale_current_health(old_max: float, new_max: float) -> void:
	if old_max <= 0:
		current_health = new_max
	else:
		var health_percentage = current_health / old_max
		current_health = new_max * health_percentage
	health_changed.emit(current_health)

# Reset all stats to base values
func reset_stats() -> void:
	for stat in stat_multipliers.keys():
		stat_multipliers[stat] = 1.0
		stat_bonuses[stat] = 0.0
		stat_changed.emit(stat, get_stat(stat), base_stats[stat])
	
	current_health = get_stat("max_health")
	health_changed.emit(current_health)

# Get all active effects that modify a specific stat
func get_stat_modifiers(stat_name: String) -> Array:
	var powerup_manager = get_node("/root/PowerupManager")
	if !powerup_manager:
		return []
		
	var modifiers = []
	for powerup in powerup_manager.get_active_powerups():
		if powerup.affects_stat(stat_name):
			modifiers.append(powerup)
	return modifiers

# Helper functions for common stat operations
func get_max_health() -> float:
	var max_health = get_stat("max_health")
	return max_health

func get_current_health() -> float:
	return current_health

func set_current_health(value: float, show_damage_number: bool = true) -> void:
	var old_health = current_health
	var new_health = clamp(value, 0, get_max_health())
	# İkinci Nefes: ölüm anında item tek seferlik diriltebilir
	if new_health <= 0.0 and old_health > 0.0:
		var im = get_node_or_null("/root/ItemManager")
		if im and im.has_method("try_revive_player") and im.try_revive_player():
			current_health = 1.0
			health_changed.emit(1.0)
			return
	current_health = new_health
	health_changed.emit(current_health)
	# Check for death
	if current_health <= 0.0 and old_health > 0.0:
		player_died.emit()
		print("[PlayerStats] 💀 Player died (health: %.1f)" % current_health)
	
	if show_damage_number and current_health < old_health:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var damage_amount = old_health - current_health
			var damage_number = preload("res://effects/damage_number.tscn").instantiate()
			player.add_child(damage_number)
			damage_number.global_position = player.global_position + Vector2(0, -50)
			damage_number.setup(int(damage_amount), false, true)

func get_base_damage() -> float:
	return get_stat("base_damage")

func get_movement_speed() -> float:
	return get_stat("movement_speed")

func get_shield_cooldown() -> float:
	return get_stat("shield_cooldown")

func get_dash_cooldown() -> float:
	return get_stat("dash_cooldown")

func get_block_charges() -> int:
	return int(get_stat("block_charges"))

# Add helper function for fall attack damage
func get_fall_attack_damage() -> float:
	return get_stat("fall_attack_damage")

# Add more helper functions as needed... 

func get_carried_resources() -> Dictionary:
	return carried_resources.duplicate()

func get_carried_resource(type: String) -> int:
	if !carried_resources.has(type):
		push_warning("[PlayerStats] Requested invalid carried resource type: %s" % type)
		return 0
	return carried_resources[type]

func add_carried_resource(type: String, amount: int) -> void:
	if amount == 0:
		return
	if !carried_resources.has(type):
		push_warning("[PlayerStats] Tried to add invalid resource type: %s" % type)
		return
	_set_carried_resource(type, carried_resources[type] + amount)

func add_carried_resources(amounts: Dictionary) -> void:
	if amounts.is_empty():
		return
	var changed := false
	for type in amounts.keys():
		var int_amount := int(amounts[type])
		if int_amount == 0:
			continue
		if !carried_resources.has(type):
			push_warning("[PlayerStats] add_carried_resources received unknown type: %s" % type)
			continue
		_set_carried_resource(type, carried_resources[type] + int_amount, false)
		changed = true
	if changed:
		_emit_carried_changed()

func remove_carried_resource(type: String, amount: int) -> int:
	if amount <= 0:
		return 0
	if !carried_resources.has(type):
		push_warning("[PlayerStats] Tried to remove invalid resource type: %s" % type)
		return 0
	var available: int = int(carried_resources[type])
	var to_remove := clampi(amount, 0, available)
	if to_remove > 0:
		_set_carried_resource(type, available - to_remove)
	return to_remove

func clear_carried_resources() -> void:
	var had_resources := false
	for type in RESOURCE_TYPES:
		if carried_resources[type] != 0:
			carried_resources[type] = 0
			had_resources = true
	if had_resources:
		_emit_carried_changed()

func lose_carried_resources_by_fraction(fraction: float, min_loss_per_type: int = 0) -> Dictionary:
	fraction = clampf(fraction, 0.0, 1.0)
	if fraction <= 0.0 and min_loss_per_type <= 0:
		return {}
	var losses := {}
	for type in RESOURCE_TYPES:
		var current: int = int(carried_resources[type])
		if current <= 0:
			continue
		var loss := int(round(current * fraction))
		if min_loss_per_type > 0:
			var min_loss := min_loss_per_type
			if current < min_loss:
				min_loss = current
			loss = max(loss, min_loss)
		loss = clamp(loss, 0, current)
		if loss > 0:
			carried_resources[type] = current - loss
			losses[type] = loss
	if losses.is_empty():
		return {}
	_emit_carried_changed()
	carried_resources_lost.emit(losses.duplicate())
	return losses

func _set_carried_resource(type: String, value: int, emit_signal_on_change: bool = true) -> void:
	var clamped: int = max(int(value), 0)
	if carried_resources[type] == clamped:
		return
	carried_resources[type] = clamped
	if emit_signal_on_change:
		_emit_carried_changed()

func _emit_carried_changed() -> void:
	carried_resources_changed.emit(carried_resources.duplicate())


func get_carried_expedition_loot() -> Dictionary:
	return carried_expedition_loot.duplicate()


func get_carried_expedition_loot_amount(loot_id: String) -> int:
	if not carried_expedition_loot.has(loot_id):
		return 0
	return int(carried_expedition_loot[loot_id])


func add_carried_expedition_loot(loot_id: String, amount: int) -> void:
	if amount == 0:
		return
	if not carried_expedition_loot.has(loot_id):
		push_warning("[PlayerStats] Unknown expedition loot: %s" % loot_id)
		return
	carried_expedition_loot[loot_id] = maxi(0, int(carried_expedition_loot[loot_id]) + amount)
	_emit_expedition_loot_changed()


func clear_carried_expedition_loot() -> void:
	var had := false
	for lid in ExpeditionLootType.all():
		if int(carried_expedition_loot.get(lid, 0)) != 0:
			carried_expedition_loot[lid] = 0
			had = true
	if had:
		_emit_expedition_loot_changed()


func transfer_carried_expedition_loot_to_village(meta_manager: Node) -> Dictionary:
	if meta_manager == null or not meta_manager.has_method("deposit_village_loot"):
		return {}
	var payload: Dictionary = {}
	for lid in ExpeditionLootType.all():
		var amt := int(carried_expedition_loot.get(lid, 0))
		if amt > 0:
			payload[lid] = amt
	if payload.is_empty():
		return {}
	var deposited: Dictionary = meta_manager.deposit_village_loot(payload)
	if not deposited.is_empty():
		for k in deposited.keys():
			var key := String(k)
			carried_expedition_loot[key] = maxi(0, int(carried_expedition_loot.get(key, 0)) - int(deposited[k]))
		_emit_expedition_loot_changed()
	return deposited


func _emit_expedition_loot_changed() -> void:
	expedition_loot_changed.emit(carried_expedition_loot.duplicate())

func configure_resource_loss_on_hit(fraction: float, min_loss: int) -> void:
	resource_loss_fraction_on_hit = clampf(fraction, 0.0, 1.0)
	min_resource_loss_per_hit = max(min_loss, 0)

func lose_resources_on_damage() -> Dictionary:
	return lose_carried_resources_by_fraction(resource_loss_fraction_on_hit, min_resource_loss_per_hit)

func lose_dungeon_gold_on_damage() -> int:
	# Yalnızca orman sahnesinde çağrılmalı (player.gd _should_apply_damage_resource_penalty).
	var gpd := get_node_or_null("/root/GlobalPlayerData")
	if gpd and gpd.has_method("lose_dungeon_gold_by_fraction"):
		return int(gpd.lose_dungeon_gold_by_fraction(dungeon_gold_loss_fraction_on_hit))
	return 0

func get_world_expedition_supplies() -> Dictionary:
	return world_expedition_supplies.duplicate(true)

func reset_world_expedition_supplies() -> void:
	world_expedition_supplies = {"food": 0, "medicine": 0, "world_gold": 0}
	_world_exp_food_debt = 0.0
	world_expedition_supplies_changed.emit(world_expedition_supplies.duplicate())

func load_world_expedition_supplies_from_save(d: Dictionary) -> void:
	if d.is_empty():
		return
	for k in ["food", "medicine", "world_gold"]:
		if d.has(k):
			world_expedition_supplies[k] = maxi(0, int(d[k]))
	_world_exp_food_debt = 0.0
	_apply_world_expedition_caps_silent()
	world_expedition_supplies_changed.emit(world_expedition_supplies.duplicate())

func get_world_expedition_pack_caps() -> Dictionary:
	return {
		"food": WORLD_EXP_FOOD_PACK_CAP,
		"medicine": WORLD_EXP_MEDICINE_PACK_CAP,
		"world_gold": WORLD_EXP_GOLD_PACK_CAP,
	}

func _apply_world_expedition_caps_silent() -> bool:
	var caps: Dictionary = get_world_expedition_pack_caps()
	var touched: bool = false
	for k in caps.keys():
		var ks: String = str(k)
		if not world_expedition_supplies.has(ks):
			continue
		var mx: int = int(caps[k])
		var nv: int = mini(_world_exp_get(ks), mx)
		if nv != int(world_expedition_supplies.get(ks, 0)):
			world_expedition_supplies[ks] = nv
			touched = true
	return touched

func clamp_world_expedition_supplies_to_caps() -> void:
	if _apply_world_expedition_caps_silent():
		world_expedition_supplies_changed.emit(world_expedition_supplies.duplicate())

func _world_exp_get(key: String) -> int:
	return maxi(0, int(world_expedition_supplies.get(key, 0)))

func _world_exp_set(key: String, v: int, emit_sig: bool = true) -> void:
	var c: int = maxi(0, v)
	if int(world_expedition_supplies.get(key, 0)) == c:
		return
	world_expedition_supplies[key] = c
	if emit_sig:
		world_expedition_supplies_changed.emit(world_expedition_supplies.duplicate())

func add_world_expedition_supplies(amounts: Dictionary) -> void:
	if amounts.is_empty():
		return
	for k in amounts.keys():
		var key := str(k)
		if not world_expedition_supplies.has(key):
			continue
		var add_n: int = int(amounts[k])
		if add_n == 0:
			continue
		_world_exp_set(key, _world_exp_get(key) + add_n, false)
	_apply_world_expedition_caps_silent()
	world_expedition_supplies_changed.emit(world_expedition_supplies.duplicate())

func apply_world_travel_ration_cost(travel_minutes: int) -> Dictionary:
	if travel_minutes <= 0:
		return {"food_used": 0, "water_used": 0, "starvation_hp": 0.0, "collapsed": false}
	var food_used: int = 0
	_world_exp_food_debt += float(travel_minutes) / WORLD_EXP_FOOD_MINUTES_PER_UNIT
	while _world_exp_food_debt >= 1.0:
		_world_exp_food_debt -= 1.0
		if _world_exp_get("food") > 0:
			_world_exp_set("food", _world_exp_get("food") - 1, false)
			food_used += 1
		else:
			world_expedition_supplies_changed.emit(world_expedition_supplies.duplicate())
			return {
				"food_used": food_used,
				"water_used": 0,
				"starvation_hp": 0.0,
				"collapsed": true,
				"collapse_cause": "food",
			}
	world_expedition_supplies_changed.emit(world_expedition_supplies.duplicate())
	return {"food_used": food_used, "water_used": 0, "starvation_hp": 0.0, "collapsed": false}


func apply_akarsu_river_hydration() -> void:
	pass

func lose_world_expedition_supplies_by_fraction(fraction: float) -> Dictionary:
	fraction = clampf(fraction, 0.0, 1.0)
	if fraction <= 0.0:
		return {}
	var losses := {}
	for key in ["food", "medicine"]:
		var cur: int = _world_exp_get(key)
		if cur <= 0:
			continue
		var loss: int = int(round(float(cur) * fraction))
		loss = clampi(loss, 0, cur)
		if loss > 0:
			_world_exp_set(key, cur - loss, false)
			losses[key] = loss
	if not losses.is_empty():
		world_expedition_supplies_changed.emit(world_expedition_supplies.duplicate())
	return losses

func lose_world_expedition_gold_by_fraction(fraction: float) -> int:
	fraction = clampf(fraction, 0.0, 1.0)
	if fraction <= 0.0:
		return 0
	var cur: int = _world_exp_get("world_gold")
	if cur <= 0:
		return 0
	var loss: int = int(round(float(cur) * fraction))
	loss = clampi(loss, 0, cur)
	if loss > 0:
		_world_exp_set("world_gold", cur - loss)
	return loss

func apply_world_expedition_gold_delta(delta: int) -> int:
	if delta == 0:
		return 0
	var cur: int = _world_exp_get("world_gold")
	if delta < 0:
		var take: int = mini(-delta, cur)
		if take > 0:
			_world_exp_set("world_gold", cur - take)
		return -take
	var new_g: int = mini(cur + delta, WORLD_EXP_GOLD_PACK_CAP)
	var applied: int = new_g - cur
	if applied != 0:
		_world_exp_set("world_gold", new_g)
	return applied

func get_world_expedition_total_weight_score() -> int:
	return _world_exp_get("food") + _world_exp_get("medicine") * 2 + _world_exp_get("world_gold") / 8


func get_world_expedition_survival_forecast() -> Dictionary:
	var food_units: int = _world_exp_get("food")
	var to_food_tick: int = int(ceil(maxf(0.0, (1.0 - _world_exp_food_debt) * WORLD_EXP_FOOD_MINUTES_PER_UNIT)))
	if to_food_tick <= 0:
		to_food_tick = int(maxi(1, int(round(WORLD_EXP_FOOD_MINUTES_PER_UNIT))))
	var food_minutes_until_hp: int = int(maxi(0, to_food_tick + int(round(float(food_units) * WORLD_EXP_FOOD_MINUTES_PER_UNIT))))
	return {
		"food_units": food_units,
		"water_units": 0,
		"minutes_until_food_hp_loss": food_minutes_until_hp,
		"minutes_until_water_hp_loss": 999999,
		"minutes_until_any_hp_loss": food_minutes_until_hp,
		"minutes_until_collapse": food_minutes_until_hp,
		"minutes_until_food_collapse": food_minutes_until_hp,
		"minutes_until_water_collapse": 999999,
	}
