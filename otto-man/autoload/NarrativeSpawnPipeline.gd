extends Node
## Görev/olay anlatılarını LLM sonrası veya mechanical fallback ile yayınlar.

const _Mission = preload("res://village/scripts/Mission.gd")

signal narrative_brief_ready(request_id: String, brief: Dictionary, target_locale: String)
signal narrative_published(request_id: String, mode: String)

const TIMEOUT_SEC: float = 15.0
const RELIEF_MISSION_CHANCE: float = 0.38

var _pending: Dictionary = {}
var _wait_elapsed: Dictionary = {}


func _process(delta: float) -> void:
	var finished: Array[String] = []
	for rid in _wait_elapsed.keys():
		_wait_elapsed[rid] = float(_wait_elapsed[rid]) + delta
		if float(_wait_elapsed[rid]) >= TIMEOUT_SEC:
			finished.append(rid)
	for rid in finished:
		_wait_elapsed.erase(rid)
		if _pending.has(rid) and String(_pending[rid].get("status", "")) == "pending":
			_publish_mechanical(rid)


## Genel giriş — tüm görev/olay türleri.
## spec: request_id, source, brief, include_mission, mission_mechanical,
##       mechanical_mission, mechanical_news, post_news, publish_mission, publish_dict_mission
func enqueue(spec: Dictionary) -> String:
	if spec.is_empty():
		return ""
	var request_id: String = String(spec.get("request_id", ""))
	if request_id.is_empty():
		request_id = "%s_%d" % [str(spec.get("source", "narrative")), Time.get_unix_time_from_system()]
	var locale: String = AiNarrativeBrief.get_output_locale()
	var brief: Dictionary = spec.get("brief", {}) if spec.get("brief") is Dictionary else {}
	if brief.is_empty() and spec.get("mission_mechanical") is Dictionary:
		brief = AiNarrativeBrief.build_from_mechanical(
			spec["mission_mechanical"],
			String(spec.get("source", "")),
			spec.get("brief_extra", {}) if spec.get("brief_extra") is Dictionary else {}
		)
	elif brief.is_empty() and spec.get("news_facts") is Dictionary:
		brief = AiNarrativeBrief.build_news_brief(String(spec.get("source", "news")), spec["news_facts"])

	_pending[request_id] = {
		"status": "pending",
		"brief": brief,
		"locale": locale,
		"source": String(spec.get("source", "")),
		"include_mission": bool(spec.get("include_mission", false)),
		"post_news": bool(spec.get("post_news", true)),
		"publish_mission": bool(spec.get("publish_mission", true)),
		"publish_dict_mission": bool(spec.get("publish_dict_mission", false)),
		"mission_id": String(spec.get("mission_id", "")),
		"mission_mechanical": spec.get("mission_mechanical", {}) if spec.get("mission_mechanical") is Dictionary else {},
		"dict_mechanical": spec.get("dict_mechanical", {}) if spec.get("dict_mechanical") is Dictionary else {},
		"mechanical_news": spec.get("mechanical_news", {}) if spec.get("mechanical_news") is Dictionary else {},
		"mechanical_mission": spec.get("mechanical_mission", {}) if spec.get("mechanical_mission") is Dictionary else {},
		"post_publish_actions": spec.get("post_publish_actions", []) if spec.get("post_publish_actions") is Array else [],
	}
	_queue_llm_or_publish(request_id)
	return request_id


func request_settlement_incident_package(incident: Dictionary, role_mods: Dictionary = {}) -> void:
	if incident.is_empty():
		return
	var wm: Node = get_node_or_null("/root/WorldManager")
	var settlement_id: String = String(incident.get("settlement_id", ""))
	var discovered: bool = true
	if wm and wm.has_method("_is_settlement_discovered_for_news"):
		discovered = bool(wm.call("_is_settlement_discovered_for_news", settlement_id))
	var undiscovered_chance: float = float(role_mods.get("undiscovered_news_chance", 0.0))
	if not discovered and undiscovered_chance <= 0.0:
		return
	if not discovered and randf() > undiscovered_chance:
		return

	var include_mission: bool = randf() <= RELIEF_MISSION_CHANCE
	var mission_mechanical: Dictionary = {}
	if include_mission:
		mission_mechanical = _build_relief_mission_mechanical(incident)
		if mission_mechanical.is_empty():
			include_mission = false

	var request_id: String = "incident_%s" % String(incident.get("id", str(Time.get_unix_time_from_system())))
	var brief_extra: Dictionary = {
		"include_mission": include_mission,
		"discovered": discovered,
		"mission_id": String(mission_mechanical.get("id", "")),
		"mission_type": "diplomacy",
		"difficulty": "easy",
	}
	if include_mission:
		brief_extra["stakes"] = {
			"success_rewards": mission_mechanical.get("rewards", {}),
			"failure_penalties": mission_mechanical.get("penalties", {}),
			"requirements": {"cariye_level": mission_mechanical.get("required_cariye_level", 1)},
			"success_chance": mission_mechanical.get("success_chance", 0.72),
		}

	enqueue({
		"request_id": request_id,
		"source": "incident_relief" if include_mission else "settlement_incident",
		"brief": AiNarrativeBrief.build_from_incident(incident, brief_extra),
		"include_mission": include_mission,
		"mission_id": String(mission_mechanical.get("id", "")),
		"mission_mechanical": mission_mechanical,
		"mechanical_news": AiNarrativeBrief.mechanical_news_for_incident(incident, discovered),
		"mechanical_mission": AiNarrativeBrief.mechanical_mission_for_relief(incident) if include_mission else {},
	})


func apply_ai_narrative(
	request_id: String,
	locale: String,
	mission_title: String = "",
	mission_body: String = "",
	news_title: String = "",
	news_body: String = ""
) -> bool:
	if not _pending.has(request_id):
		push_warning("NarrativeSpawnPipeline: unknown request_id %s" % request_id)
		return false
	var entry: Dictionary = _pending[request_id]
	if String(entry.get("status", "")) != "pending":
		return false
	_wait_elapsed.erase(request_id)
	entry["status"] = "ready"
	entry["narrative"] = {
		"locale": locale,
		"news_title": news_title,
		"news_body": news_body,
		"mission_title": mission_title,
		"mission_body": mission_body,
	}
	_pending[request_id] = entry
	_publish_narrative(request_id)
	return true


func get_pending_brief(request_id: String) -> Dictionary:
	if not _pending.has(request_id):
		return {}
	var b: Variant = _pending[request_id].get("brief", {})
	return b if b is Dictionary else {}


func debug_print_brief(request_id: String) -> void:
	var brief: Dictionary = get_pending_brief(request_id)
	if brief.is_empty():
		print("NarrativeSpawnPipeline: no brief for ", request_id)
		return
	print("BRIEF JSON: ", AiNarrativeBrief.to_json(brief))
	print("BRIEF PROMPT: ", AiNarrativeBrief.to_prompt_string(brief))


func _queue_llm_or_publish(request_id: String) -> void:
	var entry: Dictionary = _pending[request_id]
	var brief: Dictionary = entry.get("brief", {}) if entry.get("brief") is Dictionary else {}
	var locale: String = String(entry.get("locale", "en"))
	narrative_brief_ready.emit(request_id, brief, locale)
	if _should_wait_for_llm():
		_wait_elapsed[request_id] = 0.0
	else:
		_publish_mechanical(request_id)


func _should_wait_for_llm() -> bool:
	var llama: Node = get_node_or_null("/root/LlamaService")
	if llama == null:
		return false
	if llama.has_method("IsInitialized"):
		return bool(llama.call("IsInitialized"))
	return false


func _publish_mechanical(request_id: String) -> void:
	if not _pending.has(request_id):
		return
	var entry: Dictionary = _pending[request_id]
	if String(entry.get("status", "")) != "pending":
		return
	entry["status"] = "mechanical"
	_pending[request_id] = entry
	var mech_news: Dictionary = entry.get("mechanical_news", {}) if entry.get("mechanical_news") is Dictionary else {}
	_publish_common(
		request_id,
		"mechanical",
		str(mech_news.get("title", "")),
		str(mech_news.get("body", "")),
		entry,
		true
	)


func _publish_narrative(request_id: String) -> void:
	if not _pending.has(request_id):
		return
	var entry: Dictionary = _pending[request_id]
	var narr: Dictionary = entry.get("narrative", {}) if entry.get("narrative") is Dictionary else {}
	var news_title: String = str(narr.get("news_title", ""))
	var news_body: String = str(narr.get("news_body", ""))
	if news_title.is_empty() or news_body.is_empty():
		var mech: Dictionary = entry.get("mechanical_news", {}) if entry.get("mechanical_news") is Dictionary else {}
		if news_title.is_empty():
			news_title = str(mech.get("title", ""))
		if news_body.is_empty():
			news_body = str(mech.get("body", ""))
	_publish_common(request_id, "narrative", news_title, news_body, entry, false)


func _publish_common(
	request_id: String,
	mode: String,
	news_title: String,
	news_body: String,
	entry: Dictionary,
	use_mechanical_mission_text: bool
) -> void:
	var mm: Node = get_node_or_null("/root/MissionManager")
	if bool(entry.get("post_news", true)) and mm and mm.has_method("post_news") and not news_title.is_empty():
		var mech_news: Dictionary = entry.get("mechanical_news", {}) if entry.get("mechanical_news") is Dictionary else {}
		var category: String = str(mech_news.get("category", "Dünya"))
		var subcat: String = str(mech_news.get("subcategory", "info"))
		var color: Color = mech_news.get("color", Color.WHITE) if mech_news.get("color") is Color else Color.WHITE
		mm.call("post_news", category, news_title, news_body, color, subcat)

	if bool(entry.get("include_mission", false)) and mm and bool(entry.get("publish_mission", true)):
		var mech: Dictionary = entry.get("mission_mechanical", {}) if entry.get("mission_mechanical") is Dictionary else {}
		if not mech.is_empty():
			var m_title: String = ""
			var m_body: String = ""
			if use_mechanical_mission_text:
				var mm_text: Dictionary = entry.get("mechanical_mission", {}) if entry.get("mechanical_mission") is Dictionary else {}
				m_title = str(mm_text.get("title", ""))
				m_body = str(mm_text.get("body", ""))
			else:
				var narr: Dictionary = entry.get("narrative", {}) if entry.get("narrative") is Dictionary else {}
				m_title = str(narr.get("mission_title", ""))
				m_body = str(narr.get("mission_body", ""))
				if m_title.is_empty() or m_body.is_empty():
					var fallback: Dictionary = entry.get("mechanical_mission", {}) if entry.get("mechanical_mission") is Dictionary else {}
					if m_title.is_empty():
						m_title = str(fallback.get("title", ""))
					if m_body.is_empty():
						m_body = str(fallback.get("body", ""))
			var brief: Dictionary = entry.get("brief", {}) if entry.get("brief") is Dictionary else {}
			if bool(entry.get("publish_dict_mission", false)) and mm.has_method("publish_narrative_dict_mission"):
				var dict_m: Dictionary = entry.get("dict_mechanical", {}) if entry.get("dict_mechanical") is Dictionary else {}
				mm.call("publish_narrative_dict_mission", dict_m, brief, m_title, m_body, mode)
			elif mm.has_method("publish_narrative_mission"):
				mm.call("publish_narrative_mission", mech, brief, m_title, m_body, mode)

	if mm and mm.has_method("run_post_publish_actions"):
		var actions: Array = entry.get("post_publish_actions", []) if entry.get("post_publish_actions") is Array else []
		mm.call("run_post_publish_actions", actions)

	_pending.erase(request_id)
	_wait_elapsed.erase(request_id)
	narrative_published.emit(request_id, mode)


func _build_relief_mission_mechanical(incident: Dictionary) -> Dictionary:
	var raw_id: String = String(incident.get("id", "x"))
	var safe_id: String = raw_id.replace(",", "_").replace("|", "_").replace(" ", "_")
	var mission_id: String = "relief_" + safe_id
	if mission_id.length() > 96:
		mission_id = mission_id.substr(0, 96)
	var mm: Node = get_node_or_null("/root/MissionManager")
	if mm and "missions" in mm and mm.missions.has(mission_id):
		return {}
	var sn: String = String(incident.get("settlement_name", "Neighbor"))
	var sid: String = String(incident.get("settlement_id", ""))
	var wm: Node = get_node_or_null("/root/WorldManager")
	var hex_key: String = ""
	if wm and wm.has_method("get_settlement_hex_key_for_mission"):
		hex_key = String(wm.call("get_settlement_hex_key_for_mission", sid))
	return {
		"id": mission_id,
		"settlement_name": sn,
		"settlement_id": sid,
		"target_settlement_id": sid,
		"target_location": sn,
		"incident_id": raw_id,
		"completes_incident_id": raw_id,
		"world_hex_key": hex_key,
		"mission_type": _Mission.MissionType.DİPLOMASİ,
		"difficulty": _Mission.Difficulty.KOLAY,
		"duration": 150.0,
		"success_chance": 0.72,
		"required_cariye_level": 1,
		"rewards": {"gold": 12},
		"penalties": {"gold": -4},
		"risk_level": "Dusuk",
	}
