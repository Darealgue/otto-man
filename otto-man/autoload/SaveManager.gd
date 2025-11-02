extends Node

## SaveManager - Merkezi kayıt/yükleme yöneticisi
## Beta Yol Haritası FAZ 2: Save/Load Sistemi

const SAVE_VERSION: String = "0.1.0"
const SAVE_DIR: String = "user://otto-man-save/"
const MAX_SAVE_SLOTS: int = 5

signal save_completed(slot_id: int, success: bool)
signal load_completed(slot_id: int, success: bool)

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
	
	# Save to file
	var file_path = SAVE_DIR + "save_%d.json" % slot_id
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Failed to open file for writing: %s" % file_path)
		save_completed.emit(slot_id, false)
		return false
	
	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
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
	
	var json = JSON.new()
	var parse_error = json.parse(json_string)
	if parse_error != OK:
		push_error("[SaveManager] Failed to parse JSON: %s (error: %d)" % [file_path, parse_error])
		load_completed.emit(slot_id, false)
		return false
	
	var save_data: Dictionary = json.get_data()
	if not save_data is Dictionary:
		push_error("[SaveManager] Save data is not a dictionary: %s" % file_path)
		load_completed.emit(slot_id, false)
		return false
	
	# Version check (for future compatibility)
	var version = save_data.get("version", "0.0.0")
	if version != SAVE_VERSION:
		print("[SaveManager] ⚠️ Version mismatch: Save=%s, Current=%s" % [version, SAVE_VERSION])
		# For now, we'll try to load anyway
	
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
	_load_world_state(save_data.get("world", {}))
	_load_player_state(save_data.get("player", {}))
	_load_time_state(save_data.get("time", {}))
	
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
	
	# Save snapshot/meta data
	if VillageManager._saved_snapshot_time is Dictionary and not VillageManager._saved_snapshot_time.is_empty():
		state["snapshot_time"] = VillageManager._saved_snapshot_time.duplicate(true)
	else:
		state["snapshot_time"] = {}
	
	return state

func _save_mission_state() -> Dictionary:
	var state: Dictionary = {}
	
	if not is_instance_valid(MissionManager):
		push_warning("[SaveManager] MissionManager not available")
		return state
	
	# Active missions (Dictionary: mission_id -> mission_data)
	state["active_missions"] = []
	if "active_missions" in MissionManager:
		var active = MissionManager.active_missions
		if active is Dictionary:
			# Convert Dictionary to Array for JSON serialization
			for mission_id in active.keys():
				var mission_data = active[mission_id]
				if mission_data is Dictionary:
					var mission_entry = mission_data.duplicate(true)
					mission_entry["id"] = mission_id  # Ensure ID is in the data
					state["active_missions"].append(mission_entry)
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
	
	# Concubines (cariyeler)
	state["concubines"] = []
	if "concubines" in MissionManager:
		var concubines_dict = MissionManager.concubines
		for cariye_id in concubines_dict.keys():
			var cariye = concubines_dict[cariye_id]
			if cariye.has_method("to_dict") or "name" in cariye:
				var cariye_data: Dictionary = {}
				if "name" in cariye:
					cariye_data["name"] = cariye.name
				if "role" in cariye:
					cariye_data["role"] = int(cariye.role) if cariye.role is int else 0
				state["concubines"].append({"id": cariye_id, "data": cariye_data})
	
	# Trade agreements
	state["trade_agreements"] = []
	if "trade_agreements" in MissionManager:
		state["trade_agreements"] = MissionManager.trade_agreements.duplicate(true)
	
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
	
	return state

func _save_time_state() -> Dictionary:
	var state: Dictionary = {}
	
	if is_instance_valid(TimeManager):
		state["days"] = TimeManager.days if "days" in TimeManager else 1
		state["hours"] = TimeManager.hours if "hours" in TimeManager else 0
		state["minutes"] = TimeManager.minutes if "minutes" in TimeManager else 0
	
	return state

# === LOAD HELPERS ===

func _load_village_state(state: Dictionary) -> void:
	print("[SaveManager] 🔄 DEBUG: Starting _load_village_state()")
	print("[SaveManager] 🔍 DEBUG: State keys: %s" % str(state.keys()))
	
	if not is_instance_valid(VillageManager):
		push_warning("[SaveManager] VillageManager not available")
		return
	
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

func _load_mission_state(state: Dictionary) -> void:
	if not is_instance_valid(MissionManager):
		push_warning("[SaveManager] MissionManager not available")
		return
	
	# Active missions (Dictionary)
	if state.has("active_missions"):
		var loaded_active = state["active_missions"]
		if loaded_active is Array:
			# Convert Array to Dictionary format
			var active_dict: Dictionary = {}
			for mission in loaded_active:
				if mission is Dictionary and "id" in mission:
					active_dict[mission["id"]] = mission
				elif mission is Dictionary:
					# Try to find an ID in the mission dict
					for key in mission.keys():
						if key == "id" or key == "mission_id":
							active_dict[mission[key]] = mission
							break
			MissionManager.set("active_missions", active_dict)
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
	
	# Concubines (restoration might need special handling)
	# This is a simplified version - MissionManager might need its own load logic
	
	# Trade agreements
	if state.has("trade_agreements"):
		var loaded_trade = state["trade_agreements"]
		if loaded_trade is Array:
			MissionManager.set("trade_agreements", loaded_trade.duplicate(true))

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
		return false
	
	var file_path = SAVE_DIR + "save_%d.json" % slot_id
	if FileAccess.file_exists(file_path):
		var dir = DirAccess.open("user://")
		if dir:
			var error = dir.remove("otto-man-save/save_%d.json" % slot_id)
			if error == OK:
				print("[SaveManager] ✅ Deleted save slot %d" % slot_id)
				return true
			else:
				push_error("[SaveManager] Failed to delete save slot %d (error: %d)" % [slot_id, error])
				return false
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
