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
	var title_key: String = "narrative.news.%s.title" % source
	var body_key: String = "narrative.news.%s.body" % source
	var title: String = _tr(title_key, _fallback_news_title_for_source(source, facts))
	var body: String = _format_mechanical_body(_tr(body_key, _fallback_news_body_for_source(source, facts)), facts)
	if not discovered:
		body = _tr("narrative.news.undiscovered_prefix", "Rumor: ") + body
	return {
		"title": title,
		"body": body,
		"category": str(facts.get("news_category", "Dünya")),
		"color": facts.get("news_color", Color(0.85, 0.92, 1.0)),
		"subcategory": str(facts.get("subcategory", "warning")),
	}


func mechanical_mission(source: String, facts: Dictionary) -> Dictionary:
	var title_key: String = "narrative.mission.%s.mechanical_name" % source
	var desc_key: String = "narrative.mission.%s.mechanical_desc" % source
	if not facts.get("title", "").is_empty():
		return {"title": str(facts.get("title")), "body": str(facts.get("body", ""))}
	var title: String = _format_mechanical_body(_tr(title_key, _fallback_mission_title(source, facts)), facts)
	var body: String = _format_mechanical_body(_tr(desc_key, _fallback_mission_body(source, facts)), facts)
	return {"title": title, "body": body}


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
	var outcome: String = String(facts.get("outcome", ""))
	var arg_count: int = template.count("%")
	match arg_count:
		0:
			return template
		1:
			if template.find("%s") >= 0:
				if not sname.is_empty() and sname != "?":
					return template % sname
				if not attacker.is_empty():
					return template % attacker
				if not partner.is_empty():
					return template % partner
				return template % outcome
			return template
		2:
			if not attacker.is_empty() and not defender.is_empty():
				return template % [attacker, defender]
			if not sname.is_empty():
				return template % [sname, duration if duration > 0 else type_label]
			return template % [partner, level]
		3:
			return template % [attacker, defender, duration]
		_:
			return template


func _fallback_news_title_for_source(source: String, _facts: Dictionary) -> String:
	match source:
		"alliance_aid": return "Ally Aid Call"
		"dynamic_mission": return "New Mission"
		"conflict_defend": return "Defense Aid"
		"conflict_raid": return "Raid Opportunity"
		"bandit_clear": return "Bandit Cleanup"
		"plague_aid": return "Plague Relief"
		"world_event": return "World Event"
		"village_event": return "Village Event"
		_: return "News"


func _fallback_news_body_for_source(source: String, facts: Dictionary) -> String:
	var n: String = String(facts.get("settlement_name", ""))
	match source:
		"alliance_aid": return "Ally %s requests aid." % n
		"dynamic_mission": return "A new mission is available."
		"bandit_clear": return "Bandit activity on the roads."
		_: return "%s — event reported." % n


func _fallback_mission_title(source: String, facts: Dictionary) -> String:
	var n: String = String(facts.get("settlement_name", facts.get("target", "Mission")))
	match source:
		"alliance_aid": return "Ally Aid — %s" % n
		"bandit_clear": return "Bandit Cleanup"
		"plague_aid": return "Plague Relief"
		_: return "Mission — %s" % n


func _fallback_mission_body(source: String, facts: Dictionary) -> String:
	var n: String = String(facts.get("settlement_name", ""))
	match source:
		"alliance_aid": return "Respond to ally aid call at %s." % n
		"bandit_clear": return "Clear bandits from the roads."
		"plague_aid": return "Deliver aid to plague-stricken regions."
		_: return "Mission at %s." % n


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
