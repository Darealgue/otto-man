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


## Kayıtlı yerleşim adını aktif dile çevirir (EN: sıfat + ek parçaları).
static func localize_name(stored: String) -> String:
	var raw := stored.strip_edges()
	if raw.is_empty():
		return raw
	var lm := Engine.get_main_loop()
	if lm == null or not (lm is SceneTree):
		return raw
	var locale_mgr: Node = (lm as SceneTree).root.get_node_or_null("/root/LocaleManager")
	if locale_mgr == null or not locale_mgr.has_method("get_locale"):
		return raw
	if String(locale_mgr.call("get_locale")) == "tr":
		return raw
	if raw.begins_with("Adsiz Koy "):
		var num := raw.substr("Adsiz Koy ".length())
		return locale_mgr.call("tr_key", "wm.settlement.unnamed", [num]) as String
	var parts: PackedStringArray = raw.split(" ", false, 1)
	if parts.size() < 2:
		return raw
	var adj_key := "wm.settlement.adj.%s" % parts[0].to_lower()
	var suf_key := "wm.settlement.suffix.%s" % parts[1].to_lower()
	var adj_tr: String = String(locale_mgr.call("tr", adj_key))
	var suf_tr: String = String(locale_mgr.call("tr", suf_key))
	if adj_tr == adj_key:
		adj_tr = parts[0]
	if suf_tr == suf_key:
		suf_tr = parts[1]
	return "%s %s" % [adj_tr, suf_tr]
