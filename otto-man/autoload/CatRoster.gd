extends Node

## Köy kedilerinin KALICI kayıtları: her kedinin kimliği (id), adı, rengi ve oyuncuyla bağı (bond). Köy sahnesi her açıldığında
## kediler yeniden doğar; bu kayıt sayesinde aynı kediler (aynı ad, renk ve bağ) geri gelir ve kayda yazılır.
## Gelecek fazlar (bkz. hafızadaki kedi planı): balıkla besleme (fed_count), zindan eşlikçisi (companion) ve kedi başına özellik (trait).
## Bağ seviyeleri: 0 Yabancı (0-9), 1 Tanıdık (10-29), 2 Dost (30-59), 3 Yoldaş (60+).

signal cat_registered(cat_id: String)
signal bond_changed(cat_id: String, old_level: int, new_level: int)
signal companion_unlocked(cat_id: String)
signal companion_changed(cat_id: String)

const NAMES: Array[String] = [
	"Pamuk", "Duman", "Tarçın", "Mırmır", "Zeytin", "Fındık", "Karamel", "Boncuk", "Çıtır", "Minnoş",
	"Tekir", "Şeker", "Gölge", "Badem", "Kızılcık", "Sütlaç", "Pıtırcık", "Safran", "Kestane", "Limon",
	"Nane", "Yosun", "Pati", "Fıstık", "Misket", "Cesur", "Kıvırcık", "Kaplan", "Ceylan", "Tüylü",
]
const BOND_LEVEL_THRESHOLDS: Array[int] = [0, 10, 30, 60]
const PET_COOLDOWN_MSEC: int = 25000          # aynı kediyi art arda sevme aralığı
const PET_BOND_GAIN: int = 1
const PET_BOND_DAILY_CAP: int = 4             # bir kediden günde sevgiyle en fazla bu kadar bağ puanı kazanılır
const FISH_PER_DAY_CAP: int = 3               # bir kedi günde en fazla bu kadar balık ister (her balık 1 yiyecek yem harcar)
const FISH_BOND_GAIN: int = 5                 # kediye verilen her balığın bağ puanı

## Zindan eşlikçisi: kedi bu kadar balık yedikten sonra eşlikçi olabilir ve ilk kez özelliği belirlenir.
const COMPANION_FEED_REQUIREMENT: int = 3
## Kedi oyuncu ölünce bu kadar zindan seferi boyunca gelmez (kediler ölmez, küser ve dinlenir).
const REST_RUNS_AFTER_DEATH: int = 2
## Eşlikçi özellikleri (küçük avantajlar; can yenileme yok): bkz. CatCompanion.
const TRAITS: Array[String] = ["hunter", "gold_nose", "agile", "sharp", "shadow"]

## Her eşlikçi kedi özelliğine ek olarak Mucit yükseltmesiyle aynı değerde bir kalıcı bonus taşır (MetaUpgradeConfig yolu).
## "item": seferin başında +1 başlangıç eşyası seçimi (CampScene.START_ITEM_PICKS'e eklenir).
const PERKS: Array[String] = ["damage", "health", "stamina", "item"]

var _cats: Dictionary = {}                   # id -> {name, color, bond, pets, fed, trait, companion, pet_day, pets_today}
var _next_seq: int = 1
var _last_pet_msec: Dictionary = {}           # id -> msec (kaydedilmez)


# ─── Kayıt ───────────────────────────────────────────────────────────────────

func ids() -> Array[String]:
	var out: Array[String] = []
	for k in _cats.keys():
		out.append(String(k))
	return out


func has_cat(cat_id: String) -> bool:
	return _cats.has(cat_id)


func next_seq() -> int:
	return _next_seq


## Yeni (rengi henüz belli olmayan) bir kedi kaydı açıp kimliğini döndürür.
func create_cat_id() -> String:
	var id: String = "cat_%03d" % _next_seq
	_next_seq += 1
	_register(id)
	return id


## Var olan kimliği kaydeder (yoksa oluşturur) ve rengi belirler.
func register_cat(cat_id: String, color: Color = Color.WHITE) -> void:
	_register(cat_id)
	set_color(cat_id, color)


func _register(cat_id: String) -> void:
	if _cats.has(cat_id):
		return
	_cats[cat_id] = {
		"name": _pick_name(),
		"color": "",   # boş: renk henüz belli değil (kedi ilk doğduğunda rastgele seçilir ve buraya yazılır)
		"bond": 0, "pets": 0, "fed": 0,
		"trait": "", "companion": false,
		"pet_day": -1, "pets_today": 0, "fed_day": -1, "fed_today": 0, "rest_runs": 0,
	}
	# Elle verilen "cat_007" gibi kimliklerde sayaç geride kalmasın.
	var parts: PackedStringArray = cat_id.split("_")
	if parts.size() == 2 and parts[1].is_valid_int():
		_next_seq = maxi(_next_seq, int(parts[1]) + 1)
	cat_registered.emit(cat_id)


func _pick_name() -> String:
	var used: Dictionary = {}
	for c in _cats.values():
		used[String(c["name"])] = true
	var pool: Array[String] = []
	for n in NAMES:
		if not used.has(n):
			pool.append(n)
	if not pool.is_empty():
		return pool[randi() % pool.size()]
	# Havuz bitti: ad + sayı.
	return "%s %d" % [NAMES[randi() % NAMES.size()], used.size() + 1]


func set_color(cat_id: String, color: Color) -> void:
	if _cats.has(cat_id):
		_cats[cat_id]["color"] = color.to_html(true)


func has_color(cat_id: String) -> bool:
	return _cats.has(cat_id) and String(_cats[cat_id]["color"]) != ""


func get_color(cat_id: String) -> Color:
	if not has_color(cat_id):
		return Color.WHITE
	return Color.html(String(_cats[cat_id]["color"]))


func get_cat_name(cat_id: String) -> String:
	return String(_cats[cat_id]["name"]) if _cats.has(cat_id) else ""


func get_bond(cat_id: String) -> int:
	return int(_cats[cat_id]["bond"]) if _cats.has(cat_id) else 0


func get_fed_count(cat_id: String) -> int:
	return int(_cats[cat_id]["fed"]) if _cats.has(cat_id) else 0


func level_for_bond(bond: int) -> int:
	var level: int = 0
	for i in BOND_LEVEL_THRESHOLDS.size():
		if bond >= BOND_LEVEL_THRESHOLDS[i]:
			level = i
	return level


func get_level(cat_id: String) -> int:
	return level_for_bond(get_bond(cat_id))


# ─── Sevme ve bağ ────────────────────────────────────────────────────────────

func _today() -> int:
	var tm := get_node_or_null("/root/TimeManager")
	return int(tm.get_day()) if tm != null and tm.has_method("get_day") else 1


## Kedi şimdi sevilebilir mi (art arda sevmeyi önleyen kısa bekleme)?
func can_pet(cat_id: String) -> bool:
	if not _cats.has(cat_id):
		return false
	return Time.get_ticks_msec() - int(_last_pet_msec.get(cat_id, -PET_COOLDOWN_MSEC)) >= PET_COOLDOWN_MSEC


## Kediyi sever. Dönüş: {gained: int (bu sevişte kazanılan bağ), bond, level, leveled_up: bool, first_time: bool, capped: bool}.
## Günlük üst sınır dolduysa kedi yine sevilir (animasyon oynar) ama bağ puanı eklenmez.
func pet(cat_id: String) -> Dictionary:
	var result: Dictionary = {"gained": 0, "bond": 0, "level": 0, "leveled_up": false, "first_time": false, "capped": false}
	if not _cats.has(cat_id):
		return result
	var c: Dictionary = _cats[cat_id]
	_last_pet_msec[cat_id] = Time.get_ticks_msec()
	var today: int = _today()
	if int(c["pet_day"]) != today:
		c["pet_day"] = today
		c["pets_today"] = 0
	result["first_time"] = int(c["pets"]) == 0
	var level_before: int = level_for_bond(int(c["bond"]))
	c["pets"] = int(c["pets"]) + 1
	if int(c["pets_today"]) < PET_BOND_DAILY_CAP:
		c["pets_today"] = int(c["pets_today"]) + 1
		var before: int = int(c["bond"])
		add_bond(cat_id, PET_BOND_GAIN)
		result["gained"] = int(c["bond"]) - before
	else:
		result["capped"] = true
	result["bond"] = int(c["bond"])
	result["level"] = level_for_bond(int(c["bond"]))
	result["leveled_up"] = int(result["level"]) > level_before
	return result


func add_bond(cat_id: String, amount: int) -> void:
	if not _cats.has(cat_id) or amount == 0:
		return
	var c: Dictionary = _cats[cat_id]
	var old_level: int = level_for_bond(int(c["bond"]))
	c["bond"] = maxi(0, int(c["bond"]) + amount)
	var new_level: int = level_for_bond(int(c["bond"]))
	if new_level != old_level:
		bond_changed.emit(cat_id, old_level, new_level)


## Kedi şu an balık isteyebilir mi? Her kedi günde en fazla FISH_PER_DAY_CAP balık ister (balık tutma döngüsü sömürülmesin).
func can_ask_fish(cat_id: String) -> bool:
	if not _cats.has(cat_id):
		return false
	var c: Dictionary = _cats[cat_id]
	if int(c.get("fed_day", -1)) != _today():
		return true
	return int(c.get("fed_today", 0)) < FISH_PER_DAY_CAP


## Balıkla besleme: beslenen balık sayısı ve bağ artar (balık başına FISH_BOND_GAIN).
func record_fed(cat_id: String, fish_count: int = 1, bond_per_fish: int = FISH_BOND_GAIN) -> void:
	if not _cats.has(cat_id):
		return
	var c: Dictionary = _cats[cat_id]
	var today: int = _today()
	if int(c.get("fed_day", -1)) != today:
		c["fed_day"] = today
		c["fed_today"] = 0
	c["fed_today"] = int(c["fed_today"]) + fish_count
	c["fed"] = int(c["fed"]) + fish_count
	add_bond(cat_id, bond_per_fish * fish_count)
	# Gerekli balık sayısına ulaşan kedi eşlikçi olabilir: özelliği ilk kez burada belirlenir ve sonsuza dek aynı kalır.
	if int(c["fed"]) >= COMPANION_FEED_REQUIREMENT and String(c["trait"]) == "":
		c["trait"] = TRAITS[randi() % TRAITS.size()]
		c["perk"] = PERKS[randi() % PERKS.size()]
		companion_unlocked.emit(cat_id)


# ─── Zindan eşlikçisi ────────────────────────────────────────────────────────

func is_companion_eligible(cat_id: String) -> bool:
	return _cats.has(cat_id) and int(_cats[cat_id]["fed"]) >= COMPANION_FEED_REQUIREMENT and String(_cats[cat_id]["trait"]) != ""


func get_trait(cat_id: String) -> String:
	return String(_cats[cat_id]["trait"]) if _cats.has(cat_id) else ""


func get_perk(cat_id: String) -> String:
	if not _cats.has(cat_id):
		return ""
	var c: Dictionary = _cats[cat_id]
	# Perk eklenmeden önce özellik almış eski kayıtlar için tembel atama.
	if String(c.get("perk", "")) == "" and String(c.get("trait", "")) != "":
		c["perk"] = PERKS[randi() % PERKS.size()]
	return String(c.get("perk", ""))


## Kedinin bugün yediği balık sayısı (başka güne ait kayıt 0 sayılır).
func get_fed_today(cat_id: String) -> int:
	if not _cats.has(cat_id):
		return 0
	var c: Dictionary = _cats[cat_id]
	return int(c.get("fed_today", 0)) if int(c.get("fed_day", -1)) == _today() else 0


func get_rest_runs(cat_id: String) -> int:
	return int(_cats[cat_id].get("rest_runs", 0)) if _cats.has(cat_id) else 0


## Şu anki eşlikçinin kimliği ("" = yok). Aynı anda en fazla bir kedi eşlikçidir.
func get_companion_id() -> String:
	for k in _cats.keys():
		if bool(_cats[k]["companion"]):
			return String(k)
	return ""


func is_companion(cat_id: String) -> bool:
	return _cats.has(cat_id) and bool(_cats[cat_id]["companion"])


## Kediyi eşlikçi yapar (öncekinin eşlikçiliği kalkar) ya da eşlikçiliğini kaldırır.
func set_companion(cat_id: String, on: bool) -> bool:
	if not _cats.has(cat_id):
		return false
	if on:
		if not is_companion_eligible(cat_id):
			return false
		for k in _cats.keys():
			_cats[k]["companion"] = false
		_cats[cat_id]["companion"] = true
	else:
		_cats[cat_id]["companion"] = false
	companion_changed.emit(get_companion_id())
	return true


## Oyuncu ölünce eşlikçi kedi birkaç sefer dinlenir (zindana gelmez).
func start_rest(cat_id: String, runs: int = REST_RUNS_AFTER_DEATH) -> void:
	if _cats.has(cat_id):
		_cats[cat_id]["rest_runs"] = maxi(int(_cats[cat_id].get("rest_runs", 0)), runs)


## Yeni bir zindan seferi başladığında dinlenen kedilerin sayacı bir azalır. Bu sefer dinlenmesi gereken kedi mi (true)?
func consume_rest_for_new_run(cat_id: String) -> bool:
	if not _cats.has(cat_id):
		return false
	var left: int = int(_cats[cat_id].get("rest_runs", 0))
	if left <= 0:
		return false
	_cats[cat_id]["rest_runs"] = left - 1
	return true


# ─── Kayıt dosyası ───────────────────────────────────────────────────────────

func to_save() -> Dictionary:
	return {"seq": _next_seq, "cats": _cats.duplicate(true)}


func load_from_save(data: Dictionary) -> void:
	reset_for_new_game()
	_next_seq = maxi(1, int(data.get("seq", 1)))
	var saved: Variant = data.get("cats", {})
	if saved is Dictionary:
		for k in (saved as Dictionary).keys():
			var entry: Variant = (saved as Dictionary)[k]
			if not (entry is Dictionary):
				continue
			var e: Dictionary = entry
			_cats[String(k)] = {
				"name": String(e.get("name", _pick_name())),
				"color": String(e.get("color", "")),
				"bond": int(e.get("bond", 0)), "pets": int(e.get("pets", 0)), "fed": int(e.get("fed", 0)),
				"trait": String(e.get("trait", "")), "perk": String(e.get("perk", "")),"companion": bool(e.get("companion", false)),
				"pet_day": int(e.get("pet_day", -1)), "pets_today": int(e.get("pets_today", 0)),
				"fed_day": int(e.get("fed_day", -1)), "fed_today": int(e.get("fed_today", 0)),
				"rest_runs": int(e.get("rest_runs", 0)),
			}


func reset_for_new_game() -> void:
	_cats.clear()
	_last_pet_msec.clear()
	_next_seq = 1
