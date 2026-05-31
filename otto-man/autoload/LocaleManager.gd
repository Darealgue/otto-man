extends Node
## Oyun dili: CSV çevirileri yükler, locale kalıcı ayarlar ve tr() yardımcıları.

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "tr"
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


func format_playtime_profile(seconds: int) -> String:
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	if hours > 0:
		return tr("time.profile_hours_minutes") % [hours, minutes]
	if minutes > 0:
		return tr("time.profile_minutes") % minutes
	return tr("time.profile_seconds") % maxi(1, seconds)


func format_playtime_slot(seconds: int) -> String:
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	if hours > 0:
		return tr("time.slot_hours") % [hours, minutes]
	return tr("time.slot_minutes") % minutes


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
	"res://village/buildings/Armorer.tscn": "building.armorer",
	"res://village/buildings/Barracks.tscn": "building.barracks",
}


func get_resource_name(resource_key: String) -> String:
	var key := "resource.%s" % resource_key
	var text := tr(key)
	return text if text != key else resource_key.capitalize()


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


func _load_translations_from_csv() -> void:
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
