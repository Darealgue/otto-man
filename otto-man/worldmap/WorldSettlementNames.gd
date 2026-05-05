extends RefCounted
class_name WorldSettlementNames

## Turkce: sifat + koy / oba / mezra vb. (yeni dunya yerlesim isimleri)

const ADJECTIVES = [
	"Kucuk", "Buyuk", "Issiz", "Sisli", "Ruzgarli", "Yash", "Genc", "Uzak", "Yakin",
	"Yesil", "Kuru", "Soguk", "Sicak", "Alcak", "Yuksek", "Dar", "Genis", "Sakin",
	"Gurultulu", "Karanlik", "Aydin", "Kayip", "Eski", "Yeni", "Derin", "Sig",
	"Kirli", "Temiz", "Yalniz", "Kalabalik", "Sessiz", "Cayir", "Tepeli", "Vadili",
]

const SUFFIXES = [
	"Koyu", "Koy", "Obasi", "Mezrasi", "Beldesi", "Koylusu",
]

static func pick_unique_settlement_name(rng: RandomNumberGenerator, used: Dictionary) -> String:
	for _attempt in range(48):
		var adj: String = ADJECTIVES[rng.randi() % ADJECTIVES.size()]
		var suf: String = SUFFIXES[rng.randi() % SUFFIXES.size()]
		var candidate: String = "%s %s" % [adj, suf]
		if used.has(candidate):
			continue
		used[candidate] = true
		return candidate
	return "Adsiz Koy %d" % rng.randi_range(100, 999)
