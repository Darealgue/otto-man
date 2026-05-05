extends RefCounted
class_name WorldDungeonNames

const EPITHETS = [
	"Karanlik", "Unutulmus", "Kayip", "Derin", "Eskimis", "Kurak", "Ruzgarli",
	"Yarali", "Kirik", "Tuzlu", "Soguk", "Issiz", "Yanki", "Cifit", "Kumlu",
	"Kokulu", "Catlak", "Gizli", "Tilsimli", "Lanetli", "Cokusmus",
]

const SITES = [
	"Magarasi", "Ini", "Derinligi", "Kuyusu", "Yuruyusu", "Tuneli", "Mahzeni", "Oyugu",
]

static func pick_dungeon_name(rng: RandomNumberGenerator) -> String:
	var a: String = EPITHETS[rng.randi() % EPITHETS.size()]
	var b: String = SITES[rng.randi() % SITES.size()]
	return "%s %s" % [a, b]
