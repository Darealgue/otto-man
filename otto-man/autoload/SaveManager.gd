extends Node

## SaveManager - Merkezi kayıt/yükleme yöneticisi
## Beta Yol Haritası FAZ 2: Save/Load Sistemi

const SAVE_VERSION: String = "0.1.0"
const SAVE_DIR: String = "user://otto-man-save/"
const MAX_SAVE_SLOTS: int = 5

signal save_completed(slot_id: int, success: bool)
signal load_completed(slot_id: int, success: bool)
signal error_occurred(error_message: String, error_type: String)  # error_type: "save", "load", "validation"

var _playtime_start: int = 0  # Time when game started (OS.get_ticks_msec())
var _total_playtime_seconds: int = 0  # Accumulated playtime from loaded saves

func _ready() -> void:
	_ensure_save_directory()
	_playtime_start = Time.get_ticks_msec()

func _ensure_save_directory() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("otto-man-save"):
			var error = dir.make_dir("otto-man-save")
			if error != OK:
				push_error("[SaveManager] Failed to create save directory: %s" % SAVE_DIR)
			else:
				print("[SaveManager] Created save directory: %s" % SAVE_DIR)
	else:
		push_error("[SaveManager] Failed to open user:// directory")

func _news_entry_for_save(entry: Dictionary) -> Dictionary:
	var d: Dictionary = entry.duplicate(true)
	for key in ["color", "original_color"]:
		if not d.has(key):
			continue
		var v = d[key]
		if v is Color:
			var c: Color = v
			d[key] = {"__gg_color": true, "r": c.r, "g": c.g, "b": c.b, "a": c.a}
	return d

func _news_entry_from_save(entry: Dictionary) -> Dictionary:
	var d: Dictionary = entry.duplicate(true)
	for key in ["color", "original_color"]:
		if not d.has(key):
			continue
		var v = d[key]
		if v is Dictionary and (v as Dictionary).get("__gg_color", false):
			var cd: Dictionary = v
			d[key] = Color(float(cd.get("r", 1)), float(cd.get("g", 1)), float(cd.get("b", 1)), float(cd.get("a", 1)))
	return d

func _infer_next_mission_id_floor() -> int:
	var max_tail := 0
	if not is_instance_valid(MissionManager) or not "missions" in MissionManager:
		return 1
	for mid in MissionManager.missions.keys():
		var s := str(mid)
		var pos := s.rfind("_")
		if pos < 0 or pos >= s.length() - 1:
			continue
		var tail := s.substr(pos + 1)
		if tail.is_valid_int():
			var n := int(tail)
			if n > max_tail:
				max_tail = n
	return max_tail + 1

func save_game(slot_id: int) -> bool:
	"""Ana kayıt fonksiyonu. Slot ID'ye göre kaydeder (1-5)"""
	if slot_id < 1 or slot_id > MAX_SAVE_SLOTS:
		push_error("[SaveManager] Invalid slot_id: %d (must be 1-%d)" % [slot_id, MAX_SAVE_SLOTS])
		return false
	
	var save_data: Dictionary = {}
	
	# Metadata
	var current_time = Time.get_datetime_dict_from_system()
	save_data["version"] = SAVE_VERSION
	save_data["save_date"] = _format_datetime(current_time)
	save_data["playtime_seconds"] = _calculate_current_playtime()
	
	# Scene state
	if is_instance_valid(SceneManager):
		save_data["scene"] = SceneManager.current_scene_path
		save_data["scene_path"] = SceneManager.current_scene_path
	else:
		save_data["scene"] = ""
		save_data["scene_path"] = ""
	
	# Village state
	save_data["village"] = _save_village_state()
	
	# Mission state
	save_data["missions"] = _save_mission_state()
	
	# World state
	save_data["world"] = _save_world_state()
	
	# Player state
	save_data["player"] = _save_player_state()
	
	# Time state
	save_data["time"] = _save_time_state()
	
	# Weather state
	save_data["weather"] = _save_weather_state()
	
	# Save to file
	var file_path = SAVE_DIR + "save_%d.json" % slot_id
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		var error_msg = "Kayıt dosyası açılamadı. Disk alanı yetersiz olabilir veya yazma izni olmayabilir."
		push_error("[SaveManager] Failed to open file for writing: %s" % file_path)
		error_occurred.emit(error_msg, "save")
		save_completed.emit(slot_id, false)
		return false
	
	var json_string = JSON.stringify(save_data, "\t")
	if json_string.is_empty():
		var error_msg = "Kayıt verisi JSON'a dönüştürülemedi."
		push_error("[SaveManager] Failed to stringify save data")
		error_occurred.emit(error_msg, "save")
		file.close()
		save_completed.emit(slot_id, false)
		return false
	
	file.store_string(json_string)
	var store_error = file.get_error()
	file.close()
	
	if store_error != OK:
		var error_msg = "Kayıt dosyasına yazılamadı. Disk alanı yetersiz olabilir."
		push_error("[SaveManager] Failed to write to file: %s (error: %d)" % [file_path, store_error])
		error_occurred.emit(error_msg, "save")
		save_completed.emit(slot_id, false)
		return false
	
	print("[SaveManager] ✅ Game saved to slot %d: %s" % [slot_id, file_path])
	save_completed.emit(slot_id, true)
	return true

func load_game(slot_id: int) -> bool:
	"""Ana yükleme fonksiyonu. Slot ID'ye göre yükler (1-5)"""
	if slot_id < 1 or slot_id > MAX_SAVE_SLOTS:
		push_error("[SaveManager] Invalid slot_id: %d (must be 1-%d)" % [slot_id, MAX_SAVE_SLOTS])
		return false
	
	var file_path = SAVE_DIR + "save_%d.json" % slot_id
	if not FileAccess.file_exists(file_path):
		push_error("[SaveManager] Save file does not exist: %s" % file_path)
		load_completed.emit(slot_id, false)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[SaveManager] Failed to open file for reading: %s" % file_path)
		load_completed.emit(slot_id, false)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	# Validate file is not empty
	if json_string.is_empty():
		var error_msg = "Kayıt dosyası boş. Dosya bozulmuş olabilir."
		push_error("[SaveManager] %s" % error_msg)
		error_occurred.emit(error_msg, "validation")
		load_completed.emit(slot_id, false)
		return false
	
	var json = JSON.new()
	var parse_error = json.parse(json_string)
	if parse_error != OK:
		var error_msg = "Kayıt dosyası okunamıyor. JSON formatı hatalı olabilir."
		push_error("[SaveManager] Failed to parse JSON: %s (error: %d)" % [file_path, parse_error])
		error_occurred.emit(error_msg, "validation")
		load_completed.emit(slot_id, false)
		return false
	
	var save_data: Dictionary = json.get_data()
	if not save_data is Dictionary:
		var error_msg = "Kayıt dosyası formatı geçersiz. Dosya bozulmuş olabilir."
		push_error("[SaveManager] Save data is not a dictionary: %s" % file_path)
		error_occurred.emit(error_msg, "validation")
		load_completed.emit(slot_id, false)
		return false
	
	# Validate save data structure
	var validation_result = _validate_save_data(save_data)
	if not validation_result["valid"]:
		var error_msg = validation_result.get("error", "Kayıt dosyası doğrulanamadı.")
		push_error("[SaveManager] Validation failed: %s" % error_msg)
		error_occurred.emit(error_msg, "validation")
		load_completed.emit(slot_id, false)
		return false
	
	# Version check (for future compatibility)
	var version = save_data.get("version", "0.0.0")
	if version != SAVE_VERSION:
		print("[SaveManager] ⚠️ Version mismatch: Save=%s, Current=%s" % [version, SAVE_VERSION])
		# For now, we'll try to load anyway, but warn user
		var version_warning = "Kayıt dosyası farklı bir oyun sürümünden. Yükleme denenecek."
		print("[SaveManager] %s" % version_warning)
	
	# Load playtime
	_total_playtime_seconds = save_data.get("playtime_seconds", 0)
	_playtime_start = Time.get_ticks_msec()
	
	# Load scene state
	var scene_path = save_data.get("scene_path", "")
	if scene_path.is_empty():
		scene_path = save_data.get("scene", "")
	
	# Load all states
	_load_village_state(save_data.get("village", {}))
	_load_mission_state(save_data.get("missions", {}))
	if is_instance_valid(VillageManager) and VillageManager.has_method("reapply_active_event_effects"):
		VillageManager.reapply_active_event_effects(true)
	if is_instance_valid(VillageManager):
		VillageManager.set("_production_multipliers_restored_from_save", false)
	_sanitize_loaded_mission_runtime_state()
	_load_world_state(save_data.get("world", {}))
	_load_player_state(save_data.get("player", {}))
	_load_time_state(save_data.get("time", {}))
	_load_weather_state(save_data.get("weather", {}))
	
	var tm_after: Node = get_node_or_null("/root/TimeManager")
	if tm_after != null and tm_after.has_method("get_day"):
		var loaded_day: int = int(tm_after.get_day())
		if is_instance_valid(MissionManager):
			if MissionManager.has_method("prune_time_limited_state_for_day"):
				MissionManager.prune_time_limited_state_for_day(loaded_day, true)
			if "_last_tick_day" in MissionManager:
				MissionManager.set("_last_tick_day", loaded_day)
		var world_after: Node = get_node_or_null("/root/WorldManager")
		if is_instance_valid(world_after) and "_last_tick_day" in world_after:
			world_after.set("_last_tick_day", loaded_day)
	
	# Change to saved scene
	if not scene_path.is_empty() and is_instance_valid(SceneManager):
		# Use call_deferred to ensure all autoloads are ready
		call_deferred("_change_to_saved_scene", scene_path)
	else:
		# Default to village if no scene saved
		if is_instance_valid(SceneManager):
			call_deferred("_change_to_saved_scene", SceneManager.VILLAGE_SCENE)
	
	print("[SaveManager] ✅ Game loaded from slot %d" % slot_id)
	load_completed.emit(slot_id, true)
	return true

func _change_to_saved_scene(scene_path: String) -> void:
	if not is_instance_valid(SceneManager):
		push_error("[SaveManager] SceneManager not available")
		return
	if not ResourceLoader.exists(scene_path):
		push_error("[SaveManager] Scene path does not exist: %s" % scene_path)
		# Fallback to village
		if SceneManager.has_method("change_to_village"):
			SceneManager.change_to_village({})
		return
	
	print("[SaveManager] Changing to saved scene: %s" % scene_path)
	if is_instance_valid(VillageManager) and VillageManager.has_method("schedule_skip_next_snapshot"):
		VillageManager.schedule_skip_next_snapshot()
	# Use SceneManager's public methods
	if scene_path == SceneManager.VILLAGE_SCENE:
		if SceneManager.has_method("change_to_village"):
			SceneManager.change_to_village({}, true)
	elif scene_path == SceneManager.DUNGEON_SCENE:
		if SceneManager.has_method("change_to_dungeon"):
			SceneManager.change_to_dungeon({}, true)
	elif scene_path == SceneManager.FOREST_SCENE:
		if SceneManager.has_method("change_to_forest"):
			SceneManager.change_to_forest({}, true)
	else:
		# For other scenes, try to use start_new_game or fallback
		print("[SaveManager] Unknown scene path, defaulting to village: %s" % scene_path)
		if SceneManager.has_method("change_to_village"):
			SceneManager.change_to_village({})

# === SAVE HELPERS ===

func _save_village_state() -> Dictionary:
	print("[SaveManager] 💾 DEBUG: Starting _save_village_state()")
	var state: Dictionary = {}
	
	if not is_instance_valid(VillageManager):
		push_warning("[SaveManager] VillageManager not available")
		return state
	
	state["village_global_multiplier"] = VillageManager.global_multiplier
	state["village_resource_prod_multiplier"] = VillageManager.resource_prod_multiplier.duplicate(true)
	state["village_morale"] = VillageManager.village_morale
	state["economy_stats_last_day"] = VillageManager.economy_stats_last_day.duplicate(true)
	state["village_last_econ_tick_day"] = VillageManager._last_econ_tick_day
	state["village_last_event_check_day"] = VillageManager._last_village_event_check_day
	if "_event_cooldowns" in VillageManager:
		state["village_event_gen_cooldowns"] = VillageManager.get("_event_cooldowns").duplicate(true)
	state["village_last_day_shortages"] = VillageManager._last_day_shortages.duplicate(true)
	state["village_daily_event_chance"] = VillageManager.village_daily_event_chance
	
	# Resources
	state["resources"] = VillageManager.resource_levels.duplicate(true)
	state["production_progress"] = VillageManager.base_production_progress.duplicate(true)
	print("[SaveManager] 💾 DEBUG: Resources saved: %s" % str(state["resources"]))
	
	# Buildings (use saved building states if available, otherwise snapshot current state)
	var building_states: Array = []
	if VillageManager.has_method("snapshot_state_for_scene_exit"):
		print("[SaveManager] 💾 DEBUG: Calling snapshot_state_for_scene_exit()...")
		VillageManager.snapshot_state_for_scene_exit()
		# Get saved building states
		var saved_states = VillageManager.get("_saved_building_states")
		if saved_states is Array:
			building_states = saved_states.duplicate(true)
			print("[SaveManager] 💾 DEBUG: Got %d building states from snapshot" % building_states.size())
		else:
			print("[SaveManager] ⚠️ DEBUG: _saved_building_states is not an Array: %s" % str(saved_states))
	else:
		# Fallback: try to get building states directly
		if "village_scene_instance" in VillageManager and is_instance_valid(VillageManager.village_scene_instance):
			var placed_buildings = VillageManager.village_scene_instance.get_node_or_null("PlacedBuildings")
			if placed_buildings:
				for building in placed_buildings.get_children():
					if building is Node2D:
						var entry: Dictionary = {
							"scene_path": building.scene_file_path,
							"position": building.global_position
						}
						if "level" in building:
							entry["level"] = building.level
						building_states.append(entry)
	
	state["buildings"] = building_states
	print("[SaveManager] 💾 DEBUG: Saved %d buildings to state" % building_states.size())
	for i in range(min(building_states.size(), 5)):  # İlk 5 binayı logla
		var b = building_states[i]
		print("[SaveManager] 💾 DEBUG: Building %d - Path: %s, Level: %s, Workers: %s" % [
			i + 1,
			b.get("scene_path", "unknown"),
			b.get("level", "N/A"),
			b.get("assigned_workers", 0)
		])
	
	# Workers
	var worker_states: Array = []
	if "_saved_worker_states" in VillageManager and VillageManager._saved_worker_states is Array:
		worker_states = VillageManager._saved_worker_states.duplicate(true)
		print("[SaveManager] 💾 DEBUG: Saved %d workers to state" % worker_states.size())
	else:
		print("[SaveManager] ⚠️ DEBUG: _saved_worker_states not found or not Array")
	state["workers"] = worker_states
	if is_instance_valid(VillagerAiInitializer):
		var saved_infos = VillagerAiInitializer.get_saved_villagers_copy()
		state["villager_saved_infos"] = saved_infos
		state["villager_pool"] = VillagerAiInitializer.get_villager_pool_copy()
		VillagerAiInitializer.save_array_to_json(saved_infos, "Saved_Villagers.json")
	
	# Village events
	if "village_events_enabled" in VillageManager:
		state["village_events_enabled"] = VillageManager.get("village_events_enabled")
	else:
		state["village_events_enabled"] = true
	if "_village_event_cooldowns" in VillageManager:
		state["village_event_cooldowns"] = VillageManager.get("_village_event_cooldowns").duplicate(true)
	else:
		state["village_event_cooldowns"] = {}
	# Aktif köy event'leri (bandit_activity vb.) - yüklemede effect'ler yeniden uygulanacak
	state["events_active"] = []
	if "events_active" in VillageManager:
		var ev_arr = VillageManager.get("events_active")
		if ev_arr is Array:
			for ev in ev_arr:
				if ev is Dictionary:
					state["events_active"].append(ev.duplicate(true))
	
	# Save snapshot/meta data
	if VillageManager._saved_snapshot_time is Dictionary and not VillageManager._saved_snapshot_time.is_empty():
		state["snapshot_time"] = VillageManager._saved_snapshot_time.duplicate(true)
	else:
		state["snapshot_time"] = {}
	
	if is_instance_valid(VillageManager) and VillageManager.has_method("get_pending_constructions_save_data"):
		state["pending_constructions"] = VillageManager.get_pending_constructions_save_data()
	else:
		state["pending_constructions"] = []
	
	return state

func _save_mission_state() -> Dictionary:
	var state: Dictionary = {}
	
	if not is_instance_valid(MissionManager):
		push_warning("[SaveManager] MissionManager not available")
		return state
	
	# Active missions (Dictionary: mission_id -> mission_data)
	state["active_missions"] = []
	state["active_mission_assignments"] = [] # [{cariye_id:int, mission_id:String}]
	if "active_missions" in MissionManager:
		var active = MissionManager.active_missions
		if active is Dictionary:
			# Canonical format: active_missions is cariye_id -> mission_id mapping.
			for cariye_id in active.keys():
				var mission_id = active[cariye_id]
				state["active_mission_assignments"].append({
					"cariye_id": int(cariye_id),
					"mission_id": str(mission_id)
				})
				# Keep legacy mirror for backward compatibility.
				state["active_missions"].append({
					"cariye_id": int(cariye_id),
					"mission_id": str(mission_id)
				})
		elif active is Array:
			# Legacy format support
			for mission in active:
				if mission is Dictionary:
					state["active_missions"].append(mission.duplicate(true))
				else:
					state["active_missions"].append(mission)
	
	# Completed missions (Array[String])
	state["completed_missions"] = []
	if "completed_missions" in MissionManager:
		var completed = MissionManager.completed_missions
		if completed is Array:
			for mission in completed:
				# Store mission ID as string
				if mission is String:
					state["completed_missions"].append(mission)
				elif mission is Dictionary and "id" in mission:
					state["completed_missions"].append(str(mission["id"]))
				else:
					state["completed_missions"].append(str(mission))
	
	# Concubines (cariyeler) - Tam statları kaydet
	state["concubines"] = []
	if "concubines" in MissionManager:
		var concubines_dict = MissionManager.concubines
		for cariye_id in concubines_dict.keys():
			var cariye = concubines_dict[cariye_id]
			if cariye.has_method("to_dict"):
				# Debug: Save edilmeden önce görünüm durumunu kontrol et
				if cariye.appearance == null:
					printerr("[SaveManager] ⚠️ Cariye %d görünümü NULL (save edilmeden önce)! Bu bir sorun!" % cariye_id)
				else:
					print("[SaveManager] 🔍 Cariye %d görünümü var, to_dict() çağrılıyor..." % cariye_id)
				
				var cariye_data = cariye.to_dict()
				
				# Debug: Appearance kaydediliyor mu kontrol et
				if cariye.appearance != null:
					if not cariye_data.has("appearance"):
						printerr("[SaveManager] ⚠️ Cariye %d görünümü to_dict() sonrası dict'te yok!" % cariye_id)
					elif cariye_data["appearance"] == null:
						printerr("[SaveManager] ⚠️ Cariye %d görünümü to_dict() sonrası null!" % cariye_id)
					else:
						print("[SaveManager] ✅ Cariye %d görünümü kaydedildi (dict size: %d)" % [cariye_id, cariye_data["appearance"].size() if cariye_data["appearance"] is Dictionary else 0])
				else:
					printerr("[SaveManager] ⚠️ Cariye %d görünümü null, kaydedilemiyor!" % cariye_id)
				state["concubines"].append({"id": cariye_id, "data": cariye_data})
			elif "name" in cariye:
				# Fallback: Eski format
				var cariye_data: Dictionary = {}
				cariye_data["name"] = cariye.name
				if "role" in cariye:
					cariye_data["role"] = int(cariye.role) if cariye.role is int else 0
				state["concubines"].append({"id": cariye_id, "data": cariye_data})
	
	# Trade agreements
	state["trade_agreements"] = []
	if "trade_agreements" in MissionManager:
		state["trade_agreements"] = MissionManager.trade_agreements.duplicate(true)

	# World map returning mission units (for map continuity after load)
	state["world_map_returning_units"] = {}
	if "_world_map_returning_units" in MissionManager:
		var returning_units = MissionManager.get("_world_map_returning_units")
		if returning_units is Dictionary:
			state["world_map_returning_units"] = returning_units.duplicate(true)
	if "_raid_mission_extra" in MissionManager:
		state["mm_raid_mission_extra"] = MissionManager.get("_raid_mission_extra").duplicate(true)
	
	# Dinamik görevler: relief / worldmap / olay / aktif atama
	var active_mission_ids: Dictionary = {}
	if "active_missions" in MissionManager and MissionManager.active_missions is Dictionary:
		for _ck in MissionManager.active_missions.keys():
			var _mid: String = str(MissionManager.active_missions[_ck])
			if not _mid.is_empty():
				active_mission_ids[_mid] = true
	state["persisted_mission_snapshots"] = _collect_persisted_mission_snapshots(active_mission_ids)
	
	# Komşu ekonomi / rotalar (WM ile relation ayri senkron; stability vb. kalici)
	if "settlements" in MissionManager and MissionManager.settlements is Array and not MissionManager.settlements.is_empty():
		var ss_out: Array = []
		for s in MissionManager.settlements:
			if s is Dictionary:
				ss_out.append((s as Dictionary).duplicate(true))
		state["mm_settlements"] = ss_out
	if "trade_routes" in MissionManager:
		var tr_out: Array = []
		for r in MissionManager.trade_routes:
			if r is Dictionary:
				tr_out.append((r as Dictionary).duplicate(true))
		state["mm_trade_routes"] = tr_out
	if "settlement_trade_modifiers" in MissionManager:
		state["mm_settlement_trade_modifiers"] = MissionManager.settlement_trade_modifiers.duplicate(true)
	state["mm_active_traders"] = MissionManager.active_traders.duplicate(true)
	state["mm_active_rate_modifiers"] = MissionManager.active_rate_modifiers.duplicate(true)
	state["mm_player_reputation"] = MissionManager.player_reputation
	state["mm_world_stability"] = MissionManager.world_stability
	state["mm_bandit_activity_active"] = MissionManager.bandit_activity_active
	state["mm_bandit_trade_multiplier"] = MissionManager.bandit_trade_multiplier
	state["mm_bandit_risk_level"] = MissionManager.bandit_risk_level
	if "mission_history" in MissionManager:
		var mh_raw: Array = MissionManager.mission_history
		var mh_out: Array = []
		var mh_cap: int = mini(mh_raw.size(), 80)
		for hi in range(mh_cap):
			var ent = mh_raw[hi]
			if ent is Dictionary:
				mh_out.append((ent as Dictionary).duplicate(true))
		state["mm_mission_history"] = mh_out
	if "world_events" in MissionManager and MissionManager.world_events is Array:
		var we_out: Array = []
		for ev in MissionManager.world_events:
			if ev is Dictionary:
				we_out.append((ev as Dictionary).duplicate(true))
		state["mm_world_events"] = we_out
	if "world_events_timer" in MissionManager:
		state["mm_world_events_timer"] = float(MissionManager.world_events_timer)
	if "world_events_interval" in MissionManager:
		state["mm_world_events_interval"] = float(MissionManager.world_events_interval)
	state["mm_mission_rotation_timer"] = float(MissionManager.mission_rotation_timer)
	if "news_queue_village" in MissionManager:
		var nv_out: Array = []
		for ne in MissionManager.news_queue_village:
			if ne is Dictionary:
				nv_out.append(_news_entry_for_save(ne as Dictionary))
		state["mm_news_queue_village"] = nv_out
	if "news_queue_world" in MissionManager:
		var nw_out: Array = []
		for ne2 in MissionManager.news_queue_world:
			if ne2 is Dictionary:
				nw_out.append(_news_entry_for_save(ne2 as Dictionary))
		state["mm_news_queue_world"] = nw_out
	if MissionManager.get("_next_news_id") != null:
		state["mm_next_news_id"] = int(MissionManager.get("_next_news_id"))
	state["mm_next_mission_id"] = MissionManager.next_mission_id
	var unm: Variant = MissionManager.get("_used_names")
	if unm is Array:
		state["mm_used_names"] = (unm as Array).duplicate()
	if "mission_chains" in MissionManager:
		var mcf: Dictionary = {}
		for ck in MissionManager.mission_chains.keys():
			var ch: Variant = MissionManager.mission_chains[ck]
			if ch is Dictionary:
				mcf[str(ck)] = bool((ch as Dictionary).get("completed", false))
		state["mm_mission_chain_completed"] = mcf
	
	return state

func _save_world_state() -> Dictionary:
	var state: Dictionary = {}
	
	var world_manager = get_node_or_null("/root/WorldManager")
	if not is_instance_valid(world_manager):
		push_warning("[SaveManager] WorldManager not available")
		return state
	
	# Settlement relations (check if it exists as a property)
	state["settlement_relations"] = {}
	if "settlement_relations" in world_manager:
		var settlements_val = world_manager.get("settlement_relations")
		if settlements_val is Dictionary:
			state["settlement_relations"] = settlements_val.duplicate(true)
	
	# Active events
	state["active_events"] = []
	if "active_events" in world_manager:
		var events_val = world_manager.get("active_events")
		if events_val is Array:
			for event in events_val:
				if event is Dictionary:
					state["active_events"].append(event.duplicate(true))
	
	# Faction relations (using relations property)
	state["faction_relations"] = {}
	if "relations" in world_manager:
		var relations_val = world_manager.get("relations")
		if relations_val is Dictionary:
			state["faction_relations"] = relations_val.duplicate(true)

	# Hex map state (vertical slice)
	state["world_map"] = {}
	if world_manager.has_method("get_world_map_state"):
		state["world_map"] = world_manager.get_world_map_state()
	
	return state

func _save_player_state() -> Dictionary:
	var state: Dictionary = {}
	
	# GlobalPlayerData
	if is_instance_valid(GlobalPlayerData):
		state["gold"] = GlobalPlayerData.gold
		state["asker_sayisi"] = GlobalPlayerData.asker_sayisi
		state["envanter"] = GlobalPlayerData.envanter.duplicate(true)
		state["iliskiler"] = GlobalPlayerData.iliskiler.duplicate(true)
	
	# PlayerStats
	if is_instance_valid(PlayerStats):
		state["base_stats"] = PlayerStats.base_stats.duplicate(true)
		state["stat_multipliers"] = PlayerStats.stat_multipliers.duplicate(true)
		state["stat_bonuses"] = PlayerStats.stat_bonuses.duplicate(true)
		state["current_health"] = PlayerStats.current_health
		if PlayerStats.has_method("get_world_expedition_supplies"):
			state["world_expedition_supplies"] = PlayerStats.call("get_world_expedition_supplies").duplicate(true)
		state["carried_resources"] = PlayerStats.carried_resources.duplicate(true)
	
	return state

func _save_time_state() -> Dictionary:
	var state: Dictionary = {}
	
	if is_instance_valid(TimeManager):
		state["days"] = TimeManager.days if "days" in TimeManager else 1
		state["hours"] = TimeManager.hours if "hours" in TimeManager else 0
		state["minutes"] = TimeManager.minutes if "minutes" in TimeManager else 0
	
	return state

func _save_weather_state() -> Dictionary:
	var state: Dictionary = {}
	
	if is_instance_valid(WeatherManager):
		state["storm_active"] = WeatherManager.storm_active
		state["storm_level"] = WeatherManager.storm_level
		state["rain_intensity"] = WeatherManager.rain_intensity
		state["wind_strength"] = WeatherManager.wind_strength
		state["wind_direction_angle"] = WeatherManager.wind_direction_angle
	
	return state

# === LOAD HELPERS ===

func _load_village_state(state: Dictionary) -> void:
	print("[SaveManager] 🔄 DEBUG: Starting _load_village_state()")
	print("[SaveManager] 🔍 DEBUG: State keys: %s" % str(state.keys()))
	
	if not is_instance_valid(VillageManager):
		push_warning("[SaveManager] VillageManager not available")
		return
	
	VillageManager.set("_production_multipliers_restored_from_save", false)
	var prod_loaded := false
	if state.has("village_global_multiplier"):
		VillageManager.global_multiplier = float(state["village_global_multiplier"])
		prod_loaded = true
	if state.has("village_resource_prod_multiplier"):
		var vr: Variant = state["village_resource_prod_multiplier"]
		if vr is Dictionary:
			for rk in (vr as Dictionary).keys():
				VillageManager.resource_prod_multiplier[str(rk)] = float((vr as Dictionary)[rk])
			prod_loaded = true
	if state.has("village_morale"):
		VillageManager.village_morale = float(state["village_morale"])
	if prod_loaded:
		VillageManager.set("_production_multipliers_restored_from_save", true)
	if state.has("economy_stats_last_day"):
		var es: Variant = state["economy_stats_last_day"]
		if es is Dictionary:
			VillageManager.economy_stats_last_day = (es as Dictionary).duplicate(true)
	if state.has("village_last_econ_tick_day"):
		VillageManager._last_econ_tick_day = int(state["village_last_econ_tick_day"])
	if state.has("village_last_event_check_day"):
		VillageManager._last_village_event_check_day = int(state["village_last_event_check_day"])
	if state.has("village_event_gen_cooldowns"):
		var ge: Variant = state["village_event_gen_cooldowns"]
		if ge is Dictionary:
			VillageManager.set("_event_cooldowns", (ge as Dictionary).duplicate(true))
	if state.has("village_last_day_shortages"):
		var lds: Variant = state["village_last_day_shortages"]
		if lds is Dictionary:
			VillageManager._last_day_shortages = (lds as Dictionary).duplicate(true)
	if state.has("village_daily_event_chance"):
		VillageManager.village_daily_event_chance = clampf(float(state["village_daily_event_chance"]), 0.0, 1.0)
	
	# Resources
	if state.has("resources"):
		var resources = state["resources"]
		if resources is Dictionary:
			VillageManager.resource_levels = resources.duplicate(true)
			VillageManager._saved_resource_levels = VillageManager.resource_levels.duplicate(true)
			print("[SaveManager] ✅ DEBUG: Resources loaded: %s" % str(VillageManager.resource_levels))
		else:
			print("[SaveManager] ⚠️ DEBUG: Resources is not a Dictionary: %s" % str(resources))
	else:
		print("[SaveManager] ⚠️ DEBUG: State has no 'resources' key")
	if state.has("production_progress"):
		var progress = state["production_progress"]
		if progress is Dictionary:
			VillageManager.base_production_progress = progress.duplicate(true)
			VillageManager._saved_base_production_progress = VillageManager.base_production_progress.duplicate(true)
			print("[SaveManager] ✅ DEBUG: Production progress loaded")
		else:
			print("[SaveManager] ⚠️ DEBUG: Production progress is not a Dictionary")
		VillageManager._saved_base_production_progress = VillageManager.base_production_progress.duplicate(true)
	
	# Building states (will be restored when village scene loads)
	if state.has("buildings"):
		var raw_buildings = state["buildings"]
		print("[SaveManager] 🔍 DEBUG: Found 'buildings' in state, type: %s, size: %d" % [typeof(raw_buildings), raw_buildings.size() if raw_buildings is Array else 0])
		if raw_buildings is Array:
			var converted_buildings: Array = []
			print("[SaveManager] 🔄 DEBUG: Converting %d buildings..." % raw_buildings.size())
			for i in range(raw_buildings.size()):
				var raw_entry = raw_buildings[i]
				if raw_entry is Dictionary:
					var entry: Dictionary = raw_entry.duplicate(true)
					var scene_path = entry.get("scene_path", "unknown")
					print("[SaveManager] 🔄 DEBUG: Converting building %d: %s" % [i + 1, scene_path.get_file()])
					if entry.has("position"):
						entry["position"] = _to_vector2(entry.get("position"))
					if entry.has("global_position"):
						entry["global_position"] = _to_vector2(entry.get("global_position"))
						print("[SaveManager] 📍 DEBUG: Building %d global_position: %s" % [i + 1, str(entry["global_position"])])
					if entry.has("local_position"):
						entry["local_position"] = _to_vector2(entry.get("local_position"))
					if entry.has("level"):
						print("[SaveManager] 📊 DEBUG: Building %d level: %s" % [i + 1, str(entry.get("level"))])
					if entry.has("assigned_workers"):
						entry["assigned_workers"] = int(entry.get("assigned_workers", 0))
						print("[SaveManager] 👷 DEBUG: Building %d assigned_workers: %d" % [i + 1, entry["assigned_workers"]])
					if entry.has("max_workers"):
						entry["max_workers"] = int(entry.get("max_workers", 0))
						print("[SaveManager] 👷 DEBUG: Building %d max_workers: %d" % [i + 1, entry["max_workers"]])
					if entry.has("assigned_worker_ids") and entry["assigned_worker_ids"] is Array:
						entry["assigned_worker_ids"] = (entry["assigned_worker_ids"] as Array).duplicate(true)
						print("[SaveManager] 👷 DEBUG: Building %d worker_ids: %s" % [i + 1, str(entry["assigned_worker_ids"])])
					converted_buildings.append(entry)
				else:
					print("[SaveManager] ⚠️ DEBUG: Building entry %d is not a Dictionary: %s" % [i + 1, typeof(raw_entry)])
			VillageManager._saved_building_states = converted_buildings
			print("[SaveManager] ✅ DEBUG: Loaded %d buildings into _saved_building_states" % converted_buildings.size())
		else:
			print("[SaveManager] ⚠️ DEBUG: Buildings is not an Array: %s" % typeof(raw_buildings))
			VillageManager._saved_building_states = []
	else:
		print("[SaveManager] ⚠️ DEBUG: State has no 'buildings' key")
		VillageManager._saved_building_states = []
	
	if state.has("pending_constructions"):
		var raw_pc = state["pending_constructions"]
		if raw_pc is Array:
			var converted_pc: Array = []
			for i in range(raw_pc.size()):
				var raw_e = raw_pc[i]
				if raw_e is Dictionary:
					var pe: Dictionary = (raw_e as Dictionary).duplicate(true)
					if pe.has("position"):
						pe["position"] = _to_vector2(pe.get("position"))
					converted_pc.append(pe)
			if VillageManager:
				VillageManager.set("_pending_constructions_load_buffer", converted_pc)
		else:
			if VillageManager:
				VillageManager.set("_pending_constructions_load_buffer", [])
	else:
		if VillageManager:
			VillageManager.set("_pending_constructions_load_buffer", [])
	
	# Worker states
	var villager_infos: Array = []
	if state.has("workers"):
		var raw_workers = state["workers"]
		if raw_workers is Array:
			var converted_workers: Array = []
			print("[SaveManager] 🔄 DEBUG: Converting %d workers..." % raw_workers.size())
			for i in range(raw_workers.size()):
				var raw_worker = raw_workers[i]
				if raw_worker is Dictionary:
					var worker_entry: Dictionary = raw_worker.duplicate(true)
					var worker_id = worker_entry.get("worker_id", -1)
					var job_type = worker_entry.get("job_type", "")
					var building_key = worker_entry.get("building_key", "")
					print("[SaveManager] 🔄 DEBUG: Converting worker %d - ID: %d, Job: %s, Building: %s" % [i + 1, worker_id, job_type, building_key])
					var npc_info_val = worker_entry.get("npc_info", {})
					if npc_info_val is Dictionary:
						var npc_copy = npc_info_val.duplicate(true)
						worker_entry["npc_info"] = npc_copy
						villager_infos.append(npc_copy)
					else:
						worker_entry["npc_info"] = {}
					worker_entry["building_key"] = String(building_key)
					converted_workers.append(worker_entry)
				else:
					print("[SaveManager] ⚠️ DEBUG: Worker entry %d is not a Dictionary: %s" % [i + 1, typeof(raw_worker)])
			VillageManager._saved_worker_states = converted_workers
			print("[SaveManager] ✅ DEBUG: Loaded %d workers into _saved_worker_states" % converted_workers.size())
		else:
			print("[SaveManager] ⚠️ DEBUG: Workers is not an Array: %s" % typeof(raw_workers))
			VillageManager._saved_worker_states = []
	else:
		print("[SaveManager] ⚠️ DEBUG: State has no 'workers' key")
		VillageManager._saved_worker_states = []

	if is_instance_valid(VillagerAiInitializer):
		var saved_villagers_state: Array = []
		if state.has("villager_saved_infos") and state["villager_saved_infos"] is Array:
			saved_villagers_state = state["villager_saved_infos"]
		else:
			saved_villagers_state = villager_infos
		if state.has("villager_pool") and state["villager_pool"] is Array:
			VillagerAiInitializer.set_villager_pool_from_save(state["villager_pool"])
			VillagerAiInitializer.set_saved_villagers_from_save(saved_villagers_state, false)
		else:
			VillagerAiInitializer.reset_to_defaults()
			VillagerAiInitializer.set_saved_villagers_from_save(saved_villagers_state, true)
		VillagerAiInitializer.save_array_to_json(VillagerAiInitializer.get_saved_villagers_copy(), "Saved_Villagers.json")
	
	# Village events
	if state.has("village_events_enabled"):
		VillageManager.set("village_events_enabled", state["village_events_enabled"])
	if state.has("village_event_cooldowns"):
		VillageManager.set("_village_event_cooldowns", state["village_event_cooldowns"].duplicate(true))
	if state.has("events_active") and state["events_active"] is Array:
		VillageManager.events_active.clear()
		for ev in state["events_active"]:
			if ev is Dictionary:
				VillageManager.events_active.append(ev.duplicate(true))

func _should_persist_mission_snapshot(mission_id: String, mission_obj: Variant, active_mission_ids: Dictionary) -> bool:
	if active_mission_ids.has(mission_id):
		return true
	if mission_id.begins_with("relief_") or mission_id.begins_with("ally_relief_") or mission_id.begins_with("worldmap_"):
		return true
	if mission_id.begins_with("bandit_clear_") or mission_id.begins_with("escort_") or mission_id.begins_with("aid_"):
		return true
	if mission_id.begins_with("defense_") or mission_id.begins_with("raid_"):
		return true
	if mission_obj is Mission:
		var mo: Mission = mission_obj
		return String(mo.completes_incident_id).length() > 0 or String(mo.completes_alliance_aid_settlement_id).length() > 0
	return false

func _collect_persisted_mission_snapshots(active_mission_ids: Dictionary) -> Array:
	var out: Array = []
	if not is_instance_valid(MissionManager) or not "missions" in MissionManager:
		return out
	for mid in MissionManager.missions.keys():
		var mission_id: String = str(mid)
		var m = MissionManager.missions[mid]
		if not _should_persist_mission_snapshot(mission_id, m, active_mission_ids):
			continue
		if m is Mission:
			out.append({"id": mission_id, "kind": "resource", "data": m.to_save_dict()})
		elif m is Dictionary:
			out.append({"id": mission_id, "kind": "dict", "data": m.duplicate(true)})
	return out

func _apply_persisted_mission_snapshots(snapshots: Array) -> void:
	if not is_instance_valid(MissionManager):
		return
	for entry in snapshots:
		if not (entry is Dictionary):
			continue
		var mid: String = str(entry.get("id", ""))
		if mid.is_empty():
			continue
		var kind: String = str(entry.get("kind", "resource"))
		var data: Dictionary = entry.get("data", {})
		if not (data is Dictionary):
			continue
		if kind == "dict":
			MissionManager.missions[mid] = data.duplicate(true)
		else:
			var res = Mission.from_save_dict(data)
			if res:
				MissionManager.missions[mid] = res

func _load_mission_state(state: Dictionary) -> void:
	if not is_instance_valid(MissionManager):
		push_warning("[SaveManager] MissionManager not available")
		return
	
	if state.has("persisted_mission_snapshots"):
		var snaps = state["persisted_mission_snapshots"]
		if snaps is Array:
			_apply_persisted_mission_snapshots(snaps)
	
	# Active missions (canonical mapping: cariye_id -> mission_id)
	if state.has("active_mission_assignments"):
		var loaded_assignments = state["active_mission_assignments"]
		if loaded_assignments is Array:
			var active_dict: Dictionary = {}
			for entry in loaded_assignments:
				if entry is Dictionary and entry.has("cariye_id") and entry.has("mission_id"):
					active_dict[int(entry["cariye_id"])] = str(entry["mission_id"])
			MissionManager.set("active_missions", active_dict)
	elif state.has("active_missions"):
		var loaded_active = state["active_missions"]
		if loaded_active is Array:
			var active_dict_legacy: Dictionary = {}
			for entry in loaded_active:
				if entry is Dictionary and entry.has("cariye_id") and entry.has("mission_id"):
					active_dict_legacy[int(entry["cariye_id"])] = str(entry["mission_id"])
				elif entry is Dictionary and entry.has("id"):
					# Very old fallback - cannot infer cariye safely.
					continue
			MissionManager.set("active_missions", active_dict_legacy)
		elif loaded_active is Dictionary:
			MissionManager.set("active_missions", loaded_active.duplicate(true))
	
	# Completed missions (Array[String])
	if state.has("completed_missions"):
		var loaded_completed = state["completed_missions"]
		if loaded_completed is Array:
			# Convert to Array[String] format
			var completed_array: Array[String] = []
			for mission in loaded_completed:
				if mission is String:
					completed_array.append(mission)
				elif mission is Dictionary and "id" in mission:
					completed_array.append(str(mission["id"]))
				elif mission is Dictionary:
					# Try to find an ID
					for key in ["id", "mission_id", "missionId"]:
						if key in mission:
							completed_array.append(str(mission[key]))
							break
			MissionManager.set("completed_missions", completed_array)
	
	if state.has("mm_mission_chain_completed"):
		var mcf: Variant = state["mm_mission_chain_completed"]
		if mcf is Dictionary and "mission_chains" in MissionManager:
			for ck in (mcf as Dictionary).keys():
				var cks: String = str(ck)
				if not MissionManager.mission_chains.has(cks):
					continue
				var ch: Variant = MissionManager.mission_chains[cks]
				if ch is Dictionary:
					(ch as Dictionary)["completed"] = bool((mcf as Dictionary)[ck])

	# Returning world-map units
	if state.has("world_map_returning_units"):
		var loaded_returning = state["world_map_returning_units"]
		if loaded_returning is Dictionary:
			MissionManager.set("_world_map_returning_units", loaded_returning.duplicate(true))
	else:
		if "_world_map_returning_units" in MissionManager:
			MissionManager.set("_world_map_returning_units", {})
	if state.has("mm_raid_mission_extra"):
		var rxe: Variant = state["mm_raid_mission_extra"]
		if rxe is Dictionary:
			MissionManager.set("_raid_mission_extra", (rxe as Dictionary).duplicate(true))
	
	# Concubines (cariyeler) - Tam statları yükle
	if state.has("concubines"):
		var loaded_concubines = state["concubines"]
		if loaded_concubines is Array and loaded_concubines.size() > 0:
			# Önce mevcut cariyeleri temizle (yeni oyun başlatılıyorsa)
			if "concubines" in MissionManager:
				MissionManager.concubines.clear()
			
			for concubine_entry in loaded_concubines:
				if concubine_entry is Dictionary and "id" in concubine_entry and "data" in concubine_entry:
					# JSON'dan gelen id float (1.0) olabilir; MissionManager int anahtar kullanıyor
					var cariye_id_raw = concubine_entry["id"]
					var cariye_id: int = int(cariye_id_raw) if cariye_id_raw != null else 0
					var cariye_data = concubine_entry["data"]
					
					# Yeni cariye oluştur
					var cariye = Concubine.new()
					if cariye.has_method("from_dict"):
						cariye.from_dict(cariye_data)
					
					# Debug: Appearance yüklendi mi kontrol et
					if cariye_data.has("appearance"):
						if cariye.appearance == null:
							printerr("[SaveManager] ⚠️ Cariye %d görünümü yüklenemedi! Data: %s" % [cariye_id, str(cariye_data.get("appearance"))])
						else:
							print("[SaveManager] ✅ Cariye %d görünümü yüklendi" % cariye_id)
					else:
						printerr("[SaveManager] ⚠️ Cariye %d görünümü save'de yok!" % cariye_id)
					
					# MissionManager'a ekle (anahtar her zaman int olmalı, load sonrası atama çalışsın)
					if "concubines" in MissionManager:
						MissionManager.concubines[cariye_id] = cariye
						# next_concubine_id'yi güncelle
						if "next_concubine_id" in MissionManager:
							var next_id = MissionManager.get("next_concubine_id")
							if next_id is int:
								MissionManager.set("next_concubine_id", max(next_id, cariye_id + 1))
			
			print("[SaveManager] ✅ %d cariye yüklendi" % loaded_concubines.size())
	
	# Trade agreements
	if state.has("trade_agreements"):
		var loaded_trade = state["trade_agreements"]
		if loaded_trade is Array:
			MissionManager.set("trade_agreements", loaded_trade.duplicate(true))
	
	if state.has("mm_settlements"):
		var lsett: Variant = state["mm_settlements"]
		if lsett is Array and not (lsett as Array).is_empty():
			MissionManager.settlements.clear()
			for s in lsett:
				if s is Dictionary:
					MissionManager.settlements.append((s as Dictionary).duplicate(true))
	if state.has("mm_trade_routes"):
		var ltr: Variant = state["mm_trade_routes"]
		if ltr is Array and not (ltr as Array).is_empty():
			MissionManager.trade_routes.clear()
			for r in ltr:
				if r is Dictionary:
					MissionManager.trade_routes.append((r as Dictionary).duplicate(true))
	if state.has("mm_settlement_trade_modifiers"):
		var lmod: Variant = state["mm_settlement_trade_modifiers"]
		if lmod is Array:
			MissionManager.settlement_trade_modifiers.clear()
			for m in lmod:
				if m is Dictionary:
					MissionManager.settlement_trade_modifiers.append((m as Dictionary).duplicate(true))
	if state.has("mm_player_reputation"):
		MissionManager.player_reputation = int(state["mm_player_reputation"])
	if state.has("mm_world_stability"):
		MissionManager.world_stability = int(state["mm_world_stability"])
	if state.has("mm_bandit_activity_active"):
		MissionManager.bandit_activity_active = bool(state["mm_bandit_activity_active"])
	if state.has("mm_bandit_trade_multiplier"):
		MissionManager.bandit_trade_multiplier = float(state["mm_bandit_trade_multiplier"])
	if state.has("mm_bandit_risk_level"):
		MissionManager.bandit_risk_level = int(state["mm_bandit_risk_level"])
	if state.has("mm_active_traders"):
		var lat: Variant = state["mm_active_traders"]
		if lat is Array:
			MissionManager.active_traders.clear()
			for tr in lat:
				if tr is Dictionary:
					MissionManager.active_traders.append((tr as Dictionary).duplicate(true))
	if state.has("mm_active_rate_modifiers"):
		var larm: Variant = state["mm_active_rate_modifiers"]
		if larm is Array:
			MissionManager.active_rate_modifiers.clear()
			for rm in larm:
				if rm is Dictionary:
					MissionManager.active_rate_modifiers.append((rm as Dictionary).duplicate(true))
	if state.has("mm_mission_history"):
		var lmh: Variant = state["mm_mission_history"]
		if lmh is Array:
			MissionManager.mission_history.clear()
			for he in lmh:
				if he is Dictionary:
					MissionManager.mission_history.append((he as Dictionary).duplicate(true))
	if state.has("mm_world_events"):
		var lwe: Variant = state["mm_world_events"]
		if lwe is Array and not (lwe as Array).is_empty():
			MissionManager.world_events.clear()
			for ev in lwe:
				if ev is Dictionary:
					MissionManager.world_events.append((ev as Dictionary).duplicate(true))
	if state.has("mm_world_events_timer"):
		MissionManager.world_events_timer = float(state["mm_world_events_timer"])
	if state.has("mm_world_events_interval"):
		MissionManager.world_events_interval = maxf(1.0, float(state["mm_world_events_interval"]))
	if "world_events_interval" in MissionManager and "world_events_timer" in MissionManager:
		var wcap: float = maxf(1.0, float(MissionManager.world_events_interval))
		MissionManager.world_events_timer = clampf(float(MissionManager.world_events_timer), 0.0, wcap)
	if state.has("mm_mission_rotation_timer"):
		var mrt: float = float(state["mm_mission_rotation_timer"])
		var cap: float = float(MissionManager.mission_rotation_interval) if "mission_rotation_interval" in MissionManager else 30.0
		MissionManager.mission_rotation_timer = clampf(mrt, 0.0, maxf(cap, 0.001))
	if state.has("mm_news_queue_village"):
		var nqv: Variant = state["mm_news_queue_village"]
		if nqv is Array:
			MissionManager.news_queue_village.clear()
			for ent in nqv:
				if ent is Dictionary:
					MissionManager.news_queue_village.append(_news_entry_from_save(ent as Dictionary))
	if state.has("mm_news_queue_world"):
		var nqw: Variant = state["mm_news_queue_world"]
		if nqw is Array:
			MissionManager.news_queue_world.clear()
			for ent in nqw:
				if ent is Dictionary:
					MissionManager.news_queue_world.append(_news_entry_from_save(ent as Dictionary))
	if state.has("mm_next_news_id"):
		MissionManager.set("_next_news_id", int(state["mm_next_news_id"]))
	if state.has("mm_next_mission_id"):
		MissionManager.next_mission_id = int(state["mm_next_mission_id"])
	var floor_id: int = _infer_next_mission_id_floor()
	MissionManager.next_mission_id = maxi(MissionManager.next_mission_id, floor_id)
	if "_used_names" in MissionManager:
		var uarr: Variant = MissionManager.get("_used_names")
		if uarr is Array:
			(uarr as Array).clear()
			if state.has("mm_used_names"):
				var un: Variant = state["mm_used_names"]
				if un is Array:
					for n in un:
						var ns: String = str(n)
						if not ns in uarr:
							(uarr as Array).append(ns)
			if "concubines" in MissionManager:
				for ck in MissionManager.concubines.keys():
					var c = MissionManager.concubines[ck]
					if c != null and "name" in c:
						var nm: String = String(c.name)
						if not nm in uarr:
							(uarr as Array).append(nm)

func _sanitize_loaded_mission_runtime_state() -> void:
	if not is_instance_valid(MissionManager):
		return
	# Active mission assignments: keep only entries that reference existing concubine+mission.
	var sanitized_active: Dictionary = {}
	if "active_missions" in MissionManager:
		var active_raw = MissionManager.get("active_missions")
		if active_raw is Dictionary:
			for cariye_key in active_raw.keys():
				var cariye_id: int = int(cariye_key)
				var mission_id: String = str(active_raw[cariye_key])
				if mission_id.is_empty():
					continue
				if "concubines" in MissionManager and not MissionManager.concubines.has(cariye_id):
					continue
				if "missions" in MissionManager and not MissionManager.missions.has(mission_id):
					continue
				sanitized_active[cariye_id] = mission_id
		MissionManager.set("active_missions", sanitized_active)
		# Reconcile concubine runtime status with active mission mapping.
		if "concubines" in MissionManager:
			for cid_key in MissionManager.concubines.keys():
				var cid: int = int(cid_key)
				var c = MissionManager.concubines[cid_key]
				if c == null:
					continue
				if sanitized_active.has(cid):
					if "current_mission_id" in c:
						c.current_mission_id = String(sanitized_active[cid])
					if "status" in c:
						c.status = 1 # Concubine.Status.GÖREVDE
				else:
					if "current_mission_id" in c:
						c.current_mission_id = ""
					# Only reset if it was mission status; don't clobber injured/resting.
					if "status" in c and int(c.status) == 1:
						c.status = 0 # Concubine.Status.BOŞTA
	# Returning world-map units: enforce schema and drop corrupt entries.
	if "_world_map_returning_units" in MissionManager:
		var returning_raw = MissionManager.get("_world_map_returning_units")
		var sanitized_returning: Dictionary = {}
		if returning_raw is Dictionary:
			for key in returning_raw.keys():
				var entry = returning_raw[key]
				if not (entry is Dictionary):
					continue
				var start_minutes: int = int(entry.get("start_minutes", 0))
				var arrive_minutes: int = int(entry.get("arrive_minutes", 0))
				if arrive_minutes <= start_minutes:
					arrive_minutes = start_minutes + 20
				sanitized_returning[int(key)] = {
					"mission_id": str(entry.get("mission_id", "")),
					"mission_name": str(entry.get("mission_name", "Gorev Donusu")),
					"cariye_name": str(entry.get("cariye_name", "Cariye")),
					"start_q": int(entry.get("start_q", 0)),
					"start_r": int(entry.get("start_r", 0)),
					"target_q": int(entry.get("target_q", 0)),
					"target_r": int(entry.get("target_r", 0)),
					"target_name": str(entry.get("target_name", "Koy")),
					"start_minutes": start_minutes,
					"arrive_minutes": arrive_minutes
				}
		MissionManager.set("_world_map_returning_units", sanitized_returning)
	if "_raid_mission_extra" in MissionManager:
		var rex_raw = MissionManager.get("_raid_mission_extra")
		var rex_pruned: Dictionary = {}
		if rex_raw is Dictionary and "missions" in MissionManager:
			for mid_key in rex_raw.keys():
				var mid_str: String = str(mid_key)
				if not MissionManager.missions.has(mid_str):
					continue
				var ent = rex_raw[mid_key]
				if ent is Dictionary:
					rex_pruned[mid_str] = (ent as Dictionary).duplicate(true)
		MissionManager.set("_raid_mission_extra", rex_pruned)

func _load_world_state(state: Dictionary) -> void:
	var world_manager = get_node_or_null("/root/WorldManager")
	if not is_instance_valid(world_manager):
		push_warning("[SaveManager] WorldManager not available")
		return
	
	# Settlement relations
	if state.has("settlement_relations"):
		if "settlement_relations" in world_manager:
			world_manager.set("settlement_relations", state["settlement_relations"].duplicate(true))
	
	# Active events
	if state.has("active_events"):
		if "active_events" in world_manager:
			var events_array: Array = []
			for event in state["active_events"]:
				if event is Dictionary:
					events_array.append(event.duplicate(true))
			world_manager.set("active_events", events_array)
	
	# Faction relations (using relations property)
	if state.has("faction_relations"):
		if "relations" in world_manager:
			world_manager.set("relations", state["faction_relations"].duplicate(true))
	
	# Hex map state (vertical slice)
	if world_manager.has_method("set_world_map_state"):
		var map_state = state.get("world_map", {})
		if map_state is Dictionary and not map_state.is_empty():
			world_manager.set_world_map_state(map_state)
		elif world_manager.has_method("start_new_world_map"):
			# Fallback for older saves without world_map payload.
			world_manager.start_new_world_map()

func _load_player_state(state: Dictionary) -> void:
	# GlobalPlayerData
	if is_instance_valid(GlobalPlayerData):
		if state.has("gold"):
			GlobalPlayerData.gold = int(state["gold"])
		if state.has("asker_sayisi"):
			GlobalPlayerData.asker_sayisi = int(state["asker_sayisi"])
		if state.has("envanter"):
			var loaded_envanter = state["envanter"]
			if loaded_envanter is Array:
				# Convert to Array[String]
				var envanter_array: Array[String] = []
				for item in loaded_envanter:
					if item is String:
						envanter_array.append(item)
					else:
						envanter_array.append(str(item))
				GlobalPlayerData.set("envanter", envanter_array)
		if state.has("iliskiler"):
			var loaded_iliskiler = state["iliskiler"]
			if loaded_iliskiler is Dictionary:
				GlobalPlayerData.set("iliskiler", loaded_iliskiler.duplicate(true))
	
	# PlayerStats
	if is_instance_valid(PlayerStats):
		if state.has("base_stats"):
			PlayerStats.base_stats = state["base_stats"].duplicate(true)
		if state.has("stat_multipliers"):
			PlayerStats.stat_multipliers = state["stat_multipliers"].duplicate(true)
		if state.has("stat_bonuses"):
			PlayerStats.stat_bonuses = state["stat_bonuses"].duplicate(true)
		if state.has("current_health"):
			PlayerStats.current_health = float(state["current_health"])
		if state.has("world_expedition_supplies") and PlayerStats.has_method("load_world_expedition_supplies_from_save"):
			var wes: Variant = state["world_expedition_supplies"]
			if wes is Dictionary:
				PlayerStats.call("load_world_expedition_supplies_from_save", wes)
		if state.has("carried_resources"):
			var cr: Variant = state["carried_resources"]
			if cr is Dictionary:
				for ck in (cr as Dictionary).keys():
					var sk: String = String(ck)
					if PlayerStats.carried_resources.has(sk):
						PlayerStats.carried_resources[sk] = int((cr as Dictionary)[ck])
				if PlayerStats.has_method("_emit_carried_changed"):
					PlayerStats.call("_emit_carried_changed")

func _load_time_state(state: Dictionary) -> void:
	if not is_instance_valid(TimeManager):
		push_warning("[SaveManager] TimeManager not available")
		return
	
	if state.has("days"):
		TimeManager.days = int(state["days"])
	if state.has("hours"):
		TimeManager.hours = int(state["hours"])
	if state.has("minutes"):
		TimeManager.minutes = int(state["minutes"])

func _load_weather_state(state: Dictionary) -> void:
	if not is_instance_valid(WeatherManager):
		push_warning("[SaveManager] WeatherManager not available")
		return
	
	# Eğer state boşsa veya storm_active yoksa, storm'u tamamen sıfırla
	if state.is_empty() or not state.has("storm_active"):
		# Yeni oyun veya eski save dosyası - storm'u tamamen sıfırla
		if WeatherManager.storm_active:
			WeatherManager.reset_storm_completely()
		return
	
	# Save dosyasından weather state'i yükle
	var storm_active: bool = state.get("storm_active", false)
	var storm_level: int = state.get("storm_level", 1)
	
	# ÖNEMLİ: Önce mevcut storm'u tamamen sıfırla (eğer varsa)
	if WeatherManager.storm_active:
		WeatherManager.reset_storm_completely()
	
	# Eğer save dosyasında storm aktifse, storm'u başlat
	if storm_active:
		WeatherManager.set_storm_active(true, storm_level)
		# Save dosyasından weather değerlerini yükle
		if state.has("rain_intensity"):
			WeatherManager.rain_intensity = float(state["rain_intensity"])
		if state.has("wind_strength"):
			WeatherManager.wind_strength = float(state["wind_strength"])
		if state.has("wind_direction_angle"):
			WeatherManager.wind_direction_angle = float(state["wind_direction_angle"])
	else:
		# Save dosyasında storm yoksa, weather değerlerini sıfırla
		WeatherManager.rain_intensity = 0.0
		WeatherManager.wind_strength = 0.0
		WeatherManager.wind_direction_angle = 0.0
	
	print("[SaveManager] ✅ Weather state loaded: storm_active=%s, storm_level=%d, rain_intensity=%.3f" % [storm_active, storm_level, WeatherManager.rain_intensity])

func _to_vector2(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		var x = float(value.get("x", 0.0))
		var y = float(value.get("y", 0.0))
		return Vector2(x, y)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is String:
		var text: String = (value as String).strip_edges()
		if text.begins_with("Vector2(") and text.ends_with(")"):
			text = text.substr(8, text.length() - 9)
		elif text.begins_with("(") and text.ends_with(")"):
			text = text.substr(1, text.length() - 2)
		var parts: Array = text.split(",")
		if parts.size() >= 2:
			return Vector2(float(parts[0]), float(parts[1]))
	return Vector2.ZERO

# === UTILITY FUNCTIONS ===

func get_save_metadata(slot_id: int) -> Dictionary:
	"""Get metadata for a save slot without loading the full save"""
	if slot_id < 1 or slot_id > MAX_SAVE_SLOTS:
		return {}
	
	var file_path = SAVE_DIR + "save_%d.json" % slot_id
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_error = json.parse(json_string)
	if parse_error != OK:
		return {}
	
	var save_data: Dictionary = json.get_data()
	if not save_data is Dictionary:
		return {}
	
	# Extract metadata
	var metadata: Dictionary = {
		"version": save_data.get("version", "0.0.0"),
		"save_date": save_data.get("save_date", ""),
		"playtime_seconds": save_data.get("playtime_seconds", 0),
		"scene": save_data.get("scene", ""),
		"slot_id": slot_id
	}
	
	# Calculate village level (simplified: based on building count)
	if save_data.has("village") and save_data["village"] is Dictionary:
		var village = save_data["village"]
		if village.has("buildings") and village["buildings"] is Array:
			metadata["village_level"] = village["buildings"].size()
		if village.has("resources") and village["resources"] is Dictionary:
			metadata["gold"] = village["resources"].get("gold", 0)
	
	return metadata

func delete_save(slot_id: int) -> bool:
	"""Delete a save slot"""
	if slot_id < 1 or slot_id > MAX_SAVE_SLOTS:
		push_error("[SaveManager] Invalid slot_id for delete: %d" % slot_id)
		return false
	
	var file_path = SAVE_DIR + "save_%d.json" % slot_id
	if not FileAccess.file_exists(file_path):
		print("[SaveManager] Save slot %d does not exist, nothing to delete" % slot_id)
		return true  # Already deleted/non-existent, consider it success
	
	# Open user:// directory
	var dir = DirAccess.open("user://")
	if not dir:
		push_error("[SaveManager] Failed to open user:// directory")
		return false
	
	# Try multiple methods to delete the file
	var filename = "save_%d.json" % slot_id
	var relative_path = "otto-man-save/" + filename
	
	# Method 1: Try to change to directory and remove
	var change_error = dir.change_dir("otto-man-save")
	if change_error == OK:
		var error = dir.remove(filename)
		if error == OK:
			print("[SaveManager] ✅ Deleted save slot %d: %s" % [slot_id, filename])
			return true
		else:
			push_error("[SaveManager] Method 1 failed: Failed to remove file (error: %d)" % error)
	else:
		push_error("[SaveManager] Method 1 failed: Failed to change directory (error: %d)" % change_error)
	
	# Method 2: Try to remove with relative path from user://
	dir = DirAccess.open("user://")  # Reopen to reset
	if dir:
		var error = dir.remove(relative_path)
		if error == OK:
			print("[SaveManager] ✅ Deleted save slot %d (method 2): %s" % [slot_id, relative_path])
			return true
		else:
			push_error("[SaveManager] Method 2 failed: Failed to remove with relative path (error: %d)" % error)
	
	# Method 3: Try using OS.move_to_trash (platform dependent, but might work)
	# Convert user:// path to absolute path
	var user_data_dir = OS.get_user_data_dir()
	# Build path with proper separators
	var absolute_path = user_data_dir + "/otto-man-save/save_%d.json" % slot_id
	
	# Check if file exists before trying to move to trash
	if FileAccess.file_exists(absolute_path):
		var trash_result = OS.move_to_trash(absolute_path)
		if trash_result == OK:
			print("[SaveManager] ✅ Moved save slot %d to trash (method 3): %s" % [slot_id, absolute_path])
			return true
		else:
			push_error("[SaveManager] Method 3 failed: move_to_trash returned error: %d" % trash_result)
	else:
		# File doesn't exist at absolute path, try alternative path construction
		# On Windows, user data dir might be different
		var alt_path = user_data_dir + "\\otto-man-save\\save_%d.json" % slot_id
		if FileAccess.file_exists(alt_path):
			var trash_result = OS.move_to_trash(alt_path)
			if trash_result == OK:
				print("[SaveManager] ✅ Moved save slot %d to trash (method 3b): %s" % [slot_id, alt_path])
				return true
	
	push_error("[SaveManager] All methods failed to delete save slot %d" % slot_id)
	push_error("[SaveManager] File path checked: %s" % file_path)
	push_error("[SaveManager] Absolute path checked: %s" % absolute_path)
	return false

func _calculate_current_playtime() -> int:
	"""Calculate total playtime in seconds"""
	var current_session = (Time.get_ticks_msec() - _playtime_start) / 1000
	return _total_playtime_seconds + current_session

func _format_datetime(datetime_dict: Dictionary) -> String:
	"""Format datetime dictionary to ISO string"""
	var year = datetime_dict.get("year", 0)
	var month = datetime_dict.get("month", 0)
	var day = datetime_dict.get("day", 0)
	var hour = datetime_dict.get("hour", 0)
	var minute = datetime_dict.get("minute", 0)
	return "%04d-%02d-%02dT%02d:%02d:00" % [year, month, day, hour, minute]

# === VALIDATION FUNCTIONS ===

func _validate_save_data(save_data: Dictionary) -> Dictionary:
	"""
	Validate save data structure and return validation result.
	Returns: {"valid": bool, "error": String}
	"""
	# Check required top-level keys
	var required_keys = ["version", "save_date"]
	for key in required_keys:
		if not save_data.has(key):
			return {"valid": false, "error": "Kayıt dosyasında gerekli alan eksik: %s" % key}
	
	# Validate version format (should be "x.y.z")
	var version = save_data.get("version", "")
	if version.is_empty():
		return {"valid": false, "error": "Kayıt dosyası sürüm bilgisi eksik."}
	
	# Check if critical data sections exist (allow empty but must be correct type)
	var critical_sections = ["village", "missions", "world", "player", "time"]
	
	for section_name in critical_sections:
		if save_data.has(section_name):
			var section = save_data[section_name]
			if not section is Dictionary:
				return {"valid": false, "error": "Kayıt dosyasında '%s' bölümü yanlış formatta." % section_name}
	
	# Validate version compatibility (basic check)
	if not _is_version_compatible(version):
		return {"valid": false, "error": "Bu kayıt dosyası bu oyun sürümüyle uyumlu değil."}
	
	return {"valid": true, "error": ""}

func _is_version_compatible(save_version: String) -> bool:
	"""
	Check if save version is compatible with current version.
	For now, accepts same major.minor version (0.1.x)
	"""
	var save_parts = save_version.split(".")
	var current_parts = SAVE_VERSION.split(".")
	
	if save_parts.size() < 2 or current_parts.size() < 2:
		return false
	
	# Same major.minor is compatible (0.1.x)
	if save_parts[0] == current_parts[0] and save_parts[1] == current_parts[1]:
		return true
	
	# For now, reject other versions (can be made more flexible later)
	return false

func validate_save_file(slot_id: int) -> Dictionary:
	"""
	Public function to validate a save file without loading it.
	Returns: {"valid": bool, "error": String, "metadata": Dictionary}
	"""
	if slot_id < 1 or slot_id > MAX_SAVE_SLOTS:
		return {"valid": false, "error": "Geçersiz kayıt slotu.", "metadata": {}}
	
	var file_path = SAVE_DIR + "save_%d.json" % slot_id
	if not FileAccess.file_exists(file_path):
		return {"valid": false, "error": "Kayıt dosyası bulunamadı.", "metadata": {}}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {"valid": false, "error": "Kayıt dosyası açılamadı.", "metadata": {}}
	
	var json_string = file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		return {"valid": false, "error": "Kayıt dosyası boş.", "metadata": {}}
	
	var json = JSON.new()
	var parse_error = json.parse(json_string)
	if parse_error != OK:
		return {"valid": false, "error": "JSON parse hatası.", "metadata": {}}
	
	var save_data: Dictionary = json.get_data()
	if not save_data is Dictionary:
		return {"valid": false, "error": "Geçersiz dosya formatı.", "metadata": {}}
	
	var validation = _validate_save_data(save_data)
	var metadata = {}
	if validation["valid"]:
		metadata = get_save_metadata(slot_id)
	
	return {
		"valid": validation["valid"],
		"error": validation["error"],
		"metadata": metadata
	}
