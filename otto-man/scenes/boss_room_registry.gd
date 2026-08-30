class_name BossRoomRegistry
## Boss kimliği → boss odası sahnesi eşlemesi.
##
## Gelecek: orb_scatter ailesi (ışınlanan, farklı projectile, farklı hareket vb.)
## yeni boss_id + sahne veya aynı boss script'inde @export variant ile eklenebilir.

const BOSS_FIGHTS_ENABLED: bool = true

const DEFAULT_BOSS_ID: String = "orb_scatter"

const BOSS_SCENES: Dictionary = {
	"orb_scatter": "res://scenes/boss_rooms/orb_scatter_boss_room.tscn",
	# "tepegoz": "res://scenes/boss_rooms/tepegoz_boss_room.tscn",
}

## Çeviri bulunamazsa kullanılan yedek adlar (DEFAULT_LOCALE "en").
const BOSS_DISPLAY_NAMES: Dictionary = {
	"orb_scatter": "Witch",
}

## boss_id -> localization anahtarı.
const BOSS_NAME_KEYS: Dictionary = {
	"orb_scatter": "boss.name.orb_scatter",
}

## Eski tek sahne yolu — geriye dönük referanslar için.
const LEGACY_BOSS_ROOM_SCENE: String = "res://scenes/boss_room.tscn"


static func is_enabled() -> bool:
	return BOSS_FIGHTS_ENABLED and not BOSS_SCENES.is_empty()


static func get_display_name(boss_id: String = "") -> String:
	var id := boss_id.strip_edges()
	if id.is_empty():
		id = DEFAULT_BOSS_ID
	# static olduğu için tr() yok; TranslationServer doğrudan kullanılıyor.
	if BOSS_NAME_KEYS.has(id):
		var key := String(BOSS_NAME_KEYS[id])
		var translated := String(TranslationServer.translate(key))
		if not translated.is_empty() and translated != key:
			return translated
	return String(BOSS_DISPLAY_NAMES.get(id, id.replace("_", " ").capitalize()))


static func get_boss_id(payload: Dictionary = {}) -> String:
	if not is_enabled():
		return ""
	var from_payload := String(payload.get("boss_id", "")).strip_edges()
	if not from_payload.is_empty() and BOSS_SCENES.has(from_payload):
		return from_payload
	return DEFAULT_BOSS_ID


static func get_scene_path(boss_id: String = "") -> String:
	if not is_enabled():
		return ""
	var id := boss_id.strip_edges()
	if id.is_empty():
		id = DEFAULT_BOSS_ID
	if not BOSS_SCENES.has(id):
		return ""
	return String(BOSS_SCENES[id])


static func resolve_scene_path(payload: Dictionary = {}) -> String:
	return get_scene_path(get_boss_id(payload))


static func is_boss_room_path(path: String) -> bool:
	if path.is_empty():
		return false
	if path == LEGACY_BOSS_ROOM_SCENE:
		return true
	for scene_path in BOSS_SCENES.values():
		if path == scene_path:
			return true
	return "boss_room" in path.to_lower()
