class_name MetaUpgradeConfig
extends RefCounted
## Mucit Odası kalıcı upgrade tanımları (SSOT).

const TRACK_DAMAGE := "damage"
const TRACK_HEALTH := "health"
const TRACK_STAMINA := "stamina"

## Her yol 10 seviyeye kadar geliştirilebilir (oyuncu istediği kadar gelişebilsin); ilk seviyeler eskisi gibi, sonrakilerin bedeli
## kademeli artar. Bu değerler eşlikçi kedilerin bonuslarının da kaynağıdır (bir kedi = bir seviyelik bonus, bkz. CatCompanion).
const MAX_LEVEL: int = 10

const TRACKS: Dictionary = {
	TRACK_DAMAGE: {
		"title": "Kılıç Tezgâhı",
		"description": "Saldırı gücünü kalıcı artırır.",
		"stat": "base_damage",
		"bonus_per_level": 5.0,
		"max_level": MAX_LEVEL,
		"levels": {
			1: {"rusty_weapon": 10},
			2: {"rusty_weapon": 20, "metal": 1},
			3: {"rusty_weapon": 30, "metal": 5, "weapon_t1": 1},
			4: {"rusty_weapon": 40, "metal": 8, "weapon_t1": 1},
			5: {"rusty_weapon": 50, "metal": 11, "weapon_t1": 2},
			6: {"rusty_weapon": 60, "metal": 14, "weapon_t1": 2},
			7: {"rusty_weapon": 70, "metal": 18, "weapon_t1": 3},
			8: {"rusty_weapon": 80, "metal": 22, "weapon_t1": 3},
			9: {"rusty_weapon": 90, "metal": 26, "weapon_t1": 4},
			10: {"rusty_weapon": 100, "metal": 30, "weapon_t1": 5},
		},
	},
	TRACK_HEALTH: {
		"title": "Yaşam İksiri",
		"description": "Maksimum canı kalıcı artırır.",
		"stat": "max_health",
		"bonus_per_level": 25.0,
		"max_level": MAX_LEVEL,
		"levels": {
			1: {"herb_bundle": 8},
			2: {"herb_bundle": 15, "medicine": 2},
			3: {"herb_bundle": 22, "medicine": 3},
			4: {"herb_bundle": 29, "medicine": 4},
			5: {"herb_bundle": 36, "medicine": 5},
			6: {"herb_bundle": 43, "medicine": 6},
			7: {"herb_bundle": 50, "medicine": 7},
			8: {"herb_bundle": 57, "medicine": 8},
			9: {"herb_bundle": 64, "medicine": 9},
			10: {"herb_bundle": 71, "medicine": 10},
		},
	},
	TRACK_STAMINA: {
		"title": "Hafif Kanat",
		"description": "Ekstra stamina segmenti kazandırır.",
		"stat": "block_charges",
		"bonus_per_level": 1.0,
		"max_level": MAX_LEVEL,
		"levels": {
			1: {"sky_feather": 12},
			2: {"sky_feather": 20},
			3: {"sky_feather": 28},
			4: {"sky_feather": 36, "metal": 5},
			5: {"sky_feather": 44, "metal": 8},
			6: {"sky_feather": 52, "metal": 11},
			7: {"sky_feather": 60, "metal": 14},
			8: {"sky_feather": 68, "metal": 17},
			9: {"sky_feather": 76, "metal": 20},
			10: {"sky_feather": 84, "metal": 24},
		},
	},
}


## Bir yolun bir seviyelik bonusunun (stat, miktar) çifti: eşlikçi kedilerin "bir seviye" bonusu için kullanılır.
static func get_level_bonus(track_id: String) -> Dictionary:
	var track: Dictionary = TRACKS.get(track_id, {})
	return {"stat": String(track.get("stat", "")), "amount": float(track.get("bonus_per_level", 0.0))}


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
