extends RefCounted
class_name SoundCatalog
## Ses ID → dosya adı eşlemesi.
## Placeholder veya gerçek asset: `assets/audio/sfx/<dosya>.{ogg,wav,mp3}` — aynı isimle üzerine yazman yeterli.

const SFX_ROOT := "res://assets/audio/sfx/"
const MUSIC_ROOT := "res://assets/audio/music/"

const EXTENSIONS: PackedStringArray = ["ogg", "wav", "mp3"]

## Oyun kodunda kullanılan ID → dosya kök adı (uzantısız)
const SFX_FILES: Dictionary = {
	"click": "ui_click",
	"confirm": "ui_confirm",
	"cancel": "ui_cancel",
	"hurt": "player_hurt",
	"death": "player_death",
	"door_open": "door_open",
	"door_locked": "door_locked",
	"hit_light": "combat_hit_light",
	"block": "combat_block",
	"pickup": "pickup",
	"build_complete": "build_complete",
	"attack_swipe": "combat_swipe",
	"footstep_player": "footstep_player",
}

const MUSIC_FILES: Dictionary = {
	"village": "village_ambient",
	"dungeon": "dungeon_ambient",
	"menu": "menu_ambient",
}


static func get_sfx_file_stem(sound_id: String) -> String:
	return String(SFX_FILES.get(sound_id, sound_id))


static func get_music_file_stem(track_id: String) -> String:
	return String(MUSIC_FILES.get(track_id, track_id))


static func resolve_sfx_path(sound_id: String) -> String:
	return _resolve_in_folder(SFX_ROOT, get_sfx_file_stem(sound_id))


static func resolve_music_path(track_id: String) -> String:
	return _resolve_in_folder(MUSIC_ROOT, get_music_file_stem(track_id))


static func list_sfx_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in SFX_FILES.keys():
		ids.append(String(k))
	return ids


static func list_music_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in MUSIC_FILES.keys():
		ids.append(String(k))
	return ids


static func get_manifest_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for sound_id in SFX_FILES.keys():
		var stem: String = String(SFX_FILES[sound_id])
		var resolved: String = resolve_sfx_path(String(sound_id))
		rows.append({
			"id": String(sound_id),
			"category": "sfx",
			"file_stem": stem,
			"expected_path": SFX_ROOT + stem + ".ogg",
			"resolved": resolved,
			"has_asset": not resolved.is_empty(),
		})
	for track_id in MUSIC_FILES.keys():
		var stem_m: String = String(MUSIC_FILES[track_id])
		var resolved_m: String = resolve_music_path(String(track_id))
		rows.append({
			"id": String(track_id),
			"category": "music",
			"file_stem": stem_m,
			"expected_path": MUSIC_ROOT + stem_m + ".ogg",
			"resolved": resolved_m,
			"has_asset": not resolved_m.is_empty(),
		})
	return rows


static func _resolve_in_folder(root: String, stem: String) -> String:
	if stem.is_empty():
		return ""
	for ext in EXTENSIONS:
		var path: String = root + stem + "." + ext
		if ResourceLoader.exists(path):
			return path
	return ""
