class_name WorldFactionProfiles
extends RefCounted
## Komşu yerleşim fraksiyonları — ticaret süresi, baskın riski ve diplomasi etkileri.

const FACTION_IDS: Array[String] = ["Kuzey", "Güney", "Doğu", "Batı"]

const PROFILES: Dictionary = {
	"Kuzey": {
		"label": "Kuzey Halkları",
		"trade_duration_mult": 1.12,
		"raid_risk_mult": 1.2,
		"diplomacy_duration_mult": 1.05,
	},
	"Güney": {
		"label": "Güney Şehirleri",
		"trade_duration_mult": 0.92,
		"raid_risk_mult": 0.85,
		"diplomacy_duration_mult": 0.95,
	},
	"Doğu": {
		"label": "Doğu Hanlıkları",
		"trade_duration_mult": 1.0,
		"raid_risk_mult": 1.1,
		"diplomacy_duration_mult": 0.88,
	},
	"Batı": {
		"label": "Batı Ticaret Birliği",
		"trade_duration_mult": 0.88,
		"raid_risk_mult": 1.0,
		"diplomacy_duration_mult": 1.0,
	},
}


static func pick_faction_for_index(index: int) -> String:
	if FACTION_IDS.is_empty():
		return "Batı"
	return FACTION_IDS[posmod(index, FACTION_IDS.size())]


static func get_profile(faction_id: String) -> Dictionary:
	if PROFILES.has(faction_id):
		return (PROFILES[faction_id] as Dictionary).duplicate(true)
	return (PROFILES["Batı"] as Dictionary).duplicate(true)


static func get_display_label(faction_id: String) -> String:
	return String(get_profile(faction_id).get("label", faction_id))


static func adjust_trade_duration(base_minutes: int, faction_id: String) -> int:
	var mult: float = float(get_profile(faction_id).get("trade_duration_mult", 1.0))
	return maxi(30, int(round(float(base_minutes) * mult)))


static func adjust_diplomacy_duration(base_minutes: int, faction_id: String) -> int:
	var mult: float = float(get_profile(faction_id).get("diplomacy_duration_mult", 1.0))
	return maxi(30, int(round(float(base_minutes) * mult)))


static func adjust_raid_risk_label(base: String, faction_id: String) -> String:
	var mult: float = float(get_profile(faction_id).get("raid_risk_mult", 1.0))
	if mult >= 1.15:
		if base == "Dusuk":
			return "Orta"
		if base == "Orta":
			return "Yuksek"
	elif mult <= 0.9:
		if base == "Orta":
			return "Dusuk"
		if base == "Yuksek":
			return "Orta"
	return base
