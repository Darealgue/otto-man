class_name MetaUpgradeConfig
extends RefCounted
## Mucit Odası kalıcı upgrade tanımları (SSOT).

const TRACK_DAMAGE := "damage"
const TRACK_HEALTH := "health"
const TRACK_STAMINA := "stamina"

const TRACKS: Dictionary = {
	TRACK_DAMAGE: {
		"title": "Kılıç Tezgâhı",
		"description": "Saldırı gücünü kalıcı artırır.",
		"stat": "base_damage",
		"bonus_per_level": 5.0,
		"max_level": 3,
		"levels": {
			1: {"rusty_weapon": 10},
			2: {"rusty_weapon": 20, "metal": 1},
			3: {"rusty_weapon": 30, "metal": 5, "weapon": 1},
		},
	},
	TRACK_HEALTH: {
		"title": "Yaşam İksiri",
		"description": "Maksimum canı kalıcı artırır.",
		"stat": "max_health",
		"bonus_per_level": 25.0,
		"max_level": 2,
		"levels": {
			1: {"herb_bundle": 8},
			2: {"herb_bundle": 15, "medicine": 2},
		},
	},
	TRACK_STAMINA: {
		"title": "Hafif Kanat",
		"description": "Ekstra stamina segmenti kazandırır.",
		"stat": "block_charges",
		"bonus_per_level": 1.0,
		"max_level": 1,
		"levels": {
			1: {"sky_feather": 12},
		},
	},
}


static func get_track_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in TRACKS.keys():
		ids.append(String(k))
	return ids


static func get_max_level(track_id: String) -> int:
	var track: Dictionary = TRACKS.get(track_id, {})
	return int(track.get("max_level", 0))


static func get_level_cost(track_id: String, target_level: int) -> Dictionary:
	var track: Dictionary = TRACKS.get(track_id, {})
	var levels: Dictionary = track.get("levels", {})
	var raw: Variant = levels.get(target_level, {})
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	return {}


static func format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "—"
	var parts: PackedStringArray = PackedStringArray()
	for k in cost.keys():
		var key := String(k)
		var amt := int(cost[k])
		if amt <= 0:
			continue
		var label := key
		if ExpeditionLootType.is_valid(key):
			label = ExpeditionLootType.display_name(key)
		elif key == "metal":
			label = "Metal"
		elif key == "weapon":
			label = "Silah"
		elif key == "medicine":
			label = "İlaç"
		parts.append("%s ×%d" % [label, amt])
	return ", ".join(parts)
