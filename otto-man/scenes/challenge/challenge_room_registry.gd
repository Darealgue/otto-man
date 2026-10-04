class_name ChallengeRoomRegistry
extends RefCounted

## Challenge odaları: haritadaki geçici etkinlikler (bkz. docs/CHALLENGE_ROOMS.md). Tek sahne
## (challenge_room.tscn) türe ve mekâna (orman/zindan) göre kendini kurar.

const SCENE_PATH: String = "res://scenes/challenge/challenge_room.tscn"

## Tür kimliği -> görünen ad anahtarı (yerelleştirme).
const KINDS: Dictionary = {
	"koruma": "challenge.kind.koruma",
	"dalga": "challenge.kind.dalga",
	"asansor": "challenge.kind.asansor",
	"kovalamaca": "challenge.kind.kovalamaca",
	"tuzak": "challenge.kind.tuzak",
}

const BIOMES: Array[String] = ["orman", "zindan"]


## Asansör ve Tuzak Geçidi yalnız zindanda kurulur (ormanda asansör mantıksız görünüyordu); diğer türler istenen mekânda.
static func biome_for(kind: String, biome: String) -> String:
	return "zindan" if kind == "asansor" or kind == "tuzak" else biome


static func is_challenge_room_path(path: String) -> bool:
	return not path.is_empty() and "challenge_room" in path.to_lower()
