class_name BossRoomRegistry
## Boss kimliği → boss odası sahnesi eşlemesi.

const DEFAULT_BOSS_ID: String = "tepegoz"

const BOSS_SCENES: Dictionary = {
	"tepegoz": "res://scenes/boss_rooms/tepegoz_boss_room.tscn",
	"orb_scatter": "res://scenes/boss_rooms/orb_scatter_boss_room.tscn",
}

## Eski tek sahne yolu — geriye dönük referanslar için.
const LEGACY_BOSS_ROOM_SCENE: String = "res://scenes/boss_room.tscn"


static func get_boss_id(payload: Dictionary = {}) -> String:
	var from_payload := String(payload.get("boss_id", "")).strip_edges()
	if not from_payload.is_empty() and BOSS_SCENES.has(from_payload):
		return from_payload
	return DEFAULT_BOSS_ID


static func get_scene_path(boss_id: String = "") -> String:
	var id := boss_id.strip_edges()
	if id.is_empty():
		id = DEFAULT_BOSS_ID
	return String(BOSS_SCENES.get(id, BOSS_SCENES[DEFAULT_BOSS_ID]))


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
