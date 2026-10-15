extends RefCounted
class_name WorldSettlementNames

## Yerleşim adları: HER ZAMAN "<sıfat ya da isim> Köy" ("Uzak Köy", "Tembel Köy", "Pilav Köy").
## Kayıtta ASCII yazılır (anahtar araması için); gösterimde localize_name() proper Türkçe/İngilizce yazar.
## Her kelimenin `wm.settlement.adj.<küçük harf>` çeviri anahtarı strings.csv'de olmalıdır.

const ADJECTIVES = [
	# sıfatlar
	"Kucuk", "Buyuk", "Issiz", "Sisli", "Ruzgarli", "Yash", "Genc", "Uzak", "Yakin",
	"Yesil", "Kuru", "Soguk", "Sicak", "Alcak", "Yuksek", "Dar", "Genis", "Sakin",
	"Gurultulu", "Karanlik", "Aydin", "Kayip", "Eski", "Yeni", "Derin", "Sig",
	"Kirli", "Temiz", "Yalniz", "Kalabalik", "Sessiz", "Cayir", "Tepeli", "Vadili",
	# esprili sıfatlar
	"Tembel", "Ac", "Uykulu", "Dedikodulu", "Kavgaci", "Inatci", "Cimri", "Saskin",
	"Mahcup", "Sivri", "Egri", "Bozuk", "Kokulu", "Sasirmis", "Gevrek", "Mutsuz",
	# esprili isimler
	"Horoz", "Kaz", "Esek", "Kurbaga", "Patates", "Sogan", "Pilav", "Corba", "Yogurt",
	"Simit", "Kavun", "Karpuz", "Kabak", "Tosbaga", "Deve", "Kedi", "Kopek", "Tavuk",
	"Ordek", "Hindi", "Karga", "Baykus", "Yilan", "Kurt", "Ayi", "Tilki", "Tavsan",
	"Salyangoz", "Hamsi", "Kofte", "Baklava", "Lokum", "Kebap", "Pazar", "Cesme",
	"Degirmen", "Kuyu",
]

const SUFFIX := "Koy"

## Eski kayıtlardaki yerleşim adı ekleri: gösterimde hepsi "Köy" olarak yazılır.
const LEGACY_SUFFIXES = ["koyu", "obasi", "mezrasi", "beldesi", "koylusu"]

static func pick_unique_settlement_name(rng: RandomNumberGenerator, used: Dictionary) -> String:
	for _attempt in range(64):
		var adj: String = ADJECTIVES[rng.randi() % ADJECTIVES.size()]
		var candidate: String = "%s %s" % [adj, SUFFIX]
		if used.has(candidate):
			continue
		used[candidate] = true
		return candidate
	return "Adsiz Koy %d" % rng.randi_range(100, 999)


## Kayıtlı yerleşim adını aktif dile çevirir (sıfat/isim + "Köy"). Türkçede de çevrilir ki kayıttaki ASCII yazım
## ("Kucuk Koy") ekranda proper Türkçe ("Küçük Köy") görünsün; eski kayıtlardaki Obası/Mezrası/Beldesi ekleri "Köy" olur.
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
	if raw.begins_with("Adsiz Koy "):
		var num := raw.substr("Adsiz Koy ".length())
		return locale_mgr.call("tr_key", "wm.settlement.unnamed", [num]) as String
	var parts: PackedStringArray = raw.split(" ", false, 1)
	if parts.size() < 2:
		return raw
	var adj_key := "wm.settlement.adj.%s" % parts[0].to_lower()
	var suf_word: String = parts[1].to_lower()
	if suf_word in LEGACY_SUFFIXES:
		suf_word = SUFFIX.to_lower()
	var suf_key := "wm.settlement.suffix.%s" % suf_word
	var adj_tr: String = String(locale_mgr.call("tr", adj_key))
	var suf_tr: String = String(locale_mgr.call("tr", suf_key))
	if adj_tr == adj_key:
		adj_tr = parts[0]
	if suf_tr == suf_key:
		suf_tr = parts[1]
	return "%s %s" % [adj_tr, suf_tr]
