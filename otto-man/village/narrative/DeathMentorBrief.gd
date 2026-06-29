extends RefCounted
## Ölüm sonrası mentor mesajları — kaynak ve debuff bağlamına göre kısa öğrenme metni.

const DEBUFF_TR_KEYS: Dictionary = {
	"Kirik Kaburga": "mentor.death.debuff.rib",
	"Bel Tutulmasi": "mentor.death.debuff.back",
	"Denge Kaybi": "mentor.death.debuff.balance",
}

const SOURCE_RETURN_KEYS: Dictionary = {
	"dungeon": "mentor.death.return.dungeon",
	"expedition": "mentor.death.return.expedition",
	"forest": "mentor.death.return.forest",
	"tutorial": "mentor.death.return.tutorial",
	"combat": "mentor.death.return.combat",
	"unknown": "mentor.death.return.generic",
}


static func resolve_death_source(payload: Dictionary) -> String:
	var src: String = String(payload.get("source", "")).strip_edges()
	match src:
		"dungeon_death":
			return "dungeon"
		"world_map_death":
			return "expedition"
		"forest_death":
			return "forest"
		"tutorial_combat_death":
			return "tutorial"
		_:
			if src.contains("death"):
				return "combat"
			return "unknown"


static func enqueue_return_messages(tm: Node, payload: Dictionary, context: Dictionary) -> void:
	if tm == null or not tm.has_method("enqueue_message"):
		return
	var run_id: int = int(context.get("run_id", 0))
	if run_id <= 0:
		return
	var source: String = resolve_death_source(payload)
	var heal_mins: int = maxi(1, int(context.get("minutes_until_full_heal", 180)))
	var heal_hours: float = float(heal_mins) / 60.0
	var return_key: String = String(SOURCE_RETURN_KEYS.get(source, SOURCE_RETURN_KEYS["unknown"]))
	var return_text: String = tm.tr(return_key) % heal_hours
	tm.enqueue_message("death_return_%d" % run_id, return_text, "mentor", 20)
	if bool(context.get("has_debuff", false)):
		var debuff_name: String = String(context.get("debuff_name", ""))
		var debuff_key: String = String(DEBUFF_TR_KEYS.get(debuff_name, "mentor.death.debuff.generic"))
		var debuff_text: String = tm.tr(debuff_key)
		if debuff_name.strip_edges().is_empty():
			debuff_text = tm.tr("mentor.death.debuff.generic")
		tm.enqueue_message("death_debuff_%d" % run_id, debuff_text, "mentor", 18)


static func enqueue_healed_message(tm: Node, run_id: int) -> void:
	if tm == null or not tm.has_method("enqueue_message") or run_id <= 0:
		return
	tm.enqueue_message(
		"death_healed_%d" % run_id,
		tm.tr("mentor.death.healed"),
		"mentor",
		12
	)
