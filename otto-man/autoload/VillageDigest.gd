extends Node
## Köy özeti: oyuncu köyden uzaktayken (harita, orman, zindan) ya da köydeyken olan önemli şeylerin
## kısa, renk kodlu satırlarını biriktirir. VillageDigestTicker köy sahnesinde bunları ekranın
## üstünden aşağı doğru akıtır ve birkaç saniye sonra siler (mentorla konuşmaya gerek kalmasın).
##
## Kaynaklar burada dinlenir (savunma sonucu, görev bitişi, üretim, inşaat); köy olayları
## VillageManager'dan report_event_started/ended ile gelir. Hepsi `report()` çağırır.
## Satır metni BBCode'dur; sayılar `good()` / `bad()` / `warn()` ile renklendirilir.

signal entry_added

enum Tone { INFO, GOOD, WARN, BAD }

const COLOR_GOOD := "#8fdc7a"
const COLOR_BAD := "#ff7b6b"
const COLOR_WARN := "#ffc65c"
const COLOR_INFO := "#cfd8e3"
const TONE_ACCENTS: Dictionary = {
	Tone.INFO: Color(0.62, 0.72, 0.85),
	Tone.GOOD: Color(0.45, 0.82, 0.38),
	Tone.WARN: Color(0.96, 0.72, 0.26),
	Tone.BAD: Color(0.92, 0.32, 0.26),
}
## Aynı anda bekleyen en fazla satır; aşılırsa en eski ve en önemsiz atılır.
const MAX_PENDING: int = 40

var _pending: Array[Dictionary] = []
var _seq: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_sources.call_deferred()


func _connect_sources() -> void:
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm != null and wm.has_signal("defense_outcome_report") and not wm.defense_outcome_report.is_connected(_on_defense_outcome):
		wm.defense_outcome_report.connect(_on_defense_outcome)
	var mm: Node = get_node_or_null("/root/MissionManager")
	if mm != null and mm.has_signal("mission_completed") and not mm.mission_completed.is_connected(_on_mission_completed):
		mm.mission_completed.connect(_on_mission_completed)
	if mm != null and mm.has_signal("mission_started") and not mm.mission_started.is_connected(_on_mission_started):
		mm.mission_started.connect(_on_mission_started)
	if mm != null and mm.has_signal("concubine_leveled_up") and not mm.concubine_leveled_up.is_connected(_on_concubine_leveled_up):
		mm.concubine_leveled_up.connect(_on_concubine_leveled_up)
	# Köy haberleri "son dakika" satırı olarak da akar
	if mm != null and mm.has_signal("news_posted") and not mm.news_posted.is_connected(_on_news_posted):
		mm.news_posted.connect(_on_news_posted)
	var vm: Node = get_node_or_null("/root/VillageManager")
	if vm != null:
		if vm.has_signal("time_skip_completed") and not vm.time_skip_completed.is_connected(_on_time_skip):
			vm.time_skip_completed.connect(_on_time_skip)
		if vm.has_signal("construction_completed") and not vm.construction_completed.is_connected(_on_construction):
			vm.construction_completed.connect(_on_construction)


## --- Genel API ---

## text: BBCode. icon: satır başı emoji/sembol (placeholder, ileride sprite olabilir).
func report(text: String, tone: int = Tone.INFO, icon: String = "") -> void:
	if text.strip_edges().is_empty():
		return
	for e in _pending:
		if String(e.get("text", "")) == text and String(e.get("icon", "")) == icon:
			return
	_seq += 1
	_pending.append({"seq": _seq, "text": text, "tone": tone, "icon": icon})
	while _pending.size() > MAX_PENDING:
		_drop_least_important()
	entry_added.emit()


## Bekleyen satırları (önem sırasıyla, aynı önemde eskiden yeniye) verir ve kuyruğu boşaltır.
func take_pending() -> Array[Dictionary]:
	var out: Array[Dictionary] = _pending.duplicate()
	_pending.clear()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: int = int(a.get("tone", 0))
		var tb: int = int(b.get("tone", 0))
		if ta != tb:
			return ta > tb
		return int(a.get("seq", 0)) < int(b.get("seq", 0))
	)
	return out


func has_pending() -> bool:
	return not _pending.is_empty()


func clear() -> void:
	_pending.clear()


func _drop_least_important() -> void:
	var worst: int = 0
	for i in range(_pending.size()):
		var tone_i: int = int(_pending[i].get("tone", 0))
		var tone_w: int = int(_pending[worst].get("tone", 0))
		if tone_i < tone_w or (tone_i == tone_w and int(_pending[i].get("seq", 0)) < int(_pending[worst].get("seq", 0))):
			worst = i
	_pending.remove_at(worst)


## --- BBCode yardımcıları ---

static func good(s: String) -> String:
	return "[color=%s]%s[/color]" % [COLOR_GOOD, s]


static func bad(s: String) -> String:
	return "[color=%s]%s[/color]" % [COLOR_BAD, s]


static func warn(s: String) -> String:
	return "[color=%s]%s[/color]" % [COLOR_WARN, s]


static func info(s: String) -> String:
	return "[color=%s]%s[/color]" % [COLOR_INFO, s]


## +N / -N biçiminde işaretli sayı, işarete göre yeşil/kırmızı.
static func delta(label: String, amount: int) -> String:
	if amount == 0:
		return ""
	var s: String = "%+d %s" % [amount, label]
	return good(s) if amount > 0 else bad(s)


func _resource_name(res: String) -> String:
	var lm: Node = get_node_or_null("/root/LocaleManager")
	if lm != null and lm.has_method("get_resource_name"):
		return String(lm.call("get_resource_name", res))
	return res


## --- Kaynak: savunma sonucu ---

func _on_defense_outcome(report_data: Dictionary) -> void:
	var attacker: String = String(report_data.get("attacker", "?"))
	var won: bool = String(report_data.get("victor", "defender")) == "defender"
	var soldiers_lost: int = int(report_data.get("defender_losses", 0))
	var parts: PackedStringArray = PackedStringArray()
	# Ölen askerlerin adları köyden silinirken VillageManager'dan ayrı satırla gelir (kesin sayı oradan)
	if won:
		report(tr("digest.raid.won") % attacker, Tone.GOOD, "🛡")
		if int(report_data.get("alliance_defender_count", 0)) > 0 or bool(report_data.get("alliance_defender", false)):
			parts.append(good(tr("digest.raid.allied_help")))
	else:
		report(tr("digest.raid.lost") % attacker, Tone.BAD, "💥")
		var gold_loss: int = int(report_data.get("gold_loss", 0))
		if gold_loss > 0:
			parts.append(bad(tr("digest.gold") % -gold_loss))
		var losses: Variant = report_data.get("resource_losses", {})
		if losses is Dictionary:
			for res in (losses as Dictionary).keys():
				var amt: int = int((losses as Dictionary)[res])
				if amt > 0:
					parts.append(bad("-%d %s" % [amt, _resource_name(String(res))]))
		var disarmed: int = int(report_data.get("soldiers_disarmed", 0))
		if disarmed > 0:
			parts.append(warn(tr("digest.raid.disarmed") % disarmed))
		var morale: int = int(report_data.get("morale_delta", 0))
		if morale != 0:
			parts.append(good(tr("digest.raid.morale") % morale) if morale > 0 else bad(tr("digest.raid.morale") % morale))
	if not parts.is_empty():
		report("   ".join(parts), Tone.GOOD if won else Tone.BAD, "")


## --- Kaynak: haberler (MissionManager.post_news) ---

const NEWS_CONTENT_MAX_CHARS: int = 120
## Haber başlığı bu çeviri anahtarlarından birini içeriyorsa atlanır (aynı bilgi kendi satırıyla zaten gelir)
const COVERED_TITLE_KEYS: Array[String] = ["village.shortage.title", "digest.cariye.title_covered"]
static var _number_regex: RegEx = null

func _on_news_posted(news: Dictionary) -> void:
	# Savunma sonucu gibi yapılandırılmış satırı olan haberler iki kez gösterilmesin
	if bool(news.get("digest_skip", false)):
		return
	# Yalnız köyde olup bitenler: dünya haberleri (uzak köyler, ticaret modları) satıra girmez.
	# İstisna: köyü doğrudan ilgilendiren dünya haberleri (baskın uyarısı) digest_keep ile gelir.
	var category: String = String(news.get("category", "")).to_lower()
	if not (category in ["village", "başarı", "bilgi"]) and not bool(news.get("digest_keep", false)):
		return
	# Yapılandırılmış satırı olan köy haberleri (yiyecek yetmedi, cariye ihtiyacı) çift gösterilmesin
	var raw_title: String = String(news.get("title", ""))
	for covered_key in COVERED_TITLE_KEYS:
		if raw_title.contains(tr(covered_key)):
			return
	var title: String = String(news.get("title", "")).strip_edges()
	var content: String = String(news.get("content", "")).strip_edges()
	if title.is_empty() and content.is_empty():
		return
	var tone: int = Tone.INFO
	match String(news.get("subcategory", "info")):
		"critical":
			tone = Tone.BAD
		"warning":
			tone = Tone.WARN
		"success":
			tone = Tone.GOOD
	var accent: String = ""
	match tone:
		Tone.BAD:
			accent = COLOR_BAD
		Tone.WARN:
			accent = COLOR_WARN
		Tone.GOOD:
			accent = COLOR_GOOD
		_:
			accent = COLOR_INFO
	var text: String = "[color=%s]%s[/color]" % [accent, _escape_bbcode(title)]
	# Satırda yalnız başlık: "Festival başladı", "Ticaret modu değişti" yeter. Çarpan, ayrıntı, uzun cümle yok.
	# Tek istisna tehlikeli (kritik) haberler: ne olduğunu anlamak için kısa içerik eklenir.
	if tone == Tone.BAD and not content.is_empty():
		if content.length() > NEWS_CONTENT_MAX_CHARS:
			content = content.substr(0, NEWS_CONTENT_MAX_CHARS).strip_edges() + "…"
		text += "   " + _highlight_numbers(_escape_bbcode(content))
	elif title.is_empty():
		text = _escape_bbcode(content.substr(0, NEWS_CONTENT_MAX_CHARS))
	report(text, tone, "")


static func _escape_bbcode(s: String) -> String:
	return s.replace("[", "[lb]")


## Haber metnindeki sayıları renklendirir: +N yeşil, -N kırmızı, düz sayı sarı.
static func _highlight_numbers(s: String) -> String:
	if _number_regex == null:
		_number_regex = RegEx.new()
		_number_regex.compile("[+\\-]?\\d+")
	var out: String = ""
	var last: int = 0
	for m in _number_regex.search_all(s):
		var start: int = m.get_start()
		var token: String = m.get_string()
		out += s.substr(last, start - last)
		var col: String = COLOR_WARN
		if token.begins_with("+"):
			col = COLOR_GOOD
		elif token.begins_with("-") and start > 0 and s[start - 1] == " ":
			col = COLOR_BAD
		elif token.begins_with("-"):
			# "5-10" gibi aralık: tireyi renklendirme
			out += token.substr(0, 1)
			token = token.substr(1)
		out += "[color=%s]%s[/color]" % [col, token]
		last = m.get_end()
	out += s.substr(last)
	return out


## --- Kaynak: görev sonucu ---

func _on_mission_completed(_cariye_id: int, _mission_id: String, successful: bool, results: Dictionary) -> void:
	var mission_name: String = String(results.get("mission_name", ""))
	if mission_name.is_empty():
		return
	var detail: Variant = results.get("rewards", {}) if successful else results.get("penalties", {})
	var parts: PackedStringArray = PackedStringArray()
	if detail is Dictionary:
		for k in (detail as Dictionary).keys():
			var amt: int = int((detail as Dictionary)[k])
			if amt == 0:
				continue
			var key: String = String(k)
			if key == "gold":
				parts.append(good(tr("digest.gold") % amt) if amt > 0 else bad(tr("digest.gold") % amt))
			elif key in ["wood", "stone", "food", "water", "medicine", "metal"]:
				parts.append(delta(_resource_name(key), amt))
	var head: String = tr("digest.mission.won") % mission_name if successful else tr("digest.mission.lost") % mission_name
	var text: String = head
	if not parts.is_empty():
		text += "   " + "   ".join(parts)
	report(text, Tone.GOOD if successful else Tone.WARN, "📜")


## --- Kaynak: cariyeler ---

func _concubine_name(cariye_id: int) -> String:
	var mm: Node = get_node_or_null("/root/MissionManager")
	if mm != null and mm.get("concubines") != null and (mm.concubines as Dictionary).has(cariye_id):
		var c: Variant = mm.concubines[cariye_id]
		if c != null and "name" in c:
			return String(c.name)
	return tr("cariye.unknown")


func _on_mission_started(cariye_id: int, mission_id: String) -> void:
	var mm: Node = get_node_or_null("/root/MissionManager")
	var mission_name: String = mission_id
	if mm != null and mm.get("missions") != null and (mm.missions as Dictionary).has(mission_id) and mm.has_method("get_mission_display_name"):
		mission_name = String(mm.call("get_mission_display_name", mm.missions[mission_id]))
	report(tr("digest.cariye.departed") % [_concubine_name(cariye_id), mission_name], Tone.INFO, "🐎")


func _on_concubine_leveled_up(cariye_id: int, new_level: int) -> void:
	report(tr("digest.cariye.leveled") % [_concubine_name(cariye_id), new_level], Tone.GOOD, "⭐")


## Cariye yaralandı / yeni cariye katıldı gibi doğrudan çağrılanlar (MissionManager)
func report_concubine_injured(cariye_name: String) -> void:
	report(tr("digest.cariye.injured") % cariye_name, Tone.BAD, "🩹")


func report_army_lost(count: int) -> void:
	report(bad(tr("digest.army.lost") % count), Tone.BAD, "⚔")


func report_building_upgraded(building_name: String, level: int) -> void:
	report(tr("digest.building.upgraded") % [building_name, level], Tone.GOOD, "🔨")


func report_concubine_joined(cariye_name: String) -> void:
	report(tr("digest.cariye.joined") % cariye_name, Tone.GOOD, "💃")


## --- Kaynak: yokluğunda üretim ---

func _on_time_skip(total_hours: float, produced_resources: Dictionary, construction_footnote: String = "") -> void:
	var hours: int = maxi(1, int(round(total_hours)))
	var parts: PackedStringArray = PackedStringArray()
	if produced_resources is Dictionary:
		for res in (produced_resources as Dictionary).keys():
			var amt: int = int((produced_resources as Dictionary)[res])
			if amt > 0:
				parts.append(good("+%d %s" % [amt, _resource_name(String(res))]))
	if parts.is_empty():
		report(tr("digest.produced_none") % hours, Tone.WARN, "📦")
	else:
		report(tr("digest.produced") % hours + "   " + "   ".join(parts), Tone.INFO, "📦")
	if not construction_footnote.is_empty():
		report(info(construction_footnote), Tone.INFO, "🏗")


## --- Kaynak: inşaat ---

func _on_construction(scene_path: String) -> void:
	var display: String = scene_path.get_file().trim_suffix(".tscn")
	var lm: Node = get_node_or_null("/root/LocaleManager")
	if lm != null and lm.has_method("get_building_name"):
		display = String(lm.call("get_building_name", scene_path))
	report(tr("digest.built") % display, Tone.GOOD, "🏠")


## --- Köy olayları (VillageManager çağırır) ---

func report_event_started(event_name: String, positive: bool, detail: String = "") -> void:
	var text: String = (good(event_name) if positive else bad(event_name)) + " " + tr("digest.event.start")
	if not detail.is_empty():
		text += "   " + warn(detail)
	report(text, Tone.GOOD if positive else Tone.BAD, "✨" if positive else "⚠")


func report_event_ended(event_name: String, resolved: bool = false) -> void:
	report(tr("digest.event.end") % event_name, Tone.GOOD if resolved else Tone.INFO, "✔")
