extends Node
## Yapılandırılmış görev/olay brief üretici (canonical EN prompt string).

const SCHEMA_VERSION: int = 1

const COMPASS_EN: PackedStringArray = [
	"east", "northeast", "north", "northwest",
	"west", "southwest", "south", "southeast",
]

const MISSION_TYPE_KEYS: Dictionary = {
	0: "war",
	1: "exploration",
	2: "diplomacy",
	3: "trade",
	4: "intelligence",
	5: "bureaucracy",
}

const DIFFICULTY_KEYS: Dictionary = {
	0: "easy",
	1: "medium",
	2: "hard",
	3: "legendary",
}


func get_output_locale() -> String:
	var lm: Node = _locale_manager()
	if lm and lm.has_method("get_locale"):
		return str(lm.call("get_locale")).strip_edges().to_lower()
	return "tr"


func build_from_incident(incident: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var settlement_id: String = String(incident.get("settlement_id", ""))
	var settlement_name: String = String(incident.get("settlement_name", settlement_id))
	var incident_type: String = String(incident.get("type", "unknown"))
	var include_mission: bool = bool(extra.get("include_mission", false))
	var mission_id: String = String(extra.get("mission_id", ""))
	var stakes: Dictionary = extra.get("stakes", {}) if extra.get("stakes") is Dictionary else {}
	var source: String = "incident_relief" if include_mission else "settlement_incident"
	return _base_brief(
		"news_pair" if include_mission else "news",
		source,
		mission_id if not mission_id.is_empty() else String(incident.get("id", "")),
		_location_for_settlement(settlement_id, settlement_name),
		{
			"type": incident_type,
			"severity": float(incident.get("severity", 1.0)),
			"duration_days": int(incident.get("duration", 0)),
			"discovered": bool(extra.get("discovered", true)),
		},
		stakes,
		{
			"mission_type": String(extra.get("mission_type", "diplomacy")),
			"difficulty": String(extra.get("difficulty", "easy")),
			"linked_incident_id": String(incident.get("id", "")),
		}
	)


func build_from_mechanical(mech: Dictionary, source: String, extra: Dictionary = {}) -> Dictionary:
	var sid: String = String(mech.get("target_settlement_id", mech.get("settlement_id", "")))
	var sname: String = String(mech.get("target_location", mech.get("settlement_name", "")))
	var loc: Dictionary = _location_for_settlement(sid, sname) if not sid.is_empty() else _location_from_name(sname)
	var mtype_i: int = int(mech.get("mission_type", 2))
	var diff_i: int = int(mech.get("difficulty", 0))
	var stakes: Dictionary = {
		"success_rewards": mech.get("rewards", {}) if mech.get("rewards") is Dictionary else {},
		"failure_penalties": mech.get("penalties", {}) if mech.get("penalties") is Dictionary else {},
		"requirements": {
			"cariye_level": int(mech.get("required_cariye_level", 1)),
			"army_size": int(mech.get("required_army_size", 0)),
		},
		"success_chance": float(mech.get("success_chance", 0.7)),
	}
	var sit: Dictionary = extra.get("situation", {}) if extra.get("situation") is Dictionary else {}
	if sit.is_empty():
		sit = {"type": String(extra.get("event_type", source)), "severity": float(extra.get("severity", 1.0))}
	var ctx: Dictionary = {
		"mission_type": MISSION_TYPE_KEYS.get(mtype_i, "unknown"),
		"difficulty": DIFFICULTY_KEYS.get(diff_i, "medium"),
		"dynamic_type": String(mech.get("dynamic_type", "")),
		"locale_name_key": String(mech.get("locale_name_key", "")),
		"locale_desc_key": String(mech.get("locale_desc_key", "")),
		"linked_incident_id": String(mech.get("incident_id", mech.get("completes_incident_id", ""))),
		"attacker": String(extra.get("attacker", mech.get("attacker", ""))),
		"defender": String(extra.get("defender", "")),
		"partner": String(extra.get("partner", "")),
		"target_settlement": sname,
	}
	var kind: String = "news_pair" if bool(extra.get("include_mission", true)) else "news"
	if bool(extra.get("mission_only", false)):
		kind = "mission"
	return _base_brief(
		kind,
		source,
		String(mech.get("id", "")),
		loc,
		sit,
		stakes,
		ctx
	)


func build_news_brief(source: String, facts: Dictionary) -> Dictionary:
	return _base_brief(
		"news",
		source,
		String(facts.get("id", source + "_" + str(Time.get_unix_time_from_system()))),
		_location_from_facts(facts),
		{
			"type": String(facts.get("event_type", source)),
			"severity": float(facts.get("severity", 1.0)),
			"duration_days": int(facts.get("duration_days", 0)),
			"level": String(facts.get("level", "")),
		},
		{},
		facts
	)


func to_prompt_string(brief: Dictionary) -> String:
	if brief.is_empty():
		return ""
	var loc: Dictionary = brief.get("location", {}) if brief.get("location") is Dictionary else {}
	var sit: Dictionary = brief.get("situation", {}) if brief.get("situation") is Dictionary else {}
	var stakes: Dictionary = brief.get("stakes", {}) if brief.get("stakes") is Dictionary else {}
	var ctx: Dictionary = brief.get("context", {}) if brief.get("context") is Dictionary else {}
	var parts: PackedStringArray = PackedStringArray([
		"KIND:%s" % str(brief.get("kind", "")),
		"SOURCE:%s" % str(brief.get("source", "")),
		"ID:%s" % str(brief.get("id", "")),
		"LOCATION:q%s,r%s %s" % [loc.get("hex_q", "?"), loc.get("hex_r", "?"), str(loc.get("direction", ""))],
		"SETTLEMENT:%s" % str(loc.get("settlement_name", "")),
		"SITUATION:%s severity:%.2f duration:%dd" % [
			str(sit.get("type", "")),
			float(sit.get("severity", 1.0)),
			int(sit.get("duration_days", 0)),
		],
		"MISSION:%s %s" % [str(ctx.get("mission_type", "")), str(ctx.get("difficulty", ""))],
		"SUCCESS:%s" % _format_resource_dict(stakes.get("success_rewards", {})),
		"FAILURE:%s" % _format_resource_dict(stakes.get("failure_penalties", {})),
		"OUTPUT_LOCALE:%s" % str(brief.get("output_locale", "en")),
	])
	if ctx.has("attacker") and not str(ctx.get("attacker", "")).is_empty():
		parts.append("ATTACKER:%s" % str(ctx.get("attacker")))
	if ctx.has("defender") and not str(ctx.get("defender", "")).is_empty():
		parts.append("DEFENDER:%s" % str(ctx.get("defender")))
	if ctx.has("partner") and not str(ctx.get("partner", "")).is_empty():
		parts.append("PARTNER:%s" % str(ctx.get("partner")))
	if ctx.has("dynamic_type") and not str(ctx.get("dynamic_type", "")).is_empty():
		parts.append("DYNAMIC_TYPE:%s" % str(ctx.get("dynamic_type")))
	var ctx_extra: Dictionary = {}
	for k in ctx.keys():
		var ks: String = str(k)
		if ks in ["mission_type", "difficulty", "dynamic_type", "attacker", "defender", "partner", "target_settlement"]:
			continue
		ctx_extra[ks] = ctx[k]
	if not ctx_extra.is_empty():
		parts.append("CONTEXT:%s" % JSON.stringify(ctx_extra))
	return " | ".join(parts)


func to_json(brief: Dictionary) -> String:
	return JSON.stringify(brief)


func mechanical_news_for_incident(incident: Dictionary, discovered: bool) -> Dictionary:
	return mechanical_news("settlement_incident", {
		"event_type": String(incident.get("type", "")),
		"settlement_name": String(incident.get("settlement_name", "")),
		"duration_days": int(incident.get("duration", 0)),
		"discovered": discovered,
	})


func mechanical_mission_for_relief(incident: Dictionary) -> Dictionary:
	return mechanical_mission("incident_relief", {
		"settlement_name": String(incident.get("settlement_name", "")),
		"event_type": String(incident.get("type", "")),
	})


func mechanical_news(source: String, facts: Dictionary) -> Dictionary:
	var discovered: bool = bool(facts.get("discovered", true))
	var resolved: Dictionary = _resolve_news_template(source, facts)
	var title: String = String(resolved.get("title", ""))
	var body: String = String(resolved.get("body", ""))
	if title.is_empty():
		title = _fallback_news_title_for_source(source, facts)
	if body.is_empty():
		body = _format_mechanical_body(_fallback_news_body_for_source(source, facts), facts)
	if not discovered:
		body = _tr("narrative.news.undiscovered_prefix", "Duyum: ") + body
	return {
		"title": title,
		"body": body,
		"category": str(facts.get("news_category", _default_news_category(source))),
		"color": facts.get("news_color", _default_news_color(source)),
		"subcategory": str(facts.get("subcategory", _default_news_subcategory(source))),
	}


func mechanical_mission(source: String, facts: Dictionary) -> Dictionary:
	if not facts.get("title", "").is_empty():
		return {"title": str(facts.get("title")), "body": str(facts.get("body", ""))}
	var resolved: Dictionary = _resolve_mission_template(source, facts)
	var title: String = String(resolved.get("title", ""))
	var body: String = String(resolved.get("body", ""))
	if title.is_empty():
		title = _format_mechanical_body(_fallback_mission_title(source, facts), facts)
	if body.is_empty():
		body = _format_mechanical_body(_fallback_mission_body(source, facts), facts)
	return {"title": title, "body": body}


func _resolve_news_template(source: String, facts: Dictionary) -> Dictionary:
	var etype: String = String(facts.get("event_type", ""))
	var prefixes: PackedStringArray = PackedStringArray()
	if not etype.is_empty():
		prefixes.append("narrative.news.%s.%s" % [source, etype])
		prefixes.append("narrative.news.incident.%s" % etype)
		prefixes.append("narrative.news.village_event_%s" % etype)
		prefixes.append("narrative.news.village_event.%s" % etype)
	prefixes.append("narrative.news.%s" % source)
	for prefix in prefixes:
		var title_key: String = "%s.title" % prefix
		var body_key: String = "%s.body" % prefix
		var title: String = _tr_or_empty(title_key)
		if title.is_empty():
			continue
		var body_tpl: String = _tr_or_empty(body_key)
		if body_tpl.is_empty():
			continue
		return {
			"title": title,
			"body": _format_mechanical_body(body_tpl, facts),
		}
	return {"title": "", "body": ""}


func _resolve_mission_template(source: String, facts: Dictionary) -> Dictionary:
	var prefixes: PackedStringArray = PackedStringArray([
		"narrative.mission.%s" % source,
	])
	if source == "incident_relief":
		prefixes.append("narrative.mission.relief")
	for prefix in prefixes:
		var title_key: String = "%s.mechanical_name" % prefix
		var body_key: String = "%s.mechanical_desc" % prefix
		var title: String = _tr_or_empty(title_key)
		if title.is_empty():
			continue
		var body_tpl: String = _tr_or_empty(body_key)
		if body_tpl.is_empty():
			continue
		return {
			"title": _format_mechanical_body(title, facts),
			"body": _format_mechanical_body(body_tpl, facts),
		}
	return {"title": "", "body": ""}


func _default_news_category(source: String) -> String:
	if source.begins_with("village") or source.begins_with("village_"):
		return "Köy"
	return "Dünya"


func _default_news_subcategory(source: String) -> String:
	match source:
		"conflict_start", "conflict_raid", "worldmap_raid", "defense_dict", "village_event_raid":
			return "warning"
		"conflict_result", "village_surface_windfall", "village_surface_resource_discovery":
			return "success"
		"village_surface_minor_accident", "village_surface_cariye_shortage":
			return "warning"
		_:
			return "info"


func _default_news_color(source: String) -> Color:
	match _default_news_subcategory(source):
		"warning":
			return Color(1.0, 0.85, 0.75)
		"success":
			return Color(0.82, 1.0, 0.82)
		"critical":
			return Color(1.0, 0.65, 0.65)
		_:
			return Color(0.88, 0.93, 1.0)


func _tr_or_empty(key: String) -> String:
	var text: String = tr(key)
	if text.is_empty() or text == key:
		return ""
	return text


func _base_brief(
	kind: String,
	source: String,
	id: String,
	location: Dictionary,
	situation: Dictionary,
	stakes: Dictionary,
	context: Dictionary
) -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"kind": kind,
		"source": source,
		"id": id,
		"location": location,
		"situation": situation,
		"stakes": stakes,
		"context": context,
		"output_locale": get_output_locale(),
	}


func _location_from_facts(facts: Dictionary) -> Dictionary:
	var sid: String = String(facts.get("settlement_id", ""))
	var sname: String = String(facts.get("settlement_name", facts.get("target", "")))
	if not sid.is_empty():
		return _location_for_settlement(sid, sname)
	return _location_from_name(sname)


func _location_from_name(name: String) -> Dictionary:
	return {
		"hex_q": 0,
		"hex_r": 0,
		"hex_key": "",
		"direction": "unknown",
		"settlement_name": name,
		"settlement_id": "",
		"distance_hex": 0,
	}


func _location_for_settlement(settlement_id: String, settlement_name: String) -> Dictionary:
	var wm: Node = get_node_or_null("/root/WorldManager")
	var hex_q: int = 0
	var hex_r: int = 0
	var hex_key: String = ""
	var distance_hex: int = 0
	var direction: String = "unknown"
	if wm:
		if wm.has_method("get_settlement_hex_key_for_mission"):
			hex_key = String(wm.call("get_settlement_hex_key_for_mission", settlement_id))
		if not hex_key.is_empty():
			var parts: PackedStringArray = hex_key.split(",")
			if parts.size() >= 2:
				hex_q = int(parts[0])
				hex_r = int(parts[1])
		if wm.has_method("get_player_village_hex_coords"):
			var pv: Dictionary = wm.call("get_player_village_hex_coords")
			var pq: int = int(pv.get("q", 0))
			var pr: int = int(pv.get("r", 0))
			direction = _compass_from_delta(hex_q - pq, hex_r - pr)
			if wm.has_method("_hex_distance"):
				distance_hex = int(wm.call("_hex_distance", pq, pr, hex_q, hex_r))
	return {
		"hex_q": hex_q,
		"hex_r": hex_r,
		"hex_key": hex_key,
		"direction": direction,
		"settlement_name": settlement_name,
		"settlement_id": settlement_id,
		"distance_hex": distance_hex,
	}


func _compass_from_delta(dq: int, dr: int) -> String:
	if dq == 0 and dr == 0:
		return "here"
	var angle: float = atan2(float(-dr), float(dq))
	var idx: int = int(round(angle / (PI / 4.0))) % 8
	if idx < 0:
		idx += 8
	return COMPASS_EN[idx]


func _format_resource_dict(resources: Variant) -> String:
	if not (resources is Dictionary):
		return "none"
	var d: Dictionary = resources
	if d.is_empty():
		return "none"
	var parts: PackedStringArray = PackedStringArray()
	for key in d.keys():
		var k: String = str(key)
		if k == "cariye_injured":
			if bool(d[key]):
				parts.append("cariye_injured")
			continue
		if k == "reputation":
			parts.append("diplomacy%+d" % int(d[k]))
			continue
		parts.append("%s%+d" % [k, int(d[k])])
	return ",".join(parts) if parts.size() > 0 else "none"


func _format_mechanical_body(template: String, facts: Dictionary) -> String:
	var sname: String = String(facts.get("settlement_name", facts.get("target", "?")))
	var etype: String = String(facts.get("event_type", ""))
	var type_label: String = _tr("wm.incident.%s" % etype, etype) if not etype.is_empty() else ""
	var attacker: String = String(facts.get("attacker", facts.get("raid_attacker", "")))
	var defender: String = String(facts.get("defender", ""))
	var partner: String = String(facts.get("partner", ""))
	var duration: int = int(facts.get("duration_days", facts.get("duration", 0)))
	var days_until: int = int(facts.get("days_until", 0))
	var level: String = String(facts.get("level", ""))
	var mission_name: String = String(facts.get("mission_name", facts.get("headline", "")))
	var details: String = String(facts.get("details", ""))
	var kind_text: String = String(facts.get("kind_text", ""))
	var strike_resource: String = String(facts.get("strike_resource", ""))
	var resource_label: String = _tr("resource.%s" % strike_resource, strike_resource) if not strike_resource.is_empty() else ""
	var outcome: String = String(facts.get("outcome", ""))
	var message: String = String(facts.get("message", ""))
	var arg_count: int = template.count("%")
	match arg_count:
		0:
			return template
		1:
			if template.find("%s") >= 0:
				if not mission_name.is_empty():
					return template % mission_name
				if not sname.is_empty() and sname != "?":
					return template % sname
				if not attacker.is_empty():
					return template % attacker
				if not partner.is_empty():
					return template % partner
				if not outcome.is_empty():
					return template % outcome
				if not message.is_empty():
					return template % message
				if not kind_text.is_empty():
					return template % kind_text
				if days_until > 0:
					return template % days_until
				if duration > 0:
					return template % duration
				return template % type_label if not type_label.is_empty() else template
			return template
		2:
			if not attacker.is_empty() and not defender.is_empty():
				return template % [attacker, defender]
			if not sname.is_empty() and not type_label.is_empty():
				return template % [sname, type_label]
			if not sname.is_empty():
				return template % [sname, duration if duration > 0 else days_until]
			if not mission_name.is_empty() and not sname.is_empty():
				return template % [mission_name, sname]
			if not strike_resource.is_empty() and not resource_label.is_empty():
				return template % [resource_label, level if not level.is_empty() else type_label]
			if not outcome.is_empty() and not details.is_empty():
				return template % [outcome, details]
			if not partner.is_empty():
				return template % [partner, level if not level.is_empty() else type_label]
			return template % [attacker if not attacker.is_empty() else "?", defender if not defender.is_empty() else "?"]
		3:
			if not sname.is_empty():
				return template % [sname, type_label if not type_label.is_empty() else etype, duration if duration > 0 else days_until]
			return template % [attacker, defender, duration if duration > 0 else days_until]
		_:
			return template


func _fallback_news_title_for_source(source: String, _facts: Dictionary) -> String:
	match source:
		"alliance_aid": return "Muttefik Yardım Çağrısı"
		"dynamic_mission": return "Yeni Görev"
		"procedural": return "Görev Fırsatı"
		"conflict_defend": return "Savunma Yardımı"
		"conflict_raid": return "Baskın Fırsatı"
		"conflict_start": return "Çatışma Başladı"
		"conflict_result": return "Çatışma Sonucu"
		"world_event": return "Dünya Olayı"
		"worldmap_trade": return "Harita Ticaret Emri"
		"worldmap_diplomacy": return "Diplomasi Emri"
		"worldmap_raid": return "Harita Baskını"
		"defense_dict": return "Savunma Görevi"
		"bandit_clear": return "Haydut Temizliği"
		"plague_aid": return "Salgın Yardımı"
		"escort": return "Kervan Koruma"
		"special_elite": return "Elit Sözleşme"
		"special_emergency": return "Acil Müdahale"
		"incident_relief": return "Yardım Görevi"
		"settlement_incident": return "Yerleşim Krizi"
		"village_macro": return "Köy Bildirimi"
		"village_news": return "Köy Haberi"
		"village_surface_traveler": return "Seyyah Ziyareti"
		"village_surface_resource_discovery": return "Kaynak Keşfi"
		"village_surface_windfall": return "Bolluk"
		"village_surface_minor_accident": return "Küçük Kaza"
		"village_surface_immigration": return "Göç Dalgası"
		"village_surface_immigration_failed": return "Göç Durduruldu"
		"village_surface_trade_caravan_miss": return "Tüccar Gelmedi"
		"village_surface_cariye_shortage": return "Cariye İhtiyacı"
		_: return "Haber"


func _fallback_news_body_for_source(source: String, facts: Dictionary) -> String:
	var n: String = String(facts.get("settlement_name", facts.get("target", "")))
	var attacker: String = String(facts.get("attacker", facts.get("raid_attacker", "")))
	var mission_name: String = String(facts.get("mission_name", ""))
	match source:
		"alliance_aid": return "%s muttefik yardım talep ediyor." % n if not n.is_empty() else "Bir muttefik yardım talep ediyor."
		"dynamic_mission": return "Görev panosuna yeni bir iş eklendi."
		"procedural": return "Yeni bir görev fırsatı doğdu."
		"conflict_defend": return "%s savunması için yardım gerekiyor." % n if not n.is_empty() else "Savunma yardımı gerekiyor."
		"conflict_raid": return "%s hedefine baskın planlanabilir." % n if not n.is_empty() else "Baskın fırsatı doğdu."
		"bandit_clear": return "Yollarda haydut faaliyeti arttı."
		"plague_aid": return "Salgından etkilenen bölgelere yardım gerekiyor."
		"escort": return "Bir kervanın güvenli geçişi için destek isteniyor."
		"defense_dict": return "%s saldırısına karşı köy savunması planlandı." % attacker if not attacker.is_empty() else "Köy savunması planlandı."
		"worldmap_trade": return "%s ile ticaret görevi hazır." % n if not n.is_empty() else "Ticaret görevi hazır."
		"worldmap_diplomacy": return "%s ile diplomasi görevi hazır." % n if not n.is_empty() else "Diplomasi görevi hazır."
		"worldmap_raid": return "%s hedefine baskın görevi açıldı." % n if not n.is_empty() else "Baskın görevi açıldı."
		"special_elite": return "Yüksek itibar sayesinde elit bir sözleşme geldi."
		"special_emergency": return "Dünya istikrarı için acil müdahale gerekiyor."
		"village_surface_traveler": return "Bir seyyah köyünüze uğradı. Not: %s." % mission_name if not mission_name.is_empty() else "Bir seyyah köyünüze uğradı."
		"settlement_incident": return "%s — yerel kriz bildirildi." % n if not n.is_empty() else "Yakın yerleşimde kriz bildirildi."
		_: return "%s hakkında haber var." % n if not n.is_empty() else "Yeni bir olay bildirildi."


func _fallback_mission_title(source: String, facts: Dictionary) -> String:
	var n: String = String(facts.get("settlement_name", facts.get("target", "Görev")))
	match source:
		"alliance_aid": return "Muttefik Yardımı — %s" % n
		"incident_relief": return "Yardım — %s" % n
		"bandit_clear": return "Haydut Temizliği"
		"plague_aid": return "Salgın Yardımı"
		"escort": return "Kervan Koruma"
		"conflict_defend": return "Savunma: %s" % n
		"conflict_raid": return "Baskın: %s" % n
		"defense_dict": return "Savunma: %s" % String(facts.get("attacker", n))
		"worldmap_trade": return "Ticaret: %s" % n
		"worldmap_diplomacy": return "Diplomasi: %s" % n
		"worldmap_raid": return "Baskın: %s" % n
		"special_elite": return "Elit Sözleşme"
		"special_emergency": return "Acil Müdahale"
		"dynamic_mission", "procedural": return "Görev — %s" % n
		_: return "Görev — %s" % n


func _fallback_mission_body(source: String, facts: Dictionary) -> String:
	var n: String = String(facts.get("settlement_name", facts.get("target", "")))
	var etype: String = String(facts.get("event_type", ""))
	var type_label: String = _tr("wm.incident.%s" % etype, etype) if not etype.is_empty() else "kriz"
	match source:
		"alliance_aid": return "%s muttefik yardım çağrısına yanıt ver." % n if not n.is_empty() else "Muttefik yardım çağrısına yanıt ver."
		"incident_relief": return "%s köyündeki %s için yardım gönder." % [n, type_label] if not n.is_empty() else "Yardım gönder."
		"bandit_clear": return "Yollardaki haydutları temizle."
		"plague_aid": return "Salgından etkilenen bölgelere yardım ulaştır."
		"escort": return "Kervanı güvenle hedefe ulaştır."
		"conflict_defend": return "%s savunmasına destek ol." % n if not n.is_empty() else "Savunmaya destek ol."
		"conflict_raid": return "%s hedefine baskın düzenle." % n if not n.is_empty() else "Hedefe baskın düzenle."
		"defense_dict": return "%s saldırısına karşı köyü savun." % String(facts.get("attacker", "?"))
		_: return "%s için görev." % n if not n.is_empty() else "Yeni görev."


func _fallback_news_title(incident_type: String) -> String:
	match incident_type:
		"wolf_attack": return "Wolf Attack"
		"harvest_failure": return "Harvest Failure"
		"migrant_wave": return "Migration Wave"
		"bandit_road": return "Road Bandits"
		"plague_scare": return "Disease Scare"
		_: return "Settlement Crisis"


func _fallback_news_body(incident_type: String) -> String:
	match incident_type:
		"wolf_attack": return "%s — wolves sighted. (~%d days)"
		"harvest_failure": return "%s — poor harvest. (~%d days)"
		"migrant_wave": return "%s — incoming migrants. (~%d days)"
		"bandit_road": return "%s — bandit activity. (~%d days)"
		"plague_scare": return "%s — disease rumors. (~%d days)"
		_: return "%s — crisis. (~%d days)"


func _tr(key: String, fallback: String) -> String:
	var text: String = tr(key)
	return text if text != key else fallback


func _locale_manager() -> Node:
	return get_node_or_null("/root/LocaleManager")
