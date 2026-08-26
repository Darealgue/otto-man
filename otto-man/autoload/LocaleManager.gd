extends Node
## Oyun dili: CSV çevirileri yükler, locale kalıcı ayarlar ve tr() yardımcıları.

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "en"
const SUPPORTED_LOCALES: Array[String] = ["tr", "en"]
const CSV_PATH := "res://localization/strings.csv"
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "game"
const SETTINGS_KEY := "locale"

var _current_locale: String = DEFAULT_LOCALE
var _translations_loaded: bool = false


func _ready() -> void:
	_load_translations_from_csv()
	var persisted := _load_locale_from_disk()
	set_locale(persisted, false)


func get_locale() -> String:
	return _current_locale


func set_locale(locale: String, emit_signal: bool = true) -> void:
	var code := locale.strip_edges().to_lower()
	if not SUPPORTED_LOCALES.has(code):
		code = DEFAULT_LOCALE
	var changed := _current_locale != code
	_current_locale = code
	TranslationServer.set_locale(code)
	if emit_signal and changed:
		locale_changed.emit(code)


func tr_key(key: StringName, args: Array = []) -> String:
	var text := tr(key)
	if String(text) == String(key):
		text = String(key)
	if args.is_empty():
		return text
	return text % args


func get_scene_display_name(scene_path: String) -> String:
	if scene_path.contains("Village"):
		return tr("scene.village")
	if scene_path.contains("Dungeon") or scene_path.contains("test_level"):
		return tr("scene.dungeon")
	if scene_path.contains("Forest"):
		return tr("scene.forest")
	if scene_path.contains("WorldMap"):
		return tr("scene.worldmap")
	if scene_path.contains("MainMenu"):
		return tr("scene.main_menu")
	return tr("scene.unknown")


## Kayıt tarihini okunabilir hale getirir. SaveManager tarihi yerel saatle
## "2026-07-12T16:56:00" biçiminde yazıyor; bu ham haliyle bir bakışta okunmuyor.
## Bugün ve dün özel olarak adlandırılır, eskiler "12 Tem 2026 · 16:56" olur.
func format_save_date(iso_date: String) -> String:
	var raw := iso_date.strip_edges()
	if raw.is_empty():
		return tr("date.unknown")
	var dt: Dictionary = Time.get_datetime_dict_from_datetime_string(raw, false)
	if dt.is_empty() or not dt.has("year"):
		return raw
	var clock: String = "%02d:%02d" % [int(dt.get("hour", 0)), int(dt.get("minute", 0))]

	# Gün farkı: iki tarih de aynı şekilde yorumlandığı için fark tutarlı çıkar.
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var midnight := "%04d-%02d-%02dT00:00:00" % [int(now.get("year", 0)), int(now.get("month", 1)), int(now.get("day", 1))]
	var saved_unix: int = int(Time.get_unix_time_from_datetime_string(raw))
	var today_unix: int = int(Time.get_unix_time_from_datetime_string(midnight))
	var day_diff: int = int(floor(float(saved_unix - today_unix) / 86400.0))
	if day_diff == 0:
		return tr("date.today") % clock
	if day_diff == -1:
		return tr("date.yesterday") % clock

	var months: PackedStringArray = tr("date.months_short").split("|")
	var month_index: int = clampi(int(dt.get("month", 1)) - 1, 0, 11)
	var month_name: String = months[month_index] if months.size() == 12 else str(int(dt.get("month", 1)))
	return tr("date.full") % [int(dt.get("day", 1)), month_name, int(dt.get("year", 0)), clock]


func format_playtime_profile(seconds: int) -> String:
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	if hours > 0:
		return tr("time.profile_hours_minutes") % [hours, minutes]
	if minutes > 0:
		return tr("time.profile_minutes") % minutes
	return tr("time.profile_seconds") % maxi(1, seconds)


## Kayıt satırlarındaki oynanış süresi. Eskiden "time.slot_hours" ile "18:48 h" gibi
## yazılıyordu; yanındaki kayıt saatiyle karışıyordu. Artık profil ekranıyla aynı
## "18 sa 48 dk" biçimi kullanılıyor, süre ile saat birbirine benzemiyor.
func format_playtime_slot(seconds: int) -> String:
	return format_playtime_profile(seconds)


const BUILDING_SCENE_KEYS := {
	"res://village/buildings/WoodcutterCamp.tscn": "building.woodcutter",
	"res://village/buildings/StoneMine.tscn": "building.stone_mine",
	"res://village/buildings/HunterGathererHut.tscn": "building.hunter_hut",
	"res://village/buildings/Well.tscn": "building.well",
	"res://village/buildings/Bakery.tscn": "building.bakery",
	"res://village/buildings/House.tscn": "building.house",
	"res://village/buildings/Sawmill.tscn": "building.sawmill",
	"res://village/buildings/Brickworks.tscn": "building.brickworks",
	"res://village/buildings/Blacksmith.tscn": "building.blacksmith",
	"res://village/buildings/Weaver.tscn": "building.weaver",
	"res://village/buildings/Tailor.tscn": "building.tailor",
	"res://village/buildings/Herbalist.tscn": "building.herbalist",
	"res://village/buildings/TeaHouse.tscn": "building.teahouse",
	"res://village/buildings/SoapMaker.tscn": "building.soapmaker",
	"res://village/buildings/Gunsmith.tscn": "building.gunsmith",
	"res://village/buildings/Barracks.tscn": "building.barracks",
	"res://village/buildings/InventorWorkshop.tscn": "building.inventor",
	"res://village/buildings/StorageBuilding.tscn": "building.storage",
}


func get_resource_name(resource_key: String) -> String:
	var key := "resource.%s" % resource_key
	var text := tr(key)
	return text if text != key else resource_key.capitalize()


## Internal debuff identifiers (player_stats.gd DEATH_DEBUFF_POOL) stay untranslated raw strings
## since they're also used for matching active debuffs — this maps them to a display name only.
const DEBUFF_NAME_KEYS := {
	"Kirik Kaburga": "debuff.broken_rib",
	"Bel Tutulmasi": "debuff.back_strain",
	"Denge Kaybi": "debuff.balance_loss",
}

func get_debuff_name(internal_name: String) -> String:
	var tr_key: String = String(DEBUFF_NAME_KEYS.get(internal_name, ""))
	if tr_key.is_empty():
		return tr("debuff.generic") if internal_name.is_empty() else internal_name
	var text := tr(tr_key)
	return text if text != tr_key else internal_name


func get_building_name(scene_path: String) -> String:
	var tr_key: String = String(BUILDING_SCENE_KEYS.get(scene_path, ""))
	if tr_key.is_empty():
		return scene_path.get_file().trim_suffix(".tscn")
	var text := tr(tr_key)
	return text if text != tr_key else scene_path.get_file().trim_suffix(".tscn")


func get_mission_text(mission_id: String, field: String, fallback: String) -> String:
	if mission_id.is_empty():
		return fallback
	var key := "mission.%s.%s" % [mission_id, field]
	var text := tr(key)
	return text if text != key else fallback


func get_risk_level_name(risk: String) -> String:
	match risk.strip_edges():
		"Düşük", "Dusuk":
			return tr("mission.risk.low")
		"Orta":
			return tr("mission.risk.medium")
		"Yüksek", "Yuksek":
			return tr("mission.risk.high")
		"Çok Yüksek", "Cok Yuksek":
			return tr("mission.risk.very_high")
		_:
			return risk


## Godot imports strings.csv into .translation resources and ships THOSE in an exported build —
## the raw .csv is an import source and is not packed unless explicitly listed in the export
## filters. Reading only the .csv therefore worked in the editor but silently failed in every
## export, leaving every tr() call showing its raw key on screen.
##
## So: load the imported resources first (always present in exports, since export_filter is
## "all_resources"), and fall back to parsing the .csv when they are missing. The fallback keeps
## working in the editor before a first import, and means a broken export filter can no longer
## take the whole UI's text down.
const TRANSLATION_RESOURCE_PATHS := [
	"res://localization/strings.tr.translation",
	"res://localization/strings.en.translation",
]


func _load_translations_from_csv() -> void:
	if _load_imported_translations():
		_translations_loaded = true
		return
	_load_translations_from_csv_source()


func _load_imported_translations() -> bool:
	var loaded_any := false
	for path in TRANSLATION_RESOURCE_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var res := load(path)
		var translation := res as Translation
		if translation == null:
			continue
		TranslationServer.add_translation(translation)
		loaded_any = true
	if loaded_any:
		print("LocaleManager: imported .translation resources loaded.")
	return loaded_any


func _load_translations_from_csv_source() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("LocaleManager: CSV açılamadı: %s" % CSV_PATH)
		return

	var header_cells := file.get_csv_line()
	if header_cells.is_empty():
		push_error("LocaleManager: CSV başlık satırı boş")
		file.close()
		return

	var locale_columns: Dictionary = {}
	for col_idx in range(1, header_cells.size()):
		var locale_code := String(header_cells[col_idx]).strip_edges().to_lower()
		if locale_code.is_empty():
			continue
		var translation := Translation.new()
		translation.locale = locale_code
		locale_columns[col_idx] = translation

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty() or String(row[0]).strip_edges().is_empty():
			continue
		var message_key := String(row[0]).strip_edges()
		for col_idx in locale_columns.keys():
			if col_idx >= row.size():
				continue
			var message := String(row[col_idx])
			var translation: Translation = locale_columns[col_idx]
			translation.add_message(message_key, message)

	file.close()

	for translation: Translation in locale_columns.values():
		TranslationServer.add_translation(translation)

	_translations_loaded = true


func _load_locale_from_disk() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return DEFAULT_LOCALE
	var value = config.get_value(SETTINGS_SECTION, SETTINGS_KEY, DEFAULT_LOCALE)
	return String(value).strip_edges().to_lower()


func persist_locale(locale: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, locale)
	config.save(SETTINGS_PATH)


## True only if the player has explicitly chosen/saved a locale before (first-launch
## language gate in MainMenu.gd uses this to decide whether to show itself at all —
## returning players who already picked a language should never see it again).
func has_persisted_locale() -> bool:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return false
	return config.has_section_key(SETTINGS_SECTION, SETTINGS_KEY)
