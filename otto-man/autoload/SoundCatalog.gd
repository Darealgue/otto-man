extends RefCounted
class_name SoundCatalog
## Ses ID → dosya adı. Gerçek asset: aynı isimle `assets/audio/` altına koy.

const SFX_ROOT := "res://assets/audio/sfx/"
const BGS_ROOT := "res://assets/audio/bgs/"
const MUSIC_ROOT := "res://assets/audio/music/"

const EXTENSIONS: PackedStringArray = ["ogg", "wav", "mp3"]

const SFX_FILES: Dictionary = {
	"click": "ui_click",
	"confirm": "ui_confirm",
	"cancel": "ui_cancel",
	"hurt": "player_hurt",
	"death": "player_death",
	"door_open": "door_open",
	"door_locked": "door_locked",
	"hit_light": "combat_hit_light",
	"hit_heavy": "combat_hit_heavy",
	"hit_whiff": "combat_whiff",
	"block": "combat_block",
	"parry": "combat_parry",
	"pickup": "pickup",
	"build_complete": "build_complete",
	"attack_swipe": "combat_swipe",
	"footstep_player": "footstep_player",
	"footstep_dirt": "footstep_player_dirt",
	"jump": "player_jump",
	"land": "player_land",
	"land_heavy": "player_land_heavy",
	"land_dirt": "player_land_dirt",
	"dash": "player_dash",
	"dodge": "player_dodge",
	"slide": "player_slide",
	"enemy_hurt": "enemy_hurt",
	"enemy_death": "enemy_death",
	"enemy_alert": "enemy_alert",
	"enemy_attack_swing": "enemy_attack_swing",
	"projectile_fire": "projectile_fire",
	"projectile_hit": "projectile_hit",
}

## Dosya yoksa sırayla dene (ör. `player_land_heavy` yoksa `player_land`).
const SFX_FALLBACK_STEMS: Dictionary = {
	"land_heavy": ["player_land"],
	"hit_heavy": ["combat_hit_light"],
}

const AMBIENT_FILES: Dictionary = {
	"village_day": "village_ambient_day",
	"village_night": "village_ambient_night",
	"forest_day": "forest_ambient_day",
	"forest_night": "forest_ambient_night",
	"dungeon": "dungeon_ambient",
	"river": "river_ambient",
}

const MUSIC_FILES: Dictionary = {
	"menu": "menu_ambient",
}


static func get_sfx_file_stem(sound_id: String) -> String:
	return String(SFX_FILES.get(sound_id, sound_id))


static func get_ambient_file_stem(track_id: String) -> String:
	return String(AMBIENT_FILES.get(track_id, track_id))


static func get_music_file_stem(track_id: String) -> String:
	return String(MUSIC_FILES.get(track_id, track_id))


static func resolve_sfx_path(sound_id: String) -> String:
	var stems: Array[String] = []
	stems.append(get_sfx_file_stem(sound_id))
	for alt in SFX_FALLBACK_STEMS.get(sound_id, []):
		stems.append(String(alt))
	for stem in stems:
		if stem.is_empty():
			continue
		var path: String = _resolve_in_folder(SFX_ROOT, stem)
		if not path.is_empty():
			return path
	return ""


static func resolve_ambient_path(track_id: String) -> String:
	return _resolve_in_folder(BGS_ROOT, get_ambient_file_stem(track_id))


static func resolve_music_path(track_id: String) -> String:
	var ambient: String = resolve_ambient_path(track_id)
	if not ambient.is_empty():
		return ambient
	return _resolve_in_folder(MUSIC_ROOT, get_music_file_stem(track_id))


static func list_sfx_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in SFX_FILES.keys():
		ids.append(String(k))
	return ids


static func list_ambient_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in AMBIENT_FILES.keys():
		ids.append(String(k))
	return ids


static func list_music_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in MUSIC_FILES.keys():
		ids.append(String(k))
	for k in AMBIENT_FILES.keys():
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
	for track_id in AMBIENT_FILES.keys():
		var stem_a: String = String(AMBIENT_FILES[track_id])
		var resolved_a: String = resolve_ambient_path(String(track_id))
		rows.append({
			"id": String(track_id),
			"category": "ambient",
			"file_stem": stem_a,
			"expected_path": BGS_ROOT + stem_a + ".ogg",
			"resolved": resolved_a,
			"has_asset": not resolved_a.is_empty(),
		})
	for track_id in MUSIC_FILES.keys():
		var stem_m: String = String(MUSIC_FILES[track_id])
		var resolved_m: String = _resolve_in_folder(MUSIC_ROOT, stem_m)
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
