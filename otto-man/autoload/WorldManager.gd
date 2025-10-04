extends Node

# --- Feature Flags ---
@export var dynamic_world_enabled: bool = true

# --- Signals ---
signal world_event_started(event: Dictionary)
signal relation_changed(faction_a: String, faction_b: String, new_score: int)
signal war_state_changed(faction_a: String, faction_b: String, at_war: bool)

# --- World State ---
var factions: Array[String] = ["Köy", "Kuzey", "Güney", "Doğu", "Batı"]
var settlements: Array[Dictionary] = [] # { name:String, faction:String, pop:int }
var relations: Dictionary = {}          # key "A|B" -> int (-100..100)
var active_wars: Array[Dictionary] = [] # { a:String, b:String, since_day:int }
var active_events: Array[Dictionary] = [] # { type:String, faction:String, magnitude:float, duration:int, started_day:int }

# --- Internal ---
var _last_tick_day: int = 0

func _ready() -> void:
	# Connect to day changes
	var tm = get_node_or_null("/root/TimeManager")
	if tm and tm.has_signal("day_changed"):
		tm.connect("day_changed", Callable(self, "_on_new_day"))
		_last_tick_day = tm.get_day() if tm.has_method("get_day") else 0
	# Initialize basic relations as neutral
	for i in range(factions.size()):
		for j in range(i + 1, factions.size()):
			var key := _rel_key(factions[i], factions[j])
			relations[key] = 0

func _rel_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

func _on_new_day(day: int) -> void:
	if not dynamic_world_enabled:
		return
	if day <= _last_tick_day:
		return
	_last_tick_day = day
	_simulate_day(day)

func _simulate_day(day: int) -> void:
	# Very light placeholder simulation to avoid breaking gameplay
	# 10% chance of a trade boom event on a random non-player faction
	if randi() % 10 == 0 and factions.size() > 1:
		var idx := 1 + int(randi() % (factions.size() - 1))
		var faction := factions[idx]
		var ev := {
			"type": "trade_boom",
			"faction": faction,
			"magnitude": 1.1,
			"duration": 3,
			"started_day": day
		}
		active_events.append(ev)
		world_event_started.emit(ev)
		_post_world_news({
			"category": "world",
			"subcategory": "info",
			"title": "Ticaret Canlandı",
			"content": "%s bölgesinde ticaret hareketlendi." % faction,
			"day": day
		})

	# Decay expired events
	var remaining: Array[Dictionary] = []
	for e in active_events:
		var started: int = int(e.get("started_day", day))
		var duration: int = int(e.get("duration", 0))
		if day - started < duration:
			remaining.append(e)
	active_events = remaining

func set_relation(a: String, b: String, value: int) -> void:
	var key := _rel_key(a, b)
	relations[key] = clamp(value, -100, 100)
	relation_changed.emit(a, b, int(relations[key]))

func get_relation(a: String, b: String) -> int:
	var key := _rel_key(a, b)
	return int(relations.get(key, 0))

func start_war(a: String, b: String, day: int) -> bool:
	for w in active_wars:
		if (w.get("a", "") == a and w.get("b", "") == b) or (w.get("a", "") == b and w.get("b", "") == a):
			return false
	active_wars.append({ "a": a, "b": b, "since_day": day })
	war_state_changed.emit(a, b, true)
	_post_world_news({
		"category": "world",
		"subcategory": "critical",
		"title": "Savaş İlanı",
		"content": "%s ile %s arasında savaş patlak verdi!" % [a, b],
		"day": day
	})
	return true

func end_war(a: String, b: String, day: int) -> void:
	var next: Array[Dictionary] = []
	for w in active_wars:
		var wa := String(w.get("a", ""))
		var wb := String(w.get("b", ""))
		if (wa == a and wb == b) or (wa == b and wb == a):
			continue
		next.append(w)
	active_wars = next
	war_state_changed.emit(a, b, false)
	_post_world_news({
		"category": "world",
		"subcategory": "success",
		"title": "Barış",
		"content": "%s ile %s barış yaptı." % [a, b],
		"day": day
	})

func get_state() -> Dictionary:
	return {
		"relations": relations.duplicate(true),
		"active_wars": active_wars.duplicate(true),
		"active_events": active_events.duplicate(true)
	}

func set_state(state: Dictionary) -> void:
	if state.has("relations"):
		relations = state["relations"].duplicate(true)
	if state.has("active_wars"):
		active_wars = state["active_wars"].duplicate(true)
	if state.has("active_events"):
		active_events = state["active_events"].duplicate(true)

func _post_world_news(news: Dictionary) -> void:
	# Prefer MissionManager news pipeline if present
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_signal("news_posted"):
		mm.news_posted.emit(news)
	else:
		pass
		#print("[WORLD NEWS] ", news)
