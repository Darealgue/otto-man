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
	
	# Apply world event effects to village economy
	_apply_world_events_to_village(day)

func _simulate_day(day: int) -> void:
	# Dynamic world events simulation
	# 15% chance of any event on a random non-player faction
	if randi() % 100 < 15 and factions.size() > 1:
		var idx := 1 + int(randi() % (factions.size() - 1))
		var faction := factions[idx]
		var event_type := _get_random_event_type()
		var ev := _create_event(event_type, faction, day)
		active_events.append(ev)
		world_event_started.emit(ev)
		_post_event_news(ev, day)

	# Decay expired events
	var remaining: Array[Dictionary] = []
	for e in active_events:
		var started: int = int(e.get("started_day", day))
		var duration: int = int(e.get("duration", 0))
		if day - started < duration:
			remaining.append(e)
	active_events = remaining

func set_relation(a: String, b: String, value: int, post_news: bool = false) -> void:
	var key := _rel_key(a, b)
	var old_val: int = int(relations.get(key, 0))
	var new_val: int = clamp(value, -100, 100)
	relations[key] = new_val
	relation_changed.emit(a, b, new_val)
	
	# Optionally post news if the relation significantly changed
	if post_news and abs(new_val - old_val) >= 5:
		var change: int = new_val - old_val
		var subcategory: String = "info"
		if change > 0:
			subcategory = "success"
		elif change < 0:
			subcategory = "warning"
		_post_world_news({
			"category": "world",
			"subcategory": subcategory,
			"title": "İlişki Değişti",
			"content": "%s ile %s arasındaki ilişki %s%d oldu." % [a, b, "+" if change > 0 else "", change],
			"day": 0  # Will be filled by news system if needed
		})

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

func _get_random_event_type() -> String:
	var event_types := ["trade_boom", "famine", "plague", "war_declaration", "rebellion"]
	return event_types[randi() % event_types.size()]

func _create_event(type: String, faction: String, day: int) -> Dictionary:
	match type:
		"trade_boom":
			return {
				"type": "trade_boom",
				"faction": faction,
				"magnitude": 1.2,
				"duration": 5,
				"started_day": day,
				"effects": {"gold_multiplier": 1.2, "trade_bonus": 10}
			}
		"famine":
			return {
				"type": "famine",
				"faction": faction,
				"magnitude": 0.8,
				"duration": 7,
				"started_day": day,
				"effects": {"food_production": 0.5, "morale_penalty": -15}
			}
		"plague":
			return {
				"type": "plague",
				"faction": faction,
				"magnitude": 0.7,
				"duration": 10,
				"started_day": day,
				"effects": {"population_health": 0.6, "production_penalty": 0.3}
			}
		"war_declaration":
			return {
				"type": "war_declaration",
				"faction": faction,
				"magnitude": 1.0,
				"duration": 30,
				"started_day": day,
				"effects": {"military_focus": 1.5, "trade_disruption": 0.8}
			}
		"rebellion":
			return {
				"type": "rebellion",
				"faction": faction,
				"magnitude": 0.6,
				"duration": 14,
				"started_day": day,
				"effects": {"stability_penalty": -20, "production_chaos": 0.4}
			}
		_:
			return {"type": "unknown", "faction": faction, "magnitude": 1.0, "duration": 1, "started_day": day}

func _post_event_news(event: Dictionary, day: int) -> void:
	var type := String(event.get("type", "unknown"))
	var faction := String(event.get("faction", "Bilinmeyen"))
	var duration := int(event.get("duration", 0))
	var subcategory := "info"
	
	match type:
		"trade_boom":
			subcategory = "success"
		"famine", "plague", "rebellion":
			subcategory = "critical"
		"war_declaration":
			subcategory = "warning"
	
	var title := ""
	var content := ""
	
	match type:
		"trade_boom":
			title = "Ticaret Patlaması"
			content = "%s bölgesinde ticaret canlandı! (%d gün)" % [faction, duration]
		"famine":
			title = "Kıtlık"
			content = "%s bölgesinde kıtlık başladı! Gıda üretimi düştü. (%d gün)" % [faction, duration]
		"plague":
			title = "Salgın"
			content = "%s bölgesinde salgın hastalık yayıldı! Nüfus sağlığı tehlikede. (%d gün)" % [faction, duration]
		"war_declaration":
			title = "Savaş İlanı"
			content = "%s bölgesinde savaş patlak verdi! Ticaret kesintiye uğradı. (%d gün)" % [faction, duration]
		"rebellion":
			title = "İsyan"
			content = "%s bölgesinde isyan çıktı! İstikrar sarsıldı. (%d gün)" % [faction, duration]
	
	# Post news with proper subcategory for visual emphasis
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("post_news"):
		mm.post_news("Dünya", title, content, Color.WHITE, subcategory)
	else:
		# Fallback to old system
		_post_world_news({
			"category": "world",
			"subcategory": subcategory,
			"title": title,
			"content": content,
			"day": day
		})

func _apply_world_events_to_village(day: int) -> void:
	"""Apply active world events to village economy"""
	var vm = get_node_or_null("/root/VillageManager")
	if not vm or not vm.has_method("apply_world_event_effects"):
		return
	
	# Apply effects of all active events
	for event in active_events:
		vm.apply_world_event_effects(event)
	
	# Remove effects of expired events
	var remaining: Array[Dictionary] = []
	for event in active_events:
		var started_day := int(event.get("started_day", day))
		var duration := int(event.get("duration", 0))
		if day - started_day < duration:
			remaining.append(event)
		else:
			# Event expired, remove its effects
			vm.remove_world_event_effects(event)
	active_events = remaining

func _post_world_news(news: Dictionary) -> void:
	# Prefer MissionManager news pipeline if present
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_signal("news_posted"):
		mm.news_posted.emit(news)
	else:
		pass
		#print("[WORLD NEWS] ", news)
