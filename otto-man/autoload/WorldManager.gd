extends Node

# --- Feature Flags ---
@export var dynamic_world_enabled: bool = true

# --- Signals ---
signal world_event_started(event: Dictionary)
signal relation_changed(faction_a: String, faction_b: String, new_score: int)
signal war_state_changed(faction_a: String, faction_b: String, at_war: bool)
signal defense_deployment_started(attack_day: int)  # Askerlerin savaşa gitmesi için sinyal
signal defense_battle_completed(victor: String, losses: int)  # Savaş bitince askerlerin geri dönmesi için sinyal
signal battle_story_generated(story: String, battle_data: Dictionary)  # Generated battle story
signal world_map_updated
signal world_map_tile_discovered(tile_key: String, tile_data: Dictionary)
signal world_map_travel_event(event_data: Dictionary)

# --- World State ---
var factions: Array[String] = ["Köy", "Kuzey", "Güney", "Doğu", "Batı"]
var settlements: Array[Dictionary] = [] # { name:String, faction:String, pop:int }
var relations: Dictionary = {}          # key "A|B" -> int (-100..100)
var active_wars: Array[Dictionary] = [] # { a:String, b:String, since_day:int }
var active_events: Array[Dictionary] = [] # { type:String, faction:String, magnitude:float, duration:int, started_day:int }

# Zamanlanmış saldırılar (köye gelecek saldırılar için uyarı + zamanlama)
var pending_attacks: Array[Dictionary] = [] # { attacker:String, warning_day:int, warning_hour:float, attack_day:int, attack_hour:float, deployed:bool }

# --- Hex World Map State (Vertical Slice) ---
const WORLD_MAP_VERSION: int = 3
const DEFAULT_MAP_RADIUS: int = 40
const STARTING_REVEAL_RADIUS: int = 3
const PLAYER_STEP_REVEAL_RADIUS: int = 1
const MIN_DUNGEON_DISTANCE_FROM_VILLAGE: int = 14
const TARGET_DUNGEON_COUNT: int = 6
const TARGET_BRIDGE_COUNT: int = 10
const BASE_TRAVEL_MINUTES_PER_COST: float = 18.0
const MAX_ACTIVE_SETTLEMENT_INCIDENTS: int = 3
const MAX_INCIDENTS_PER_SETTLEMENT: int = 1
# Concubine role/skill IDs (Concubine.gd enums)
const LW_ROLE_KOMUTAN: int = 1
const LW_ROLE_AJAN: int = 2
const LW_ROLE_DIPLOMAT: int = 3
const LW_ROLE_TUCCAR: int = 4
const LW_ROLE_ALIM: int = 5
const LW_ROLE_TIBBIYECI: int = 6
const LW_SKILL_SAVAS: int = 0
const LW_SKILL_DIPLOMASI: int = 1
const LW_SKILL_TICARET: int = 2
const LW_SKILL_BUROKRASI: int = 3
const LW_SKILL_KESIF: int = 4

var world_map_radius: int = DEFAULT_MAP_RADIUS
var world_map_seed: int = 0
var world_map_tiles: Dictionary = {} # key "q,r" -> tile dictionary
var world_map_player_pos: Dictionary = {"q": 0, "r": 0}
# Seyahat oturumu (harita animasyonu hex hex ilerletir; olayda durur)
var _travel_session_path: Array = []
var _travel_session_route_mode: String = "shortest"
var _travel_session_next_index: int = 1
var _travel_session_minutes_accum: int = 0
var _travel_session_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var world_map_settlement_positions: Dictionary = {} # settlement_id -> {id,name,q,r,discovered}
var world_settlement_states: Dictionary = {} # settlement_id -> lightweight sim state
var world_settlement_incidents: Array[Dictionary] = []
# Inter-settlement relations: "id_a|id_b" -> int -100..100
var world_settlement_relations: Dictionary = {}
# Active multi-stage event chains (RimWorld-esinli mikro zincir)
var world_event_chains: Array[Dictionary] = []
# Active inter-settlement migrations (gercek nufus akisi)
var world_settlement_migrations: Array[Dictionary] = []
# Inter-settlement diplomacy state machine: "id_a|id_b" -> { state, since_day, last_changed_day, war_intensity }
var world_settlement_diplomacy: Dictionary = {}
# Player <-> settlement alliances: settlement_id -> { established_day, last_aid_call_day, aid_call_active, aid_call_started_day }
var world_player_alliances: Dictionary = {}

# --- Internal ---
var _last_tick_day: int = 0
var _time_advanced_connected: bool = false
var _pending_battle_story_data: Dictionary = {}  # Store battle data while waiting for LLM response

var _continent_noise_a: float = 0.0
var _continent_noise_b: float = 0.0
var _continent_noise_c: float = 0.0

func _ready() -> void:
	# Connect to day changes
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		if tm.has_signal("day_changed"):
			tm.connect("day_changed", Callable(self, "_on_new_day"))
		if tm.has_signal("time_advanced") and not _time_advanced_connected:
			tm.connect("time_advanced", Callable(self, "_on_time_advanced"))
			_time_advanced_connected = true
		_last_tick_day = tm.get_day() if tm.has_method("get_day") else 0
	# Initialize basic relations as neutral
	for i in range(factions.size()):
		for j in range(i + 1, factions.size()):
			var key := _rel_key(factions[i], factions[j])
			relations[key] = 0
	# Connect to LlamaService for battle story generation
	if not LlamaService.is_connected("GenerationComplete", Callable(self, "_on_battle_story_generated")):
		var error_code = LlamaService.connect("GenerationComplete", Callable(self, "_on_battle_story_generated"))
		if error_code != OK:
			printerr("WorldManager: Failed to connect to LlamaService for battle stories: Error ", error_code)
	if world_map_tiles.is_empty():
		# Lazy init fallback for old saves or first boot.
		start_new_world_map()

func reset_world_map_state() -> void:
	world_map_radius = DEFAULT_MAP_RADIUS
	world_map_seed = 0
	world_map_tiles.clear()
	world_map_player_pos = {"q": 0, "r": 0}
	world_map_settlement_positions.clear()
	world_settlement_states.clear()
	world_settlement_incidents.clear()
	world_settlement_relations.clear()
	world_event_chains.clear()
	world_settlement_migrations.clear()
	world_settlement_diplomacy.clear()
	world_player_alliances.clear()
	pending_attacks.clear()
	_clear_travel_session_state()
	world_map_updated.emit()

func start_new_world_map(seed: int = 0, map_radius: int = DEFAULT_MAP_RADIUS) -> void:
	reset_world_map_state()
	world_map_radius = max(3, map_radius)
	world_map_seed = seed if seed != 0 else int(Time.get_unix_time_from_system())
	_generate_hex_tiles()
	_place_settlements_on_map()
	_initialize_world_settlement_states()
	_reveal_tiles(world_map_player_pos, STARTING_REVEAL_RADIUS, true)
	_refresh_visible_tiles()
	var mm_new: Node = get_node_or_null("/root/MissionManager")
	if mm_new and mm_new.has_method("sync_settlement_relations_from_world_map"):
		mm_new.sync_settlement_relations_from_world_map()
	world_map_updated.emit()

func discover_tiles(center: Dictionary, radius: int, source: String = "player", emit_update: bool = true) -> Array:
	if world_map_tiles.is_empty():
		return []
	var discovered_keys: Array = _reveal_tiles(center, max(0, radius), true)
	if source == "player":
		world_map_player_pos = {"q": int(center.get("q", 0)), "r": int(center.get("r", 0))}
		_refresh_visible_tiles()
		if emit_update:
			world_map_updated.emit()
	elif not discovered_keys.is_empty():
		# Non-player scouts/mission teams also contribute to persistent discovery.
		if emit_update:
			world_map_updated.emit()
	return discovered_keys

func move_player_on_world_map(target_q: int, target_r: int, reveal_radius: int = PLAYER_STEP_REVEAL_RADIUS, emit_update: bool = true) -> bool:
	var key := _hex_key(target_q, target_r)
	if not world_map_tiles.has(key):
		return false
	world_map_player_pos = {"q": target_q, "r": target_r}
	discover_tiles(world_map_player_pos, reveal_radius, "player", emit_update)
	return true

func is_player_on_own_village_hex() -> bool:
	var pq: int = int(world_map_player_pos.get("q", 0))
	var pr: int = int(world_map_player_pos.get("r", 0))
	var tile: Dictionary = world_map_tiles.get(_hex_key(pq, pr), {})
	return bool(tile.get("contains_village", false)) and String(tile.get("poi_type", "")) == "player_village"

## Oyuncu dunyada koye geri donduruldugunde (ozellikle zindan olum donusu),
## haritadaki piyonun da player_village hex'ine senkron kalmasini saglar.
func sync_player_world_map_pos_to_own_village(emit_update: bool = true) -> bool:
	var target_pos: Dictionary = _get_player_village_position()
	if target_pos.is_empty():
		return false
	var tq: int = int(target_pos.get("q", 0))
	var tr: int = int(target_pos.get("r", 0))
	return move_player_on_world_map(tq, tr, STARTING_REVEAL_RADIUS, emit_update)

func find_world_map_path(start_q: int, start_r: int, target_q: int, target_r: int, route_mode: String = "shortest") -> Dictionary:
	var start_key: String = _hex_key(start_q, start_r)
	var target_key: String = _hex_key(target_q, target_r)
	if not world_map_tiles.has(start_key) or not world_map_tiles.has(target_key):
		return {"ok": false, "reason": "invalid_tile", "path": [], "total_cost": 0.0, "minutes": 0}
	if start_key == target_key:
		return {"ok": true, "path": [{"q": start_q, "r": start_r}], "total_cost": 0.0, "minutes": 0}
	var start_tile: Dictionary = world_map_tiles[start_key]
	var target_tile: Dictionary = world_map_tiles[target_key]
	# Deniz (ve diger geçilmez) hedef: A* hedefe basamadigi icin tum kara komponentini dolasir = ciddi lag.
	if not _is_passable_world_tile(start_tile):
		return {"ok": false, "reason": "impassable_start", "path": [], "total_cost": 0.0, "minutes": 0}
	if not _is_passable_world_tile(target_tile):
		return {"ok": false, "reason": "impassable_target", "path": [], "total_cost": 0.0, "minutes": 0}
	var open_nodes: Array[String] = [start_key]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_key: 0.0}
	var f_score: Dictionary = {start_key: float(_hex_distance(start_q, start_r, target_q, target_r))}
	while not open_nodes.is_empty():
		var current_key: String = _pick_lowest_f_score(open_nodes, f_score)
		if current_key == target_key:
			var path: Array[Dictionary] = _reconstruct_world_path(came_from, current_key)
			var total_cost: float = float(g_score.get(current_key, 0.0))
			var minutes: int = int(ceili(total_cost * BASE_TRAVEL_MINUTES_PER_COST))
			return {"ok": true, "path": path, "total_cost": total_cost, "minutes": max(0, minutes)}
		open_nodes.erase(current_key)
		var current_coords: Dictionary = _coords_from_key(current_key)
		for neighbor in _get_hex_neighbors(int(current_coords.get("q", 0)), int(current_coords.get("r", 0))):
			var nq: int = int(neighbor.get("q", 0))
			var nr: int = int(neighbor.get("r", 0))
			var neighbor_key: String = _hex_key(nq, nr)
			if not world_map_tiles.has(neighbor_key):
				continue
			var n_tile: Dictionary = world_map_tiles[neighbor_key]
			if not _is_passable_world_tile(n_tile):
				continue
			var step_cost: float = _get_world_tile_travel_cost(n_tile, route_mode)
			var tentative_g: float = float(g_score.get(current_key, 0.0)) + step_cost
			if tentative_g < float(g_score.get(neighbor_key, INF)):
				came_from[neighbor_key] = current_key
				g_score[neighbor_key] = tentative_g
				var heuristic: float = float(_hex_distance(nq, nr, target_q, target_r))
				f_score[neighbor_key] = tentative_g + heuristic
				if not open_nodes.has(neighbor_key):
					open_nodes.append(neighbor_key)
	return {"ok": false, "reason": "no_path", "path": [], "total_cost": 0.0, "minutes": 0}

func travel_player_to_world_hex(target_q: int, target_r: int, route_mode: String = "shortest") -> Dictionary:
	var start_q: int = int(world_map_player_pos.get("q", 0))
	var start_r: int = int(world_map_player_pos.get("r", 0))
	var result: Dictionary = find_world_map_path(start_q, start_r, target_q, target_r, route_mode)
	if not bool(result.get("ok", false)):
		return result
	var path: Array = result.get("path", [])
	if path.size() <= 1:
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_unix_time_from_system()) + (start_q * 92821) + (start_r * 68917)
	var total_minutes_advanced: int = 0
	for i in range(1, path.size()):
		var node: Dictionary = path[i]
		var nq: int = int(node.get("q", 0))
		var nr: int = int(node.get("r", 0))
		move_player_on_world_map(nq, nr, PLAYER_STEP_REVEAL_RADIUS, false)
		var tile_key: String = _hex_key(nq, nr)
		var tile: Dictionary = world_map_tiles.get(tile_key, {})
		var step_minutes: int = int(ceili(_get_world_tile_travel_cost(tile, route_mode) * BASE_TRAVEL_MINUTES_PER_COST))
		total_minutes_advanced += max(1, step_minutes)
		var ps_tr: Node = get_node_or_null("/root/PlayerStats")
		if ps_tr and ps_tr.has_method("apply_world_travel_ration_cost"):
			ps_tr.call("apply_world_travel_ration_cost", max(1, step_minutes))
		_try_hydrate_player_on_akarsu_tile(tile)
		if _should_trigger_world_travel_event(tile, rng):
			if total_minutes_advanced > 0:
				var tm_event: Node = get_node_or_null("/root/TimeManager")
				if tm_event and tm_event.has_method("advance_minutes"):
					tm_event.call("advance_minutes", total_minutes_advanced)
			var event_data: Dictionary = _build_world_travel_event_payload(tile, nq, nr, rng)
			world_map_travel_event.emit(event_data)
			world_map_updated.emit()
			return {
				"ok": true,
				"event_triggered": true,
				"event_data": event_data,
				"path": path,
				"total_cost": result.get("total_cost", 0.0),
				"minutes": total_minutes_advanced
			}
	var minutes: int = total_minutes_advanced
	if minutes > 0:
		var tm: Node = get_node_or_null("/root/TimeManager")
		if tm and tm.has_method("advance_minutes"):
			tm.call("advance_minutes", minutes)
	world_map_updated.emit()
	return result

func _clear_travel_session_state() -> void:
	_travel_session_path.clear()
	_travel_session_route_mode = "shortest"
	_travel_session_next_index = 1
	_travel_session_minutes_accum = 0

func begin_world_travel_session(target_q: int, target_r: int, route_mode: String = "shortest") -> Dictionary:
	_clear_travel_session_state()
	var start_q: int = int(world_map_player_pos.get("q", 0))
	var start_r: int = int(world_map_player_pos.get("r", 0))
	var result: Dictionary = find_world_map_path(start_q, start_r, target_q, target_r, route_mode)
	if not bool(result.get("ok", false)):
		return result
	var path: Array = result.get("path", [])
	if path.size() <= 1:
		return result
	_travel_session_path = path.duplicate()
	_travel_session_route_mode = route_mode
	_travel_session_next_index = 1
	_travel_session_minutes_accum = 0
	_travel_session_rng.seed = int(Time.get_unix_time_from_system()) + (start_q * 92821) + (start_r * 68917)
	return {
		"ok": true,
		"path": path,
		"total_cost": result.get("total_cost", 0.0),
		"minutes": result.get("minutes", 0)
	}

func advance_world_travel_step() -> Dictionary:
	if _travel_session_path.is_empty():
		return {"ok": false, "reason": "no_session", "done": true, "event_triggered": false}
	if _travel_session_next_index >= _travel_session_path.size():
		_finalize_travel_session_at_destination()
		return {"ok": true, "done": true, "event_triggered": false}
	var node: Dictionary = _travel_session_path[_travel_session_next_index]
	var nq: int = int(node.get("q", 0))
	var nr: int = int(node.get("r", 0))
	move_player_on_world_map(nq, nr, PLAYER_STEP_REVEAL_RADIUS, false)
	var tile_key: String = _hex_key(nq, nr)
	var tile: Dictionary = world_map_tiles.get(tile_key, {})
	var step_minutes: int = int(ceili(_get_world_tile_travel_cost(tile, _travel_session_route_mode) * BASE_TRAVEL_MINUTES_PER_COST))
	_travel_session_minutes_accum += max(1, step_minutes)
	var ps_step: Node = get_node_or_null("/root/PlayerStats")
	if ps_step and ps_step.has_method("apply_world_travel_ration_cost"):
		ps_step.call("apply_world_travel_ration_cost", max(1, step_minutes))
	_try_hydrate_player_on_akarsu_tile(tile)
	_travel_session_next_index += 1
	if _should_trigger_world_travel_event(tile, _travel_session_rng):
		if _travel_session_minutes_accum > 0:
			var tm_ev: Node = get_node_or_null("/root/TimeManager")
			if tm_ev and tm_ev.has_method("advance_minutes"):
				tm_ev.call("advance_minutes", _travel_session_minutes_accum)
		var event_data: Dictionary = _build_world_travel_event_payload(tile, nq, nr, _travel_session_rng)
		_clear_travel_session_state()
		world_map_travel_event.emit(event_data)
		world_map_updated.emit()
		return {"ok": true, "event_triggered": true, "event_data": event_data, "done": false}
	if _travel_session_next_index >= _travel_session_path.size():
		_finalize_travel_session_at_destination()
		return {"ok": true, "done": true, "event_triggered": false}
	world_map_updated.emit()
	return {"ok": true, "done": false, "event_triggered": false, "stepped": true}

func _finalize_travel_session_at_destination() -> void:
	var minutes: int = _travel_session_minutes_accum
	_clear_travel_session_state()
	if minutes > 0:
		var tm: Node = get_node_or_null("/root/TimeManager")
		if tm and tm.has_method("advance_minutes"):
			tm.call("advance_minutes", minutes)
	world_map_updated.emit()

func _try_hydrate_player_on_akarsu_tile(tile: Dictionary) -> void:
	if String(tile.get("terrain_type", "")) != "akarsu":
		return
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps and ps.has_method("apply_akarsu_river_hydration"):
		ps.call("apply_akarsu_river_hydration")

func get_world_map_state() -> Dictionary:
	return {
		"version": WORLD_MAP_VERSION,
		"radius": world_map_radius,
		"seed": world_map_seed,
		"player_pos": world_map_player_pos.duplicate(true),
		"tiles": world_map_tiles.duplicate(true),
		"settlement_positions": world_map_settlement_positions.duplicate(true),
		"settlement_states": world_settlement_states.duplicate(true),
		"settlement_incidents": world_settlement_incidents.duplicate(true),
		"settlement_relations": world_settlement_relations.duplicate(true),
		"event_chains": world_event_chains.duplicate(true),
		"settlement_migrations": world_settlement_migrations.duplicate(true),
		"settlement_diplomacy": world_settlement_diplomacy.duplicate(true),
		"player_alliances": world_player_alliances.duplicate(true),
		"pending_attacks": _serialize_pending_attacks()
	}

func set_world_map_state(state: Dictionary) -> void:
	if state.is_empty():
		start_new_world_map()
		return
	world_map_radius = int(state.get("radius", DEFAULT_MAP_RADIUS))
	world_map_seed = int(state.get("seed", 0))
	var pos = state.get("player_pos", {"q": 0, "r": 0})
	world_map_player_pos = {
		"q": int(pos.get("q", 0)),
		"r": int(pos.get("r", 0))
	}
	world_map_tiles = state.get("tiles", {}).duplicate(true)
	world_map_settlement_positions = state.get("settlement_positions", {}).duplicate(true)
	world_settlement_states = state.get("settlement_states", {}).duplicate(true)
	var raw_incidents: Array = state.get("settlement_incidents", [])
	world_settlement_incidents.clear()
	for incident in raw_incidents:
		if incident is Dictionary:
			world_settlement_incidents.append(incident.duplicate(true))
	world_settlement_relations = state.get("settlement_relations", {}).duplicate(true)
	world_event_chains.clear()
	var raw_chains: Array = state.get("event_chains", [])
	for chain in raw_chains:
		if chain is Dictionary:
			world_event_chains.append(chain.duplicate(true))
	world_settlement_migrations.clear()
	var raw_migrations: Array = state.get("settlement_migrations", [])
	for migration in raw_migrations:
		if migration is Dictionary:
			world_settlement_migrations.append(migration.duplicate(true))
	world_settlement_diplomacy = state.get("settlement_diplomacy", {}).duplicate(true)
	world_player_alliances = state.get("player_alliances", {}).duplicate(true)
	_deserialize_pending_attacks(state.get("pending_attacks", []))
	if world_map_tiles.is_empty():
		start_new_world_map()
		return
	_upgrade_world_map_state_if_needed(state)
	_initialize_world_settlement_states()
	_refresh_visible_tiles()
	var mm_map: Node = get_node_or_null("/root/MissionManager")
	if mm_map and mm_map.has_method("sync_settlement_relations_from_world_map"):
		mm_map.sync_settlement_relations_from_world_map()
	world_map_updated.emit()

func _serialize_pending_attacks() -> Array:
	var out: Array = []
	for a in pending_attacks:
		if a is Dictionary:
			out.append(a.duplicate(true))
	return out

func _deserialize_pending_attacks(raw: Variant) -> void:
	pending_attacks.clear()
	if not (raw is Array):
		return
	for a in raw:
		if a is Dictionary:
			pending_attacks.append(a.duplicate(true))

func get_discovered_tiles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in world_map_tiles.keys():
		var tile = world_map_tiles[key]
		if bool(tile.get("discovered", false)):
			out.append(tile.duplicate(true))
	return out

func get_discovered_settlements() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for settlement_id in world_map_settlement_positions.keys():
		var info: Dictionary = world_map_settlement_positions[settlement_id]
		if bool(info.get("discovered", false)):
			out.append(info.duplicate(true))
	return out

func is_settlement_discovered(settlement_id: String) -> bool:
	if not world_map_settlement_positions.has(settlement_id):
		return false
	return bool(world_map_settlement_positions[settlement_id].get("discovered", false))

func _generate_hex_tiles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_map_seed)
	_continent_noise_a = rng.randf_range(0.6, 1.7)
	_continent_noise_b = rng.randf_range(1.1, 2.4)
	_continent_noise_c = rng.randf_range(2.0, 3.8)
	for q in range(-world_map_radius, world_map_radius + 1):
		var r1 = max(-world_map_radius, -q - world_map_radius)
		var r2 = min(world_map_radius, -q + world_map_radius)
		for r in range(r1, r2 + 1):
			var terrain := _pick_terrain(q, r, rng)
			var tile := {
				"q": q,
				"r": r,
				"terrain_type": terrain,
				"discovered": false,
				"visible": false,
				"contains_village": false,
				"poi_type": "",
				"travel_feature": "",
				"settlement_id": "",
				"settlement_name": ""
			}
			world_map_tiles[_hex_key(q, r)] = tile
	_generate_rivers_and_bridges(rng)
	_place_player_village_on_coast(rng)
	_place_dungeons_on_map(rng)

func _pick_terrain(q: int, r: int, rng: RandomNumberGenerator) -> String:
	var dist_norm: float = float(_hex_distance(0, 0, q, r)) / float(max(1, world_map_radius))
	var shape_noise: float = _sample_continent_noise(q, r)
	var land_score: float = (1.0 - dist_norm * 1.05) + shape_noise * 0.25
	if land_score < 0.18:
		return "deniz"
	# Dag icin radial agirligi dusur; orta frekans relief ile tepeler haritaya yayilir.
	var relief: float = _sample_continent_noise(q * 3 + 23, r * 3 - 19)
	var elevation: float = clampf(
		land_score * 0.44 + shape_noise * 0.34 + relief * 0.42 + rng.randf_range(-0.11, 0.11),
		0.0, 1.0)
	if elevation > 0.742:
		return "dag"
	if elevation > 0.54:
		return "orman"
	if rng.randf() < 0.22:
		return "orman"
	return "ova"

func _place_settlements_on_map() -> void:
	world_map_settlement_positions.clear()
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		return
	if "settlements" in mm and mm.settlements.is_empty() and mm.has_method("create_settlements"):
		mm.create_settlements()
	var all_settlements: Array = mm.settlements if "settlements" in mm else []
	var land_candidates: Array = []
	for key in world_map_tiles.keys():
		var tile = world_map_tiles[key]
		var terrain: String = String(tile.get("terrain_type", "ova"))
		if terrain != "dag" and terrain != "deniz" and not bool(tile.get("contains_village", false)) and String(tile.get("poi_type", "")).is_empty():
			var dist = _hex_distance(
				int(world_map_player_pos.get("q", 0)),
				int(world_map_player_pos.get("r", 0)),
				int(tile.get("q", 0)),
				int(tile.get("r", 0))
			)
			if dist >= 2:
				land_candidates.append(tile)
	for settlement in all_settlements:
		if land_candidates.is_empty():
			break
		var idx := randi() % land_candidates.size()
		var selected: Dictionary = land_candidates[idx]
		land_candidates.remove_at(idx)
		var s_id: String = String(settlement.get("id", ""))
		var s_name: String = String(settlement.get("name", "Bilinmeyen"))
		var q: int = int(selected.get("q", 0))
		var r: int = int(selected.get("r", 0))
		var key := _hex_key(q, r)
		if world_map_tiles.has(key):
			world_map_tiles[key]["contains_village"] = true
			world_map_tiles[key]["poi_type"] = "neighbor_village"
			world_map_tiles[key]["settlement_id"] = s_id
			world_map_tiles[key]["settlement_name"] = s_name
		world_map_settlement_positions[s_id] = {
			"id": s_id,
			"name": s_name,
			"q": q,
			"r": r,
			"discovered": false
		}

func _initialize_world_settlement_states() -> void:
	for settlement_id in world_map_settlement_positions.keys():
		var info: Dictionary = world_map_settlement_positions[settlement_id]
		var q: int = int(info.get("q", 0))
		var r: int = int(info.get("r", 0))
		var tile: Dictionary = world_map_tiles.get(_hex_key(q, r), {})
		var terrain: String = String(tile.get("terrain_type", "ova"))
		if world_settlement_states.has(settlement_id):
			# Geriye donuk uyumluluk: profil yoksa ekle.
			var existing: Dictionary = world_settlement_states[settlement_id]
			if not existing.has("economy_profile"):
				existing["economy_profile"] = _build_settlement_economy_profile(terrain)
				world_settlement_states[settlement_id] = existing
			continue
		var base_food: int = 120
		match terrain:
			"orman":
				base_food = 145
			"dag":
				base_food = 95
			"akarsu":
				base_food = 155
			_:
				base_food = 120
		world_settlement_states[settlement_id] = {
			"id": String(info.get("id", settlement_id)),
			"name": String(info.get("name", "Bilinmeyen Koy")),
			"population": randi_range(55, 140),
			"food_stock": base_food + randi_range(-25, 35),
			"security": randi_range(45, 80),
			"stability": randi_range(45, 85),
			"crisis_pressure": 0.0,
			"economy_profile": _build_settlement_economy_profile(terrain),
			"last_updated_day": _last_tick_day
		}

func _build_settlement_economy_profile(terrain: String) -> Dictionary:
	var produces: Array[String] = []
	var scarce: Array[String] = []
	match terrain:
		"orman":
			produces = ["wood", "food"]
			scarce = ["stone"]
		"dag":
			produces = ["stone"]
			scarce = ["food", "wood"]
		"akarsu":
			produces = ["water", "food"]
			scarce = ["stone"]
		_:
			produces = ["food"]
			scarce = ["stone", "water"]
	var label: String = ""
	match terrain:
		"orman":
			label = "orman koyu"
		"dag":
			label = "dag koyu"
		"akarsu":
			label = "su kenari koy"
		_:
			label = "ova koyu"
	return {
		"label": label,
		"terrain": terrain,
		"produces": produces,
		"scarce": scarce
	}

func _reveal_tiles(center: Dictionary, radius: int, persistent: bool) -> Array:
	var cq := int(center.get("q", 0))
	var cr := int(center.get("r", 0))
	var discovered_now: Array = []
	for key in world_map_tiles.keys():
		var tile = world_map_tiles[key]
		var dist = _hex_distance(cq, cr, int(tile.get("q", 0)), int(tile.get("r", 0)))
		if dist <= radius:
			if persistent and not bool(tile.get("discovered", false)):
				tile["discovered"] = true
				discovered_now.append(key)
				world_map_tile_discovered.emit(key, tile.duplicate(true))
			world_map_tiles[key] = tile
			_mark_settlement_discovered_if_present(tile)
	return discovered_now

func _refresh_visible_tiles() -> void:
	var pq = int(world_map_player_pos.get("q", 0))
	var pr = int(world_map_player_pos.get("r", 0))
	for key in world_map_tiles.keys():
		var tile = world_map_tiles[key]
		var dist = _hex_distance(pq, pr, int(tile.get("q", 0)), int(tile.get("r", 0)))
		tile["visible"] = dist <= STARTING_REVEAL_RADIUS
		world_map_tiles[key] = tile

func _mark_settlement_discovered_if_present(tile: Dictionary) -> void:
	var settlement_id := String(tile.get("settlement_id", ""))
	if settlement_id.is_empty():
		return
	if world_map_settlement_positions.has(settlement_id):
		world_map_settlement_positions[settlement_id]["discovered"] = true

func _hex_key(q: int, r: int) -> String:
	return str(q) + "," + str(r)

func _hex_distance(aq: int, ar: int, bq: int, br: int) -> int:
	var asv := -aq - ar
	var bsv := -bq - br
	return int((abs(aq - bq) + abs(ar - br) + abs(asv - bsv)) / 2)

func _count_akarsu_neighbor_tiles(q: int, r: int) -> int:
	var n: int = 0
	for nb in _get_hex_neighbors(q, r):
		var nk: String = _hex_key(int(nb.get("q", 0)), int(nb.get("r", 0)))
		if not world_map_tiles.has(nk):
			continue
		var nt: Dictionary = world_map_tiles[nk]
		if String(nt.get("terrain_type", "")) == "akarsu":
			n += 1
	return n

func _min_hex_distance_to_any_akarsu(q: int, r: int) -> int:
	var best: int = 9999
	for key in world_map_tiles.keys():
		var tile: Dictionary = world_map_tiles[key]
		if String(tile.get("terrain_type", "")) != "akarsu":
			continue
		var aq: int = int(tile.get("q", 0))
		var ar: int = int(tile.get("r", 0))
		best = mini(best, _hex_distance(q, r, aq, ar))
	return best

func _pick_lowest_f_score(open_nodes: Array[String], f_score: Dictionary) -> String:
	var best_key: String = open_nodes[0]
	var best_val: float = float(f_score.get(best_key, INF))
	for key in open_nodes:
		var v: float = float(f_score.get(key, INF))
		if v < best_val:
			best_val = v
			best_key = key
	return best_key

func _reconstruct_world_path(came_from: Dictionary, current_key: String) -> Array[Dictionary]:
	var keys_reversed: Array[String] = [current_key]
	var key: String = current_key
	while came_from.has(key):
		key = String(came_from[key])
		keys_reversed.append(key)
	keys_reversed.reverse()
	var path: Array[Dictionary] = []
	for k in keys_reversed:
		path.append(_coords_from_key(k))
	return path

func _coords_from_key(key: String) -> Dictionary:
	var parts: PackedStringArray = key.split(",")
	if parts.size() != 2:
		return {"q": 0, "r": 0}
	return {"q": int(parts[0]), "r": int(parts[1])}

func _is_passable_world_tile(tile: Dictionary) -> bool:
	var terrain: String = String(tile.get("terrain_type", "ova"))
	return terrain != "deniz"

func _get_world_tile_travel_cost(tile: Dictionary, route_mode: String) -> float:
	var terrain: String = String(tile.get("terrain_type", "ova"))
	var feature: String = String(tile.get("travel_feature", ""))
	var base_cost: float = 1.0
	match terrain:
		"ova":
			base_cost = 1.0
		"orman":
			base_cost = 1.35
		"dag":
			base_cost = 2.0
		"akarsu":
			base_cost = 1.8
		_:
			base_cost = 1.0
	if feature == "kopru":
		base_cost *= 0.6
	if route_mode == "safest":
		match terrain:
			"orman":
				base_cost += 0.2
			"dag":
				base_cost += 0.45
			"akarsu":
				base_cost += 0.3
	return base_cost

func _should_trigger_world_travel_event(tile: Dictionary, rng: RandomNumberGenerator) -> bool:
	var terrain: String = String(tile.get("terrain_type", "ova"))
	var chance: float = 0.045
	match terrain:
		"orman":
			chance = 0.065
		"dag":
			chance = 0.09
		"akarsu":
			chance = 0.075
		_:
			chance = 0.045
	if String(tile.get("travel_feature", "")) == "kopru":
		chance *= 0.6
	var q: int = int(tile.get("q", 0))
	var r: int = int(tile.get("r", 0))
	chance += _get_settlement_incident_threat_bonus(q, r)
	chance += _get_hostile_settlement_threat_bonus(q, r)
	chance = clampf(chance, 0.01, 0.35)
	return rng.randf() < chance

func find_linked_incident_for_travel_hex(q: int, r: int, max_hex_distance: int = 5) -> Dictionary:
	var best: Dictionary = {}
	var best_d: int = 999
	for incident in world_settlement_incidents:
		if not incident is Dictionary:
			continue
		if bool(incident.get("resolved", false)):
			continue
		var sid: String = String(incident.get("settlement_id", ""))
		if sid.is_empty() or not world_map_settlement_positions.has(sid):
			continue
		var s_info: Dictionary = world_map_settlement_positions[sid]
		var sq: int = int(s_info.get("q", 0))
		var sr: int = int(s_info.get("r", 0))
		var dist: int = _hex_distance(q, r, sq, sr)
		if dist > max_hex_distance:
			continue
		if dist < best_d:
			best_d = dist
			best = incident.duplicate(true)
	if best.is_empty():
		return {}
	best["_hex_distance_to_incident_settlement"] = best_d
	return best

func get_settlement_hex_key_for_mission(settlement_id: String) -> String:
	if settlement_id.is_empty() or not world_map_settlement_positions.has(settlement_id):
		return ""
	var inf: Dictionary = world_map_settlement_positions[settlement_id]
	return str(int(inf.get("q", 0))) + "," + str(int(inf.get("r", 0)))

func _world_tile_is_village_center_hex(tile: Dictionary) -> bool:
	return bool(tile.get("contains_village", false))

func _min_hex_distance_to_any_settlement_center(q: int, r: int) -> int:
	var best: int = 999999
	for settlement_id in world_map_settlement_positions.keys():
		var inf: Dictionary = world_map_settlement_positions[settlement_id]
		var sq: int = int(inf.get("q", 0))
		var sr: int = int(inf.get("r", 0))
		var d: int = _hex_distance(q, r, sq, sr)
		if d < best:
			best = d
	return best

## `placement`: "any" — oyuncudan uzaklık halkası, köy merkez hex'leri hariç (yardım görevleri kendi hex'ini zaten set eder).
## "wilderness" — köy hex'i olmayan arazi (keşif).
## "near_settlement_trail" — köy üzerinde değil, en az bir yerleşime 1–3 hex (yol/karavan baskını vb.).
func _collect_mission_objective_hex_candidates(origin_q: int, origin_r: int, min_hex_distance: int, max_hex_distance: int, placement: String) -> Array[String]:
	var out: Array[String] = []
	var mn: int = maxi(1, min_hex_distance)
	var mx: int = maxi(mn, max_hex_distance)
	const NEAR_SETTLEMENT_MIN: int = 1
	const NEAR_SETTLEMENT_MAX: int = 3
	for key in world_map_tiles.keys():
		var tile: Dictionary = world_map_tiles[key]
		if not _is_passable_world_tile(tile):
			continue
		var q: int = int(tile.get("q", 0))
		var r: int = int(tile.get("r", 0))
		var d_player: int = _hex_distance(origin_q, origin_r, q, r)
		if d_player < mn or d_player > mx:
			continue
		if _world_tile_is_village_center_hex(tile):
			continue
		match placement:
			"any":
				out.append(key)
			"wilderness":
				# Köy hex'i değil; mümkünse yerleşim komşuluğundan da biraz uzak (saf arazi keşfi).
				var d_w: int = _min_hex_distance_to_any_settlement_center(q, r)
				if d_w >= 2:
					out.append(key)
			"near_settlement_trail":
				var d_t: int = _min_hex_distance_to_any_settlement_center(q, r)
				if d_t >= NEAR_SETTLEMENT_MIN and d_t <= NEAR_SETTLEMENT_MAX:
					out.append(key)
			_:
				out.append(key)
	return out

func pick_random_mission_objective_hex(min_hex_distance: int = 2, max_hex_distance: int = 14, placement: String = "any") -> String:
	var origin_q: int = int(world_map_player_pos.get("q", 0))
	var origin_r: int = int(world_map_player_pos.get("r", 0))
	var p: String = String(placement)
	if p.is_empty():
		p = "any"
	var candidates: Array[String] = _collect_mission_objective_hex_candidates(origin_q, origin_r, min_hex_distance, max_hex_distance, p)
	if not candidates.is_empty():
		candidates.shuffle()
		return candidates[0]
	if p != "any":
		candidates = _collect_mission_objective_hex_candidates(origin_q, origin_r, min_hex_distance, max_hex_distance, "any")
		if not candidates.is_empty():
			candidates.shuffle()
			return candidates[0]
	return ""

func resolve_settlement_incident_by_id(incident_id: String) -> bool:
	if incident_id.is_empty():
		return false
	var idx: int = -1
	for i in range(world_settlement_incidents.size()):
		if String(world_settlement_incidents[i].get("id", "")) == incident_id:
			idx = i
			break
	if idx < 0:
		return false
	var incident: Dictionary = world_settlement_incidents[idx].duplicate(true)
	world_settlement_incidents.remove_at(idx)
	var settlement_id: String = String(incident.get("settlement_id", ""))
	if world_settlement_states.has(settlement_id):
		var state: Dictionary = world_settlement_states[settlement_id]
		state["stability"] = clamp(int(state.get("stability", 60)) + randi_range(3, 9), 5, 100)
		state["security"] = clamp(int(state.get("security", 60)) + randi_range(1, 5), 5, 100)
		world_settlement_states[settlement_id] = state
	_post_incident_resolved_by_player_news(incident)
	world_map_updated.emit()
	return true

func _post_incident_resolved_by_player_news(incident: Dictionary) -> void:
	var nm: String = String(incident.get("settlement_name", "Komsu koy"))
	var day_report: int = _last_tick_day
	var tm: Node = get_node_or_null("/root/TimeManager")
	if tm and tm.has_method("get_day"):
		day_report = int(tm.get_day())
	_post_world_news({
		"category": "world",
		"subcategory": "success",
		"title": "Krize Mudahale",
		"content": "%s bolgesindeki kriz cariye yardimiyla yatisti." % nm,
		"day": day_report
	})

func on_village_surface_event(event_type: String, day: int) -> void:
	match event_type:
		"trade_caravan":
			_village_ripple_trade_caravan(day)
		"windfall":
			_village_ripple_windfall(day)
		"minor_accident":
			_village_ripple_minor_accident(day)
		"resource_discovery":
			_village_ripple_resource_discovery(day)
		"traveler":
			_village_ripple_traveler(day)
		"immigration_wave":
			_village_ripple_immigration_wave(day)
		_:
			pass

func _village_ripple_trade_caravan(day: int) -> void:
	var candidates: Array[String] = []
	for sid in world_map_settlement_positions.keys():
		var inf: Dictionary = world_map_settlement_positions[sid]
		if String(inf.get("id", sid)).is_empty():
			continue
		candidates.append(sid)
	if candidates.is_empty():
		return
	var pick: String = candidates[randi() % candidates.size()]
	var nm: String = String(world_map_settlement_positions[pick].get("name", "?"))
	if nm.is_empty() or nm == "?":
		return
	change_settlement_relation("Köy", nm, 1)
	_post_world_news({
		"category": "world",
		"subcategory": "info",
		"title": "Ticaret Hatti",
		"content": "Koydeki tuccar trafigi %s ile iliskiyi hafif yumusatti." % nm,
		"day": day
	})

func _village_ripple_windfall(day: int) -> void:
	var keys: Array = world_map_settlement_positions.keys()
	if keys.is_empty():
		return
	var sid: String = String(keys[randi() % keys.size()])
	if not world_settlement_states.has(sid):
		return
	var st: Dictionary = world_settlement_states[sid]
	st["food_stock"] = clamp(int(st.get("food_stock", 100)) + randi_range(4, 12), 0, 260)
	world_settlement_states[sid] = st

func _village_ripple_minor_accident(day: int) -> void:
	if world_settlement_incidents.size() >= MAX_ACTIVE_SETTLEMENT_INCIDENTS:
		return
	if randf() > 0.18:
		return
	var candidates: Array[String] = []
	for sid in world_map_settlement_positions.keys():
		if _has_active_incident_for_settlement(sid):
			continue
		candidates.append(sid)
	if candidates.is_empty():
		return
	candidates.shuffle()
	var target: String = String(candidates[0])
	var role_mods: Dictionary = _get_living_world_role_modifiers()
	var inc: Dictionary = _create_settlement_incident(target, day, role_mods)
	if inc.is_empty():
		return
	inc["type"] = "bandit_road"
	inc["severity"] = clampf(float(inc.get("severity", 1.0)) * 0.75, 0.4, 1.6)
	world_settlement_incidents.append(inc)
	_apply_settlement_incident_start_effects(inc)
	_post_settlement_incident_news(inc, role_mods)
	_try_offer_relief_mission_for_incident(inc)

func _village_ripple_resource_discovery(day: int) -> void:
	var keys: Array = world_map_settlement_positions.keys()
	if keys.is_empty():
		return
	var sid: String = String(keys[randi() % keys.size()])
	if not world_settlement_states.has(sid):
		return
	var st: Dictionary = world_settlement_states[sid]
	st["security"] = clamp(int(st.get("security", 60)) + randi_range(1, 4), 0, 100)
	world_settlement_states[sid] = st
	var nm: String = String(world_map_settlement_positions.get(sid, {}).get("name", "?"))
	if nm.is_empty() or nm == "?":
		return
	_post_world_news({
		"category": "world",
		"subcategory": "info",
		"title": "Bolgede Soz",
		"content": "Koydeki kesif haberi %s civarinda guvenlik algisini hafif artirdi." % nm,
		"day": day
	})

func _village_ripple_traveler(day: int) -> void:
	var candidates: Array[String] = []
	for sid in world_map_settlement_positions.keys():
		var inf: Dictionary = world_map_settlement_positions[sid]
		if String(inf.get("id", sid)).is_empty():
			continue
		candidates.append(sid)
	if candidates.is_empty():
		return
	var pick: String = candidates[randi() % candidates.size()]
	var nm: String = String(world_map_settlement_positions[pick].get("name", "?"))
	if nm.is_empty() or nm == "?":
		return
	change_settlement_relation("Köy", nm, 1)
	_post_world_news({
		"category": "world",
		"subcategory": "info",
		"title": "Seyyah",
		"content": "Koyde konaklayan bir gezgin %s ile iliskiyi yumusatti." % nm,
		"day": day
	})

func _village_ripple_immigration_wave(day: int) -> void:
	var keys: Array = world_map_settlement_positions.keys()
	if keys.is_empty():
		return
	var sid: String = String(keys[randi() % keys.size()])
	if not world_settlement_states.has(sid):
		return
	var st: Dictionary = world_settlement_states[sid]
	st["stability"] = clamp(int(st.get("stability", 60)) + randi_range(2, 6), 0, 100)
	st["crisis_pressure"] = clampf(float(st.get("crisis_pressure", 0.0)) - 0.25, 0.0, 2.0)
	world_settlement_states[sid] = st
	var nm: String = String(world_map_settlement_positions.get(sid, {}).get("name", "?"))
	if nm.is_empty() or nm == "?":
		return
	_post_world_news({
		"category": "world",
		"subcategory": "info",
		"title": "Goc Etkisi",
		"content": "Koydeki goc hareketi %s tarafinda istikrara hafif destek oldu." % nm,
		"day": day
	})

func _try_offer_relief_mission_for_incident(incident: Dictionary) -> void:
	var mm: Node = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("try_spawn_incident_relief_mission"):
		mm.call("try_spawn_incident_relief_mission", incident)

func _roll_travel_event_expedition_gain(rng: RandomNumberGenerator, terrain: String, choice_branch: String) -> Dictionary:
	var g: Dictionary = {}
	match choice_branch:
		"cancel":
			match terrain:
				"orman":
					if rng.randf() < 0.72:
						g["food"] = 2 if rng.randf() < 0.24 else 1
				"akarsu":
					g["water"] = 2 if rng.randf() < 0.40 else 1
				"dag":
					if rng.randf() < 0.38:
						g["food"] = 1
					if rng.randf() < 0.20:
						g["water"] = maxi(int(g.get("water", 0)), 1)
				"ova":
					if rng.randf() < 0.30:
						g["food"] = 1
				_:
					if rng.randf() < 0.22:
						g["food"] = 1
		"continue":
			match terrain:
				"orman":
					if rng.randf() < 0.14:
						g["food"] = 1
				"akarsu":
					if rng.randf() < 0.22:
						g["water"] = 1
				"dag":
					if rng.randf() < 0.10:
						g["food"] = 1
				_:
					pass
		"drop":
			match terrain:
				"orman":
					if rng.randf() < 0.34:
						g["food"] = 1
				"akarsu":
					if rng.randf() < 0.48:
						g["water"] = 1
				_:
					pass
	return g


func _clamp_world_expedition_gain_to_room(gain: Dictionary, player_stats: Node) -> Dictionary:
	if gain.is_empty() or player_stats == null or not player_stats.has_method("get_world_expedition_supplies"):
		return {}
	var caps: Dictionary = {}
	if player_stats.has_method("get_world_expedition_pack_caps"):
		caps = player_stats.call("get_world_expedition_pack_caps")
	else:
		caps = {"food": 1, "water": 1, "medicine": 24, "world_gold": 2500}
	var cur: Dictionary = player_stats.call("get_world_expedition_supplies")
	var out: Dictionary = {}
	for k in gain.keys():
		var key: String = str(k)
		if not caps.has(key):
			continue
		var add_n: int = maxi(0, int(gain[k]))
		if add_n <= 0:
			continue
		var cap: int = int(caps[key])
		var have: int = maxi(0, int(cur.get(key, 0)))
		var room: int = maxi(0, cap - have)
		add_n = mini(add_n, room)
		if add_n > 0:
			out[key] = add_n
	return out


func _build_world_travel_event_message(tile: Dictionary, linked_incident: Dictionary = {}, rng: RandomNumberGenerator = null) -> String:
	var terrain: String = String(tile.get("terrain_type", "ova"))
	var rr: RandomNumberGenerator = rng
	if rr == null:
		rr = RandomNumberGenerator.new()
		rr.randomize()
	var prefix: String = ""
	if not linked_incident.is_empty():
		var nm: String = String(linked_incident.get("settlement_name", ""))
		var it: String = String(linked_incident.get("type", ""))
		if not nm.is_empty():
			match it:
				"wolf_attack":
					prefix = "%s bolgesindeki kurt gerilimi buraya da siziyor. " % nm
				"harvest_failure":
					prefix = "%s tarafindaki erzak baskisi haberleri yayildi. " % nm
				"migrant_wave":
					prefix = "%s civarinda duzensiz goc hareketleri var. " % nm
				"bandit_road":
					prefix = "%s yolunda haydut tehlikesi bolgede. " % nm
				"plague_scare":
					prefix = "%s tarafinda hastalik kaygisi dolanıyor. " % nm
				_:
					prefix = "%s civarinda kriz haberi var. " % nm
	var prompts: PackedStringArray = PackedStringArray()
	match _normalized_travel_story_terrain(terrain):
		"orman":
			prompts = [
				"Sis bir anda coktu; patika secmek zorlasti.",
				"Dallar arasindan gelen sesler ekibi gerdi.",
				"Terk bir kamp atesine rastladin; ici supheli gorunuyor."
			]
		"dag":
			prompts = [
				"Dar gecitte ufak kaya dusmeleri basladi.",
				"Ruzgar bastirdi; adimlar guvensizlesiyor.",
				"Eski maden agzinda catlak sesleri duyuldu."
			]
		"akarsu":
			prompts = [
				"Akinti sertlesti; gecis noktasi riskli.",
				"Kopru tahtalari gicirdiyor, zemin oynak.",
				"Kiyida suruklenen bir sandik dikkat cekti."
			]
		_:
			prompts = [
				"Yol catallandi; izler birbirine girdi.",
				"Kervan izleri bir anda kesildi.",
				"Yol kenari enkazinda ters giden bir seyler var."
			]
	var base: String = prompts[rr.randi_range(0, prompts.size() - 1)] + " Talihi iki zar belirleyecek."
	return prefix + base

func _make_travel_effect(extra_minutes: int, card_text: String, expedition_gain: Dictionary = {}, world_gold_loss_fraction: float = 0.0, health_loss_fraction: float = 0.0, carried_resource_loss_fraction: float = 0.0, dungeon_gold_loss_fraction: float = 0.0, rescued_loss_fraction: float = 0.0, gold_delta: int = 0) -> Dictionary:
	return {
		"extra_minutes": maxi(0, extra_minutes),
		"gold_delta": gold_delta,
		"world_gold_loss_fraction": clampf(world_gold_loss_fraction, 0.0, 1.0),
		"carried_resource_loss_fraction": clampf(carried_resource_loss_fraction, 0.0, 1.0),
		"dungeon_gold_loss_fraction": clampf(dungeon_gold_loss_fraction, 0.0, 1.0),
		"rescued_loss_fraction": clampf(rescued_loss_fraction, 0.0, 1.0),
		"health_loss_fraction": clampf(health_loss_fraction, 0.0, 1.0),
		"expedition_supplies_gain": expedition_gain.duplicate(true),
		"card_text": card_text
	}

func _build_world_travel_event_payload(tile: Dictionary, q: int, r: int, rng: RandomNumberGenerator) -> Dictionary:
	var terrain: String = String(tile.get("terrain_type", "ova"))
	var cargo_risk_mult: float = _compute_cargo_risk_multiplier()
	var linked: Dictionary = find_linked_incident_for_travel_hex(q, r, 5)
	var linked_incident_id: String = ""
	var linked_settlement_id: String = ""
	var linked_settlement_name: String = ""
	var linked_incident_type: String = ""
	if not linked.is_empty():
		linked_incident_id = String(linked.get("id", ""))
		linked_settlement_id = String(linked.get("settlement_id", ""))
		linked_settlement_name = String(linked.get("settlement_name", ""))
		linked_incident_type = String(linked.get("type", ""))
	return {
		"type": "travel_incident",
		"q": q,
		"r": r,
		"terrain": terrain,
		"cargo_risk_multiplier": cargo_risk_mult,
		"linked_incident_id": linked_incident_id,
		"linked_settlement_id": linked_settlement_id,
		"linked_settlement_name": linked_settlement_name,
		"linked_incident_type": linked_incident_type,
		"message": _build_world_travel_event_message(tile, linked, rng)
	}

func _classify_travel_dice_tier(d1: int, d2: int) -> int:
	var s: int = d1 + d2
	if s <= 2:
		return 0
	if s <= 4:
		return 1
	if s <= 8:
		return 2
	if s <= 11:
		return 3
	return 4

func _travel_dice_tier_display_name(tier: int, d1: int, d2: int) -> String:
	if d1 == 3 and d2 == 3:
		return "Tam notr (3+3)"
	match tier:
		0:
			return "Felaket (2 — du yek)"
		1:
			return "Kotu (3-4)"
		2:
			return "Sakin (5-8)"
		3:
			return "Iyi (9-11)"
		4:
			return "Mukemmel (12 — dusek)"
	return ""

func _apply_cargo_and_bridge_to_bad_effect(effect: Dictionary, cargo: float, bridge: bool) -> void:
	var mult: float = cargo
	if bridge:
		mult *= 0.55
	for k in ["world_gold_loss_fraction", "health_loss_fraction", "carried_resource_loss_fraction", "dungeon_gold_loss_fraction", "rescued_loss_fraction"]:
		if effect.has(k):
			effect[k] = clampf(float(effect[k]) * mult, 0.0, 0.92)

func _normalized_travel_story_terrain(terrain: String) -> String:
	return terrain if terrain in ["orman", "dag", "akarsu"] else "ova"

func _pick_travel_story_bundle(terrain: String, rng: RandomNumberGenerator) -> Dictionary:
	var t: String = _normalized_travel_story_terrain(terrain)
	var pool: Array[Dictionary] = []
	match t:
		"orman":
			pool = [
				{"intro": "Sis basti, izler kayboldu.", "t4": "Yosunlu bir kestirme buldun.", "t3": "Kuru patikayi yakaladin.", "t2": "Dallari acip ilerledin.", "t1": "Yanlis patikaya sapip geri dondun.", "t0": "Bogucu sis, ekip dagildi ve buyuk zaman kaybi yasandi."},
				{"intro": "Yabani hayvan izleri cogaldi.", "t4": "Hayvanlar senden uzaklasti; guvenli bir gecis yakaladin.", "t3": "Tehlikeyi sessizce atlattin.", "t2": "Nefesini tutup gecmeyi basardin.", "t1": "Kacisirken yaralandin.", "t0": "Pusuya benzer bir kargasada agir bedel odedin."},
				{"intro": "Terk bir kamp atesine rastladin.", "t4": "Kamp temizdi, ise yarar erzak buldun.", "t3": "Kullanisli bir parca cikarabildin.", "t2": "Kamp bos cikti, yoluna devam ettin.", "t1": "Curuuk malzeme oyalanmana neden oldu.", "t0": "Tuzakli kamp buyuk kayba yol acti."}
			]
		"dag":
			pool = [
				{"intro": "Dar gecitte kaya sesleri yankilandi.", "t4": "Gizli bir dag gecidi buldun.", "t3": "Saglam zeminden akici gectin.", "t2": "Temkinli adimlarla sorunsuz gectin.", "t1": "Kucuk bir kayma yavaslatti.", "t0": "Kaya dusmesi ekibi zorladi."},
				{"intro": "Sert ruzgar dengeyi bozdu.", "t4": "Ruzgari arkana alip hiz kazandin.", "t3": "Ruzgar dindi, gecis kolaylasti.", "t2": "Bekleyip uygun anda gectin.", "t1": "Yuk dengesi bozuldu, oyalandin.", "t0": "Ucurum kenarinda panik buyuk kayip getirdi."},
				{"intro": "Eski maden agzinda catlaklar gordun.", "t4": "Maden ceplerinden degerli parca topladin.", "t3": "Kucuk bir odul buldun.", "t2": "Gereksiz risk almayip yoluna devam ettin.", "t1": "Cokuntu yuzunden geri adim attin.", "t0": "Maden agzi cokerken agir gecikme yasandi."}
			]
		"akarsu":
			pool = [
				{"intro": "Akinti beklenenden hizliydi.", "t4": "Sakin bir gecit bulup hizla karsiya gectin.", "t3": "Akintiyi dogru aciyla gectin.", "t2": "Islanip toparlandin, yoluna devam.", "t1": "Sicrama aninda dengeyi kaybettin.", "t0": "Akinti yukunu surukledi, agir kayip yasandi."},
				{"intro": "Kopru tahtalari gicirdamaya basladi.", "t4": "Yan servis koprusunu fark ettin.", "t3": "Saglam bolmeden gectin.", "t2": "Yavas ama temiz bir gecis oldu.", "t1": "Kopru donusu oyalanmana neden oldu.", "t0": "Kopru kismi cokerken panik buyudu."},
				{"intro": "Kiyida suruklenen bir sandik gordun.", "t4": "Sandiktan degerli seyler cikti.", "t3": "Az da olsa ise yarar malzeme buldun.", "t2": "Sandik neredeyse bostu.", "t1": "Sandigi acarken zaman kaybettin.", "t0": "Tuzakli sandik zarar verdi."}
			]
		_:
			pool = [
				{"intro": "Yol catallandi, izler karisti.", "t4": "Kestirme buldun.", "t3": "Dogru kola erken saptin.", "t2": "Kisa bir tereddutle devam ettin.", "t1": "Yanlis kola girip geri dondun.", "t0": "Uzun bir dolambac buyuk kayip getirdi."},
				{"intro": "Kervan izleri dagilmisti.", "t4": "Takas icin uygun bir kervanla karsilastin.", "t3": "Yolcu notundan faydali bilgi ciktı.", "t2": "Izler anlamsizlasti.", "t1": "Kucuk bir hirsizlik yasandi.", "t0": "Haydut artcisi pusuya dusurdun."},
				{"intro": "Yol kenari enkazi dikkat cekti.", "t4": "Enkazdan temiz kazanc elde ettin.", "t3": "Ise yarar bir parca buldun.", "t2": "Risk almadan gectin.", "t1": "Curuk malzeme moral bozdu.", "t0": "Enkazdaki tehlike buyuk zarar verdi."}
			]
	return pool[rng.randi_range(0, pool.size() - 1)]

func _travel_penalty_profile(terrain: String, tier: int) -> Dictionary:
	var t: String = _normalized_travel_story_terrain(terrain)
	if tier == 1:
		match t:
			"orman":
				return {"m_min": 12, "m_max": 26, "wg": 0.10, "hp": 0.08, "carried": 0.09, "dg": 0.05, "resc": 0.03, "g_min": 2, "g_max": 5}
			"dag":
				return {"m_min": 14, "m_max": 30, "wg": 0.11, "hp": 0.09, "carried": 0.10, "dg": 0.06, "resc": 0.04, "g_min": 2, "g_max": 5}
			"akarsu":
				return {"m_min": 10, "m_max": 24, "wg": 0.09, "hp": 0.07, "carried": 0.08, "dg": 0.05, "resc": 0.03, "g_min": 1, "g_max": 4}
			_:
				return {"m_min": 10, "m_max": 24, "wg": 0.09, "hp": 0.06, "carried": 0.08, "dg": 0.05, "resc": 0.03, "g_min": 1, "g_max": 4}
	# tier 0 felaket
	match t:
		"orman":
			return {"m_min": 30, "m_max": 52, "wg": 0.20, "hp": 0.15, "carried": 0.18, "dg": 0.12, "resc": 0.08, "g_min": 4, "g_max": 8}
		"dag":
			return {"m_min": 34, "m_max": 58, "wg": 0.22, "hp": 0.17, "carried": 0.20, "dg": 0.14, "resc": 0.09, "g_min": 4, "g_max": 9}
		"akarsu":
			return {"m_min": 28, "m_max": 50, "wg": 0.18, "hp": 0.13, "carried": 0.16, "dg": 0.11, "resc": 0.07, "g_min": 3, "g_max": 7}
		_:
			return {"m_min": 26, "m_max": 46, "wg": 0.17, "hp": 0.12, "carried": 0.15, "dg": 0.10, "resc": 0.07, "g_min": 3, "g_max": 7}

## Zar iyi bantlarinda sifir cikarsa (canta dolu vb.) kucuk bir odul garantisi.
func _dice_padded_expedition_gain(base: Dictionary, terrain: String, rng: RandomNumberGenerator, psn: Node) -> Dictionary:
	var g: Dictionary = _clamp_world_expedition_gain_to_room(base, psn)
	if not g.is_empty():
		return g
	var fallback: Dictionary = {}
	if terrain == "akarsu" and rng.randf() < 0.55:
		fallback["water"] = 1
	else:
		fallback["food"] = 1
	return _clamp_world_expedition_gain_to_room(fallback, psn)

func _build_travel_dice_resolution_effect(terrain: String, tier: int, d1: int, d2: int, rng: RandomNumberGenerator, tile: Dictionary) -> Dictionary:
	var bundle: Dictionary = _pick_travel_story_bundle(terrain, rng)
	if d1 == 3 and d2 == 3:
		return _make_travel_effect(
			0,
			String(bundle.get("intro", "Yol sustu.")) + " Iki zar da 3: ne kazandin ne kaybettin.",
			{},
			0.0,
			0.0,
			0.0,
			0.0,
			0.0,
			0
		)
	var cargo: float = _compute_cargo_risk_multiplier()
	var bridge: bool = String(tile.get("travel_feature", "")) == "kopru"
	var psn: Node = get_node_or_null("/root/PlayerStats")
	match tier:
		4:
			var g_can: Dictionary = _roll_travel_event_expedition_gain(rng, terrain, "cancel")
			var g_con: Dictionary = _roll_travel_event_expedition_gain(rng, terrain, "continue")
			var merged: Dictionary = {}
			for kk in g_can.keys():
				merged[str(kk)] = int(g_can[kk])
			for kk2 in g_con.keys():
				var ks: String = str(kk2)
				merged[ks] = int(merged.get(ks, 0)) + int(g_con.get(ks, 0))
			var exm: Dictionary = _dice_padded_expedition_gain(merged, terrain, rng, psn)
			return _make_travel_effect(
				rng.randi_range(0, 6),
				String(bundle.get("intro", "")) + " " + String(bundle.get("t4", "Mukemmel sans.")),
				exm,
				0.0,
				0.0,
				0.0,
				0.0,
				0.0,
				rng.randi_range(4, 8)
			)
		3:
			var g3raw: Dictionary = _roll_travel_event_expedition_gain(rng, terrain, "continue")
			var g3: Dictionary = _dice_padded_expedition_gain(g3raw, terrain, rng, psn)
			return _make_travel_effect(
				rng.randi_range(4, 14),
				String(bundle.get("intro", "")) + " " + String(bundle.get("t3", "Isler yolunda.")),
				g3,
				0.0,
				0.0,
				0.0,
				0.0,
				0.0,
				0
			)
		2:
			return _make_travel_effect(
				rng.randi_range(5, 18),
				String(bundle.get("intro", "")) + " " + String(bundle.get("t2", "Sakin bir gecis.")),
				{},
				0.0,
				0.0,
				0.0,
				0.0,
				0.0,
				0
			)
		1:
			var p1: Dictionary = _travel_penalty_profile(terrain, 1)
			var eff1: Dictionary = _make_travel_effect(
				rng.randi_range(int(p1.get("m_min", 12)), int(p1.get("m_max", 28))),
				String(bundle.get("intro", "")) + " " + String(bundle.get("t1", "Kucuk felaket.")),
				{},
				float(p1.get("wg", 0.11)),
				float(p1.get("hp", 0.07)),
				float(p1.get("carried", 0.09)),
				float(p1.get("dg", 0.06)),
				float(p1.get("resc", 0.04)),
				-rng.randi_range(int(p1.get("g_min", 2)), int(p1.get("g_max", 5)))
			)
			_apply_cargo_and_bridge_to_bad_effect(eff1, cargo, bridge)
			return eff1
		0:
			var p0: Dictionary = _travel_penalty_profile(terrain, 0)
			var eff0: Dictionary = _make_travel_effect(
				rng.randi_range(int(p0.get("m_min", 28)), int(p0.get("m_max", 52))),
				String(bundle.get("intro", "")) + " " + String(bundle.get("t0", "Her sey bir anda kotuye gitti.")),
				{},
				float(p0.get("wg", 0.22)),
				float(p0.get("hp", 0.16)),
				float(p0.get("carried", 0.20)),
				float(p0.get("dg", 0.14)),
				float(p0.get("resc", 0.09)),
				-rng.randi_range(int(p0.get("g_min", 4)), int(p0.get("g_max", 9)))
			)
			_apply_cargo_and_bridge_to_bad_effect(eff0, cargo, bridge)
			return eff0
	return _make_travel_effect(0, "", {}, 0.0, 0.0, 0.0, 0.0, 0.0, 0)

func apply_world_map_travel_event_dice_roll(event_data: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var d1: int = rng.randi_range(1, 6)
	var d2: int = rng.randi_range(1, 6)
	return apply_world_map_travel_event_with_dice(event_data, d1, d2)

func apply_world_map_travel_event_with_dice(event_data: Dictionary, die1: int, die2: int) -> Dictionary:
	var d1: int = clampi(int(die1), 1, 6)
	var d2: int = clampi(int(die2), 1, 6)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tier: int = _classify_travel_dice_tier(d1, d2)
	var terrain: String = String(event_data.get("terrain", "ova"))
	var q: int = int(event_data.get("q", 0))
	var r: int = int(event_data.get("r", 0))
	var tile_key: String = str(q) + "," + str(r)
	var tile: Dictionary = world_map_tiles.get(tile_key, {})
	if tile.is_empty():
		tile = {"terrain_type": terrain, "travel_feature": "", "q": q, "r": r}
	var eff: Dictionary = _build_travel_dice_resolution_effect(terrain, tier, d1, d2, rng, tile)
	var res: Dictionary = _apply_travel_event_effect_payload(eff, "dice")
	res["dice_d1"] = d1
	res["dice_d2"] = d2
	res["dice_sum"] = d1 + d2
	res["dice_tier"] = tier
	res["dice_tier_name"] = _travel_dice_tier_display_name(tier, d1, d2)
	return res

func _compute_cargo_risk_multiplier() -> float:
	# Oyuncu ne kadar yük taşıyorsa o kadar hedef olur: riskler 1.0 .. 1.85 arasında artar.
	var score: float = 0.0
	
	var player_stats: Node = get_node_or_null("/root/PlayerStats")
	if player_stats and player_stats.has_method("get_carried_resources"):
		var carried: Dictionary = player_stats.get_carried_resources()
		var total_resources: int = 0
		for key in carried.keys():
			total_resources += max(0, int(carried[key]))
		score += minf(0.6, float(total_resources) / 120.0)  # ~120 kaynakta +0.6
	
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if gpd and "dungeon_gold" in gpd:
		var dg: int = max(0, int(gpd.get("dungeon_gold")))
		score += minf(0.55, float(dg) / 700.0)  # ~700 altında +0.55
	
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if drs:
		var villagers: Array = drs.get("pending_rescued_villagers") if "pending_rescued_villagers" in drs else []
		var cariyes: Array = drs.get("pending_rescued_cariyes") if "pending_rescued_cariyes" in drs else []
		score += minf(0.5, float(villagers.size() + cariyes.size()) * 0.08)
	if player_stats and player_stats.has_method("get_world_expedition_total_weight_score"):
		var ew: int = int(player_stats.call("get_world_expedition_total_weight_score"))
		score += minf(0.35, float(ew) / 90.0)
	return clampf(1.0 + score, 1.0, 1.85)

func apply_world_map_travel_event_resolution(event_data: Dictionary, chose_continue: bool) -> Dictionary:
	var effect_key: String = "continue_effect" if chose_continue else "cancel_effect"
	return _apply_world_map_travel_event_resolution_internal(event_data, effect_key)

func apply_world_map_travel_event_resolution_with_choice(event_data: Dictionary, choice: String) -> Dictionary:
	var effect_key: String = "cancel_effect"
	match choice:
		"continue":
			effect_key = "continue_effect"
		"drop":
			effect_key = "drop_effect"
		_:
			effect_key = "cancel_effect"
	return _apply_world_map_travel_event_resolution_internal(event_data, effect_key)

func _apply_world_map_travel_event_resolution_internal(event_data: Dictionary, effect_key: String) -> Dictionary:
	var effect: Dictionary = event_data.get(effect_key, {})
	var choice_key: String = effect_key.replace("_effect", "")
	return _apply_travel_event_effect_payload(effect, choice_key)

func _apply_travel_event_effect_payload(effect: Dictionary, resolved_choice: String) -> Dictionary:
	var extra_minutes: int = int(effect.get("extra_minutes", 0))
	var gold_delta: int = int(effect.get("gold_delta", 0))
	var world_gold_loss_fraction: float = float(effect.get("world_gold_loss_fraction", 0.0))
	var carried_loss_fraction: float = float(effect.get("carried_resource_loss_fraction", 0.0))
	var dungeon_gold_loss_fraction: float = float(effect.get("dungeon_gold_loss_fraction", 0.0))
	var rescued_loss_fraction: float = float(effect.get("rescued_loss_fraction", 0.0))
	var health_loss_fraction: float = float(effect.get("health_loss_fraction", 0.0))
	var carried_losses: Dictionary = {}
	var world_gold_lost: int = 0
	var dungeon_gold_lost: int = 0
	var rescued_losses: Dictionary = {"villagers": 0, "cariyes": 0}
	var health_lost: float = 0.0
	if extra_minutes > 0:
		var tm: Node = get_node_or_null("/root/TimeManager")
		if tm and tm.has_method("advance_minutes"):
			tm.call("advance_minutes", extra_minutes)
	if gold_delta != 0:
		var ps_g: Node = get_node_or_null("/root/PlayerStats")
		if ps_g and ps_g.has_method("apply_world_expedition_gold_delta"):
			ps_g.call("apply_world_expedition_gold_delta", gold_delta)
	if world_gold_loss_fraction > 0.0:
		var ps_loss: Node = get_node_or_null("/root/PlayerStats")
		if ps_loss and ps_loss.has_method("lose_world_expedition_gold_by_fraction"):
			world_gold_lost = int(ps_loss.call("lose_world_expedition_gold_by_fraction", world_gold_loss_fraction))
	var player_stats: Node = get_node_or_null("/root/PlayerStats")
	if player_stats and player_stats.has_method("lose_world_expedition_supplies_by_fraction"):
		carried_losses = player_stats.lose_world_expedition_supplies_by_fraction(carried_loss_fraction)
	if player_stats and player_stats.has_method("lose_world_expedition_gold_by_fraction") and dungeon_gold_loss_fraction > 0.0:
		player_stats.lose_world_expedition_gold_by_fraction(dungeon_gold_loss_fraction)
	var gpd2: Node = get_node_or_null("/root/GlobalPlayerData")
	if gpd2 and gpd2.has_method("lose_dungeon_gold_by_fraction"):
		dungeon_gold_lost = int(gpd2.lose_dungeon_gold_by_fraction(dungeon_gold_loss_fraction))
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if drs:
		rescued_losses = _lose_pending_rescued_by_fraction(drs, rescued_loss_fraction)
	if player_stats and player_stats.has_method("get_current_health") and player_stats.has_method("set_current_health"):
		var old_health: float = float(player_stats.get_current_health())
		var max_health: float = float(player_stats.get_max_health()) if player_stats.has_method("get_max_health") else old_health
		var damage: float = maxf(1.0, floor(max_health * health_loss_fraction)) if health_loss_fraction > 0.0 else 0.0
		if damage > 0.0:
			var new_health: float = maxf(1.0, old_health - damage)
			player_stats.set_current_health(new_health, false)
			health_lost = maxf(0.0, old_health - new_health)
	var exp_gain_raw: Dictionary = effect.get("expedition_supplies_gain", {})
	var expedition_food_gained: int = 0
	var expedition_water_gained: int = 0
	var expedition_medicine_gained: int = 0
	if not exp_gain_raw.is_empty() and player_stats and player_stats.has_method("add_world_expedition_supplies"):
		var capped_gain: Dictionary = _clamp_world_expedition_gain_to_room(exp_gain_raw, player_stats)
		if not capped_gain.is_empty():
			player_stats.add_world_expedition_supplies(capped_gain)
			expedition_food_gained = int(capped_gain.get("food", 0))
			expedition_water_gained = int(capped_gain.get("water", 0))
			expedition_medicine_gained = int(capped_gain.get("medicine", 0))
	return {
		"applied": true,
		"extra_minutes": extra_minutes,
		"gold_delta": gold_delta,
		"world_gold_lost": world_gold_lost,
		"carried_losses": carried_losses,
		"dungeon_gold_lost": dungeon_gold_lost,
		"rescued_losses": rescued_losses,
		"health_lost": health_lost,
		"choice": resolved_choice,
		"card_text": String(effect.get("card_text", "")),
		"expedition_food_gained": expedition_food_gained,
		"expedition_water_gained": expedition_water_gained,
		"expedition_medicine_gained": expedition_medicine_gained
	}

func _lose_pending_rescued_by_fraction(drs: Node, fraction: float) -> Dictionary:
	fraction = clampf(fraction, 0.0, 1.0)
	if fraction <= 0.0:
		return {"villagers": 0, "cariyes": 0}
	var villagers_loss: int = 0
	var cariyes_loss: int = 0
	if "pending_rescued_villagers" in drs:
		var villagers: Array = drs.pending_rescued_villagers
		var target_v_loss: int = int(floor(float(villagers.size()) * fraction))
		for _i in range(target_v_loss):
			if villagers.is_empty():
				break
			villagers.remove_at(villagers.size() - 1)
			villagers_loss += 1
	if "pending_rescued_cariyes" in drs:
		var cariyes: Array = drs.pending_rescued_cariyes
		var target_c_loss: int = int(floor(float(cariyes.size()) * fraction))
		for _j in range(target_c_loss):
			if cariyes.is_empty():
				break
			cariyes.remove_at(cariyes.size() - 1)
			cariyes_loss += 1
	return {"villagers": villagers_loss, "cariyes": cariyes_loss}

func _upgrade_world_map_state_if_needed(state: Dictionary) -> void:
	var version: int = int(state.get("version", 1))
	if version >= WORLD_MAP_VERSION:
		return
	for key in world_map_tiles.keys():
		var tile: Dictionary = world_map_tiles[key]
		if not tile.has("travel_feature"):
			tile["travel_feature"] = ""
		world_map_tiles[key] = tile

func _sample_continent_noise(q: int, r: int) -> float:
	var x := float(q)
	var y := float(r)
	var n1 := sin((x * 0.12 + y * 0.19) * _continent_noise_a)
	var n2 := cos((x * 0.08 - y * 0.11) * _continent_noise_b)
	var n3 := sin((x * 0.04 + y * 0.06) * _continent_noise_c)
	return (n1 * 0.5 + n2 * 0.35 + n3 * 0.15)

func _is_land_terrain(terrain: String) -> bool:
	return terrain != "deniz"

func _is_coastal_tile(q: int, r: int) -> bool:
	var key := _hex_key(q, r)
	if not world_map_tiles.has(key):
		return false
	var tile: Dictionary = world_map_tiles[key]
	if not _is_land_terrain(String(tile.get("terrain_type", "deniz"))):
		return false
	for n in _get_hex_neighbors(q, r):
		var nk := _hex_key(int(n.get("q", 0)), int(n.get("r", 0)))
		if world_map_tiles.has(nk):
			var neighbor: Dictionary = world_map_tiles[nk]
			if String(neighbor.get("terrain_type", "ova")) == "deniz":
				return true
	return false

func _place_player_village_on_coast(rng: RandomNumberGenerator) -> void:
	var coastal_candidates: Array[Dictionary] = []
	for key in world_map_tiles.keys():
		var tile: Dictionary = world_map_tiles[key]
		var q := int(tile.get("q", 0))
		var r := int(tile.get("r", 0))
		if _is_coastal_tile(q, r):
			var dist_center := _hex_distance(0, 0, q, r)
			if dist_center >= int(world_map_radius * 0.2) and dist_center <= int(world_map_radius * 0.75):
				coastal_candidates.append(tile)
	if coastal_candidates.is_empty():
		world_map_player_pos = {"q": 0, "r": 0}
		var fallback_key := _hex_key(0, 0)
		if world_map_tiles.has(fallback_key):
			world_map_tiles[fallback_key]["contains_village"] = true
			world_map_tiles[fallback_key]["poi_type"] = "player_village"
		return
	var selected: Dictionary = coastal_candidates[rng.randi_range(0, coastal_candidates.size() - 1)]
	var vq: int = int(selected.get("q", 0))
	var vr: int = int(selected.get("r", 0))
	var village_key: String = _hex_key(vq, vr)
	world_map_player_pos = {"q": vq, "r": vr}
	world_map_tiles[village_key]["contains_village"] = true
	world_map_tiles[village_key]["poi_type"] = "player_village"

func _place_dungeons_on_map(rng: RandomNumberGenerator) -> void:
	var candidates: Array[Dictionary] = []
	var vq: int = int(world_map_player_pos.get("q", 0))
	var vr: int = int(world_map_player_pos.get("r", 0))
	for key in world_map_tiles.keys():
		var tile: Dictionary = world_map_tiles[key]
		if bool(tile.get("contains_village", false)):
			continue
		if not String(tile.get("poi_type", "")).is_empty():
			continue
		var terrain: String = String(tile.get("terrain_type", "ova"))
		if terrain == "deniz":
			continue
		var dist: int = _hex_distance(vq, vr, int(tile.get("q", 0)), int(tile.get("r", 0)))
		if dist < MIN_DUNGEON_DISTANCE_FROM_VILLAGE:
			continue
		candidates.append(tile)
	var placed: Array[Dictionary] = []
	var limit: int = mini(TARGET_DUNGEON_COUNT, candidates.size())
	while placed.size() < limit and not candidates.is_empty():
		var idx: int = rng.randi_range(0, candidates.size() - 1)
		var selected: Dictionary = candidates[idx]
		candidates.remove_at(idx)
		var q: int = int(selected.get("q", 0))
		var r: int = int(selected.get("r", 0))
		var is_far_enough: bool = true
		for prev in placed:
			if _hex_distance(q, r, int(prev.get("q", 0)), int(prev.get("r", 0))) < int(world_map_radius * 0.28):
				is_far_enough = false
				break
		if not is_far_enough:
			continue
		var key: String = _hex_key(q, r)
		if world_map_tiles.has(key):
			world_map_tiles[key]["poi_type"] = "dungeon"
			placed.append({"q": q, "r": r})

func _generate_rivers_and_bridges(rng: RandomNumberGenerator) -> void:
	var mountain_sources: Array[Dictionary] = []
	for key in world_map_tiles.keys():
		var tile: Dictionary = world_map_tiles[key]
		if String(tile.get("terrain_type", "")) == "dag":
			mountain_sources.append(tile)
	# Daha fazla nehir + daha gevsek kaynak mesafesi -> daha cok catal / birlesme.
	var river_count: int = clampi(int(world_map_radius / 5.2), 6, 14)
	var min_sep_from_existing: int = maxi(3, int(world_map_radius * 0.082))
	var rivers_created: int = 0
	for spacing_pass in range(3):
		if rivers_created >= river_count:
			break
		var spacing_strict: bool = (spacing_pass == 0)
		var spacing_medium: bool = (spacing_pass == 1)
		mountain_sources.shuffle()
		for source in mountain_sources:
			if rivers_created >= river_count:
				break
			var sq: int = int(source.get("q", 0))
			var sr: int = int(source.get("r", 0))
			if rivers_created > 0:
				var d_ak: int = _min_hex_distance_to_any_akarsu(sq, sr)
				var need_sep: int = min_sep_from_existing
				if spacing_medium:
					need_sep = maxi(2, min_sep_from_existing - 3)
				elif not spacing_strict:
					need_sep = maxi(1, min_sep_from_existing - 5)
				if d_ak < need_sep:
					continue
			if _carve_single_river(sq, sr, rng):
				rivers_created += 1
	_stitch_disconnected_akarsu_network()
	_place_bridges_on_rivers(rng)

func _akarsu_stitch_step_allowed(tile: Dictionary) -> bool:
	var t: String = String(tile.get("terrain_type", "ova"))
	return t == "ova" or t == "orman" or t == "akarsu"

func _sample_keys_sparse(keys: Array, limit: int) -> Array[String]:
	var out: Array[String] = []
	if keys.size() <= limit:
		for k in keys:
			out.append(String(k))
		return out
	var step: int = maxi(1, keys.size() / limit)
	var i: int = 0
	while i < keys.size() and out.size() < limit:
		out.append(String(keys[i]))
		i += step
	return out

func _reconstruct_stitch_key_path(came_from: Dictionary, end_key: String) -> Array[String]:
	var out: Array[String] = []
	var k: String = end_key
	out.append(k)
	while came_from.has(k):
		k = String(came_from[k])
		out.append(k)
	out.reverse()
	return out

func _bfs_akarsu_stitch_path(from_key: String, to_key: String) -> Array[String]:
	if from_key == to_key:
		return [from_key]
	var queue: Array[String] = []
	queue.append(from_key)
	var qi: int = 0
	var came_from: Dictionary = {}
	var visited: Dictionary = {from_key: true}
	while qi < queue.size():
		var cur: String = queue[qi]
		qi += 1
		if cur == to_key:
			return _reconstruct_stitch_key_path(came_from, to_key)
		var cq: int = int(_coords_from_key(cur).get("q", 0))
		var cr: int = int(_coords_from_key(cur).get("r", 0))
		for nb in _get_hex_neighbors(cq, cr):
			var nk: String = _hex_key(int(nb.get("q", 0)), int(nb.get("r", 0)))
			if visited.has(nk):
				continue
			if not world_map_tiles.has(nk):
				continue
			var n_tile: Dictionary = world_map_tiles[nk]
			if not _akarsu_stitch_step_allowed(n_tile):
				continue
			visited[nk] = true
			came_from[nk] = cur
			queue.append(nk)
	return []

func _akarsu_connected_components() -> Array:
	var visited: Dictionary = {}
	var comps: Array = []
	for key in world_map_tiles.keys():
		var tile: Dictionary = world_map_tiles[key]
		if String(tile.get("terrain_type", "")) != "akarsu":
			continue
		if visited.has(key):
			continue
		var comp: Array[String] = []
		var queue: Array[String] = [key]
		visited[key] = true
		var head: int = 0
		while head < queue.size():
			var ck: String = queue[head]
			head += 1
			comp.append(ck)
			var cq: int = int(_coords_from_key(ck).get("q", 0))
			var cr: int = int(_coords_from_key(ck).get("r", 0))
			for nb in _get_hex_neighbors(cq, cr):
				var nk: String = _hex_key(int(nb.get("q", 0)), int(nb.get("r", 0)))
				if visited.has(nk):
					continue
				if not world_map_tiles.has(nk):
					continue
				var nt: Dictionary = world_map_tiles[nk]
				if String(nt.get("terrain_type", "")) != "akarsu":
					continue
				visited[nk] = true
				queue.append(nk)
		comps.append(comp)
	return comps

func _apply_akarsu_stitch_path(path_keys: Array[String]) -> void:
	for k in path_keys:
		if not world_map_tiles.has(k):
			continue
		var tile: Dictionary = world_map_tiles[k]
		var t: String = String(tile.get("terrain_type", ""))
		if t == "ova" or t == "orman":
			tile["terrain_type"] = "akarsu"
			world_map_tiles[k] = tile

func _stitch_disconnected_akarsu_network() -> void:
	var max_iterations: int = 32
	var pair_failures: int = 0
	const SAMPLE_PAIRS: int = 14
	const MAX_PAIR_DIST: int = 8
	for _iter in range(max_iterations):
		var comps: Array = _akarsu_connected_components()
		if comps.size() <= 1:
			break
		var best_d: int = 9999
		var best_a: String = ""
		var best_b: String = ""
		for i in range(comps.size()):
			for j in range(i + 1, comps.size()):
				var sa: Array[String] = _sample_keys_sparse(comps[i], SAMPLE_PAIRS)
				var sb: Array[String] = _sample_keys_sparse(comps[j], SAMPLE_PAIRS)
				for ka in sa:
					var ca: Dictionary = _coords_from_key(ka)
					var cqa: int = int(ca.get("q", 0))
					var cra: int = int(ca.get("r", 0))
					for kb in sb:
						var cb: Dictionary = _coords_from_key(kb)
						var d: int = _hex_distance(cqa, cra, int(cb.get("q", 0)), int(cb.get("r", 0)))
						if d < best_d:
							best_d = d
							best_a = ka
							best_b = kb
		if best_a.is_empty() or best_b.is_empty() or best_d > MAX_PAIR_DIST:
			break
		var path: Array[String] = _bfs_akarsu_stitch_path(best_a, best_b)
		if path.is_empty():
			pair_failures += 1
			if pair_failures >= 8:
				break
			continue
		pair_failures = 0
		_apply_akarsu_stitch_path(path)

func _carve_single_river(start_q: int, start_r: int, rng: RandomNumberGenerator) -> bool:
	var current_q: int = start_q
	var current_r: int = start_r
	var visited: Dictionary = {}
	var carved: int = 0
	var max_steps: int = maxi(12, int(world_map_radius * 2.2))
	while carved < max_steps:
		var key: String = _hex_key(current_q, current_r)
		if not world_map_tiles.has(key):
			break
		var tile: Dictionary = world_map_tiles[key]
		var terrain: String = String(tile.get("terrain_type", "ova"))
		if terrain == "deniz":
			return carved >= 6
		if terrain != "dag":
			tile["terrain_type"] = "akarsu"
			world_map_tiles[key] = tile
			carved += 1
		visited[key] = true
		var neighbors: Array[Dictionary] = _get_hex_neighbors(current_q, current_r)
		neighbors.shuffle()
		var best_next: Dictionary = {}
		var best_score: float = 99999.0
		for n in neighbors:
			var nq: int = int(n.get("q", 0))
			var nr: int = int(n.get("r", 0))
			var nkey: String = _hex_key(nq, nr)
			if not world_map_tiles.has(nkey):
				continue
			if visited.has(nkey):
				continue
			var n_tile: Dictionary = world_map_tiles[nkey]
			var n_terrain: String = String(n_tile.get("terrain_type", "ova"))
			var dist_to_edge: int = world_map_radius - _hex_distance(0, 0, nq, nr)
			var score: float = float(dist_to_edge)
			if n_terrain == "deniz":
				score -= 14.0
			elif n_terrain == "dag":
				score += 4.0
			var ak_deg: int = _count_akarsu_neighbor_tiles(nq, nr)
			score += float(ak_deg) * 1.85
			if n_terrain == "akarsu":
				score += 1.55
				if rng.randf() < 0.3:
					score -= 3.8
			elif n_terrain == "ova":
				score -= 0.75
			score += rng.randf_range(-2.85, 2.85)
			if score < best_score:
				best_score = score
				best_next = {"q": nq, "r": nr}
		if best_next.is_empty():
			break
		current_q = int(best_next.get("q", current_q))
		current_r = int(best_next.get("r", current_r))
	return false

func _place_bridges_on_rivers(rng: RandomNumberGenerator) -> void:
	var bridge_candidates: Array[String] = []
	for key in world_map_tiles.keys():
		var tile: Dictionary = world_map_tiles[key]
		if String(tile.get("terrain_type", "")) != "akarsu":
			continue
		var q: int = int(tile.get("q", 0))
		var r: int = int(tile.get("r", 0))
		var land_neighbors := 0
		for n in _get_hex_neighbors(q, r):
			var nk := _hex_key(int(n.get("q", 0)), int(n.get("r", 0)))
			if world_map_tiles.has(nk):
				var nt: Dictionary = world_map_tiles[nk]
				if String(nt.get("terrain_type", "")) != "akarsu" and String(nt.get("terrain_type", "")) != "deniz":
					land_neighbors += 1
		if land_neighbors >= 3:
			bridge_candidates.append(key)
	bridge_candidates.shuffle()
	var placed: int = 0
	for key in bridge_candidates:
		if placed >= TARGET_BRIDGE_COUNT:
			break
		var tile: Dictionary = world_map_tiles[key]
		if String(tile.get("poi_type", "")).is_empty():
			tile["travel_feature"] = "kopru"
			world_map_tiles[key] = tile
			placed += 1

func _get_hex_neighbors(q: int, r: int) -> Array[Dictionary]:
	return [
		{"q": q + 1, "r": r},
		{"q": q - 1, "r": r},
		{"q": q, "r": r + 1},
		{"q": q, "r": r - 1},
		{"q": q + 1, "r": r - 1},
		{"q": q - 1, "r": r + 1}
	]

func _process(_delta: float) -> void:
	# Saat bazlı saldırı kontrolü için her frame kontrol et
	if dynamic_world_enabled:
		_check_pending_attacks()

func _rel_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

func _on_time_advanced(total_minutes: int, start_day: int, start_hour: int, start_minute: int) -> void:
	if not dynamic_world_enabled:
		return
	var tm = get_node_or_null("/root/TimeManager")
	if not tm:
		return
	var end_day: int = start_day
	var end_hour: int = start_hour
	if tm.has_method("get_day"):
		end_day = tm.get_day()
	if tm.has_method("get_hour"):
		end_hour = tm.get_hour()
	var minutes_per_hour: int = 60
	var hours_per_day: int = 24
	if "MINUTES_PER_HOUR" in tm:
		minutes_per_hour = tm.MINUTES_PER_HOUR
	if "HOURS_PER_DAY" in tm:
		hours_per_day = tm.HOURS_PER_DAY
	var current_day: int = start_day
	var current_hour: int = start_hour
	var current_minute: int = start_minute
	var minutes_processed: int = 0
	while minutes_processed < total_minutes:
		current_minute += 1
		minutes_processed += 1
		if current_minute >= minutes_per_hour:
			current_minute = 0
			current_hour += 1
			if current_hour >= hours_per_day:
				current_hour = 0
				current_day += 1
				if current_day <= end_day:
					_simulate_day(current_day)
					_apply_world_events_to_village(current_day)
		if current_day < end_day or (current_day == end_day and current_hour < end_hour):
			_check_pending_attacks_during_skip(current_day, current_hour)

func _check_pending_attacks_during_skip(day: int, hour: int) -> void:
	var remaining_attacks: Array[Dictionary] = []
	for attack in pending_attacks:
		var attack_day = attack.get("attack_day", day)
		var attack_hour: float = float(attack.get("attack_hour", 0.0))
		var deploy_time = attack_hour - 3.0
		var deploy_day = attack_day
		if deploy_time < 0.0:
			deploy_time += 24.0
			deploy_day -= 1
		var deployed: bool = bool(attack.get("deployed", false))
		if not deployed:
			if day > deploy_day or (day == deploy_day and float(hour) >= deploy_time):
				defense_deployment_started.emit(attack_day)
				attack["deployed"] = true
		var attack_time_reached = false
		if day > attack_day or (day == attack_day and float(hour) >= attack_hour):
			attack_time_reached = true
		if attack_time_reached:
			var attacker = attack.get("attacker", "Bilinmeyen")
			var d_count2: int = int(attack.get("defender_count", 1 if bool(attack.get("defender_intervention", false)) else 0))
			_execute_village_defense(attacker, day, d_count2 > 0, d_count2)
		else:
			remaining_attacks.append(attack)
	pending_attacks = remaining_attacks

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
	_simulate_neighbor_settlements(day)
	_simulate_settlement_diplomacy(day)
	_simulate_settlement_trade_flows(day)
	_simulate_event_chains(day)
	_simulate_settlement_migrations(day)
	_simulate_player_alliances(day)

	# Rastgele olay başlatma şansı
	if randf() < 0.1:  # %10 şans
		var event_type = _get_random_event_type()
		var faction = factions[randi() % factions.size()]
		if faction != "Köy":  # Köy kendine olay başlatmasın
			var event = _create_event(event_type, faction, day)
			active_events.append(event)
			_post_event_news(event, day)
	
	# Köy saldırıları kontrolü (yeni saldırı tetikleme)
	_check_village_attacks(day)
	
	# Aktif olayları güncelle
	_update_active_events(day)
	# Not: Zamanlanmış saldırılar _process() içinde saat bazlı kontrol ediliyor

func _simulate_neighbor_settlements(day: int) -> void:
	if world_map_settlement_positions.is_empty():
		return
	_initialize_world_settlement_states()
	var role_mods: Dictionary = _get_living_world_role_modifiers()
	_resolve_expired_settlement_incidents(day, role_mods)
	for settlement_id in world_map_settlement_positions.keys():
		if not world_settlement_states.has(settlement_id):
			continue
		var state: Dictionary = world_settlement_states[settlement_id]
		state["last_updated_day"] = day
		var population: int = int(state.get("population", 80))
		var food_stock: int = int(state.get("food_stock", 100))
		var security: int = int(state.get("security", 60))
		var stability: int = int(state.get("stability", 60))

		food_stock += randi_range(-8, 10)
		food_stock += int(role_mods.get("food_drift_bonus", 0))
		security += int(role_mods.get("security_recovery_bonus", 0))
		stability += int(role_mods.get("stability_recovery_bonus", 0))
		if food_stock < 45:
			stability -= randi_range(1, 4)
			security -= randi_range(0, 2)
		if security < 38:
			stability -= randi_range(1, 3)
		if stability < 35 and randf() < 0.35:
			population = max(25, population - randi_range(1, 4))

		food_stock = clamp(food_stock, 0, 260)
		security = clamp(security, 10, 100)
		stability = clamp(stability, 5, 100)
		population = clamp(population, 20, 240)

		var incident_chance: float = 0.09
		if food_stock < 55:
			incident_chance += 0.05
		if security < 40:
			incident_chance += 0.04
		if world_settlement_incidents.size() >= MAX_ACTIVE_SETTLEMENT_INCIDENTS:
			incident_chance = 0.0
		if _has_active_incident_for_settlement(String(settlement_id)):
			incident_chance = 0.0

		state["population"] = population
		state["food_stock"] = food_stock
		state["security"] = security
		state["stability"] = stability
		state["crisis_pressure"] = clampf((100.0 - float(security) + 100.0 - float(stability)) / 200.0, 0.0, 1.0)
		world_settlement_states[settlement_id] = state

		if incident_chance > 0.0 and randf() < incident_chance:
			var incident: Dictionary = _create_settlement_incident(String(settlement_id), day, role_mods)
			if not incident.is_empty():
				world_settlement_incidents.append(incident)
				_apply_settlement_incident_start_effects(incident)
				_post_settlement_incident_news(incident, role_mods)
				_try_offer_relief_mission_for_incident(incident)

func _has_active_incident_for_settlement(settlement_id: String) -> bool:
	var active_count: int = 0
	for incident in world_settlement_incidents:
		if String(incident.get("settlement_id", "")) != settlement_id:
			continue
		if bool(incident.get("resolved", false)):
			continue
		active_count += 1
	return active_count >= MAX_INCIDENTS_PER_SETTLEMENT

func _create_settlement_incident(settlement_id: String, day: int, role_mods: Dictionary = {}) -> Dictionary:
	if not world_settlement_states.has(settlement_id):
		return {}
	var state: Dictionary = world_settlement_states[settlement_id]
	var severity: float = clampf(0.6 + randf() * 0.9 + float(state.get("crisis_pressure", 0.0)), 0.5, 2.0)
	var incident_type: String = "wolf_attack"
	var roll: float = randf()
	if roll < 0.26:
		incident_type = "wolf_attack"
	elif roll < 0.50:
		incident_type = "harvest_failure"
	elif roll < 0.68:
		incident_type = "migrant_wave"
	elif roll < 0.82:
		incident_type = "bandit_road"
	else:
		incident_type = "plague_scare"
	var duration: int = randi_range(2, 4)
	# Komutan: kurt baskini siddetini azaltir
	if incident_type == "wolf_attack":
		severity = clampf(severity * float(role_mods.get("wolf_severity_mult", 1.0)), 0.4, 2.0)
	if incident_type == "harvest_failure":
		severity = clampf(severity * float(role_mods.get("harvest_failure_severity_mult", 1.0)), 0.35, 2.0)
	if incident_type == "plague_scare":
		severity = clampf(severity * float(role_mods.get("plague_scare_severity_mult", 1.0)), 0.35, 2.0)
	# Diplomat: kriz suresini kisaltir
	var duration_mult: float = float(role_mods.get("incident_duration_mult", 1.0))
	if duration_mult < 1.0:
		duration = max(1, int(round(float(duration) * duration_mult)))
	return {
		"id": "%s_%d_%d" % [settlement_id, day, randi_range(10, 999)],
		"settlement_id": settlement_id,
		"settlement_name": String(state.get("name", settlement_id)),
		"type": incident_type,
		"severity": severity,
		"started_day": day,
		"duration": duration,
		"resolved": false
	}

func _apply_settlement_incident_start_effects(incident: Dictionary) -> void:
	var settlement_id: String = String(incident.get("settlement_id", ""))
	if settlement_id.is_empty() or not world_settlement_states.has(settlement_id):
		return
	var state: Dictionary = world_settlement_states[settlement_id]
	var severity: float = float(incident.get("severity", 1.0))
	var incident_type: String = String(incident.get("type", "wolf_attack"))
	var lw_mods: Dictionary = _get_living_world_role_modifiers()
	var plague_pop_mult: float = float(lw_mods.get("plague_population_loss_mult", 1.0))
	match incident_type:
		"wolf_attack":
			state["security"] = clamp(int(state.get("security", 60)) - int(round(8.0 * severity)), 5, 100)
			state["food_stock"] = clamp(int(state.get("food_stock", 100)) - int(round(12.0 * severity)), 0, 260)
		"harvest_failure":
			state["food_stock"] = clamp(int(state.get("food_stock", 100)) - int(round(20.0 * severity)), 0, 260)
			state["stability"] = clamp(int(state.get("stability", 60)) - int(round(5.0 * severity)), 5, 100)
		"migrant_wave":
			state["population"] = clamp(int(state.get("population", 80)) + int(round(8.0 * severity)), 20, 260)
			state["food_stock"] = clamp(int(state.get("food_stock", 100)) - int(round(10.0 * severity)), 0, 260)
			state["stability"] = clamp(int(state.get("stability", 60)) - int(round(3.0 * severity)), 5, 100)
		"bandit_road":
			state["security"] = clamp(int(state.get("security", 60)) - int(round(7.0 * severity)), 5, 100)
			state["food_stock"] = clamp(int(state.get("food_stock", 100)) - int(round(8.0 * severity)), 0, 260)
		"plague_scare":
			state["stability"] = clamp(int(state.get("stability", 60)) - int(round(6.0 * severity)), 5, 100)
			state["population"] = clamp(int(state.get("population", 80)) - int(round(2.0 * severity * plague_pop_mult)), 20, 260)
		_:
			pass
	world_settlement_states[settlement_id] = state

func _simulate_settlement_trade_flows(day: int) -> void:
	if world_settlement_states.size() < 2:
		return
	var attempts: int = 1
	if randf() < 0.55:
		attempts = 2
	for _i in range(attempts):
		var pair: Dictionary = _pick_trade_pair()
		if pair.is_empty():
			continue
		var sender_id: String = String(pair.get("sender", ""))
		var receiver_id: String = String(pair.get("receiver", ""))
		var resource: String = String(pair.get("resource", ""))
		if sender_id.is_empty() or receiver_id.is_empty() or resource.is_empty():
			continue
		_resolve_trade_convoy(day, sender_id, receiver_id, resource)

func _pick_trade_pair() -> Dictionary:
	var ids: Array = world_settlement_states.keys()
	if ids.size() < 2:
		return {}
	ids.shuffle()
	for sender_id in ids:
		var sender_state: Dictionary = world_settlement_states[sender_id]
		var sender_economy: Dictionary = sender_state.get("economy_profile", {})
		var sender_produces: Array = sender_economy.get("produces", [])
		if sender_produces.is_empty():
			continue
		var resource: String = String(sender_produces[randi() % sender_produces.size()])
		for receiver_id in ids:
			if receiver_id == sender_id:
				continue
			var receiver_state: Dictionary = world_settlement_states[receiver_id]
			var receiver_economy: Dictionary = receiver_state.get("economy_profile", {})
			var receiver_scarce: Array = receiver_economy.get("scarce", [])
			if not (resource in receiver_scarce):
				continue
			# Oyuncuya dusmanca koyler konvoy ticaretine katilmaz (harita ekonomisi soyut).
			if is_settlement_hostile_to_player(String(sender_id)) or is_settlement_hostile_to_player(String(receiver_id)):
				continue
			# Acik savasta ticaret bloklanir.
			var diplo: Dictionary = get_settlement_diplomacy_state(String(sender_id), String(receiver_id))
			if String(diplo.get("state", "")) == DIPLOMACY_STATE_OPEN_WAR:
				continue
			return {
				"sender": String(sender_id),
				"receiver": String(receiver_id),
				"resource": resource
			}
	return {}

func _resolve_trade_convoy(day: int, sender_id: String, receiver_id: String, resource: String) -> void:
	if not world_settlement_states.has(sender_id) or not world_settlement_states.has(receiver_id):
		return
	var sender_pos: Dictionary = world_map_settlement_positions.get(sender_id, {})
	var receiver_pos: Dictionary = world_map_settlement_positions.get(receiver_id, {})
	if sender_pos.is_empty() or receiver_pos.is_empty():
		return
	var distance: int = _hex_distance(
		int(sender_pos.get("q", 0)),
		int(sender_pos.get("r", 0)),
		int(receiver_pos.get("q", 0)),
		int(receiver_pos.get("r", 0))
	)
	var sender_state: Dictionary = world_settlement_states[sender_id]
	var receiver_state: Dictionary = world_settlement_states[receiver_id]
	var sender_security: int = int(sender_state.get("security", 60))
	var receiver_security: int = int(receiver_state.get("security", 60))
	var avg_security: float = (float(sender_security) + float(receiver_security)) * 0.5
	var success_chance: float = clampf(0.92 - 0.025 * float(distance) - (60.0 - avg_security) * 0.004, 0.35, 0.97)
	# Komsu krizleri konvoy guvenligini etkiler.
	var sender_incident: Dictionary = get_active_settlement_incident(sender_id)
	var receiver_incident: Dictionary = get_active_settlement_incident(receiver_id)
	if String(sender_incident.get("type", "")) == "wolf_attack":
		success_chance -= 0.18
	if String(receiver_incident.get("type", "")) == "wolf_attack":
		success_chance -= 0.10
	# Diplomasi durumu konvoy guvenligini etkiler.
	var diplo_state_dict: Dictionary = get_settlement_diplomacy_state(sender_id, receiver_id)
	match String(diplo_state_dict.get("state", "")):
		DIPLOMACY_STATE_TENSION:
			success_chance -= 0.08
		DIPLOMACY_STATE_COLD_WAR:
			success_chance -= 0.18
		DIPLOMACY_STATE_CEASEFIRE:
			success_chance -= 0.05
		_:
			pass
	success_chance = clampf(success_chance, 0.15, 0.97)
	var sender_name: String = String(sender_state.get("name", sender_id))
	var receiver_name: String = String(receiver_state.get("name", receiver_id))
	var sender_discovered: bool = _is_settlement_discovered_for_news(sender_id)
	var receiver_discovered: bool = _is_settlement_discovered_for_news(receiver_id)
	if randf() < success_chance:
		_apply_trade_convoy_success(sender_id, receiver_id, resource)
		_post_trade_convoy_news(day, sender_name, receiver_name, resource, true, sender_discovered or receiver_discovered)
	else:
		_apply_trade_convoy_failure(sender_id, receiver_id, resource)
		_post_trade_convoy_news(day, sender_name, receiver_name, resource, false, sender_discovered or receiver_discovered)

func _apply_trade_convoy_success(sender_id: String, receiver_id: String, resource: String) -> void:
	var sender_state: Dictionary = world_settlement_states[sender_id]
	var receiver_state: Dictionary = world_settlement_states[receiver_id]
	if resource == "food":
		sender_state["food_stock"] = clamp(int(sender_state.get("food_stock", 100)) - randi_range(8, 14), 0, 260)
		receiver_state["food_stock"] = clamp(int(receiver_state.get("food_stock", 100)) + randi_range(8, 14), 0, 260)
	receiver_state["stability"] = clamp(int(receiver_state.get("stability", 60)) + randi_range(0, 2), 5, 100)
	world_settlement_states[sender_id] = sender_state
	world_settlement_states[receiver_id] = receiver_state
	change_settlement_relation(sender_id, receiver_id, 1)

func _apply_trade_convoy_failure(sender_id: String, receiver_id: String, resource: String) -> void:
	var sender_state: Dictionary = world_settlement_states[sender_id]
	var receiver_state: Dictionary = world_settlement_states[receiver_id]
	if resource == "food":
		sender_state["food_stock"] = clamp(int(sender_state.get("food_stock", 100)) - randi_range(6, 12), 0, 260)
	receiver_state["stability"] = clamp(int(receiver_state.get("stability", 60)) - randi_range(1, 3), 5, 100)
	world_settlement_states[sender_id] = sender_state
	world_settlement_states[receiver_id] = receiver_state
	# Yagmalanan konvoy iliskiyi az da olsa zedeler.
	change_settlement_relation(sender_id, receiver_id, -1)

func _post_trade_convoy_news(day: int, sender_name: String, receiver_name: String, resource: String, success: bool, allow_full_news: bool) -> void:
	if not allow_full_news and randf() > 0.20:
		return
	var resource_label: String = resource
	match resource:
		"food":
			resource_label = "erzak"
		"wood":
			resource_label = "odun"
		"stone":
			resource_label = "tas"
		"water":
			resource_label = "su"
		_:
			resource_label = resource
	var title: String = ""
	var content: String = ""
	var subcategory: String = "info"
	if success:
		title = "Konvoy Ulasti"
		content = "%s'tan %s'a %s konvoyu basariyla ulasti." % [sender_name, receiver_name, resource_label]
		subcategory = "success"
	else:
		title = "Konvoy Yagmalandi"
		content = "%s'tan %s'a giden %s konvoyu yolda kayboldu." % [sender_name, receiver_name, resource_label]
		subcategory = "warning"
	if not allow_full_news:
		content = "Duyum: " + content
	_post_world_news({
		"category": "world",
		"subcategory": subcategory,
		"title": title,
		"content": content,
		"day": day
	})

func _resolve_expired_settlement_incidents(day: int, role_mods: Dictionary = {}) -> void:
	var remaining: Array[Dictionary] = []
	var bonus_security: int = int(role_mods.get("post_incident_security_bonus", 0))
	var bonus_stability: int = int(role_mods.get("post_incident_stability_bonus", 0))
	for incident in world_settlement_incidents:
		var started_day: int = int(incident.get("started_day", day))
		var duration: int = int(incident.get("duration", 0))
		var settlement_id: String = String(incident.get("settlement_id", ""))
		if day - started_day < duration:
			remaining.append(incident)
			continue
		if world_settlement_states.has(settlement_id):
			var state: Dictionary = world_settlement_states[settlement_id]
			var incident_type: String = String(incident.get("type", ""))
			match incident_type:
				"wolf_attack":
					state["security"] = clamp(int(state.get("security", 60)) + randi_range(3, 8) + bonus_security, 5, 100)
				"harvest_failure":
					state["stability"] = clamp(int(state.get("stability", 60)) + randi_range(2, 6) + bonus_stability, 5, 100)
				"migrant_wave":
					state["stability"] = clamp(int(state.get("stability", 60)) + randi_range(2, 5) + bonus_stability, 5, 100)
				"bandit_road":
					state["security"] = clamp(int(state.get("security", 60)) + randi_range(2, 7) + bonus_security, 5, 100)
				"plague_scare":
					state["stability"] = clamp(int(state.get("stability", 60)) + randi_range(3, 7) + bonus_stability, 5, 100)
					state["population"] = clamp(int(state.get("population", 80)) + randi_range(0, 2), 20, 260)
				_:
					pass
			world_settlement_states[settlement_id] = state
		_post_settlement_incident_end_news(incident)
		_try_seed_event_chain_from_incident(incident, day)
	world_settlement_incidents = remaining

func _post_settlement_incident_news(incident: Dictionary, role_mods: Dictionary = {}) -> void:
	var settlement_id: String = String(incident.get("settlement_id", ""))
	var settlement_name: String = String(incident.get("settlement_name", "Komsu Koy"))
	var incident_type: String = String(incident.get("type", "wolf_attack"))
	var duration: int = int(incident.get("duration", 0))
	var discovered: bool = _is_settlement_discovered_for_news(settlement_id)
	var undiscovered_news_chance: float = float(role_mods.get("undiscovered_news_chance", 0.30))
	if not discovered and randf() > undiscovered_news_chance:
		return
	var title: String = "Komsu Koy Krizi"
	var content: String = ""
	match incident_type:
		"wolf_attack":
			title = "Kurt Baskini"
			content = "%s cevresinde kurt suruleri goruldu. Guvenlik zayifladi. (~%d gun)" % [settlement_name, duration]
		"harvest_failure":
			title = "Hasat Basarisizligi"
			content = "%s bolgesinde hasat dusuk. Erzak sikintisi buyuyor. (~%d gun)" % [settlement_name, duration]
		"migrant_wave":
			title = "Goc Dalgasi"
			content = "%s yeni gocmenler aliyor. Nufus artisiyla duzen zorlanabilir. (~%d gun)" % [settlement_name, duration]
		"bandit_road":
			title = "Yol Haydutlari"
			content = "%s ana yollarinda haydut faaliyeti artti. (~%d gun)" % [settlement_name, duration]
		"plague_scare":
			title = "Hastalik Kaygisi"
			content = "%s civarinda salgin dedikodulari duzeni sarsiyor. (~%d gun)" % [settlement_name, duration]
		_:
			content = "%s civarinda beklenmedik bir kriz gelisiyor. (~%d gun)" % [settlement_name, duration]
	if not discovered:
		content = "Duyum: Uzak bir komsu koyde kriz haberi var. " + content
	_post_world_news({
		"category": "world",
		"subcategory": "warning",
		"title": title,
		"content": content,
		"day": int(incident.get("started_day", 0))
	})

func _post_settlement_incident_end_news(incident: Dictionary) -> void:
	var settlement_id: String = String(incident.get("settlement_id", ""))
	if not _is_settlement_discovered_for_news(settlement_id):
		return
	var settlement_name: String = String(incident.get("settlement_name", "Komsu Koy"))
	var incident_type: String = String(incident.get("type", ""))
	var title: String = "Kriz Sona Erdi"
	var content: String = "%s cevresindeki kriz yatisti." % settlement_name
	match incident_type:
		"wolf_attack":
			title = "Kurt Tehdidi Dagildi"
		"harvest_failure":
			title = "Hasat Toparlaniyor"
		"migrant_wave":
			title = "Goc Dalgasi Duruldu"
		_:
			pass
	_post_world_news({
		"category": "world",
		"subcategory": "success",
		"title": title,
		"content": content,
		"day": int(incident.get("started_day", 0)) + int(incident.get("duration", 0))
	})

func _is_settlement_discovered_for_news(settlement_id: String) -> bool:
	if settlement_id.is_empty():
		return false
	if not world_map_settlement_positions.has(settlement_id):
		return false
	return bool(world_map_settlement_positions[settlement_id].get("discovered", false))

func _get_settlement_incident_threat_bonus(q: int, r: int) -> float:
	if world_settlement_incidents.is_empty():
		return 0.0
	var bonus: float = 0.0
	for incident in world_settlement_incidents:
		var settlement_id: String = String(incident.get("settlement_id", ""))
		if settlement_id.is_empty() or not world_map_settlement_positions.has(settlement_id):
			continue
		var s_info: Dictionary = world_map_settlement_positions[settlement_id]
		var dist: int = _hex_distance(q, r, int(s_info.get("q", 0)), int(s_info.get("r", 0)))
		if dist > 4:
			continue
		var severity: float = float(incident.get("severity", 1.0))
		var incident_type: String = String(incident.get("type", ""))
		var type_weight: float = 1.0
		match incident_type:
			"wolf_attack":
				type_weight = 1.2
			"harvest_failure":
				type_weight = 0.9
			"migrant_wave":
				type_weight = 0.7
			"bandit_road":
				type_weight = 1.1
			"plague_scare":
				type_weight = 1.0
			_:
				type_weight = 1.0
		var proximity: float = clampf((5.0 - float(dist)) / 5.0, 0.0, 1.0)
		bonus += 0.02 * severity * type_weight * proximity
	return clampf(bonus, 0.0, 0.10)

func get_world_settlement_states() -> Dictionary:
	return world_settlement_states.duplicate(true)

func get_world_settlement_incidents() -> Array[Dictionary]:
	return world_settlement_incidents.duplicate(true)

func get_settlement_state(settlement_id: String) -> Dictionary:
	if settlement_id.is_empty() or not world_settlement_states.has(settlement_id):
		return {}
	return world_settlement_states[settlement_id].duplicate(true)

func get_active_settlement_incident(settlement_id: String) -> Dictionary:
	if settlement_id.is_empty():
		return {}
	for incident in world_settlement_incidents:
		if String(incident.get("settlement_id", "")) != settlement_id:
			continue
		if bool(incident.get("resolved", false)):
			continue
		return incident.duplicate(true)
	return {}

func get_settlement_incident_threat_bonus(q: int, r: int) -> float:
	return _get_settlement_incident_threat_bonus(q, r)

func _get_hostile_settlement_threat_bonus(q: int, r: int) -> float:
	# Oyuncuya dusman koylere yakin hex'lerde yol riski artar.
	# 4 hex menzil icinde (proximity ile yumusatilmis) ve relation ne kadar dusukse bonus o kadar yuksek.
	var hostiles: Array = get_player_hostile_settlements()
	if hostiles.is_empty():
		return 0.0
	var role_mods: Dictionary = _get_living_world_role_modifiers()
	var route_risk_mult: float = float(role_mods.get("hostile_route_risk_mult", 1.0))
	var bonus: float = 0.0
	for h in hostiles:
		if not (h is Dictionary):
			continue
		var sid: String = String(h.get("settlement_id", ""))
		if sid.is_empty() or not world_map_settlement_positions.has(sid):
			continue
		var s_info: Dictionary = world_map_settlement_positions[sid]
		var dist: int = _hex_distance(q, r, int(s_info.get("q", 0)), int(s_info.get("r", 0)))
		if dist > 4:
			continue
		var rel: int = int(h.get("relation", 0))
		# Relation -30 -> hafif, -100 -> agir.
		var severity: float = clampf((float(-rel) - 30.0) / 70.0, 0.0, 1.0)
		var proximity: float = clampf((5.0 - float(dist)) / 5.0, 0.0, 1.0)
		bonus += 0.025 * (0.4 + 0.6 * severity) * proximity
	bonus *= route_risk_mult
	return clampf(bonus, 0.0, 0.12)

func get_hostile_settlement_threat_bonus(q: int, r: int) -> float:
	return _get_hostile_settlement_threat_bonus(q, r)

func _get_top_cariye_skill_for_role(role_id: int, skill_id: int) -> int:
	var mm: Node = get_node_or_null("/root/MissionManager")
	if not mm or not mm.has_method("get_concubines_by_role"):
		return 0
	var arr = mm.call("get_concubines_by_role", role_id)
	if not (arr is Array) or arr.is_empty():
		return 0
	var best: int = 0
	for c in arr:
		if c == null:
			continue
		var s: int = 0
		if c.has_method("get_skill_level"):
			s = int(c.call("get_skill_level", skill_id))
		if s > best:
			best = s
	return best

func _get_living_world_role_modifiers() -> Dictionary:
	var mods: Dictionary = {
		"wolf_severity_mult": 1.0,
		"incident_duration_mult": 1.0,
		"security_recovery_bonus": 0,
		"stability_recovery_bonus": 0,
		"food_drift_bonus": 0,
		"undiscovered_news_chance": 0.30,
		"post_incident_security_bonus": 0,
		"post_incident_stability_bonus": 0,
		"hostile_attack_chance_mult": 1.0,
		"hostile_route_risk_mult": 1.0,
		"alliance_tribute_bonus": 0,
		"alliance_intel_radius_bonus": 0,
		"alliance_defense_chance_bonus": 0.0,
		"alliance_defense_range_bonus": 0,
		"harvest_failure_severity_mult": 1.0,
		"plague_scare_severity_mult": 1.0,
		"plague_population_loss_mult": 1.0
	}
	var komutan_skill: int = _get_top_cariye_skill_for_role(LW_ROLE_KOMUTAN, LW_SKILL_SAVAS)
	if komutan_skill > 0:
		var k_norm: float = clampf(float(komutan_skill) / 100.0, 0.0, 1.0)
		mods["wolf_severity_mult"] = clampf(1.0 - 0.30 * k_norm, 0.55, 1.0)
		mods["security_recovery_bonus"] = int(round(1.0 + 2.0 * k_norm))
		mods["post_incident_security_bonus"] = int(round(1.0 + 3.0 * k_norm))
		# Komutan dusman koy saldirilarini ve yol riskini azaltir.
		mods["hostile_attack_chance_mult"] = clampf(1.0 - 0.40 * k_norm, 0.5, 1.0)
		mods["hostile_route_risk_mult"] = clampf(1.0 - 0.30 * k_norm, 0.6, 1.0)
		# Komutan muttefik defans koordinasyonunu iyilestirir.
		mods["alliance_defense_chance_bonus"] = 0.20 * k_norm
		mods["alliance_defense_range_bonus"] = int(round(2.0 * k_norm))
	var diplomat_skill: int = _get_top_cariye_skill_for_role(LW_ROLE_DIPLOMAT, LW_SKILL_DIPLOMASI)
	if diplomat_skill > 0:
		var d_norm: float = clampf(float(diplomat_skill) / 100.0, 0.0, 1.0)
		mods["incident_duration_mult"] = clampf(1.0 - 0.30 * d_norm, 0.6, 1.0)
		mods["stability_recovery_bonus"] = int(round(1.0 + 2.0 * d_norm))
		mods["post_incident_stability_bonus"] = int(round(1.0 + 3.0 * d_norm))
	var ajan_skill: int = _get_top_cariye_skill_for_role(LW_ROLE_AJAN, LW_SKILL_KESIF)
	if ajan_skill > 0:
		var a_norm: float = clampf(float(ajan_skill) / 100.0, 0.0, 1.0)
		mods["undiscovered_news_chance"] = clampf(0.30 + 0.55 * a_norm, 0.30, 0.90)
		# Ajan ittifak istihbarat menzilini +1 ile +2 arttirir.
		mods["alliance_intel_radius_bonus"] = int(round(1.0 + 1.0 * a_norm))
	var tuccar_skill: int = _get_top_cariye_skill_for_role(LW_ROLE_TUCCAR, LW_SKILL_TICARET)
	if tuccar_skill > 0:
		var t_norm: float = clampf(float(tuccar_skill) / 100.0, 0.0, 1.0)
		mods["food_drift_bonus"] = int(round(1.0 + 3.0 * t_norm))
		# Tuccar tribute miktarini +1 ile +3 altin arttirir.
		mods["alliance_tribute_bonus"] = int(round(1.0 + 2.0 * t_norm))
	var alim_skill: int = _get_top_cariye_skill_for_role(LW_ROLE_ALIM, LW_SKILL_BUROKRASI)
	if alim_skill > 0:
		var al_norm: float = clampf(float(alim_skill) / 100.0, 0.0, 1.0)
		mods["harvest_failure_severity_mult"] = clampf(1.0 - 0.30 * al_norm, 0.52, 1.0)
		mods["plague_scare_severity_mult"] *= clampf(1.0 - 0.18 * al_norm, 0.78, 1.0)
	var tibb_skill: int = _get_top_cariye_skill_for_role(LW_ROLE_TIBBIYECI, LW_SKILL_DIPLOMASI)
	if tibb_skill > 0:
		var tb_norm: float = clampf(float(tibb_skill) / 100.0, 0.0, 1.0)
		mods["plague_scare_severity_mult"] *= clampf(1.0 - 0.28 * tb_norm, 0.62, 1.0)
		mods["plague_population_loss_mult"] = clampf(1.0 - 0.45 * tb_norm, 0.42, 1.0)
	return mods

func get_living_world_role_modifiers() -> Dictionary:
	return _get_living_world_role_modifiers().duplicate(true)

# === Inter-settlement relations (Faz 3 temeli) ===
# Komsu koyler arasi diplomasi/savas/ittifak icin temel altyapi.

func _settlement_rel_key(a: String, b: String) -> String:
	if a == b:
		return a
	return a + "|" + b if a < b else b + "|" + a

func get_settlement_relation(a: String, b: String) -> int:
	if a.is_empty() or b.is_empty() or a == b:
		return 0
	return int(world_settlement_relations.get(_settlement_rel_key(a, b), 0))

func set_settlement_relation(a: String, b: String, value: int) -> void:
	if a.is_empty() or b.is_empty() or a == b:
		return
	var key: String = _settlement_rel_key(a, b)
	world_settlement_relations[key] = clampi(value, -100, 100)

func change_settlement_relation(a: String, b: String, delta: int) -> void:
	set_settlement_relation(a, b, get_settlement_relation(a, b) + delta)

func get_settlement_stance(a: String, b: String) -> String:
	var v: int = get_settlement_relation(a, b)
	if v >= 40:
		return "muttefik"
	if v <= -40:
		return "dusman"
	if v <= -15:
		return "gergin"
	return "tarafsiz"

func get_world_settlement_relations() -> Dictionary:
	return world_settlement_relations.duplicate(true)

# === Event Chain Framework (mikro zincir) ===
# Tek incident yerine 2-3 adimli surec yaratir. RimWorld hissi icin omurga.
# Yapilan tasarim: data-driven CHAIN_DEFINITIONS, gunluk tickte ilerleme,
# stage giris/cikiste effect uygulamasi, news + state degisikligi.

const MAX_ACTIVE_EVENT_CHAINS: int = 4
const CHAIN_DEFINITIONS: Dictionary = {
	"drought_chain": {
		"label": "Kuraklik Zinciri",
		"news_root": "drought",
		"stages": [
			{"id": "drought", "duration": 2, "next": "famine"},
			{"id": "famine", "duration": 3, "next": "migration_pressure"},
			{"id": "migration_pressure", "duration": 2, "next": ""}
		]
	},
	"raid_chain": {
		"label": "Baskin Zinciri",
		"news_root": "raid",
		"stages": [
			{"id": "raid_warning", "duration": 1, "next": "raid"},
			{"id": "raid", "duration": 1, "next": "raid_aftermath"},
			{"id": "raid_aftermath", "duration": 2, "next": ""}
		]
	}
}

func _find_chain_stage_def(stages: Array, stage_id: String) -> Dictionary:
	for stage in stages:
		if not (stage is Dictionary):
			continue
		if String(stage.get("id", "")) == stage_id:
			return stage
	return {}

func _simulate_event_chains(day: int) -> void:
	if world_event_chains.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for chain in world_event_chains:
		var chain_type: String = String(chain.get("chain_type", ""))
		var def: Dictionary = CHAIN_DEFINITIONS.get(chain_type, {})
		if def.is_empty():
			continue
		var stages: Array = def.get("stages", [])
		var current_stage_id: String = String(chain.get("stage", ""))
		var stage_def: Dictionary = _find_chain_stage_def(stages, current_stage_id)
		if stage_def.is_empty():
			continue
		var stage_started_day: int = int(chain.get("stage_started_day", day))
		var duration: int = int(stage_def.get("duration", 1))
		if day - stage_started_day < duration:
			remaining.append(chain)
			continue
		_exit_event_chain_stage(chain, stage_def, day)
		var next_stage_id: String = String(stage_def.get("next", ""))
		if next_stage_id.is_empty():
			_post_event_chain_end_news(chain, day)
			continue
		var next_stage_def: Dictionary = _find_chain_stage_def(stages, next_stage_id)
		if next_stage_def.is_empty():
			_post_event_chain_end_news(chain, day)
			continue
		chain["stage"] = next_stage_id
		chain["stage_started_day"] = day
		_enter_event_chain_stage(chain, next_stage_def, day)
		remaining.append(chain)
	world_event_chains = remaining

func _try_seed_event_chain_from_incident(incident: Dictionary, day: int) -> void:
	if world_event_chains.size() >= MAX_ACTIVE_EVENT_CHAINS:
		return
	var settlement_id: String = String(incident.get("settlement_id", ""))
	if settlement_id.is_empty():
		return
	if _has_active_chain_for_settlement(settlement_id):
		return
	var incident_type: String = String(incident.get("type", ""))
	var severity: float = float(incident.get("severity", 1.0))
	var chain_type: String = ""
	match incident_type:
		"harvest_failure":
			if randf() < clampf(0.30 + severity * 0.20, 0.30, 0.65):
				chain_type = "drought_chain"
		"wolf_attack":
			if randf() < clampf(0.20 + severity * 0.15, 0.20, 0.50):
				chain_type = "raid_chain"
		_:
			pass
	if chain_type.is_empty():
		return
	_start_event_chain(chain_type, settlement_id, day, String(incident.get("id", "")))

func _has_active_chain_for_settlement(settlement_id: String) -> bool:
	for chain in world_event_chains:
		if String(chain.get("settlement_id", "")) == settlement_id:
			return true
	return false

func _start_event_chain(chain_type: String, settlement_id: String, day: int, source_incident_id: String = "") -> void:
	var def: Dictionary = CHAIN_DEFINITIONS.get(chain_type, {})
	if def.is_empty():
		return
	var stages: Array = def.get("stages", [])
	if stages.is_empty():
		return
	var first_stage: Dictionary = stages[0]
	var settlement_name: String = ""
	if world_settlement_states.has(settlement_id):
		settlement_name = String(world_settlement_states[settlement_id].get("name", settlement_id))
	var chain: Dictionary = {
		"id": "chain_%s_%s_%d" % [chain_type, settlement_id, day],
		"chain_type": chain_type,
		"settlement_id": settlement_id,
		"settlement_name": settlement_name,
		"stage": String(first_stage.get("id", "")),
		"started_day": day,
		"stage_started_day": day,
		"source_incident_id": source_incident_id
	}
	world_event_chains.append(chain)
	_enter_event_chain_stage(chain, first_stage, day)

func _enter_event_chain_stage(chain: Dictionary, stage_def: Dictionary, day: int) -> void:
	var settlement_id: String = String(chain.get("settlement_id", ""))
	if settlement_id.is_empty() or not world_settlement_states.has(settlement_id):
		return
	var state: Dictionary = world_settlement_states[settlement_id]
	var stage_id: String = String(stage_def.get("id", ""))
	match stage_id:
		"drought":
			state["food_stock"] = clamp(int(state.get("food_stock", 100)) - randi_range(8, 14), 0, 260)
		"famine":
			state["food_stock"] = clamp(int(state.get("food_stock", 100)) - randi_range(18, 26), 0, 260)
			state["stability"] = clamp(int(state.get("stability", 60)) - randi_range(4, 8), 5, 100)
		"migration_pressure":
			state["stability"] = clamp(int(state.get("stability", 60)) - randi_range(2, 5), 5, 100)
			# Stage etkisi sadece state degil, gercek goc entry'si de uretir.
			_seed_migration_from_settlement(settlement_id, day)
		"raid_warning":
			state["security"] = clamp(int(state.get("security", 60)) - randi_range(2, 5), 5, 100)
		"raid":
			state["security"] = clamp(int(state.get("security", 60)) - randi_range(8, 14), 5, 100)
			state["food_stock"] = clamp(int(state.get("food_stock", 100)) - randi_range(10, 18), 0, 260)
		"raid_aftermath":
			state["stability"] = clamp(int(state.get("stability", 60)) - randi_range(3, 6), 5, 100)
		_:
			pass
	world_settlement_states[settlement_id] = state
	_post_event_chain_stage_news(chain, stage_def, day)

func _exit_event_chain_stage(chain: Dictionary, _stage_def: Dictionary, _day: int) -> void:
	# Yer tutucu: ileride stage cikisinda iyilesme/zincir mutasyonu eklenebilir.
	pass

func _post_event_chain_stage_news(chain: Dictionary, stage_def: Dictionary, day: int) -> void:
	var settlement_id: String = String(chain.get("settlement_id", ""))
	if not _is_settlement_discovered_for_news(settlement_id) and randf() > 0.30:
		return
	var settlement_name: String = String(chain.get("settlement_name", "Komsu Koy"))
	var stage_id: String = String(stage_def.get("id", ""))
	var title: String = ""
	var content: String = ""
	var subcategory: String = "warning"
	match stage_id:
		"drought":
			title = "Kuraklik Basladi"
			content = "%s bolgesinde kuraklik etkisini gosteriyor." % settlement_name
		"famine":
			title = "Kitlik"
			content = "%s'ta erzak iyice azaldi, halk zorlaniyor." % settlement_name
			subcategory = "critical"
		"migration_pressure":
			title = "Goc Baskisi"
			content = "%s'tan dogru goc dalgalari yola cikiyor." % settlement_name
		"raid_warning":
			title = "Saldiri Sinyalleri"
			content = "%s yakininda eskiya hareketliligi rapor edildi." % settlement_name
		"raid":
			title = "Baskin"
			content = "%s baskina ugradi, kayiplar var." % settlement_name
			subcategory = "critical"
		"raid_aftermath":
			title = "Baskin Sonrasi"
			content = "%s baskinin yaralarini sariyor, duzen sarsilmis." % settlement_name
		_:
			title = "Olay"
			content = "%s bolgesinde gelisme yasaniyor." % settlement_name
	if not _is_settlement_discovered_for_news(settlement_id):
		content = "Duyum: " + content
	_post_world_news({
		"category": "world",
		"subcategory": subcategory,
		"title": title,
		"content": content,
		"day": day
	})

func _post_event_chain_end_news(chain: Dictionary, day: int) -> void:
	var settlement_id: String = String(chain.get("settlement_id", ""))
	if not _is_settlement_discovered_for_news(settlement_id):
		return
	var settlement_name: String = String(chain.get("settlement_name", "Komsu Koy"))
	var def: Dictionary = CHAIN_DEFINITIONS.get(String(chain.get("chain_type", "")), {})
	var label: String = String(def.get("label", "Olay Zinciri"))
	_post_world_news({
		"category": "world",
		"subcategory": "info",
		"title": "%s Sona Erdi" % label,
		"content": "%s'taki surec yatisti." % settlement_name,
		"day": day
	})

func get_world_event_chains() -> Array[Dictionary]:
	return world_event_chains.duplicate(true)

func get_active_event_chain_for_settlement(settlement_id: String) -> Dictionary:
	for chain in world_event_chains:
		if String(chain.get("settlement_id", "")) == settlement_id:
			return chain.duplicate(true)
	return {}

# === Migration Flow Model (Faz 3 omurgasi) ===
# Bir koyden cikan goc dalgasi gercek bir hedef koye akar.
# Kaynak nufus kaybi, hedef nufus artisi + erzak baskisi + istikrar baskisi.
# Iliski yuksek olan komsu daha kolay tercih edilir.

const MAX_ACTIVE_MIGRATIONS: int = 6
const MIGRATION_DEFAULT_DURATION_DAYS: int = 3

func _seed_migration_from_settlement(source_id: String, day: int) -> void:
	if source_id.is_empty() or not world_settlement_states.has(source_id):
		return
	if world_settlement_migrations.size() >= MAX_ACTIVE_MIGRATIONS:
		return
	# Ayni kaynaktan zaten aktif goc varsa cogaltma.
	for m in world_settlement_migrations:
		if String(m.get("source_id", "")) == source_id and not bool(m.get("completed", false)):
			return
	var target_id: String = _pick_migration_target(source_id)
	if target_id.is_empty():
		return
	var source_state: Dictionary = world_settlement_states[source_id]
	var population: int = int(source_state.get("population", 80))
	# Goc buyuklugu: kaynak nufusun kucuk bir orani (~%6-12), en az 4 kisi.
	var migrant_count: int = max(4, int(round(float(population) * randf_range(0.06, 0.12))))
	migrant_count = clampi(migrant_count, 4, 30)
	var migration: Dictionary = {
		"id": "mig_%s_%s_%d" % [source_id, target_id, day],
		"source_id": source_id,
		"source_name": String(source_state.get("name", source_id)),
		"target_id": target_id,
		"target_name": String(world_settlement_states[target_id].get("name", target_id)),
		"total": migrant_count,
		"transferred": 0,
		"started_day": day,
		"duration_days": MIGRATION_DEFAULT_DURATION_DAYS,
		"completed": false
	}
	world_settlement_migrations.append(migration)
	_post_migration_started_news(migration, day)

func _pick_migration_target(source_id: String) -> String:
	if not world_map_settlement_positions.has(source_id):
		return ""
	var source_pos: Dictionary = world_map_settlement_positions[source_id]
	var sq: int = int(source_pos.get("q", 0))
	var sr: int = int(source_pos.get("r", 0))
	var best_id: String = ""
	var best_score: float = -INF
	for candidate_id in world_settlement_states.keys():
		if String(candidate_id) == source_id:
			continue
		if not world_map_settlement_positions.has(candidate_id):
			continue
		var cpos: Dictionary = world_map_settlement_positions[candidate_id]
		var dist: int = _hex_distance(sq, sr, int(cpos.get("q", 0)), int(cpos.get("r", 0)))
		if dist <= 0 or dist > 14:
			continue
		var cstate: Dictionary = world_settlement_states[candidate_id]
		var stability: int = int(cstate.get("stability", 60))
		var security: int = int(cstate.get("security", 60))
		var food: int = int(cstate.get("food_stock", 100))
		var rel: int = get_settlement_relation(source_id, String(candidate_id))
		var score: float = 0.0
		score += float(stability) * 0.4
		score += float(security) * 0.3
		score += float(food) * 0.15
		score += float(rel) * 0.4
		score -= float(dist) * 1.6
		# Hedef de migration_pressure altindaysa cazip degil.
		var target_chain: Dictionary = get_active_event_chain_for_settlement(String(candidate_id))
		if String(target_chain.get("stage", "")) == "migration_pressure":
			score -= 25.0
		if score > best_score:
			best_score = score
			best_id = String(candidate_id)
	return best_id

func _simulate_settlement_migrations(day: int) -> void:
	if world_settlement_migrations.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for migration in world_settlement_migrations:
		if bool(migration.get("completed", false)):
			continue
		var source_id: String = String(migration.get("source_id", ""))
		var target_id: String = String(migration.get("target_id", ""))
		if source_id.is_empty() or target_id.is_empty():
			continue
		if not world_settlement_states.has(source_id) or not world_settlement_states.has(target_id):
			continue
		var total: int = int(migration.get("total", 0))
		var transferred: int = int(migration.get("transferred", 0))
		var duration: int = int(migration.get("duration_days", MIGRATION_DEFAULT_DURATION_DAYS))
		var per_day: int = max(1, int(round(float(total) / float(max(1, duration)))))
		var step: int = mini(per_day, total - transferred)
		if step <= 0:
			migration["completed"] = true
			_finalize_migration(migration, day)
			continue
		# Gercek transfer
		var source_state: Dictionary = world_settlement_states[source_id]
		var target_state: Dictionary = world_settlement_states[target_id]
		source_state["population"] = max(20, int(source_state.get("population", 80)) - step)
		target_state["population"] = clamp(int(target_state.get("population", 80)) + step, 20, 260)
		# Hedefte erzak baskisi ve istikrar baskisi (mulkeci entegrasyonu zor)
		target_state["food_stock"] = clamp(int(target_state.get("food_stock", 100)) - max(1, int(round(float(step) * 0.6))), 0, 260)
		var relation: int = get_settlement_relation(source_id, target_id)
		var stability_hit: int = max(1, int(round(float(step) * 0.20)))
		if relation >= 25:
			stability_hit = max(0, stability_hit - 1)
		elif relation <= -25:
			stability_hit += 1
		target_state["stability"] = clamp(int(target_state.get("stability", 60)) - stability_hit, 5, 100)
		world_settlement_states[source_id] = source_state
		world_settlement_states[target_id] = target_state
		migration["transferred"] = transferred + step
		if migration["transferred"] >= total:
			migration["completed"] = true
			_finalize_migration(migration, day)
			continue
		remaining.append(migration)
	world_settlement_migrations = remaining

func _finalize_migration(migration: Dictionary, day: int) -> void:
	var source_id: String = String(migration.get("source_id", ""))
	var target_id: String = String(migration.get("target_id", ""))
	var transferred: int = int(migration.get("transferred", 0))
	# Goc iliskiyi ufak da olsa pozitif etkiler (yardimseverlik).
	change_settlement_relation(source_id, target_id, 1)
	_post_migration_completed_news(migration, day, transferred)

func _post_migration_started_news(migration: Dictionary, day: int) -> void:
	var source_id: String = String(migration.get("source_id", ""))
	var target_id: String = String(migration.get("target_id", ""))
	var allow_full: bool = _is_settlement_discovered_for_news(source_id) or _is_settlement_discovered_for_news(target_id)
	if not allow_full and randf() > 0.30:
		return
	var content: String = "%s'tan %s'a goc dalgasi yola cikti (~%d kisi)." % [
		String(migration.get("source_name", source_id)),
		String(migration.get("target_name", target_id)),
		int(migration.get("total", 0))
	]
	if not allow_full:
		content = "Duyum: " + content
	_post_world_news({
		"category": "world",
		"subcategory": "warning",
		"title": "Goc Yola Cikti",
		"content": content,
		"day": day
	})

func _post_migration_completed_news(migration: Dictionary, day: int, transferred: int) -> void:
	var source_id: String = String(migration.get("source_id", ""))
	var target_id: String = String(migration.get("target_id", ""))
	var allow_full: bool = _is_settlement_discovered_for_news(source_id) or _is_settlement_discovered_for_news(target_id)
	if not allow_full and randf() > 0.25:
		return
	var content: String = "%s'a %d gocmen yerlesti." % [
		String(migration.get("target_name", target_id)),
		transferred
	]
	if not allow_full:
		content = "Duyum: " + content
	_post_world_news({
		"category": "world",
		"subcategory": "info",
		"title": "Goc Tamamlandi",
		"content": content,
		"day": day
	})

func get_world_settlement_migrations() -> Array[Dictionary]:
	return world_settlement_migrations.duplicate(true)

func get_active_migrations_for_settlement(settlement_id: String) -> Dictionary:
	var incoming: Array[Dictionary] = []
	var outgoing: Array[Dictionary] = []
	for migration in world_settlement_migrations:
		if bool(migration.get("completed", false)):
			continue
		if String(migration.get("source_id", "")) == settlement_id:
			outgoing.append(migration.duplicate(true))
		elif String(migration.get("target_id", "")) == settlement_id:
			incoming.append(migration.duplicate(true))
	return {"incoming": incoming, "outgoing": outgoing}

# === Inter-settlement Diplomacy FSM (Faz 3 omurgasi) ===
# State'ler relation skoru + olaylar uzerine kategorik durum saglar.
# Boylece "savas ilan edildi" / "ateskes imzalandi" gibi temiz gecisler olur.

const DIPLOMACY_STATE_PEACE: String = "peace"
const DIPLOMACY_STATE_TENSION: String = "tension"
const DIPLOMACY_STATE_COLD_WAR: String = "cold_war"
const DIPLOMACY_STATE_OPEN_WAR: String = "open_war"
const DIPLOMACY_STATE_CEASEFIRE: String = "ceasefire"

const DIPLOMACY_TENSION_THRESHOLD: int = -15
const DIPLOMACY_COLD_WAR_THRESHOLD: int = -35
const DIPLOMACY_OPEN_WAR_THRESHOLD: int = -65
const DIPLOMACY_PEACE_RECOVERY_THRESHOLD: int = -10
const CEASEFIRE_MIN_DAYS: int = 4
const OPEN_WAR_MIN_DAYS: int = 3

func _diplomacy_pair_key(a: String, b: String) -> String:
	return _settlement_rel_key(a, b)

func get_settlement_diplomacy_state(a: String, b: String) -> Dictionary:
	if a.is_empty() or b.is_empty() or a == b:
		return {}
	var key: String = _diplomacy_pair_key(a, b)
	if not world_settlement_diplomacy.has(key):
		return {"state": DIPLOMACY_STATE_PEACE, "since_day": _last_tick_day, "last_changed_day": _last_tick_day, "war_intensity": 0}
	return world_settlement_diplomacy[key].duplicate(true)

func _set_settlement_diplomacy_state(a: String, b: String, new_state: String, day: int, war_intensity: int = 0) -> void:
	if a.is_empty() or b.is_empty() or a == b:
		return
	var key: String = _diplomacy_pair_key(a, b)
	world_settlement_diplomacy[key] = {
		"state": new_state,
		"since_day": day,
		"last_changed_day": day,
		"war_intensity": war_intensity
	}

func get_world_settlement_diplomacy() -> Dictionary:
	return world_settlement_diplomacy.duplicate(true)

func _simulate_settlement_diplomacy(day: int) -> void:
	if world_settlement_states.size() < 2:
		return
	var ids: Array = world_settlement_states.keys()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			_evaluate_diplomacy_transition(String(ids[i]), String(ids[j]), day)
	# open_war ciftlerinde dusuk olasilikla raid_chain seedle
	for key in world_settlement_diplomacy.keys():
		var entry: Dictionary = world_settlement_diplomacy[key]
		if String(entry.get("state", "")) != DIPLOMACY_STATE_OPEN_WAR:
			continue
		if randf() > 0.18:
			continue
		var pair_ids: PackedStringArray = String(key).split("|")
		if pair_ids.size() < 2:
			continue
		var attacker_id: String = pair_ids[0] if randf() < 0.5 else pair_ids[1]
		_try_seed_war_raid_chain(attacker_id, day)

func _evaluate_diplomacy_transition(a: String, b: String, day: int) -> void:
	var rel: int = get_settlement_relation(a, b)
	var current: Dictionary = get_settlement_diplomacy_state(a, b)
	var current_state: String = String(current.get("state", DIPLOMACY_STATE_PEACE))
	var since_day: int = int(current.get("since_day", day))
	var days_in_state: int = day - since_day
	# Bos pair (peace + relation 0) durumunda map'e yazmiyalim, bellek yormasin.
	if current_state == DIPLOMACY_STATE_PEACE and rel >= DIPLOMACY_TENSION_THRESHOLD and not world_settlement_diplomacy.has(_diplomacy_pair_key(a, b)):
		return
	var next_state: String = current_state
	match current_state:
		DIPLOMACY_STATE_PEACE:
			if rel <= DIPLOMACY_OPEN_WAR_THRESHOLD:
				next_state = DIPLOMACY_STATE_OPEN_WAR
			elif rel <= DIPLOMACY_COLD_WAR_THRESHOLD:
				next_state = DIPLOMACY_STATE_COLD_WAR
			elif rel <= DIPLOMACY_TENSION_THRESHOLD:
				next_state = DIPLOMACY_STATE_TENSION
		DIPLOMACY_STATE_TENSION:
			if rel >= DIPLOMACY_PEACE_RECOVERY_THRESHOLD:
				next_state = DIPLOMACY_STATE_PEACE
			elif rel <= DIPLOMACY_OPEN_WAR_THRESHOLD:
				next_state = DIPLOMACY_STATE_OPEN_WAR
			elif rel <= DIPLOMACY_COLD_WAR_THRESHOLD:
				next_state = DIPLOMACY_STATE_COLD_WAR
		DIPLOMACY_STATE_COLD_WAR:
			if rel >= DIPLOMACY_PEACE_RECOVERY_THRESHOLD:
				next_state = DIPLOMACY_STATE_PEACE
			elif rel >= DIPLOMACY_TENSION_THRESHOLD:
				next_state = DIPLOMACY_STATE_TENSION
			elif rel <= DIPLOMACY_OPEN_WAR_THRESHOLD:
				next_state = DIPLOMACY_STATE_OPEN_WAR
		DIPLOMACY_STATE_OPEN_WAR:
			# Min savas suresi sonrasinda relation toparlanirsa ateskes
			if days_in_state >= OPEN_WAR_MIN_DAYS and rel >= DIPLOMACY_COLD_WAR_THRESHOLD:
				next_state = DIPLOMACY_STATE_CEASEFIRE
		DIPLOMACY_STATE_CEASEFIRE:
			if days_in_state >= CEASEFIRE_MIN_DAYS:
				if rel >= DIPLOMACY_PEACE_RECOVERY_THRESHOLD:
					next_state = DIPLOMACY_STATE_PEACE
				elif rel <= DIPLOMACY_OPEN_WAR_THRESHOLD:
					# Ateskes bozuldu
					next_state = DIPLOMACY_STATE_OPEN_WAR
				elif rel >= DIPLOMACY_TENSION_THRESHOLD:
					next_state = DIPLOMACY_STATE_TENSION
		_:
			next_state = DIPLOMACY_STATE_PEACE
	if next_state != current_state:
		var war_intensity: int = int(current.get("war_intensity", 0))
		if next_state == DIPLOMACY_STATE_OPEN_WAR:
			war_intensity = max(1, war_intensity + 1)
		elif next_state == DIPLOMACY_STATE_PEACE:
			war_intensity = 0
		_set_settlement_diplomacy_state(a, b, next_state, day, war_intensity)
		_post_diplomacy_transition_news(a, b, current_state, next_state, day)

func _post_diplomacy_transition_news(a: String, b: String, prev_state: String, new_state: String, day: int) -> void:
	var name_a: String = _get_settlement_display_name(a)
	var name_b: String = _get_settlement_display_name(b)
	var allow_full: bool = _is_settlement_discovered_for_news(a) or _is_settlement_discovered_for_news(b)
	# Peace transitions can be noisy - sustain only meaningful ones.
	if new_state == DIPLOMACY_STATE_PEACE and prev_state == DIPLOMACY_STATE_TENSION:
		return
	var title: String = ""
	var content: String = ""
	var subcategory: String = "info"
	match new_state:
		DIPLOMACY_STATE_TENSION:
			title = "Gerginlik"
			content = "%s ile %s arasinda gerginlik artiyor." % [name_a, name_b]
			subcategory = "info"
		DIPLOMACY_STATE_COLD_WAR:
			title = "Soguk Savas"
			content = "%s ve %s sinirlarini siktilastirdi." % [name_a, name_b]
			subcategory = "warning"
		DIPLOMACY_STATE_OPEN_WAR:
			title = "Savas Ilani"
			content = "%s ile %s arasinda savas patlak verdi." % [name_a, name_b]
			subcategory = "critical"
		DIPLOMACY_STATE_CEASEFIRE:
			title = "Ateskes"
			content = "%s ve %s ateskes ilan etti." % [name_a, name_b]
			subcategory = "success"
		DIPLOMACY_STATE_PEACE:
			title = "Baris"
			content = "%s ve %s arasinda baris saglandi." % [name_a, name_b]
			subcategory = "success"
		_:
			return
	if not allow_full:
		if randf() > 0.30:
			return
		content = "Duyum: " + content
	_post_world_news({
		"category": "world",
		"subcategory": subcategory,
		"title": title,
		"content": content,
		"day": day
	})

func _get_settlement_display_name(settlement_id: String) -> String:
	if world_settlement_states.has(settlement_id):
		return String(world_settlement_states[settlement_id].get("name", settlement_id))
	if world_map_settlement_positions.has(settlement_id):
		return String(world_map_settlement_positions[settlement_id].get("name", settlement_id))
	return settlement_id

func _try_seed_war_raid_chain(attacker_id: String, day: int) -> void:
	if attacker_id.is_empty() or not world_settlement_states.has(attacker_id):
		return
	if world_event_chains.size() >= MAX_ACTIVE_EVENT_CHAINS:
		return
	if _has_active_chain_for_settlement(attacker_id):
		return
	_start_event_chain("raid_chain", attacker_id, day, "")

# === Player diplomatic intervention API ===
# Oyuncu mevcut diplomasi FSM'sine kaynak harcayarak mudahale edebilir.

const WAR_SUPPORT_GOLD_COST: int = 80
const WAR_SUPPORT_FOOD_COST: int = 35
const MEDIATION_GOLD_COST: int = 130

func get_war_support_options(settlement_id: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if settlement_id.is_empty() or not world_settlement_states.has(settlement_id):
		return options
	for entry in get_settlement_diplomacy_summary(settlement_id):
		if String(entry.get("state", "")) != DIPLOMACY_STATE_OPEN_WAR:
			continue
		var opp_id: String = String(entry.get("other_id", ""))
		if opp_id.is_empty():
			continue
		options.append({
			"id": "war_support",
			"label": "Savasta Destek (%s'a karsi)" % String(entry.get("other_name", "?")),
			"type": "war_support",
			"supported_id": settlement_id,
			"opponent_id": opp_id,
			"opponent_name": String(entry.get("other_name", "?")),
			"cost": {"gold": WAR_SUPPORT_GOLD_COST, "food": WAR_SUPPORT_FOOD_COST},
			"summary": "Destekli koy guvenlik+, dusman zayiflar. Iliski +5 / -5."
		})
	return options

func get_mediation_options(settlement_id: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if settlement_id.is_empty() or not world_settlement_states.has(settlement_id):
		return options
	for entry in get_settlement_diplomacy_summary(settlement_id):
		var state: String = String(entry.get("state", ""))
		if state != DIPLOMACY_STATE_OPEN_WAR and state != DIPLOMACY_STATE_COLD_WAR:
			continue
		var other_id: String = String(entry.get("other_id", ""))
		if other_id.is_empty():
			continue
		options.append({
			"id": "mediation",
			"label": "Aracilik (%s ile)" % String(entry.get("other_name", "?")),
			"type": "mediation",
			"between_a": settlement_id,
			"between_b": other_id,
			"between_b_name": String(entry.get("other_name", "?")),
			"cost": {"gold": MEDIATION_GOLD_COST},
			"summary": "Iki tarafi yatistirir (savas->ateskes, soguk savas->gerginlik). Iliski +3 / +3."
		})
	return options

func can_afford_diplomatic_intervention(option: Dictionary) -> bool:
	return can_afford_settlement_aid(option)

func apply_war_support(supported_id: String, opponent_id: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "summary": ""}
	if supported_id.is_empty() or opponent_id.is_empty():
		result["reason"] = "invalid_settlement"
		return result
	if not world_settlement_states.has(supported_id) or not world_settlement_states.has(opponent_id):
		result["reason"] = "invalid_settlement"
		return result
	var diplo: Dictionary = get_settlement_diplomacy_state(supported_id, opponent_id)
	if String(diplo.get("state", "")) != DIPLOMACY_STATE_OPEN_WAR:
		result["reason"] = "not_at_war"
		return result
	var option_for_check: Dictionary = {"cost": {"gold": WAR_SUPPORT_GOLD_COST, "food": WAR_SUPPORT_FOOD_COST}}
	if not can_afford_diplomatic_intervention(option_for_check):
		result["reason"] = "cannot_afford"
		return result
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gpd:
		if gpd.has_method("add_gold"):
			gpd.call("add_gold", -WAR_SUPPORT_GOLD_COST)
		else:
			gpd.gold = max(0, int(gpd.gold) - WAR_SUPPORT_GOLD_COST)
	if gm and gm.has_method("add_resource"):
		gm.call("add_resource", "food", -WAR_SUPPORT_FOOD_COST)
	var supported_state: Dictionary = world_settlement_states[supported_id]
	var opponent_state: Dictionary = world_settlement_states[opponent_id]
	supported_state["security"] = clamp(int(supported_state.get("security", 60)) + 10, 5, 100)
	supported_state["stability"] = clamp(int(supported_state.get("stability", 60)) + 5, 5, 100)
	opponent_state["security"] = clamp(int(opponent_state.get("security", 60)) - 8, 5, 100)
	opponent_state["food_stock"] = clamp(int(opponent_state.get("food_stock", 100)) - 8, 0, 260)
	world_settlement_states[supported_id] = supported_state
	world_settlement_states[opponent_id] = opponent_state
	# War intensity arttir
	var key: String = _diplomacy_pair_key(supported_id, opponent_id)
	if world_settlement_diplomacy.has(key):
		world_settlement_diplomacy[key]["war_intensity"] = int(world_settlement_diplomacy[key].get("war_intensity", 1)) + 1
	# Player iliskileri
	var supported_name: String = _get_settlement_display_name(supported_id)
	var opponent_name: String = _get_settlement_display_name(opponent_id)
	change_relation("Köy", supported_name, 5, false)
	change_relation("Köy", opponent_name, -5, false)
	_post_world_news({
		"category": "world",
		"subcategory": "warning",
		"title": "Savas Destegi",
		"content": "%s'a karsi %s desteklendi. Savas siddetleniyor." % [opponent_name, supported_name],
		"day": _last_tick_day
	})
	world_map_updated.emit()
	result["ok"] = true
	result["summary"] = "%s'a karsi %s desteklendi." % [opponent_name, supported_name]
	return result

func apply_mediation(between_a: String, between_b: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "summary": ""}
	if between_a.is_empty() or between_b.is_empty():
		result["reason"] = "invalid_settlement"
		return result
	if not world_settlement_states.has(between_a) or not world_settlement_states.has(between_b):
		result["reason"] = "invalid_settlement"
		return result
	var diplo: Dictionary = get_settlement_diplomacy_state(between_a, between_b)
	var current_state: String = String(diplo.get("state", ""))
	if current_state != DIPLOMACY_STATE_OPEN_WAR and current_state != DIPLOMACY_STATE_COLD_WAR:
		result["reason"] = "no_conflict"
		return result
	var option_for_check: Dictionary = {"cost": {"gold": MEDIATION_GOLD_COST}}
	if not can_afford_diplomatic_intervention(option_for_check):
		result["reason"] = "cannot_afford"
		return result
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if gpd:
		if gpd.has_method("add_gold"):
			gpd.call("add_gold", -MEDIATION_GOLD_COST)
		else:
			gpd.gold = max(0, int(gpd.gold) - MEDIATION_GOLD_COST)
	# Diplomasi gecisini zorla
	change_settlement_relation(between_a, between_b, 25)
	var new_state: String = current_state
	if current_state == DIPLOMACY_STATE_OPEN_WAR:
		new_state = DIPLOMACY_STATE_CEASEFIRE
	elif current_state == DIPLOMACY_STATE_COLD_WAR:
		new_state = DIPLOMACY_STATE_TENSION
	_set_settlement_diplomacy_state(between_a, between_b, new_state, _last_tick_day)
	_post_diplomacy_transition_news(between_a, between_b, current_state, new_state, _last_tick_day)
	var name_a: String = _get_settlement_display_name(between_a)
	var name_b: String = _get_settlement_display_name(between_b)
	change_relation("Köy", name_a, 3, false)
	change_relation("Köy", name_b, 3, false)
	_post_world_news({
		"category": "world",
		"subcategory": "success",
		"title": "Aracilik",
		"content": "%s ile %s arasinda aracilik yapildi." % [name_a, name_b],
		"day": _last_tick_day
	})
	world_map_updated.emit()
	result["ok"] = true
	result["summary"] = "%s ve %s yatistirildi." % [name_a, name_b]
	return result

# === Player <-> Settlement Alliance API (Faz 4 omurga) ===
# Oyuncu artik bir koyle baglayici ittifak kurabilir.
# Etkiler:
#  - O koy oyuncu icin "muttefik" rozeti tasir.
#  - Kriz aninda yardim cagrisi (aid_call) acilir; oyuncu yardim ederse iliski +5/-5, ihmal ederse her gun -1.
#  - Ileride: muttefigin dusmanlari oyuncuya hostile olur (data alani hazir).
const ALLIANCE_PROPOSE_GOLD_COST: int = 200
const ALLIANCE_PROPOSE_FOOD_COST: int = 60
const ALLIANCE_MIN_RELATION: int = 70
const ALLIANCE_BREAK_RELATION_PENALTY: int = -25
const ALLIANCE_AID_CALL_FOOD_THRESHOLD: int = 25
const ALLIANCE_AID_CALL_SECURITY_THRESHOLD: int = 25
const ALLIANCE_AID_CALL_COOLDOWN_DAYS: int = 5
const ALLIANCE_AID_IGNORE_DAILY_RELATION: int = -1
# Hostility yayilim: muttefigin dusmanlari oyuncuya da hostile olur.
const ALLIANCE_HOSTILITY_INITIAL_PENALTY: int = -10
const ALLIANCE_HOSTILITY_NEW_ENEMY_PENALTY: int = -8
const ALLIANCE_HOSTILITY_THRESHOLD: int = -30  # bu seviyenin altindaki iliski "dusmanca"
# Tribute (gunluk pasif kazanc): muttefik koy stabil + erzaki bolse oyuncuya akar.
const ALLIANCE_TRIBUTE_FOOD_MIN: int = 80
const ALLIANCE_TRIBUTE_STABILITY_MIN: int = 50
const ALLIANCE_TRIBUTE_BASE_GOLD: int = 1
const ALLIANCE_TRIBUTE_FOOD_CHANCE: float = 0.30
const ALLIANCE_TRIBUTE_POP_REF: float = 90.0  # ~orta nufus; tribute carpani referansi
# Shared Intel (gunluk pasif kesif): muttefik koy etrafindaki hex'ler pasif kesfedilir.
const ALLIANCE_INTEL_BASE_RADIUS: int = 2
# Defansif destek (hostile baskin geldiginde muttefik mudahale eder).
const ALLIANCE_DEFENSE_BASE_RANGE: int = 6  # hex menzili
const ALLIANCE_DEFENSE_FOOD_MIN: int = 60
const ALLIANCE_DEFENSE_SECURITY_MIN: int = 50
const ALLIANCE_DEFENSE_BASE_CHANCE: float = 0.55  # rol/koy sartlariyla scaled

func is_player_allied(settlement_id: String) -> bool:
	if settlement_id.is_empty():
		return false
	return world_player_alliances.has(settlement_id)

func get_player_alliance(settlement_id: String) -> Dictionary:
	if not is_player_allied(settlement_id):
		return {}
	return (world_player_alliances[settlement_id] as Dictionary).duplicate(true)

func get_all_player_alliances() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sid in world_player_alliances.keys():
		var entry: Dictionary = world_player_alliances[sid]
		var copy: Dictionary = entry.duplicate(true)
		copy["settlement_id"] = String(sid)
		copy["settlement_name"] = _get_settlement_display_name(String(sid))
		out.append(copy)
	return out

func get_alliance_proposal_options(settlement_id: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if settlement_id.is_empty() or not world_settlement_states.has(settlement_id):
		return options
	if is_player_allied(settlement_id):
		return options
	options.append({
		"id": "alliance_propose",
		"label": "Ittifak Onerisi",
		"type": "alliance_propose",
		"settlement_id": settlement_id,
		"cost": {"gold": ALLIANCE_PROPOSE_GOLD_COST, "food": ALLIANCE_PROPOSE_FOOD_COST},
		"summary": "Iliski >= %d ise kabul edilir. Muttefik koy kriz aninda yardim ister." % ALLIANCE_MIN_RELATION
	})
	return options

func get_alliance_break_options(settlement_id: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if not is_player_allied(settlement_id):
		return options
	options.append({
		"id": "alliance_break",
		"label": "Ittifaki Boz",
		"type": "alliance_break",
		"settlement_id": settlement_id,
		"cost": {},
		"summary": "Iliski %d puan duser. Acik kriz cagrisi varsa kapanir." % ALLIANCE_BREAK_RELATION_PENALTY
	})
	return options

func propose_alliance(settlement_id: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "summary": ""}
	if settlement_id.is_empty() or not world_settlement_states.has(settlement_id):
		result["reason"] = "invalid_settlement"
		return result
	if is_player_allied(settlement_id):
		result["reason"] = "already_allied"
		return result
	var settlement_name: String = _get_settlement_display_name(settlement_id)
	var current_rel: int = get_relation("Köy", settlement_name)
	if current_rel < ALLIANCE_MIN_RELATION:
		result["reason"] = "relation_too_low"
		result["summary"] = "Iliski cok dusuk: %d / %d" % [current_rel, ALLIANCE_MIN_RELATION]
		return result
	var option_for_check: Dictionary = {"cost": {"gold": ALLIANCE_PROPOSE_GOLD_COST, "food": ALLIANCE_PROPOSE_FOOD_COST}}
	if not can_afford_diplomatic_intervention(option_for_check):
		result["reason"] = "cannot_afford"
		return result
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gpd:
		if gpd.has_method("add_gold"):
			gpd.call("add_gold", -ALLIANCE_PROPOSE_GOLD_COST)
		else:
			gpd.gold = max(0, int(gpd.gold) - ALLIANCE_PROPOSE_GOLD_COST)
	if gm and gm.has_method("add_resource"):
		gm.call("add_resource", "food", -ALLIANCE_PROPOSE_FOOD_COST)
	world_player_alliances[settlement_id] = {
		"established_day": _last_tick_day,
		"last_aid_call_day": -999,
		"aid_call_active": false,
		"aid_call_started_day": -1,
		"aid_call_reason": "",
		"tracked_enemies": _get_settlement_open_war_enemies(settlement_id)
	}
	change_relation("Köy", settlement_name, 5, false)
	_post_world_news({
		"category": "world",
		"subcategory": "success",
		"title": "Ittifak Kuruldu",
		"content": "%s koyuyle ittifak imzalandi." % settlement_name,
		"day": _last_tick_day
	})
	# Hostility yayilim: muttefigin OPEN_WAR rakipleri oyuncuya da hostile olur.
	_apply_alliance_hostility_initial(settlement_id)
	world_map_updated.emit()
	result["ok"] = true
	result["summary"] = "%s ile ittifak kuruldu." % settlement_name
	return result

func break_alliance(settlement_id: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "summary": ""}
	if not is_player_allied(settlement_id):
		result["reason"] = "not_allied"
		return result
	var settlement_name: String = _get_settlement_display_name(settlement_id)
	world_player_alliances.erase(settlement_id)
	change_relation("Köy", settlement_name, ALLIANCE_BREAK_RELATION_PENALTY, false)
	_post_world_news({
		"category": "world",
		"subcategory": "warning",
		"title": "Ittifak Sona Erdi",
		"content": "%s ile ittifak bozuldu." % settlement_name,
		"day": _last_tick_day
	})
	world_map_updated.emit()
	result["ok"] = true
	result["summary"] = "%s ittifaki bozuldu." % settlement_name
	return result

# Gunluk: muttefik koylerin durumunu kontrol et, kriz cagrisi ac/kapa, ihmal cezasi uygula.
func _simulate_player_alliances(day: int) -> void:
	if world_player_alliances.is_empty():
		return
	var to_remove: Array[String] = []
	var role_mods: Dictionary = _get_living_world_role_modifiers()
	var total_tribute_gold: int = 0
	var total_tribute_food: int = 0
	var tribute_sources: PackedStringArray = PackedStringArray()
	for sid in world_player_alliances.keys():
		if not world_settlement_states.has(sid):
			to_remove.append(String(sid))
			continue
		var alliance: Dictionary = world_player_alliances[sid]
		var state: Dictionary = world_settlement_states[sid]
		var food: int = int(state.get("food_stock", 100))
		var security: int = int(state.get("security", 60))
		var aid_active: bool = bool(alliance.get("aid_call_active", false))
		var in_crisis: bool = food <= ALLIANCE_AID_CALL_FOOD_THRESHOLD or security <= ALLIANCE_AID_CALL_SECURITY_THRESHOLD
		if in_crisis and not aid_active:
			var last_call: int = int(alliance.get("last_aid_call_day", -999))
			if day - last_call >= ALLIANCE_AID_CALL_COOLDOWN_DAYS:
				var reason: String = "guvenlik" if security <= ALLIANCE_AID_CALL_SECURITY_THRESHOLD else "erzak"
				alliance["aid_call_active"] = true
				alliance["aid_call_started_day"] = day
				alliance["aid_call_reason"] = reason
				alliance["last_aid_call_day"] = day
				world_player_alliances[sid] = alliance
				_post_alliance_aid_call_news(String(sid), reason, day)
				var mm_aid: Node = get_node_or_null("/root/MissionManager")
				if mm_aid and mm_aid.has_method("try_spawn_alliance_aid_relief_mission"):
					mm_aid.call("try_spawn_alliance_aid_relief_mission", String(sid), day, true)
		elif aid_active and not in_crisis:
			alliance["aid_call_active"] = false
			alliance["aid_call_started_day"] = -1
			alliance["aid_call_reason"] = ""
			world_player_alliances[sid] = alliance
			_post_alliance_aid_resolved_news(String(sid), day)
		elif aid_active and in_crisis:
			# Ihmal cezasi: her gun iliski -1
			var s_name: String = _get_settlement_display_name(String(sid))
			change_relation("Köy", s_name, ALLIANCE_AID_IGNORE_DAILY_RELATION, false)
		# Hostility diff: muttefik bugun yeni bir dusman edindiyse oyuncu da etkilensin.
		_apply_alliance_hostility_diff(String(sid), day)
		# Tribute: kriz yoksa ve koy stabil + erzaki yeterliyse pasif kazanc.
		if not aid_active and not in_crisis:
			var tribute_result: Dictionary = _try_apply_alliance_tribute(String(sid), state, role_mods)
			if bool(tribute_result.get("paid", false)):
				total_tribute_gold += int(tribute_result.get("gold", 0))
				total_tribute_food += int(tribute_result.get("food", 0))
				tribute_sources.append(String(state.get("name", sid)))
				# Stat update ediyoruz (food drift) - tasarim: koy gercekten bir miktar erzak veriyor
				world_settlement_states[String(sid)] = state
		# Shared Intel: kriz/aid_active yoksa muttefik etrafini pasif kesfet.
		if not aid_active and not in_crisis:
			_apply_alliance_shared_intel(String(sid), role_mods)
	for dead_sid in to_remove:
		world_player_alliances.erase(dead_sid)
	# Tribute haberi (toplu)
	if total_tribute_gold > 0 or total_tribute_food > 0:
		_post_alliance_tribute_news(total_tribute_gold, total_tribute_food, tribute_sources, day)

func _alliance_tribute_population_multiplier(population: int) -> float:
	var p: float = float(clampi(population, 25, 240))
	return clampf(sqrt(p / ALLIANCE_TRIBUTE_POP_REF), 0.65, 1.5)

func _try_apply_alliance_tribute(settlement_id: String, state: Dictionary, role_mods: Dictionary) -> Dictionary:
	# Tribute kosullari: stability >= MIN ve food_stock >= MIN.
	var result: Dictionary = {"paid": false, "gold": 0, "food": 0}
	var stability: int = int(state.get("stability", 60))
	var food: int = int(state.get("food_stock", 100))
	if stability < ALLIANCE_TRIBUTE_STABILITY_MIN or food < ALLIANCE_TRIBUTE_FOOD_MIN:
		return result
	var tuccar_bonus: int = int(role_mods.get("alliance_tribute_bonus", 0))
	var pop: int = int(state.get("population", int(ALLIANCE_TRIBUTE_POP_REF)))
	var pop_mult: float = _alliance_tribute_population_multiplier(pop)
	var gold_amount: int = int(round(float(ALLIANCE_TRIBUTE_BASE_GOLD + tuccar_bonus) * pop_mult))
	var food_amount: int = 0
	if randf() < ALLIANCE_TRIBUTE_FOOD_CHANCE:
		var base_food: int = 1 + (1 if tuccar_bonus >= 2 else 0)
		food_amount = maxi(1, int(round(float(base_food) * clampf(pop_mult, 0.85, 1.25))))
	# Oyuncu kasasi/kaynaklarini guncelle
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if gpd and gold_amount > 0:
		if gpd.has_method("add_gold"):
			gpd.call("add_gold", gold_amount)
		else:
			gpd.gold = int(gpd.gold) + gold_amount
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and food_amount > 0 and gm.has_method("add_resource"):
		gm.call("add_resource", "food", food_amount)
	# Koyden simgesel cikis (gercek bir akis hissi icin)
	if food_amount > 0:
		state["food_stock"] = clamp(int(state.get("food_stock", 100)) - food_amount, 0, 260)
	result["paid"] = true
	result["gold"] = gold_amount
	result["food"] = food_amount
	return result

func _apply_alliance_shared_intel(settlement_id: String, role_mods: Dictionary) -> void:
	# Muttefik koyun bulundugu hex etrafinda pasif kesif.
	if not world_map_settlement_positions.has(settlement_id):
		return
	var pos: Dictionary = world_map_settlement_positions[settlement_id]
	var radius: int = ALLIANCE_INTEL_BASE_RADIUS + int(role_mods.get("alliance_intel_radius_bonus", 0))
	radius = clampi(radius, 1, 5)
	discover_tiles({"q": int(pos.get("q", 0)), "r": int(pos.get("r", 0))}, radius, "alliance")

func _post_alliance_tribute_news(gold: int, food: int, sources: PackedStringArray, day: int) -> void:
	if gold <= 0 and food <= 0:
		return
	var parts: PackedStringArray = PackedStringArray()
	if gold > 0:
		parts.append("%d altin" % gold)
	if food > 0:
		parts.append("%d erzak" % food)
	var src_text: String = ", ".join(sources) if sources.size() > 0 else "muttefikler"
	_post_world_news({
		"category": "world",
		"subcategory": "success",
		"title": "Muttefik Lojistik Destegi",
		"content": "%s'tan tribute alindi: %s." % [src_text, ", ".join(parts)],
		"day": day
	})

# UI getter: gunluk tribute tahmini (tuccar + aktif muttefikler hesabiyla)
func get_estimated_daily_alliance_tribute() -> Dictionary:
	var out: Dictionary = {"gold": 0, "food_avg": 0.0, "ally_count": 0, "eligible_count": 0}
	if world_player_alliances.is_empty():
		return out
	var role_mods: Dictionary = _get_living_world_role_modifiers()
	var tuccar_bonus: int = int(role_mods.get("alliance_tribute_bonus", 0))
	var gold_sum: int = 0
	var food_weighted: float = 0.0
	var eligible: int = 0
	for sid in world_player_alliances.keys():
		out["ally_count"] = int(out["ally_count"]) + 1
		var alliance: Dictionary = world_player_alliances[sid]
		if bool(alliance.get("aid_call_active", false)):
			continue
		if not world_settlement_states.has(sid):
			continue
		var state: Dictionary = world_settlement_states[sid]
		if int(state.get("stability", 0)) < ALLIANCE_TRIBUTE_STABILITY_MIN:
			continue
		if int(state.get("food_stock", 0)) < ALLIANCE_TRIBUTE_FOOD_MIN:
			continue
		eligible += 1
		var pop: int = int(state.get("population", int(ALLIANCE_TRIBUTE_POP_REF)))
		var pop_mult: float = _alliance_tribute_population_multiplier(pop)
		gold_sum += int(round(float(ALLIANCE_TRIBUTE_BASE_GOLD + tuccar_bonus) * pop_mult))
		# Kabaca beklenen erzak: pop_mult ile hafif agirlik
		var food_extra: float = 1.0 + (1.0 if tuccar_bonus >= 2 else 0.0)
		food_weighted += ALLIANCE_TRIBUTE_FOOD_CHANCE * food_extra * clampf(pop_mult, 0.85, 1.25)
	out["eligible_count"] = eligible
	out["gold"] = gold_sum
	out["food_avg"] = food_weighted
	return out

# === Alliance Hostility Yayilim Helpers ===
func _get_settlement_open_war_enemies(settlement_id: String) -> Array[String]:
	# settlement_id'nin OPEN_WAR durumunda oldugu diger koy ID listesini doner.
	var enemies: Array[String] = []
	if settlement_id.is_empty():
		return enemies
	for entry in get_settlement_diplomacy_summary(settlement_id):
		if not (entry is Dictionary):
			continue
		if String(entry.get("state", "")) != DIPLOMACY_STATE_OPEN_WAR:
			continue
		var other_id: String = String(entry.get("other_id", ""))
		if not other_id.is_empty():
			enemies.append(other_id)
	return enemies

func _apply_alliance_hostility_initial(ally_id: String) -> void:
	# Ittifak kurulurken muttefigin OPEN_WAR rakiplerine oyuncu iliski -10.
	if not world_player_alliances.has(ally_id):
		return
	var enemies: Array[String] = _get_settlement_open_war_enemies(ally_id)
	if enemies.is_empty():
		return
	var ally_name: String = _get_settlement_display_name(ally_id)
	var hostile_names: PackedStringArray = PackedStringArray()
	for enemy_id in enemies:
		var enemy_name: String = _get_settlement_display_name(enemy_id)
		change_relation("Köy", enemy_name, ALLIANCE_HOSTILITY_INITIAL_PENALTY, false)
		hostile_names.append(enemy_name)
	if not hostile_names.is_empty():
		_post_world_news({
			"category": "world",
			"subcategory": "warning",
			"title": "Ittifak Yansimasi",
			"content": "%s'in dusmanlari sana karsi sertlesti: %s." % [ally_name, ", ".join(hostile_names)],
			"day": _last_tick_day
		})

func _apply_alliance_hostility_diff(ally_id: String, day: int) -> void:
	# Muttefigin tracked_enemies setine kiyasla yeni dusmanlar varsa oyuncu iliski -8.
	if not world_player_alliances.has(ally_id):
		return
	var alliance: Dictionary = world_player_alliances[ally_id]
	var prev_set: Dictionary = {}
	var prev_arr: Array = alliance.get("tracked_enemies", [])
	for v in prev_arr:
		prev_set[String(v)] = true
	var current_enemies: Array[String] = _get_settlement_open_war_enemies(ally_id)
	var new_enemies: Array[String] = []
	for enemy_id in current_enemies:
		if not prev_set.has(enemy_id):
			new_enemies.append(enemy_id)
	if not new_enemies.is_empty():
		var ally_name: String = _get_settlement_display_name(ally_id)
		var new_names: PackedStringArray = PackedStringArray()
		for enemy_id in new_enemies:
			var enemy_name: String = _get_settlement_display_name(enemy_id)
			change_relation("Köy", enemy_name, ALLIANCE_HOSTILITY_NEW_ENEMY_PENALTY, false)
			new_names.append(enemy_name)
		_post_world_news({
			"category": "world",
			"subcategory": "warning",
			"title": "Ittifak Yansimasi",
			"content": "%s yeni dusman edindi: %s. Sana karsi sogudular." % [ally_name, ", ".join(new_names)],
			"day": day
		})
	# Track listesini guncel tut (hem yeni eklenenler hem cikanlar).
	alliance["tracked_enemies"] = current_enemies
	world_player_alliances[ally_id] = alliance

# UI icin: oyuncuya dusmanca olan koylerin ozeti (relation < ALLIANCE_HOSTILITY_THRESHOLD)
func get_player_hostile_settlements() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sid in world_settlement_states.keys():
		var s_name: String = _get_settlement_display_name(String(sid))
		var rel: int = get_relation("Köy", s_name)
		if rel <= ALLIANCE_HOSTILITY_THRESHOLD:
			out.append({
				"settlement_id": String(sid),
				"settlement_name": s_name,
				"relation": rel
			})
	return out

func is_settlement_hostile_to_player(settlement_id: String) -> bool:
	if settlement_id.is_empty():
		return false
	var s_name: String = _get_settlement_display_name(settlement_id)
	return get_relation("Köy", s_name) <= ALLIANCE_HOSTILITY_THRESHOLD

func _post_alliance_aid_call_news(settlement_id: String, reason: String, day: int) -> void:
	var settlement_name: String = _get_settlement_display_name(settlement_id)
	var content: String
	if reason == "guvenlik":
		content = "%s muttefigi guvenlik krizinde. Yardim bekliyor." % settlement_name
	else:
		content = "%s muttefigi kitlik icinde. Erzak yardimi bekliyor." % settlement_name
	_post_world_news({
		"category": "world",
		"subcategory": "warning",
		"title": "Muttefik Yardim Cagrisi",
		"content": content,
		"day": day
	})

func _post_alliance_aid_resolved_news(settlement_id: String, day: int) -> void:
	var settlement_name: String = _get_settlement_display_name(settlement_id)
	_post_world_news({
		"category": "world",
		"subcategory": "success",
		"title": "Muttefik Toparlandi",
		"content": "%s muttefigi krizden cikti." % settlement_name,
		"day": day
	})

## MissionManager: `completes_alliance_aid_settlement_id` li gorev basarili olunca — aid_call kapat, durum/iliski
func apply_alliance_aid_mission_success(settlement_id: String) -> void:
	if String(settlement_id).is_empty():
		return
	if not world_player_alliances.has(settlement_id):
		return
	var alliance: Dictionary = world_player_alliances[settlement_id]
	var s_name: String = _get_settlement_display_name(settlement_id)
	var had_call: bool = bool(alliance.get("aid_call_active", false))
	var reason: String = String(alliance.get("aid_call_reason", ""))
	if had_call:
		alliance["aid_call_active"] = false
		alliance["aid_call_started_day"] = -1
		alliance["aid_call_reason"] = ""
		world_player_alliances[settlement_id] = alliance
	if world_settlement_states.has(settlement_id) and had_call:
		var state: Dictionary = world_settlement_states[settlement_id]
		match reason:
			"guvenlik":
				state["security"] = clamp(int(state.get("security", 60)) + 14, 5, 100)
				state["stability"] = clamp(int(state.get("stability", 60)) + 4, 5, 100)
			"erzak":
				state["food_stock"] = clamp(int(state.get("food_stock", 100)) + 35, 0, 260)
				state["stability"] = clamp(int(state.get("stability", 60)) + 6, 5, 100)
			_:
				state["stability"] = clamp(int(state.get("stability", 60)) + 5, 5, 100)
		world_settlement_states[settlement_id] = state
	if had_call:
		change_relation("Köy", s_name, 5, false)
		_post_world_news({
			"category": "world",
			"subcategory": "success",
			"title": "Muttefik Yardim Gorevi",
			"content": "%s yardim cagrisina lojistik/diplomatik cevap verildi." % s_name,
			"day": _last_tick_day
		})
	else:
		change_relation("Köy", s_name, 2, false)
		_post_world_news({
			"category": "world",
			"subcategory": "info",
			"title": "Muttefik Lojistik",
			"content": "%s icin yardim gorevi tamamlandi (kriz haritada cozulmus olabilir)." % s_name,
			"day": _last_tick_day
		})
	world_map_updated.emit()

# Belirli bir settlement icin diplomasi ozeti (UI icin)
func get_settlement_diplomacy_summary(settlement_id: String) -> Array[Dictionary]:
	var summary: Array[Dictionary] = []
	if settlement_id.is_empty():
		return summary
	for key in world_settlement_diplomacy.keys():
		var entry: Dictionary = world_settlement_diplomacy[key]
		var state: String = String(entry.get("state", DIPLOMACY_STATE_PEACE))
		if state == DIPLOMACY_STATE_PEACE:
			continue
		var pair_ids: PackedStringArray = String(key).split("|")
		if pair_ids.size() < 2:
			continue
		var other_id: String = ""
		if pair_ids[0] == settlement_id:
			other_id = pair_ids[1]
		elif pair_ids[1] == settlement_id:
			other_id = pair_ids[0]
		else:
			continue
		summary.append({
			"other_id": other_id,
			"other_name": _get_settlement_display_name(other_id),
			"state": state,
			"since_day": int(entry.get("since_day", 0))
		})
	return summary

const SETTLEMENT_AID_FOOD_COST: int = 35
const SETTLEMENT_AID_GOLD_COST: int = 30
const SETTLEMENT_PATROL_GOLD_COST: int = 45

func get_settlement_aid_options(settlement_id: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if settlement_id.is_empty() or not world_settlement_states.has(settlement_id):
		return options
	var incident: Dictionary = get_active_settlement_incident(settlement_id)
	if incident.is_empty():
		return options
	var incident_type: String = String(incident.get("type", ""))
	match incident_type:
		"wolf_attack":
			options.append({
				"id": "patrol",
				"label": "Devriye Gonder",
				"cost": {"gold": SETTLEMENT_PATROL_GOLD_COST},
				"summary": "Guvenlik +12, suresi -1 gun, iliski +3"
			})
		"harvest_failure":
			options.append({
				"id": "food_aid",
				"label": "Erzak Yardimi",
				"cost": {"food": SETTLEMENT_AID_FOOD_COST},
				"summary": "Erzak +30, istikrar +6, iliski +4"
			})
		"migrant_wave":
			options.append({
				"id": "settle_aid",
				"label": "Iskan Yardimi",
				"cost": {"gold": SETTLEMENT_AID_GOLD_COST, "food": int(SETTLEMENT_AID_FOOD_COST / 2)},
				"summary": "Istikrar +8, suresi -1 gun, iliski +3"
			})
		_:
			pass
	return options

func can_afford_settlement_aid(option: Dictionary) -> bool:
	var cost: Dictionary = option.get("cost", {})
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	var gm: Node = get_node_or_null("/root/GameManager")
	var gold_cost: int = int(cost.get("gold", 0))
	if gold_cost > 0:
		if gpd == null or not ("gold" in gpd):
			return false
		if int(gpd.gold) < gold_cost:
			return false
	for resource_type in ["food", "wood", "stone", "water"]:
		var amount: int = int(cost.get(resource_type, 0))
		if amount <= 0:
			continue
		if gm == null or not gm.has_method("get_resource"):
			return false
		if int(gm.call("get_resource", resource_type)) < amount:
			return false
	return true

func apply_settlement_aid(settlement_id: String, option_id: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "summary": ""}
	if settlement_id.is_empty() or not world_settlement_states.has(settlement_id):
		result["reason"] = "invalid_settlement"
		return result
	var incident: Dictionary = get_active_settlement_incident(settlement_id)
	if incident.is_empty():
		result["reason"] = "no_active_incident"
		return result
	var matching_option: Dictionary = {}
	for opt in get_settlement_aid_options(settlement_id):
		if String(opt.get("id", "")) == option_id:
			matching_option = opt
			break
	if matching_option.is_empty():
		result["reason"] = "invalid_option"
		return result
	if not can_afford_settlement_aid(matching_option):
		result["reason"] = "cannot_afford"
		return result
	var cost: Dictionary = matching_option.get("cost", {})
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	var gm: Node = get_node_or_null("/root/GameManager")
	var gold_cost: int = int(cost.get("gold", 0))
	if gold_cost > 0 and gpd:
		if gpd.has_method("add_gold"):
			gpd.call("add_gold", -gold_cost)
		else:
			gpd.gold = max(0, int(gpd.gold) - gold_cost)
	for resource_type in ["food", "wood", "stone", "water"]:
		var amount: int = int(cost.get(resource_type, 0))
		if amount > 0 and gm and gm.has_method("add_resource"):
			gm.call("add_resource", resource_type, -amount)
	var state: Dictionary = world_settlement_states[settlement_id]
	var settlement_name: String = String(state.get("name", settlement_id))
	var relation_delta: int = 0
	var summary_text: String = ""
	match option_id:
		"patrol":
			state["security"] = clamp(int(state.get("security", 60)) + 12, 5, 100)
			incident["duration"] = max(1, int(incident.get("duration", 1)) - 1)
			summary_text = "%s icin devriye gonderildi. Guvenlik artti, kriz kisaldi." % settlement_name
			relation_delta = 3
		"food_aid":
			state["food_stock"] = clamp(int(state.get("food_stock", 100)) + 30, 0, 260)
			state["stability"] = clamp(int(state.get("stability", 60)) + 6, 5, 100)
			summary_text = "%s icin erzak yardimi yollandi. Halk kismen rahatladi." % settlement_name
			relation_delta = 4
		"settle_aid":
			state["stability"] = clamp(int(state.get("stability", 60)) + 8, 5, 100)
			incident["duration"] = max(1, int(incident.get("duration", 1)) - 1)
			summary_text = "%s'ta gocmenlerin iskani icin destek saglandi." % settlement_name
			relation_delta = 3
		_:
			summary_text = "%s icin yardim uygulandi." % settlement_name
			relation_delta = 2
	world_settlement_states[settlement_id] = state
	for i in range(world_settlement_incidents.size()):
		if String(world_settlement_incidents[i].get("id", "")) == String(incident.get("id", "")):
			world_settlement_incidents[i] = incident
			break
	if relation_delta != 0:
		change_relation("Köy", String(state.get("name", settlement_id)), relation_delta, false)
	# Muttefik aid_call hook: aktif yardim cagrisi varsa kapat ve bonus iliski ver.
	if is_player_allied(settlement_id):
		var alliance: Dictionary = world_player_alliances[settlement_id]
		if bool(alliance.get("aid_call_active", false)):
			alliance["aid_call_active"] = false
			alliance["aid_call_started_day"] = -1
			alliance["aid_call_reason"] = ""
			world_player_alliances[settlement_id] = alliance
			change_relation("Köy", String(state.get("name", settlement_id)), 5, false)
			summary_text += " Muttefik tesekkur etti (+5 iliski)."
	_post_world_news({
		"category": "world",
		"subcategory": "success",
		"title": "Komsu Yardimi",
		"content": summary_text,
		"day": _last_tick_day
	})
	world_map_updated.emit()
	result["ok"] = true
	result["summary"] = summary_text
	return result

func _check_village_attacks(day: int) -> void:
	"""Köy saldırılarını kontrol et"""
	# Düşman fraksiyonları kontrol et
	for faction in factions:
		if faction == "Köy":
			continue
		
		var relation = get_relation("Köy", faction)
		
		# Düşman fraksiyonlar saldırı yapabilir
		if relation < -30 and randf() < 0.05:  # %5 şans
			_trigger_village_attack(faction, day)
		
		# Köy de saldırı yapabilir (oyuncu kontrolünde)
		if relation < -50 and randf() < 0.02:  # %2 şans
			_trigger_village_raid(faction, day)
	# Hostile settlement (oyuncuya dusmanca olan koyler) baskinlari
	_check_hostile_settlement_attacks(day)

func _check_hostile_settlement_attacks(day: int) -> void:
	# Hostile esigi altindaki koylerden gunluk dusuk sansla baskin tetiklenir.
	var hostiles: Array = get_player_hostile_settlements()
	if hostiles.is_empty():
		return
	var role_mods: Dictionary = _get_living_world_role_modifiers()
	var defense_buff: float = float(role_mods.get("hostile_attack_chance_mult", 1.0))
	for h in hostiles:
		if not (h is Dictionary):
			continue
		var rel: int = int(h.get("relation", 0))
		# Iliski ne kadar dusukse sans o kadar yuksek (-30 -> %0.5, -60 -> %2.5, -100 -> %5)
		var raw_chance: float = clampf((float(-rel) - 30.0) * 0.0007 + 0.005, 0.005, 0.05)
		var final_chance: float = raw_chance * defense_buff
		if randf() < final_chance:
			var attacker_name: String = String(h.get("settlement_name", "?"))
			var settlement_id: String = String(h.get("settlement_id", ""))
			_trigger_hostile_settlement_attack(attacker_name, settlement_id, day)

func _trigger_hostile_settlement_attack(attacker_name: String, settlement_id: String, day: int) -> void:
	# _trigger_village_attack pattern'ini kullaniyor, ek meta ile.
	var tm: Node = get_node_or_null("/root/TimeManager")
	if not tm:
		return
	var current_hour: float = 0.0
	if tm.has_method("get_hour"):
		current_hour = tm.get_hour()
	var attack_hour: float = current_hour + 6.0
	var attack_day: int = day
	if attack_hour >= 24.0:
		attack_day += 1
		attack_hour -= 24.0
	_post_world_news({
		"category": "world",
		"subcategory": "critical",
		"title": "🚨 Dusman Koy Baskini!",
		"content": "%s koyu (sana dusmanca) baskina hazirlaniyor. 6 saat icinde gelecekler." % attacker_name,
		"day": day
	})
	# Multi-ally defans destegi denemesi
	var defender_meta: Dictionary = _try_apply_alliance_defense_intervention(settlement_id, day)
	var defenders_arr: Array = defender_meta.get("defenders", []) if defender_meta.get("intervened", false) else []
	pending_attacks.append({
		"attacker": attacker_name,
		"settlement_id": settlement_id,
		"is_hostile_settlement": true,
		"warning_day": day,
		"warning_hour": current_hour,
		"attack_day": attack_day,
		"attack_hour": attack_hour,
		"deployed": false,
		"defender_settlement_id": String(defender_meta.get("defender_id", "")),
		"defender_settlement_name": String(defender_meta.get("defender_name", "")),
		"defender_intervention": bool(defender_meta.get("intervened", false)),
		"defender_count": int(defenders_arr.size()),
		"defenders": defenders_arr
	})
	print("🛡️ Dusman koy baskini zamanlandi: %s -> 6 saat sonra (Gun %d, Saat %.1f)" % [attacker_name, attack_day, attack_hour])

# === Alliance Defense System ===
func _get_player_village_position() -> Dictionary:
	# poi_type == "player_village" olan tile'i bul, q/r doner.
	for key in world_map_tiles.keys():
		var tile: Dictionary = world_map_tiles[key]
		if String(tile.get("poi_type", "")) == "player_village":
			return {"q": int(tile.get("q", 0)), "r": int(tile.get("r", 0))}
	return {}

func _pick_alliance_defender(attacker_settlement_id: String) -> Dictionary:
	var all_d: Array[Dictionary] = _pick_alliance_defenders(attacker_settlement_id, 1)
	return all_d[0] if not all_d.is_empty() else {}

func _pick_alliance_defenders(attacker_settlement_id: String, max_count: int = 3) -> Array[Dictionary]:
	if world_player_alliances.is_empty():
		return []
	var target_pos: Dictionary = _get_player_village_position()
	if target_pos.is_empty():
		return []
	var role_mods: Dictionary = _get_living_world_role_modifiers()
	var max_range: int = ALLIANCE_DEFENSE_BASE_RANGE + int(role_mods.get("alliance_defense_range_bonus", 0))
	var candidates: Array[Dictionary] = []
	for sid in world_player_alliances.keys():
		var ally_id: String = String(sid)
		if ally_id == attacker_settlement_id:
			continue
		var alliance: Dictionary = world_player_alliances[ally_id]
		if bool(alliance.get("aid_call_active", false)):
			continue
		if not world_settlement_states.has(ally_id):
			continue
		var state: Dictionary = world_settlement_states[ally_id]
		if int(state.get("food_stock", 0)) < ALLIANCE_DEFENSE_FOOD_MIN:
			continue
		if int(state.get("security", 0)) < ALLIANCE_DEFENSE_SECURITY_MIN:
			continue
		if not world_map_settlement_positions.has(ally_id):
			continue
		var pos: Dictionary = world_map_settlement_positions[ally_id]
		var dist: int = _hex_distance(
			int(target_pos.get("q", 0)),
			int(target_pos.get("r", 0)),
			int(pos.get("q", 0)),
			int(pos.get("r", 0))
		)
		if dist > max_range:
			continue
		candidates.append({
			"settlement_id": ally_id,
			"settlement_name": String(state.get("name", ally_id)),
			"distance": dist,
			"max_range": max_range
		})
	if candidates.is_empty():
		return []
	candidates.sort_custom(func(a, b): return int(a.get("distance", 0)) < int(b.get("distance", 0)))
	return candidates.slice(0, min(max_count, candidates.size()))

func _try_apply_alliance_defense_intervention(attacker_settlement_id: String, day: int) -> Dictionary:
	# Multi-ally savunma: birden fazla muttefik katilabilir.
	# Donus: { intervened, defender_id, defender_name, defenders (Array) }
	var result: Dictionary = {"intervened": false, "defender_id": "", "defender_name": "", "defenders": []}
	var candidates: Array[Dictionary] = _pick_alliance_defenders(attacker_settlement_id, 3)
	if candidates.is_empty():
		return result
	var role_mods: Dictionary = _get_living_world_role_modifiers()
	var chance_bonus: float = float(role_mods.get("alliance_defense_chance_bonus", 0.0))
	var intervened_list: Array[Dictionary] = []
	for defender in candidates:
		var dist: int = int(defender.get("distance", 0))
		var max_range: int = int(defender.get("max_range", ALLIANCE_DEFENSE_BASE_RANGE))
		var proximity: float = clampf(1.0 - (float(dist) / float(max(1, max_range))), 0.2, 1.0)
		# Ek defender'larin katilma sansi azalir (ilk tam sans, sonrakiler %70, %50)
		var stack_penalty: float = 1.0 - float(intervened_list.size()) * 0.15
		var final_chance: float = clampf(ALLIANCE_DEFENSE_BASE_CHANCE * proximity * stack_penalty + chance_bonus, 0.05, 0.95)
		if randf() <= final_chance:
			var d_id: String = String(defender.get("settlement_id", ""))
			var d_name: String = String(defender.get("settlement_name", "Muttefik"))
			_apply_alliance_defense_effects(attacker_settlement_id, d_id, d_name, day)
			intervened_list.append({"defender_id": d_id, "defender_name": d_name})
	if intervened_list.is_empty():
		return result
	result["intervened"] = true
	result["defender_id"] = String(intervened_list[0].get("defender_id", ""))
	result["defender_name"] = String(intervened_list[0].get("defender_name", "Muttefik"))
	result["defenders"] = intervened_list
	return result

func _apply_alliance_defense_effects(attacker_id: String, defender_id: String, defender_name: String, day: int) -> void:
	# Saldirgan koy zayiflar, defender koy minik yipranma yasar, oyuncu iliskileri etkilenir,
	# ve iki koy arasi diplomasi gerilir (FSM dogal akisina yansir).
	if world_settlement_states.has(attacker_id):
		var attacker_state: Dictionary = world_settlement_states[attacker_id]
		attacker_state["security"] = clamp(int(attacker_state.get("security", 60)) - 5, 5, 100)
		attacker_state["stability"] = clamp(int(attacker_state.get("stability", 60)) - 3, 5, 100)
		world_settlement_states[attacker_id] = attacker_state
	if world_settlement_states.has(defender_id):
		var defender_state: Dictionary = world_settlement_states[defender_id]
		defender_state["security"] = clamp(int(defender_state.get("security", 60)) - 2, 5, 100)
		world_settlement_states[defender_id] = defender_state
	var attacker_name: String = _get_settlement_display_name(attacker_id)
	change_relation("Köy", defender_name, 3, false)
	change_relation("Köy", attacker_name, -3, false)
	# Defender ile attacker arasinda gerilim/diplomasi: FSM dogal akisina yansisin.
	change_settlement_relation(defender_id, attacker_id, -10)
	_post_world_news({
		"category": "world",
		"subcategory": "success",
		"title": "Muttefik Savunma Destegi",
		"content": "%s koyu, %s baskinina karsi savunmaya katildi. Saldirgan zayifladi, muttefik iliski guclendi." % [defender_name, attacker_name],
		"day": day
	})
	world_map_updated.emit()

# UI getter: Bir muttefigin defender olabilirligini (current state) doner.
func get_alliance_defender_eligibility(settlement_id: String) -> Dictionary:
	var info: Dictionary = {"eligible": false, "reason": "", "max_range": 0, "distance": -1}
	if not is_player_allied(settlement_id):
		info["reason"] = "not_allied"
		return info
	if not world_settlement_states.has(settlement_id):
		info["reason"] = "no_state"
		return info
	var alliance: Dictionary = world_player_alliances[settlement_id]
	if bool(alliance.get("aid_call_active", false)):
		info["reason"] = "in_crisis"
		return info
	var state: Dictionary = world_settlement_states[settlement_id]
	if int(state.get("food_stock", 0)) < ALLIANCE_DEFENSE_FOOD_MIN:
		info["reason"] = "low_food"
		return info
	if int(state.get("security", 0)) < ALLIANCE_DEFENSE_SECURITY_MIN:
		info["reason"] = "low_security"
		return info
	var role_mods: Dictionary = _get_living_world_role_modifiers()
	var max_range: int = ALLIANCE_DEFENSE_BASE_RANGE + int(role_mods.get("alliance_defense_range_bonus", 0))
	info["max_range"] = max_range
	var target_pos: Dictionary = _get_player_village_position()
	if target_pos.is_empty():
		info["reason"] = "no_player_village"
		return info
	if not world_map_settlement_positions.has(settlement_id):
		info["reason"] = "no_position"
		return info
	var pos: Dictionary = world_map_settlement_positions[settlement_id]
	var dist: int = _hex_distance(
		int(target_pos.get("q", 0)),
		int(target_pos.get("r", 0)),
		int(pos.get("q", 0)),
		int(pos.get("r", 0))
	)
	info["distance"] = dist
	if dist > max_range:
		info["reason"] = "out_of_range"
		return info
	info["eligible"] = true
	return info

func _trigger_village_attack(attacker_faction: String, day: int) -> void:
	"""Köye saldırı uyarısı ve zamanlaması - 6 saat sonra saldırı"""
	var tm = get_node_or_null("/root/TimeManager")
	if not tm:
		return
	
	# Mevcut saat bilgisini al
	var current_hour: float = 0.0
	if tm.has_method("get_hour"):
		current_hour = tm.get_hour()
	
	# Saldırı 6 saat sonra olacak
	var attack_hour = current_hour + 6.0
	var attack_day = day
	var warning_day = day
	var warning_hour = current_hour
	
	# Eğer 6 saat sonra gece yarısını geçiyorsa bir sonraki güne geç
	if attack_hour >= 24.0:
		attack_day += 1
		attack_hour = attack_hour - 24.0
	
	# Uyarı haberini şimdi gönder
	_post_world_news({
		"category": "world",
		"subcategory": "critical",
		"title": "🚨 Saldırı Uyarısı!",
		"content": "%s fraksiyonu köyümüze saldırı hazırlığı yapıyor! Saldırı 6 saat sonra bekleniyor. Askerlerinizi hazırlayın!" % attacker_faction,
		"day": day
	})
	
	# Zamanlanmış saldırıyı kaydet
	pending_attacks.append({
		"attacker": attacker_faction,
		"warning_day": warning_day,
		"warning_hour": warning_hour,
		"attack_day": attack_day,
		"attack_hour": attack_hour,
		"deployed": false
	})
	
	print("🛡️ Köye saldırı zamanlandı: %s -> 6 saat sonra (Gün %d, Saat %.1f)" % [attacker_faction, attack_day, attack_hour])

func _check_pending_attacks() -> void:
	"""Zamanlanmış saldırıları kontrol et ve gerçekleştir (saat bazlı)"""
	var tm = get_node_or_null("/root/TimeManager")
	if not tm:
		return
	
	var current_day: int = 0
	var current_hour: float = 0.0
	
	if tm.has_method("get_day"):
		current_day = tm.get_day()
	if tm.has_method("get_hour"):
		current_hour = tm.get_hour()
	
	var remaining_attacks: Array[Dictionary] = []
	
	for attack in pending_attacks:
		var attack_day = attack.get("attack_day", current_day)
		var attack_hour: float = float(attack.get("attack_hour", 0.0))
		var warning_day = attack.get("warning_day", current_day)
		var warning_hour: float = float(attack.get("warning_hour", 0.0))
		var deployed: bool = bool(attack.get("deployed", false))
		
		# Saldırıdan 3 saat önce askerleri deploy et (saldırıdan 6 saat sonra, deploy 3 saat önce = 3 saat sonra)
		var deploy_time = attack_hour - 3.0
		var deploy_day = attack_day
		if deploy_time < 0.0:
			deploy_time += 24.0
			deploy_day -= 1
		
		var should_deploy = false
		if current_day > deploy_day:
			should_deploy = true
		elif current_day == deploy_day and current_hour >= deploy_time:
			should_deploy = true
		
		if not deployed and should_deploy:
			defense_deployment_started.emit(attack_day)
			attack["deployed"] = true
			print("⚔️ Askerler savaşa hazırlanıyor, ekran dışına yürüyorlar (Saldırı: Gün %d, Saat %.1f)" % [attack_day, attack_hour])
		
		# Saldırı zamanı kontrolü
		var attack_time_reached = false
		if current_day > attack_day:
			attack_time_reached = true
		elif current_day == attack_day and current_hour >= attack_hour:
			attack_time_reached = true
		
		if attack_time_reached:
			var attacker = attack.get("attacker", "Bilinmeyen")
			var d_count: int = int(attack.get("defender_count", 1 if bool(attack.get("defender_intervention", false)) else 0))
			_execute_village_defense(attacker, current_day, d_count > 0, d_count)
		else:
			# Henüz zamanı gelmedi
			remaining_attacks.append(attack)
	
	pending_attacks = remaining_attacks

func _execute_village_defense(attacker_faction: String, day: int, alliance_defender: bool = false, defender_count: int = 0) -> void:
	print("⚔️ Otomatik savunma: %s saldırısı (muttefik destek: %s, adet: %d)" % [attacker_faction, str(alliance_defender), defender_count])
	
	var cr = get_node_or_null("/root/CombatResolver")
	
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		print("❌ MissionManager bulunamadı!")
		return
	
	var defender_force = mm._get_player_military_force()
	
	if alliance_defender and defender_count > 0:
		var base_soldiers: int = int(defender_force.get("units", {}).get("soldiers", 0))
		var per_ally_ratio: float = 0.25
		var reinforcement: int = max(2 * defender_count, int(base_soldiers * per_ally_ratio * float(defender_count)))
		if defender_force.has("units") and defender_force["units"] is Dictionary:
			defender_force["units"]["soldiers"] = base_soldiers + reinforcement
		defender_force["alliance_reinforcement"] = reinforcement
		defender_force["alliance_defender_count"] = defender_count
	
	var attacker_force = _get_attacker_force_for_defense(attacker_faction)
	
	var battle_result: Dictionary = {}
	if cr and cr.has_method("simulate_skirmish"):
		battle_result = cr.simulate_skirmish(attacker_force, defender_force)
	else:
		var atk_units: int = int(attacker_force.get("units", {}).get("infantry", 0)) + int(attacker_force.get("units", {}).get("archers", 0))
		var def_units: int = int(defender_force.get("units", {}).get("soldiers", 0))
		var atk_power: float = float(atk_units) * 1.0
		var def_power: float = float(def_units) * 1.2
		if alliance_defender:
			def_power *= (1.0 + 0.10 * float(min(defender_count, 3)))
		var defender_wins: bool = def_power >= atk_power * randf_range(0.8, 1.2)
		battle_result = {
			"victor": "defender" if defender_wins else "attacker",
			"defender_losses": int(max(0, round(def_units * randf_range(0.1, 0.5)))) if def_units > 0 else 0,
			"attacker_losses": int(max(0, round(atk_units * randf_range(0.2, 0.6)))),
			"alliance_defender": alliance_defender,
			"alliance_defender_count": defender_count
		}
	
	_process_defense_result(attacker_faction, battle_result, day, attacker_force, defender_force)

func _get_attacker_force_for_defense(attacker_faction: String) -> Dictionary:
	"""Savunma için saldırgan gücünü hesapla"""
	# İlişkiye göre saldırgan gücü belirle
	var relation = get_relation("Köy", attacker_faction)
	var base_strength = 5 + abs(relation) / 10  # Daha düşman = daha güçlü saldırı
	
	return {
		"units": {"infantry": int(base_strength), "archers": int(base_strength * 0.6)},
		"equipment": {"weapon": int(base_strength * 1.5), "armor": int(base_strength)},
		"supplies": {"bread": int(base_strength * 2), "water": int(base_strength * 1.5)},
		"gold": int(base_strength * 20)
	}

func _process_defense_result(attacker_faction: String, battle_result: Dictionary, day: int, attacker_force: Dictionary = {}, defender_force: Dictionary = {}) -> void:
	"""Savunma sonuçlarını işle ve haber olarak bildir"""
	var victor = battle_result.get("victor", "defender")
	var defender_losses = battle_result.get("defender_losses", 0)
	var attacker_losses = battle_result.get("attacker_losses", 0)
	
	# Generate battle story using LLM
	_generate_battle_story(attacker_faction, battle_result, day, attacker_force, defender_force)
	
	var vm = get_node_or_null("/root/VillageManager")
	var mm = get_node_or_null("/root/MissionManager")
	var barracks = mm._find_barracks() if mm else null
	
	if victor == "defender":
		# Köy savunmayı başardı
		_post_world_news({
			"category": "world",
			"subcategory": "success",
			"title": "✅ Savunma Başarılı",
			"content": "%s saldırısı püskürtüldü! Kayıplar: %d asker. Köy zarar görmedi." % [attacker_faction, defender_losses],
			"day": day
		})
		
		# Ölü askerleri kaldır
		if barracks and barracks.has_method("remove_soldiers"):
			barracks.remove_soldiers(defender_losses)
		
		# Küçük moral bonusu
		if vm:
			vm.village_morale = min(100.0, vm.village_morale + 2.0)
		
		# Askerlerin geri dönmesi için sinyal gönder
		defense_battle_completed.emit("defender", defender_losses)
		
	else:
		# Köy yenildi - zarar gör
		var gold_loss = randi_range(100, 300)
		var morale_loss = randi_range(5, 15)
		
		# Kaynak kaybı
		var gpd = get_node_or_null("/root/GlobalPlayerData")
		if gpd:
			gpd.gold = max(0, gpd.gold - gold_loss)
		
		# Moral kaybı
		if vm:
			vm.village_morale = max(0.0, vm.village_morale - morale_loss)
		
		# Ölü askerleri kaldır
		if barracks and barracks.has_method("remove_soldiers"):
			barracks.remove_soldiers(defender_losses)
		
		_post_world_news({
			"category": "world",
			"subcategory": "critical",
			"title": "❌ Savunma Başarısız",
			"content": "%s saldırısı köye zarar verdi! Kayıplar: %d asker, %d altın, %d moral." % [attacker_faction, defender_losses, gold_loss, morale_loss],
			"day": day
		})
		
		# Askerlerin geri dönmesi için sinyal gönder
		defense_battle_completed.emit("attacker", defender_losses)

func _trigger_village_raid(target_faction: String, day: int) -> void:
	"""Köyden saldırı başlat"""
	var raid_event = {
		"type": "village_raid",
		"attacker": "Köy",
		"target": target_faction,
		"day": day,
		"severity": "moderate"
	}
	
	# Saldırı haberini yayınla
	_post_world_news({
		"category": "world",
		"subcategory": "warning",
		"title": "Saldırı Fırsatı",
		"content": "%s fraksiyonuna saldırı fırsatı doğdu!" % target_faction,
		"day": day
	})
	
	# Saldırıyı MissionManager'a bildir
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("create_raid_mission"):
		mm.create_raid_mission(target_faction, day)

func _update_active_events(day: int) -> void:
	"""Aktif olayları güncelle"""
	var remaining_events: Array[Dictionary] = []
	
	for event in active_events:
		var started_day = event.get("started_day", day)
		var duration = event.get("duration", 0)
		
		if day - started_day < duration:
			remaining_events.append(event)
		else:
			# Olay süresi doldu
			_post_event_end_news(event, day)
	
	active_events = remaining_events

func _post_event_end_news(event: Dictionary, day: int) -> void:
	"""Olay sona erdiğinde haber yayınla"""
	var event_type = event.get("type", "")
	var faction = event.get("faction", "")
	
	var title = ""
	var content = ""
	
	match event_type:
		"trade_boom":
			title = "Ticaret Patlaması Sona Erdi"
			content = "%s bölgesindeki ticaret patlaması sona erdi." % faction
		"famine":
			title = "Kıtlık Sona Erdi"
			content = "%s bölgesindeki kıtlık sona erdi." % faction
		"plague":
			title = "Salgın Sona Erdi"
			content = "%s bölgesindeki salgın sona erdi." % faction
		"war_declaration":
			title = "Savaş Sona Erdi"
			content = "%s bölgesindeki savaş sona erdi." % faction
		"rebellion":
			title = "İsyan Bastırıldı"
			content = "%s bölgesindeki isyan bastırıldı." % faction
	
	_post_world_news({
		"category": "world",
		"subcategory": "success",
		"title": title,
		"content": content,
		"day": day
	})
	# Dynamic world events simulation
	# 15% chance of any event on a random non-player faction
	if randi() % 100 < 15 and factions.size() > 1:
		var idx := 1 + int(randi() % (factions.size() - 1))
		var selected_faction := factions[idx]
		var random_event_type := _get_random_event_type()
		var ev := _create_event(random_event_type, selected_faction, day)
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
	if a == "Köy" or b == "Köy":
		var mm_sync: Node = get_node_or_null("/root/MissionManager")
		if mm_sync and mm_sync.has_method("sync_settlement_relations_from_world_map"):
			mm_sync.sync_settlement_relations_from_world_map()

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

func change_relation(a: String, b: String, delta: int, post_news: bool = true) -> void:
	var current = get_relation(a, b)
	set_relation(a, b, current + delta, post_news)

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
	if MissionManager and MissionManager.has_method("post_news"):
		MissionManager.post_news("Dünya", title, content, Color.WHITE, subcategory)
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
	if not VillageManager or not VillageManager.has_method("apply_world_event_effects"):
		return
	
	# Apply effects of all active events
	for event in active_events:
		VillageManager.apply_world_event_effects(event)
	
	# Remove effects of expired events
	var remaining: Array[Dictionary] = []
	for event in active_events:
		var started_day := int(event.get("started_day", day))
		var duration := int(event.get("duration", 0))
		if day - started_day < duration:
			remaining.append(event)
		else:
			# Event expired, remove its effects
			VillageManager.remove_world_event_effects(event)
	active_events = remaining

func _post_world_news(news: Dictionary) -> void:
	# MissionManager'ın post_news metodunu kullan
	if MissionManager and MissionManager.has_method("post_news"):
		var category = news.get("category", "world")
		var title = news.get("title", "Bilinmeyen")
		var content = news.get("content", "")
		var subcategory = news.get("subcategory", "info")
		
		# Category'yi MissionManager formatına çevir
		if category == "world":
			category = "Dünya"
		
		MissionManager.post_news(category, title, content, Color.WHITE, subcategory)
	else:
		# Fallback: sinyal emit et
		if MissionManager and MissionManager.has_signal("news_posted"):
			MissionManager.news_posted.emit(news)
		else:
			print("[WORLD NEWS] ", news)

func _generate_battle_story(attacker_faction: String, battle_result: Dictionary, day: int, attacker_force: Dictionary, defender_force: Dictionary) -> void:
	"""Generate a battle story using LLM without grammar constraints"""
	if not LlamaService.IsInitialized():
		print("WorldManager: LlamaService not available, skipping battle story generation")
		return
	
	# Store battle data for when LLM response arrives
	_pending_battle_story_data = {
		"attacker_faction": attacker_faction,
		"battle_result": battle_result,
		"day": day,
		"attacker_force": attacker_force,
		"defender_force": defender_force
	}
	
	# Construct prompt with battle information
	var prompt = _construct_battle_story_prompt(attacker_faction, battle_result, day, attacker_force, defender_force)
	
	# Call LLM without grammar (useGrammar = false)
	LlamaService.GenerateResponseAsync(prompt, 500, false)  # 500 tokens for longer story
	print("WorldManager: Sent battle story generation request to LlamaService")

func _construct_battle_story_prompt(attacker_faction: String, battle_result: Dictionary, day: int, attacker_force: Dictionary, defender_force: Dictionary) -> String:
	"""Construct a prompt for battle story generation"""
	var victor = battle_result.get("victor", "defender")
	var defender_losses = battle_result.get("defender_losses", 0)
	var attacker_losses = battle_result.get("attacker_losses", 0)
	var severity = battle_result.get("severity", "moderate")
	
	# Count units for each side
	var attacker_units = attacker_force.get("units", {})
	var defender_units = defender_force.get("units", {})
	var attacker_total = 0
	var defender_total = 0
	for unit_type in attacker_units:
		attacker_total += int(attacker_units[unit_type])
	for unit_type in defender_units:
		defender_total += int(defender_units[unit_type])
	
	var prompt = """You are a storyteller describing a medieval battle. Write a vivid, engaging narrative of the battle that just occurred.

Battle Information:
- Attacker: %s
- Defender: Village (Köy)
- Day: %d
- Victor: %s
- Attacker Forces: %d total units (Infantry: %d, Archers: %d)
- Defender Forces: %d total units (Soldiers: %d)
- Attacker Losses: %d units
- Defender Losses: %d units
- Battle Severity: %s

Write a compelling 2-3 paragraph story describing:
1. How the battle began and the initial clash
2. The key moments and turning points
3. The final outcome and its impact

Make it dramatic, immersive, and appropriate for a medieval fantasy setting. Write in third person past tense. Do not include any JSON formatting or special markers - just write the story directly.""" % [
		attacker_faction,
		day,
		"Village defenders" if victor == "defender" else attacker_faction,
		attacker_total,
		int(attacker_units.get("infantry", 0)),
		int(attacker_units.get("archers", 0)),
		defender_total,
		int(defender_units.get("soldiers", 0)),
		attacker_losses,
		defender_losses,
		severity
	]
	
	return prompt

func _on_battle_story_generated(story: String) -> void:
	"""Handle LLM response for battle story generation"""
	if _pending_battle_story_data.is_empty():
		# This response might be for NPC dialogue, ignore it
		return
	
	# Battle stories should be free text, not JSON
	# If the response looks like JSON (starts with {), it's probably for NPC dialogue
	var trimmed_story = story.strip_edges()
	if trimmed_story.begins_with("{"):
		# This is likely a JSON response for NPC dialogue, not a battle story
		return
	
	if trimmed_story.is_empty():
		print("WorldManager: Empty battle story received from LLM")
		_pending_battle_story_data = {}
		return
	
	var battle_data = _pending_battle_story_data.duplicate()
	_pending_battle_story_data = {}
	
	print("WorldManager: Battle story generated: ", trimmed_story)
	
	# Emit signal with the generated story
	battle_story_generated.emit(trimmed_story, battle_data)
	
	# Optionally, you could also post it as news or store it somewhere
	# For now, we just emit the signal so other systems can use it

# === DEBUG/TEST FUNCTION ===
func test_battle(attacker_faction: String = "Kuzey") -> void:
	"""Test function to immediately trigger a battle for testing battle story generation"""
	var tm = get_node_or_null("/root/TimeManager")
	var current_day = tm.get_day() if tm and tm.has_method("get_day") else 1
	print("🧪 TEST: Triggering immediate battle from %s" % attacker_faction)
	_execute_village_defense(attacker_faction, current_day)

# === Ofansif Raid Sistemi (Hostile koylere baskin gorevi) ===
const OFFENSIVE_RAID_GOLD_COST: int = 150
const OFFENSIVE_RAID_MIN_SOLDIERS: int = 3
const OFFENSIVE_RAID_RELATION_PENALTY: int = -8

func get_offensive_raid_options(settlement_id: String) -> Array[Dictionary]:
	if not is_settlement_hostile_to_player(settlement_id):
		return []
	var s_name: String = _get_settlement_display_name(settlement_id)
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	var gold: int = int(gpd.gold) if gpd else 0
	var mm: Node = get_node_or_null("/root/MissionManager")
	var soldier_count: int = 0
	if mm and mm.has_method("_get_player_military_force"):
		var force: Dictionary = mm._get_player_military_force()
		soldier_count = int(force.get("units", {}).get("soldiers", 0))
	var can_afford: bool = gold >= OFFENSIVE_RAID_GOLD_COST
	var has_soldiers: bool = soldier_count >= OFFENSIVE_RAID_MIN_SOLDIERS
	var difficulty: String = "hard"
	var rel: int = get_relation("Köy", s_name)
	if rel <= -30:
		difficulty = "medium"
	return [{
		"id": "offensive_raid",
		"label": "Baskin Duzenle (%s)" % s_name,
		"cost_gold": OFFENSIVE_RAID_GOLD_COST,
		"min_soldiers": OFFENSIVE_RAID_MIN_SOLDIERS,
		"current_soldiers": soldier_count,
		"can_afford": can_afford,
		"has_soldiers": has_soldiers,
		"enabled": can_afford and has_soldiers,
		"difficulty": difficulty,
		"settlement_id": settlement_id,
		"settlement_name": s_name,
		"reason": "" if (can_afford and has_soldiers) else ("Yetersiz altin" if not can_afford else "Yetersiz asker (%d/%d)" % [soldier_count, OFFENSIVE_RAID_MIN_SOLDIERS])
	}]

func launch_offensive_raid(settlement_id: String) -> Dictionary:
	var result: Dictionary = {"success": false, "reason": "", "mission_id": ""}
	var options: Array[Dictionary] = get_offensive_raid_options(settlement_id)
	if options.is_empty() or not bool(options[0].get("enabled", false)):
		result["reason"] = options[0].get("reason", "not_hostile") if not options.is_empty() else "not_hostile"
		return result
	var opt: Dictionary = options[0]
	var s_name: String = String(opt.get("settlement_name", ""))
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if gpd:
		gpd.gold = max(0, int(gpd.gold) - OFFENSIVE_RAID_GOLD_COST)
	change_relation("Köy", s_name, OFFENSIVE_RAID_RELATION_PENALTY, false)
	var tm: Node = get_node_or_null("/root/TimeManager")
	var day: int = tm.get_day() if tm and tm.has_method("get_day") else 1
	var mm: Node = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("create_raid_mission"):
		var mission: Dictionary = mm.create_raid_mission(s_name, day, String(opt.get("difficulty", "medium")), "offensive_hostile", settlement_id)
		result["success"] = true
		result["mission_id"] = String(mission.get("id", ""))
		_post_world_news({
			"category": "world",
			"subcategory": "warning",
			"title": "Ofansif Baskin Emri",
			"content": "%s koyune karsi baskin gorevi olusturuldu. Cariye atayarak gorevi baslatabilirsin." % s_name,
			"day": day
		})
	else:
		result["reason"] = "no_mission_manager"
	world_map_updated.emit()
	return result

func get_offensive_raid_result_effects(settlement_id: String, success: bool) -> Dictionary:
	var s_name: String = _get_settlement_display_name(settlement_id)
	if success:
		if world_settlement_states.has(settlement_id):
			var state: Dictionary = world_settlement_states[settlement_id]
			state["security"] = clamp(int(state.get("security", 60)) - 10, 5, 100)
			state["food_stock"] = clamp(int(state.get("food_stock", 80)) - 15, 5, 200)
			state["stability"] = clamp(int(state.get("stability", 60)) - 5, 5, 100)
			world_settlement_states[settlement_id] = state
		change_relation("Köy", s_name, -5, false)
		return {"gold_loot": randi_range(150, 400), "food_loot": randi_range(5, 15), "relation_change": -5, "target_weakened": true}
	else:
		change_relation("Köy", s_name, -3, false)
		return {"gold_loot": 0, "food_loot": 0, "relation_change": -3, "target_weakened": false}
