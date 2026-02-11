extends Node

const HouseScript = preload("res://village/scripts/House.gd")

# --- YENİ: Bina Gereksinimleri --- (COSTS yerine REQUIREMENTS)
const BUILDING_REQUIREMENTS = {
	# Temel binalar için sadece altın maliyeti (veya 0)
	# Doğru yollar kullanılıyor: village/buildings/
	"res://village/buildings/WoodcutterCamp.tscn": {"cost": {"gold": 5}}, # Örnek - AYARLA!
	"res://village/buildings/StoneMine.tscn": {"cost": {"gold": 5}},
	"res://village/buildings/HunterGathererHut.tscn": {"cost": {"gold": 5}},
	"res://village/buildings/Well.tscn": {"cost": {"gold": 10}},
	"res://village/buildings/Sawmill.tscn": {"cost": {"gold": 40, "wood": 1}},
	"res://village/buildings/Brickworks.tscn": {"cost": {"gold": 40, "stone": 1}},
	# Gelişmiş binalar (Fırın için sadece altın gereksinimi)
	"res://village/buildings/Bakery.tscn": {"cost": {"gold": 50}},
	"res://village/buildings/House.tscn": {"cost": {"gold": 50,"wood": 1, "stone": 1}}, #<<< YENİ EV MALİYETİ
	"res://village/buildings/StorageBuilding.tscn": {"cost": {"gold": 80, "wood": 2, "stone": 1}},
	# Yeni üretim zinciri binaları (placeholder maliyetler)
	"res://village/buildings/Blacksmith.tscn": {"cost": {"gold": 120, "wood": 2, "stone": 2}},
	"res://village/buildings/Armorer.tscn": {"cost": {"gold": 120, "wood": 2, "stone": 2}},
	"res://village/buildings/Tailor.tscn": {"cost": {"gold": 90, "wood": 1}},
	"res://village/buildings/Weaver.tscn": {"cost": {"gold": 70, "wood": 1}},
	"res://village/buildings/Herbalist.tscn": {"cost": {"gold": 70}},
	"res://village/buildings/TeaHouse.tscn": {"cost": {"gold": 60}},
	"res://village/buildings/SoapMaker.tscn": {"cost": {"gold": 80}},
	"res://village/buildings/Gunsmith.tscn": {"cost": {"gold": 120, "wood": 2}},
	# Kışla (geçici olarak ücretsiz)
	"res://village/buildings/Barracks.tscn": {"cost": {}}
}

# --- VillageScene Referansı ---
var village_scene_instance: Node2D = null

# Toplam işçi sayısı (Başlangıçta örnek bir değer)
var total_workers: int = 0
# Boşta bekleyen işçi sayısı
var idle_workers: int = 0

# Temel kaynakların mevcut SEVİYELERİ (Stoklama yok, hesaplanacak)
# Bu dictionary artık bir önbellek veya başka bir amaç için kullanılabilir,
# ancak başlangıç değerleri 0 olmalı.
var resource_levels: Dictionary = {
	"wood": 0,
	"stone": 0,
	"food": 0,
	"water": 0,
	"lumber": 0,
	"brick": 0,
	"metal": 0,
	"cloth": 0,
	"garment": 0,
	"bread": 0,
	"tea": 0,
	"medicine": 0,
	"soap": 0,
	"weapon": 5,  # Silah (Blacksmith üretir) - Başlangıç: 5
	"armor": 5    # Zırh (Armorer üretir) - Başlangıç: 5
}

# Kaynak SEVİYELERİNİN kilitlenen kısmı (Yükseltmeler ve Gelişmiş Üretim için)
var locked_resource_levels: Dictionary = {
	"wood": 0,
	"stone": 0,
	"food": 0,
	"water": 0,
	"lumber": 0,
	"brick": 0,
	"metal": 0,
	"cloth": 0,
	"garment": 0,
	"bread": 0,
	"tea": 0,
	"medicine": 0,
	"soap": 0
}

# --- ZAMAN BAZLI ÜRETİM (YENİ) ---
# Temel kaynaklar için stok ve saat bazlı birikim ilerlemesi
const BASE_RESOURCE_TYPES := ["wood", "stone", "food", "water"]
const SECONDS_PER_RESOURCE_UNIT := 300.0 # 1 işçi-2saat == 1 kaynak (oyun içi 2 saat = 2 * 2.5 * 60 = 300 gerçek saniye)
var base_production_progress: Dictionary = {
	"wood": 0.0,
	"stone": 0.0,
	"food": 0.0,
	"water": 0.0
}

var _time_signal_connected: bool = false
var _time_advanced_connected: bool = false

# Sinyaller
signal village_data_changed
signal resource_produced(resource_type, amount)
signal worker_assigned(building_node, resource_type)
signal worker_removed(building_node, resource_type)
signal worker_list_changed  # Worker listesi değiştiğinde UI'yi güncellemek için
signal cariye_data_changed
signal gorev_data_changed
signal building_state_changed(building_node)
signal mission_completed(cariye_id, gorev_id, successful, results)
signal time_skip_completed(total_hours, produced_resources)  # total_hours: float, produced_resources: Dictionary

# --- Diğer Değişkenler (Cariye, Görev vb.) ---
# Cariyeleri saklayacağımız dictionary: { cariye_id: {veri} }
var cariyeler: Dictionary = {}
# Görevleri saklayacağımız dictionary: { gorev_id: {veri} }
var gorevler: Dictionary = {}
# Devam eden görevleri saklayacağımız dictionary: { cariye_id: {gorev_id, timer_node} }
var active_missions: Dictionary = {}

# Cariye ve görevler için benzersiz ID üretici
var next_cariye_id: int = 1
var next_gorev_id: int = 1
# -----------------------------------------

# --- Sinyaller ---
# signal cariye_data_changed # Cariye UI güncellemesi için
# signal gorev_data_changed  # Görev UI güncellemesi için
# -----------------

# --- İşçi Yönetimi ---
var worker_scene: PackedScene = preload("res://village/scenes/Worker.tscn") # Worker.tscn dosya yolunu kontrol edin!
var all_workers: Dictionary = {} # { worker_id: worker_data } # <<< YENİ: active_workers yerine
var worker_id_counter: int = 0 # <<< YENİ: ID üretici
var campfire_node: Node2D = null # Kamp ateşi referansı
var workers_container: Node = null #<<< YENİ: workers_parent_node yerine

# --- Cariye Yönetimi ---
var concubine_scene: PackedScene = preload("res://village/scenes/Concubine.tscn")
var concubines_container: Node = null
# Tüccar sprite'ları (köye yürüyerek girer, merkezde bekler, süre bitince yürüyerek çıkar)
var traders_container: Node2D = null
var trader_npc_by_id: Dictionary = {}  # trader_id -> TraderVillageNPC
const TraderVillageNPCScene = preload("res://village/scenes/TraderVillageNPC.tscn")
const TRADER_ENTRY_X: float = -2800.0
const TRADER_CENTER_X: float = 0.0
const TRADER_EXIT_X: float = 2800.0
const TRADER_CENTER_Y: float = -26.0

var _saved_building_states: Array = []
var _saved_worker_states: Array = []
var _saved_resource_levels: Dictionary = {}  # Save resource levels when leaving village
var _saved_base_production_progress: Dictionary = {}  # Save production progress
var _saved_snapshot_time: Dictionary = {}  # Save time when snapshot is taken (day, hour, minute)
var _pending_time_skip_notification: Dictionary = {}  # Pending notification data to show after scene loads
var _is_leaving_village: bool = false  # Flag to prevent simulation when leaving village
var _scene_signal_connected: bool = false

# --- Village Event System ---
var village_events_enabled: bool = true  # Enable/disable village-specific events
var village_daily_event_chance: float = 0.15  # 15% chance per day for a village event
var _village_event_cooldowns: Dictionary = {}  # Event type -> day when cooldown ends
var _last_village_event_check_day: int = 0  # Track last day we checked for events
# Note: events_enabled, daily_event_chance, events_active, _event_cooldowns are already defined below

var _skip_next_snapshot: bool = false

func _ready() -> void:
	# Connect to SceneManager for scene change tracking
	if is_instance_valid(SceneManager) and not _scene_signal_connected:
		SceneManager.scene_change_started.connect(Callable(self, "_on_scene_change_started"))
		_scene_signal_connected = true
	
	# Bandit Activity + göreve giden askerlerin ekrandan çıkması
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		if not mm.mission_completed.is_connected(_on_mission_manager_mission_completed):
			mm.mission_completed.connect(_on_mission_manager_mission_completed)
		if not mm.mission_started.is_connected(_on_mission_manager_mission_started):
			mm.mission_started.connect(_on_mission_manager_mission_started)
		if not mm.mission_cancelled.is_connected(_on_mission_manager_mission_cancelled):
			mm.mission_cancelled.connect(_on_mission_manager_mission_cancelled)
	
	# Initialize resource levels (restore from saved if available)
	if not _saved_resource_levels.is_empty():
		resource_levels = _saved_resource_levels.duplicate(true)
		# Ensure weapon/armor have default values if not in saved data
		if not resource_levels.has("weapon"):
			resource_levels["weapon"] = 5
		if not resource_levels.has("armor"):
			resource_levels["armor"] = 5
	else:
		resource_levels = {
			"wood": 0,
			"stone": 0,
			"food": 0,
			"water": 0,
			"lumber": 0,
			"brick": 0,
			"metal": 0,
			"cloth": 0,
			"garment": 0,
			"bread": 0,
			"tea": 0,
			"medicine": 0,
			"soap": 0,
			"weapon": resource_levels.get("weapon", 5),
			"armor": resource_levels.get("armor", 5)
		}
	
	# Restore production progress if available
	if not _saved_base_production_progress.is_empty():
		base_production_progress = _saved_base_production_progress.duplicate(true)
	else:
		for res in BASE_RESOURCE_TYPES:
			if not base_production_progress.has(res):
				base_production_progress[res] = 0.0
	locked_resource_levels = {
		"wood": 0,
		"stone": 0,
		"food": 0,
		"water": 0,
		"lumber": 0,
		"brick": 0,
		"metal": 0,
		"cloth": 0,
		"garment": 0,
		"bread": 0,
		"tea": 0,
		"medicine": 0,
		"soap": 0
	}
	_create_debug_cariyeler()
	_create_debug_gorevler()
	
	# Connect WorldManager signals
	call_deferred("_connect_world_manager_signals")

func _on_scene_change_started(target_path: String) -> void:
	if not is_instance_valid(SceneManager):
		return
	if SceneManager.current_scene_path != SceneManager.VILLAGE_SCENE:
		return
	# Set flag to prevent simulation during travel out (we're leaving village)
	_is_leaving_village = true
	# Save current time before taking snapshot (this is the time simulation should start from)
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		_saved_snapshot_time = {
			"day": time_manager.get_day() if time_manager.has_method("get_day") else 0,
			"hour": time_manager.get_hour() if time_manager.has_method("get_hour") else 0,
			"minute": time_manager.get_minute() if time_manager.has_method("get_minute") else 0
		}
	snapshot_state_for_scene_exit()

func schedule_skip_next_snapshot() -> void:
	set("_skip_next_snapshot", true)

func snapshot_state_for_scene_exit() -> void:
	var skip_flag: bool = false
	if "_skip_next_snapshot" in self:
		skip_flag = bool(get("_skip_next_snapshot"))
	if skip_flag:
		set("_skip_next_snapshot", false)
		return
	
	if not is_instance_valid(village_scene_instance):
		return

	_saved_building_states.clear()
	var placed_buildings := village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return
	
	for building in placed_buildings.get_children():
			if not (building is Node2D):
				continue
			var node2d := building as Node2D
			var scene_path: String = building.scene_file_path
			if scene_path.is_empty():
				continue
			var entry: Dictionary = {
				"scene_path": scene_path,
				"position": node2d.global_position,
				"global_position": node2d.global_position,
				"local_position": node2d.position,
				"key": _make_building_snapshot_key(scene_path, node2d.global_position)
			}
			if "level" in building:
				var level_val = building.get("level")
				if level_val != null:
					entry["level"] = int(level_val)
			if "assigned_workers" in building:
				entry["assigned_workers"] = int(building.assigned_workers)
			if "max_workers" in building:
				entry["max_workers"] = int(building.max_workers)
			if "assigned_worker_ids" in building:
				entry["assigned_worker_ids"] = (building.assigned_worker_ids as Array).duplicate(true)
			if "produced_resource" in building:
				entry["produced_resource"] = String(building.produced_resource)
			if "required_resources" in building:
				entry["required_resources"] = _copy_dictionary(building.required_resources)
			if "input_buffer" in building:
				entry["input_buffer"] = _copy_dictionary(building.input_buffer)
			if "production_progress" in building:
				entry["production_progress"] = float(building.production_progress)
			if "PRODUCTION_TIME" in building:
				entry["production_time"] = float(building.PRODUCTION_TIME)
			if "FETCH_TIME_PER_UNIT" in building:
				entry["fetch_time"] = float(building.FETCH_TIME_PER_UNIT)
			if "fetch_target" in building:
				entry["fetch_target"] = String(building.fetch_target)
			if "is_fetcher_out" in building:
				entry["is_fetcher_out"] = bool(building.is_fetcher_out)
			if "fetch_timer" in building and building.fetch_timer:
				entry["fetch_time_left"] = building.fetch_timer.time_left
			if "is_upgrading" in building:
				entry["is_upgrading"] = bool(building.is_upgrading)
				if building.is_upgrading and "upgrade_timer" in building and building.upgrade_timer:
					entry["upgrade_time_left"] = building.upgrade_timer.time_left
			if "upgrade_time_seconds" in building:
				entry["upgrade_time_total"] = float(building.upgrade_time_seconds)
			entry["fetch_progress"] = entry.get("fetch_progress", {})
			_saved_building_states.append(entry)
	
	# Kamp ateşinin kapasitesini kaydet (PlacedBuildings'de değil, doğrudan sahne içinde)
	if is_instance_valid(campfire_node) and "max_capacity" in campfire_node:
		var campfire_entry: Dictionary = {
			"scene_path": campfire_node.scene_file_path if campfire_node.scene_file_path != "" else "res://village/scenes/CampFire.tscn",
			"position": campfire_node.global_position,
			"global_position": campfire_node.global_position,
			"is_campfire": true,  # Kamp ateşi işareti
			"max_capacity": int(campfire_node.max_capacity)
		}
		_saved_building_states.append(campfire_entry)
	
	# Save resource levels and production progress
	_saved_resource_levels = resource_levels.duplicate(true)
	_saved_base_production_progress = base_production_progress.duplicate(true)

	_saved_worker_states.clear()
	var worker_ids := all_workers.keys()
	worker_ids.sort()
	for worker_id in worker_ids:
		var worker_data = all_workers.get(worker_id, {})
		if not worker_data:
			continue
		var worker_instance: Node = worker_data.get("instance", null)
		if not is_instance_valid(worker_instance):
			continue
		var npc_info_value = worker_instance.get("NPC_Info") if worker_instance else null
		var npc_info: Dictionary = npc_info_value.duplicate(true) if npc_info_value is Dictionary else {}
		var job_type_value = worker_instance.get("assigned_job_type") if worker_instance else null
		var job_type: String = job_type_value if job_type_value is String else ""
		var building_key := ""
		var assigned_building = worker_instance.get("assigned_building_node") if worker_instance else null
		if is_instance_valid(assigned_building) and assigned_building is Node2D:
			var assigned_scene: String = assigned_building.scene_file_path
			if not assigned_scene.is_empty():
				building_key = _make_building_snapshot_key(assigned_scene, assigned_building.global_position)
		
		# Housing node referansını kaydet (kamp ateşi veya ev)
		var housing_key := ""
		var housing_node = worker_instance.get("housing_node") if worker_instance else null
		if is_instance_valid(housing_node) and housing_node is Node2D:
			var housing_scene: String = housing_node.scene_file_path if housing_node.scene_file_path != "" else "res://village/scenes/CampFire.tscn"
			housing_key = _make_building_snapshot_key(housing_scene, housing_node.global_position)
		
		# Askerler için is_deployed durumunu kaydet
		var is_deployed_value = false
		if worker_instance and "is_deployed" in worker_instance:
			var deployed_val = worker_instance.get("is_deployed")
			is_deployed_value = deployed_val if deployed_val is bool else false
		
		var worker_entry: Dictionary = {
			"worker_id": worker_id,
			"npc_info": npc_info,
			"job_type": job_type,
			"building_key": building_key,
			"housing_key": housing_key,  # Housing node referansı
			"is_deployed": is_deployed_value  # Askerler için deploy durumu
		}
		_saved_worker_states.append(worker_entry)
	
	if is_instance_valid(VillagerAiInitializer):
		VillagerAiInitializer.Saved_Villagers.clear()
		for worker_entry in _saved_worker_states:
			var info: Dictionary = worker_entry.get("npc_info", {}).duplicate(true)
			VillagerAiInitializer.Saved_Villagers.append(info)

func _make_building_snapshot_key(scene_path: String, position: Vector2) -> String:
	return "%s|%s" % [scene_path, str(position)]

func _to_vector2(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		var x = float(value.get("x", 0.0))
		var y = float(value.get("y", 0.0))
		return Vector2(x, y)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

func _reset_worker_runtime_data() -> void:
	for worker_id in all_workers.keys():
		var worker_data = all_workers[worker_id]
		if worker_data and worker_data.has("instance"):
			var worker_instance = worker_data["instance"]
			if is_instance_valid(worker_instance) and worker_instance.get_parent():
				worker_instance.queue_free()
	all_workers.clear()
	total_workers = 0
	idle_workers = 0

func _restore_saved_buildings() -> Dictionary:
	var restored_map: Dictionary = {}
	if not is_instance_valid(village_scene_instance):
		return restored_map
	if _saved_building_states.is_empty():
		return restored_map
	
	var placed_buildings := village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return restored_map
	
	for child in placed_buildings.get_children():
		child.queue_free()
	
	# Önce kamp ateşinin kapasitesini yükle (eğer kaydedilmişse)
	if is_instance_valid(campfire_node):
		for entry in _saved_building_states:
			if entry.get("is_campfire", false) and "max_capacity" in entry:
				var saved_capacity = int(entry.get("max_capacity", 3))
				if "max_capacity" in campfire_node:
					campfire_node.max_capacity = saved_capacity
					print("[VillageManager] ✅ DEBUG: Campfire max_capacity restored to %d" % saved_capacity)
				break
	
	# Önce kamp ateşinin kapasitesini yükle (eğer kaydedilmişse)
	# Bu, worker'lar yüklenmeden önce yapılmalı
	if is_instance_valid(campfire_node):
		for entry in _saved_building_states:
			if entry.get("is_campfire", false) and "max_capacity" in entry:
				var saved_capacity = int(entry.get("max_capacity", 3))
				if "max_capacity" in campfire_node:
					campfire_node.max_capacity = saved_capacity
					print("[VillageManager] ✅ DEBUG: Campfire max_capacity restored to %d" % saved_capacity)
				break
	
	var restored_count = 0
	for entry in _saved_building_states:
		# Kamp ateşini atla (zaten yüklendi)
		if entry.get("is_campfire", false):
			continue
		
		var scene_path: String = entry.get("scene_path", "")
		if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
			continue
		var packed := load(scene_path)
		if not (packed is PackedScene):
			continue
		var building_instance = (packed as PackedScene).instantiate()
		placed_buildings.add_child(building_instance)
		if building_instance is Node2D:
			var node2d := building_instance as Node2D
			var saved_global_pos: Vector2 = _to_vector2(entry.get("global_position", entry.get("position", Vector2.ZERO)))
			var saved_local_pos = entry.get("local_position", null)
			node2d.global_position = saved_global_pos
			if saved_local_pos is Vector2:
				node2d.position = saved_local_pos
			elif is_instance_valid(placed_buildings):
				node2d.position = placed_buildings.to_local(saved_global_pos)
		if entry.has("level"):
			var saved_level = entry.get("level")
			if saved_level != null:
				var level_int = int(saved_level)
				if "level" in building_instance:
					building_instance.set("level", level_int)
					if building_instance.has_method("_update_texture"):
						building_instance._update_texture()
					elif building_instance.has_method("update_texture"):
						building_instance.update_texture()
					if building_instance.has_method("_update_collision"):
						building_instance._update_collision()
		var max_workers_restored := false
		if entry.has("max_workers"):
			var saved_max_workers = entry.get("max_workers", null)
			if saved_max_workers != null and "max_workers" in building_instance:
				building_instance.max_workers = int(saved_max_workers)
				max_workers_restored = true
		elif "max_workers" in building_instance and "level" in building_instance:
			building_instance.max_workers = max(int(building_instance.max_workers), int(building_instance.level))
		if entry.has("assigned_workers"):
			var saved_workers = int(entry.get("assigned_workers", 0))
			if "assigned_workers" in building_instance:
				building_instance.assigned_workers = saved_workers
				if "max_workers" in building_instance:
					building_instance.max_workers = max(int(building_instance.max_workers), saved_workers)
		if entry.has("assigned_worker_ids"):
			var saved_ids = entry.get("assigned_worker_ids", [])
			if "assigned_worker_ids" in building_instance:
				if saved_ids is Array:
					var worker_ids_array: Array[int] = []
					for id_val in saved_ids:
						if id_val is int:
							worker_ids_array.append(id_val)
					building_instance.set("assigned_worker_ids", worker_ids_array)
		if entry.has("produced_resource") and "produced_resource" in building_instance:
			building_instance.produced_resource = String(entry.get("produced_resource", ""))
		if entry.has("required_resources") and "required_resources" in building_instance:
			building_instance.required_resources = _copy_dictionary(entry.get("required_resources", {}))
		if entry.has("input_buffer") and "input_buffer" in building_instance:
			building_instance.input_buffer = _copy_dictionary(entry.get("input_buffer", {}))
		if entry.has("production_progress") and "production_progress" in building_instance:
			building_instance.production_progress = float(entry.get("production_progress", 0.0))
		if entry.has("is_fetcher_out") and "is_fetcher_out" in building_instance:
			building_instance.is_fetcher_out = bool(entry.get("is_fetcher_out", false))
		if entry.has("fetch_target") and "fetch_target" in building_instance:
			building_instance.fetch_target = String(entry.get("fetch_target", ""))
		if entry.has("fetch_time_left") and "fetch_timer" in building_instance and building_instance.fetch_timer:
			var fetch_timer: Timer = building_instance.fetch_timer
			fetch_timer.stop()
			var fetch_left := float(entry.get("fetch_time_left", 0.0))
			if fetch_left > 0.0:
				fetch_timer.wait_time = max(fetch_left, 0.001)
				fetch_timer.start(fetch_left)
		if entry.has("is_upgrading") and "is_upgrading" in building_instance:
			building_instance.is_upgrading = bool(entry.get("is_upgrading", false))
			if building_instance.is_upgrading and "upgrade_timer" in building_instance and building_instance.upgrade_timer:
				var upgrade_timer: Timer = building_instance.upgrade_timer
				upgrade_timer.stop()
				var upgrade_left := float(entry.get("upgrade_time_left", 0.0))
				var upgrade_total := float(entry.get("upgrade_time_total", upgrade_timer.wait_time))
				if upgrade_total > 0.0:
					upgrade_timer.wait_time = max(upgrade_total, upgrade_left)
				if upgrade_left > 0.0:
					upgrade_timer.start(upgrade_left)
		if building_instance.has_method("_update_ui"):
			building_instance._update_ui()
		elif building_instance.has_method("update_ui"):
			building_instance.update_ui()
		var key: String = entry.get("key", "")
		if key != "":
			restored_map[key] = building_instance
		restored_count += 1
	
	return restored_map

func _on_time_advanced(total_minutes: int, start_day: int, start_hour: int, start_minute: int) -> void:
	if total_minutes <= 0:
		return
	# Skip simulation if we're leaving village (only advancing time, no production)
	if _is_leaving_village:
		print("[VillageManager] ⏸️ Skipping simulation - leaving village (only advancing time)")
		return
	# Use snapshot time if available (when returning from forest/dungeon)
	# Otherwise use the provided start time
	var sim_start_day := start_day
	var sim_start_hour := start_hour
	var sim_start_minute := start_minute
	if not _saved_snapshot_time.is_empty():
		sim_start_day = int(_saved_snapshot_time.get("day", start_day))
		sim_start_hour = int(_saved_snapshot_time.get("hour", start_hour))
		sim_start_minute = int(_saved_snapshot_time.get("minute", start_minute))
		print("[VillageManager] Using snapshot time for simulation: Day %d, %02d:%02d" % [sim_start_day, sim_start_hour, sim_start_minute])
		# Clear after use
		_saved_snapshot_time = {}
	_simulate_time_skip(total_minutes, sim_start_day, sim_start_hour, sim_start_minute)

func _simulate_time_skip(total_minutes: int, start_day: int, start_hour: int, start_minute: int) -> void:
	# Validation: Check for invalid input values
	if total_minutes <= 0:
		print("[VillageManager] ⚠️ Invalid total_minutes: %d. Skipping simulation." % total_minutes)
		return
	
	# Check for extremely large values (prevent performance issues)
	# Max: 1000 days = 1,440,000 minutes
	var max_minutes: int = 1000 * TimeManager.HOURS_PER_DAY * TimeManager.MINUTES_PER_HOUR
	if total_minutes > max_minutes:
		push_warning("[VillageManager] ⚠️ Very large time skip detected: %d minutes (%.1f days). Capping to %d minutes." % [total_minutes, float(total_minutes) / float(TimeManager.MINUTES_PER_HOUR * TimeManager.HOURS_PER_DAY), max_minutes])
		total_minutes = max_minutes
	
	# Validate start time
	if start_day < 0:
		push_warning("[VillageManager] ⚠️ Negative start_day detected: %d. Setting to 1." % start_day)
		start_day = 1
	if start_hour < 0 or start_hour >= TimeManager.HOURS_PER_DAY:
		push_warning("[VillageManager] ⚠️ Invalid start_hour detected: %d. Setting to 0." % start_hour)
		start_hour = 0
	if start_minute < 0 or start_minute >= TimeManager.MINUTES_PER_HOUR:
		push_warning("[VillageManager] ⚠️ Invalid start_minute detected: %d. Setting to 0." % start_minute)
		start_minute = 0
	
	# Check if we have any workers (log warning if none)
	var worker_maps := _build_worker_maps()
	var resource_counts: Dictionary = worker_maps.get("resource_counts", {})
	var building_worker_map: Dictionary = worker_maps.get("building_map", {})
	var total_workers: int = 0
	for count in resource_counts.values():
		total_workers += int(count)
	if total_workers == 0:
		print("[VillageManager] ℹ️ No workers assigned to production during time skip. Resources will not increase.")
	
	# Save resource levels before simulation to calculate production
	var resources_before: Dictionary = {}
	for res in BASE_RESOURCE_TYPES:
		resources_before[res] = resource_levels.get(res, 0)
	# Also track advanced resources produced during simulation
	var advanced_resources_before: Dictionary = {}
	for res in ["lumber", "brick", "metal", "cloth", "garment", "bread", "tea", "medicine", "soap"]:
		advanced_resources_before[res] = resource_levels.get(res, 0)
	var seconds_per_minute: float = float(TimeManager.SECONDS_PER_GAME_MINUTE)
	var work_start := TimeManager.WORK_START_HOUR
	var work_end := TimeManager.WORK_END_HOUR
	var minutes_per_hour := TimeManager.MINUTES_PER_HOUR
	var hours_per_day := TimeManager.HOURS_PER_DAY

	var current_hour := start_hour % hours_per_day
	var current_minute := start_minute % minutes_per_hour
	var current_day := start_day
	var produced_basic := false
	var advanced_changed := false
	var upgrade_completed := false

	var total_seconds := float(total_minutes) * seconds_per_minute
	var total_hours := float(total_minutes) / float(minutes_per_hour)
	
	# Performance optimization: For long time skips (> 1 day), use hourly batch simulation
	# For shorter skips (< 1 day), simulate minute by minute for accuracy
	var use_batch_simulation: bool = total_minutes > minutes_per_hour * hours_per_day
	var batch_size: int = minutes_per_hour if use_batch_simulation else 1  # 1 hour batches or 1 minute batches
	var batch_iterations: int = total_minutes / batch_size if use_batch_simulation else total_minutes
	var remaining_minutes: int = total_minutes % batch_size if use_batch_simulation else 0
	var seconds_per_batch: float = float(batch_size) * seconds_per_minute
	
	if use_batch_simulation:
		print("[VillageManager] ⚡ Using optimized batch simulation: %d hours (%d batches + %d minutes remainder)" % [int(total_hours), batch_iterations, remaining_minutes])
	
	# Simulate full batches
	for i in range(batch_iterations):
		# Check if current time is work time
		var is_work_time := current_hour >= work_start and current_hour < work_end
		if is_work_time:
			# Simulate production for this batch
			if use_batch_simulation:
				# Hourly batch: simulate one hour's worth of production
				if _simulate_basic_production_minute(seconds_per_batch, resource_counts):
					produced_basic = true
				if _simulate_advanced_buildings_minute(seconds_per_batch, building_worker_map):
					advanced_changed = true
			else:
				# Minute by minute: accurate simulation for short skips
				if _simulate_basic_production_minute(seconds_per_minute, resource_counts):
					produced_basic = true
				if _simulate_advanced_buildings_minute(seconds_per_minute, building_worker_map):
					advanced_changed = true
		
		# Advance time by batch size
		if use_batch_simulation:
			# Advance by one hour
			current_hour = (current_hour + 1) % hours_per_day
			if current_hour == 0:
				current_day += 1
		else:
			# Advance by one minute
			current_minute += 1
			if current_minute >= minutes_per_hour:
				current_minute = 0
				current_hour = (current_hour + 1) % hours_per_day
				if current_hour == 0:
					current_day += 1
	
	# Simulate remaining minutes (if using batch simulation and there's a remainder)
	if use_batch_simulation and remaining_minutes > 0:
		# Simulate remaining minutes minute by minute for accuracy
		for i in range(remaining_minutes):
			var is_work_time := current_hour >= work_start and current_hour < work_end
			if is_work_time:
				if _simulate_basic_production_minute(seconds_per_minute, resource_counts):
					produced_basic = true
				if _simulate_advanced_buildings_minute(seconds_per_minute, building_worker_map):
					advanced_changed = true
			# Advance time by one minute
			current_minute += 1
			if current_minute >= minutes_per_hour:
				current_minute = 0
				current_hour = (current_hour + 1) % hours_per_day
				if current_hour == 0:
					current_day += 1
	
	_simulate_upgrades_during_skip(total_seconds)
	if _simulate_events_during_skip(total_minutes, start_day, current_day):
		advanced_changed = true

	if produced_basic or advanced_changed or upgrade_completed:
		emit_signal("village_data_changed")
	
	# Calculate produced resources and emit notification signal
	var produced_resources: Dictionary = {}
	for res in BASE_RESOURCE_TYPES:
		var before = resources_before.get(res, 0)
		var after = resource_levels.get(res, 0)
		var produced = after - before
		if produced > 0:
			produced_resources[res] = produced
	for res in advanced_resources_before.keys():
		var before = advanced_resources_before.get(res, 0)
		var after = resource_levels.get(res, 0)
		var produced = after - before
		if produced > 0:
			produced_resources[res] = produced
	
	if total_hours > 0.0:
		print("[VillageManager] 📢 Emitting time_skip_completed signal: %.1f hours, resources: %s" % [total_hours, produced_resources])
		# Check if village scene is loaded - if not, save notification for later
		if is_instance_valid(village_scene_instance):
			emit_signal("time_skip_completed", total_hours, produced_resources)
		else:
			# Scene not loaded yet, save notification for when scene loads
			_pending_time_skip_notification = {
				"total_hours": total_hours,
				"produced_resources": produced_resources
			}
			print("[VillageManager] ⏸️ Village scene not loaded, saving notification for later: %.1f hours" % total_hours)
	else:
		print("[VillageManager] ⚠️ Not emitting time_skip_completed: total_hours = %.1f" % total_hours)

func _simulate_basic_production_minute(game_seconds: float, resource_counts: Dictionary) -> bool:
	var produced_any := false
	var morale_mult: float = _get_morale_multiplier()
	var prod_mult: float = (1.0 + building_bonus + caregiver_bonus) * global_multiplier
	for resource_type in BASE_RESOURCE_TYPES:
		var active_workers: int = int(resource_counts.get(resource_type, 0))
		if active_workers <= 0:
			continue
		var res_mult: float = float(resource_prod_multiplier.get(resource_type, 1.0))
		var progress_increment: float = game_seconds * float(active_workers) * morale_mult * prod_mult * res_mult
		base_production_progress[resource_type] = base_production_progress.get(resource_type, 0.0) + progress_increment
		if base_production_progress[resource_type] >= SECONDS_PER_RESOURCE_UNIT:
			var units: int = int(floor(base_production_progress[resource_type] / SECONDS_PER_RESOURCE_UNIT))
			if units > 0:
				var cap: int = _get_storage_capacity_for(resource_type)
				if cap > 0:
					var cur: int = int(resource_levels.get(resource_type, 0))
					var allowed: int = max(0, cap - cur)
					units = min(units, allowed)
				if units > 0:
					resource_levels[resource_type] = resource_levels.get(resource_type, 0) + units
					_daily_production_counter[resource_type] = int(_daily_production_counter.get(resource_type, 0)) + units
					produced_any = true
				base_production_progress[resource_type] -= float(units) * SECONDS_PER_RESOURCE_UNIT
	return produced_any

func _simulate_advanced_buildings_minute(game_seconds: float, building_worker_map: Dictionary) -> bool:
	var changed := false
	var using_saved := not _saved_building_states.is_empty()
	if using_saved:
		for i in range(_saved_building_states.size()):
			var entry: Dictionary = _saved_building_states[i]
			var key: String = String(entry.get("key", ""))
			var assigned_list = building_worker_map.get(key, [])
			var assigned_count := 0
			if assigned_list is Array:
				assigned_count = (assigned_list as Array).size()
			else:
				assigned_count = int(entry.get("assigned_workers", 0))
			if assigned_count <= 0:
				entry["assigned_workers"] = assigned_count
				_saved_building_states[i] = entry
				continue
			if _simulate_building_entry(entry, assigned_count, game_seconds):
				changed = true
			_saved_building_states[i] = entry
	else:
		if not is_instance_valid(village_scene_instance):
			return changed
		var placed := village_scene_instance.get_node_or_null("PlacedBuildings")
		if not placed:
			return changed
		for building in placed.get_children():
			if not (building is Node2D):
				continue
			var key := _make_building_snapshot_key(building.scene_file_path, (building as Node2D).global_position)
			var assigned_list = building_worker_map.get(key, [])
			var assigned_count := 0
			if assigned_list is Array:
				assigned_count = (assigned_list as Array).size()
			elif "assigned_workers" in building:
				assigned_count = int(building.assigned_workers)
			if assigned_count <= 0:
				continue
			var entry := _capture_building_state(building)
			if entry.is_empty():
				continue
			if _simulate_building_entry(entry, assigned_count, game_seconds):
				changed = true
			_apply_entry_state_to_building(entry, building)
	return changed

func _simulate_building_entry(entry: Dictionary, assigned_count: int, game_seconds: float) -> bool:
	var produced_resource := String(entry.get("produced_resource", ""))
	var production_time := float(entry.get("production_time", 0.0))
	if produced_resource == "" or production_time <= 0.0:
		entry["production_progress"] = float(entry.get("production_progress", 0.0))
		entry["assigned_workers"] = assigned_count
		return false
	entry["assigned_workers"] = assigned_count
	if assigned_count <= 0:
		return false
	var required_resources: Dictionary = entry.get("required_resources", {})
	if required_resources == null:
		required_resources = {}
	var input_buffer: Dictionary = entry.get("input_buffer", {})
	if input_buffer == null:
		input_buffer = {}
	else:
		input_buffer = _copy_dictionary(input_buffer)
	var fetch_time := float(entry.get("fetch_time", 0.0))
	var fetch_progress: Dictionary = entry.get("fetch_progress", {})
	if fetch_progress == null:
		fetch_progress = {}
	var progress: float = float(entry.get("production_progress", 0.0))
	var changed := false

	if not required_resources.is_empty():
		for res in required_resources.keys():
			var need_each := int(required_resources[res])
			var buffer_amount := int(input_buffer.get(res, 0))
			if buffer_amount < need_each:
				var timer_val := float(fetch_progress.get(res, 0.0))
				timer_val -= game_seconds
				if timer_val <= 0.0:
					var available := int(resource_levels.get(res, 0))
					if available > 0:
						input_buffer[res] = buffer_amount + 1
						resource_levels[res] = available - 1
						changed = true
						buffer_amount += 1
						timer_val += fetch_time if fetch_time > 0.0 else 0.0
					else:
						timer_val = 0.0
				fetch_progress[res] = timer_val
			else:
				fetch_progress[res] = max(0.0, float(fetch_progress.get(res, 0.0)))

	progress += game_seconds * float(assigned_count)
	var produced_units := 0
	while progress >= production_time:
		var can_produce := true
		if not required_resources.is_empty():
			for res in required_resources.keys():
				var need_each := int(required_resources[res])
				if int(input_buffer.get(res, 0)) < need_each:
					can_produce = false
					break
		if can_produce:
			for res in required_resources.keys():
				var need_each := int(required_resources[res])
				input_buffer[res] = int(input_buffer.get(res, 0)) - need_each
			resource_levels[produced_resource] = int(resource_levels.get(produced_resource, 0)) + 1
			_daily_production_counter[produced_resource] = int(_daily_production_counter.get(produced_resource, 0)) + 1
			produced_units += 1
			changed = true
			progress -= production_time
		else:
			progress = 0.0
			break

	entry["production_progress"] = progress
	entry["input_buffer"] = input_buffer
	entry["fetch_progress"] = fetch_progress
	entry["is_fetcher_out"] = false
	entry["fetch_target"] = ""
	return changed

func _build_worker_maps() -> Dictionary:
	var resource_counts: Dictionary = {}
	for res in BASE_RESOURCE_TYPES:
		resource_counts[res] = 0
	var building_map: Dictionary = {}
	if not _saved_worker_states.is_empty():
		for worker_entry in _saved_worker_states:
			var job_type := String(worker_entry.get("job_type", ""))
			if resource_counts.has(job_type):
				resource_counts[job_type] = int(resource_counts.get(job_type, 0)) + 1
			var key := String(worker_entry.get("building_key", ""))
			if key != "":
				if not building_map.has(key):
					building_map[key] = []
				(building_map[key] as Array).append(worker_entry)
	else:
		for worker_id in all_workers.keys():
			var worker_data = all_workers.get(worker_id, {})
			if not worker_data:
				continue
			var worker_instance: Node = worker_data.get("instance", null)
			if not is_instance_valid(worker_instance):
				continue
			var job_type := ""
			if "assigned_job_type" in worker_instance:
				job_type = worker_instance.get("assigned_job_type")
			if resource_counts.has(job_type):
				resource_counts[job_type] = int(resource_counts.get(job_type, 0)) + 1
			var building = worker_instance.get("assigned_building_node") if "assigned_building_node" in worker_instance else null
			if is_instance_valid(building) and building is Node2D:
				var key := _make_building_snapshot_key(building.scene_file_path, (building as Node2D).global_position)
				if not building_map.has(key):
					building_map[key] = []
				(building_map[key] as Array).append(worker_id)
	return {
		"resource_counts": resource_counts,
		"building_map": building_map
	}

func _capture_building_state(building: Node) -> Dictionary:
	if not (building is Node2D):
		return {}
	var entry: Dictionary = {}
	entry["scene_path"] = building.scene_file_path if "scene_file_path" in building else ""
	entry["position"] = (building as Node2D).global_position
	entry["global_position"] = (building as Node2D).global_position
	entry["local_position"] = (building as Node2D).position
	entry["key"] = _make_building_snapshot_key(entry["scene_path"], entry["position"])
	if "level" in building:
		entry["level"] = int(building.level)
	if "produced_resource" in building:
		entry["produced_resource"] = String(building.produced_resource)
	else:
		entry["produced_resource"] = ""
	if "required_resources" in building:
		entry["required_resources"] = _copy_dictionary(building.required_resources)
	if "input_buffer" in building:
		entry["input_buffer"] = _copy_dictionary(building.input_buffer)
	if "production_progress" in building:
		entry["production_progress"] = float(building.production_progress)
	if "PRODUCTION_TIME" in building:
		entry["production_time"] = float(building.PRODUCTION_TIME)
	if "FETCH_TIME_PER_UNIT" in building:
		entry["fetch_time"] = float(building.FETCH_TIME_PER_UNIT)
	entry["fetch_progress"] = entry.get("fetch_progress", {})
	entry["assigned_workers"] = int(building.assigned_workers) if "assigned_workers" in building else 0
	return entry

func _apply_entry_state_to_building(entry: Dictionary, building: Node) -> void:
	if "production_progress" in entry and "production_progress" in building:
		building.production_progress = float(entry.get("production_progress", 0.0))
	if "input_buffer" in entry and "input_buffer" in building:
		building.input_buffer = _copy_dictionary(entry.get("input_buffer", {}))
	if "is_fetcher_out" in entry and "is_fetcher_out" in building:
		building.is_fetcher_out = bool(entry.get("is_fetcher_out", false))
	if "fetch_target" in entry and "fetch_target" in building:
		building.fetch_target = String(entry.get("fetch_target", ""))
	if "assigned_workers" in entry and "assigned_workers" in building:
		building.assigned_workers = int(entry.get("assigned_workers", building.assigned_workers))

func _copy_dictionary(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		var value = source[key]
		if value is Dictionary:
			result[key] = _copy_dictionary(value)
		elif value is Array:
			result[key] = (value as Array).duplicate(true)
		else:
			result[key] = value
	return result

func _simulate_upgrades_during_skip(total_seconds: float) -> void:
	if not is_instance_valid(village_scene_instance):
		return
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return
	for building in placed_buildings.get_children():
		if not (building is Node2D):
			continue
		if "is_upgrading" not in building or not building.is_upgrading:
			continue
		if "upgrade_timer" not in building or not building.upgrade_timer:
			continue
		var timer: Timer = building.upgrade_timer
		var time_left := timer.time_left
		if time_left <= total_seconds:
			if "upgrade_finished" in building and building.has_method("_on_upgrade_finished"):
				building._on_upgrade_finished()
			else:
				if "is_upgrading" in building:
					building.is_upgrading = false
				if "level" in building:
					var next_level = int(building.level) + 1
					if "max_level" in building:
						var max_lvl = int(building.max_level) if building.max_level != null else 999
						if next_level <= max_lvl:
							building.level = next_level
							if "max_workers" in building and building.level == next_level:
								building.max_workers = next_level
					else:
						building.level = next_level
				if "upgrade_finished" in building:
					building.upgrade_finished.emit()
				if "state_changed" in building:
					building.state_changed.emit()
				notify_building_state_changed(building)
		else:
			timer.stop()
			timer.wait_time = time_left - total_seconds
			timer.start(time_left - total_seconds)

func _simulate_events_during_skip(total_minutes: int, start_day: int, end_day: int) -> bool:
	var changed := false
	
	# Handle existing event system (if enabled)
	if events_enabled:
		for i in range(start_day + 1, end_day + 1):
			_update_events_for_new_day(i)
			changed = true
	
	# Handle village-specific events
	if village_events_enabled:
		for i in range(start_day + 1, end_day + 1):
			if _check_and_trigger_village_event(i):
				changed = true
	
	return changed

func _apply_saved_worker_states(_restored_buildings_map: Dictionary) -> void:
	print("[VillageManager] 🔄 DEBUG: Starting _apply_saved_worker_states() with %d saved states, %d buildings in map" % [_saved_worker_states.size(), _restored_buildings_map.size()])
	if _saved_worker_states.is_empty():
		print("[VillageManager] ⚠️ DEBUG: _saved_worker_states is empty, nothing to apply")
		return
	
	var tm = get_node_or_null("/root/TimeManager")
	var current_hour: int = 6
	var current_minute: int = 0
	if tm and tm.has_method("get_hour"):
		current_hour = tm.get_hour()
	if tm and tm.has_method("get_minute"):
		current_minute = tm.get_minute()
	
	var work_start_hour: int = 7
	var work_end_hour: int = 18
	var sleep_hour: int = 22
	var wake_hour: int = 6
	if tm and "WORK_START_HOUR" in tm:
		work_start_hour = tm.WORK_START_HOUR
	if tm and "WORK_END_HOUR" in tm:
		work_end_hour = tm.WORK_END_HOUR
	if tm and "SLEEP_HOUR" in tm:
		sleep_hour = tm.SLEEP_HOUR
	if tm and "WAKE_UP_HOUR" in tm:
		wake_hour = tm.WAKE_UP_HOUR
	
	var is_work_time: bool = current_hour >= work_start_hour and current_hour < work_end_hour
	var is_sleep_time: bool = current_hour >= sleep_hour or current_hour < wake_hour
	
	var applied_count = 0
	for worker_entry in _saved_worker_states:
		var saved_worker_id: int = worker_entry.get("worker_id", -1)
		var job_type: String = worker_entry.get("job_type", "")
		var building_key: String = worker_entry.get("building_key", "")
		print("[VillageManager] 🔍 DEBUG: Processing worker entry - ID: %d, Job: %s, Building Key: %s" % [saved_worker_id, job_type, building_key])
		
		var assigned_worker: Node = null
		if saved_worker_id >= 0 and all_workers.has(saved_worker_id):
			var worker_data = all_workers.get(saved_worker_id, {})
			if worker_data and worker_data.has("instance"):
				assigned_worker = worker_data.get("instance", null)
		
		if not is_instance_valid(assigned_worker):
			for worker_id in all_workers.keys():
				var worker_data = all_workers.get(worker_id, {})
				if not worker_data:
					continue
				var worker_instance: Node = worker_data.get("instance", null)
				if not is_instance_valid(worker_instance):
					continue
				var worker_job: String = ""
				if worker_instance and "assigned_job_type" in worker_instance:
					var job_val = worker_instance.get("assigned_job_type")
					worker_job = job_val if job_val is String else ""
				if worker_job.is_empty() and assigned_worker == null:
					assigned_worker = worker_instance
		
		if not is_instance_valid(assigned_worker):
			continue
		
		if job_type.is_empty():
			print("[VillageManager] ⚠️ DEBUG: Worker %d has no job_type, skipping" % saved_worker_id)
			continue
		
		var worker_instance = assigned_worker
		var assigned_building: Node2D = null
		
		if not building_key.is_empty() and _restored_buildings_map.has(building_key):
			assigned_building = _restored_buildings_map[building_key]
			print("[VillageManager] ✅ DEBUG: Found building for key '%s'" % building_key)
		
		if not is_instance_valid(assigned_building):
			var target_script_path = RESOURCE_PRODUCER_SCRIPTS.get(job_type, "")
			if not target_script_path.is_empty() and is_instance_valid(village_scene_instance):
				var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
				if placed_buildings:
					for building in placed_buildings.get_children():
						if building.has_method("get_script") and building.get_script() != null:
							var building_script = building.get_script()
							if building_script is GDScript and building_script.resource_path == target_script_path:
								if "assigned_workers" in building:
									var current_assigned = int(building.assigned_workers)
									if "max_workers" in building:
										var max_w = int(building.max_workers) if building.max_workers != null else 999
										if current_assigned < max_w:
											assigned_building = building
											break
								else:
									assigned_building = building
									break
		
		if not is_instance_valid(assigned_building):
			print("[VillageManager] ⚠️ DEBUG: Building not found for worker %d, key: %s" % [saved_worker_id, building_key])
			continue
		
		if worker_instance.has_method("set"):
			worker_instance.set("assigned_job_type", job_type)
			worker_instance.set("assigned_building_node", assigned_building)
			# Askerler için is_deployed durumunu restore et
			if job_type == "soldier" and worker_entry.has("is_deployed"):
				var saved_is_deployed = worker_entry.get("is_deployed", false)
				worker_instance.set("is_deployed", saved_is_deployed)
			print("[VillageManager] ✅ DEBUG: Assigned worker %d to building %s with job %s (is_deployed: %s)" % [saved_worker_id, assigned_building.scene_file_path.get_file(), job_type, worker_instance.get("is_deployed") if "is_deployed" in worker_instance else "N/A"])
		
		if "assigned_worker_ids" in assigned_building:
			var worker_id_val: int = -1
			if worker_instance and "worker_id" in worker_instance:
				var id_val = worker_instance.get("worker_id")
				worker_id_val = id_val if id_val is int else -1
			if worker_id_val >= 0 and not (worker_id_val in assigned_building.assigned_worker_ids):
				assigned_building.assigned_worker_ids.append(worker_id_val)
				if "assigned_workers" in assigned_building:
					assigned_building.assigned_workers = int(assigned_building.assigned_worker_ids.size())

		idle_workers = max(0, idle_workers - 1)
		applied_count += 1
		
		if not worker_instance.has_method("get") or "current_state" not in worker_instance:
			print("[VillageManager] ⚠️ DEBUG: Worker %d has no current_state property" % saved_worker_id)
			continue
		
		if is_sleep_time:
			worker_instance.current_state = 0
			var housing = worker_instance.get("housing_node") if worker_instance else null
			if is_instance_valid(housing) and housing is Node2D:
				var housing_pos = (housing as Node2D).global_position
				if worker_instance is Node2D:
					(worker_instance as Node2D).global_position = housing_pos
			worker_instance.visible = false
			print("[VillageManager] 😴 DEBUG: Worker %d set to sleep state" % saved_worker_id)
		elif is_work_time:
			# ASKER İSTİSNASI: Askerler köyde geziniyorlar (deploy edilmedikleri sürece)
			if job_type == "soldier":
				# Askerler için is_deployed kontrolü yap (save'den restore edilmiş olabilir)
				var is_deployed_val = worker_instance.get("is_deployed") if "is_deployed" in worker_instance else false
				if is_deployed_val:
					# Deploy edilmiş askerler ekran dışında
					worker_instance.current_state = 4  # WAITING_OFFSCREEN
					worker_instance.visible = false
					print("[VillageManager] ⚔️ DEBUG: Soldier %d is deployed (offscreen)" % saved_worker_id)
				else:
					# Deploy edilmemiş askerler köyde geziniyor
					worker_instance.current_state = 7  # SOCIALIZING
					worker_instance.visible = true
					# Askerleri kışla yakınına yerleştir
					if assigned_building is Node2D:
						var building_pos = (assigned_building as Node2D).global_position
						if worker_instance is Node2D:
							var worker_node2d = worker_instance as Node2D
							# Kışla yakınında rastgele bir pozisyon
							worker_node2d.global_position = Vector2(
								building_pos.x + randf_range(-100.0, 100.0),
								building_pos.y + randf_range(-50.0, 50.0)
							)
							worker_node2d.move_target_x = worker_node2d.global_position.x
					print("[VillageManager] ⚔️ DEBUG: Soldier %d set to socializing (village patrol)" % saved_worker_id)
			else:
				# Normal işçiler için çalışma mantığı
				var go_inside = false
				if "worker_stays_inside" in assigned_building and assigned_building.worker_stays_inside:
					go_inside = true
				elif "level" in assigned_building and assigned_building.level >= 2:
					if "assigned_worker_ids" in assigned_building:
						var worker_ids = assigned_building.assigned_worker_ids
						if not worker_ids.is_empty():
							var worker_id_val: int = -1
							if worker_instance and "worker_id" in worker_instance:
								var id_val = worker_instance.get("worker_id")
								worker_id_val = id_val if id_val is int else -1
							if worker_id_val == worker_ids[0]:
								go_inside = true
				
				if go_inside:
					worker_instance.current_state = 5
					if assigned_building is Node2D:
						var building_pos = (assigned_building as Node2D).global_position
						if worker_instance is Node2D:
							(worker_instance as Node2D).global_position = building_pos
					worker_instance.visible = false
					print("[VillageManager] 🏢 DEBUG: Worker %d set to work inside building" % saved_worker_id)
				else:
					if assigned_building is Node2D:
						var building_pos = (assigned_building as Node2D).global_position
						var offscreen_x: float = -2500.0
						if building_pos.x >= 960:
							offscreen_x = 2500.0
						
						if worker_instance is Node2D:
							var worker_node2d = worker_instance as Node2D
							worker_node2d.global_position = Vector2(offscreen_x, building_pos.y)
							worker_instance.set("move_target_x", offscreen_x)
							worker_instance.set("_target_global_y", building_pos.y)
							worker_instance.set("_offscreen_exit_x", offscreen_x)
					
					worker_instance.current_state = 4
					worker_instance.visible = false
					print("[VillageManager] 🔨 DEBUG: Worker %d set to work offscreen" % saved_worker_id)
		else:
			# Ne uyku ne de çalışma saati (örneğin sabah 6-7 arası veya akşam 18-22 arası)
			# ASKER İSTİSNASI: Askerler köyde geziniyorlar
			if job_type == "soldier":
				# Askerler için is_deployed kontrolü yap (save'den restore edilmiş olabilir)
				var is_deployed_val = worker_instance.get("is_deployed") if "is_deployed" in worker_instance else false
				if is_deployed_val:
					worker_instance.current_state = 4  # WAITING_OFFSCREEN
					worker_instance.visible = false
					print("[VillageManager] ⚔️ DEBUG: Soldier %d is deployed (offscreen, non-work time)" % saved_worker_id)
				else:
					worker_instance.current_state = 7  # SOCIALIZING
					worker_instance.visible = true
					# Askerleri kışla yakınına yerleştir
					if assigned_building is Node2D:
						var building_pos = (assigned_building as Node2D).global_position
						if worker_instance is Node2D:
							var worker_node2d = worker_instance as Node2D
							worker_node2d.global_position = Vector2(
								building_pos.x + randf_range(-100.0, 100.0),
								building_pos.y + randf_range(-50.0, 50.0)
							)
							worker_node2d.move_target_x = worker_node2d.global_position.x
					print("[VillageManager] ⚔️ DEBUG: Soldier %d set to socializing (non-work time)" % saved_worker_id)
			else:
				# Normal işçiler için AWAKE_IDLE state'ine ayarla
				worker_instance.current_state = 1
				worker_instance.visible = true
			
			# Eğer worker'ın bir işi varsa ve çalışma saati yakınsa, işe gitmesi için kontrol et
			# Bu, yükleme sonrası çalışma saati geldiğinde worker'ların işe gitmesini sağlar
			if job_type != "" and job_type != "soldier" and is_instance_valid(assigned_building):
				# Çalışma saati kontrolü: WORK_START_HOUR ile WORK_END_HOUR arası
				var is_work_start_hour = current_hour == work_start_hour
				var work_start_minute_offset = 0
				# Worker instance'ından work_start_minute_offset değerini güvenli şekilde al
				if worker_instance.has_method("get"):
					var offset_val = worker_instance.get("work_start_minute_offset")
					work_start_minute_offset = offset_val if offset_val is int else 0
				var passed_offset = current_minute >= work_start_minute_offset
				
				# Çalışma saatleri içindeyse ve (ilk çalışma saatinde değilse VEYA dakika offset'i geçmişse) işe git
				if current_hour >= work_start_hour and current_hour < work_end_hour:
					if not is_work_start_hour or passed_offset:
						worker_instance.current_state = 2  # GOING_TO_BUILDING_FIRST
						if assigned_building is Node2D:
							var building_pos = (assigned_building as Node2D).global_position
							if worker_instance is Node2D:
								var worker_node2d = worker_instance as Node2D
								worker_node2d.move_target_x = building_pos.x
								worker_node2d._target_global_y = randf_range(0.0, 25.0)  # VERTICAL_RANGE_MAX değeri
						print("[VillageManager] 🏃 DEBUG: Worker %d set to go to work (after load, work time check)" % saved_worker_id)
			
			print("[VillageManager] ☀️ DEBUG: Worker %d set to awake idle state" % saved_worker_id)
	
	print("[VillageManager] ✅ DEBUG: Applied %d worker states (out of %d saved)" % [applied_count, _saved_worker_states.size()])

func _sync_soldiers_with_missions() -> void:
	"""Görev ormandayken tamamlandıysa askerler geri çağrılmamış olabilir (sahne yoktu).
	Şu an aktif görevde olmayan ama is_deployed=true kalan askerleri köye geri getir."""
	var mm = get_node_or_null("/root/MissionManager")
	if not mm or not mm.has_method("get_raid_mission_extra"):
		return
	var on_mission_wids: Dictionary = {}  # worker_id -> true
	for cariye_id in mm.active_missions:
		var mission_id = mm.active_missions[cariye_id]
		var extra = mm.get_raid_mission_extra(mission_id)
		var wids = extra.get("assigned_soldier_worker_ids", [])
		if wids is Array:
			for w in wids:
				var wid = int(w) if w is float else w
				on_mission_wids[wid] = true
	var barracks = _find_barracks()
	var return_x: float = 0.0
	if is_instance_valid(barracks):
		return_x = barracks.global_position.x
	elif campfire_node and is_instance_valid(campfire_node):
		return_x = campfire_node.global_position.x
	var brought_back = 0
	for wid in all_workers:
		var worker_data = all_workers.get(wid, {})
		var inst = worker_data.get("instance", null)
		if not is_instance_valid(inst):
			continue
		var job = inst.get("assigned_job_type") if "assigned_job_type" in inst else ""
		if job != "soldier":
			continue
		var deployed = inst.get("is_deployed") if "is_deployed" in inst else false
		if not deployed:
			continue
		if on_mission_wids.has(wid):
			continue
		inst.set("is_deployed", false)
		# Görev sen köyde değilken bitti; köye vardığında zaten kışla civarında idle olmalılar
		inst.set("current_state", 7)  # Worker.State.SOCIALIZING (kışla yakınında oturuyorlar)
		if inst is Node2D and is_instance_valid(barracks):
			var node2d := inst as Node2D
			var building_pos = barracks.global_position
			node2d.global_position = Vector2(
				building_pos.x + randf_range(-100.0, 100.0),
				building_pos.y + randf_range(-50.0, 50.0)
			)
			node2d.set("move_target_x", node2d.global_position.x)
			node2d.set("_target_global_y", node2d.global_position.y)
		inst.visible = true
		brought_back += 1
	if brought_back > 0:
		print("[VillageManager] ⚔️ _sync_soldiers_with_missions: %d asker geri getirildi (görev ormandayken tamamlanmıştı, kışla civarında idle)" % brought_back)

# İşçilerin ekleneceği parent node. @onready KULLANMAYIN,
# çünkü VillageManager'ın kendisi Autoload olabilir veya sahne ağacına farklı zamanda eklenebilir.
# Bu referansı _ready içinde veya ihtiyaç duyulduğunda alacağız.
# var workers_parent_node: Node = null #<<< SİLİNDİ

const STARTING_WORKER_COUNT = 3 # Başlangıç işçi sayısı (CampFire kapasitesi)
# ---------------------
var active_dialogue_npc: Node = null
var dialogue_npcs : Array

# === Economy Scaffold (Feature-flagged, non-breaking) ===
var economy_enabled: bool = true
var production_per_worker_base: float = 4.0
var building_bonus: float = 0.0
var caregiver_bonus: float = 0.0
var global_multiplier: float = 1.0
var per_frame_production_enabled: bool = true

var daily_water_per_pop: float = 0.5
var daily_food_per_pop: float = 0.5
var cariye_period_days: int = 7

var resource_prod_multiplier: Dictionary = {
	"wood": 1.0,
	"stone": 1.0,
	"food": 1.0,
	"water": 1.0,
	"lumber": 1.0,
	"brick": 1.0,
	"metal": 1.0,
	"cloth": 1.0,
	"garment": 1.0,
	"bread": 1.0,
	"tea": 1.0,
	"medicine": 1.0,
	"soap": 1.0,
	"weapon": 1.0,
	"armor": 1.0
}

var economy_stats_last_day: Dictionary = {
	"day": 0,
	"total_production": 0.0,
	"total_consumption": 0.0,
	"net": 0.0
}
var _daily_production_counter: Dictionary = {
	"wood": 0,
	"stone": 0,
	"food": 0,
	"water": 0,
	"lumber": 0,
	"brick": 0,
	"metal": 0,
	"cloth": 0,
	"garment": 0,
	"bread": 0,
	"tea": 0,
	"medicine": 0,
	"soap": 0
}
var village_morale: float = 80.0
var _last_day_shortages: Dictionary = {"water": 0, "food": 0}

var _last_econ_tick_day: int = 0

# === Events scaffold (feature-flagged) ===
var events_enabled: bool = true
var daily_event_chance: float = 0.05
var event_severity_min: float = 0.1  # Deprecated: artık kullanılmıyor, level sistemi kullanılıyor
var event_severity_max: float = 0.35  # Deprecated: artık kullanılmıyor, level sistemi kullanılıyor
var event_duration_min_days: int = 3
var event_duration_max_days: int = 14
var events_active: Array[Dictionary] = []
var _event_cooldowns: Dictionary = {} # type -> day_until

# Event seviyeleri ve çarpanları (fark edilir etkiler için)
enum EventLevel {
	LOW,      # Düşük: %20 azalma/artış
	MEDIUM,   # Orta: %40 azalma/artış
	HIGH      # Yüksek: %60 azalma/artış
}

const EVENT_LEVEL_MULTIPLIERS := {
	EventLevel.LOW: 0.8,      # %20 azalma (negatif eventler için)
	EventLevel.MEDIUM: 0.6,   # %40 azalma
	EventLevel.HIGH: 0.4      # %60 azalma
}

const EVENT_LEVEL_BONUS_MULTIPLIERS := {
	EventLevel.LOW: 1.2,      # %20 artış (pozitif eventler için)
	EventLevel.MEDIUM: 1.4,  # %40 artış
	EventLevel.HIGH: 1.6     # %60 artış
}

const EVENT_LEVEL_NAMES := {
	EventLevel.LOW: "Düşük",
	EventLevel.MEDIUM: "Orta",
	EventLevel.HIGH: "Yüksek"
}

# === Storage (feature-flagged usage via economy) ===
const STORAGE_PER_BASIC_BUILDING: int = 10
#Player reference in village
var Village_Player

func _connect_world_manager_signals() -> void:
	"""WorldManager sinyallerini bağla (gecikmeli çağrı)"""
	var wm = get_node_or_null("/root/WorldManager")
	if wm:
		if wm.has_signal("defense_deployment_started"):
			if not wm.defense_deployment_started.is_connected(_on_defense_deployment_started):
				wm.defense_deployment_started.connect(_on_defense_deployment_started)
				print("[VillageManager] ✅ defense_deployment_started sinyali bağlandı")
			else:
				print("[VillageManager] ⚠️ defense_deployment_started sinyali zaten bağlı")
		else:
			print("[VillageManager] ❌ defense_deployment_started sinyali bulunamadı!")
		if wm.has_signal("defense_battle_completed"):
			if not wm.defense_battle_completed.is_connected(_on_defense_battle_completed):
				wm.defense_battle_completed.connect(_on_defense_battle_completed)
				print("[VillageManager] ✅ defense_battle_completed sinyali bağlandı")
			else:
				print("[VillageManager] ⚠️ defense_battle_completed sinyali zaten bağlı")
		else:
			print("[VillageManager] ❌ defense_battle_completed sinyali bulunamadı!")
		if wm.has_signal("battle_story_generated"):
			if not wm.battle_story_generated.is_connected(_on_battle_story_generated):
				wm.battle_story_generated.connect(_on_battle_story_generated)
				print("[VillageManager] ✅ battle_story_generated sinyali bağlandı")
			else:
				print("[VillageManager] ⚠️ battle_story_generated sinyali zaten bağlı")
		else:
			print("[VillageManager] ❌ battle_story_generated sinyali bulunamadı!")
	else:
		print("[VillageManager] ❌ WorldManager bulunamadı! Tekrar denenecek...")
		# 1 saniye sonra tekrar dene
		var timer = get_tree().create_timer(1.0)
		timer.timeout.connect(_connect_world_manager_signals)

	# --- YENİ DEBUG PRINT'LERİ ---
	# Debug prints disabled to reduce console spam
	# print("VillageManager Ready: Cariyeler Count = ", cariyeler.size())
	# print("VillageManager Ready: Gorevler Count = ", gorevler.size())
	# print("VillageManager Ready: Initial resource levels set to 0.")


func register_village_scene(scene: Node2D) -> void:
	village_scene_instance = scene
	#print("VillageManager: VillageScene kaydedildi.")

	# --- İşçi Yönetimi Kurulumu (Buraya Taşındı) ---
	# CampFire'ı bul
	await get_tree().process_frame # Grupların güncel olduğundan emin ol
	campfire_node = get_tree().get_first_node_in_group("Housing")
	if campfire_node == null:
		#printerr("VillageManager Error (in register_village_scene): 'Housing' grubunda CampFire bulunamadı!")
		return

	# WorkersContainer'ı bul (artık scene referansımız var)
	workers_container = scene.get_node_or_null("WorkersContainer")
	if workers_container == null:
		#printerr("VillageManager Error (in register_village_scene): Kaydedilen sahnede 'WorkersContainer' node'u bulunamadı!")
		# Alternatif yolu deneyebiliriz ama sahne adı sabit olmalı:
		# workers_parent_node = get_tree().root.get_node_or_null("VillageScene/WorkersContainer") 
		# if workers_parent_node == null:
		#    #printerr("VillageManager Error: Root'tan da 'WorkersContainer' bulunamadı!")
		#    return
		return
	
	# ConcubinesContainer'ı bul
	concubines_container = scene.get_node_or_null("ConcubinesContainer")
	if concubines_container == null:
		#printerr("VillageManager Error (in register_village_scene): Kaydedilen sahnede 'ConcubinesContainer' node'u bulunamadı!")
		return
	
	# TradersContainer'ı bul ve tüccar NPC sinyalini bağla
	traders_container = scene.get_node_or_null("TradersContainer")
	if traders_container != null:
		var mm = get_node_or_null("/root/MissionManager")
		if mm and mm.has_signal("active_traders_updated"):
			if not mm.active_traders_updated.is_connected(_sync_trader_npcs):
				mm.active_traders_updated.connect(_sync_trader_npcs)
			call_deferred("_sync_trader_npcs")
	
	# Cariyeleri sahneye ekle
	_spawn_concubines_in_scene()
	
	# İlk isim görünürlük kontrolünü yap
	call_deferred("_update_nearest_npc_name_visibility")
	
	# Reset leaving flag when returning to village
	_is_leaving_village = false
	
	# Show pending notification if any (after scene is loaded)
	if not _pending_time_skip_notification.is_empty():
		var hours = _pending_time_skip_notification.get("total_hours", 0.0)
		var resources = _pending_time_skip_notification.get("produced_resources", {})
		print("[VillageManager] 📬 Showing pending notification: %.1f hours, resources: %s" % [hours, resources])
		# Wait a bit more for UI to fully initialize
		await get_tree().process_frame
		await get_tree().process_frame
		emit_signal("time_skip_completed", hours, resources)
		_pending_time_skip_notification = {}

	# Note: Resources are restored in SceneManager._handle_travel_time() BEFORE simulation
	# This function is called AFTER scene change, so resources should already be restored
	# But we still check here for first-time initialization
	if _saved_resource_levels.is_empty() and resource_levels.is_empty():
		# First time initialization - set defaults
		for res in BASE_RESOURCE_TYPES:
			if not resource_levels.has(res):
				resource_levels[res] = 0
		if not resource_levels.has("weapon"):
			resource_levels["weapon"] = 5
		if not resource_levels.has("armor"):
			resource_levels["armor"] = 5
	
	# Başlangıç işçilerini oluştur
	if workers_container and is_instance_valid(campfire_node):
		print("[VillageManager] 🔄 DEBUG: Starting worker restoration...")
		_reset_worker_runtime_data()
		worker_id_counter = 0
		var restored_buildings_map := _restore_saved_buildings()
		print("[VillageManager] 🔍 DEBUG: Restored buildings map has %d entries" % restored_buildings_map.size())
		
		# Kamp ateşinin kapasitesini yükle (eğer kaydedilmişse) - worker'lar yüklenmeden önce
		for entry in _saved_building_states:
			if entry.get("is_campfire", false) and "max_capacity" in entry:
				var saved_capacity = int(entry.get("max_capacity", 3))
				if "max_capacity" in campfire_node:
					campfire_node.max_capacity = saved_capacity
					print("[VillageManager] ✅ DEBUG: Campfire max_capacity restored to %d (before workers)" % saved_capacity)
				break
		var worker_entries: Array = []
		if _saved_worker_states.size() > 0:
			print("[VillageManager] 🔍 DEBUG: Found %d saved worker states" % _saved_worker_states.size())
			worker_entries = _saved_worker_states.duplicate(true)
			if has_method("_worker_entry_sorter"):
				worker_entries.sort_custom(Callable(self, "_worker_entry_sorter"))
			else:
				print("[VillageManager] ⚠️ DEBUG: _worker_entry_sorter method not found, skipping sort")
		elif is_instance_valid(VillagerAiInitializer) and VillagerAiInitializer.Saved_Villagers.size() > 0:
			for info in VillagerAiInitializer.Saved_Villagers:
				var info_copy: Dictionary = info.duplicate(true)
				worker_entries.append({
					"worker_id": -1,
					"npc_info": info_copy
				})
		else:
			for i in range(STARTING_WORKER_COUNT):
				worker_entries.append({
					"worker_id": -1,
					"npc_info": {}
				})
		var max_worker_id := 0
		var worker_created_count = 0
		for worker_entry in worker_entries:
			var worker_id_from_entry = worker_entry.get("worker_id", -1)
			var job_type_from_entry = worker_entry.get("job_type", "")
			var building_key_from_entry = worker_entry.get("building_key", "")
			var housing_key_from_entry = worker_entry.get("housing_key", "")  # Housing node referansı
			var info_dict: Dictionary = worker_entry.get("npc_info", {}).duplicate(true)
			print("[VillageManager] 🔄 DEBUG: Creating worker - Saved ID: %d, Job: %s, Building: %s, Housing: %s" % [worker_id_from_entry, job_type_from_entry, building_key_from_entry, housing_key_from_entry])
			
			# Worker'ı oluştur, ama housing_node'yu kaydet (sonra geri yükleyeceğiz)
			var saved_housing_key = housing_key_from_entry
			if _add_new_worker(info_dict):
				worker_created_count += 1
				var desired_id: int = int(worker_entry.get("worker_id", -1))
				var new_id: int = worker_id_counter
				if desired_id >= 0 and desired_id != new_id:
					print("[VillageManager] 🔄 DEBUG: Changing worker ID from %d to %d" % [new_id, desired_id])
					var worker_data = all_workers.get(new_id, {})
					if worker_data:
						all_workers.erase(new_id)
						var worker_instance: Node = worker_data.get("instance", null)
						if is_instance_valid(worker_instance):
							worker_instance.worker_id = desired_id
							worker_instance.name = "Worker" + str(desired_id)
						all_workers[desired_id] = worker_data
					worker_id_counter = max(worker_id_counter, desired_id)
					new_id = desired_id
				else:
					print("[VillageManager] ✅ DEBUG: Worker created with ID %d (desired: %d)" % [new_id, desired_id])
				
				# Housing node'u geri yükle (eğer kaydedilmişse)
				# Not: _add_new_worker içinde _assign_housing çağrılıyor, bu da yeni bir housing atıyor
				# Bu yüzden önceki housing'ı geri yüklemeliyiz
				if not saved_housing_key.is_empty():
					var worker_data = all_workers.get(new_id, {})
					var worker_instance: Node = worker_data.get("instance", null)
					if is_instance_valid(worker_instance):
						# Önce _assign_housing tarafından atanan housing'ı kaldır
						var current_housing = worker_instance.get("housing_node")
						if is_instance_valid(current_housing) and current_housing.has_method("remove_occupant"):
							# CampFire için worker argümanı gerekli, House için gerekli değil
							if current_housing.get_script() and current_housing.get_script().resource_path.ends_with("CampFire.gd"):
								# CampFire için worker instance'ı geç
								current_housing.remove_occupant(worker_instance)
							else:
								# House ve diğerleri için argüman geçme
								current_housing.remove_occupant()
						
						# Kaydedilmiş housing node'u bul ve geri yükle
						var housing_node = _find_housing_by_key(saved_housing_key)
						if is_instance_valid(housing_node):
							worker_instance.housing_node = housing_node
							# Housing node'un occupant sayısını güncelle (eğer method varsa)
							if housing_node.has_method("add_occupant"):
								housing_node.add_occupant(worker_instance)
							print("[VillageManager] ✅ DEBUG: Restored housing_node for worker %d (key: %s)" % [new_id, saved_housing_key])
						else:
							print("[VillageManager] ⚠️ DEBUG: Housing node not found for key: %s" % saved_housing_key)
				
				max_worker_id = max(max_worker_id, new_id)
			else:
				print("[VillageManager] ⚠️ DEBUG: Failed to create worker with saved ID %d" % worker_id_from_entry)
		worker_id_counter = max(worker_id_counter, max_worker_id)
		print("[VillageManager] ✅ DEBUG: Created %d workers, max ID: %d" % [worker_created_count, worker_id_counter])
		print("[VillageManager] 🔄 DEBUG: Applying saved worker states to buildings...")
		_apply_saved_worker_states(restored_buildings_map)
		# Görev ormandayken tamamlandıysa askerler geri çağrılmamış olabilir; yükleme sonrası senkronize et
		call_deferred("_sync_soldiers_with_missions")
		emit_signal("village_data_changed")
	#else:
		#if not workers_container:
			##printerr("VillageManager Ready Error: WorkersContainer bulunamadı!")
		#if not is_instance_valid(campfire_node):
			##printerr("VillageManager Ready Error: Campfire bulunamadı veya geçersiz!")
		#
	## --- Kaynak Seviyesi Hesaplama (YENİ) ---

	# Production progress already restored above if available, otherwise initialize
	for res in BASE_RESOURCE_TYPES:
		if not base_production_progress.has(res):
			base_production_progress[res] = 0.0

	# Economy daily tick hookup (non-breaking)
	var tm = get_node_or_null("/root/TimeManager")
	if tm and tm.has_signal("day_changed"):
		# Check if already connected to prevent duplicate connections
		if not tm.day_changed.is_connected(Callable(self, "_on_day_changed")):
			tm.connect("day_changed", Callable(self, "_on_day_changed"))
		_last_econ_tick_day = tm.get_day() if tm.has_method("get_day") else 0
	if tm:
		if tm.has_signal("hour_changed") and not _time_signal_connected:
			tm.connect("hour_changed", Callable(self, "_on_hour_changed"))
			_time_signal_connected = true
		if tm.has_signal("time_advanced") and not _time_advanced_connected:
			tm.connect("time_advanced", Callable(self, "_on_time_advanced"))
			_time_advanced_connected = true
		_apply_time_of_day(tm.get_hour() if tm.has_method("get_hour") else 0)
	else:
		_apply_time_of_day(6)

# Belirli bir kaynak türünü üreten Tescilli Script Yolları
# Bu, get_resource_level için gereklidir
const RESOURCE_PRODUCER_SCRIPTS = {
	"wood": "res://village/scripts/WoodcutterCamp.gd",
	"stone": "res://village/scripts/StoneMine.gd",
	"food": "res://village/scripts/HunterGathererHut.gd", # Veya Tarla/Balıkçı vb.
	"water": "res://village/scripts/Well.gd",
	"lumber": "res://village/scripts/Sawmill.gd",
	"brick": "res://village/scripts/Brickworks.gd",
	"metal": "res://village/scripts/Blacksmith.gd",
	"bread": "res://village/scripts/Bakery.gd", #<<< YENİ
	"cloth": "res://village/scripts/Weaver.gd",
	"garment": "res://village/scripts/Tailor.gd",
	"tea": "res://village/scripts/TeaHouse.gd",
	"medicine": "res://village/scripts/Herbalist.gd",
	"soap": "res://village/scripts/SoapMaker.gd",
	"weapon": "res://village/scripts/Gunsmith.gd",
	"armor": "res://village/scripts/Armorer.gd",
	"soldier": "res://village/scripts/Barracks.gd" # Asker işçi türü eklendi
}

# Scene path mapping for robust counting (some checks rely on scene_file_path)
const RESOURCE_PRODUCER_SCENES = {
	"wood": "res://village/buildings/WoodcutterCamp.tscn",
	"stone": "res://village/buildings/StoneMine.tscn",
	"food": "res://village/buildings/HunterGathererHut.tscn",
	"water": "res://village/buildings/Well.tscn",
	"lumber": "res://village/buildings/Sawmill.tscn",
	"brick": "res://village/buildings/Brickworks.tscn",
	"metal": "res://village/buildings/Blacksmith.tscn",
	"bread": "res://village/buildings/Bakery.tscn",
	"cloth": "res://village/buildings/Weaver.tscn",
	"garment": "res://village/buildings/Tailor.tscn",
	"tea": "res://village/buildings/TeaHouse.tscn",
	"medicine": "res://village/buildings/Herbalist.tscn",
	"soap": "res://village/buildings/SoapMaker.tscn",
	"weapon": "res://village/buildings/Gunsmith.tscn",
	"armor": "res://village/buildings/Armorer.tscn"
}

# Bir kaynak türünün mevcut stok seviyesini döndürür (temel ve gelişmiş için ortak)
func get_resource_level(resource_type: String) -> int:
	return resource_levels.get(resource_type, 0)

# İç yardımcı: Belirli bir temel kaynak için atanan toplam işçi sayısını sayar
func _count_assigned_workers_for_resource(resource_type: String) -> int:
	if not RESOURCE_PRODUCER_SCRIPTS.has(resource_type):
		return 0
	if not is_instance_valid(village_scene_instance):
		return 0
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return 0
	var target_script_path = RESOURCE_PRODUCER_SCRIPTS[resource_type]
	var total_workers_for_resource = 0
	for building in placed_buildings.get_children():
		if building.has_method("get_script") and building.get_script() != null:
			var building_script = building.get_script()
			if building_script is GDScript and building_script.resource_path == target_script_path:
				if "assigned_workers" in building:
					total_workers_for_resource += int(building.assigned_workers)
	return total_workers_for_resource

# İç yardımcı: Belirli bir temel kaynak için atanan işçi sayısını sayar (mesai saatlerinde sürekli çalışır)
func _count_active_workers_for_resource(resource_type: String) -> int:
	if not RESOURCE_PRODUCER_SCRIPTS.has(resource_type):
		return 0
	if not is_instance_valid(village_scene_instance):
		return 0
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return 0
	var target_script_path = RESOURCE_PRODUCER_SCRIPTS[resource_type]
	var assigned_workers_for_resource = 0
	
	for building in placed_buildings.get_children():
		if building.has_method("get_script") and building.get_script() != null:
			var building_script = building.get_script()
			if building_script is GDScript and building_script.resource_path == target_script_path:
				# Bu binadaki atanan işçi sayısını al (aktif durum fark etmez)
				if "assigned_workers" in building:
					assigned_workers_for_resource += int(building.assigned_workers)
	
	return assigned_workers_for_resource

# Belirli bir kaynak seviyesinin ne kadarının kullanılabilir (kilitli olmayan) olduğunu döndürür
func get_available_resource_level(resource_type: String) -> int:
	var total_level = get_resource_level(resource_type)
	var locked_level = locked_resource_levels.get(resource_type, 0)
	# #print("DEBUG VillageManager: get_available_resource_level(%s): Total=%d, Locked=%d, Available=%d" % [resource_type, total_level, locked_level, max(0, total_level - locked_level)]) #<<< DEBUG
	return max(0, total_level - locked_level)

# Her frame'de temel kaynakları zamanla biriktirir
func _process(delta: float) -> void:
	# Economy açıkken per-frame üretim opsiyonel
	if economy_enabled and not per_frame_production_enabled:
		# Sadece günlük tick fallback çalışsın
		pass
	else:
		# Eski per-frame üretim (economy kapalıyken)
		var scaled_delta: float = delta * Engine.time_scale
		if not TimeManager.is_work_time():
			# En yakın NPC'nin ismini göster (work time olmasa bile)
			_update_nearest_npc_name_visibility()
			return
		var produced_any: bool = false
		for resource_type in BASE_RESOURCE_TYPES:
			var active_workers: int = _count_active_workers_for_resource(resource_type)
			if active_workers <= 0:
				continue
			var morale_mult: float = _get_morale_multiplier()
			# Seviyeye bağlı bina bonusu ve küresel çarpanları per-frame üretime de uygula
			var prod_mult: float = (1.0 + building_bonus + caregiver_bonus) * global_multiplier
			var res_mult: float = float(resource_prod_multiplier.get(resource_type, 1.0))
			var progress_increment: float = scaled_delta * float(active_workers) * morale_mult * prod_mult * res_mult
			base_production_progress[resource_type] = base_production_progress.get(resource_type, 0.0) + progress_increment
			if base_production_progress[resource_type] >= SECONDS_PER_RESOURCE_UNIT:
				var units: int = int(floor(base_production_progress[resource_type] / SECONDS_PER_RESOURCE_UNIT))
				if units > 0:
					# Storage cap clamp
					var cap: int = _get_storage_capacity_for(resource_type)
					if cap > 0:
						var cur: int = int(resource_levels.get(resource_type, 0))
						var allowed: int = max(0, cap - cur)
						units = min(units, allowed)
					if units > 0:
						# Debug: Eğer çarpan 1.0'dan farklıysa logla
						if res_mult != 1.0:
							# Üretim hızını hesapla (birim/saniye)
							var progress_per_second = (scaled_delta * float(active_workers) * morale_mult * prod_mult * res_mult) / scaled_delta
							var seconds_per_unit = SECONDS_PER_RESOURCE_UNIT / progress_per_second if progress_per_second > 0 else 0.0
							var normal_progress_per_second = float(active_workers) * morale_mult * prod_mult * 1.0
							var normal_seconds_per_unit = SECONDS_PER_RESOURCE_UNIT / normal_progress_per_second if normal_progress_per_second > 0 else 0.0
							var speed_reduction_pct = (1.0 - res_mult) * 100.0
							print("[PRODUCTION DEBUG] %s: %d birim üretildi | Çarpan: %.2f (%+.0f%% hız değişimi) | Normal: %.1fs/birim → Şu an: %.1fs/birim (%.1fx daha yavaş)" % [resource_type, units, res_mult, -speed_reduction_pct, normal_seconds_per_unit, seconds_per_unit, 1.0 / res_mult])
						resource_levels[resource_type] = resource_levels.get(resource_type, 0) + units
						# Daily counter (for stats consistency)
						_daily_production_counter[resource_type] = int(_daily_production_counter.get(resource_type, 0)) + units
					base_production_progress[resource_type] -= float(units) * SECONDS_PER_RESOURCE_UNIT
					produced_any = true
		if produced_any:
			emit_signal("village_data_changed")

	# Economy daily polling fallback (in case signal missed)
	if economy_enabled:
		var tm = get_node_or_null("/root/TimeManager")
		if tm and tm.has_method("get_day"):
			var d = tm.get_day()
			if d != _last_econ_tick_day and d > 0:
				_last_econ_tick_day = d
				_daily_economy_tick(d)
	
	# En yakın NPC'nin ismini göster, diğerlerini gizle
	_update_nearest_npc_name_visibility()

# --- Seviye Kilitleme (Yükseltmeler ve Gelişmiş Üretim için) ---

# Belirli bir kaynak seviyesini kilitlemeye çalışır
func lock_resource_level(resource_type: String, level_to_lock: int) -> bool:
	if get_available_resource_level(resource_type) >= level_to_lock:
		locked_resource_levels[resource_type] = locked_resource_levels.get(resource_type, 0) + level_to_lock
		#print("VillageManager: Kilitlendi - %s Seviye: %d (Toplam Kilitli: %d)" % [resource_type, level_to_lock, locked_resource_levels[resource_type]]) #<<< GÜNCELLENDİ
		emit_signal("village_data_changed") # UI güncellensin
		return true
	else:
		#print("VillageManager: Kilitlenemedi - Yetersiz Kullanılabilir %s Seviyesi (İstenen: %d, Mevcut Kullanılabilir: %d)" % [resource_type, level_to_lock, get_available_resource_level(resource_type)]) #<<< GÜNCELLENDİ
		return false

# Kilitli kaynak seviyesini serbest bırakır
func unlock_resource_level(resource_type: String, level_to_unlock: int) -> void:
	var current_lock = locked_resource_levels.get(resource_type, 0)
	if current_lock >= level_to_unlock:
		locked_resource_levels[resource_type] = current_lock - level_to_unlock
		#print("VillageManager: Kilit Açıldı - %s Seviye: %d (Kalan Kilitli: %d)" % [resource_type, level_to_unlock, locked_resource_levels[resource_type]]) #<<< GÜNCELLENDİ
	else:
		#printerr("VillageManager Warning: Kilit açma hatası! %s için %d açılmaya çalışıldı ama sadece %d kilitliydi. Kilit sıfırlanıyor." % [resource_type, level_to_unlock, current_lock]) #<<< GÜNCELLENDİ
		locked_resource_levels[resource_type] = 0 # Hata durumunda sıfırla
	emit_signal("village_data_changed") # UI güncellensin

# --- İnşa Yönetimi (Düzeltilmiş) ---

# --- Bina Yönetimi ---
# Belirtilen sahne yoluna sahip bir binanın zaten var olup olmadığını kontrol eder
func does_building_exist(building_scene_path: String) -> bool:
	if not village_scene_instance:
		#printerr("VillageManager: does_building_exist - VillageScene referansı yok!")
		return false # Hata durumu, var kabul etmeyelim?

	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		#printerr("VillageManager: does_building_exist - PlacedBuildings bulunamadı!")
		return false

	for building in placed_buildings.get_children():
		# scene_file_path kullanarak kontrol et
		if building.scene_file_path == building_scene_path:
			return true # Bu türden bina zaten var

	return false # Bu türden bina bulunamadı

# Bina gereksinimlerini döndürür
func get_building_requirements(building_scene_path: String) -> Dictionary:
	return BUILDING_REQUIREMENTS.get(building_scene_path, {})

# Bina gereksinimlerinin karşılanıp karşılanmadığını kontrol eder (Altın, Kaynak ve Seviye)
func can_meet_requirements(building_scene_path: String) -> bool:
	var requirements = get_building_requirements(building_scene_path)
	if requirements.is_empty():
		return false

	# 1. Altın Maliyetini Kontrol Et
	var cost = requirements.get("cost", {})
	var gold_cost = cost.get("gold", 0)
	if GlobalPlayerData.gold < gold_cost:
		return false

	# 2. Kaynak Maliyetlerini Kontrol Et
	for resource_type in cost:
		if resource_type == "gold":
			continue
		
		var required_amount = cost.get(resource_type, 0)
		if required_amount > 0:
			var available_amount = resource_levels.get(resource_type, 0)
			if available_amount < required_amount:
				return false

	# 3. Gerekli Kaynak Seviyelerini Kontrol Et
	var required_levels = requirements.get("requires_level", {})
	for resource_type in required_levels:
		var required_level = required_levels[resource_type]
		var available_level = get_available_resource_level(resource_type)
		if available_level < required_level:
			return false

	return true

# Boş bir inşa alanı bulur ve pozisyonunu döndürür, yoksa INF döner
func find_free_building_plot() -> Vector2:
	if not village_scene_instance:
		push_warning("[VillageManager] find_free_building_plot - VillageScene referansı yok!")
		return Vector2.INF

	var plot_markers = village_scene_instance.get_node_or_null("PlotMarkers")
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")

	if not plot_markers or not placed_buildings:
		push_warning("[VillageManager] find_free_building_plot - PlotMarkers veya PlacedBuildings bulunamadı!")
		return Vector2.INF

	# Her plot marker'ını kontrol et
	for marker in plot_markers.get_children():
		if not marker is Marker2D: continue

		var marker_pos = marker.global_position
		var plot_occupied = false

		# Bu pozisyonda zaten bina var mı diye kontrol et
		for building in placed_buildings.get_children():
			if building is Node2D and building.global_position.distance_to(marker_pos) < 1.0:
				plot_occupied = true
				break

		if not plot_occupied:
			return marker_pos

	# Fallback: Mevcut yerleşik binaların yanına ofsetle yerleştir
	if placed_buildings:
		var count:int = placed_buildings.get_child_count()
		var base_pos: Vector2 = Vector2.ZERO
		if plot_markers and plot_markers.get_child_count() > 0 and plot_markers.get_child(0) is Node2D:
			base_pos = plot_markers.get_child(0).global_position
		var fallback_pos = base_pos + Vector2(56 * count, 0)
		return fallback_pos
	return Vector2.ZERO

# Verilen bina sahnesini belirtilen pozisyona yerleştirir
func place_building(building_scene_path: String, position: Vector2) -> bool:
	if not village_scene_instance:
		push_warning("[VillageManager] place_building - VillageScene referansı yok!")
		return false

	var placed_buildings_node_ref = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings_node_ref:
		push_warning("[VillageManager] place_building - PlacedBuildings node bulunamadı!")
		return false

	var building_scene = load(building_scene_path)
	if not building_scene:
		push_error("[VillageManager] Bina sahnesi yüklenemedi: %s" % building_scene_path)
		return false

	var new_building = building_scene.instantiate()
	placed_buildings_node_ref.add_child(new_building)
	new_building.global_position = position
	emit_signal("village_data_changed")
	return true

# İnşa isteğini işler (Düzeltilmiş - Her türden sadece 1 bina)
func request_build_building(building_scene_path: String) -> bool:
	print("[VillageManager] 🏗️ İnşa isteği: %s" % building_scene_path.get_file())
	
	# 0. Bu Türden Bina Zaten Var Mı Kontrol Et
	if does_building_exist(building_scene_path):
		print("[VillageManager] ❌ İnşa reddedildi - Bu türden bina zaten var")
		return false
	
	# 1. Gereksinimleri Kontrol Et
	if not can_meet_requirements(building_scene_path):
		print("[VillageManager] ❌ İnşa reddedildi - Gereksinimler karşılanmıyor")
		var reqs = get_building_requirements(building_scene_path)
		print("[VillageManager]    Gereksinimler: %s" % reqs)
		return false

	# 2. Boş Yer Bul
	var placement_position = find_free_building_plot()
	if placement_position == Vector2.INF or placement_position == Vector2.ZERO:
		print("[VillageManager] ❌ İnşa reddedildi - Boş yer bulunamadı (pos: %s)" % placement_position)
		return false

	print("[VillageManager] ✅ Yer bulundu: %s" % placement_position)

	# 3. Maliyetleri Düş (Altın ve Kaynaklar)
	var requirements = get_building_requirements(building_scene_path)
	var cost = requirements.get("cost", {})
	
	# Altın maliyetini düş
	var gold_cost = cost.get("gold", 0)
	if gold_cost > 0:
		GlobalPlayerData.add_gold(-gold_cost)
		print("[VillageManager] 💰 Altın düşüldü: %d (Kalan: %d)" % [gold_cost, GlobalPlayerData.gold])
	
	# Kaynak maliyetlerini düş
	for resource_type in cost:
		if resource_type == "gold":
			continue
		
		var resource_cost = cost.get(resource_type, 0)
		if resource_cost > 0:
			var current_amount = resource_levels.get(resource_type, 0)
			resource_levels[resource_type] = current_amount - resource_cost
			print("[VillageManager] 📦 %s düşüldü: %d (Kalan: %d)" % [resource_type, resource_cost, resource_levels[resource_type]])
			emit_signal("village_data_changed")

	# 4. Binayı Yerleştir
	if place_building(building_scene_path, placement_position):
		print("[VillageManager] ✅ Bina başarıyla inşa edildi: %s" % building_scene_path.get_file())
		return true
	else:
		# Yerleştirme başarısız olduysa altını iade et!
		if gold_cost > 0:
			GlobalPlayerData.add_gold(gold_cost)
			print("[VillageManager] 💰 Altın iade edildi: %d" % gold_cost)
		push_error("[VillageManager] ❌ Bina yerleştirme başarısız oldu!")
		return false

# --- Diğer Fonksiyonlar (Cariye, Görev vb.) ---

# --- YENİ Genel İşçi Fonksiyonları ---
# Kayıtlı bir işçi örneğini döndürür veya yoksa yenisini ekler (şimdilik sadece boşta olanları döndürür)
func register_generic_worker() -> Node: #<<< BU AYNI KALIYOR
	# Boşta işçi var mı diye active_workers'ı kontrol et
	for worker_id in all_workers:
		var worker = all_workers[worker_id]["instance"]
		if is_instance_valid(worker) and worker.assigned_job_type == "":
			# HASTA KONTROLÜ: Hasta işçiler atanamaz
			if "is_sick" in worker and worker.is_sick:
				print("VillageManager: Worker %d hasta, atanamaz!" % worker_id)
				continue
			
			print("VillageManager: Found idle worker (ID: %d), registering." % worker_id) # Debug
			idle_workers = max(0, idle_workers - 1) # Boşta işçi sayısını azalt (negatif olmasın)

			emit_signal("village_data_changed")
			return worker # Boşta olanı döndür
		else:
			print("VillageManager: Worker %d not available - Job: '%s', Valid: %s" % [
				worker_id, worker.assigned_job_type if is_instance_valid(worker) else "INVALID", is_instance_valid(worker)
			])

	# Boşta işçi bulunamadıysa hata ver (veya otomatik yeni işçi ekle?)
	#printerr("VillageManager: register_generic_worker - Uygun boşta işçi bulunamadı!")
	return null

# Bir işçiyi tekrar boşta duruma getirir (generic)
func unregister_generic_worker(worker_id: int):
	print("=== UNREGISTER GENERIC WORKER DEBUG ===")
	print("Worker ID: %d" % worker_id)
	
	if all_workers.has(worker_id):
		var worker_data = all_workers[worker_id]
		var worker_instance = worker_data["instance"]
		if not is_instance_valid(worker_instance):
			#printerr("unregister_generic_worker: Worker instance for ID %d is invalid!" % worker_id)
			return


		# --- DETAYLI DEBUG ---
		print("🔍 Worker %d durumu:" % worker_id)
		print("  - assigned_job_type: '%s'" % worker_instance.assigned_job_type)
		print("  - assigned_building_node: %s" % worker_instance.assigned_building_node)
		print("  - assigned_building_node valid: %s" % is_instance_valid(worker_instance.assigned_building_node))
		print("  - Mevcut idle_workers: %d" % idle_workers)
		
		# İşçi gerçekten bir binada çalışıyor muydu? (assigned_job_type değil, assigned_building_node kontrol et)
		var needs_to_become_idle = is_instance_valid(worker_instance.assigned_building_node)
		print("  - needs_to_become_idle: %s" % needs_to_become_idle)

		# -------------------------------------------

		# Binadan çıkar (Bu kısım büyük ölçüde formalite, asıl iş bina scriptinde yapıldı)
		var current_building = worker_instance.assigned_building_node
		if is_instance_valid(current_building):
			print("  - Bina mevcut, bağlantı kesiliyor...")
			# worker_instance.assigned_building = null # Bina scripti zaten yapıyor ama garanti olsun
			# Bina scriptinin remove_worker'ını tekrar çağırmaya gerek yok.
			pass
		else:
			print("  - Bina zaten null veya geçersiz")
		# Hata durumunda bile worker instance'ın bina bağlantısını keselim:
		worker_instance.assigned_building_node = null 
		

		# --- Idle Sayısını Artır (sadece çalışan işçi için) ---
		if needs_to_become_idle:
			idle_workers += 1
			print("✅ Worker %d unregistered. Idle count: %d -> %d" % [worker_id, idle_workers - 1, idle_workers])
		else:
			print("❌ Worker %d was already idle, not incrementing idle count." % worker_id)
		
		print("=== UNREGISTER GENERIC WORKER DEBUG BİTTİ ===")

		# Eğer işçi bir barınakta kalıyorsa, barınağın doluluk sayısını azalt
		var current_housing = worker_instance.housing_node
		if is_instance_valid(current_housing):
			if current_housing.has_method("remove_occupant"):
				# CampFire ve House için worker instance'ı geç (her ikisi de kabul ediyor)
				if current_housing.get_script() and current_housing.get_script().resource_path.ends_with("CampFire.gd"):
					# CampFire için worker instance'ı geç
					current_housing.remove_occupant(worker_instance)
				else:
					# House için de worker instance'ı geç (artık kabul ediyor)
					current_housing.remove_occupant(worker_instance)
				
				# remove_occupant artık her zaman true döner (worker listede yoksa bile normal)
				# if not success:
				# 	printerr("VillageManager: Failed to remove occupant from %s for worker %d." % [current_housing.name, worker_id])
			else:
				printerr("VillageManager: Housing node %s does not have remove_occupant method!" % current_housing.name)


		# WorkerAssignmentUI'yi güncellemek için sinyal gönder (varsa)
		emit_signal("worker_list_changed")
	#else:
		#printerr("unregister_generic_worker: Worker data not found for ID: %d" % worker_id)

# --- YENİ İleri Seviye Üretim Yönetimi (Dictionary Tabanlı) --- #<<< BAŞLIK GÜNCELLENDİ

# Gelişmiş bir ürünün üretimini kaydeder (gerekli kaynakları kilitler)
# produced_resource: Üretilen kaynağın adı (örn: "bread")
# required_resources: Gerekli kaynaklar ve miktarları içeren dictionary (örn: {"food": 1, "water": 1})
func register_advanced_production(produced_resource: String, required_resources: Dictionary) -> bool:
	#print("DEBUG VillageManager: register_advanced_production (dict) çağrıldı. Üretilen: %s, Gereken: %s" % [produced_resource, required_resources]) #<<< YENİ DEBUG
	var successfully_locked: Dictionary = {} # Başarıyla kilitlenenleri takip et (rollback için)

	# 1. Adım: Gerekli tüm kaynakları kilitlemeye çalış
	for resource_name in required_resources:
		var amount_needed = required_resources[resource_name]
		if lock_resource_level(resource_name, amount_needed):
			successfully_locked[resource_name] = amount_needed
		else:
			# Kilitleme başarısız oldu!
			#printerr("VillageManager Error: Gelişmiş üretim için %s kilitleme başarısız! Üretim iptal ediliyor." % resource_name)
			# Rollback: Başarıyla kilitlenenleri geri aç
			for locked_resource in successfully_locked:
				unlock_resource_level(locked_resource, successfully_locked[locked_resource])
			return false # Başarısız

	# 2. Adım: Tüm kaynaklar başarıyla kilitlendi, üretilen kaynağın seviyesini artır
	resource_levels[produced_resource] = resource_levels.get(produced_resource, 0) + 1
	#print("VillageManager: Gelişmiş üretim kaydedildi: +1 %s. Toplam %s: %d" % [produced_resource, produced_resource, resource_levels[produced_resource]]) #<<< YENİ
	emit_signal("village_data_changed") # UI güncellensin
	# Gerekirse üretilen kaynak için de bir sinyal yayılabilir:
	# emit_signal("resource_produced", produced_resource, 1) 
	return true # Başarılı

# Gelişmiş bir ürünün üretim kaydını kaldırır (kilitli kaynakları serbest bırakır)
# produced_resource: Üretimi durdurulan kaynağın adı (örn: "bread")
# required_resources: Serbest bırakılacak kaynaklar ve miktarları (örn: {"food": 1, "water": 1})
func unregister_advanced_production(produced_resource: String, required_resources: Dictionary) -> void:
	#print("DEBUG VillageManager: unregister_advanced_production (dict) çağrıldı. Durdurulan: %s, Serbest Bırakılan: %s" % [produced_resource, required_resources]) #<<< YENİ DEBUG
	
	# 1. Adım: Üretilen kaynağın seviyesini azalt
	var current_level = resource_levels.get(produced_resource, 0)
	if current_level > 0:
		resource_levels[produced_resource] = current_level - 1
		#print("VillageManager: Gelişmiş üretim kaydı kaldırıldı: -1 %s. Kalan %s: %d" % [produced_resource, produced_resource, resource_levels[produced_resource]]) #<<< YENİ
	#else:
		#printerr("VillageManager Warning: %s üretim kaydı kaldırılmaya çalışıldı ama seviye zaten 0." % produced_resource)

	# 2. Adım: Kilitli kaynakları serbest bırak
	for resource_name in required_resources:
		var amount_to_unlock = required_resources[resource_name]
		unlock_resource_level(resource_name, amount_to_unlock)

	emit_signal("village_data_changed") # UI güncellensin

# --- ESKİ 3 PARAMETRELİ VERSİYONLAR (SİLİNECEK) --- 
# func register_advanced_production(produced_resource: String, consumed_resource: String, consume_amount: int) -> bool:
# 	...
# func unregister_advanced_production(produced_resource: String, consumed_resource: String, consume_amount: int) -> void:
# 	...
# ---------------------------------------------------

# --- Yeni Köylü Ekleme Fonksiyonu ---
func add_villager() -> void:
	# Barınak kontrolü yap - _add_new_worker() fonksiyonunu kullan
	if _add_new_worker():
		print("VillageManager: Yeni köylü eklendi. Toplam: %d, Boşta: %d" % [total_workers, idle_workers])
		emit_signal("village_data_changed") # UI güncellensin
	else:
		print("VillageManager: Yeni köylü eklenemedi - yeterli barınak yok!")


# Yeni bir cariye ekler (örn. zindandan kurtarıldığında)
func add_cariye(cariye_data: Dictionary) -> void:
	var id = next_cariye_id
	cariyeler[id] = cariye_data
	# Durumunu 'boşta' olarak ayarlayalım
	cariyeler[id]["durum"] = "boşta" 
	next_cariye_id += 1

	# Debug print disabled to reduce console spam
	# print("VillageManager: Yeni cariye eklendi: ", cariye_data.get("isim", "İsimsiz"), " (ID: ", id, ")")

	emit_signal("cariye_data_changed")

# Yeni bir görev tanımı ekler
func add_gorev(gorev_data: Dictionary) -> void:
	var id = next_gorev_id
	gorevler[id] = gorev_data
	next_gorev_id += 1

	# Debug print disabled to reduce console spam
	# print("VillageManager: Yeni görev eklendi: ", gorev_data.get("isim", "İsimsiz"), " (ID: ", id, ")")

	emit_signal("gorev_data_changed")

# Bir cariyeyi bir göreve atar
func assign_cariye_to_mission(cariye_id: int, gorev_id: int) -> bool:
	if not cariyeler.has(cariye_id) or not gorevler.has(gorev_id):
		#printerr("VillageManager: Geçersiz cariye veya görev ID!")
		return false
	if cariyeler[cariye_id]["durum"] != "boşta":
		#print("VillageManager: Cariye %d zaten meşgul (%s)" % [cariye_id, cariyeler[cariye_id]["durum"]])
		return false
	# !!! GÖREV KOŞULLARI KONTROLÜ (Gelecekte eklenecek) !!!
	# Örneğin: Asker sayısı, yetenek vb. kontrolü burada yapılmalı.
	# if not _check_mission_requirements(cariye_id, gorev_id): return false
		
	var gorev = gorevler[gorev_id]
	var cariye = cariyeler[cariye_id]
	var sure = gorev.get("sure", 10.0) # Varsayılan süre 10sn

	#print("VillageManager: Cariye %d (%s), Görev %d (%s)'e atanıyor (Süre: %.1fs)" % [cariye_id, cariye.get("isim", ""), gorev_id, gorev.get("isim", ""), sure])

	# Cariye durumunu güncelle
	cariye["durum"] = "görevde"
	
	# Görev için bir zamanlayıcı oluştur
	var mission_timer = Timer.new()
	mission_timer.name = "MissionTimer_%d_%d" % [cariye_id, gorev_id] # Benzersiz isim
	mission_timer.one_shot = true
	mission_timer.wait_time = sure
	# Zamanlayıcı bittiğinde çalışacak fonksiyona hem cariye hem görev ID'sini bağla
	mission_timer.timeout.connect(_on_mission_timer_timeout.bind(cariye_id, gorev_id)) 
	add_child(mission_timer) # VillageManager'a ekle (Autoload olduğu için sahnede kalır)
	mission_timer.start()

	# Aktif görevi kaydet
	active_missions[cariye_id] = {"gorev_id": gorev_id, "timer": mission_timer}

	emit_signal("cariye_data_changed") # Cariye durumu değişti
	emit_signal("gorev_data_changed") # Görev durumu (aktifleşti) değişti (UI için)
	return true

# Görev zamanlayıcısı bittiğinde çağrılır
func _on_mission_timer_timeout(cariye_id: int, gorev_id: int) -> void:
	if not active_missions.has(cariye_id) or active_missions[cariye_id]["gorev_id"] != gorev_id:
		#printerr("VillageManager: Görev tamamlandı ama aktif görevlerde bulunamadı veya ID eşleşmedi!")
		return # Beklenmedik durum

	var cariye = cariyeler[cariye_id]
	var gorev = gorevler[gorev_id]
	var timer = active_missions[cariye_id]["timer"]

	#print("VillageManager: Görev %d (%s) tamamlandı (Cariye: %d)" % [gorev_id, gorev.get("isim", ""), cariye_id])

	# --- BAŞARI/BAŞARISIZLIK HESAPLAMA (Basit Örnek) ---
	# TODO: Daha karmaşık hesaplama (zorluk, cariye yeteneği vb. kullan)
	var success_chance = gorev.get("basari_sansi", 0.7) # Varsayılan %70 başarı şansı
	var successful = randf() < success_chance # Rastgele sayı < başarı şansı ise başarılı
	# --------------------------------------------------
	
	var cariye_injured = false # Cariye yaralandı mı flag'i
	var oduller = {} # Ödüller dictionary'si
	var cezalar = {} # Cezalar dictionary'si

	if successful:

		print("  -> Görev Başarılı!")
		oduller = gorev.get("odul", {})
		print("     Ödüller: ", oduller)

		# --- ÖDÜLLERİ UYGULA (GlobalPlayerData kullanarak) ---
		if oduller.has("altin"):
			GlobalPlayerData.add_gold(oduller["altin"])
		if oduller.has("iliski_komsu"):
			GlobalPlayerData.update_relationship("komsu_koy", oduller["iliski_komsu"])
		# Başka ilişki türleri de eklenebilir...
		if oduller.has("bulunan_esya"):
			GlobalPlayerData.add_item_to_inventory(oduller["bulunan_esya"])
		# TODO: Diğer ödül türleri (kaynak seviyesi artışı vb.) eklenebilir
		# ---------------------------------------------------
	else:
		print("  -> Görev Başarısız!")
		cezalar = gorev.get("ceza", {})
		print("     Cezalar: ", cezalar)

		# --- CEZALARI UYGULA (GlobalPlayerData kullanarak) ---
		if cezalar.has("asker_kaybi"):
			GlobalPlayerData.change_asker_sayisi(-cezalar["asker_kaybi"])
		if cezalar.has("cariye_yaralanma_ihtimali"):
			if randf() < cezalar["cariye_yaralanma_ihtimali"]:
				cariye_injured = true
				cariye["durum"] = "yaralı"
				#print("     UYARI: Cariye %d (%s) görev sırasında yaralandı!" % [cariye_id, cariye.get("isim", "")])
				# TODO: Yaralı cariye için bir iyileşme süreci başlatılabilir
		# TODO: Diğer ceza türleri eklenebilir
		# -------------------------------------------------

	# --- ETKİLERİ UYGULA (Başarı/Başarısızlıktan bağımsız olabilir) ---
	var etkiler = gorev.get("etki", {})
	#if not etkiler.is_empty(): # Sadece etki varsa yazdır
		#print("     Etkiler: ", etkiler)
	# TODO: Etkileri uygula (ilişki değişimi vb.)
	# -----------------------------------------------------------------

	# Cariye durumunu güncelle (eğer yaralanmadıysa)
	if not cariye_injured:
		cariye["durum"] = "boşta"
	
	# Aktif görevi temizle
	active_missions.erase(cariye_id)
	timer.queue_free() # Zamanlayıcıyı sil

	# Görev sonuçlarını hazırla
	var results = {
		"cariye_name": cariye.get("isim", "İsimsiz"),
		"mission_name": gorev.get("isim", "İsimsiz"),
		"successful": successful,
		"rewards": oduller if successful else {},
		"penalties": cezalar if not successful else {},
		"cariye_injured": cariye_injured
	}
	
	emit_signal("mission_completed", cariye_id, gorev_id, successful, results)
	emit_signal("cariye_data_changed")
	emit_signal("gorev_data_changed") 

# --- DEBUG Fonksiyonları ---
func _create_debug_cariyeler() -> void:
	add_cariye({"isim": "Ayşe", "yetenekler": ["Diplomasi", "Ticaret"]})
	add_cariye({"isim": "Fatma", "yetenekler": ["Liderlik", "Savaş"]})
	add_cariye({"isim": "Zeynep", "yetenekler": ["Gizlilik", "Keşif"]})

func _create_debug_gorevler() -> void:
	add_gorev({
		"isim": "Komşu Köy ile Ticaret Anlaşması",
		"tur": "TICARET",
		"sure": 15.0,
		"basari_sansi": 0.8,
		"gereken_cariye_yetenek": "Ticaret",
		"odul": {"iliski_komsu": 5, "altin": 50}
	})
	add_gorev({
		"isim": "Yakındaki Harabeleri Keşfet",
		"tur": "KESIF",
		"sure": 20.0,
		"basari_sansi": 0.6,
		"gereken_cariye_yetenek": "Keşif",
		"odul": {"bulunan_esya": "Eski Harita", "altin": 20},
		"ceza": {"cariye_yaralanma_ihtimali": 0.2}
	})
	add_gorev({
		"isim": "Haydut Kampına Baskın",
		"tur": "YAGMA",
		"sure": 30.0,
		"basari_sansi": 0.5,
		"gereken_cariye_yetenek": "Liderlik",
		"gereken_asker": 3, # Henüz uygulanmıyor
		"odul": {"altin": 150, "odun_seviyesi_artis": 1},
		"ceza": {"asker_kaybi": 1, "cariye_yaralanma_ihtimali": 0.4}
	})

# Bir binanın durumu değiştiğinde UI'yi bilgilendirir
func notify_building_state_changed(building_node: Node) -> void:
	# #print("VillageManager: notify_building_state_changed called by: ", building_node.name) # DEBUG <<< KALDIRILDI
	emit_signal("building_state_changed", building_node)
	# İsteğe bağlı: Genel UI güncellemesi için bunu da tetikleyebiliriz?
	emit_signal("village_data_changed")
	# Bina seviyeleri/varlığı değiştiyse günlük üretim bonusunu güncelle
	_recalculate_building_bonus()

# === Economy: daily tick handlers and helpers (feature-flagged) ===
func _on_day_changed(new_day: int) -> void:
	if not economy_enabled:
		return
	_last_econ_tick_day = new_day
	# Gün başında bina bonusunu tazele (yükseltmeler etkilesin)
	_recalculate_building_bonus()
	_daily_economy_tick(new_day)
	
	# Check for village-specific events (normal gameplay)
	if village_events_enabled and new_day != _last_village_event_check_day:
		_last_village_event_check_day = new_day
		_check_and_trigger_village_event(new_day)

func _daily_economy_tick(current_day: int) -> void:
	# 1) Production
	var produced: Dictionary = {}
	var population := int(total_workers)
	if per_frame_production_enabled:
		# Use accumulated counters gathered during the day
		produced = _daily_production_counter.duplicate(true)
	else:
		var prod_per_worker := production_per_worker_base * (1.0 + building_bonus + caregiver_bonus) * global_multiplier
		var total_prod := float(population) * prod_per_worker * _get_morale_multiplier()
		produced = _allocate_production(total_prod)
		for r in produced.keys():
			var mult := float(resource_prod_multiplier.get(r, 1.0))
			var to_add := int(floor(produced[r] * mult))
			produced[r] = to_add
			# Apply to stocks with cap
			if to_add > 0:
				var cap: int = _get_storage_capacity_for(r)
				if cap > 0:
					var cur: int = int(resource_levels.get(r, 0))
					var new_total: int = min(cap, cur + to_add)
					resource_levels[r] = new_total
				else:
					resource_levels[r] = resource_levels.get(r, 0) + to_add

	# 2) Consumption
	var village_need := float(population) * (daily_water_per_pop + daily_food_per_pop)
	
	# Soldiers: add extra daily need per soldier (bread/water) on top of base village consumption
	var soldier_count := _count_active_soldiers()
	if soldier_count > 0:
		var soldier_extra_food_per := 0.5
		var soldier_extra_water_per := 0.5
		var extra_need := float(soldier_count) * (soldier_extra_food_per + soldier_extra_water_per)
		_consume_for_soldiers(extra_need, soldier_extra_food_per, soldier_extra_water_per)

	var cariye_daily_equiv := _compute_cariye_daily_equiv()
	var total_need := village_need + cariye_daily_equiv
	_consume_for_village(village_need)
	_consume_for_cariyes(cariye_daily_equiv)

	# 3) Stats
	var produced_sum := 0.0
	for r2 in produced.keys():
		produced_sum += float(produced[r2])
	var net := produced_sum - total_need
	economy_stats_last_day = {"day": current_day, "total_production": produced_sum, "total_consumption": total_need, "net": net}

	# 4) Soft penalties (placeholder)
	_check_shortages_and_apply_morale_penalties()
	process_weekly_cariye_needs(current_day)

	# 5) Events update (scaffold)
	_update_events_for_new_day(current_day)

	emit_signal("village_data_changed")
	# Reset daily counters at end of day
	_daily_production_counter = {
		"wood": 0,
		"stone": 0,
		"food": 0,
		"water": 0,
		"lumber": 0,
		"brick": 0,
		"metal": 0,
		"cloth": 0,
		"garment": 0,
		"bread": 0,
		"tea": 0,
		"medicine": 0,
		"soap": 0
	}

func _get_storage_capacity_for(resource_type: String) -> int:
	# Basic resources get capacity from number of corresponding buildings * STORAGE_PER_BASIC_BUILDING.
	# Advanced resources currently uncapped (return 0).
	match resource_type:
		"wood", "stone", "food", "water":
			var base_cap := _count_buildings_for_resource(resource_type) * STORAGE_PER_BASIC_BUILDING
			var extra_cap := _count_storage_buildings_capacity(resource_type)
			return base_cap + extra_cap
		_:
			return 0

func _count_storage_buildings_capacity(resource_type: String) -> int:
	# Sum capacity bonuses from any Storage buildings (generic or per-resource). Placeholder values.
	if not is_instance_valid(village_scene_instance):
		return 0
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return 0
	var bonus: int = 0
	for building in placed_buildings.get_children():
		# Generic storage building could expose a method or property
		if "provides_storage" in building and building.provides_storage == true:
			# If building has a dictionary of caps per resource, use it; else use a flat bonus
			if "storage_bonus" in building and building.storage_bonus is Dictionary:
				bonus += int(building.storage_bonus.get(resource_type, 0))
			elif "storage_bonus_all" in building:
				bonus += int(building.storage_bonus_all)
		# Alternatively, check by script/scene path if needed in the future
	return bonus

func _count_buildings_for_resource(resource_type: String) -> int:
	if not RESOURCE_PRODUCER_SCRIPTS.has(resource_type):
		return 0
	if not is_instance_valid(village_scene_instance):
		return 0
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return 0
	var target_script_path = String(RESOURCE_PRODUCER_SCRIPTS[resource_type])
	var target_scene_path = String(RESOURCE_PRODUCER_SCENES.get(resource_type, ""))
	var count: int = 0
	for building in placed_buildings.get_children():
		# Prefer scene path match if available
		if target_scene_path != "" and "scene_file_path" in building and building.scene_file_path == target_scene_path:
			count += 1
		else:
			if building.has_method("get_script") and building.get_script() != null:
				var building_script = building.get_script()
				if building_script is GDScript and building_script.resource_path == target_script_path:
					count += 1
	return count

func _allocate_production(total_prod: float) -> Dictionary:
	# Actual allocation by worker assignments across basic resources
	if total_prod <= 0.0:
		return {}
	var basic := ["wood", "stone", "food", "water"]
	var assigned: Dictionary = {}
	var total_assigned := 0
	for r in basic:
		var cnt := _count_active_workers_for_resource(r)
		assigned[r] = cnt
		total_assigned += cnt
	var out: Dictionary = {}
	if total_assigned <= 0:
		# Fallback to equal split if no explicit assignments
		var share := total_prod / float(basic.size())
		for r in basic:
			out[r] = share
		return out
	for r in basic:
		var ratio := float(assigned[r]) / float(max(1, total_assigned))
		out[r] = total_prod * ratio
	return out

func _compute_cariye_daily_equiv() -> float:
	# Cariyelerin günlük su/yiyecek tüketimi yok; ihtiyaçlar haftalık ve lüks (ekmek, çay, sabun, giyim).
	# Haftalık periyotlu ihtiyaçlar günlük eşdeğere çevrilebilir, fakat stok düşümü haftanın belirli gününde yapılır.
	return 0.0

# === DÜNYA OLAYLARI EKONOMİ ETKİLERİ ===
func apply_world_event_effects(event: Dictionary) -> void:
	"""Apply world event effects to village economy"""
	if not events_enabled:
		return
	
	var event_type := String(event.get("type", ""))
	var effects: Dictionary = event.get("effects", {})
	var magnitude := float(event.get("magnitude", 1.0))
	
	match event_type:
		"trade_boom":
			# Ticaret patlaması - altın çarpanı artışı
			var gold_mult := float(effects.get("gold_multiplier", 1.0))
			global_multiplier *= gold_mult
			var trade_bonus := int(effects.get("trade_bonus", 0))
			# Trade bonus'u MissionManager'a iletebiliriz
			_post_event_notification("Ticaret patlaması! Altın kazançları artıyor.", "success")
			
		"famine":
			# Kıtlık - gıda üretimi düşüşü
			var food_mult := float(effects.get("food_production", 1.0))
			resource_prod_multiplier["food"] *= food_mult
			var morale_penalty := int(effects.get("morale_penalty", 0))
			village_morale = max(0.0, village_morale + morale_penalty)
			_post_event_notification("Kıtlık başladı! Gıda üretimi düştü.", "critical")
			
		"plague":
			# Salgın - nüfus sağlığı ve üretim düşüşü
			var health_mult := float(effects.get("population_health", 1.0))
			var prod_penalty := float(effects.get("production_penalty", 1.0))
			global_multiplier *= prod_penalty
			# Sağlık etkisi için moral düşüşü
			village_morale = max(0.0, village_morale - 20.0)
			_post_event_notification("Salgın hastalık! Üretim ve moral düştü.", "critical")
			
		"war_declaration":
			# Savaş ilanı - ticaret kesintisi, askeri odaklanma
			var trade_disruption := float(effects.get("trade_disruption", 1.0))
			var military_focus := float(effects.get("military_focus", 1.0))
			global_multiplier *= trade_disruption
			# Askeri odaklanma için weapon/armor üretimi artışı
			if resource_prod_multiplier.has("metal"):
				resource_prod_multiplier["metal"] *= military_focus
			_post_event_notification("Savaş ilanı! Ticaret kesintiye uğradı.", "warning")
			
		"rebellion":
			# İsyan - istikrar ve üretim kaosu
			var stability_penalty := int(effects.get("stability_penalty", 0))
			var production_chaos := float(effects.get("production_chaos", 1.0))
			village_morale = max(0.0, village_morale + stability_penalty)
			global_multiplier *= production_chaos
			_post_event_notification("İsyan çıktı! Üretim kaosu ve moral düşüşü.", "critical")

func remove_world_event_effects(event: Dictionary) -> void:
	"""Remove world event effects when event expires"""
	if not events_enabled:
		return
	
	var event_type := String(event.get("type", ""))
	var effects: Dictionary = event.get("effects", {})
	
	match event_type:
		"trade_boom":
			var gold_mult := float(effects.get("gold_multiplier", 1.0))
			global_multiplier /= gold_mult
			_post_event_notification("Ticaret patlaması sona erdi.", "info")
			
		"famine":
			var food_mult := float(effects.get("food_production", 1.0))
			resource_prod_multiplier["food"] /= food_mult
			var morale_penalty := int(effects.get("morale_penalty", 0))
			village_morale = min(100.0, village_morale - morale_penalty)
			_post_event_notification("Kıtlık sona erdi.", "success")
			
		"plague":
			var prod_penalty := float(effects.get("production_penalty", 1.0))
			global_multiplier /= prod_penalty
			village_morale = min(100.0, village_morale + 20.0)
			_post_event_notification("Salgın hastalık sona erdi.", "success")
			
		"war_declaration":
			var trade_disruption := float(effects.get("trade_disruption", 1.0))
			var military_focus := float(effects.get("military_focus", 1.0))
			global_multiplier /= trade_disruption
			if resource_prod_multiplier.has("metal"):
				resource_prod_multiplier["metal"] /= military_focus
			_post_event_notification("Savaş sona erdi.", "success")
			
		"rebellion":
			var stability_penalty := int(effects.get("stability_penalty", 0))
			var production_chaos := float(effects.get("production_chaos", 1.0))
			village_morale = min(100.0, village_morale - stability_penalty)
			global_multiplier /= production_chaos
			_post_event_notification("İsyan bastırıldı.", "success")

func _post_event_notification(message: String, category: String) -> void:
	"""Post event notification to news system"""
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("post_news"):
		mm.post_news("Köy", "Dünya Olayı", message, Color.WHITE, category)

# --- Soldiers extra consumption helpers ---
func _count_active_soldiers() -> int:
	if not is_instance_valid(village_scene_instance):
		return 0
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return 0
	var count := 0
	for building in placed_buildings.get_children():
		if building.has_method("get_military_force") and ("assigned_workers" in building):
			count += int(building.assigned_workers)
	return count

func _consume_for_soldiers(extra_need: float, per_food: float, per_water: float) -> void:
	# Split extra need into food/water portions and consume with shortage tracking
	var water_need: float = ceil(extra_need * 0.5)
	var food_need: float = ceil(extra_need * 0.5)
	var take_water: int = min(int(water_need), int(resource_levels.get("water", 0)))
	var take_food: int = min(int(food_need), int(resource_levels.get("food", 0)))
	resource_levels["water"] = int(resource_levels.get("water", 0)) - take_water
	resource_levels["food"] = int(resource_levels.get("food", 0)) - take_food
	_last_day_shortages["soldier_water"] = int(max(0, int(water_need) - take_water))
	_last_day_shortages["soldier_food"] = int(max(0, int(food_need) - take_food))

func _consume_for_village(village_need: float) -> void:
	# Öncelik: su ve yiyecekten ceil ile düş
	var need := village_need
	var water_need: float = ceil(need * 0.5)
	var food_need: float = ceil(need * 0.5)
	var take_water: int = min(int(water_need), int(resource_levels.get("water", 0)))
	var take_food: int = min(int(food_need), int(resource_levels.get("food", 0)))
	resource_levels["water"] = int(resource_levels.get("water", 0)) - take_water
	resource_levels["food"] = int(resource_levels.get("food", 0)) - take_food
	# Record shortages for morale penalties
	_last_day_shortages["water"] = int(max(0, int(water_need) - take_water))
	_last_day_shortages["food"] = int(max(0, int(food_need) - take_food))

	# Optional bonus consumption by population tiers to raise morale (soft luxury)
	var pop := int(total_workers)
	var bonus_morale := 0.0
	if pop >= 16 and pop <= 25:
		# Bread bonus: try to consume up to ceil(pop * 0.1)
		var want_bread: int = int(ceil(float(pop) * 0.1))
		var have_bread: int = int(resource_levels.get("bread", 0))
		var take_bread: int = min(want_bread, have_bread)
		if take_bread > 0:
			resource_levels["bread"] = have_bread - take_bread
			bonus_morale += float(take_bread)
	if pop >= 26 and pop <= 50:
		# Medicine bonus
		var want_med: int = int(ceil(float(pop) * 0.05))
		var have_food: int = int(resource_levels.get("food", 0))
		var have_water: int = int(resource_levels.get("water", 0))
		var pairs: int = min(want_med, min(have_food, have_water))
		if pairs > 0:
			resource_levels["food"] = have_food - pairs
			resource_levels["water"] = have_water - pairs
			bonus_morale += float(pairs)
	if pop >= 51:
		# Tea bonus
		var want_tea: int = int(ceil(float(pop) * 0.05))
		var have_food2: int = int(resource_levels.get("food", 0))
		var have_water2: int = int(resource_levels.get("water", 0))
		var tea_pairs: int = min(want_tea, min(have_food2, have_water2))
		if tea_pairs > 0:
			resource_levels["food"] = have_food2 - tea_pairs
			resource_levels["water"] = have_water2 - tea_pairs
			bonus_morale += float(tea_pairs)
	if bonus_morale > 0.0:
		village_morale = min(100.0, village_morale + min(5.0, bonus_morale))

func _consume_for_cariyes(cariye_daily_equiv: float) -> void:
	# Günlük tüketimde cariye harcaması yapılmaz; haftalık role-based tüketim ayrı bir akışta uygulanacak.
	return

func process_weekly_cariye_needs(current_day: int) -> void:
	# Every 7th day apply role-based needs (placeholder simple costs)
	if cariye_period_days <= 0:
		return
	if current_day % cariye_period_days != 0:
		return
	# Example simple needs (can be extended per-role):
	# Try to consume 1 bread and 1 tea equivalent per cariye weekly; if missing, apply small morale hit.
	var cariye_count := int(cariyeler.size())
	if cariye_count <= 0:
		return
	var missing_any := false
	var missing_bread: int = 0
	var missing_tea: int = 0
	var to_consume_bread := cariye_count
	var to_consume_tea := cariye_count
	var have_bread := int(resource_levels.get("bread", 0))
	var have_food := int(resource_levels.get("food", 0))
	var have_water := int(resource_levels.get("water", 0))
	# Bread preferred, fallback to food+water craft equivalence
	var take_bread: int = min(to_consume_bread, have_bread)
	resource_levels["bread"] = have_bread - take_bread
	to_consume_bread -= take_bread
	# Fallback: consume food+water pairs if bread missing
	if to_consume_bread > 0:
		var pairs: int = min(to_consume_bread, min(have_food, have_water))
		resource_levels["food"] = have_food - pairs
		resource_levels["water"] = have_water - pairs
		to_consume_bread -= pairs
		if to_consume_bread > 0:
			missing_any = true
			missing_bread = to_consume_bread
	# Tea equivalence: food+water per unit
	if to_consume_tea > 0:
		have_food = int(resource_levels.get("food", 0))
		have_water = int(resource_levels.get("water", 0))
		var tea_pairs: int = min(to_consume_tea, min(have_food, have_water))
		resource_levels["food"] = have_food - tea_pairs
		resource_levels["water"] = have_water - tea_pairs
		if tea_pairs < to_consume_tea:
			missing_any = true
			missing_tea = to_consume_tea - tea_pairs
	if missing_any:
		village_morale = max(0.0, village_morale - 2.0)
		var mm = get_node_or_null("/root/MissionManager")
		if mm and mm.has_method("post_news"):
			var msg := "Eksik haftalık cariye ihtiyaçları: "
			if missing_bread > 0:
				msg += "Ekmek %d " % missing_bread
			if missing_tea > 0:
				msg += "Çay %d" % missing_tea
			mm.post_news("village", "Cariye ihtiyaçları karşılanamadı", msg.strip_edges(), Color(1,0.6,0.2,1))

func _check_shortages_and_apply_morale_penalties() -> void:
	var penalty := 0.0
	for k in _last_day_shortages.keys():
		var missing := float(_last_day_shortages.get(k, 0))
		if missing > 0.0:
			penalty += 5.0 # -5 per missing type/day (simple)
	if penalty > 0.0:
		village_morale = max(0.0, village_morale - penalty)
	else:
		# Slow recovery
		village_morale = min(100.0, village_morale + 1.0)
	# Reset shortages for next day
	_last_day_shortages = {"water": 0, "food": 0}

func _get_morale_multiplier() -> float:
	# Above 50, no penalty; below 50, linear down to 0.5 at morale 0
	if village_morale >= 50.0:
		return 1.0
	var deficit := 50.0 - village_morale
	return max(0.5, 1.0 - deficit * 0.01)

func _update_events_for_new_day(current_day: int) -> void:
	if not events_enabled:
		return
	# Expire old events
	var remaining: Array[Dictionary] = []
	for ev in events_active:
		var ends_day := int(ev.get("ends_day", current_day))
		if current_day <= ends_day:
			remaining.append(ev)
		else:
			_remove_event_effects(ev)
	events_active = remaining

	# Hastalık kontrolü: Her gün hasta işçileri kontrol et
	_check_and_heal_sick_workers(current_day)

	# Maybe trigger new event
	if randf() < daily_event_chance:
		var ev = _pick_and_create_event(current_day)
		if not ev.is_empty():
			events_active.append(ev)
			_apply_event_effects(ev)

# === World Event Effects Integration ===
# (Duplicate functions removed - using the ones defined earlier)

func _pick_and_create_event(current_day: int) -> Dictionary:
	# cooldown check and simple pool
	var pool := ["drought", "famine", "pest", "disease", "raid", "wolf_attack", "severe_storm", "weather_blessing", "worker_strike", "bandit_activity"]
	pool.shuffle()
	for t in pool:
		var cd_until := int(_event_cooldowns.get(t, 0))
		if current_day < cd_until:
			continue
		
		# 3 seviyeli sistem: Düşük, Orta, Yüksek (rastgele seç)
		var level_weights := [0.4, 0.4, 0.2]  # %40 düşük, %40 orta, %20 yüksek
		var rand_val := randf()
		var event_level: int = EventLevel.LOW
		if rand_val < level_weights[0]:
			event_level = EventLevel.LOW
		elif rand_val < level_weights[0] + level_weights[1]:
			event_level = EventLevel.MEDIUM
		else:
			event_level = EventLevel.HIGH
		
		var dur := randi_range(event_duration_min_days, event_duration_max_days)
		var ev := {"type": t, "level": event_level, "severity": float(event_level) / 3.0, "ends_day": current_day + dur}  # severity geriye dönük uyumluluk için
		
		# Raid için özel zamanlama - 1-2 gün sonra saldırı olacak
		if t == "raid":
			var warning_days: int = randi_range(1, 2)  # 1-2 gün önce haber
			var attack_day: int = current_day + warning_days
			ev["raid_attack_day"] = attack_day
			ev["raid_warning_day"] = current_day
			# Event'in bitiş günü saldırı günü olsun
			ev["ends_day"] = attack_day
			# Raid için saldırgan fraksiyonu belirle (seviyeye göre)
			var attacker_names: Array[String] = ["Bilinmeyen Haydutlar", "Eşkıya Grubu", "Yağmacılar", "Brigand Çetesi"]
			if event_level >= EventLevel.MEDIUM:
				attacker_names = ["Güçlü Eşkıyalar", "Profesyonel Yağmacılar", "Savaşçı Çetesi", "Tehlikeli Haydutlar"]
			attacker_names.shuffle()
			ev["raid_attacker"] = attacker_names[0]
		
		# Worker Strike için özel sebep belirleme
		if t == "worker_strike":
			# Grev sebebi: düşük moral, kaynak eksikliği veya genel hoşnutsuzluk
			var strike_reason: String = ""
			var current_morale: float = village_morale
			var food_shortage: int = _last_day_shortages.get("food", 0)
			var water_shortage: int = _last_day_shortages.get("water", 0)
			
			if current_morale < 40.0:
				strike_reason = "düşük_moral"
			elif food_shortage > 0 or water_shortage > 0:
				strike_reason = "kaynak_eksikliği"
			else:
				strike_reason = "genel_hoşnutsuzluk"
			
			# Grev yapılacak kaynak tipini seç (temel kaynaklardan biri)
			var resource_types: Array[String] = ["wood", "stone", "food", "water"]
			resource_types.shuffle()
			ev["strike_resource"] = resource_types[0]
			ev["strike_reason"] = strike_reason
		
		# simple cooldown: 30 days
		_event_cooldowns[t] = current_day + 30
		# Post news to MissionManager if available
		var mm = get_node_or_null("/root/MissionManager")
		if mm and mm.has_method("post_news"):
			var level_name: String = EVENT_LEVEL_NAMES.get(event_level, "Bilinmeyen")
			var title := "Yeni Olay: %s" % t.capitalize()
			var msg := "Seviye: %s, Süre: %d gün" % [level_name, dur]
			if t == "raid" and ev.has("raid_attack_day"):
				var days_until = ev["raid_attack_day"] - current_day
				var attacker = ev.get("raid_attacker", "Bilinmeyen Haydutlar")
				msg = "%s saldırısı %d gün sonra bekleniyor! Askerlerinizi hazırlayın!" % [attacker, days_until]
				title = "🚨 Baskın Uyarısı!"
			elif t == "worker_strike" and ev.has("strike_resource"):
				var res_names: Dictionary = {"wood": "Odun", "stone": "Taş", "food": "Yiyecek", "water": "Su"}
				var reason_names: Dictionary = {"düşük_moral": "Düşük Moral", "kaynak_eksikliği": "Kaynak Eksikliği", "genel_hoşnutsuzluk": "Genel Hoşnutsuzluk"}
				msg = "%s - %s üretimi durdu (%s)" % [msg, res_names.get(ev["strike_resource"], ev["strike_resource"]), reason_names.get(ev.get("strike_reason", ""), "")]
			mm.post_news("world", title, msg, Color.ORANGE)
		return ev
	return {}

func _apply_event_effects(ev: Dictionary) -> void:
	var t := String(ev.get("type", ""))
	var tm = get_node_or_null("/root/TimeManager")
	var current_day: int = tm.get_day() if tm and tm.has_method("get_day") else 0
	
	# Seviyeyi al (geriye dönük uyumluluk için severity'den de çevirebiliriz)
	var event_level: int = ev.get("level", EventLevel.MEDIUM)
	if not ev.has("level") and ev.has("severity"):
		# Eski sistem: severity'yi level'a çevir
		var sev = float(ev.get("severity", 0.0))
		if sev < 0.2:
			event_level = EventLevel.LOW
		elif sev < 0.3:
			event_level = EventLevel.MEDIUM
		else:
			event_level = EventLevel.HIGH
	
	var level_name: String = EVENT_LEVEL_NAMES.get(event_level, "Bilinmeyen")
	var multiplier: float = EVENT_LEVEL_MULTIPLIERS.get(event_level, 0.8)
	var bonus_multiplier: float = EVENT_LEVEL_BONUS_MULTIPLIERS.get(event_level, 1.2)
	
	print("[EVENT DEBUG] 🔴 Applying event: %s (Seviye: %s)" % [t, level_name])
	
	match t:
		"drought":
			var old_val = float(resource_prod_multiplier.get("water", 1.0))
			resource_prod_multiplier["water"] = old_val * multiplier
			var new_val = resource_prod_multiplier["water"]
			var reduction_pct = (1.0 - multiplier) * 100.0
			print("[EVENT DEBUG]   Water multiplier: %.2f → %.2f (%.0f%% reduction)" % [old_val, new_val, reduction_pct])
		"famine":
			var old_val = float(resource_prod_multiplier.get("food", 1.0))
			resource_prod_multiplier["food"] = old_val * multiplier
			var new_val = resource_prod_multiplier["food"]
			var reduction_pct = (1.0 - multiplier) * 100.0
			print("[EVENT DEBUG]   Food multiplier: %.2f → %.2f (%.0f%% reduction)" % [old_val, new_val, reduction_pct])
		"pest":
			# Pest (zararlı) - odun üretimini azaltır (ağaç zararlıları)
			var old_val = float(resource_prod_multiplier.get("wood", 1.0))
			resource_prod_multiplier["wood"] = old_val * multiplier
			var new_val = resource_prod_multiplier["wood"]
			var reduction_pct = (1.0 - multiplier) * 100.0
			print("[EVENT DEBUG]   Wood multiplier: %.2f → %.2f (%.0f%% reduction)" % [old_val, new_val, reduction_pct])
		"wolf_attack":
			# Wolf Attack (kurt saldırısı) - taş üretimini azaltır
			var old_val = float(resource_prod_multiplier.get("stone", 1.0))
			resource_prod_multiplier["stone"] = old_val * multiplier
			var new_val = resource_prod_multiplier["stone"]
			var reduction_pct = (1.0 - multiplier) * 100.0
			print("[EVENT DEBUG]   Stone multiplier: %.2f → %.2f (%.0f%% reduction)" % [old_val, new_val, reduction_pct])
		"severe_storm":
			# Severe Storm (şiddetli fırtına) - tüm üretim azalır; hava durumuna yoğun yağmur + güçlü rüzgar
			var old_val = global_multiplier
			global_multiplier *= multiplier
			var reduction_pct = (1.0 - multiplier) * 100.0
			print("[EVENT DEBUG]   Global multiplier: %.2f → %.2f (%.0f%% reduction)" % [old_val, global_multiplier, reduction_pct])
			if WeatherManager:
				WeatherManager.set_storm_active(true, event_level)
		"weather_blessing":
			# Weather Blessing (hava bereketi) - tüm üretim artar
			var old_val = global_multiplier
			global_multiplier *= bonus_multiplier
			var increase_pct = (bonus_multiplier - 1.0) * 100.0
			print("[EVENT DEBUG]   Global multiplier: %.2f → %.2f (%.0f%% increase)" % [old_val, global_multiplier, increase_pct])
		"worker_strike":
			# Worker Strike (işçi grevi) - belirli bir kaynak tipinde üretim durur
			var strike_resource: String = String(ev.get("strike_resource", "wood"))
			var old_val = float(resource_prod_multiplier.get(strike_resource, 1.0))
			resource_prod_multiplier[strike_resource] = 0.0  # Üretim tamamen durur
			print("[EVENT DEBUG]   %s multiplier: %.2f → 0.00 (PRODUCTION STOPPED)" % [strike_resource.capitalize(), old_val])
			if ev.has("strike_reason"):
				print("[EVENT DEBUG]   Strike reason: %s" % ev["strike_reason"])
		"disease":
			# Disease (hastalık) - işçileri hasta yapar
			# tm ve current_day zaten fonksiyonun başında tanımlı
			
			# Seviyeye göre kaç işçi hasta olacak
			var total_worker_count: int = all_workers.size()
			var sick_count: int = 0
			match event_level:
				EventLevel.LOW:
					sick_count = max(1, int(total_worker_count * 0.2))  # %20 işçi hasta
				EventLevel.MEDIUM:
					sick_count = max(1, int(total_worker_count * 0.35))  # %35 işçi hasta
				EventLevel.HIGH:
					sick_count = max(1, int(total_worker_count * 0.5))  # %50 işçi hasta
			
			# Tüm işçileri hasta yapabilir (askerler dahil)
			var worker_ids_list: Array = []
			for worker_id in all_workers.keys():
				var worker_data = all_workers.get(worker_id, {})
				if not worker_data:
					continue
				var worker_instance = worker_data.get("instance", null)
				if not is_instance_valid(worker_instance):
					continue
				worker_ids_list.append(worker_id)
			
			worker_ids_list.shuffle()
			var actually_sick: int = 0
			for i in range(min(sick_count, worker_ids_list.size())):
				var worker_id = worker_ids_list[i]
				var worker_data = all_workers.get(worker_id, {})
				if not worker_data:
					continue
				var worker_instance = worker_data.get("instance", null)
				if not is_instance_valid(worker_instance):
					continue
				
				# Eski iş bilgilerini kaydet (iyileşince dönmek için)
				var old_job_type: String = ""
				var old_building: Node2D = null
				if "assigned_job_type" in worker_instance:
					old_job_type = worker_instance.assigned_job_type
				if "assigned_building_node" in worker_instance:
					old_building = worker_instance.assigned_building_node
				
				worker_instance.previous_job_type = old_job_type
				worker_instance.previous_building_node = old_building
				
				# İşçiyi binadan çıkar
				if is_instance_valid(old_building):
					_make_worker_sick_and_unassign(worker_instance, worker_id, old_building)
				
				# İşçiyi hasta yap
				worker_instance.is_sick = true
				worker_instance.sick_since_day = current_day
				
				# Eğer uykudaysa direkt SICK state'ine geç, değilse evine git
				if worker_instance.current_state == 0:  # State.SLEEPING
					worker_instance.current_state = 12  # State.SICK (enum değeri: 12)
					worker_instance.visible = false
				else:
					# Evine gitmesi için GOING_HOME_SICK state'ine geç
					worker_instance.current_state = 13  # State.GOING_HOME_SICK (enum değeri: 13)
					worker_instance.visible = true  # Evine giderken görünür
				
				actually_sick += 1
			
			# Event'e hasta işçi sayısını kaydet (iyileşme kontrolü için)
			ev["sick_worker_ids"] = worker_ids_list.slice(0, actually_sick)
			print("[EVENT DEBUG]   Disease: %d işçi hasta oldu (Seviye: %s)" % [actually_sick, level_name])
		"raid":
			# Raid (baskın) - WorldManager'a saldırı zamanlaması ekle
			# Direkt kaynak çalma yapmak yerine, mevcut savunma sistemini kullan
			var wm = get_node_or_null("/root/WorldManager")
			if not wm:
				print("[EVENT DEBUG]   Raid: WorldManager bulunamadı!")
				return
			
			# tm zaten fonksiyonun başında tanımlı
			if not tm:
				print("[EVENT DEBUG]   Raid: TimeManager bulunamadı!")
				return
			
			var attack_day: int = int(ev.get("raid_attack_day", current_day + 1))
			var attacker: String = String(ev.get("raid_attacker", "Bilinmeyen Haydutlar"))
			var current_hour: float = tm.get_hour() if tm.has_method("get_hour") else 12.0
			
			print("[EVENT DEBUG]   Raid: %s saldırısı %d. günde gerçekleşecek (Seviye: %s)" % [attacker, attack_day, level_name])
			
			# WorldManager'a saldırı zamanlaması ekle
			# Raid event'i için özel zamanlama: 1-2 gün sonra saldırı
			# Saldırı günü öğlen saatinde (12:00) olacak
			var attack_hour: float = 12.0
			var warning_day: int = current_day
			var warning_hour: float = current_hour
			
			# WorldManager'ın pending_attacks array'ine direkt ekle
			if "pending_attacks" in wm:
				var pending_attack = {
					"attacker": attacker,
					"warning_day": warning_day,
					"warning_hour": warning_hour,
					"attack_day": attack_day,
					"attack_hour": attack_hour,
					"deployed": false,
					"is_raid_event": true,  # Raid event'inden geldiğini işaretle
					"severity": float(event_level) / 3.0,  # Geriye dönük uyumluluk için
					"level": event_level  # Seviyeyi sakla
				}
				wm.pending_attacks.append(pending_attack)
				print("[EVENT DEBUG]   Raid: Saldırı zamanlaması WorldManager'a eklendi (Gün %d, Saat %.1f)" % [attack_day, attack_hour])
			else:
				print("[EVENT DEBUG]   Raid: WorldManager.pending_attacks bulunamadı!")
		"bandit_activity":
			# Bandit Activity (haydut faaliyeti) - ticaret aksar, cariye görevleri daha tehlikeli
			var mm = get_node_or_null("/root/MissionManager")
			if not mm:
				print("[EVENT DEBUG]   Bandit Activity: MissionManager bulunamadı!")
				return
			
			# Ticaret modifikasyonu: Tüm yerleşimler için ticaret zorlaşır
			var trade_multiplier: float = 1.0
			match event_level:
				EventLevel.LOW:
					trade_multiplier = 0.7  # %30 azalma
				EventLevel.MEDIUM:
					trade_multiplier = 0.5  # %50 azalma
				EventLevel.HIGH:
					trade_multiplier = 0.3  # %70 azalma
			
			ev["bandit_trade_multiplier"] = trade_multiplier
			ev["bandit_risk_bonus"] = event_level
			
			# MissionManager'a doğrudan ata (set() bazen eksik kalabiliyor)
			mm.bandit_activity_active = true
			mm.bandit_trade_multiplier = trade_multiplier
			mm.bandit_risk_level = event_level
			if mm.has_method("add_bandit_clear_mission"):
				mm.add_bandit_clear_mission()
			
			print("[EVENT DEBUG]   Bandit Activity: Ticaret çarpanı %.2f, Haydut Temizliği görevi eklendi (Seviye: %s)" % [trade_multiplier, level_name])
		_:
			pass # placeholder: other effects can be added later

func _remove_event_effects(ev: Dictionary) -> void:
	var t := String(ev.get("type", ""))
	
	# Seviyeyi al (geriye dönük uyumluluk için)
	var event_level: int = ev.get("level", EventLevel.MEDIUM)
	if not ev.has("level") and ev.has("severity"):
		var sev = float(ev.get("severity", 0.0))
		if sev < 0.2:
			event_level = EventLevel.LOW
		elif sev < 0.3:
			event_level = EventLevel.MEDIUM
		else:
			event_level = EventLevel.HIGH
	
	var level_name: String = EVENT_LEVEL_NAMES.get(event_level, "Bilinmeyen")
	var multiplier: float = EVENT_LEVEL_MULTIPLIERS.get(event_level, 0.8)
	var bonus_multiplier: float = EVENT_LEVEL_BONUS_MULTIPLIERS.get(event_level, 1.2)
	
	print("[EVENT DEBUG] 🟢 Removing event: %s (Seviye: %s)" % [t, level_name])
	
	match t:
		"drought":
			var old_val = float(resource_prod_multiplier.get("water", 1.0))
			resource_prod_multiplier["water"] = old_val / multiplier
			var new_val = resource_prod_multiplier["water"]
			print("[EVENT DEBUG]   Water multiplier: %.2f → %.2f (restored)" % [old_val, new_val])
		"famine":
			var old_val = float(resource_prod_multiplier.get("food", 1.0))
			resource_prod_multiplier["food"] = old_val / multiplier
			var new_val = resource_prod_multiplier["food"]
			print("[EVENT DEBUG]   Food multiplier: %.2f → %.2f (restored)" % [old_val, new_val])
		"pest":
			var old_val = float(resource_prod_multiplier.get("wood", 1.0))
			resource_prod_multiplier["wood"] = old_val / multiplier
			var new_val = resource_prod_multiplier["wood"]
			print("[EVENT DEBUG]   Wood multiplier: %.2f → %.2f (restored)" % [old_val, new_val])
		"wolf_attack":
			var old_val = float(resource_prod_multiplier.get("stone", 1.0))
			resource_prod_multiplier["stone"] = old_val / multiplier
			var new_val = resource_prod_multiplier["stone"]
			print("[EVENT DEBUG]   Stone multiplier: %.2f → %.2f (restored)" % [old_val, new_val])
		"severe_storm":
			var old_val = global_multiplier
			global_multiplier /= multiplier
			print("[EVENT DEBUG]   Global multiplier: %.2f → %.2f (restored)" % [old_val, global_multiplier])
			if WeatherManager:
				WeatherManager.set_storm_active(false)
		"weather_blessing":
			var old_val = global_multiplier
			global_multiplier /= bonus_multiplier
			print("[EVENT DEBUG]   Global multiplier: %.2f → %.2f (restored)" % [old_val, global_multiplier])
		"worker_strike":
			# Grev bittiğinde üretim normale döner
			var strike_resource: String = String(ev.get("strike_resource", "wood"))
			var old_val = float(resource_prod_multiplier.get(strike_resource, 0.0))
			resource_prod_multiplier[strike_resource] = 1.0
			print("[EVENT DEBUG]   %s multiplier: %.2f → 1.00 (PRODUCTION RESUMED)" % [strike_resource.capitalize(), old_val])
		"disease":
			# Disease event'i bittiğinde kalan hasta işçileri iyileştir
			var sick_worker_ids = ev.get("sick_worker_ids", [])
			var healed_count: int = 0
			for worker_id in sick_worker_ids:
				var worker_data = all_workers.get(worker_id, {})
				if not worker_data:
					continue
				var worker_instance = worker_data.get("instance", null)
				if not is_instance_valid(worker_instance):
					continue
				if "is_sick" in worker_instance and worker_instance.is_sick:
					worker_instance.is_sick = false
					worker_instance.sick_since_day = -1
					
					# Eski işine dönmeyi dene
					_restore_worker_to_previous_job(worker_instance)
					
					healed_count += 1
			print("[EVENT DEBUG]   Disease event sona erdi: %d işçi iyileşti" % healed_count)
		"bandit_activity":
			# Bandit Activity event'i bittiğinde ticaret normale döner
			var mm = get_node_or_null("/root/MissionManager")
			if mm:
				if "bandit_activity_active" in mm:
					mm.set("bandit_activity_active", false)
				if "bandit_trade_multiplier" in mm:
					mm.set("bandit_trade_multiplier", 1.0)
				if "bandit_risk_level" in mm:
					mm.set("bandit_risk_level", 0)
			print("[EVENT DEBUG]   Bandit Activity event sona erdi: Ticaret normale döndü")
		"raid":
			# Raid event'i için özel kaldırma işlemi yok
			# Savaş zaten WorldManager tarafından yönetiliyor ve sonuçları işleniyor
			print("[EVENT DEBUG]   Raid event sona erdi (savaş WorldManager tarafından yönetildi)")
		_:
			pass

# === Village-Specific Direct Events ===
func _check_and_trigger_village_event(day: int) -> bool:
	"""Check and trigger village-specific direct events (not world events).
	Returns true if an event was triggered."""
	if not village_events_enabled:
		return false
	
	# İlişkiye göre tüccar gelme şansı (dinamik)
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		# settlements property'sine direkt erişim (MissionManager'da tanımlı)
		var settlements = mm.settlements
		if settlements and not settlements.is_empty():
			# En yüksek ilişkiye sahip yerleşimden tüccar gelme şansı
			var best_settlement = null
			var best_relation = 0
			for s in settlements:
				var rel = s.get("relation", 50)
				if rel > best_relation:
					best_relation = rel
					best_settlement = s
			
			if best_settlement:
				# İlişkiye göre şans hesapla
				var base_chance = village_daily_event_chance  # Temel şans
				var relation_bonus = (best_relation - 50) * 0.01  # Her 1 ilişki = %1 bonus
				var final_chance = clamp(base_chance + relation_bonus, 0.05, 0.5)  # Min %5, Max %50
				
				# Sadece tüccar eventi için özel şans
				if randf() < final_chance:
					# Tüccar eventi tetikle
					_trigger_village_event("trade_caravan", day)
					return true
	
	# Diğer eventler için normal şans kontrolü
	if randf() > village_daily_event_chance:
		return false
	
	# Select a random village event
	var event_pool: Array[String] = [
		"trade_caravan",      # Ticaret kervanı - altın bonusu
		"resource_discovery", # Kaynak keşfi - rastgele kaynak bonusu
		"windfall",          # Bolluk - küçük kaynak bonusu
		"traveler",          # Seyyah - yeni görev fırsatı (placeholder)
		"minor_accident",    # Küçük kaza - küçük kaynak kaybı
		"immigration_wave"   # Göç dalgası - bedava işçi ekler
	]
	
	# Filter out events on cooldown
	var available_events: Array[String] = []
	for event_type in event_pool:
		var cooldown_until: int = _village_event_cooldowns.get(event_type, 0)
		if day >= cooldown_until:
			available_events.append(event_type)
	
	if available_events.is_empty():
		return false
	
	# Pick random event
	available_events.shuffle()
	var selected_event: String = available_events[0]
	
	# Trigger the event
	_trigger_village_event(selected_event, day)
	
	# Set cooldown (5-10 days depending on event)
	var cooldown_days: int = 5
	match selected_event:
		"trade_caravan":
			cooldown_days = 7
		"resource_discovery":
			cooldown_days = 10
		"traveler":
			cooldown_days = 8
		"immigration_wave":
			cooldown_days = 15  # Göç dalgası nadir olmalı
		_:
			cooldown_days = 5
	_village_event_cooldowns[selected_event] = day + cooldown_days
	
	return true

func _trigger_village_event(event_type: String, day: int) -> void:
	"""Trigger a village-specific direct event."""
	var mm = get_node_or_null("/root/MissionManager")
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	
	match event_type:
		"trade_caravan":
			# YENİ SİSTEM: Köye tüccar geliyor
			if not mm:
				return
			
			# MissionManager'dan yerleşimleri al
			if not mm.has_method("create_settlements"):
				return
			
			# settlements property'sine direkt erişim
			var settlements = mm.settlements
			if not settlements or settlements.is_empty():
				if mm.has_method("create_settlements"):
					mm.create_settlements()
				settlements = mm.settlements
			
			if settlements.is_empty():
				return
			
			# En yüksek ilişkiye sahip yerleşimden tüccar gelir (veya rastgele)
			var settlement = _select_settlement_for_trader(settlements)
			var trader_type = _select_trader_type_by_relation(settlement)
			
			# MissionManager'a tüccar ekle
			if mm.has_method("add_active_trader"):
				mm.add_active_trader(settlement, day, 3, trader_type)
			print("[VillageManager] 🎉 Tüccar geldi: %s'den (Tip: %d)" % [settlement.get("name", "?"), trader_type])
		
		"resource_discovery":
			# Kaynak keşfi - rastgele kaynak bonusu
			var resource_pool: Array[String] = ["wood", "stone", "food", "water"]
			resource_pool.shuffle()
			var discovered_resource: String = resource_pool[0]
			var amount: int = randi_range(5, 15)
			resource_levels[discovered_resource] = resource_levels.get(discovered_resource, 0) + amount
			var res_names: Dictionary = {
				"wood": "Odun",
				"stone": "Taş",
				"food": "Yiyecek",
				"water": "Su"
			}
			var title := "🔍 Kaynak Keşfi"
			var content := "Köylüler bir %s deposu buldular! +%d %s eklendi." % [res_names.get(discovered_resource, discovered_resource), amount, res_names.get(discovered_resource, discovered_resource)]
			if mm and mm.has_method("post_news"):
				mm.post_news("village", title, content, Color.CYAN, "info")
			print("[VillageManager] 🎉 Resource discovery: +%d %s" % [amount, discovered_resource])
		
		"windfall":
			# Bolluk - küçük kaynak bonusu
			var bonus_wood: int = randi_range(2, 5)
			var bonus_stone: int = randi_range(2, 5)
			resource_levels["wood"] = resource_levels.get("wood", 0) + bonus_wood
			resource_levels["stone"] = resource_levels.get("stone", 0) + bonus_stone
			var title := "🍀 Bolluk"
			var content := "İyi bir hasat sezonu geçirdik! +%d odun, +%d taş eklendi." % [bonus_wood, bonus_stone]
			if mm and mm.has_method("post_news"):
				mm.post_news("village", title, content, Color.GREEN, "success")
			print("[VillageManager] 🎉 Windfall event: +%d wood, +%d stone" % [bonus_wood, bonus_stone])
		
		"traveler":
			# Seyyah - yeni görev fırsatı (placeholder, MissionManager'a entegre edilebilir)
			var title := "🧳 Seyyah Ziyareti"
			var content := "Bir seyyah köyünüze uğradı ve size ilginç hikayeler anlattı."
			if mm and mm.has_method("post_news"):
				mm.post_news("village", title, content, Color.YELLOW, "info")
			print("[VillageManager] 🎉 Traveler event")
		
		"minor_accident":
			# Küçük kaza - küçük kaynak kaybı
			var resource_pool: Array[String] = ["wood", "stone"]
			resource_pool.shuffle()
			var lost_resource: String = resource_pool[0]
			var loss: int = randi_range(1, 3)
			var current: int = resource_levels.get(lost_resource, 0)
			resource_levels[lost_resource] = max(0, current - loss)
			var res_names: Dictionary = {"wood": "Odun", "stone": "Taş"}
			var title := "⚠️ Küçük Kaza"
			var content := "Köyde küçük bir kaza oldu. -%d %s kaybedildi." % [loss, res_names.get(lost_resource, lost_resource)]
			if mm and mm.has_method("post_news"):
				mm.post_news("village", title, content, Color.ORANGE, "warning")
			print("[VillageManager] ⚠️ Minor accident: -%d %s" % [loss, lost_resource])
		
		"immigration_wave":
			# Göç dalgası - bedava işçi ekler
			var worker_count: int = randi_range(2, 5)  # 2-5 işçi
			var added_count: int = 0
			for i in range(worker_count):
				if _add_new_worker({}):  # Boş NPC info ile yeni işçi ekle
					added_count += 1
			
			if added_count > 0:
				var title := "👥 Göç Dalgası"
				var content := "%d yeni köylü köyünüze yerleşti!" % added_count
				if mm and mm.has_method("post_news"):
					mm.post_news("village", title, content, Color.CYAN, "success")
				print("[VillageManager] 🎉 Immigration wave: +%d workers" % added_count)
			else:
				# Barınak yetersizse haber gönderme (opsiyonel)
				if mm and mm.has_method("post_news"):
					mm.post_news("village", "Göç Dalgası", "Göçmenler geldi ama barınak yetersiz olduğu için geri döndüler.", Color.YELLOW, "info")
	
	emit_signal("village_data_changed")

# Yerleşim seçimi (ilişkiye göre ağırlıklandırılmış)
func _select_settlement_for_trader(settlements: Array) -> Dictionary:
	# İyi ilişkilere sahip yerleşimlerden daha sık tüccar gelir
	var weighted_settlements: Array = []
	for s in settlements:
		var relation = s.get("relation", 50)
		var weight = max(1, relation / 10)  # İlişki/10 = ağırlık (min 1)
		for i in range(int(weight)):
			weighted_settlements.append(s)
	
	if weighted_settlements.is_empty():
		return settlements[randi() % settlements.size()]
	
	weighted_settlements.shuffle()
	return weighted_settlements[randi() % weighted_settlements.size()]

# İlişkiye göre tüccar tipi seç
func _select_trader_type_by_relation(settlement: Dictionary) -> int:
	var relation = settlement.get("relation", 50)
	var rand_val = randf()
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		return 0  # NORMAL
	
	# İyi ilişkilerde daha iyi tüccarlar gelir
	if relation >= 70:
		if rand_val < 0.3:
			return mm.TraderType.RICH
		elif rand_val < 0.5:
			return mm.TraderType.SPECIAL
		elif rand_val < 0.7:
			return mm.TraderType.NOMAD
		else:
			return mm.TraderType.NORMAL
	elif relation >= 40:
		if rand_val < 0.2:
			return mm.TraderType.SPECIAL
		elif rand_val < 0.4:
			return mm.TraderType.NOMAD
		else:
			return mm.TraderType.NORMAL
	else:
		if rand_val < 0.3:
			return mm.TraderType.POOR
		else:
			return mm.TraderType.NORMAL

# === UI getters & toggles ===
func get_economy_last_day_stats() -> Dictionary:
	return economy_stats_last_day

func get_active_events() -> Array:
	return events_active

func reapply_active_event_effects() -> void:
	"""Kayıt yüklemeden sonra çağrılır: Aktif event'lerin effect'lerini yeniden uygular (Bandit Activity → Haydut Temizliği görevi vb.)."""
	for ev in events_active:
		_apply_event_effects(ev)

func clear_event(event_type: String = "") -> int:
	"""Clear active events. If event_type is empty, clears all events.
	Returns the number of events cleared."""
	var cleared_count = 0
	var tm = get_node_or_null("/root/TimeManager")
	var day: int = tm.get_day() if tm and tm.has_method("get_day") else 0
	
	if event_type.is_empty():
		# Clear all events
		print("[EVENT DEBUG] 🗑️ Clearing all events (%d active)" % events_active.size())
		for ev in events_active:
			_remove_event_effects(ev)
			cleared_count += 1
		events_active.clear()
	else:
		# Clear specific event type
		var remaining: Array[Dictionary] = []
		for ev in events_active:
			if String(ev.get("type", "")) == event_type:
				_remove_event_effects(ev)
				cleared_count += 1
			else:
				remaining.append(ev)
		events_active = remaining
	
	return cleared_count

func _on_mission_manager_mission_started(_cariye_id: int, mission_id: String) -> void:
	# Göreve giden askerleri cariyeyle aynı yöne yürüyerek ekrandan çıkar (raid savunması gibi)
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		print("[RAID_DEBUG] VillageManager mission_started: MissionManager yok")
		return
	var extra = mm.get_raid_mission_extra(mission_id)
	var exit_x: float = float(extra.get("mission_exit_x", 0))
	var worker_ids: Array = []
	var wids = extra.get("assigned_soldier_worker_ids", [])
	if wids is Array:
		worker_ids = wids
	print("[RAID_DEBUG] VillageManager mission_started: mission_id=%s extra_keys=%s exit_x=%.0f worker_ids=%s all_workers_keys_count=%d" % [
		mission_id, str(extra.keys()), exit_x, str(worker_ids), all_workers.size()
	])
	if worker_ids.is_empty():
		print("[RAID_DEBUG] VillageManager: worker_ids boş, çıkılıyor")
		return
	# Worker.State.WORKING_OFFSCREEN = 3 (enum sırası)
	const STATE_WORKING_OFFSCREEN := 3
	var set_count := 0
	for w in worker_ids:
		var wid = int(w) if w is float else w
		if not all_workers.has(wid):
			print("[RAID_DEBUG]   wid=%s all_workers'da yok" % wid)
			continue
		var worker_data = all_workers[wid]
		var inst = worker_data.get("instance", null)
		if not is_instance_valid(inst):
			print("[RAID_DEBUG]   wid=%s instance geçersiz" % wid)
			continue
		var job = inst.get("assigned_job_type")
		if job == null:
			job = ""
		if job != "soldier":
			print("[RAID_DEBUG]   wid=%s job='%s' (soldier değil)" % [wid, job])
			continue
		inst.set("is_deployed", true)
		inst.set("current_state", STATE_WORKING_OFFSCREEN)
		inst.visible = true
		inst.set("move_target_x", exit_x)
		inst.set("_target_global_y", inst.global_position.y)
		set_count += 1
		print("[RAID_DEBUG]   wid=%s -> deployed, state=WORKING_OFFSCREEN, move_target_x=%.0f" % [wid, exit_x])
	print("[RAID_DEBUG] VillageManager: %d asker deploy edildi" % set_count)

func _on_mission_manager_mission_cancelled(_cariye_id: int, mission_id: String) -> void:
	# İptal edilen görevdeki askerleri tekrar göster
	_show_soldiers_back_from_mission(mission_id)

func _show_soldiers_back_from_mission(mission_id: String) -> void:
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		return
	var extra = mm.get_raid_mission_extra(mission_id)
	var worker_ids: Array = []
	var wids = extra.get("assigned_soldier_worker_ids", [])
	if wids is Array:
		worker_ids = wids
	var barracks = _find_barracks()
	var return_x: float = 0.0
	if is_instance_valid(barracks):
		return_x = barracks.global_position.x
	elif campfire_node and is_instance_valid(campfire_node):
		return_x = campfire_node.global_position.x
	for w in worker_ids:
		var wid = int(w) if w is float else w
		if not all_workers.has(wid):
			continue
		var worker_data = all_workers[wid]
		var inst = worker_data.get("instance", null)
		if not is_instance_valid(inst):
			continue
		inst.set("is_deployed", false)
		inst.set("current_state", 6)  # Worker.State.RETURNING_FROM_WORK
		inst.visible = true
		inst.set("move_target_x", return_x)
		inst.set("_target_global_y", inst.global_position.y)
	# Temizlik: MissionManager'daki raid ek verisini sil
	mm.clear_raid_mission_extra(mission_id)
	print("[RAID_DEBUG] _show_soldiers_back_from_mission: mission_id=%s %d asker geri çağrıldı" % [mission_id, worker_ids.size()])

func _on_mission_manager_mission_completed(_cariye_id: int, mission_id: String, successful: bool, _results: Dictionary) -> void:
	# Görevdeki askerleri tekrar ekranda göster
	_show_soldiers_back_from_mission(mission_id)
	# Haydut Temizliği görevi başarıyla bitince bandit_activity event'ini kapat
	if mission_id.begins_with("bandit_clear_") and successful:
		var n = clear_event("bandit_activity")
		if n > 0:
			print("[EVENT DEBUG] Haydut Temizliği başarılı: bandit_activity event sona erdirildi.")

func get_production_multipliers() -> Dictionary:
	"""Get current production multipliers for debugging."""
	return {
		"global": global_multiplier,
		"resource": resource_prod_multiplier.duplicate(true),
		"morale": village_morale
	}

func _make_worker_sick_and_unassign(worker_instance: Node, worker_id: int, building: Node2D) -> void:
	"""İşçiyi binadan çıkar ve hasta yap (hastalık event'i için)"""
	if not is_instance_valid(building):
		return
	
	# Binadan işçiyi çıkar
	if "assigned_worker_ids" in building:
		var worker_ids = building.get("assigned_worker_ids")
		if worker_ids is Array and worker_id in worker_ids:
			var idx = worker_ids.find(worker_id)
			if idx >= 0:
				worker_ids.remove_at(idx)
	
	# Bina sayacını azalt
	if "assigned_workers" in building:
		building.assigned_workers = max(0, building.assigned_workers - 1)
		notify_building_state_changed(building)
	
	# İşçinin atamasını kaldır
	var was_working: bool = not worker_instance.assigned_job_type.is_empty()
	worker_instance.assigned_job_type = ""
	worker_instance.assigned_building_node = null
	
	# Idle sayısını artır (eğer çalışıyorsa)
	if was_working:
		idle_workers += 1

func _check_and_heal_sick_workers(current_day: int) -> void:
	"""Her gün hasta işçileri kontrol et: İlaç varsa iyileştir, yoksa moral düşür."""
	var sick_workers: Array = []
	var total_sick: int = 0
	
	# Tüm hasta işçileri bul
	for worker_id in all_workers.keys():
		var worker_data = all_workers.get(worker_id, {})
		if not worker_data:
			continue
		var worker_instance = worker_data.get("instance", null)
		if not is_instance_valid(worker_instance):
			continue
		
		if "is_sick" in worker_instance and worker_instance.is_sick:
			total_sick += 1
			sick_workers.append(worker_instance)
	
	if total_sick == 0:
		return  # Hasta işçi yok
	
	# İlaç kontrolü
	var medicine_count: int = int(resource_levels.get("medicine", 0))
	var healed_count: int = 0
	var morale_loss: float = 0.0
	
	# İlaç varsa hasta işçileri iyileştir (1 günde iyileşir)
	if medicine_count > 0:
		for worker_instance in sick_workers:
			var sick_since: int = -1
			if "sick_since_day" in worker_instance:
				sick_since = worker_instance.sick_since_day
			if sick_since >= 0 and current_day > sick_since:  # En az 1 gün geçmişse
				# İlaç kullan ve iyileştir
				resource_levels["medicine"] = max(0, medicine_count - 1)
				medicine_count -= 1
				worker_instance.is_sick = false
				worker_instance.sick_since_day = -1
				
				# Eski işine dönmeyi dene
				_restore_worker_to_previous_job(worker_instance)
				
				healed_count += 1
				
				if medicine_count <= 0:
					break  # İlaç bitti
	
	# İyileşemeyen hasta işçiler için moral düşüşü
	var still_sick: int = total_sick - healed_count
	if still_sick > 0:
		# Her hasta işçi için -2 moral (günlük)
		morale_loss = float(still_sick) * 2.0
		village_morale = max(0.0, village_morale - morale_loss)
		print("[DISEASE DEBUG] %d işçi hala hasta, moral düştü: -%.1f (Toplam hasta: %d, İyileşen: %d)" % [still_sick, morale_loss, total_sick, healed_count])
	
	if healed_count > 0:
		print("[DISEASE DEBUG] %d işçi ilaçla iyileşti (Kalan ilaç: %d)" % [healed_count, medicine_count])

func _restore_worker_to_previous_job(worker_instance: Node) -> void:
	"""İyileşen işçiyi eski işine geri döndürmeyi dene"""
	if not is_instance_valid(worker_instance):
		return
	
	var prev_job: String = ""
	var prev_building: Node2D = null
	
	if "previous_job_type" in worker_instance:
		prev_job = worker_instance.previous_job_type
	if "previous_building_node" in worker_instance:
		prev_building = worker_instance.previous_building_node
	
	# Eski iş bilgisi yoksa açıkta kalır
	if prev_job.is_empty() or not is_instance_valid(prev_building):
		worker_instance.current_state = 1  # State.AWAKE_IDLE
		worker_instance.visible = true
		worker_instance.previous_job_type = ""
		worker_instance.previous_building_node = null
		idle_workers += 1
		return
	
	# Bina hala geçerli mi ve yer var mı kontrol et
	var max_workers: int = 0
	var current_workers: int = 0
	
	if "max_workers" in prev_building:
		max_workers = prev_building.max_workers
	if "assigned_workers" in prev_building:
		current_workers = prev_building.assigned_workers
	
	# Yer varsa eski işine dön
	if current_workers < max_workers:
		worker_instance.assigned_job_type = prev_job
		worker_instance.assigned_building_node = prev_building
		
		# Binaya ekle
		if "assigned_worker_ids" in prev_building:
			var worker_ids = prev_building.get("assigned_worker_ids")
			if worker_ids is Array:
				if not worker_instance.worker_id in worker_ids:
					worker_ids.append(worker_instance.worker_id)
		
		if "assigned_workers" in prev_building:
			prev_building.assigned_workers = current_workers + 1
			notify_building_state_changed(prev_building)
		
		worker_instance.current_state = 1  # State.AWAKE_IDLE
		worker_instance.visible = true
		print("[DISEASE DEBUG] İşçi %d eski işine (%s) döndü" % [worker_instance.worker_id, prev_job])
	else:
		# Yer yoksa açıkta kalır
		worker_instance.current_state = 1  # State.AWAKE_IDLE
		worker_instance.visible = true
		idle_workers += 1
		print("[DISEASE DEBUG] İşçi %d iyileşti ama eski işinde (%s) yer yok, açıkta kaldı" % [worker_instance.worker_id, prev_job])
	
	# Eski iş bilgilerini temizle
	worker_instance.previous_job_type = ""
	worker_instance.previous_building_node = null

func set_economy_enabled(enabled: bool) -> void:
	economy_enabled = enabled

func set_events_enabled(enabled: bool) -> void:
	events_enabled = enabled

# Storage UI helpers
func get_storage_capacity_for(resource_type: String) -> int:
	return _get_storage_capacity_for(resource_type)

func get_storage_usage(resource_type: String) -> Dictionary:
	var level := int(resource_levels.get(resource_type, 0))
	var cap := _get_storage_capacity_for(resource_type)
	return {"level": level, "capacity": cap}

# --- Public helpers for UI/Debug ---
func get_morale() -> float:
	return village_morale

func get_active_events_summary(current_day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev in events_active:
		var ends := int(ev.get("ends_day", current_day))
		var days_left: int = max(0, ends - current_day)
		var event_level: int = ev.get("level", EventLevel.MEDIUM)
		var level_name: String = EVENT_LEVEL_NAMES.get(event_level, "Bilinmeyen")
		out.append({
			"type": String(ev.get("type", "")),
			"severity": float(ev.get("severity", 0.0)),  # Geriye dönük uyumluluk için
			"level": event_level,
			"level_name": level_name,
			"days_left": days_left
		})
	return out

func trigger_random_event_debug() -> void:
	var tm = get_node_or_null("/root/TimeManager")
	var day: int = tm.get_day() if tm and tm.has_method("get_day") else 0
	var ev := _pick_and_create_event(day)
	if not ev.is_empty():
		events_active.append(ev)
		_apply_event_effects(ev)

func trigger_specific_world_event(event_type: String, severity: float = -1.0, duration_days: int = -1) -> bool:
	"""Trigger a specific world event for testing.
	Returns true if event was successfully triggered."""
	var tm = get_node_or_null("/root/TimeManager")
	var day: int = tm.get_day() if tm and tm.has_method("get_day") else 0
	
	# Valid event types (dev console trigger_world_event ile test için)
	var valid_types: Array[String] = ["drought", "famine", "pest", "disease", "raid", "wolf_attack", "severe_storm", "weather_blessing", "worker_strike", "bandit_activity"]
	if not event_type in valid_types:
		return false
	
	# Seviye belirleme (severity parametresi varsa onu kullan, yoksa rastgele)
	var event_level: int = EventLevel.MEDIUM
	if severity >= 0.0:
		# Severity'yi level'a çevir (test için)
		if severity < 0.2:
			event_level = EventLevel.LOW
		elif severity < 0.3:
			event_level = EventLevel.MEDIUM
		else:
			event_level = EventLevel.HIGH
	else:
		# Rastgele seviye seç
		var rand_val := randf()
		if rand_val < 0.4:
			event_level = EventLevel.LOW
		elif rand_val < 0.8:
			event_level = EventLevel.MEDIUM
		else:
			event_level = EventLevel.HIGH
	
	var dur: int = duration_days if duration_days > 0 else randi_range(event_duration_min_days, event_duration_max_days)
	var ev := {"type": event_type, "level": event_level, "severity": float(event_level) / 3.0, "ends_day": day + dur}  # severity geriye dönük uyumluluk için
	
	# Raid için özel zamanlama - 1-2 gün sonra saldırı olacak
	if event_type == "raid":
		var warning_days: int = randi_range(1, 2)  # 1-2 gün önce haber
		var attack_day: int = day + warning_days
		ev["raid_attack_day"] = attack_day
		ev["raid_warning_day"] = day
		# Event'in bitiş günü saldırı günü olsun
		ev["ends_day"] = attack_day
		# Raid için saldırgan fraksiyonu belirle (seviyeye göre)
		var attacker_names: Array[String] = ["Bilinmeyen Haydutlar", "Eşkıya Grubu", "Yağmacılar", "Brigand Çetesi"]
		if event_level >= EventLevel.MEDIUM:
			attacker_names = ["Güçlü Eşkıyalar", "Profesyonel Yağmacılar", "Savaşçı Çetesi", "Tehlikeli Haydutlar"]
		attacker_names.shuffle()
		ev["raid_attacker"] = attacker_names[0]
	
	# Worker Strike için özel sebep belirleme
	if event_type == "worker_strike":
		var strike_reason: String = ""
		var current_morale: float = village_morale
		var food_shortage: int = _last_day_shortages.get("food", 0)
		var water_shortage: int = _last_day_shortages.get("water", 0)
		
		if current_morale < 40.0:
			strike_reason = "düşük_moral"
		elif food_shortage > 0 or water_shortage > 0:
			strike_reason = "kaynak_eksikliği"
		else:
			strike_reason = "genel_hoşnutsuzluk"
		
		var resource_types: Array[String] = ["wood", "stone", "food", "water"]
		resource_types.shuffle()
		ev["strike_resource"] = resource_types[0]
		ev["strike_reason"] = strike_reason
	
	# Cooldown'u atla (test için)
	# _event_cooldowns[event_type] = day + 30
	
	# Post news
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("post_news"):
		var level_name: String = EVENT_LEVEL_NAMES.get(event_level, "Bilinmeyen")
		var title := "Yeni Olay: %s" % event_type.capitalize()
		var msg := "Seviye: %s, Süre: %d gün" % [level_name, dur]
		if event_type == "raid" and ev.has("raid_attack_day"):
			var days_until = ev["raid_attack_day"] - day
			var attacker = ev.get("raid_attacker", "Bilinmeyen Haydutlar")
			msg = "%s saldırısı %d gün sonra bekleniyor! Askerlerinizi hazırlayın!" % [attacker, days_until]
			title = "🚨 Baskın Uyarısı!"
		elif event_type == "worker_strike" and ev.has("strike_resource"):
			var res_names: Dictionary = {"wood": "Odun", "stone": "Taş", "food": "Yiyecek", "water": "Su"}
			var reason_names: Dictionary = {"düşük_moral": "Düşük Moral", "kaynak_eksikliği": "Kaynak Eksikliği", "genel_hoşnutsuzluk": "Genel Hoşnutsuzluk"}
			msg = "%s - %s üretimi durdu (%s)" % [msg, res_names.get(ev["strike_resource"], ev["strike_resource"]), reason_names.get(ev.get("strike_reason", ""), "")]
		mm.post_news("world", title, msg, Color.ORANGE)
	
	events_active.append(ev)
	_apply_event_effects(ev)
	return true

func _recalculate_building_bonus() -> void:
	# Compute average bonus across basic producer buildings: +0.25 per level above 1, capped at +0.5
	var placed := 0
	var bonus_sum := 0.0
	if is_instance_valid(village_scene_instance):
		var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
		if placed_buildings:
			for b in placed_buildings.get_children():
				if not is_instance_valid(b):
					continue
				# Only consider known producers
				var is_producer := false
				for r in ["wood", "stone", "food", "water"]:
					if b.has_method("get_script") and b.get_script() != null and b.get_script().resource_path == String(RESOURCE_PRODUCER_SCRIPTS.get(r, "")):
						is_producer = true
						break
				if not is_producer:
					continue
				var lvl := 1
				if "level" in b and b.level != null:
					lvl = int(b.level)
				if lvl > 1:
					bonus_sum += 0.25 * float(lvl - 1)
				placed += 1
	var avg_bonus := 0.0
	if placed > 0:
		avg_bonus = bonus_sum / float(placed)
	building_bonus = clamp(avg_bonus, 0.0, 0.5)

# === Weekly cariye need helpers ===
func get_days_until_weekly_cariye_needs() -> int:
	if cariye_period_days <= 0:
		return 0
	var tm = get_node_or_null("/root/TimeManager")
	var day: int = tm.get_day() if tm and tm.has_method("get_day") else 0
	if day <= 0:
		return cariye_period_days
	var r := day % cariye_period_days
	return 0 if r == 0 else cariye_period_days - r

func get_next_weekly_cariye_day() -> int:
	var tm = get_node_or_null("/root/TimeManager")
	var day: int = tm.get_day() if tm and tm.has_method("get_day") else 0
	return day + get_days_until_weekly_cariye_needs()

# Yeni bir işçi düğümü oluşturur, ID atar, listeye ekler, sayacı günceller ve barınak atar.
# Başarılı olursa true, barınak bulunamazsa veya hata olursa false döner.


func _add_new_worker(NPC_Info = {}) -> bool: # <<< Dönüş tipi eklendi
	if not worker_scene:
		#printerr("VillageManager: Worker scene not loaded!")
		return false
	
	var worker_instance = worker_scene.instantiate()
	worker_id_counter += 1
	worker_instance.worker_id = worker_id_counter
	worker_instance.name = "Worker" + str(worker_id_counter) 
	
	# <<< YENİ: Rastgele Görünüm Ata >>>
	if worker_instance.has_method("update_visuals"): # Önce metodun varlığını kontrol et (güvenlik)
		worker_instance.appearance = AppearanceDB.generate_random_appearance()
	#else:
		#printerr("VillageManager: Worker instance does not have 'update_visuals' method!")
	# <<< YENİ SONU >>>

	# <<< GÜNCELLENDİ: Önce WorkersContainer'a ekle, sonra barınak ataması yap >>>
	# Worker'ı önce WorkersContainer'a ekle (housing atamasından önce)
	if not workers_container:
		#printerr("VillageManager: WorkersContainer not found! Cannot add worker to scene.")
		worker_instance.queue_free() # Oluşturulan instance'ı sil
		return false # Başarısız
	
	workers_container.add_child(worker_instance)
	
	# Barınak atamaya çalış (bu fonksiyon housing_node ve start_x_pos ayarlar)
	# Worker artık WorkersContainer'da olduğu için housing sadece referans tutacak
	if not _assign_housing(worker_instance):
		#printerr("VillageManager: Yeni işçi (ID: %d) İÇİN BARINAK BULUNAMADI, işçi eklenmiyor." % worker_id_counter) 
		worker_instance.queue_free() # Oluşturulan instance'ı sil
		# ID sayacını geri almalı mıyız? Şimdilik almıyoruz, ID'ler atlanmış olacak.
		return false # Başarısız

	# Barınak bulunduysa initialize et ve listeye ekle
	worker_instance.Initialize_Existing_Villager(NPC_Info)
		
	# Yeni işçiyi listeye ekle (Sadece sahneye eklendiyse)
	var worker_data = {
		"instance": worker_instance,
		"status": "idle", 
		"assigned_building": null,
		"housing_node": worker_instance.housing_node # _assign_housing tarafından ayarlandı
	}
	all_workers[worker_id_counter] = worker_data

	# Toplam ve boştaki işçi sayısını güncelle
	total_workers += 1
	idle_workers += 1
	
	#print("VillageManager: Yeni işçi (ID: %d) eklendi ve barınağa atandı." % worker_id_counter)
	
	# <<< YENİ: Test için Walk Animasyonunu Başlat >>>
	# Normalde bu _physics_process'te state'e göre belirlenir,
	# ama şimdi test için doğrudan başlatalım.
	if worker_instance.has_method("play_animation"):
		worker_instance.play_animation("walk")
	# <<< YENİ SONU >>>
	
	# WorkerAssignmentUI'yi güncellemek için sinyal gönder
	emit_signal("worker_list_changed")
	return true # Başarılı

# Tüccar listesi değiştiğinde köydeki tüccar sprite'larını senkronize et (girme / bekleme / çıkma)
func _sync_trader_npcs() -> void:
	if not is_instance_valid(traders_container):
		return
	var mm = get_node_or_null("/root/MissionManager")
	if not mm or not mm.has_method("get_active_traders"):
		return
	var active = mm.get_active_traders()
	var active_ids: Dictionary = {}
	for t in active:
		var tid = t.get("id", "")
		if tid.is_empty():
			continue
		active_ids[tid] = true
		if not trader_npc_by_id.has(tid):
			var npc = TraderVillageNPCScene.instantiate()
			if npc.has_method("setup"):
				npc.setup(tid, TRADER_ENTRY_X, TRADER_CENTER_X, TRADER_EXIT_X, TRADER_CENTER_Y)
			npc.trader_id = tid
			traders_container.add_child(npc)
			trader_npc_by_id[tid] = npc
	for tid in trader_npc_by_id.keys():
		if not active_ids.has(tid):
			var npc = trader_npc_by_id[tid]
			trader_npc_by_id.erase(tid)
			if is_instance_valid(npc) and npc.has_method("start_leaving"):
				npc.start_leaving()
		elif not is_instance_valid(trader_npc_by_id[tid]):
			trader_npc_by_id.erase(tid)

# Cariyeleri sahneye ekle
func _spawn_concubines_in_scene() -> void:
	if not concubine_scene:
		printerr("VillageManager: Concubine scene not loaded!")
		return
	
	if not concubines_container:
		printerr("VillageManager: ConcubinesContainer not found!")
		return
	
	# MissionManager'dan cariyeleri al
	var mission_manager = get_node_or_null("/root/MissionManager")
	if not mission_manager:
		printerr("VillageManager: MissionManager not found!")
		return
	
	# MissionManager'dan concubines dictionary'sini al
	var concubines_dict = mission_manager.concubines
	
	# Debug: Kaç tane cariye var?
	print("VillageManager: MissionManager'da %d cariye bulundu." % concubines_dict.size())
	
	# Zaten sahneye eklenmiş cariyeleri kontrol et ve görünümlerini güncelle
	var existing_concubine_ids = {}
	var existing_concubine_instances = {}
	for child in concubines_container.get_children():
		# concubine_id property'sini kontrol et (get() null dönerse property yok demektir)
		var child_id = child.get("concubine_id")
		if child_id != null:
			existing_concubine_ids[child_id] = true
			existing_concubine_instances[child_id] = child
	
	print("VillageManager: Sahneye zaten eklenmiş %d cariye var." % existing_concubine_ids.size())
	
	# Mevcut cariyelerin görünümlerini güncelle (sadece appearance yoksa)
	for concubine_id in existing_concubine_ids:
		if concubine_id in concubines_dict:
			var concubine_data: Concubine = concubines_dict[concubine_id]
			var existing_instance = existing_concubine_instances[concubine_id]
			if concubine_data and existing_instance:
				# Mevcut appearance'ı kullan (save'den yüklenmiş olmalı)
				if concubine_data.appearance == null:
					printerr("VillageManager: Cariye (ID: %d) görünümü null! Save/load sisteminde sorun var. Geçici görünüm oluşturuluyor." % concubine_id)
					# Geçici çözüm: Görünüm null ise yeni görünüm oluştur (ama bu her load'da farklı görünümlere neden olabilir)
					concubine_data.appearance = AppearanceDB.generate_random_concubine_appearance()
					existing_instance.appearance = concubine_data.appearance
					if existing_instance.has_method("update_visuals"):
						existing_instance.update_visuals()
				else:
					# Mevcut appearance'ı kullan (save'den yüklenmiş)
					existing_instance.appearance = concubine_data.appearance
					if existing_instance.has_method("update_visuals"):
						existing_instance.update_visuals()
					# İsmi güncelle
					if existing_instance.has_method("update_concubine_name"):
						existing_instance.update_concubine_name()
	
	# Her cariye için sahneye ekle (sadece daha önce eklenmemişse)
	var spawned_count = 0
	for concubine_id in concubines_dict:
		# Eğer bu ID'ye sahip bir cariye zaten varsa, atla
		if concubine_id in existing_concubine_ids:
			continue
		
		var concubine_data: Concubine = concubines_dict[concubine_id]
		if not concubine_data:
			continue
		
		# Cariye NPC'sini oluştur
		var concubine_instance = concubine_scene.instantiate()
		concubine_instance.name = "Concubine" + str(concubine_id)
		
		# Cariye ID'sini ve verisini ata
		concubine_instance.concubine_id = concubine_id
		concubine_instance.concubine_data = concubine_data
		
		# İsmi güncelle
		if concubine_instance.has_method("update_concubine_name"):
			concubine_instance.update_concubine_name()
		
		# Görünüm bilgisini ata (save'den yüklenmiş olmalı)
		if concubine_data.appearance == null:
			printerr("VillageManager: Yeni spawn edilen cariye (ID: %d) görünümü null! Save/load sisteminde sorun var. Geçici görünüm oluşturuluyor." % concubine_id)
			# Geçici çözüm: Görünüm null ise yeni görünüm oluştur (ama bu her load'da farklı görünümlere neden olabilir)
			concubine_data.appearance = AppearanceDB.generate_random_concubine_appearance()
			concubine_instance.appearance = concubine_data.appearance
		else:
			concubine_instance.appearance = concubine_data.appearance  # Mevcut appearance'ı kullan
		
		# Görünümü güncelle
		if concubine_instance.has_method("update_visuals"):
			concubine_instance.update_visuals()
		
		# Rastgele pozisyon ayarla (köy içinde)
		var random_x = randf_range(-200, 200)
		var random_y = randf_range(-50, 50)
		concubine_instance.global_position = Vector2(random_x, random_y)
		
		# Container'a ekle
		concubines_container.add_child(concubine_instance)
		spawned_count += 1
		
		print("VillageManager: Cariye (ID: %d, Name: %s) sahneye eklendi." % [concubine_id, concubine_data.name])
	
	print("VillageManager: Toplam %d yeni cariye sahneye eklendi." % spawned_count)
	
	# Ormandan dönüş vb. sahne yüklemesinde: MissionManager'da hâlâ görevde olan cariyeleri
	# ekran dışında tut (ON_MISSION + visible = false). Deferred ile tüm _ready tamamlansın.
	call_deferred("_sync_concubines_on_mission")

func _sync_concubines_on_mission() -> void:
	if not concubines_container:
		return
	var mm = get_node_or_null("/root/MissionManager")
	if not mm or not ("active_missions" in mm):
		return
	var active = mm.get("active_missions")
	if not (active is Dictionary) or active.is_empty():
		return
	for child in concubines_container.get_children():
		var cid = child.get("concubine_id")
		if cid == null:
			continue
		var cid_int := int(cid)
		if cid_int < 0 or not active.has(cid_int):
			continue
		child.set("current_state", 4)  # ConcubineNPC.State.ON_MISSION = 4
		child.visible = false
		if child.has_method("get") and child.get("_wander_timer"):
			var wt = child.get("_wander_timer")
			if wt and wt.has_method("stop"):
				wt.stop()
		print("VillageManager: Cariye (ID: %d) görevde senkronize edildi (sahne dışında)." % cid_int)

# Verilen işçiye uygun bir barınak bulup atar ve evin sayacını günceller
func _assign_housing(worker_instance: Node2D) -> bool:
	var housing_node = _find_available_housing()
	if housing_node:
		worker_instance.housing_node = housing_node
		
		# Yerleşme pozisyonunu ayarla (sol/sağ kenar)
		var viewport_width = get_tree().root.get_viewport().get_visible_rect().size.x
		if housing_node.global_position.x < viewport_width / 2:
			worker_instance.start_x_pos = -2500 # Sol kenar
		else:
			worker_instance.start_x_pos = 2500  # Sağ kenar
		
		# İlgili barınağın doluluk sayısını artır
		if housing_node.has_method("add_occupant"):
			if not housing_node.add_occupant(worker_instance):
				printerr("VillageManager: Failed to add occupant to %s. Housing might be full despite find_available_housing passing." % housing_node.name)

				# Bu durumda ne yapılmalı? Belki işçiyi kamp ateşine atamayı dene?
				# Şimdilik sadece hata verelim.
				return false # Atama başarısız
		else:
			#printerr("VillageManager: Housing node %s does not have add_occupant method!" % housing_node.name)
			return false # Atama başarısız
		
		return true
	else:
		# #printerr("VillageManager: No available housing found for %s." % worker_instance.name) # Hata mesajını _add_new_worker'da veriyoruz
		return false

# Housing key'e göre housing node'u bulur (kayıt/yükleme için)
func _find_housing_by_key(housing_key: String) -> Node2D:
	if housing_key.is_empty():
		return null
	
	# Key'i parse et: "scene_path|position"
	var parts = housing_key.split("|")
	if parts.size() < 2:
		return null
	
	var scene_path = parts[0]
	var position_str = parts[1]
	
	# Position'ı Vector2'ye çevir
	var pos_parts = position_str.replace("(", "").replace(")", "").split(",")
	if pos_parts.size() < 2:
		return null
	var pos = Vector2(float(pos_parts[0]), float(pos_parts[1]))
	
	# Housing node'ları bul (Housing grubundaki tüm node'lar)
	var housing_nodes = get_tree().get_nodes_in_group("Housing")
	for node in housing_nodes:
		if node is Node2D:
			var node2d = node as Node2D
			# Pozisyon ve scene path'e göre eşleştir
			var node_scene = node2d.scene_file_path if node2d.scene_file_path != "" else "res://village/scenes/CampFire.tscn"
			if node_scene == scene_path or (scene_path == "res://village/scenes/CampFire.tscn" and node.is_in_group("Housing")):
				# Pozisyon yakınsa (10 piksel tolerans) eşleştir
				if node2d.global_position.distance_to(pos) < 10.0:
					return node2d
	
	return null

# Boş kapasitesi olan bir barınak (önce Ev, sonra CampFire) arar
func _find_available_housing() -> Node2D:
	# #print("DEBUG VillageManager: Searching for available housing...") #<<< Yorumlandı
	var housing_nodes = get_tree().get_nodes_in_group("Housing")
	# #print("DEBUG VillageManager: Found %d nodes in Housing group." % housing_nodes.size()) #<<< Yorumlandı

	# Önce Evleri kontrol et
	for node in housing_nodes:
		# #print("DEBUG VillageManager: Checking node: %s" % node.name) #<<< Yorumlandı
		# <<< DEĞİŞTİRİLDİ: Sadece House ise kapasiteyi kontrol et >>>
		if node.has_method("get_script") and node.get_script() == HouseScript:
			# print("DEBUG VillageManager:   Node is House. Checking capacity (%d/%d)" % [node.current_occupants, node.max_occupants]) #<<< Yorumlandı
			if node.can_add_occupant():
				# print("DEBUG VillageManager:   Found available House: %s. Returning this node." % node.name) #<<< Yorumlandı

				return node # Boş ev bulundu
			# else: # Ev doluysa (debug için)
				# #print("DEBUG VillageManager:   House %s is full." % node.name) #<<< Yorumlandı
		# <<< DEĞİŞİKLİK SONU >>>
		# else: # Eğer scripti HouseScript değilse (örn. CampFire) veya scripti yoksa, bu döngüde atla
			# #print("DEBUG VillageManager:   Node %s is not a House, skipping capacity check in this loop." % node.name) # Debug
			# pass # Bu else bloğu artık gereksiz

	# Boş ev yoksa, CampFire'ı kontrol et (varsa)
	# #print("DEBUG VillageManager: No available house found. Checking for CampFire...") #<<< Yorumlandı
	# campfire_node referansı _ready veya register_village_scene içinde set edilmiş olmalı
	if is_instance_valid(campfire_node) and campfire_node.is_in_group("Housing"):
		# #print("DEBUG VillageManager:   Found valid CampFire: %s. Returning this node." % campfire_node.name) #<<< Yorumlandı
		# <<< YENİ: Campfire kapasitesini kontrol et >>>
		if campfire_node.can_add_occupant():
			# print("DEBUG VillageManager:   Found available CampFire: %s. Returning this node." % campfire_node.name) #<<< Yorumlandı

			return campfire_node
		# else: # Kamp ateşi doluysa
		# 	# #print("DEBUG VillageManager:   Campfire is full.") #<<< Yorumlandı
		# 	pass
		# <<< YENİ SONU >>>
	# else: # Debug için
		# #print("DEBUG VillageManager:   Campfire node is not valid or not in Housing group.") #<<< Yorumlandı

	# Hiçbir barınak bulunamadı
	# #printerr("VillageManager Warning: No available housing found (No suitable House or CampFire).") # Bu mesajı artık burada vermeyebiliriz, çağıran yer kontrol etmeli.
	return null

# --- İşçi Atama/Çıkarma (Mevcut Fonksiyonlar) --- # Burası olduğu gibi kalacak

# Boşta bir işçiyi belirtilen TEMEL iş türüne ve ilgili binaya atar #<<< GÜNCELLENDİ
func assign_idle_worker_to_job(job_type: String) -> bool:
	var idle_worker_instance: Node = null
	var idle_worker_id = -1

	# 1. Boşta bir işçi bul
	for worker_id in all_workers:
		var worker = all_workers[worker_id]["instance"]
		if is_instance_valid(worker) and worker.assigned_job_type == "":
			# HASTA KONTROLÜ: Hasta işçiler atanamaz
			if "is_sick" in worker and worker.is_sick:
				continue
			
			idle_worker_instance = worker
			idle_worker_id = worker_id
			break # İlk boşta işçiyi bulduk

	if idle_worker_instance == null:
		#print("VillageManager: assign_idle_worker_to_job - Boşta işçi bulunamadı.")
		return false

	# 2. İşe uygun binayı bul
	var building_node: Node2D = null
	var target_script_path = RESOURCE_PRODUCER_SCRIPTS.get(job_type) 
	if not target_script_path:
		#printerr("VillageManager: assign_idle_worker_to_job - Bilinmeyen iş türü veya script yolu yok: ", job_type)
		return false

	# <<< YENİ KONTROL: Bu fonksiyon sadece TEMEL kaynaklar için! >>>
	# Bakery.gd gibi gelişmiş üreticiler kendi add_worker metodunu kullanmalı.
	if target_script_path == "res://village/scripts/Bakery.gd": # Şimdilik sadece Bakery için kontrol
		#printerr("VillageManager Error: assign_idle_worker_to_job cannot be used for advanced resource '%s'. Call Bakery.add_worker() directly." % job_type)
		return false
	# TODO: Daha genel bir kontrol (örn. BASE_RESOURCE_SCRIPTS listesi ile)
	# if not target_script_path in BASE_RESOURCE_SCRIPTS: ...
	# <<< KONTROL SONU >>>

	var work_buildings = get_tree().get_nodes_in_group("WorkBuildings")
	for building in work_buildings:
		# Binanın script yolunu kontrol et
		if building.has_method("get_script") and building.get_script() != null:
			var building_script = building.get_script()
			if building_script is GDScript and building_script.resource_path == target_script_path:
				# TODO: Binanın kapasitesini kontrol et (max_workers)
				# if building.assigned_workers < building.max_workers: 
				building_node = building
				break # İlk uygun binayı bulduk

	if building_node == null:
		#print("VillageManager: assign_idle_worker_to_job - İşe uygun bina bulunamadı (İnşa edilmemiş veya kapasite dolu?): ", job_type)
		return false

	# 3. Atamayı yap
	idle_worker_instance.assigned_job_type = job_type
	idle_worker_instance.assigned_building_node = building_node
	
	# İlgili binanın da işçi sayısını artır (eğer takip ediyorsa)
	building_node.assigned_workers += 1
	notify_building_state_changed(building_node) # Binanın durumunu güncelle (UI için önemli)

	idle_workers -= 1
	#print("VillageManager: İşçi %d, '%s' işine (%s) atandı." % [idle_worker_id, job_type, building_node.name])
	# emit_signal("village_data_changed") # Zaten _process ile güncelleniyor
	
	return true # Fonksiyonun ana bloğuna geri çek

# Belirtilen iş türüne atanmış bir işçiyi işten çıkarır (idle yapar)
func unassign_worker_from_job(job_type: String) -> bool:
	var assigned_worker_instance: Node = null
	var assigned_worker_id = -1
	var building_node: Node2D = null # İşçinin çalıştığı bina

	# 1. Bu işe atanmış bir işçi bul
	for worker_id in all_workers:
		var worker = all_workers[worker_id]["instance"]
		if is_instance_valid(worker) and worker.assigned_job_type == job_type:
			assigned_worker_instance = worker
			assigned_worker_id = worker_id
			building_node = worker.assigned_building_node # Çalıştığı binayı kaydet
			break # İlk eşleşen işçiyi bulduk

	if assigned_worker_instance == null:
		#print("VillageManager: unassign_worker_from_job - '%s' işine atanmış işçi bulunamadı." % job_type)
		return false

	# 2. Atamayı kaldır
	assigned_worker_instance.assigned_job_type = ""
	assigned_worker_instance.assigned_building_node = null
	
	# İşçinin mevcut durumunu IDLE yapalım (eğer çalışıyorsa)
	if assigned_worker_instance.current_state == assigned_worker_instance.State.WORKING_OFFSCREEN or \
	   assigned_worker_instance.current_state == assigned_worker_instance.State.GOING_TO_BUILDING_FIRST or \
	   assigned_worker_instance.current_state == assigned_worker_instance.State.GOING_TO_BUILDING_LAST:
		assigned_worker_instance.current_state = assigned_worker_instance.State.AWAKE_IDLE
		assigned_worker_instance.visible = true # Görünür yap
		# Hedefini sıfırla veya rastgele yap
		assigned_worker_instance.move_target_x = assigned_worker_instance.global_position.x 

	# İlgili binanın işçi sayısını azalt (eğer takip ediyorsa ve hala geçerliyse)
	if is_instance_valid(building_node) and "assigned_workers" in building_node:
		building_node.assigned_workers = max(0, building_node.assigned_workers - 1)
		notify_building_state_changed(building_node) # Binanın durumunu güncelle

	idle_workers += 1
	#print("VillageManager: İşçi %d, '%s' işinden çıkarıldı." % [assigned_worker_id, job_type])
	# emit_signal("village_data_changed") # Zaten _process ile güncelleniyor
	return true

# --- YENİ: Köylü Eksiltme Mekaniği ---
func remove_worker_from_village(worker_id_to_remove: int) -> void:
	#print("VillageManager: Attempting to remove worker %d" % worker_id_to_remove) # Debug

	# 1. İşçi listede var mı ve geçerli mi?
	if not all_workers.has(worker_id_to_remove):
		#printerr("VillageManager Error: Worker %d not found in active_workers." % worker_id_to_remove)
		return
		
	var worker_instance = all_workers[worker_id_to_remove]["instance"]
	if not is_instance_valid(worker_instance):
		#printerr("VillageManager Warning: Worker %d instance is invalid. Removing from list." % worker_id_to_remove)
		all_workers.erase(worker_id_to_remove) # Listeyi temizle
		# Sayaçları burada azaltmak riskli olabilir, belki zaten azalmıştır.
		return

	# 2. Barınaktan Çıkar (Eğer Ev veya CampFire İse)
	var housing = worker_instance.housing_node
	if is_instance_valid(housing):
		# Debug: Only log errors
		# print("VillageManager: Removing worker %d from housing %s" % [worker_id_to_remove, housing.name])
		
		if housing.has_method("remove_occupant"):
			# CampFire ve House için worker instance'ı geç (her ikisi de kabul ediyor)
			var success = false
			if housing.get_script() and housing.get_script().resource_path.ends_with("CampFire.gd"):
				# CampFire için worker instance'ı geç
				success = housing.remove_occupant(worker_instance)
			else:
				# House için de worker instance'ı geç (artık kabul ediyor)
				success = housing.remove_occupant(worker_instance)
			
			# remove_occupant artık her zaman true döner (worker listede yoksa bile normal)
			# if not success:
			# 	printerr("VillageManager: Failed to remove worker %d from housing %s" % [worker_id_to_remove, housing.name])
		else:
			printerr("VillageManager: Housing %s does not have remove_occupant method!" % housing.name)
	#else: # Debug için
	#	print("VillageManager: Worker %d was not in housing (or housing invalid)." % worker_id_to_remove)

	
	# 3. İşten Çıkar (Eğer Çalışıyorsa)
	var job_type = worker_instance.assigned_job_type
	var was_idle = (job_type == "") # İşçi boştaydıysa bunu kaydet
	
	if not was_idle:
		#print("VillageManager: Worker %d was working (%s). Unassigning from building." % [worker_id_to_remove, job_type]) # Debug
		var building = worker_instance.assigned_building_node
		if is_instance_valid(building):
			# Building'den worker'ı çıkar (eğer Barracks ise assigned_worker_ids listesinden de çıkar)
			if building.has_method("get_military_force"):  # Barracks
				# Barracks'taki listeden çıkar (eğer henüz çıkarılmadıysa)
				if "assigned_worker_ids" in building:
					var worker_ids = building.get("assigned_worker_ids")
					if worker_ids is Array and worker_id_to_remove in worker_ids:
						var idx = worker_ids.find(worker_id_to_remove)
						if idx >= 0:
							worker_ids.remove_at(idx)
							print("[VillageManager] Worker %d Barracks listesinden çıkarıldı" % worker_id_to_remove)
				
				# Barracks'taki assigned_workers sayısını azalt
				if "assigned_workers" in building:
					building.assigned_workers = max(0, building.assigned_workers - 1)
					print("[VillageManager] Barracks assigned_workers azaltıldı: %d" % building.assigned_workers)
			else:
				# Diğer binalar için
				if "assigned_workers" in building:
					building.assigned_workers = max(0, building.assigned_workers - 1)
					notify_building_state_changed(building)
		#else: # Debug için
		#	#print("VillageManager: Building node for worker %d is invalid or lacks 'assigned_workers'." % worker_id_to_remove)

	# 4. Sayaçları Güncelle
	if was_idle:
		idle_workers = max(0, idle_workers - 1) # Boştaysa idle sayısını azalt
		# #print("DEBUG: Decremented idle_workers.") # Debug
	# else: # Debug için
		# #print("DEBUG: Worker was not idle, idle_workers not decremented.")
	total_workers = max(0, total_workers - 1)
	# #print("DEBUG: Total workers: %d, Idle workers: %d" % [total_workers, idle_workers]) # Debug

	# 5. Listeden Sil
	all_workers.erase(worker_id_to_remove)
	
	# 6. Sahneden Sil
	worker_instance.queue_free()
	
	#print("VillageManager: Worker %d successfully removed from the village." % worker_id_to_remove)
	# İsteğe bağlı: UI güncellemesi için sinyal yay
	# emit_signal("village_data_changed") # Zaten periyodik güncelleniyor

# --- WorldManager Defense Sinyalleri ---
func _on_defense_deployment_started(attack_day: int) -> void:
	"""Askerlerin savaşa deploy edilmesi için çağrılır"""
	print("[VillageManager] _on_defense_deployment_started çağrıldı - Saldırı günü: %d" % attack_day)
	# Kışla binasını bul ve askerleri deploy et
	var barracks = _find_barracks()
	if not barracks:
		print("[VillageManager] ❌ Kışla bulunamadı!")
		return
	
	if not barracks.has_method("deploy_soldiers"):
		print("[VillageManager] ❌ Kışla deploy_soldiers metoduna sahip değil!")
		return
	
	print("[VillageManager] ✅ Kışla bulundu, deploy_soldiers çağrılıyor...")
	barracks.deploy_soldiers()

func _on_defense_battle_completed(victor: String, losses: int) -> void:
	"""Savaş bitince askerlerin geri çağrılması için çağrılır"""
	# Kışla binasını bul ve askerleri geri çağır
	var barracks = _find_barracks()
	if barracks and barracks.has_method("recall_soldiers"):
		barracks.recall_soldiers()

func _on_battle_story_generated(story: String, battle_data: Dictionary) -> void:
	"""Handle generated battle story from WorldManager"""
	print("[VillageManager] Battle story generated:")
	print(story)
	# You can add logic here to display the story in UI, save it, or post it as news
	# For example, you could post it as a news item:
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("post_news"):
		var attacker_faction = battle_data.get("attacker_faction", "Unknown")
		var day = battle_data.get("day", 0)
		mm.post_news("Dünya", "⚔️ Battle Report - Day %d" % day, story, Color.ORANGE, "battle")

func _find_barracks() -> Node:
	"""Kışla binasını bul"""
	if not village_scene_instance:
		print("[VillageManager] _find_barracks: village_scene_instance null!")
		return null
	
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		print("[VillageManager] _find_barracks: PlacedBuildings node bulunamadı!")
		return null
	
	var building_count = placed_buildings.get_child_count()
	print("[VillageManager] _find_barracks: %d bina kontrol ediliyor..." % building_count)
	
	for building in placed_buildings.get_children():
		if building.has_method("get_military_force"):  # Barracks-specific method
			print("[VillageManager] _find_barracks: ✅ Kışla bulundu: %s" % building.name)
			return building
	
	print("[VillageManager] _find_barracks: ❌ Kışla bulunamadı!")
	return null

# --- Helper Fonksiyonlar ---
func get_active_worker_ids() -> Array[int]:
	# return all_workers.keys() #<<< ESKİ KOD: Genel Array döndürüyor
	var keys_array: Array[int] = [] #<<< YENİ: Tip belirterek boş dizi oluştur
	for key in all_workers.keys(): #<<< YENİ: Anahtarlar üzerinde döngü
		keys_array.append(key) #<<< YENİ: Tipi belli diziye ekle
	return keys_array #<<< YENİ: Tipi belli diziyi döndür

# PlacedBuildings node'unu kaydeder (VillageScene _ready tarafından çağrılır)

# <<< YENİ FONKSİYON: cancel_worker_registration >>>
# Başarısız bir işçi atama girişiminden sonra (örn. kaynak yetersizliği),
# register_generic_worker tarafından azaltılan idle_workers sayacını geri artırır.
func cancel_worker_registration() -> void:
	# #print("VillageManager: Canceling previous worker registration attempt, incrementing idle_workers.") #<<< KALDIRILDI
	idle_workers += 1
	emit_signal("village_data_changed") # <<< Girinti Düzeltildi
# <<< YENİ FONKSİYON BİTİŞ >>>



# Belirli bir kaynak türünü üreten ilk binanın pozisyonunu döndürür
# (Kaynak Taşıma İllüzyonu için)
func get_source_building_position(resource_type: String) -> Vector2:
	# <<< DÜZELTİLDİ: Doğrudan dictionary lookup >>>
	# Kaynak türünü hangi scriptlerin ürettiğini bul
	var target_script_path = RESOURCE_PRODUCER_SCRIPTS.get(resource_type, "")
	# <<< DÜZELTME SONU >>>
	
	if target_script_path.is_empty():
		#printerr("VillageManager: No script found producing resource type '%s' for fetching illusion." % resource_type)
		return Vector2.ZERO # Veya null? Şimdilik ZERO
		
	# İlgili script'e sahip tüm düğümleri (binaları) bul
	# ... (rest of the function remains the same: find building instance with this script path) ...
	var potential_buildings = []
	# Varsayım: Tüm binalar village_scene altında
	if is_instance_valid(village_scene_instance):
		# <<< YENİ: PlacedBuildings altını kontrol et (daha güvenli) >>>
		var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
		if placed_buildings:
			for child in placed_buildings.get_children(): # Sadece yerleştirilmiş binalara bak
				if child.has_method("get_script") and child.get_script() != null and child.get_script().resource_path == target_script_path:
					potential_buildings.append(child)
		else:
			#printerr("VillageManager: PlacedBuildings node not found in VillageScene.")
			return Vector2.ZERO
		# <<< YENİ SONU >>>
	else:
		#printerr("VillageManager: VillageScene invalid, cannot search for source buildings.")
		return Vector2.ZERO
	
	# Bulunan ilk binanın pozisyonunu döndür
	if not potential_buildings.is_empty():
		var target_building = potential_buildings[0]
		# #print("VillageManager: Found source building %s for %s at %s" % [target_building.name, resource_type, target_building.global_position]) # Debug
		return target_building.global_position
	else:
		#print("VillageManager: No building instance found producing '%s' (script: %s)" % [resource_type, target_script_path])
		return Vector2.ZERO # Uygun bina bulunamadı

func _on_hour_changed(new_hour: int) -> void:
	_apply_time_of_day(new_hour)

func apply_current_time_schedule() -> void:
	var tm = get_node_or_null("/root/TimeManager")
	var hour := 6
	if tm and tm.has_method("get_hour"):
		hour = tm.get_hour()
	_apply_time_of_day(hour)

func _apply_time_of_day(hour: int) -> void:
	var sleep_start := 22
	var wake_hour := 6
	var is_sleep_time := hour >= sleep_start or hour < wake_hour
	
	# Worker'lar için saat kontrolü
	if workers_container != null:
		for child in workers_container.get_children():
			var worker := child as Node2D
			if worker == null:
				continue
			# Önce check_hour_transition çağır (worker kendi state'ini ayarlasın)
			if worker.has_method("check_hour_transition"):
				worker.check_hour_transition(hour)
			
			# Worker'ın state'ine göre görünürlüğü ayarla
			# GOING_TO_SLEEP state'indeyse görünür olmalı (eve yürüyor)
			if worker.has_method("get") and "current_state" in worker:
				var current_state = worker.get("current_state")
				var going_to_sleep_state = 8  # State.GOING_TO_SLEEP
				var sleeping_state = 0  # State.SLEEPING
				var awake_idle_state = 1  # State.AWAKE_IDLE
				var socializing_state = 7  # State.SOCIALIZING
				
				if current_state == going_to_sleep_state:
					# Eve yürüyor, görünür olmalı
					worker.visible = true
					if worker.has_method("set_process"):
						worker.set_process(true)
					if worker.has_method("set_physics_process"):
						worker.set_physics_process(true)
				elif current_state == sleeping_state:
					# Uyuyor, görünmez olmalı
					worker.visible = false
					# Uyanma kontrolü için physics_process'i açık tut (uyanma kontrolü _physics_process içinde yapılıyor)
					# Ama process'i kapatabiliriz (görsel güncelleme gerekmez)
					if worker.has_method("set_process"):
						worker.set_process(false)
					# Physics process'i açık tut ki uyanma kontrolü çalışsın
					if worker.has_method("set_physics_process"):
						worker.set_physics_process(true)
					# Pozisyonu housing'a taşı
					if "housing_node" in worker:
						var housing = worker.get("housing_node")
						if housing and housing is Node2D:
							worker.global_position = (housing as Node2D).global_position
				elif current_state == awake_idle_state or current_state == socializing_state:
					# Uyanık ve boşta, kesinlikle görünür olmalı
					worker.visible = true
					if worker.has_method("set_process"):
						worker.set_process(true)
					if worker.has_method("set_physics_process"):
						worker.set_physics_process(true)
				else:
					# Diğer state'lerde (çalışma, işe gitme vb.) worker'ın kendi görünürlük kontrolüne bırak
					# Ama genel olarak görünür olmalılar (WORKING_INSIDE ve WAITING_OFFSCREEN hariç)
					var working_inside_state = 5  # State.WORKING_INSIDE
					var waiting_offscreen_state = 4  # State.WAITING_OFFSCREEN
					if current_state != working_inside_state and current_state != waiting_offscreen_state:
						worker.visible = true
						if worker.has_method("set_process"):
							worker.set_process(true)
						if worker.has_method("set_physics_process"):
							worker.set_physics_process(true)
			else:
				# Fallback: Eski davranış (sadece uyku saati kontrolü)
				worker.visible = not is_sleep_time
				if worker.has_method("set_process"):
					worker.set_process(not is_sleep_time)
				if worker.has_method("set_physics_process"):
					worker.set_physics_process(not is_sleep_time)
				if is_sleep_time and "housing_node" in worker:
					var housing = worker.get("housing_node")
					if housing and housing is Node2D:
						worker.global_position = (housing as Node2D).global_position
	
	# Cariyeler için saat kontrolü
	if concubines_container != null:
		for child in concubines_container.get_children():
			var concubine := child as Node2D
			if concubine == null:
				continue
			if concubine.has_method("check_hour_transition"):
				concubine.check_hour_transition(hour)

func reset_saved_state_for_new_game() -> void:
	_saved_building_states.clear()
	_saved_worker_states.clear()
	_saved_resource_levels = {}
	_saved_base_production_progress = {}
	_saved_snapshot_time = {}
	_pending_time_skip_notification = {}
	_is_leaving_village = false
	if is_instance_valid(VillagerAiInitializer):
		if VillagerAiInitializer.has_method("reset_to_defaults"):
			VillagerAiInitializer.reset_to_defaults()
		else:
			VillagerAiInitializer.Saved_Villagers.clear()

func _worker_entry_sorter(a, b) -> bool:
	var a_id: int = 0
	var b_id: int = 0
	if a is Dictionary:
		a_id = int(a.get("worker_id", 0))
	if b is Dictionary:
		b_id = int(b.get("worker_id", 0))
	return a_id < b_id

# En yakın NPC'nin ismini göster, diğerlerini gizle
func _update_nearest_npc_name_visibility() -> void:
	# Container'lar yoksa çık
	if not workers_container and not concubines_container:
		return
	
	# Oyuncuyu bul
	var player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		# Oyuncu yoksa tüm isimleri gizle
		_hide_all_npc_names()
		return
	
	var player_pos = player.global_position
	var nearest_npc: Node2D = null
	var nearest_distance: float = INF
	
	# Tüm NPC'leri topla ve en yakını bul
	var all_npcs: Array[Node2D] = []
	
	# Worker'ları ekle
	if workers_container:
		for child in workers_container.get_children():
			if child is Node2D:
				var name_plate_container = child.get_node_or_null("NamePlateContainer")
				if name_plate_container:
					all_npcs.append(child)
	
	# Cariyeleri ekle
	if concubines_container:
		for child in concubines_container.get_children():
			if child is Node2D:
				var name_plate_container = child.get_node_or_null("NamePlateContainer")
				if name_plate_container:
					all_npcs.append(child)
	
	# En yakın NPC'yi bul (maksimum mesafe: num8 etkileşim mesafesiyle aynı - yaklaşık 35 piksel)
	const MAX_NAME_DISTANCE: float = 35.0
	for npc in all_npcs:
		if not is_instance_valid(npc):
			continue
		# NPC görünmezse (uyuyor vb.) atla
		if not npc.visible:
			continue
		var distance = player_pos.distance_to(npc.global_position)
		if distance < nearest_distance and distance <= MAX_NAME_DISTANCE:
			nearest_distance = distance
			nearest_npc = npc
	
	# Tüm NPC'lerin isimlerini gizle
	for npc in all_npcs:
		if not is_instance_valid(npc):
			continue
		var name_plate_container = npc.get_node_or_null("NamePlateContainer")
		if name_plate_container:
			name_plate_container.visible = false
	
	# En yakın NPC'nin ismini göster
	if nearest_npc and is_instance_valid(nearest_npc):
		var name_plate_container = nearest_npc.get_node_or_null("NamePlateContainer")
		if name_plate_container:
			name_plate_container.visible = true

# Tüm NPC isimlerini gizle (oyuncu yoksa)
func _hide_all_npc_names() -> void:
	# Worker'ları gizle
	if workers_container:
		for child in workers_container.get_children():
			if child is Node2D:
				var name_plate_container = child.get_node_or_null("NamePlateContainer")
				if name_plate_container:
					name_plate_container.visible = false
	
	# Cariyeleri gizle
	if concubines_container:
		for child in concubines_container.get_children():
			if child is Node2D:
				var name_plate_container = child.get_node_or_null("NamePlateContainer")
				if name_plate_container:
					name_plate_container.visible = false
