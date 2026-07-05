extends Node

const HOUSE_SCENE_PATH := "res://village/buildings/House.tscn"
const _BuildingUpgradeConfig = preload("res://village/scripts/BuildingUpgradeConfig.gd")
const RESIDENTIAL_EXTENSION_NODE := "ResidentialHousingExtension"
const RESIDENTIAL_MAX_FLOORS := 4
const RESIDENTIAL_CAPACITY_PER_FLOOR := 2
# Dükkan üst kenarının matematiksel Y'sine eklenen piksel miktarı.
# Ev katı görseli tam sprite üst kenarından değil, birkaç piksel aşağıdan başlar;
# bu sabit, dükkan-ev arasındaki görsel boşluğu kapatır.
const RESIDENTIAL_EXTENSION_OVERLAP_PX: float = 10.0
const RESIDENTIAL_BASE_EXCLUDED_SCENES := [
	"res://village/buildings/WoodcutterCamp.tscn",
	"res://village/buildings/StoneMine.tscn",
	"res://village/buildings/HunterGathererHut.tscn",
]

# --- YENİ: Bina Gereksinimleri --- (COSTS yerine REQUIREMENTS)
const BUILDING_REQUIREMENTS = {
	# Katman 1 - Temel kurulum (ilk kaynak binaları bedava)
	"res://village/buildings/WoodcutterCamp.tscn": {"cost": {}},
	"res://village/buildings/StoneMine.tscn": {"cost": {}},
	"res://village/buildings/HunterGathererHut.tscn": {"cost": {}},
	"res://village/buildings/House.tscn": {"cost": {"gold": 12, "wood": 1, "stone": 0}},
	# Katman 2 - İlk işleme
	"res://village/buildings/Sawmill.tscn": {
		"cost": {"gold": 35, "wood": 2, "stone": 1},
		"requires_building": {"res://village/buildings/WoodcutterCamp.tscn": 2},
		"requires_level": {"wood": 2},
	},
	"res://village/buildings/Brickworks.tscn": {
		"cost": {"gold": 35, "wood": 1, "stone": 2},
		"requires_building": {"res://village/buildings/StoneMine.tscn": 2},
		"requires_level": {"stone": 2},
	},
	"res://village/buildings/Bakery.tscn": {
		"cost": {"gold": 45, "wood": 1, "stone": 1},
		"requires_building": {
			"res://village/buildings/HunterGathererHut.tscn": 2,
		},
		"requires_level": {"food": 2},
	},
	# Destek binası
	"res://village/buildings/StorageBuilding.tscn": {
		"cost": {"gold": 80, "wood": 2, "stone": 1},
		"requires_building": {
			"res://village/buildings/WoodcutterCamp.tscn": 2,
			"res://village/buildings/StoneMine.tscn": 2,
		},
	},
	# Katman 3-4 - Uzmanlaşma
	"res://village/buildings/Weaver.tscn": {
		"cost": {"gold": 60, "lumber": 2, "brick": 1},
		"requires_building": {"res://village/buildings/Sawmill.tscn": 2},
		"requires_level": {"lumber": 2},
	},
	"res://village/buildings/Tailor.tscn": {
		"cost": {"gold": 75, "lumber": 2, "brick": 2, "cloth": 1},
		"requires_building": {"res://village/buildings/Weaver.tscn": 2},
		"requires_level": {"cloth": 2},
	},
	"res://village/buildings/TeaHouse.tscn": {
		"cost": {"gold": 65, "lumber": 2, "brick": 1},
		"requires_building": {"res://village/buildings/Bakery.tscn": 2},
		"requires_level": {"bread": 2},
	},
	"res://village/buildings/SoapMaker.tscn": {
		"cost": {"gold": 70, "lumber": 1, "brick": 2},
		"requires_building": {"res://village/buildings/Brickworks.tscn": 2},
		"requires_level": {"brick": 2},
	},
	"res://village/buildings/Blacksmith.tscn": {
		"cost": {"gold": 95, "lumber": 2, "brick": 2, "stone": 1},
		"requires_building": {
			"res://village/buildings/Sawmill.tscn": 2,
			"res://village/buildings/Brickworks.tscn": 2,
		},
		"requires_level": {"lumber": 2, "brick": 2},
	},
	"res://village/buildings/Herbalist.tscn": {
		"cost": {"gold": 85, "lumber": 2, "brick": 2},
		"requires_building": {
			"res://village/buildings/HunterGathererHut.tscn": 2,
		},
		"requires_level": {"food": 3},
	},
	# Silahçı: 1. seviye silah (odun+taş) üretmek için erken kurulabilir olmalı —
	# zırh sistemi kaldırıldı, sadece silah seviyeleri var (bkz. Gunsmith.gd).
	"res://village/buildings/Gunsmith.tscn": {
		"cost": {"gold": 30, "wood": 2, "stone": 1},
		"requires_building": {
			"res://village/buildings/WoodcutterCamp.tscn": 2,
			"res://village/buildings/StoneMine.tscn": 2,
		},
	},
	# Kışla: erken savunma için bilinçli olarak ucuz — ham kaynakla,
	# hiçbir zanaat binası şartı olmadan en baştan kurulabilir.
	"res://village/buildings/Barracks.tscn": {
		"cost": {"gold": 20, "wood": 2, "stone": 2},
	},
	"res://village/buildings/InventorWorkshop.tscn": {
		"cost": {"gold": 120, "lumber": 3, "brick": 2},
		"requires_building": {"res://village/buildings/Blacksmith.tscn": 1},
		"requires_level": {"metal": 1},
	},
}

# Test akışı: tüm binaların seviye kilitlerini yok say.
# Maliyet kontrolleri çalışmaya devam eder.
const UNLOCK_ALL_BUILDINGS_FOR_TESTING := false

# --- VillageScene Referansı ---
var village_scene_instance: Node2D = null
## Köydeki aktif oyuncu (NPC diyalogunda UI kilidi için Worker.gd kullanır).
var Village_Player: CharacterBody2D = null

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
	"lumber": 0,
	"brick": 0,
	"metal": 0,
	"cloth": 0,
	"garment": 0,
	"bread": 0,
	"tea": 0,
	"medicine": 0,
	"soap": 0,
	# Silah seviyeleri (zırh sistemi kaldırıldı — bkz. Gunsmith.gd / Barracks.gd)
	"weapon_t1": 5,  # 1. seviye silah (odun+taş) - Başlangıç: 5
	"weapon_t2": 0,  # 2. seviye silah (kereste+tuğla)
	"weapon_t3": 0   # 3. seviye silah (metal+kumaş)
}

# Kaynak SEVİYELERİNİN kilitlenen kısmı (Yükseltmeler ve Gelişmiş Üretim için)
var locked_resource_levels: Dictionary = {
	"wood": 0,
	"stone": 0,
	"food": 0,
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
const BASE_RESOURCE_TYPES := ["wood", "stone", "food"]
const SECONDS_PER_RESOURCE_UNIT := 300.0 # 1 işçi-2saat == 1 kaynak (oyun içi 2 saat = 2 * 2.5 * 60 = 300 gerçek saniye)
var base_production_progress: Dictionary = {
	"wood": 0.0,
	"stone": 0.0,
	"food": 0.0,
}

# Mesafe tabanlı köy işçisi temel kaynak seferleri (orman / dağ / akarsu).
const USE_DISTANCE_BASED_BASIC_GATHER := true
const GATHER_DEPARTURE_HOUR := 8
const GATHER_DEPARTURE_MINUTE := 0
## Mesafe seferi tesliminde varsayılan getiri (odun/taş); yemek ayrı çarpanlı.
const GATHER_DELIVERY_YIELD_DEFAULT := 1
const GATHER_DELIVERY_YIELD_FOOD := 4
## worker_id -> sefer kaydı (delivery_minutes: TimeManager.get_total_game_minutes ile uyumlu mutlak dakika)
var basic_gather_expeditions_by_worker: Dictionary = {}
## worker_id -> son çıkış günü (TimeManager.days ile karşılaştırılır)
var basic_gather_last_departure_day: Dictionary = {}
## Teslim yapıldı; görsel efekt köylü binaya varınca oynatılır (ekran dışı flush'ta değil).
var basic_gather_pending_visual_by_worker: Dictionary = {}
## Depo taşması (gece yarısı çürütülür)
var basic_resource_overflow: Dictionary = {}
var _last_gather_processed_total_minutes: int = -1

var _time_signal_connected: bool = false
var _time_advanced_connected: bool = false
var _last_construction_total_minutes: int = -1
var pending_constructions: Array = []
var reserved_build_plots: Array[Vector2] = []
## Kayıttan yüklenecek inşaat kuyruğu (sahne hazır olunca uygulanır)
var _pending_constructions_load_buffer: Array = []
const MAX_PARALLEL_CONSTRUCTIONS: int = 3
const PARALLEL_BUILD_GOLD_MULT_PER_PENDING: float = 0.12
const PARALLEL_BUILD_GOLD_MULT_MAX: float = 1.48
var _active_upgrade_vfx_ids: Dictionary = {}

const CONSTRUCTION_TIER_BY_SCENE := {
	"res://village/buildings/WoodcutterCamp.tscn": 1,
	"res://village/buildings/StoneMine.tscn": 1,
	"res://village/buildings/HunterGathererHut.tscn": 1,
	"res://village/buildings/House.tscn": 1,
	"res://village/buildings/Sawmill.tscn": 2,
	"res://village/buildings/Brickworks.tscn": 2,
	"res://village/buildings/Bakery.tscn": 2,
	"res://village/buildings/StorageBuilding.tscn": 2,
	"res://village/buildings/Weaver.tscn": 3,
	"res://village/buildings/Tailor.tscn": 3,
	"res://village/buildings/TeaHouse.tscn": 3,
	"res://village/buildings/SoapMaker.tscn": 3,
	"res://village/buildings/Blacksmith.tscn": 4,
	"res://village/buildings/Herbalist.tscn": 4,
	# Silahçı artık erken kurulabildiği için hafif katman
	"res://village/buildings/Gunsmith.tscn": 2,
	"res://village/buildings/Barracks.tscn": 1,
	"res://village/buildings/InventorWorkshop.tscn": 4,
}
const CONSTRUCTION_HOURS_BY_TIER := {1: 1.5, 2: 3.0, 3: 6.0, 4: 10.0, 5: 14.0}
const UPGRADE_BASE_HOURS_BY_TIER := {1: 1.0, 2: 2.0, 3: 4.0, 4: 7.0, 5: 10.0}
const MAX_BUILD_OR_UPGRADE_HOURS := 24.0
const HEALER_CONCUBINE_TREATMENT_COST := {"gold": 35, "medicine": 2}
const GUEST_DEPARTURE_DAYS: int = 1

# Sinyaller
signal village_data_changed
signal resource_produced(resource_type, amount)
signal basic_gather_deposited(worker_id: int, resource_type: String, amount: int, world_position: Vector2)
signal worker_assigned(building_node, resource_type)
signal worker_removed(building_node, resource_type)
signal worker_list_changed  # Worker listesi değiştiğinde UI'yi güncellemek için
signal cariye_data_changed
signal gorev_data_changed
signal building_state_changed(building_node)
signal mission_completed(cariye_id, gorev_id, successful, results)
signal time_skip_completed(total_hours, produced_resources, construction_footnote)
signal morale_game_over  # Köy morali 0'a düştüğünde (oyun kaybı)
signal construction_started(scene_path, total_minutes)
signal construction_completed(scene_path)

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
var _saved_basic_gather_expeditions: Array = []
var _saved_basic_gather_last_departure_day: Dictionary = {}
var _saved_basic_resource_overflow: Dictionary = {}
var _saved_snapshot_time: Dictionary = {}  # Save time when snapshot is taken (day, hour, minute)
var _pending_time_skip_notification: Dictionary = {}  # Pending notification data to show after scene loads
var _campfire_rest_skip_toast: bool = false
var _is_leaving_village: bool = false  # Flag to prevent simulation when leaving village
## advance_minutes() sırasında gece yarısı ekonomi tick'ini simülasyon sonrasına erteler.
var _defer_economy_during_time_advance: bool = false
var _pending_economy_tick_days: Array[int] = []
var _batch_time_advance_connected: bool = false
var _scene_signal_connected: bool = false

## SceneManager: köyden çıkışta yolculuk süresi TimeManager'a yazılmadan hemen önce çağrılır.
## Böylece time_advanced ile _simulate_time_skip (köy üretimi) çift sayılmaz.
func mark_leaving_village_for_travel_out() -> void:
	_is_leaving_village = true

## SceneManager: köye dönüşte _handle_travel_time / simülasyondan hemen önce çağrılır.
func mark_arriving_to_village_from_travel() -> void:
	_is_leaving_village = false

# --- Village Event System ---
var village_events_enabled: bool = true  # Enable/disable village-specific events
var village_daily_event_chance: float = 0.05
var _village_event_cooldowns: Dictionary = {}  # Event type -> day when cooldown ends
var _last_village_event_check_day: int = 0
var _last_village_direct_event_day: int = -9999
const VILLAGE_EVENT_MIN_GAP_DAYS: int = 2
# Note: events_enabled, daily_event_chance, events_active, _event_cooldowns are already defined below

var _skip_next_snapshot: bool = false
var _last_festival_day: int = -9999
var _npc_ambient_director: Node = null

func _ready() -> void:
	_ensure_guest_housing_day_listener()
	_setup_npc_ambient_director()
	_ensure_time_manager_economy_hooks()
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
		_strip_legacy_water_from_resources()
		# Silah seviyeleri kayıtlı veride yoksa varsayılan değer ata (zırh kaldırıldı)
		if not resource_levels.has("weapon_t1"):
			resource_levels["weapon_t1"] = 5
		if not resource_levels.has("weapon_t2"):
			resource_levels["weapon_t2"] = 0
		if not resource_levels.has("weapon_t3"):
			resource_levels["weapon_t3"] = 0
		resource_levels.erase("weapon")
		resource_levels.erase("armor")
	else:
		resource_levels = {
			"wood": 0,
			"stone": 0,
			"food": 0,
			"lumber": 0,
			"brick": 0,
			"metal": 0,
			"cloth": 0,
			"garment": 0,
			"bread": 0,
			"tea": 0,
			"medicine": 0,
			"soap": 0,
			"weapon_t1": 5,
			"weapon_t2": 0,
			"weapon_t3": 0
		}
	
	# Restore production progress if available
	if not _saved_base_production_progress.is_empty():
		base_production_progress = _saved_base_production_progress.duplicate(true)
	else:
		for res in BASE_RESOURCE_TYPES:
			if not base_production_progress.has(res):
				base_production_progress[res] = 0.0
	if USE_DISTANCE_BASED_BASIC_GATHER and not _saved_basic_gather_expeditions.is_empty():
		_deserialize_basic_gather_from_save()
	locked_resource_levels = {
		"wood": 0,
		"stone": 0,
		"food": 0,
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
	# DEBUG cariye/görev üretimi sadece çok eski prototip içindi; gerçek oyunda kullanmayalım.
	# Cariyeler yalnızca zindan kurtarma (add_concubine_from_rescue) akışıyla oluşur.
	# _create_debug_cariyeler()
	# _create_debug_gorevler()
	
	# Connect WorldManager signals
	call_deferred("_connect_world_manager_signals")

func _on_scene_change_started(target_path: String) -> void:
	if not is_instance_valid(SceneManager):
		return
	if SceneManager.current_scene_path != SceneManager.VILLAGE_SCENE:
		return
	# Köy -> köy (reload): PlacedBuildings boşalırken snapshot alma; kayıtlı binalar silinmesin.
	if target_path == SceneManager.VILLAGE_SCENE:
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


## Köyden dünya haritası overlay ile çıkıldığında (ilk kez köy hex'inden ayrılınca SceneManager tetikler).
func prepare_snapshot_for_overlay_world_map_departure() -> void:
	if _is_leaving_village:
		return
	var time_manager := get_node_or_null("/root/TimeManager")
	if time_manager:
		_saved_snapshot_time = {
			"day": time_manager.get_day() if time_manager.has_method("get_day") else 0,
			"hour": time_manager.get_hour() if time_manager.has_method("get_hour") else 0,
			"minute": time_manager.get_minute() if time_manager.has_method("get_minute") else 0
		}
	_is_leaving_village = true
	snapshot_state_for_scene_exit()


func _is_campfire_snapshot_entry(entry: Dictionary) -> bool:
	return bool(entry.get("is_campfire", false))


func _count_production_buildings_in_snapshot(states: Array) -> int:
	var count: int = 0
	for raw in states:
		if raw is Dictionary and not _is_campfire_snapshot_entry(raw):
			var scene_path: String = String((raw as Dictionary).get("scene_path", ""))
			if not scene_path.is_empty():
				count += 1
	return count


func _should_keep_previous_building_snapshot(new_states: Array) -> bool:
	var previous_prod: int = _count_production_buildings_in_snapshot(_saved_building_states)
	if previous_prod <= 0:
		return false
	var new_prod: int = _count_production_buildings_in_snapshot(new_states)
	return new_prod < previous_prod


func _refresh_campfire_snapshot_entry(states: Array) -> void:
	if not is_instance_valid(campfire_node) or not ("max_capacity" in campfire_node):
		return
	var campfire_path: String = (
		campfire_node.scene_file_path
		if campfire_node.scene_file_path != ""
		else "res://village/scenes/CampFire.tscn"
	)
	for i in states.size():
		var entry: Dictionary = states[i]
		if entry is Dictionary and _is_campfire_snapshot_entry(entry):
			entry["max_capacity"] = int(campfire_node.max_capacity)
			states[i] = entry
			return
	states.append({
		"scene_path": campfire_path,
		"position": campfire_node.global_position,
		"global_position": campfire_node.global_position,
		"is_campfire": true,
		"max_capacity": int(campfire_node.max_capacity),
	})


func _collect_building_snapshot_from_scene() -> Array:
	var collected: Array = []
	if not is_instance_valid(village_scene_instance):
		return collected
	var placed_buildings := village_scene_instance.get_node_or_null("PlacedBuildings")
	if not is_instance_valid(placed_buildings):
		return collected
	
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
			var housing_node = _get_or_create_residential_housing_for_building(node2d, false)
			if is_instance_valid(housing_node):
				entry["residential_floors"] = int(housing_node.get_current_floors())
				entry["residential_max_floors"] = int(housing_node.max_floors)
				entry["residential_capacity_per_floor"] = int(housing_node.capacity_per_floor)
			entry["fetch_progress"] = entry.get("fetch_progress", {})
			collected.append(entry)
	
	_refresh_campfire_snapshot_entry(collected)
	return collected


func _job_type_from_building_snapshot_entry(entry: Dictionary) -> String:
	if "produced_resource" in entry:
		var produced: String = String(entry.get("produced_resource", ""))
		if not produced.is_empty():
			return produced
	var scene_path: String = String(entry.get("scene_path", ""))
	for job_type in RESOURCE_PRODUCER_SCENES.keys():
		if scene_path == String(RESOURCE_PRODUCER_SCENES[job_type]):
			return String(job_type)
	return ""


func _enrich_worker_snapshots_from_building_states(worker_states: Array, building_states: Array) -> void:
	for worker_entry in worker_states:
		if not (worker_entry is Dictionary):
			continue
		var worker_id: int = int(worker_entry.get("worker_id", -1))
		if worker_id < 0:
			continue
		var job_type: String = String(worker_entry.get("job_type", ""))
		var building_key: String = String(worker_entry.get("building_key", ""))
		if not job_type.is_empty() and not building_key.is_empty():
			continue
		for building_entry in building_states:
			if not (building_entry is Dictionary) or _is_campfire_snapshot_entry(building_entry):
				continue
			var assigned_ids: Array = building_entry.get("assigned_worker_ids", [])
			if assigned_ids is Array and worker_id in assigned_ids:
				if job_type.is_empty():
					worker_entry["job_type"] = _job_type_from_building_snapshot_entry(building_entry)
				if building_key.is_empty() and building_entry.has("key"):
					worker_entry["building_key"] = String(building_entry.get("key", ""))
				break


func _count_assigned_workers_in_snapshot(states: Array) -> int:
	var count: int = 0
	for raw in states:
		if raw is Dictionary and String((raw as Dictionary).get("job_type", "")) != "":
			count += 1
	return count


func _should_keep_previous_worker_snapshot(new_states: Array) -> bool:
	var previous_assigned: int = _count_assigned_workers_in_snapshot(_saved_worker_states)
	if previous_assigned <= 0:
		return false
	var new_assigned: int = _count_assigned_workers_in_snapshot(new_states)
	return new_assigned < previous_assigned


func _collect_worker_snapshot_entries() -> Array:
	var collected: Array = []
	var worker_ids := all_workers.keys()
	worker_ids.sort()
	for worker_id in worker_ids:
		var worker_data = all_workers.get(worker_id, {})
		if not worker_data:
			continue
		var worker_instance: Node = _worker_node_from_all_workers_entry(worker_id, worker_data, true)
		if worker_instance == null:
			for prev_entry in _saved_worker_states:
				if prev_entry is Dictionary and int(prev_entry.get("worker_id", -1)) == worker_id:
					collected.append((prev_entry as Dictionary).duplicate(true))
					break
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
		
		# Housing node referansını kaydet (kamp ateşi veya konut birimi)
		var housing_key := ""
		var housing_node = worker_instance.get("housing_node") if worker_instance else null
		if is_instance_valid(housing_node) and housing_node is Node2D:
			var housing_scene: String = ""
			if housing_node.has_method("get_housing_snapshot_scene_path"):
				housing_scene = String(housing_node.get_housing_snapshot_scene_path())
			elif housing_node.scene_file_path != "":
				housing_scene = housing_node.scene_file_path
			elif housing_node.get_script() and housing_node.get_script().resource_path.ends_with("CampFire.gd"):
				housing_scene = "res://village/scenes/CampFire.tscn"
			else:
				var housing_parent = housing_node.get_parent()
				if housing_parent is Node2D and (housing_parent as Node2D).scene_file_path != "":
					housing_scene = "%s#housing" % (housing_parent as Node2D).scene_file_path
				else:
					housing_scene = "res://village/buildings/House.tscn#housing"
			housing_key = _make_building_snapshot_key(housing_scene, housing_node.global_position)
		
		# Askerler için is_deployed durumunu kaydet
		var is_deployed_value = false
		if worker_instance and "is_deployed" in worker_instance:
			var deployed_val = worker_instance.get("is_deployed")
			is_deployed_value = deployed_val if deployed_val is bool else false
		
		var is_guest_snap: bool = _is_guest_worker(worker_instance)
		var guest_day_snap: int = -1
		var guest_minutes_snap: int = -1
		if is_guest_snap and "guest_arrival_day" in worker_instance:
			guest_day_snap = int(worker_instance.guest_arrival_day)
		if is_guest_snap and "guest_arrival_total_minutes" in worker_instance:
			guest_minutes_snap = int(worker_instance.guest_arrival_total_minutes)
		var appearance_snap: Dictionary = _worker_appearance_to_dict(worker_instance)
		var worker_entry: Dictionary = {
			"worker_id": worker_id,
			"npc_info": npc_info,
			"job_type": job_type,
			"building_key": building_key,
			"housing_key": housing_key,
			"is_deployed": is_deployed_value,
			"is_guest_villager": is_guest_snap,
			"guest_arrival_day": guest_day_snap,
			"guest_arrival_total_minutes": guest_minutes_snap,
			"appearance": appearance_snap
		}
		collected.append(worker_entry)
	return collected


func snapshot_state_for_scene_exit() -> void:
	var skip_flag: bool = false
	if "_skip_next_snapshot" in self:
		skip_flag = bool(get("_skip_next_snapshot"))
	if skip_flag:
		set("_skip_next_snapshot", false)
		return
	
	if not is_instance_valid(village_scene_instance):
		return

	var previous_buildings: Array = _saved_building_states.duplicate(true)
	var previous_workers: Array = _saved_worker_states.duplicate(true)
	var new_buildings: Array = _collect_building_snapshot_from_scene()
	if _should_keep_previous_building_snapshot(new_buildings):
		_saved_building_states = previous_buildings
		_refresh_campfire_snapshot_entry(_saved_building_states)
		print(
			"[VillageManager] Snapshot: kept previous building state (%d production buildings); scene had %d placed." % [
				_count_production_buildings_in_snapshot(_saved_building_states),
				new_buildings.size()
			]
		)
	else:
		_saved_building_states = new_buildings
	
	# Save resource levels and production progress
	_saved_resource_levels = resource_levels.duplicate(true)
	_saved_base_production_progress = base_production_progress.duplicate(true)
	if USE_DISTANCE_BASED_BASIC_GATHER:
		_serialize_basic_gather_for_save()

	var new_workers: Array = _collect_worker_snapshot_entries()
	_enrich_worker_snapshots_from_building_states(new_workers, _saved_building_states)
	if _should_keep_previous_worker_snapshot(new_workers):
		_saved_worker_states = previous_workers
		_enrich_worker_snapshots_from_building_states(_saved_worker_states, _saved_building_states)
		print(
			"[VillageManager] Snapshot: kept previous worker assignments (%d with jobs)." % [
				_count_assigned_workers_in_snapshot(_saved_worker_states)
			]
		)
	else:
		_saved_worker_states = new_workers
	
	if is_instance_valid(VillagerAiInitializer):
		VillagerAiInitializer.Saved_Villagers.clear()
		for worker_entry in _saved_worker_states:
			var info: Dictionary = worker_entry.get("npc_info", {}).duplicate(true)
			VillagerAiInitializer.Saved_Villagers.append(info)

func _make_building_snapshot_key(scene_path: String, position: Vector2) -> String:
	return "%s|%s" % [scene_path, str(position)]

func _find_building_by_snapshot_key(key: String) -> Node2D:
	if key.is_empty() or not is_instance_valid(village_scene_instance):
		return null
	var placed: Node = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not is_instance_valid(placed):
		return null
	for building in placed.get_children():
		if not building is Node2D:
			continue
		var n := building as Node2D
		var sp := String(n.scene_file_path)
		if sp.is_empty():
			continue
		if _make_building_snapshot_key(sp, n.global_position) == key:
			return n
	return null

func _apply_pending_construction_completion(entry: Dictionary) -> bool:
	var scene_path := String(entry.get("scene_path", ""))
	var pos := Vector2(entry.get("position", Vector2.ZERO))
	if String(entry.get("pending_kind", "")) == "house_floor":
		var host_key := String(entry.get("host_building_key", ""))
		var host := _find_building_by_snapshot_key(host_key)
		if not is_instance_valid(host):
			push_warning("[VillageManager] Ev katı tamamlanamadı: ana bina bulunamadı (%s)" % host_key)
			return false
		var housing := _get_or_create_residential_housing_for_building(host as Node2D, true)
		if not is_instance_valid(housing):
			return false
		return housing.add_floor()
	return place_building(scene_path, pos)

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
	# queue_free() deferred çalıştığından silinen işçiler aynı frame'de
	# hâlâ geçerli görünür. Barınak listelerini şimdi temizle; aksi takdirde
	# hemen ardından çalışan worker yaratma döngüsü "kamp ateşi dolu" hatası alır.
	if get_tree() != null:
		for _h in get_tree().get_nodes_in_group("Housing"):
			if is_instance_valid(_h) and "_occupants" in _h:
				_h._occupants.clear()

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
		if entry.has("residential_floors"):
			var housing_node = _get_or_create_residential_housing_for_building(building_instance as Node2D, true)
			if is_instance_valid(housing_node):
				var saved_max_floors = int(entry.get("residential_max_floors", RESIDENTIAL_MAX_FLOORS))
				var saved_per_floor = int(entry.get("residential_capacity_per_floor", RESIDENTIAL_CAPACITY_PER_FLOOR))
				housing_node.configure_for_host(building_instance as Node2D, int(entry.get("residential_floors", 0)), saved_max_floors, saved_per_floor)
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
		_flush_deferred_economy_ticks()
		_defer_economy_during_time_advance = false
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
	_flush_deferred_economy_ticks()
	_defer_economy_during_time_advance = false

func _on_batch_time_advance_started(_total_minutes: int) -> void:
	_defer_economy_during_time_advance = true
	_pending_economy_tick_days.clear()

func _flush_deferred_economy_ticks() -> void:
	if _pending_economy_tick_days.is_empty():
		return
	_pending_economy_tick_days.sort()
	for day in _pending_economy_tick_days:
		_apply_day_transition_economy(int(day))
	_pending_economy_tick_days.clear()

func _apply_day_transition_economy(new_day: int) -> void:
	if not economy_enabled:
		return
	if new_day <= _last_econ_tick_day:
		return
	_last_econ_tick_day = new_day
	_recalculate_building_bonus()
	_daily_economy_tick(new_day)
	if village_events_enabled and new_day != _last_village_event_check_day:
		_last_village_event_check_day = new_day
		_check_and_trigger_village_event(new_day)

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
	
	var had_pending_construction: bool = not pending_constructions.is_empty()
	
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

	if USE_DISTANCE_BASED_BASIC_GATHER:
		var t_start_abs: int = start_day * TimeManager.HOURS_PER_DAY * TimeManager.MINUTES_PER_HOUR + start_hour * TimeManager.MINUTES_PER_HOUR + start_minute
		var t_end_abs: int = t_start_abs + total_minutes
		_basic_gather_simulate_interval(t_start_abs, t_end_abs)
		_gather_flush_completed_deliveries_up_to(t_end_abs)
		_complete_gather_deliveries_for_time_skip(t_end_abs)
		var tm_gather := get_node_or_null("/root/TimeManager")
		if tm_gather != null and tm_gather.has_method("get_total_game_minutes"):
			_last_gather_processed_total_minutes = int(tm_gather.get_total_game_minutes())
		else:
			_last_gather_processed_total_minutes = t_end_abs

	if not pending_constructions.is_empty():
		_advance_pending_constructions(float(total_minutes))
	var tm_con := get_node_or_null("/root/TimeManager")
	if tm_con != null and tm_con.has_method("get_total_game_minutes"):
		_last_construction_total_minutes = int(tm_con.get_total_game_minutes())
	_finalize_awaiting_construction_placements()
	apply_current_time_schedule()
	_sync_workers_after_time_skip()

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
		var construction_footnote: String = ""
		if had_pending_construction:
			construction_footnote = "Devam eden şantiyeler oyun saatiyle ilerledi; tamamlananlar köye döndüğünde görünür."
		print("[VillageManager] 📢 Emitting time_skip_completed signal: %.1f hours, resources: %s" % [total_hours, produced_resources])
		if not _campfire_rest_skip_toast:
			# Check if village scene is loaded - if not, save notification for later
			if is_instance_valid(village_scene_instance):
				emit_signal("time_skip_completed", total_hours, produced_resources, construction_footnote)
			else:
				# Scene not loaded yet, save notification for when scene loads
				_pending_time_skip_notification = {
					"total_hours": total_hours,
					"produced_resources": produced_resources,
					"construction_footnote": construction_footnote
				}
				print("[VillageManager] ⏸️ Village scene not loaded, saving notification for later: %.1f hours" % total_hours)
	else:
		print("[VillageManager] ⚠️ Not emitting time_skip_completed: total_hours = %.1f" % total_hours)

func _gather_breakdown_total_minutes(t: int) -> Dictionary:
	var rem: int = int(t) % (TimeManager.HOURS_PER_DAY * TimeManager.MINUTES_PER_HOUR)
	var day: int = int(t) / (TimeManager.HOURS_PER_DAY * TimeManager.MINUTES_PER_HOUR)
	var hour: int = rem / TimeManager.MINUTES_PER_HOUR
	var minute: int = rem % TimeManager.MINUTES_PER_HOUR
	return {"day": day, "hour": hour, "minute": minute}


func _basic_gather_simulate_interval(t0: int, t1: int) -> void:
	if t1 <= t0:
		return
	var span: int = t1 - t0
	const MAX_SIM_MINUTES: int = 10080  # 7 oyun günü; üzeri sadece teslim flush
	if span > MAX_SIM_MINUTES:
		push_warning("[VillageManager] Gather sim span capped (%d min); flushing deliveries only." % span)
		_gather_flush_completed_deliveries_up_to(t1)
		return
	const MAX_CHUNK: int = 480
	var cur: int = t0
	while cur < t1:
		var nxt: int = mini(cur + MAX_CHUNK, t1)
		for tt in range(cur + 1, nxt + 1):
			_gather_process_synthetic_minute(tt)
		cur = nxt


func _gather_process_synthetic_minute(t_abs: int) -> void:
	var cal: Dictionary = _gather_breakdown_total_minutes(t_abs)
	if int(cal.get("hour", 0)) == 0 and int(cal.get("minute", 0)) == 0:
		_decay_basic_resource_overflow_midnight()
	_gather_process_deliveries_at_total(t_abs)
	if int(cal.get("hour", 0)) == GATHER_DEPARTURE_HOUR and int(cal.get("minute", 0)) == GATHER_DEPARTURE_MINUTE:
		_gather_try_departures_at_total(t_abs)


func _tick_basic_gather_realtime_clock() -> void:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return
	var tm := get_node_or_null("/root/TimeManager")
	if tm == null or not tm.has_method("get_total_game_minutes"):
		return
	var gt: int = int(tm.get_total_game_minutes())
	if _last_gather_processed_total_minutes < 0:
		_last_gather_processed_total_minutes = gt
		return
	if gt <= _last_gather_processed_total_minutes:
		return
	var from_m: int = _last_gather_processed_total_minutes
	var gap: int = gt - from_m
	# Yükleme / time_advanced sonrası senkron kayması: tek karede yüz binlerce dakika işleme (debugger çökmesi).
	const DESYNC_SNAP_THRESHOLD: int = 120
	const MAX_MINUTES_PER_FRAME: int = 8
	if gap > DESYNC_SNAP_THRESHOLD:
		_gather_flush_completed_deliveries_up_to(gt)
		_last_gather_processed_total_minutes = gt
		return
	var to_m: int = mini(gt, from_m + MAX_MINUTES_PER_FRAME)
	for tt in range(from_m + 1, to_m + 1):
		_gather_process_synthetic_minute(tt)
	_gather_flush_completed_deliveries_up_to(to_m)
	_last_gather_processed_total_minutes = to_m


func _decay_basic_resource_overflow_midnight() -> void:
	if basic_resource_overflow.is_empty():
		return
	basic_resource_overflow.clear()
	emit_signal("village_data_changed")


func _deposit_basic_resource_with_overflow(res: String, amount: int) -> void:
	if amount <= 0:
		return
	var cap: int = _get_storage_capacity_for(res)
	var cur: int = int(resource_levels.get(res, 0))
	if cap <= 0:
		resource_levels[res] = cur + amount
		return
	var space: int = maxi(0, cap - cur)
	if amount <= space:
		resource_levels[res] = cur + amount
	else:
		resource_levels[res] = cur + space
		var over: int = amount - space
		basic_resource_overflow[res] = int(basic_resource_overflow.get(res, 0)) + over


func _gather_process_deliveries_at_total(t_abs: int) -> void:
	for wid in basic_gather_expeditions_by_worker.keys():
		var exp: Dictionary = basic_gather_expeditions_by_worker.get(wid, {})
		var dm: int = int(exp.get("delivery_minutes", -1))
		if dm == t_abs:
			exp["delivery_ready"] = true


func _gather_deposit_visual_position(worker_id: int) -> Vector2:
	# Yalnızca bina üstü — köylü ekran dışındayken global_position kullanılmaz.
	var data: Dictionary = all_workers.get(worker_id, {})
	var inst: Node = _worker_node_from_all_workers_entry(worker_id, data, false)
	if inst != null and "assigned_building_node" in inst:
		var building: Variant = inst.get("assigned_building_node")
		if is_instance_valid(building) and building is Node2D:
			var bp: Vector2 = (building as Node2D).global_position
			return bp + Vector2(randf_range(-14.0, 14.0), -58.0)
	if is_instance_valid(campfire_node) and campfire_node is Node2D:
		return (campfire_node as Node2D).global_position + Vector2(0.0, -40.0)
	return Vector2(960.0, -26.0)


func _queue_gather_deposit_visual(worker_id: int, resource_type: String, amount: int) -> void:
	if amount <= 0 or resource_type.is_empty():
		return
	basic_gather_pending_visual_by_worker[int(worker_id)] = {
		"resource_type": resource_type,
		"amount": amount,
	}


func present_basic_gather_deposit_visual_at_building(worker_id: int) -> void:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return
	var wid: int = int(worker_id)
	var pending: Variant = basic_gather_pending_visual_by_worker.get(wid, null)
	if not pending is Dictionary:
		return
	var amt: int = int((pending as Dictionary).get("amount", 0))
	var res_type: String = String((pending as Dictionary).get("resource_type", ""))
	basic_gather_pending_visual_by_worker.erase(wid)
	if amt <= 0 or res_type.is_empty():
		return
	emit_signal("basic_gather_deposited", wid, res_type, amt, _gather_deposit_visual_position(wid))


func finalize_basic_gather_delivery_at_building(worker_id: int) -> void:
	## Kaynak + FX yalnızca köylü binaya vardığında (load/flush erken yatırım yapmaz).
	var wid: int = int(worker_id)
	var exp: Variant = basic_gather_expeditions_by_worker.get(wid, null)
	if not exp is Dictionary:
		present_basic_gather_deposit_visual_at_building(wid)
		return
	var exp_dict: Dictionary = exp as Dictionary
	if bool(exp_dict.get("deposit_complete", false)):
		basic_gather_expeditions_by_worker.erase(wid)
		present_basic_gather_deposit_visual_at_building(wid)
		return
	var dm: int = int(exp_dict.get("delivery_minutes", -1))
	var tm := get_node_or_null("/root/TimeManager")
	if dm < 0 or tm == null or not tm.has_method("get_total_game_minutes"):
		return
	var gt: int = int(tm.get_total_game_minutes())
	if dm >= 0 and gt >= dm:
		exp_dict["delivery_ready"] = true
	if not bool(exp_dict.get("delivery_ready", false)) and gt < dm:
		return
	var res_type: String = String(exp_dict.get("resource_type", ""))
	var deposited: int = _gather_complete_delivery(wid, exp_dict)
	basic_gather_expeditions_by_worker.erase(wid)
	if deposited > 0 and not res_type.is_empty():
		_queue_gather_deposit_visual(wid, res_type, deposited)
	present_basic_gather_deposit_visual_at_building(wid)


func _gather_complete_delivery(worker_id: int, exp: Dictionary) -> int:
	if bool(exp.get("deposit_complete", false)):
		return 0
	var res_type: String = String(exp.get("resource_type", ""))
	if res_type.is_empty() or not (res_type in BASE_RESOURCE_TYPES):
		return 0
	exp["deposit_complete"] = true
	var yield_amt: int = _gather_roll_trip_yield(res_type, worker_id)
	if yield_amt > 0:
		_deposit_basic_resource_with_overflow(res_type, yield_amt)
		_daily_production_counter[res_type] = int(_daily_production_counter.get(res_type, 0)) + yield_amt
		emit_signal("resource_produced", res_type, yield_amt)
	elif yield_amt == 0:
		print("[GATHER] Worker %d eli boş döndü (%s)" % [worker_id, res_type])
	emit_signal("village_data_changed")
	return yield_amt


## Sefer kaydı teslim dakikasında silinmez; Worker binaya varınca teslim eder.
func is_gather_return_ready_for_worker(worker_id: int) -> bool:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return false
	var exp: Variant = basic_gather_expeditions_by_worker.get(worker_id, {})
	if not exp is Dictionary:
		return false
	if bool((exp as Dictionary).get("deposit_complete", false)):
		return false
	if bool((exp as Dictionary).get("delivery_ready", false)):
		return true
	var dm: int = int(exp.get("delivery_minutes", -1))
	if dm < 0:
		return false
	var tm := get_node_or_null("/root/TimeManager")
	if tm == null or not tm.has_method("get_total_game_minutes"):
		return false
	var gt: int = int(tm.get_total_game_minutes())
	return gt >= dm


## Sefer bitti ama kaynak henüz binaya yatırılmadı (uyku/idle öncesi tamamlanmalı).
func worker_needs_gather_deposit_at_building(worker_id: int) -> bool:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return false
	if not basic_gather_expeditions_by_worker.has(worker_id):
		return false
	var exp: Variant = basic_gather_expeditions_by_worker.get(worker_id, {})
	if not exp is Dictionary:
		return false
	if bool((exp as Dictionary).get("deposit_complete", false)):
		return false
	return is_gather_return_ready_for_worker(worker_id)


func has_active_basic_gather_expedition_for_worker(worker_id: int) -> bool:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return false
	return basic_gather_expeditions_by_worker.has(worker_id)


## İşçi işe atanır / mesai başlar ama 08:00 çıkışını kaçırdıysa sefer kaydı oluştur.
## Görsel gidiş-dönüş bu kayıt olmadan kaynak üretmez.
func ensure_basic_gather_expedition_for_worker(worker_id: int) -> bool:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return false
	var wid: int = int(worker_id)
	if basic_gather_expeditions_by_worker.has(wid):
		var existing: Variant = basic_gather_expeditions_by_worker.get(wid, {})
		if existing is Dictionary and not bool((existing as Dictionary).get("deposit_complete", false)):
			return true
		basic_gather_expeditions_by_worker.erase(wid)
	var res_job: String = _gather_worker_job_type(wid)
	if res_job.is_empty() or not (res_job in BASE_RESOURCE_TYPES):
		return false
	var tm := get_node_or_null("/root/TimeManager")
	if tm == null or not tm.has_method("get_total_game_minutes"):
		return false
	if tm.has_method("is_work_time") and not bool(tm.is_work_time()):
		return false
	var gt: int = int(tm.get_total_game_minutes())
	var today: int = _gather_calendar_day_from_total_minutes(gt)
	var last_d: int = int(basic_gather_last_departure_day.get(wid, -999999))
	if last_d == today:
		return false
	return _gather_start_expedition_at_departure(wid, gt)


func complete_basic_gather_delivery_for_worker_if_ready(worker_id: int) -> bool:
	finalize_basic_gather_delivery_at_building(worker_id)
	return true


func clear_basic_gather_expedition_for_worker(worker_id: int) -> void:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return
	basic_gather_expeditions_by_worker.erase(worker_id)


func is_distance_based_basic_gather_enabled() -> bool:
	return USE_DISTANCE_BASED_BASIC_GATHER


func get_gather_delivery_total_minutes_for_worker(worker_id: int) -> int:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return -1
	var exp: Variant = basic_gather_expeditions_by_worker.get(worker_id, {})
	if exp is Dictionary:
		return int(exp.get("delivery_minutes", -1))
	return -1


func _gather_calendar_day_from_total_minutes(t_abs: int) -> int:
	return int(t_abs) / (TimeManager.HOURS_PER_DAY * TimeManager.MINUTES_PER_HOUR)


func _gather_start_expedition_at_departure(worker_id: int, departure_abs: int) -> bool:
	var wm := get_node_or_null("/root/WorldManager")
	if wm == null or not wm.has_method("compute_village_gather_round_trip_minutes"):
		return false
	var res_job: String = _gather_worker_job_type(worker_id)
	if res_job.is_empty():
		return false
	var trip: Dictionary = wm.compute_village_gather_round_trip_minutes(res_job)
	if bool(trip.get("ok", false)) and wm.has_method("reveal_village_gather_intel_for_successful_trip"):
		wm.reveal_village_gather_intel_for_successful_trip(trip)
	var total_m: int = maxi(1, int(trip.get("round_trip_minutes", 240)))
	var delivery_minutes: int = departure_abs + total_m
	var cal_day: int = _gather_calendar_day_from_total_minutes(departure_abs)
	basic_gather_expeditions_by_worker[worker_id] = {
		"resource_type": res_job,
		"delivery_minutes": delivery_minutes,
		"delivery_ready": false,
		"deposit_complete": false,
		"total_trip_minutes": total_m,
		"one_way_minutes": int(trip.get("one_way_minutes", 1))
	}
	basic_gather_last_departure_day[worker_id] = cal_day
	return true


func _gather_try_departures_at_total(t_abs: int) -> void:
	var today: int = _gather_calendar_day_from_total_minutes(t_abs)
	var wm := get_node_or_null("/root/WorldManager")
	if wm == null or not wm.has_method("compute_village_gather_round_trip_minutes"):
		return
	for wid in _iter_basic_gather_worker_ids():
		if basic_gather_expeditions_by_worker.has(wid):
			continue
		var last_d: int = int(basic_gather_last_departure_day.get(wid, -999999))
		if last_d == today:
			continue
		_gather_start_expedition_at_departure(int(wid), t_abs)


## Sefer süresi dolduğunda yalnızca "dönüş hazır" işaretle; kaynak stoğa köylü binaya varınca yazılır.
func _gather_flush_completed_deliveries_up_to(t_abs: int) -> void:
	for wid in basic_gather_expeditions_by_worker.keys():
		var exp: Dictionary = basic_gather_expeditions_by_worker.get(wid, {})
		if bool(exp.get("deposit_complete", false)):
			continue
		var dm: int = int(exp.get("delivery_minutes", -1))
		if dm >= 0 and dm <= t_abs:
			exp["delivery_ready"] = true
			basic_gather_expeditions_by_worker[wid] = exp


## Zaman atlama: teslim zamanı geçmiş seferleri sessizce tamamla (kaynak stoğa, animasyonsuz).
func _complete_gather_deliveries_for_time_skip(t_end_abs: int) -> void:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return
	var to_complete: Array[int] = []
	for wid in basic_gather_expeditions_by_worker.keys():
		var exp: Dictionary = basic_gather_expeditions_by_worker.get(wid, {})
		if bool(exp.get("deposit_complete", false)):
			to_complete.append(int(wid))
			continue
		var dm: int = int(exp.get("delivery_minutes", -1))
		if dm >= 0 and dm <= t_end_abs:
			to_complete.append(int(wid))
		elif bool(exp.get("delivery_ready", false)):
			to_complete.append(int(wid))
	for wid in to_complete:
		var exp: Dictionary = basic_gather_expeditions_by_worker.get(wid, {})
		if exp.is_empty():
			basic_gather_expeditions_by_worker.erase(wid)
			continue
		_gather_complete_delivery(wid, exp)
		basic_gather_expeditions_by_worker.erase(wid)
	basic_gather_pending_visual_by_worker.clear()


func _sync_workers_after_time_skip() -> void:
	if workers_container == null:
		return
	var tm := get_node_or_null("/root/TimeManager")
	if tm == null:
		return
	var hour: int = tm.get_hour() if tm.has_method("get_hour") else TimeManager.WAKE_UP_HOUR
	var minute: int = tm.get_minute() if tm.has_method("get_minute") else 0
	for child in workers_container.get_children():
		if child.is_in_group("cats"):
			continue
		if child.has_method("apply_time_skip_presence"):
			child.call("apply_time_skip_presence", hour, minute)


func _purge_stale_worker_registry_entry(worker_id: int) -> void:
	if all_workers.has(worker_id):
		var entry: Variant = all_workers.get(worker_id, null)
		if entry is Dictionary:
			(entry as Dictionary).erase("instance")
	all_workers.erase(worker_id)
	basic_gather_expeditions_by_worker.erase(worker_id)
	basic_gather_last_departure_day.erase(worker_id)
	basic_gather_pending_visual_by_worker.erase(worker_id)


## all_workers["instance"] silinmiş Node ise tipli değişkene atamak çökebilir; sadece Variant + is_instance_valid, ara Object ataması yok.
func _worker_node_from_all_workers_entry(worker_id: Variant, data: Dictionary, purge_if_dead: bool = true) -> Node:
	var ref = data.get("instance", null)
	if ref == null:
		return null
	if typeof(ref) != TYPE_OBJECT:
		return null
	if not is_instance_valid(ref):
		if purge_if_dead:
			_purge_stale_worker_registry_entry(int(worker_id))
		return null
	if not (ref is Node):
		return null
	return ref


func _basic_gather_reconcile_after_village_ready() -> void:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return
	var tm := get_node_or_null("/root/TimeManager")
	if tm == null:
		return
	var gt: int = int(tm.get_total_game_minutes())
	var day_start: int = gt - tm.get_hour() * 60 - tm.get_minute()
	var depart_slot: int = day_start + GATHER_DEPARTURE_HOUR * 60 + GATHER_DEPARTURE_MINUTE
	if gt >= depart_slot:
		for wid in _iter_basic_gather_worker_ids():
			if basic_gather_expeditions_by_worker.has(wid):
				continue
			var today: int = _gather_calendar_day_from_total_minutes(gt)
			var last_d: int = int(basic_gather_last_departure_day.get(wid, -999999))
			if last_d == today:
				continue
			_gather_start_expedition_at_departure(int(wid), depart_slot)
	if tm.has_method("is_work_time") and bool(tm.is_work_time()):
		for wid in _iter_basic_gather_worker_ids():
			ensure_basic_gather_expedition_for_worker(int(wid))
	_gather_flush_completed_deliveries_up_to(gt)
	_last_gather_processed_total_minutes = gt
	emit_signal("village_data_changed")


func _iter_basic_gather_worker_ids() -> Array:
	var out: Array = []
	for wid in all_workers.keys():
		var data: Dictionary = all_workers.get(wid, {})
		var inst: Node = _worker_node_from_all_workers_entry(wid, data, true)
		if inst == null:
			continue
		if inst.get("is_sick"):
			continue
		if "current_state" in inst:
			var cs: int = int(inst.current_state)
			# SICK / GOING_HOME_SICK — evde yatan veya eve giden hasta toplamaz.
			if cs == 12 or cs == 13:
				continue
		var jt: String = ""
		if "assigned_job_type" in inst:
			jt = String(inst.get("assigned_job_type"))
		if not (jt in BASE_RESOURCE_TYPES):
			continue
		out.append(int(wid))
	return out


## Evde yatan (veya eve giden) hasta köylü sayısı — HUD göstergesi için.
func get_sick_villagers_at_home_count() -> int:
	var count := 0
	for wid in all_workers.keys():
		var data: Dictionary = all_workers.get(wid, {})
		var inst: Node = _worker_node_from_all_workers_entry(wid, data, true)
		if inst == null or _is_guest_worker(inst):
			continue
		if not inst.get("is_sick"):
			continue
		if "current_state" in inst and int(inst.current_state) != 12:
			continue
		count += 1
	return count


## Belirli bir barınak (ev / kamp ateşi) için evde yatan hasta sayısı.
func get_sick_count_at_housing(housing: Node) -> int:
	if not is_instance_valid(housing):
		return 0
	var count := 0
	for wid in all_workers.keys():
		var data: Dictionary = all_workers.get(wid, {})
		var inst: Node = _worker_node_from_all_workers_entry(wid, data, true)
		if inst == null or _is_guest_worker(inst):
			continue
		if not inst.get("is_sick"):
			continue
		if "current_state" in inst and int(inst.current_state) != 12:
			continue
		var hn = inst.get("housing_node") if "housing_node" in inst else null
		if not is_instance_valid(hn):
			continue
		if hn == housing:
			count += 1
	return count


func _gather_worker_job_type(worker_id: int) -> String:
	var data: Dictionary = all_workers.get(worker_id, {})
	var inst: Node = _worker_node_from_all_workers_entry(worker_id, data, true)
	if inst == null:
		return ""
	if "assigned_job_type" in inst:
		return String(inst.get("assigned_job_type"))
	return ""


func _serialize_basic_gather_for_save() -> void:
	_saved_basic_gather_expeditions.clear()
	for wid in basic_gather_expeditions_by_worker.keys():
		var exp: Dictionary = basic_gather_expeditions_by_worker.get(wid, {}).duplicate(true)
		exp["worker_id"] = int(wid)
		_saved_basic_gather_expeditions.append(exp)
	_saved_basic_gather_last_departure_day = basic_gather_last_departure_day.duplicate(true)
	_saved_basic_resource_overflow = basic_resource_overflow.duplicate(true)


func _restore_basic_gather_runtime_if_needed() -> void:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return
	if not basic_gather_expeditions_by_worker.is_empty():
		return
	if _saved_basic_gather_expeditions.is_empty():
		return
	_deserialize_basic_gather_from_save()


func _deserialize_basic_gather_from_save() -> void:
	basic_gather_expeditions_by_worker.clear()
	basic_gather_last_departure_day.clear()
	basic_resource_overflow.clear()
	for e in _saved_basic_gather_expeditions:
		if e is Dictionary:
			var wid: int = int(e.get("worker_id", -1))
			if wid < 0:
				continue
			var copy: Dictionary = e.duplicate(true)
			copy.erase("worker_id")
			basic_gather_expeditions_by_worker[wid] = copy
	if not _saved_basic_gather_last_departure_day.is_empty():
		basic_gather_last_departure_day = _saved_basic_gather_last_departure_day.duplicate(true)
	if not _saved_basic_resource_overflow.is_empty():
		basic_resource_overflow = _saved_basic_resource_overflow.duplicate(true)

func _simulate_basic_production_minute(game_seconds: float, resource_counts: Dictionary) -> bool:
	if USE_DISTANCE_BASED_BASIC_GATHER:
		return false
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
			var worker_instance: Node = _worker_node_from_all_workers_entry(worker_id, worker_data, true)
			if worker_instance == null:
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
	var housing_node = _get_or_create_residential_housing_for_building(building as Node2D, false)
	if is_instance_valid(housing_node):
		entry["residential_floors"] = int(housing_node.get_current_floors())
		entry["residential_max_floors"] = int(housing_node.max_floors)
		entry["residential_capacity_per_floor"] = int(housing_node.capacity_per_floor)
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
	var remaining_seconds := total_seconds
	var safety := 0
	while remaining_seconds > 0.0 and safety < 64:
		safety += 1
		var completed_any := false
		for building in placed_buildings.get_children():
			if not (building is Node2D):
				continue
			if "is_upgrading" not in building or not building.is_upgrading:
				continue
			if "upgrade_timer" not in building or not building.upgrade_timer:
				continue
			var timer: Timer = building.upgrade_timer
			var time_left := timer.time_left
			if time_left <= remaining_seconds:
				if building.has_method("finish_upgrade"):
					building.finish_upgrade()
				elif building.has_method("_on_upgrade_finished"):
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
					if building.has_signal("upgrade_finished"):
						building.upgrade_finished.emit()
					if building.has_signal("state_changed"):
						building.state_changed.emit()
					notify_building_state_changed(building)
					if building.has_method("_update_texture"):
						building._update_texture()
					if building.has_method("_update_collision"):
						building._update_collision()
				remaining_seconds -= maxf(time_left, 0.0)
				completed_any = true
			else:
				timer.stop()
				timer.wait_time = time_left - remaining_seconds
				timer.start()
		if not completed_any:
			break

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

const DEBUG_VILLAGE_MANAGER: bool = false
const LOAD_IDLE_SPREAD_X_RANGE: float = 180.0
const LOAD_IDLE_WANDER_TARGET_RANGE: float = 120.0
const LOAD_IDLE_Y_MIN: float = 5.0
const LOAD_IDLE_Y_MAX: float = 30.0
const WORKER_OFFSCREEN_LOAD_DISTANCE: float = 5500.0


func _infer_job_type_for_worker_snapshot(worker_id: int, building_key: String) -> String:
	if not building_key.is_empty():
		for entry in _saved_building_states:
			if not (entry is Dictionary) or _is_campfire_snapshot_entry(entry):
				continue
			if String(entry.get("key", "")) == building_key:
				return _job_type_from_building_snapshot_entry(entry)
	for entry in _saved_building_states:
		if not (entry is Dictionary) or _is_campfire_snapshot_entry(entry):
			continue
		var assigned_ids: Array = entry.get("assigned_worker_ids", [])
		if assigned_ids is Array and worker_id in assigned_ids:
			return _job_type_from_building_snapshot_entry(entry)
	return ""


func _find_building_key_for_worker_job(job_type: String, restored_buildings_map: Dictionary) -> String:
	var target_scene: String = String(RESOURCE_PRODUCER_SCENES.get(job_type, ""))
	if target_scene.is_empty():
		return ""
	for key in restored_buildings_map.keys():
		var building: Node2D = restored_buildings_map[key]
		if is_instance_valid(building) and building.scene_file_path == target_scene:
			return String(key)
	for entry in _saved_building_states:
		if not (entry is Dictionary) or _is_campfire_snapshot_entry(entry):
			continue
		if String(entry.get("scene_path", "")) == target_scene:
			return String(entry.get("key", ""))
	return ""


func _apply_saved_worker_states(_restored_buildings_map: Dictionary) -> void:
	if DEBUG_VILLAGE_MANAGER:
		print("[VillageManager] 🔄 DEBUG: Starting _apply_saved_worker_states() with %d saved states, %d buildings in map" % [_saved_worker_states.size(), _restored_buildings_map.size()])
	if _saved_worker_states.is_empty():
		if DEBUG_VILLAGE_MANAGER:
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
			if worker_data:
				assigned_worker = _worker_node_from_all_workers_entry(saved_worker_id, worker_data, false)
		
		if not is_instance_valid(assigned_worker):
			for worker_id in all_workers.keys():
				var worker_data = all_workers.get(worker_id, {})
				if not worker_data:
					continue
				var worker_instance: Node = _worker_node_from_all_workers_entry(worker_id, worker_data, true)
				if worker_instance == null:
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
			job_type = _infer_job_type_for_worker_snapshot(saved_worker_id, building_key)
		if building_key.is_empty() and not job_type.is_empty():
			building_key = _find_building_key_for_worker_job(job_type, _restored_buildings_map)
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
				var is_offscreen_gather := job_type in BASE_RESOURCE_TYPES and USE_DISTANCE_BASED_BASIC_GATHER
				if not is_offscreen_gather:
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
						var offscreen_x: float = -WORKER_OFFSCREEN_LOAD_DISTANCE
						if building_pos.x >= 960:
							offscreen_x = WORKER_OFFSCREEN_LOAD_DISTANCE
						
						if worker_instance is Node2D:
							var worker_node2d = worker_instance as Node2D
							worker_node2d.global_position = Vector2(offscreen_x, building_pos.y)
							worker_instance.set("move_target_x", offscreen_x)
							worker_instance.set("_target_global_y", building_pos.y)
							worker_instance.set("_offscreen_exit_x", offscreen_x)
					
					if job_type in BASE_RESOURCE_TYPES and USE_DISTANCE_BASED_BASIC_GATHER:
						ensure_basic_gather_expedition_for_worker(saved_worker_id)
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
				_place_worker_for_loaded_idle(worker_instance, assigned_building)
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
						if job_type in BASE_RESOURCE_TYPES and USE_DISTANCE_BASED_BASIC_GATHER:
							ensure_basic_gather_expedition_for_worker(saved_worker_id)
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

func _place_worker_for_loaded_idle(worker_instance: Node, assigned_building: Node2D) -> void:
	if not (worker_instance is Node2D):
		return
	
	var worker_node2d := worker_instance as Node2D
	var anchor_x: float = worker_node2d.global_position.x
	
	if is_instance_valid(assigned_building):
		anchor_x = assigned_building.global_position.x
	else:
		var housing = worker_instance.get("housing_node") if worker_instance.has_method("get") else null
		if is_instance_valid(housing) and housing is Node2D:
			anchor_x = (housing as Node2D).global_position.x
		elif is_instance_valid(campfire_node):
			anchor_x = campfire_node.global_position.x
	
	var spawn_x = anchor_x + randf_range(-LOAD_IDLE_SPREAD_X_RANGE, LOAD_IDLE_SPREAD_X_RANGE)
	var spawn_y = randf_range(LOAD_IDLE_Y_MIN, LOAD_IDLE_Y_MAX)
	worker_node2d.global_position = Vector2(spawn_x, spawn_y)
	worker_instance.set("move_target_x", spawn_x + randf_range(-LOAD_IDLE_WANDER_TARGET_RANGE, LOAD_IDLE_WANDER_TARGET_RANGE))
	worker_instance.set("_target_global_y", randf_range(LOAD_IDLE_Y_MIN, LOAD_IDLE_Y_MAX))

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
		var inst: Node = _worker_node_from_all_workers_entry(wid, worker_data, true)
		if inst == null:
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

var daily_food_per_pop: float = 1.0
var cariye_period_days: int = 7

var resource_prod_multiplier: Dictionary = {
	"wood": 1.0,
	"stone": 1.0,
	"food": 1.0,
	"lumber": 1.0,
	"brick": 1.0,
	"metal": 1.0,
	"cloth": 1.0,
	"garment": 1.0,
	"bread": 1.0,
	"tea": 1.0,
	"medicine": 1.0,
	"soap": 1.0,
	"weapon_t1": 1.0,
	"weapon_t2": 1.0,
	"weapon_t3": 1.0
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
## SaveManager: üretim çarpanları kayıttan yüklendiyse reapply'da kuraklık vb. tekrar uygulanmaz.
var _production_multipliers_restored_from_save: bool = false
var _last_day_shortages: Dictionary = {"food": 0, "soldier_food": 0}

var _last_econ_tick_day: int = 0

# === Events scaffold (feature-flagged) ===
var events_enabled: bool = true
var daily_event_chance: float = 0.02
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
const VillageDefenseAlertScript := preload("res://ui/VillageDefenseAlert.gd")
const VillageDefenseBattleRunnerScript := preload("res://village/scripts/VillageDefenseBattleRunner.gd")

var _village_defense_alert: VillageDefenseAlert = null
var _defense_battle_runner: VillageDefenseBattleRunner = null
var _last_pending_attack_banner_count: int = 0

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
		if wm.has_signal("pending_attacks_changed"):
			if not wm.pending_attacks_changed.is_connected(_on_pending_attacks_changed):
				wm.pending_attacks_changed.connect(_on_pending_attacks_changed)
		if wm.has_signal("defense_outcome_report"):
			if not wm.defense_outcome_report.is_connected(_on_defense_outcome_report):
				wm.defense_outcome_report.connect(_on_defense_outcome_report)
		if wm.has_signal("playable_defense_required"):
			if not wm.playable_defense_required.is_connected(_on_playable_defense_required):
				wm.playable_defense_required.connect(_on_playable_defense_required)
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
	_setup_village_defense_ui()
	#print("VillageManager: VillageScene kaydedildi.")

	# --- İşçi Yönetimi Kurulumu (Buraya Taşındı) ---
	# CampFire'ı bul.
	# Not: ResidentialHousing/House node'ları da "Housing" grubundadır; bu yüzden
	# get_first_node_in_group("Housing") yanlış node döndürebilir.
	# CampFire'ı script yolundan kesin olarak ayırt et.
	await get_tree().process_frame # Grupların güncel olduğundan emin ol
	campfire_node = null
	for _housing_node in get_tree().get_nodes_in_group("Housing"):
		if _housing_node.get_script() and \
				String(_housing_node.get_script().resource_path).ends_with("CampFire.gd"):
			campfire_node = _housing_node
			break
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
		var cfoot: String = String(_pending_time_skip_notification.get("construction_footnote", ""))
		print("[VillageManager] 📬 Showing pending notification: %.1f hours, resources: %s" % [hours, resources])
		# Wait a bit more for UI to fully initialize
		await get_tree().process_frame
		await get_tree().process_frame
		emit_signal("time_skip_completed", hours, resources, cfoot)
		_pending_time_skip_notification = {}

	# Note: Resources are restored in SceneManager._handle_travel_time() BEFORE simulation
	# This function is called AFTER scene change, so resources should already be restored
	# But we still check here for first-time initialization
	if _saved_resource_levels.is_empty() and resource_levels.is_empty():
		# First time initialization - set defaults
		for res in BASE_RESOURCE_TYPES:
			if not resource_levels.has(res):
				resource_levels[res] = 0
		if not resource_levels.has("weapon_t1"):
			resource_levels["weapon_t1"] = 5
		if not resource_levels.has("weapon_t2"):
			resource_levels["weapon_t2"] = 0
		if not resource_levels.has("weapon_t3"):
			resource_levels["weapon_t3"] = 0
	
	# Başlangıç işçilerini oluştur
	if workers_container and is_instance_valid(campfire_node):
		if DEBUG_VILLAGE_MANAGER:
			print("[VillageManager] 🔄 DEBUG: Starting worker restoration...")
		_reset_worker_runtime_data()
		worker_id_counter = 0
		var restored_buildings_map := _restore_saved_buildings()
		if DEBUG_VILLAGE_MANAGER:
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
			if DEBUG_VILLAGE_MANAGER:
				print("[VillageManager] 🔍 DEBUG: Found %d saved worker states" % _saved_worker_states.size())
			worker_entries = _saved_worker_states.duplicate(true)
			if has_method("_worker_entry_sorter"):
				worker_entries.sort_custom(Callable(self, "_worker_entry_sorter"))
			else:
				if DEBUG_VILLAGE_MANAGER:
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
			if DEBUG_VILLAGE_MANAGER:
				print("[VillageManager] 🔄 DEBUG: Creating worker - Saved ID: %d, Job: %s, Building: %s, Housing: %s" % [worker_id_from_entry, job_type_from_entry, building_key_from_entry, housing_key_from_entry])
			
			var saved_housing_key = housing_key_from_entry
			if bool(worker_entry.get("is_guest_villager", false)):
				_restore_guest_worker_from_snapshot(worker_entry)
				max_worker_id = max(max_worker_id, int(worker_entry.get("worker_id", worker_id_counter)))
				worker_created_count += 1
				continue
			var saved_appearance: Dictionary = worker_entry.get("appearance", {}) if worker_entry.get("appearance", {}) is Dictionary else {}
			if _add_new_worker(info_dict, saved_appearance):
				worker_created_count += 1
				var desired_id: int = int(worker_entry.get("worker_id", -1))
				var new_id: int = worker_id_counter
				if desired_id >= 0 and desired_id != new_id:
					if DEBUG_VILLAGE_MANAGER:
						print("[VillageManager] 🔄 DEBUG: Changing worker ID from %d to %d" % [new_id, desired_id])
					var worker_data = all_workers.get(new_id, {})
					if worker_data:
						all_workers.erase(new_id)
						var worker_instance: Node = _worker_node_from_all_workers_entry(new_id, worker_data, false)
						if is_instance_valid(worker_instance):
							worker_instance.worker_id = desired_id
							worker_instance.name = "Worker" + str(desired_id)
						all_workers[desired_id] = worker_data
					worker_id_counter = max(worker_id_counter, desired_id)
					new_id = desired_id
				else:
					if DEBUG_VILLAGE_MANAGER:
						print("[VillageManager] ✅ DEBUG: Worker created with ID %d (desired: %d)" % [new_id, desired_id])
				
				# Housing node'u geri yükle (eğer kaydedilmişse)
				# Not: _add_new_worker içinde _assign_housing çağrılıyor, bu da yeni bir housing atıyor
				# Bu yüzden önceki housing'ı geri yüklemeliyiz
				if not saved_housing_key.is_empty():
					var worker_data = all_workers.get(new_id, {})
					var worker_instance: Node = _worker_node_from_all_workers_entry(new_id, worker_data, false)
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
							if DEBUG_VILLAGE_MANAGER:
								print("[VillageManager] ✅ DEBUG: Restored housing_node for worker %d (key: %s)" % [new_id, saved_housing_key])
						else:
							if DEBUG_VILLAGE_MANAGER:
								print("[VillageManager] ⚠️ DEBUG: Housing node not found for key: %s" % saved_housing_key)
				
				max_worker_id = max(max_worker_id, new_id)
			else:
				if DEBUG_VILLAGE_MANAGER:
					print("[VillageManager] ⚠️ DEBUG: Failed to create worker with saved ID %d" % worker_id_from_entry)
		worker_id_counter = max(worker_id_counter, max_worker_id)
		if DEBUG_VILLAGE_MANAGER:
			print("[VillageManager] ✅ DEBUG: Created %d workers, max ID: %d" % [worker_created_count, worker_id_counter])
			print("[VillageManager] 🔄 DEBUG: Applying saved worker states to buildings...")
		_apply_saved_worker_states(restored_buildings_map)
		_reconcile_housing_occupant_lists()
		# Görev ormandayken tamamlandıysa askerler geri çağrılmamış olabilir; yükleme sonrası senkronize et
		call_deferred("_sync_soldiers_with_missions")
		emit_signal("village_data_changed")
		_apply_pending_constructions_from_load_buffer()
		_resync_pending_construction_sites_after_scene_load()
		_rebuild_reserved_plots_from_pending_positions()
		_finalize_awaiting_construction_placements()
		# Worker restoration tamamlandıktan sonra, varsa zindandan kurtarılan köylü/cariyeleri uygula
		if is_instance_valid(village_scene_instance) and village_scene_instance.has_method("_apply_dungeon_rescued"):
			if DEBUG_VILLAGE_MANAGER:
				print("[VillageManager] 🔁 DEBUG: Calling VillageScene._apply_dungeon_rescued() after restoration")
			village_scene_instance.call_deferred("_apply_dungeon_rescued")
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
	_ensure_time_manager_economy_hooks()
	if tm:
		if tm.has_method("get_total_game_minutes"):
			_last_construction_total_minutes = int(tm.get_total_game_minutes())
		if tm.has_signal("hour_changed") and not _time_signal_connected:
			tm.connect("hour_changed", Callable(self, "_on_hour_changed"))
			_time_signal_connected = true
		if tm.has_signal("time_advanced") and not _time_advanced_connected:
			tm.connect("time_advanced", Callable(self, "_on_time_advanced"))
			_time_advanced_connected = true
		if USE_DISTANCE_BASED_BASIC_GATHER and tm.has_method("get_total_game_minutes"):
			_sanitize_legacy_basic_gather_multipliers()
			_restore_basic_gather_runtime_if_needed()
			_last_gather_processed_total_minutes = int(tm.get_total_game_minutes())
			call_deferred("_basic_gather_reconcile_after_village_ready")
		_apply_time_of_day(tm.get_hour() if tm.has_method("get_hour") else 0)
	else:
		_apply_time_of_day(6)

# Belirli bir kaynak türünü üreten Tescilli Script Yolları
# Bu, get_resource_level için gereklidir
const RESOURCE_PRODUCER_SCRIPTS = {
	"wood": "res://village/scripts/WoodcutterCamp.gd",
	"stone": "res://village/scripts/StoneMine.gd",
	"food": "res://village/scripts/HunterGathererHut.gd", # Veya Tarla/Balıkçı vb.
	"lumber": "res://village/scripts/Sawmill.gd",
	"brick": "res://village/scripts/Brickworks.gd",
	"metal": "res://village/scripts/Blacksmith.gd",
	"bread": "res://village/scripts/Bakery.gd", #<<< YENİ
	"cloth": "res://village/scripts/Weaver.gd",
	"garment": "res://village/scripts/Tailor.gd",
	"tea": "res://village/scripts/TeaHouse.gd",
	"medicine": "res://village/scripts/Herbalist.gd",
	"soap": "res://village/scripts/SoapMaker.gd",
	"weapon_t1": "res://village/scripts/Gunsmith.gd",
	"weapon_t2": "res://village/scripts/Gunsmith.gd",
	"weapon_t3": "res://village/scripts/Gunsmith.gd",
	"soldier": "res://village/scripts/Barracks.gd" # Asker işçi türü eklendi
}

# Scene path mapping for robust counting (some checks rely on scene_file_path)
const RESOURCE_PRODUCER_SCENES = {
	"wood": "res://village/buildings/WoodcutterCamp.tscn",
	"stone": "res://village/buildings/StoneMine.tscn",
	"food": "res://village/buildings/HunterGathererHut.tscn",
	"lumber": "res://village/buildings/Sawmill.tscn",
	"brick": "res://village/buildings/Brickworks.tscn",
	"metal": "res://village/buildings/Blacksmith.tscn",
	"bread": "res://village/buildings/Bakery.tscn",
	"cloth": "res://village/buildings/Weaver.tscn",
	"garment": "res://village/buildings/Tailor.tscn",
	"tea": "res://village/buildings/TeaHouse.tscn",
	"medicine": "res://village/buildings/Herbalist.tscn",
	"soap": "res://village/buildings/SoapMaker.tscn",
	"weapon_t1": "res://village/buildings/Gunsmith.tscn",
	"weapon_t2": "res://village/buildings/Gunsmith.tscn",
	"weapon_t3": "res://village/buildings/Gunsmith.tscn"
}

# Bir kaynak türünün mevcut stok seviyesini döndürür (temel ve gelişmiş için ortak)
func get_resource_level(resource_type: String) -> int:
	return resource_levels.get(resource_type, 0)


func _strip_legacy_water_from_resources() -> void:
	resource_levels.erase("water")
	locked_resource_levels.erase("water")
	base_production_progress.erase("water")
	resource_prod_multiplier.erase("water")
	_daily_production_counter.erase("water")

## world_map / görev: { "food": 5, "gold": 10 } — gold GlobalPlayerData üzerinden.
func can_afford_resources(cost: Dictionary) -> bool:
	if cost.is_empty():
		return true
	if int(cost.get("gold", 0)) > 0:
		if not GlobalPlayerData or GlobalPlayerData.gold < int(cost.get("gold", 0)):
			return false
	for k in cost.keys():
		if str(k) == "gold":
			continue
		var need: int = int(cost[k])
		if need <= 0:
			continue
		if int(resource_levels.get(str(k), 0)) < need:
			return false
	return true

func spend_resources(cost: Dictionary) -> bool:
	if not can_afford_resources(cost):
		return false
	var g: int = int(cost.get("gold", 0))
	if g > 0 and GlobalPlayerData:
		GlobalPlayerData.add_gold(-g)
	for k in cost.keys():
		if str(k) == "gold":
			continue
		var need: int = int(cost[k])
		if need <= 0:
			continue
		var key: String = str(k)
		resource_levels[key] = int(resource_levels.get(key, 0)) - need
	emit_signal("village_data_changed")
	return true

## Görev ödül/ceza: stok artışı (+) veya düşüşü (-). Uygulanan miktarı döndürür.
func apply_resource_delta(resource_type: String, delta: int) -> int:
	if delta == 0:
		return 0
	var key: String = str(resource_type)
	if delta > 0:
		_deposit_basic_resource_with_overflow(key, delta)
		emit_signal("village_data_changed")
		return delta
	var cur: int = int(resource_levels.get(key, 0))
	var loss: int = mini(-delta, cur)
	if loss > 0:
		resource_levels[key] = cur - loss
		emit_signal("village_data_changed")
	return -loss

func get_healer_concubine_treatment_cost() -> Dictionary:
	return HEALER_CONCUBINE_TREATMENT_COST.duplicate(true)

func can_healer_concubine_treat(cariye_id: int) -> bool:
	if not cariyeler.has(cariye_id):
		return false
	var mission_manager = get_node_or_null("/root/MissionManager")
	if not mission_manager or not ("concubines" in mission_manager):
		return false
	var mm_concubines: Dictionary = mission_manager.get("concubines")
	if not mm_concubines.has(cariye_id):
		return false
	var healer: Concubine = mm_concubines[cariye_id]
	if healer == null:
		return false
	if healer.role != Concubine.Role.TIBBIYECI:
		return false
	if healer.status != Concubine.Status.BOŞTA:
		return false
	var player_stats = get_node_or_null("/root/PlayerStats")
	if not player_stats or not player_stats.has_method("has_active_death_debuff"):
		return false
	if not bool(player_stats.call("has_active_death_debuff")):
		return false
	return can_afford_resources(HEALER_CONCUBINE_TREATMENT_COST)

func try_healer_concubine_treatment(cariye_id: int) -> Dictionary:
	var result := {"ok": false, "message": "Tedavi uygulanamadı."}
	if not can_healer_concubine_treat(cariye_id):
		result["message"] = "Şifacı cariye boşta değil, debuff yok veya maliyet karşılanmıyor."
		return result
	var player_stats = get_node_or_null("/root/PlayerStats")
	if not is_instance_valid(player_stats):
		result["message"] = "PlayerStats bulunamadı."
		return result
	if not spend_resources(HEALER_CONCUBINE_TREATMENT_COST):
		result["message"] = "Yeterli altın/ilaç yok."
		return result
	var cleared: bool = false
	if player_stats.has_method("clear_active_death_debuff"):
		cleared = bool(player_stats.call("clear_active_death_debuff"))
	if not cleared:
		result["message"] = "Aktif bir debuff bulunamadı."
		return result
	emit_signal("cariye_data_changed")
	result["ok"] = true
	result["message"] = "Şifacı cariye tedaviyi tamamladı."
	return result

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
				if "assigned_worker_ids" in building:
					var ids: Variant = building.get("assigned_worker_ids")
					if ids is Array and not ids.is_empty():
						assigned_workers_for_resource += ids.size()
						continue
				if "assigned_workers" in building:
					assigned_workers_for_resource += int(building.assigned_workers)
	
	return assigned_workers_for_resource

## Mesafe tabanlı toplamada sefer atanmış işçi sayısı (job type + bina kaydı — UI ile uyumlu).
func _count_gather_workers_for_resource(resource_type: String) -> int:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return _count_active_workers_for_resource(resource_type)
	var count := 0
	for wid in _iter_basic_gather_worker_ids():
		if _gather_worker_job_type(int(wid)) == resource_type:
			count += 1
	return count

func _count_workers_for_daily_projection(resource_type: String) -> int:
	if USE_DISTANCE_BASED_BASIC_GATHER and resource_type in BASE_RESOURCE_TYPES:
		return _count_gather_workers_for_resource(resource_type)
	return _count_active_workers_for_resource(resource_type)

# Belirli bir kaynak seviyesinin ne kadarının kullanılabilir (kilitli olmayan) olduğunu döndürür
func get_available_resource_level(resource_type: String) -> int:
	var total_level = get_resource_level(resource_type)
	var locked_level = locked_resource_levels.get(resource_type, 0)
	# #print("DEBUG VillageManager: get_available_resource_level(%s): Total=%d, Locked=%d, Available=%d" % [resource_type, total_level, locked_level, max(0, total_level - locked_level)]) #<<< DEBUG
	return max(0, total_level - locked_level)

func _gather_yield_per_trip(resource_type: String) -> int:
	if resource_type == "food":
		return GATHER_DELIVERY_YIELD_FOOD
	return GATHER_DELIVERY_YIELD_DEFAULT


func _event_level_empty_trip_chance(event_level: int) -> float:
	# Eski çarpan modeli: 0.8 / 0.6 / 0.4 → boş sefer %20 / %40 / %60
	var mult: float = float(EVENT_LEVEL_MULTIPLIERS.get(event_level, 0.8))
	return clampf(1.0 - mult, 0.0, 0.95)


func _event_level_bonus_trip_yield(event_level: int) -> int:
	match event_level:
		EventLevel.LOW:
			return 1
		EventLevel.MEDIUM:
			return 1
		EventLevel.HIGH:
			return 2
		_:
			return 1


func _event_still_active(ev: Dictionary, current_day: int) -> bool:
	if ev.has("ends_day"):
		return current_day <= int(ev.get("ends_day", current_day))
	var started_day := int(ev.get("started_day", current_day))
	var duration := int(ev.get("duration", 0))
	if duration > 0:
		return current_day < started_day + duration
	return true


func _resolve_event_level(ev: Dictionary) -> int:
	if ev.has("level"):
		return int(ev.get("level", EventLevel.MEDIUM))
	if ev.has("severity"):
		var sev := float(ev.get("severity", 0.0))
		if sev < 0.2:
			return EventLevel.LOW
		if sev < 0.3:
			return EventLevel.MEDIUM
		return EventLevel.HIGH
	return EventLevel.MEDIUM


func _accumulate_gather_trip_mods_from_event(
	ev: Dictionary,
	resource_type: String,
	current_day: int,
	empty_chance: float,
	bonus_yield: int
) -> Dictionary:
	if not _event_still_active(ev, current_day):
		return {"empty_chance": empty_chance, "bonus_yield": bonus_yield}
	var event_type := String(ev.get("type", ""))
	var event_level: int = _resolve_event_level(ev)
	var fail_p: float = _event_level_empty_trip_chance(event_level)
	match event_type:
		"drought", "famine":
			if resource_type == "food":
				empty_chance = maxf(empty_chance, fail_p)
		"pest":
			if resource_type == "wood":
				empty_chance = maxf(empty_chance, fail_p)
		"wolf_attack":
			if resource_type == "stone":
				empty_chance = maxf(empty_chance, fail_p)
		"severe_storm":
			if resource_type in BASE_RESOURCE_TYPES:
				empty_chance = maxf(empty_chance, fail_p)
		"weather_blessing":
			if resource_type in BASE_RESOURCE_TYPES:
				bonus_yield = maxi(bonus_yield, _event_level_bonus_trip_yield(event_level))
		"worker_strike":
			var strike_res := String(ev.get("strike_resource", ""))
			if strike_res == resource_type:
				empty_chance = 1.0
		"plague", "disease":
			pass
	return {"empty_chance": empty_chance, "bonus_yield": bonus_yield}


func _get_gather_trip_modifiers(resource_type: String) -> Dictionary:
	var empty_chance := 0.0
	var bonus_yield := 0
	var tm := get_node_or_null("/root/TimeManager")
	var current_day: int = int(tm.get_day()) if tm and tm.has_method("get_day") else 0
	for ev in events_active:
		if ev is Dictionary:
			var merged := _accumulate_gather_trip_mods_from_event(
				ev, resource_type, current_day, empty_chance, bonus_yield
			)
			empty_chance = float(merged.get("empty_chance", empty_chance))
			bonus_yield = int(merged.get("bonus_yield", bonus_yield))
	var wm := get_node_or_null("/root/WorldManager")
	if wm != null and wm.get("active_events") != null:
		for ev in wm.active_events:
			if ev is Dictionary:
				var merged_w := _accumulate_gather_trip_mods_from_event(
					ev, resource_type, current_day, empty_chance, bonus_yield
				)
				empty_chance = float(merged_w.get("empty_chance", empty_chance))
				bonus_yield = int(merged_w.get("bonus_yield", bonus_yield))
				# Dünya olayı effects sözlüğü (kıtlık vb.)
				if ev.has("effects") and ev.get("effects") is Dictionary:
					var effects: Dictionary = ev.get("effects")
					if resource_type == "food" and effects.has("food_production"):
						var food_p: float = float(effects.get("food_production", 1.0))
						if food_p < 1.0:
							empty_chance = maxf(empty_chance, clampf(1.0 - food_p, 0.0, 0.95))
	var mm := get_node_or_null("/root/MissionManager")
	if mm != null and mm.has_method("get_external_rate_delta"):
		var ext_delta: int = int(mm.get_external_rate_delta(resource_type))
		if ext_delta < 0:
			empty_chance = maxf(empty_chance, clampf(0.25 * float(-ext_delta), 0.0, 0.95))
		elif ext_delta > 0:
			# Bölgesel +1/g modları toplanmasın — başarılı seferde en fazla +1 ekstra.
			bonus_yield = maxi(bonus_yield, 1)
	empty_chance = clampf(empty_chance, 0.0, 0.95)
	bonus_yield = mini(bonus_yield, 2)
	return {"empty_chance": empty_chance, "bonus_yield": bonus_yield}


func _gather_roll_trip_yield(resource_type: String, worker_id: int) -> int:
	var mods: Dictionary = _get_gather_trip_modifiers(resource_type)
	var empty_p: float = float(mods.get("empty_chance", 0.0))
	if empty_p >= 1.0 or (empty_p > 0.0 and randf() < empty_p):
		return 0
	var base: int = _gather_yield_per_trip(resource_type)
	return maxi(0, base + int(mods.get("bonus_yield", 0)))


func _sanitize_legacy_basic_gather_multipliers() -> void:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return
	for rk in BASE_RESOURCE_TYPES:
		resource_prod_multiplier[rk] = 1.0

func _estimate_daily_basic_gather_yield(resource_type: String, worker_count: int) -> float:
	if worker_count <= 0:
		return 0.0
	# Mesafe seferi: günde en fazla bir çıkış (basic_gather_last_departure_day).
	return float(worker_count) * float(_gather_yield_per_trip(resource_type))

func _estimate_daily_food_consumption() -> float:
	return float(int(total_workers)) * daily_food_per_pop

## Sefer/temel toplama günlük tahmini — tam sayılı sefer modeli (boş dönüş olasılığı).
func _estimate_daily_basic_gather_yield_adjusted(resource_type: String, worker_count: int) -> float:
	if worker_count <= 0:
		return 0.0
	return float(_estimate_daily_basic_gather_units(resource_type, worker_count))


## Beklenen günlük toplama birimi (tam sayı, sefer modeli).
func _estimate_daily_basic_gather_units(resource_type: String, worker_count: int) -> int:
	if worker_count <= 0:
		return 0
	var mods: Dictionary = _get_gather_trip_modifiers(resource_type)
	var empty_p: float = float(mods.get("empty_chance", 0.0))
	var per_trip: int = _gather_yield_per_trip(resource_type) + int(mods.get("bonus_yield", 0))
	var per_worker: float = (1.0 - empty_p) * float(per_trip)
	return int(round(float(worker_count) * per_worker))


## Yiyecek HUD: toplama − tüketim = net (hepsi tam sayı).
func get_food_daily_balance() -> Dictionary:
	var gatherers: int = _count_gather_workers_for_resource("food")
	var gather: int = _estimate_daily_basic_gather_units("food", gatherers)
	var eat: int = int(_estimate_daily_food_consumption()) + _count_active_soldiers()
	return {
		"gatherers": gatherers,
		"gather": gather,
		"eat": eat,
		"net": gather - eat,
		"trip_yield": _gather_yield_per_trip("food") + int(_get_gather_trip_modifiers("food").get("bonus_yield", 0)),
	}


## Felaket/etki yüzünden sefer başarısı belirsizse true (HUD ? işareti).
func is_gather_projection_uncertain(resource_type: String) -> bool:
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return false
	if resource_type not in BASE_RESOURCE_TYPES:
		return false
	if _count_gather_workers_for_resource(resource_type) <= 0:
		return false
	var empty_p: float = float(_get_gather_trip_modifiers(resource_type).get("empty_chance", 0.0))
	return empty_p > 0.001

const DISASTER_EVENT_TO_RESOURCE: Dictionary = {
	"drought": "food",
	"famine": "food",
	"pest": "wood",
	"wolf_attack": "stone",
}

const DISASTER_EVENT_LABEL_KEYS: Dictionary = {
	"drought": "hud.disaster_drought",
	"famine": "hud.disaster_famine",
	"pest": "hud.disaster_pest",
	"wolf_attack": "hud.disaster_wolf",
	"worker_strike": "hud.disaster_strike",
	"severe_storm": "hud.disaster_storm",
	"weather_blessing": "hud.disaster_blessing",
	"plague": "hud.disaster_plague",
	"disease": "hud.disaster_plague",
}

const PLAGUE_MORALE_PENALTY := 10.0

## HUD: kaynak satırına eklenecek felaket/etki uyarıları (resource_key → metin listesi).
func get_resource_disaster_hints() -> Dictionary:
	var hints: Dictionary = {}
	var tm := get_node_or_null("/root/TimeManager")
	var current_day: int = int(tm.get_day()) if tm and tm.has_method("get_day") else 0

	for ev in events_active:
		_collect_disaster_hint_from_event(hints, ev, current_day)

	var wm := get_node_or_null("/root/WorldManager")
	if wm != null and wm.get("active_events") != null:
		for ev in wm.active_events:
			if ev is Dictionary:
				_collect_disaster_hint_from_event(hints, ev, current_day)

	var soldier_count := _count_active_soldiers()
	if soldier_count > 0:
		_push_disaster_hint(hints, "food", tr("hud.disaster_soldier_rations") % soldier_count)

	return hints

func _collect_disaster_hint_from_event(hints: Dictionary, ev: Dictionary, current_day: int) -> void:
	var event_type := String(ev.get("type", ""))
	if event_type.is_empty():
		return
	var days_left := _disaster_event_days_left(ev, current_day)
	var days_suffix := tr("hud.disaster_days") % days_left if days_left > 0 else ""

	if event_type == "worker_strike":
		var strike_res := String(ev.get("strike_resource", ""))
		if strike_res.is_empty():
			return
		var label_key: String = String(DISASTER_EVENT_LABEL_KEYS.get("worker_strike", ""))
		if label_key.is_empty():
			return
		_push_disaster_hint(hints, strike_res, tr(label_key) + days_suffix)
		return

	if event_type == "severe_storm":
		for res in BASE_RESOURCE_TYPES:
			_push_disaster_hint(hints, res, tr("hud.disaster_storm") + days_suffix)
		return
	if event_type == "plague" or event_type == "disease":
		return
	if event_type == "weather_blessing":
		for res in BASE_RESOURCE_TYPES:
			_push_disaster_hint(hints, res, tr("hud.disaster_blessing") + days_suffix)
		return

	var resource_key := String(DISASTER_EVENT_TO_RESOURCE.get(event_type, ""))
	if resource_key.is_empty():
		return
	var label_key2: String = String(DISASTER_EVENT_LABEL_KEYS.get(event_type, ""))
	if label_key2.is_empty():
		return
	_push_disaster_hint(hints, resource_key, tr(label_key2) + days_suffix)

func _disaster_event_days_left(ev: Dictionary, current_day: int) -> int:
	if ev.has("ends_day"):
		return maxi(0, int(ev.get("ends_day", current_day)) - current_day)
	var started_day := int(ev.get("started_day", current_day))
	var duration := int(ev.get("duration", 0))
	if duration > 0:
		return maxi(0, started_day + duration - current_day)
	return 0

func _push_disaster_hint(hints: Dictionary, resource_key: String, text: String) -> void:
	if text.is_empty():
		return
	if not hints.has(resource_key):
		hints[resource_key] = []
	var bucket: Array = hints[resource_key]
	if text in bucket:
		return
	bucket.append(text)

# Günlük net kaynak tahmini döndürür.
# Not: Üretim sadece çalışma saatleri için hesaplanır (24 saat varsayımı yoktur).
# Pozitif değer artış, negatif değer azalış anlamına gelir.
func get_projected_daily_resource_nets() -> Dictionary:
	var nets: Dictionary = {}
	for key in resource_levels.keys():
		nets[key] = 0.0

	var game_minutes_per_hour: float = 60.0
	var seconds_per_game_minute: float = 2.5
	var work_start_hour: int = 7
	var work_end_hour: int = 18
	if TimeManager:
		if "MINUTES_PER_HOUR" in TimeManager:
			game_minutes_per_hour = float(TimeManager.MINUTES_PER_HOUR)
		if "SECONDS_PER_GAME_MINUTE" in TimeManager:
			seconds_per_game_minute = float(TimeManager.SECONDS_PER_GAME_MINUTE)
		if "WORK_START_HOUR" in TimeManager:
			work_start_hour = int(TimeManager.WORK_START_HOUR)
		if "WORK_END_HOUR" in TimeManager:
			work_end_hour = int(TimeManager.WORK_END_HOUR)
	var work_hours_per_day: int = max(0, work_end_hour - work_start_hour)
	var work_day_seconds: float = float(work_hours_per_day) * game_minutes_per_hour * seconds_per_game_minute

	var morale_mult: float = _get_morale_multiplier()
	var prod_mult: float = (1.0 + building_bonus + caregiver_bonus) * global_multiplier

	# Temel kaynak üretimi: işçi atamasına göre.
	for res in BASE_RESOURCE_TYPES:
		var workers: int = _count_workers_for_daily_projection(res)
		if workers <= 0:
			continue
		if USE_DISTANCE_BASED_BASIC_GATHER:
			nets[res] = float(nets.get(res, 0.0)) + _estimate_daily_basic_gather_yield_adjusted(res, workers)
			continue
		var res_mult: float = float(resource_prod_multiplier.get(res, 1.0))
		var per_sec := (float(workers) / SECONDS_PER_RESOURCE_UNIT) * morale_mult * prod_mult * res_mult
		nets[res] = float(nets.get(res, 0.0)) + (per_sec * work_day_seconds)

	# İşleme binaları: output üretimi + input tüketimi (temel toplama binaları hariç).
	var placed_buildings = null
	if is_instance_valid(village_scene_instance):
		placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if placed_buildings:
		for building in placed_buildings.get_children():
			if not ("assigned_workers" in building):
				continue
			# Oduncu / taş ocağı / avcı kulübesi: sefer sistemi yukarıda sayıldı.
			if USE_DISTANCE_BASED_BASIC_GATHER and building.has_method("get_script") and building.get_script() != null:
				var bscript: Script = building.get_script()
				if bscript is GDScript:
					var bpath: String = (bscript as GDScript).resource_path
					if bpath in RESOURCE_PRODUCER_SCRIPTS.values():
						continue
			var workers_assigned := int(building.assigned_workers)
			if workers_assigned <= 0:
				continue
			var production_time := 0.0
			if "PRODUCTION_TIME" in building:
				production_time = float(building.PRODUCTION_TIME)
			elif "BREAD_PRODUCTION_TIME" in building:
				production_time = float(building.BREAD_PRODUCTION_TIME)
			if production_time <= 0.0:
				continue
			var b_res_mult: float = float(resource_prod_multiplier.get(
				String(building.produced_resource) if "produced_resource" in building else "",
				1.0
			))
			var cycles_per_day := (work_day_seconds / production_time) * float(workers_assigned) * morale_mult * prod_mult * b_res_mult

			if "produced_resource" in building:
				var produced_key := String(building.produced_resource)
				if produced_key != "":
					nets[produced_key] = float(nets.get(produced_key, 0.0)) + cycles_per_day

			if "required_resources" in building and building.required_resources is Dictionary:
				var reqs: Dictionary = building.required_resources
				for req_key in reqs.keys():
					var req_amount := float(reqs[req_key])
					nets[req_key] = float(nets.get(req_key, 0.0)) - (cycles_per_day * req_amount)

	# Köylü temel tüketimi (günlük): köylü başına 1 yemek.
	var food_eaters: int = int(_estimate_daily_food_consumption()) + _count_active_soldiers()
	nets["food"] = float(nets.get("food", 0.0)) - float(food_eaters)

	return nets

# Her frame'de temel kaynakları zamanla biriktirir
func _process(delta: float) -> void:
	_tick_basic_gather_realtime_clock()
	_tick_pending_constructions_from_clock()
	_sync_upgrade_vfx()
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
			if USE_DISTANCE_BASED_BASIC_GATHER:
				continue
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
	if economy_enabled and not _defer_economy_during_time_advance:
		var tm = get_node_or_null("/root/TimeManager")
		if tm and tm.has_method("get_day"):
			var d = tm.get_day()
			if d != _last_econ_tick_day and d > 0:
				_apply_day_transition_economy(d)
	
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
	if has_pending_construction(building_scene_path):
		return true
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


func get_building_level_for_scene(scene_path: String) -> int:
	if scene_path.is_empty() or not is_instance_valid(village_scene_instance):
		return 0
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return 0
	var best := 0
	for building in placed_buildings.get_children():
		if String(building.scene_file_path) != scene_path:
			continue
		var lvl := int(building.get("level")) if building.get("level") != null else 1
		best = maxi(best, lvl)
	return best


func get_building_upgrade_cost(building: Node) -> Dictionary:
	if not is_instance_valid(building):
		return {}
	var path := String(building.scene_file_path)
	var lvl := int(building.get("level")) if building.get("level") != null else 1
	return _BuildingUpgradeConfig.get_cost(path, lvl + 1)


func can_pay_village_cost(cost: Dictionary) -> bool:
	if cost.is_empty():
		return false
	if int(cost.get("gold", 0)) > GlobalPlayerData.gold:
		return false
	for key in cost.keys():
		var key_str := String(key)
		if key_str == "gold":
			continue
		if int(cost[key]) > int(resource_levels.get(key_str, 0)):
			return false
	return true


func try_pay_village_cost(cost: Dictionary) -> bool:
	if not can_pay_village_cost(cost):
		return false
	var gold_paid := int(cost.get("gold", 0))
	if gold_paid > 0:
		GlobalPlayerData.add_gold(-gold_paid)
	for key in cost.keys():
		var key_str := String(key)
		if key_str == "gold":
			continue
		var amt := int(cost[key])
		if amt > 0:
			resource_levels[key_str] = int(resource_levels.get(key_str, 0)) - amt
	emit_signal("village_data_changed")
	return true


func format_village_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	var gold := int(cost.get("gold", 0))
	if gold > 0:
		parts.append("%d altın" % gold)
	for key in cost.keys():
		var key_str := String(key)
		if key_str == "gold":
			continue
		var amt := int(cost[key])
		if amt <= 0:
			continue
		var label := key_str
		var lm := get_node_or_null("/root/LocaleManager")
		if lm and lm.has_method("get_resource_name"):
			label = String(lm.call("get_resource_name", key_str))
		parts.append("%s ×%d" % [label, amt])
	return ", ".join(parts)


func get_building_display_name_for_scene(scene_path: String) -> String:
	match scene_path:
		"res://village/buildings/WoodcutterCamp.tscn": return "Odun Kampı"
		"res://village/buildings/StoneMine.tscn": return "Taş Madeni"
		"res://village/buildings/HunterGathererHut.tscn": return "Avcı Kulübesi"
		"res://village/buildings/Well.tscn": return "Kuyu"
		"res://village/buildings/Sawmill.tscn": return "Kerestehane"
		"res://village/buildings/Brickworks.tscn": return "Tuğla Ocağı"
		"res://village/buildings/Bakery.tscn": return "Fırın"
		"res://village/buildings/Weaver.tscn": return "Dokuma Atölyesi"
		"res://village/buildings/Tailor.tscn": return "Terzi"
		"res://village/buildings/TeaHouse.tscn": return "Çay Evi"
		"res://village/buildings/SoapMaker.tscn": return "Sabun Atölyesi"
		"res://village/buildings/Blacksmith.tscn": return "Demirci"
		"res://village/buildings/Herbalist.tscn": return "Otacı"
		"res://village/buildings/Gunsmith.tscn": return "Silah Ustası"
		"res://village/buildings/Barracks.tscn": return "Kışla"
		"res://village/buildings/StorageBuilding.tscn": return "Depo"
		"res://village/buildings/InventorWorkshop.tscn": return "Mucit Odası"
		"res://village/buildings/House.tscn": return "Ev"
		_:
			return scene_path.get_file().trim_suffix(".tscn")


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
	if not UNLOCK_ALL_BUILDINGS_FOR_TESTING:
		var required_levels = requirements.get("requires_level", {})
		for resource_type in required_levels:
			var required_level = required_levels[resource_type]
			var available_level = get_available_resource_level(resource_type)
			if available_level < required_level:
				return false
		var required_buildings: Dictionary = requirements.get("requires_building", {})
		for scene_path in required_buildings.keys():
			var min_level: int = int(required_buildings[scene_path])
			if get_building_level_for_scene(String(scene_path)) < min_level:
				return false

	return true

# Boş bir inşa alanı bulur ve pozisyonunu döndürür, yoksa INF döner
func find_free_building_plot() -> Vector2:
	if not village_scene_instance:
		push_warning("[VillageManager] find_free_building_plot - VillageScene referansı yok!")
		return Vector2.INF

	var plot_markers = village_scene_instance.get_node_or_null("PlotMarkers")
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	var construction_sites = village_scene_instance.get_node_or_null("ConstructionSites")

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

		if not plot_occupied and not _plot_blocked_by_construction_sites(marker_pos, construction_sites) and not _is_plot_reserved(marker_pos):
			return marker_pos

	# Fallback: Mevcut yerleşik binaların yanına ofsetle yerleştir
	if placed_buildings:
		var count:int = placed_buildings.get_child_count()
		var base_pos: Vector2 = Vector2.ZERO
		if plot_markers and plot_markers.get_child_count() > 0 and plot_markers.get_child(0) is Node2D:
			base_pos = plot_markers.get_child(0).global_position
		var fallback_pos = base_pos + Vector2(56 * count, 0)
		if not _plot_blocked_by_construction_sites(fallback_pos, construction_sites) and not _is_plot_reserved(fallback_pos):
			return fallback_pos
	return Vector2.ZERO

func _resolve_build_plot_position(plot_position: Variant) -> Vector2:
	if plot_position is Vector2:
		var pos := plot_position as Vector2
		if is_plot_position_buildable(pos):
			return pos
		return Vector2.INF
	return find_free_building_plot()

func get_all_plot_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not is_instance_valid(village_scene_instance):
		return out
	var plot_markers := village_scene_instance.get_node_or_null("PlotMarkers")
	if not plot_markers:
		return out
	for marker in plot_markers.get_children():
		if marker is Node2D:
			out.append((marker as Node2D).global_position)
	return out

func get_building_at_plot_position(plot_pos: Vector2, tolerance: float = 12.0) -> Node2D:
	if not is_instance_valid(village_scene_instance):
		return null
	var placed := village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed:
		return null
	for building in placed.get_children():
		if building is Node2D and (building as Node2D).global_position.distance_to(plot_pos) <= tolerance:
			return building as Node2D
	return null

func is_plot_position_buildable(plot_pos: Vector2, tolerance: float = 8.0) -> bool:
	if plot_pos == Vector2.INF or plot_pos == Vector2.ZERO:
		return false
	if get_building_at_plot_position(plot_pos, tolerance) != null:
		return false
	if _is_plot_reserved(plot_pos):
		return false
	var sites: Node = null
	if is_instance_valid(village_scene_instance):
		sites = village_scene_instance.get_node_or_null("ConstructionSites")
	return not _plot_blocked_by_construction_sites(plot_pos, sites)

func is_plot_position_empty(plot_pos: Vector2, tolerance: float = 8.0) -> bool:
	return is_plot_position_buildable(plot_pos, tolerance)

func request_build_building_at_plot(building_scene_path: String, plot_position: Vector2) -> bool:
	return request_build_building(building_scene_path, plot_position)

func try_add_worker_to_building(building: Node) -> bool:
	if not is_instance_valid(building) or not building.has_method("add_worker"):
		return false
	return bool(building.call("add_worker"))

func try_remove_worker_from_building(building: Node) -> bool:
	if not is_instance_valid(building) or not building.has_method("remove_worker"):
		return false
	return bool(building.call("remove_worker"))

func try_upgrade_building(building: Node) -> bool:
	if not is_instance_valid(building) or not building.has_method("start_upgrade"):
		return false
	return bool(building.call("start_upgrade"))

func has_pending_house_floor_on(building: Node2D) -> bool:
	if not is_instance_valid(building):
		return false
	var host_key := _make_building_snapshot_key(String(building.scene_file_path), building.global_position)
	for entry in pending_constructions:
		if String(entry.get("pending_kind", "")) != "house_floor":
			continue
		if String(entry.get("host_building_key", "")) == host_key:
			return true
	return false

func get_pending_house_floor_minutes_on(building: Node2D) -> int:
	if not is_instance_valid(building):
		return 0
	var host_key := _make_building_snapshot_key(String(building.scene_file_path), building.global_position)
	for entry in pending_constructions:
		if String(entry.get("pending_kind", "")) != "house_floor":
			continue
		if String(entry.get("host_building_key", "")) == host_key:
			return int(ceil(float(entry.get("remaining_minutes", 0.0))))
	return 0

func can_build_residential_floor_on(building: Node2D) -> bool:
	if not _can_build_residential_on(building):
		return false
	if has_pending_house_floor_on(building):
		return false
	if pending_constructions.size() >= MAX_PARALLEL_CONSTRUCTIONS:
		return false
	if not can_meet_requirements(HOUSE_SCENE_PATH):
		return false
	var housing := _get_or_create_residential_housing_for_building(building, false)
	if is_instance_valid(housing):
		return housing.can_add_floor()
	return true

func request_build_house_floor_on(host_building: Node2D) -> bool:
	if not can_build_residential_floor_on(host_building):
		print("[VillageManager] ❌ Konut katı reddedildi (hedef=%s)" % (host_building.name if is_instance_valid(host_building) else "?"))
		return false

	var requirements: Dictionary = get_building_requirements(HOUSE_SCENE_PATH)
	var cost: Dictionary = requirements.get("cost", {})
	var gold_cost_raw: int = int(cost.get("gold", 0))
	var gold_charged: int = gold_cost_raw
	if gold_charged > GlobalPlayerData.gold:
		print("[VillageManager] ❌ Konut katı reddedildi — altın yetmiyor (gerekli %d)" % gold_charged)
		return false

	if gold_charged > 0:
		GlobalPlayerData.add_gold(-gold_charged)
	for resource_type in cost:
		if resource_type == "gold":
			continue
		var resource_cost := int(cost.get(resource_type, 0))
		if resource_cost > 0:
			var current_amount := int(resource_levels.get(resource_type, 0))
			resource_levels[resource_type] = current_amount - resource_cost

	var host_key := _make_building_snapshot_key(String(host_building.scene_file_path), host_building.global_position)
	print("[VillageManager] 🏠 Konut katı şantiyeye alındı (hedef: %s)" % host_building.name)
	var build_success := _queue_construction(HOUSE_SCENE_PATH, host_building.global_position, {
		"pending_kind": "house_floor",
		"host_building_key": host_key
	}, host_building)

	if build_success:
		emit_signal("village_data_changed")
		_reassign_campfire_workers_to_houses()
		return true

	if gold_charged > 0:
		GlobalPlayerData.add_gold(gold_charged)
	for resource_type in cost:
		if resource_type == "gold":
			continue
		var resource_cost := int(cost.get(resource_type, 0))
		if resource_cost > 0:
			resource_levels[resource_type] = int(resource_levels.get(resource_type, 0)) + resource_cost
	emit_signal("village_data_changed")
	return false

func demolish_building(building: Node) -> bool:
	if not is_instance_valid(building):
		return false
	if building.has_method("demolish"):
		building.call("demolish")
	else:
		building.queue_free()
	emit_signal("village_data_changed")
	return true

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
	if new_building is Node2D and String(building_scene_path) == HOUSE_SCENE_PATH:
		var housing_node = _get_or_create_residential_housing_for_building(new_building as Node2D, true)
		if is_instance_valid(housing_node):
			housing_node.configure_for_host(new_building as Node2D, 1, RESIDENTIAL_MAX_FLOORS, RESIDENTIAL_CAPACITY_PER_FLOOR)
	emit_signal("village_data_changed")
	return true

# İnşa isteğini işler (Düzeltilmiş - Her türden sadece 1 bina)
func request_build_building(building_scene_path: String, plot_position: Variant = null) -> bool:
	print("[VillageManager] 🏗️ İnşa isteği: %s" % building_scene_path.get_file())

	# 0. Ev dışındaki binalar için tekil bina kuralı devam eder.
	if building_scene_path != HOUSE_SCENE_PATH and does_building_exist(building_scene_path):
		print("[VillageManager] ❌ İnşa reddedildi - Bu türden bina zaten var")
		return false
	
	# 1. Gereksinimleri Kontrol Et
	if not can_meet_requirements(building_scene_path):
		print("[VillageManager] ❌ İnşa reddedildi - Gereksinimler karşılanmıyor")
		var reqs = get_building_requirements(building_scene_path)
		print("[VillageManager]    Gereksinimler: %s" % reqs)
		return false

	# Yeni parsel kuyruğu gerektiren inşa: paralel şantiye limiti (ev yeni parsel dahil)
	if building_scene_path != HOUSE_SCENE_PATH:
		if pending_constructions.size() >= MAX_PARALLEL_CONSTRUCTIONS:
			print("[VillageManager] ❌ İnşa reddedildi — en fazla %d paralel şantiye" % MAX_PARALLEL_CONSTRUCTIONS)
			return false

	var requirements: Dictionary = get_building_requirements(building_scene_path)
	var cost: Dictionary = requirements.get("cost", {})
	var gold_cost_raw: int = int(cost.get("gold", 0))
	var gold_mult: float = 1.0
	if building_scene_path != HOUSE_SCENE_PATH:
		gold_mult = get_pending_construction_gold_multiplier()
	var gold_charged: int = int(ceil(float(gold_cost_raw) * gold_mult)) if gold_cost_raw > 0 else 0
	if gold_charged > GlobalPlayerData.gold:
		print("[VillageManager] ❌ İnşa reddedildi — paralel şantiye altın çarpanı sonrası altın yetmiyor (gerekli %d)" % gold_charged)
		return false

	# 2. Maliyetleri Düş (Altın ve Kaynaklar)
	if gold_charged > 0:
		GlobalPlayerData.add_gold(-gold_charged)
		print("[VillageManager] 💰 Altın düşüldü: %d (çarpan %.2f, Kalan: %d)" % [gold_charged, gold_mult, GlobalPlayerData.gold])
	
	for resource_type in cost:
		if resource_type == "gold":
			continue
		
		var resource_cost = cost.get(resource_type, 0)
		if resource_cost > 0:
			var current_amount = resource_levels.get(resource_type, 0)
			resource_levels[resource_type] = current_amount - resource_cost
			print("[VillageManager] 📦 %s düşüldü: %d (Kalan: %d)" % [resource_type, resource_cost, resource_levels[resource_type]])
			emit_signal("village_data_changed")

	# 3. Eylem: ev — kat eklenebilecek hedef varsa şantiye kuyruğu (duman + süre), yoksa yeni parsel
	var build_success := false
	if building_scene_path == HOUSE_SCENE_PATH:
		var floor_host: Node2D = null
		var force_standalone_plot := plot_position is Vector2
		if not force_standalone_plot and not _should_prefer_standalone_house_build():
			floor_host = _find_residential_floor_target()
		if is_instance_valid(floor_host):
			if pending_constructions.size() >= MAX_PARALLEL_CONSTRUCTIONS:
				print("[VillageManager] ❌ Ev inşaatı reddedildi — paralel şantiye limiti (%d)" % MAX_PARALLEL_CONSTRUCTIONS)
				build_success = false
			else:
				var host_key := _make_building_snapshot_key(String(floor_host.scene_file_path), floor_host.global_position)
				print("[VillageManager] 🏠 Konut katı şantiyeye alındı (hedef: %s)" % floor_host.name)
				build_success = _queue_construction(building_scene_path, floor_host.global_position, {
					"pending_kind": "house_floor",
					"host_building_key": host_key
				}, floor_host)
		else:
			if pending_constructions.size() >= MAX_PARALLEL_CONSTRUCTIONS:
				print("[VillageManager] ❌ Ev inşaatı reddedildi — paralel şantiye limiti (%d)" % MAX_PARALLEL_CONSTRUCTIONS)
				build_success = false
			else:
				var placement_position := _resolve_build_plot_position(plot_position)
				if placement_position == Vector2.INF or placement_position == Vector2.ZERO:
					print("[VillageManager] ❌ İnşa reddedildi - Boş yer bulunamadı (pos: %s)" % placement_position)
				else:
					print("[VillageManager] ✅ Yer bulundu: %s" % placement_position)
					build_success = _queue_construction(building_scene_path, placement_position)
	else:
		var placement_position := _resolve_build_plot_position(plot_position)
		if placement_position == Vector2.INF or placement_position == Vector2.ZERO:
			print("[VillageManager] ❌ İnşa reddedildi - Boş yer bulunamadı (pos: %s)" % placement_position)
		else:
			print("[VillageManager] ✅ Yer bulundu: %s" % placement_position)
			build_success = _queue_construction(building_scene_path, placement_position)

	if build_success:
		print("[VillageManager] ✅ Bina başarıyla inşa edildi: %s" % building_scene_path.get_file())
		# Yeni barınak oluşturulduysa kamp ateşindeki köylüleri eve taşı
		_reassign_campfire_workers_to_houses()
		return true

	# Yerleştirme başarısız olduysa maliyetleri iade et
	if gold_charged > 0:
		GlobalPlayerData.add_gold(gold_charged)
		print("[VillageManager] 💰 Altın iade edildi: %d" % gold_charged)
	for resource_type in cost:
		if resource_type == "gold":
			continue
		var resource_cost = int(cost.get(resource_type, 0))
		if resource_cost > 0:
			resource_levels[resource_type] = int(resource_levels.get(resource_type, 0)) + resource_cost
	push_error("[VillageManager] ❌ Bina yerleştirme başarısız oldu!")
	emit_signal("village_data_changed")
	return false

func get_building_tier(scene_path: String) -> int:
	return int(CONSTRUCTION_TIER_BY_SCENE.get(scene_path, 1))

func get_build_duration_hours(scene_path: String) -> float:
	var tier := get_building_tier(scene_path)
	var base_hours := float(CONSTRUCTION_HOURS_BY_TIER.get(tier, 3.0))
	return clamp(base_hours, 1.0, MAX_BUILD_OR_UPGRADE_HOURS)

func get_upgrade_duration_hours_for_building(building: Node) -> float:
	if not is_instance_valid(building):
		return 1.0
	var scene_path := ""
	if "scene_file_path" in building:
		scene_path = String(building.scene_file_path)
	var tier := get_building_tier(scene_path)
	var level := int(building.get("level")) if building.get("level") != null else 1
	var base_hours := float(UPGRADE_BASE_HOURS_BY_TIER.get(tier, 2.0))
	var scaled := base_hours * pow(1.7, max(0, level - 1))
	return clamp(scaled, 1.0, MAX_BUILD_OR_UPGRADE_HOURS)

func get_upgrade_duration_seconds_for_building(building: Node) -> float:
	return _game_hours_to_real_seconds(get_upgrade_duration_hours_for_building(building))

func prepare_building_upgrade(building: Node) -> void:
	if not is_instance_valid(building):
		return
	if not ("upgrade_time_seconds" in building):
		return
	building.upgrade_time_seconds = get_upgrade_duration_seconds_for_building(building)

func _game_hours_to_real_seconds(game_hours: float) -> float:
	var seconds_per_game_minute := 2.5
	if TimeManager and "SECONDS_PER_GAME_MINUTE" in TimeManager:
		seconds_per_game_minute = float(TimeManager.SECONDS_PER_GAME_MINUTE)
	return game_hours * 60.0 * seconds_per_game_minute

func has_pending_construction(scene_path: String) -> bool:
	for entry in pending_constructions:
		if String(entry.get("scene_path", "")) == scene_path:
			return true
	return false

func get_pending_construction_minutes(scene_path: String) -> int:
	for entry in pending_constructions:
		if String(entry.get("scene_path", "")) == scene_path:
			return int(ceil(float(entry.get("remaining_minutes", 0.0))))
	return 0

func _queue_construction(scene_path: String, position: Vector2, extra: Dictionary = {}, vfx_vertical_anchor: Node2D = null) -> bool:
	var build_hours: float = get_build_duration_hours(scene_path)
	var total_minutes: float = max(1.0, build_hours * 60.0)
	var _tm := get_node_or_null("/root/TutorialManager")
	if _tm and _tm.has_method("is_village_tutorial_active") and _tm.is_village_tutorial_active():
		total_minutes = 0.01
	if not _reserve_build_plot(position):
		return false
	var rooftop_vfx: bool = (String(extra.get("pending_kind", "")) == "house_floor") and is_instance_valid(vfx_vertical_anchor)
	var site: Node2D = _spawn_construction_site(scene_path, position, vfx_vertical_anchor, rooftop_vfx)
	var entry: Dictionary = {
		"scene_path": scene_path,
		"position": position,
		"remaining_minutes": total_minutes,
		"total_minutes": total_minutes,
		"site_path": site.get_path() if is_instance_valid(site) else NodePath("")
	}
	for ek in extra.keys():
		entry[ek] = extra[ek]
	pending_constructions.append(entry)
	emit_signal("construction_started", scene_path, int(round(total_minutes)))
	emit_signal("village_data_changed")
	return true

func _spawn_construction_site(scene_path: String, position: Vector2, vfx_vertical_ref: Node = null, rooftop_construction: bool = false) -> Node2D:
	if not is_instance_valid(village_scene_instance):
		return null
	var parent := village_scene_instance.get_node_or_null("ConstructionSites")
	if parent == null:
		parent = Node2D.new()
		parent.name = "ConstructionSites"
		village_scene_instance.add_child(parent)
	var site := Node2D.new()
	site.name = "ConstructionSite_" + scene_path.get_file().trim_suffix(".tscn")
	site.global_position = position
	parent.add_child(site)
	var info := Label.new()
	info.name = "Info"
	info.text = "İnşaat başlıyor..."
	var vfx_node: Node = vfx_vertical_ref if is_instance_valid(vfx_vertical_ref) else null
	var offsets := _get_vfx_offsets_for_target(vfx_node, rooftop_construction)
	info.position = Vector2(-80, float(offsets.get("info_y", -190.0)))
	info.z_index = 10
	site.add_child(info)
	# Kullanıcı sonradan sprite_frames ekleyebilir: SmokeVFX / ToolVFX
	var smoke := AnimatedSprite2D.new()
	smoke.name = "SmokeVFX"
	smoke.position = Vector2(0, float(offsets.get("smoke_y", -129.0)))
	smoke.z_index = 5
	site.add_child(smoke)
	_setup_construction_fx_animation(smoke, "res://village/assets/fx/build_smoke_fx.png", 8, 10.0)
	var tool := AnimatedSprite2D.new()
	tool.name = "ToolVFX"
	tool.position = Vector2(0, float(offsets.get("tool_y", -154.0)))
	tool.z_index = 6
	site.add_child(tool)
	_setup_construction_fx_animation(tool, "res://village/assets/fx/tool_fx.png", 8, 12.0)
	return site

func _setup_construction_fx_animation(sprite: AnimatedSprite2D, texture_path: String, frame_count: int, fps: float) -> void:
	if not is_instance_valid(sprite):
		return
	if not ResourceLoader.exists(texture_path):
		return
	var tex: Texture2D = load(texture_path)
	if tex == null:
		return
	var safe_frames: int = max(1, frame_count)
	var frame_w: int = int(tex.get_width() / safe_frames)
	var frame_h: int = tex.get_height()
	if frame_w <= 0 or frame_h <= 0:
		return
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", true)
	for i in range(safe_frames):
		var region := Rect2(i * frame_w, 0, frame_w, frame_h)
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = region
		frames.add_frame("default", atlas)
	sprite.sprite_frames = frames
	sprite.animation = "default"
	sprite.play("default")

func _tick_pending_constructions_from_clock() -> void:
	if not TimeManager or not TimeManager.has_method("get_total_game_minutes"):
		return
	var now_total := int(TimeManager.get_total_game_minutes())
	# Kuyruk boşken de oyun saatini takip et; aksi halde biriken (now - last) dakikası
	# bir sonraki inşa başlatıldığında tek seferde düşer ve bina anında biter.
	if pending_constructions.is_empty():
		_last_construction_total_minutes = now_total
		return
	if _last_construction_total_minutes < 0:
		_last_construction_total_minutes = now_total
		return
	var delta_minutes := now_total - _last_construction_total_minutes
	if delta_minutes <= 0:
		return
	_last_construction_total_minutes = now_total
	_advance_pending_constructions(float(delta_minutes))

func _advance_pending_constructions(delta_minutes: float) -> void:
	if delta_minutes <= 0.0 or pending_constructions.is_empty():
		return
	var village_ready: bool = is_instance_valid(village_scene_instance) and village_scene_instance.is_inside_tree()
	for i in range(pending_constructions.size() - 1, -1, -1):
		var entry: Dictionary = pending_constructions[i]
		if bool(entry.get("awaiting_placement", false)):
			continue
		var remaining: float = float(entry.get("remaining_minutes", 0.0)) - delta_minutes
		entry["remaining_minutes"] = max(0.0, remaining)
		_update_construction_site_ui(entry)
		if remaining <= 0.0:
			var scene_path := String(entry.get("scene_path", ""))
			var pos := Vector2(entry.get("position", Vector2.ZERO))
			if village_ready:
				_remove_construction_site(entry)
				var built_ok := _apply_pending_construction_completion(entry)
				_release_build_plot(pos)
				if built_ok:
					emit_signal("construction_completed", scene_path)
					_reassign_campfire_workers_to_houses()
					_try_settle_guest_villagers()
				pending_constructions.remove_at(i)
			else:
				# Köyde değilken süre bitti: parsel rezervi kalır, bina köye dönünce konur
				entry["remaining_minutes"] = 0.0
				entry["awaiting_placement"] = true
				_remove_construction_site(entry)
				pending_constructions[i] = entry
		else:
			pending_constructions[i] = entry
	emit_signal("village_data_changed")

func _finalize_awaiting_construction_placements() -> void:
	if not is_instance_valid(village_scene_instance) or not village_scene_instance.is_inside_tree():
		return
	for i in range(pending_constructions.size() - 1, -1, -1):
		var entry: Dictionary = pending_constructions[i]
		if not bool(entry.get("awaiting_placement", false)):
			continue
		var scene_path := String(entry.get("scene_path", ""))
		var pos := Vector2(entry.get("position", Vector2.ZERO))
		var built_ok := _apply_pending_construction_completion(entry)
		_release_build_plot(pos)
		if built_ok:
			emit_signal("construction_completed", scene_path)
			_reassign_campfire_workers_to_houses()
			_try_settle_guest_villagers()
		pending_constructions.remove_at(i)
	emit_signal("village_data_changed")

func _update_construction_site_ui(entry: Dictionary) -> void:
	var site_path: NodePath = entry.get("site_path", NodePath(""))
	if site_path == NodePath("") or not is_instance_valid(village_scene_instance):
		return
	var site = village_scene_instance.get_node_or_null(site_path)
	if not is_instance_valid(site):
		return
	var info: Label = site.get_node_or_null("Info")
	if is_instance_valid(info):
		var rem: float = max(0.0, float(entry.get("remaining_minutes", 0.0)))
		var total: float = max(1.0, float(entry.get("total_minutes", 1.0)))
		var pct := int(round(((total - rem) / total) * 100.0))
		var rem_hours: float = rem / 60.0
		info.text = "İnşaat: %d%% (%.1f saat)" % [pct, rem_hours]

func _remove_construction_site(entry: Dictionary) -> void:
	var site_path: NodePath = entry.get("site_path", NodePath(""))
	if site_path == NodePath("") or not is_instance_valid(village_scene_instance):
		return
	var site = village_scene_instance.get_node_or_null(site_path)
	if is_instance_valid(site):
		site.queue_free()

func _reserve_build_plot(pos: Vector2) -> bool:
	if _is_plot_reserved(pos):
		return false
	reserved_build_plots.append(pos)
	return true

func _release_build_plot(pos: Vector2) -> void:
	var idx := reserved_build_plots.size() - 1
	while idx >= 0:
		if reserved_build_plots[idx].distance_to(pos) < 1.0:
			reserved_build_plots.remove_at(idx)
		idx -= 1

func _is_plot_reserved(pos: Vector2) -> bool:
	for p in reserved_build_plots:
		if p.distance_to(pos) < 1.0:
			return true
	for entry in pending_constructions:
		var p2 := Vector2(entry.get("position", Vector2.ZERO))
		if p2.distance_to(pos) < 1.0:
			return true
	return false

func _plot_blocked_by_construction_sites(pos: Vector2, sites_root: Node) -> bool:
	if not is_instance_valid(sites_root):
		return false
	for child in sites_root.get_children():
		if child is Node2D and (child as Node2D).global_position.distance_to(pos) < 1.0:
			return true
	return false

func get_max_parallel_constructions() -> int:
	return MAX_PARALLEL_CONSTRUCTIONS

func get_pending_construction_gold_multiplier() -> float:
	var n: int = pending_constructions.size()
	return clampf(1.0 + PARALLEL_BUILD_GOLD_MULT_PER_PENDING * float(n), 1.0, PARALLEL_BUILD_GOLD_MULT_MAX)

func get_pending_construction_display_lines() -> Array[String]:
	var lines: Array[String] = []
	if pending_constructions.is_empty():
		lines.append("Aktif şantiye yok.")
		lines.append("Paralel limit: %d şantiye" % MAX_PARALLEL_CONSTRUCTIONS)
		return lines
	for entry in pending_constructions:
		var sp := String(entry.get("scene_path", ""))
		var fn := sp.get_file().trim_suffix(".tscn")
		if fn.is_empty():
			fn = sp
		if bool(entry.get("awaiting_placement", false)):
			if String(entry.get("pending_kind", "")) == "house_floor":
				lines.append("Konut katı — tamamlandı, köye dönünce yerleşecek")
			else:
				lines.append("%s — tamamlandı, köye dönünce yerleşecek" % fn)
			continue
		var rem_h: float = float(entry.get("remaining_minutes", 0.0)) / 60.0
		if String(entry.get("pending_kind", "")) == "house_floor":
			lines.append("Konut katı — ~%.1f saat kaldı" % rem_h)
		else:
			lines.append("%s — ~%.1f saat kaldı" % [fn, rem_h])
	lines.append("Paralel: %d / %d" % [pending_constructions.size(), MAX_PARALLEL_CONSTRUCTIONS])
	return lines

func get_pending_constructions_save_data() -> Array:
	var out: Array = []
	for entry in pending_constructions:
		if not entry is Dictionary:
			continue
		var pos := Vector2((entry as Dictionary).get("position", Vector2.ZERO))
		var ed2: Dictionary = entry as Dictionary
		var row: Dictionary = {
			"scene_path": String(ed2.get("scene_path", "")),
			"position": {"x": pos.x, "y": pos.y},
			"remaining_minutes": float(ed2.get("remaining_minutes", 0.0)),
			"total_minutes": float(ed2.get("total_minutes", 0.0)),
			"awaiting_placement": bool(ed2.get("awaiting_placement", false))
		}
		if ed2.has("pending_kind"):
			row["pending_kind"] = String(ed2.get("pending_kind", ""))
		if ed2.has("host_building_key"):
			row["host_building_key"] = String(ed2.get("host_building_key", ""))
		out.append(row)
	return out

func _apply_pending_constructions_from_load_buffer() -> void:
	if _pending_constructions_load_buffer.is_empty():
		return
	pending_constructions.clear()
	reserved_build_plots.clear()
	for raw in _pending_constructions_load_buffer:
		if raw is Dictionary:
			_restore_one_pending_from_save_dict(raw as Dictionary)
	_pending_constructions_load_buffer.clear()
	emit_signal("village_data_changed")

func _restore_one_pending_from_save_dict(d: Dictionary) -> void:
	var scene_path := String(d.get("scene_path", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return
	var pos := _to_vector2(d.get("position", Vector2.ZERO))
	var rem: float = float(d.get("remaining_minutes", 0.0))
	var tot: float = float(d.get("total_minutes", 0.0))
	if tot < 1.0:
		tot = maxf(1.0, rem)
	if rem < 0.0:
		rem = 0.0
	var awaiting: bool = bool(d.get("awaiting_placement", false))
	var pkind := String(d.get("pending_kind", ""))
	var hkey := String(d.get("host_building_key", ""))
	if not is_instance_valid(village_scene_instance):
		var row_off: Dictionary = {
			"scene_path": scene_path,
			"position": pos,
			"remaining_minutes": rem,
			"total_minutes": tot,
			"site_path": NodePath(""),
			"awaiting_placement": awaiting
		}
		if pkind != "":
			row_off["pending_kind"] = pkind
		if hkey != "":
			row_off["host_building_key"] = hkey
		pending_constructions.append(row_off)
		return
	if awaiting:
		var row_aw: Dictionary = {
			"scene_path": scene_path,
			"position": pos,
			"remaining_minutes": 0.0,
			"total_minutes": tot,
			"site_path": NodePath(""),
			"awaiting_placement": true
		}
		if pkind != "":
			row_aw["pending_kind"] = pkind
		if hkey != "":
			row_aw["host_building_key"] = hkey
		pending_constructions.append(row_aw)
		return
	var vfx_host: Node2D = null
	if pkind == "house_floor" and not hkey.is_empty():
		vfx_host = _find_building_by_snapshot_key(hkey)
	var rooftop_vfx: bool = pkind == "house_floor" and is_instance_valid(vfx_host)
	var site: Node2D = _spawn_construction_site(scene_path, pos, vfx_host, rooftop_vfx)
	var row_ok: Dictionary = {
		"scene_path": scene_path,
		"position": pos,
		"remaining_minutes": rem,
		"total_minutes": tot,
		"site_path": site.get_path() if is_instance_valid(site) else NodePath("")
	}
	if pkind != "":
		row_ok["pending_kind"] = pkind
	if hkey != "":
		row_ok["host_building_key"] = hkey
	pending_constructions.append(row_ok)

func on_village_scene_tree_exiting(scene: Node2D) -> void:
	if village_scene_instance != scene:
		return
	for entry in pending_constructions:
		if entry is Dictionary:
			(entry as Dictionary)["site_path"] = NodePath("")
	if is_instance_valid(_village_defense_alert):
		_village_defense_alert.queue_free()
		_village_defense_alert = null
	_last_pending_attack_banner_count = 0
	village_scene_instance = null
	Village_Player = null

func _resync_pending_construction_sites_after_scene_load() -> void:
	if pending_constructions.is_empty() or not is_instance_valid(village_scene_instance):
		return
	for entry in pending_constructions:
		if not entry is Dictionary:
			continue
		var ed := entry as Dictionary
		if bool(ed.get("awaiting_placement", false)):
			continue
		var scene_path := String(ed.get("scene_path", ""))
		var pos := Vector2(ed.get("position", Vector2.ZERO))
		var pkind2 := String(ed.get("pending_kind", ""))
		var hkey2 := String(ed.get("host_building_key", ""))
		var vfx_host2: Node2D = null
		if pkind2 == "house_floor" and not hkey2.is_empty():
			vfx_host2 = _find_building_by_snapshot_key(hkey2)
		var rooftop2: bool = pkind2 == "house_floor" and is_instance_valid(vfx_host2)
		var path: NodePath = ed.get("site_path", NodePath("")) as NodePath
		var need_spawn := true
		if path != NodePath(""):
			var n = village_scene_instance.get_node_or_null(path)
			if is_instance_valid(n):
				need_spawn = false
		if need_spawn and not scene_path.is_empty():
			var site: Node2D = _spawn_construction_site(scene_path, pos, vfx_host2, rooftop2)
			ed["site_path"] = site.get_path() if is_instance_valid(site) else NodePath("")
		_update_construction_site_ui(ed)

func _rebuild_reserved_plots_from_pending_positions() -> void:
	reserved_build_plots.clear()
	for entry in pending_constructions:
		if entry is Dictionary:
			var pos := Vector2((entry as Dictionary).get("position", Vector2.ZERO))
			reserved_build_plots.append(pos)

func _sync_upgrade_vfx() -> void:
	if not is_instance_valid(village_scene_instance):
		return
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not is_instance_valid(placed_buildings):
		return
	var currently_upgrading_ids: Dictionary = {}
	for building in placed_buildings.get_children():
		if not is_instance_valid(building):
			continue
		if not ("is_upgrading" in building):
			continue
		var upgrading: bool = bool(building.get("is_upgrading"))
		if not upgrading:
			continue
		var bid: int = int(building.get_instance_id())
		currently_upgrading_ids[bid] = true
		_ensure_upgrade_vfx_for_building(building)
		_update_upgrade_vfx_for_building(building)
	for bid_key in _active_upgrade_vfx_ids.keys():
		var bid: int = int(bid_key)
		if currently_upgrading_ids.has(bid):
			continue
		var node_path: NodePath = _active_upgrade_vfx_ids.get(bid, NodePath(""))
		if node_path != NodePath(""):
			var node = get_node_or_null(node_path)
			if is_instance_valid(node):
				node.queue_free()
		_active_upgrade_vfx_ids.erase(bid)

func _ensure_upgrade_vfx_for_building(building: Node) -> void:
	var bid: int = int(building.get_instance_id())
	if _active_upgrade_vfx_ids.has(bid):
		var existing_path: NodePath = _active_upgrade_vfx_ids.get(bid, NodePath(""))
		if existing_path != NodePath("") and is_instance_valid(get_node_or_null(existing_path)):
			return
	var root := Node2D.new()
	root.name = "UpgradeVFXRoot"
	if building is Node2D:
		root.position = Vector2.ZERO
	building.add_child(root)
	var offsets := _get_vfx_offsets_for_target(building, false)
	var info := Label.new()
	info.name = "Info"
	info.text = "Yükseltiliyor..."
	info.position = Vector2(-80, float(offsets.get("info_y", -190.0)))
	info.z_index = 10
	root.add_child(info)
	var smoke := AnimatedSprite2D.new()
	smoke.name = "SmokeVFX"
	smoke.position = Vector2(0, float(offsets.get("smoke_y", -129.0)))
	smoke.z_index = 5
	root.add_child(smoke)
	_setup_construction_fx_animation(smoke, "res://village/assets/fx/build_smoke_fx.png", 8, 10.0)
	var tool := AnimatedSprite2D.new()
	tool.name = "ToolVFX"
	tool.position = Vector2(0, float(offsets.get("tool_y", -154.0)))
	tool.z_index = 6
	root.add_child(tool)
	_setup_construction_fx_animation(tool, "res://village/assets/fx/tool_fx.png", 8, 12.0)
	_active_upgrade_vfx_ids[bid] = root.get_path()

func _update_upgrade_vfx_for_building(building: Node) -> void:
	var bid: int = int(building.get_instance_id())
	if not _active_upgrade_vfx_ids.has(bid):
		return
	var root_path: NodePath = _active_upgrade_vfx_ids.get(bid, NodePath(""))
	if root_path == NodePath(""):
		return
	var root = get_node_or_null(root_path)
	if not is_instance_valid(root):
		return
	var info: Label = root.get_node_or_null("Info")
	if not is_instance_valid(info):
		return
	var text := "Yükseltiliyor..."
	if "upgrade_timer" in building and building.get("upgrade_timer") != null:
		var timer: Timer = building.get("upgrade_timer")
		var left: float = max(0.0, float(timer.time_left))
		text = "Yükseltme: %.1f saat" % [left / 60.0]
	info.text = text

func _get_vfx_offsets_for_target(target: Node, for_rooftop_construction: bool = false) -> Dictionary:
	var base_smoke: float = -129.0
	var base_tool: float = -154.0
	var base_info: float = -190.0
	var extra_lift: float = 0.0
	if is_instance_valid(target):
		# House/ResidentialHousing: yükseltme VFX'i (for_rooftop=false) mevcut üst katın altında hizalanır;
		# yeni kat şantiyesi (for_rooftop=true) dumanı mevcut çatı hizasına (üstte çalışma) taşır.
		if target.has_method("get_current_floors") and target.get("floor_height") != null:
			var floors := int(target.call("get_current_floors"))
			var floor_h := float(target.get("floor_height"))
			if for_rooftop_construction:
				extra_lift = max(0.0, float(floors) * floor_h)
			else:
				extra_lift = max(0.0, float(floors - 1) * floor_h)
		# Dükkan üstü konut eklentisi (ResidentialHousingExtension) varsa oradan hesapla.
		var ext = target.get_node_or_null("ResidentialHousingExtension")
		if is_instance_valid(ext) and ext.has_method("get_current_floors"):
			var ext_floors := int(ext.call("get_current_floors"))
			var ext_floor_h := float(ext.get("floor_height")) if ext.get("floor_height") != null else 123.0
			var ext_lift: float = max(0.0, float(ext_floors) * ext_floor_h)
			extra_lift = max(extra_lift, ext_lift)
	return {
		"smoke_y": base_smoke - extra_lift,
		"tool_y": base_tool - extra_lift,
		"info_y": base_info - extra_lift
	}

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

		# Barınak: işten çıkmak evden çıkmak değildir — asker/köylü barınağında kalır.
		# remove_occupant yalnızca köylü köyden tamamen giderken (_remove_worker) çağrılır.

		# WorkerAssignmentUI'yi güncellemek için sinyal gönder (varsa)
		emit_signal("worker_list_changed")
		if needs_to_become_idle:
			emit_signal("village_data_changed")
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

# --- Zindan kapasite önbelleği (köy sahnesi yüklü değilken kullanılır) ---
var _cached_can_add_villager: bool = true
var _cached_can_add_cariye: bool = true

# --- Debug: Kapasite override (kurtarma minigame test için; DevConsole ile değiştirilebilir) ---
var debug_force_villager_capacity_full: bool = false   ## true ise can_add_villager false döner
var debug_force_villager_has_space: bool = false       ## true ise can_add_villager true döner
var debug_force_cariye_capacity_full: bool = false
var debug_force_cariye_has_space: bool = false

## Köydeki tüm barınakların toplam sakin/kapasite bilgisini döndürür.
## Dönüş:
##   "occupied"          — tüm barınaklardaki kayıtlı sakin sayısı (kamp ateşi dahil)
##   "capacity"          — tüm barınakların toplam kapasitesi
##   "houses"            — ev (ResidentialHousing) sayısı
##   "house_occupied"    — evlerdeki kayıtlı sakin sayısı (kamp ateşi hariç)
##   "house_capacity"    — evlerin toplam kapasitesi (kamp ateşi hariç)
##   "house_units_total" — ev birimi sayısı
##   "house_units_occupied" — içinde en az 1 sakin olan ev sayısı
func get_housing_summary() -> Dictionary:
	var capacity: int = 0
	var houses: int = 0
	var house_capacity: int = 0
	var house_units_total: int = 0
	var per_unit_occupants: Dictionary = {}
	var housing_nodes := get_tree().get_nodes_in_group("Housing")
	for node in housing_nodes:
		if not is_instance_valid(node):
			continue
		var cap := 0
		if node.has_method("get_max_capacity"):
			cap = int(node.get_max_capacity())
		capacity += cap
		if node is ResidentialHousing:
			houses += 1
			house_capacity += cap
			house_units_total += 1
			per_unit_occupants[node] = 0

	# Barınma sayacı: köylünün housing_node kaydı (uyku/gündüz geçici liste değil).
	var occupied: int = 0
	var house_occupied: int = 0
	var house_units_occupied: int = 0
	for wid in all_workers:
		var w: Node = _worker_node_from_all_workers_entry(wid, all_workers[wid], true)
		if w == null or _is_guest_worker(w):
			continue
		var hn = w.get("housing_node") if "housing_node" in w else null
		if not is_instance_valid(hn) or not hn.is_in_group("Housing"):
			continue
		occupied += 1
		if hn is ResidentialHousing:
			house_occupied += 1
			if per_unit_occupants.has(hn):
				per_unit_occupants[hn] = int(per_unit_occupants[hn]) + 1
	for unit_count in per_unit_occupants.values():
		if int(unit_count) > 0:
			house_units_occupied += 1

	return {
		"occupied": occupied,
		"capacity": capacity,
		"houses": houses,
		"house_occupied": house_occupied,
		"house_capacity": house_capacity,
		"house_units_total": house_units_total,
		"house_units_occupied": house_units_occupied,
	}

## housing_node kayıtları ile barınak occupant listelerini eşitle (uyku/atlama sonrası).
func _reconcile_housing_occupant_lists() -> void:
	for wid in all_workers:
		var w: Node = _worker_node_from_all_workers_entry(wid, all_workers[wid], true)
		if w == null or _is_guest_worker(w):
			continue
		var hn = w.get("housing_node") if "housing_node" in w else null
		if not is_instance_valid(hn) or not hn.has_method("add_occupant"):
			continue
		hn.add_occupant(w)

## Kamp ateşine atanmış köylüleri, boş kapasitesi olan evlere taşır.
## Yeni ev inşa edildiğinde çağrılır.
func _reassign_campfire_workers_to_houses() -> void:
	if not is_instance_valid(campfire_node):
		return
	# Kamp ateşine atanmış tüm geçerli işçileri topla
	var workers_to_reassign: Array = []
	for wid in all_workers:
		var entry: Dictionary = all_workers[wid]
		var w: Node = _worker_node_from_all_workers_entry(wid, entry, true)
		if w == null:
			continue
		var wh = w.get("housing_node") if "housing_node" in w else null
		if is_instance_valid(wh) and wh == campfire_node:
			workers_to_reassign.append(w)
	if workers_to_reassign.is_empty():
		return
	for worker in workers_to_reassign:
		# Kamp ateşi dışında boş yer var mı?
		var house_node := _find_available_housing()
		if not is_instance_valid(house_node) or house_node == campfire_node:
			break  # Boş ev kalmadı
		# Kamp ateşinden çıkar
		if campfire_node.has_method("remove_occupant"):
			campfire_node.remove_occupant(worker)
		# Eve taşı
		worker.housing_node = house_node
		if house_node.has_method("add_occupant"):
			house_node.add_occupant(worker)
		# Uykuya gidiş noktasını güncelle
		var viewport_width := get_tree().root.get_viewport().get_visible_rect().size.x
		if house_node.global_position.x < viewport_width / 2.0:
			worker.start_x_pos = -2500.0
		else:
			worker.start_x_pos = 2500.0
		print("[VillageManager] 🏠 Köylü kamp ateşinden eve taşındı: %s → %s" % [worker.name, house_node.name])
	if has_signal("village_data_changed"):
		emit_signal("village_data_changed")

func _ensure_guest_housing_day_listener() -> void:
	var tm: Node = get_node_or_null("/root/TimeManager")
	if not is_instance_valid(tm) or not tm.has_signal("day_changed"):
		return
	var cb := Callable(self, "_on_guest_housing_day_tick")
	if not tm.day_changed.is_connected(cb):
		tm.day_changed.connect(cb)


func _on_guest_housing_day_tick(new_day: int) -> void:
	_process_guest_departures(new_day)
	_try_settle_guest_villagers()


func get_guest_villager_count() -> int:
	var count: int = 0
	for worker_id in all_workers.keys():
		var worker: Node = _worker_node_from_all_workers_entry(worker_id, all_workers[worker_id], true)
		if _is_guest_worker(worker):
			count += 1
	return count


func _is_guest_worker(worker: Node) -> bool:
	return is_instance_valid(worker) and "is_guest_villager" in worker and bool(worker.is_guest_villager)


func _worker_appearance_to_dict(worker: Node) -> Dictionary:
	if not is_instance_valid(worker):
		return {}
	var app = worker.get("appearance") if "appearance" in worker else null
	if app == null:
		return {}
	if app.has_method("to_dict"):
		return app.to_dict()
	return {}


func _apply_worker_appearance(worker: Node, appearance_dict: Dictionary) -> void:
	if not is_instance_valid(worker):
		return
	var dict: Dictionary = appearance_dict if appearance_dict is Dictionary else {}
	if dict.is_empty():
		worker.appearance = AppearanceDB.generate_random_appearance()
	else:
		var app = VillagerAppearance.new()
		if app.has_method("from_dict"):
			app.from_dict(dict)
		worker.appearance = app
	if worker.has_method("play_animation"):
		worker.play_animation("walk")


func get_guest_urgency_for_worker(worker: Node) -> float:
	if not _is_guest_worker(worker):
		return 0.0
	var tm: Node = get_node_or_null("/root/TimeManager")
	if not is_instance_valid(tm) or not tm.has_method("get_total_game_minutes"):
		return 0.0
	var now_minutes: int = int(tm.call("get_total_game_minutes"))
	var arrival_minutes: int = -1
	if "guest_arrival_total_minutes" in worker:
		arrival_minutes = int(worker.get("guest_arrival_total_minutes"))
	if arrival_minutes < 0:
		var arrival_day: int = int(worker.get("guest_arrival_day")) if "guest_arrival_day" in worker else _get_current_game_day()
		arrival_minutes = arrival_day * TimeManager.HOURS_PER_DAY * TimeManager.MINUTES_PER_HOUR
	var deadline: int = arrival_minutes + GUEST_DEPARTURE_DAYS * TimeManager.HOURS_PER_DAY * TimeManager.MINUTES_PER_HOUR
	if now_minutes >= deadline:
		return 1.0
	var window_minutes: int = GUEST_DEPARTURE_DAYS * TimeManager.HOURS_PER_DAY * TimeManager.MINUTES_PER_HOUR
	if window_minutes <= 0:
		return 1.0
	var remaining: int = deadline - now_minutes
	return 1.0 - clampf(float(remaining) / float(window_minutes), 0.0, 1.0)


func get_guest_urgency_color(urgency: float) -> Color:
	var u: float = clampf(urgency, 0.0, 1.0)
	if u < 0.35:
		return Color(0.35, 0.92, 0.45, 1.0)
	if u < 0.65:
		return Color(0.98, 0.88, 0.28, 1.0)
	if u < 0.85:
		return Color(1.0, 0.55, 0.22, 1.0)
	return Color(0.95, 0.28, 0.28, 1.0)


func _stamp_guest_arrival_time(worker_instance: Node2D) -> void:
	var tm: Node = get_node_or_null("/root/TimeManager")
	if is_instance_valid(tm) and tm.has_method("get_total_game_minutes"):
		worker_instance.set("guest_arrival_total_minutes", int(tm.call("get_total_game_minutes")))
	else:
		worker_instance.set("guest_arrival_total_minutes", 0)
	if worker_instance.get("appearance") == null:
		_apply_worker_appearance(worker_instance, {})


func _refresh_worker_guest_hourglass(worker: Node) -> void:
	if is_instance_valid(worker) and worker.has_method("refresh_guest_hourglass"):
		worker.call("refresh_guest_hourglass")


func _get_current_game_day() -> int:
	var tm: Node = get_node_or_null("/root/TimeManager")
	if is_instance_valid(tm) and tm.has_method("get_day"):
		return int(tm.call("get_day"))
	return 1


func _finalize_guest_villager(worker_instance: Node2D, npc_info: Dictionary) -> void:
	var arrival_day: int = _get_current_game_day()
	worker_instance.housing_node = null
	worker_instance.is_guest_villager = true
	worker_instance.guest_arrival_day = arrival_day
	_stamp_guest_arrival_time(worker_instance)
	worker_instance.assigned_job_type = ""
	worker_instance.assigned_building_node = null
	_setup_guest_spawn_position(worker_instance)
	worker_instance.Initialize_Existing_Villager(npc_info)
	if "current_state" in worker_instance:
		worker_instance.current_state = 7  # SOCIALIZING — kamp ateşi civarında dolaşır
	var worker_data: Dictionary = {
		"instance": worker_instance,
		"status": "guest",
		"assigned_building": null,
		"housing_node": null
	}
	all_workers[worker_instance.worker_id] = worker_data
	total_workers += 1
	idle_workers += 1
	if worker_instance.has_method("play_animation"):
		worker_instance.play_animation("walk")
	_refresh_worker_guest_hourglass(worker_instance)
	emit_signal("village_data_changed")
	emit_signal("worker_list_changed")
	print("VillageManager: Misafir köylü (barınaksız): %s — %d gün içinde ev gerekli" % [
		npc_info["Info"]["Name"], GUEST_DEPARTURE_DAYS
	])


func _setup_guest_spawn_position(worker_instance: Node2D) -> void:
	var spawn_x: float = 0.0
	if is_instance_valid(campfire_node):
		spawn_x = campfire_node.global_position.x
		worker_instance.global_position = campfire_node.global_position + Vector2(randf_range(-80.0, 80.0), randf_range(8.0, 24.0))
	else:
		worker_instance.global_position = Vector2(randf_range(-200.0, 200.0), 20.0)
	var viewport_width: float = get_tree().root.get_viewport().get_visible_rect().size.x
	if spawn_x < viewport_width * 0.5:
		worker_instance.start_x_pos = viewport_width + 400.0
	else:
		worker_instance.start_x_pos = -400.0


func _try_settle_guest_villagers() -> void:
	if get_guest_villager_count() <= 0:
		return
	var settled: int = 0
	for worker_id in all_workers.keys():
		if settled >= get_guest_villager_count():
			break
		if _find_available_housing() == null:
			break
		var worker_data = all_workers.get(worker_id, {})
		var worker: Node2D = _worker_node_from_all_workers_entry(worker_id, worker_data, true) as Node2D
		if not _is_guest_worker(worker) or bool(worker.get("is_guest_departing")):
			continue
		if not _assign_housing(worker):
			continue
		worker.is_guest_villager = false
		worker.guest_arrival_day = -1
		worker.guest_arrival_total_minutes = -1
		worker.is_guest_departing = false
		_refresh_worker_guest_hourglass(worker)
		if worker.appearance == null:
			_apply_worker_appearance(worker, {})
		elif worker.has_method("play_animation"):
			worker.play_animation("walk")
		worker_data["status"] = "idle"
		worker_data["housing_node"] = worker.housing_node
		settled += 1
		print("VillageManager: Misafir köylü barınağa yerleşti: %s" % worker.name)
	if settled > 0:
		emit_signal("village_data_changed")
		emit_signal("worker_list_changed")


func _process_guest_departures(_current_day: int) -> void:
	var to_depart: Array[int] = []
	for worker_id in all_workers.keys():
		var worker: Node = _worker_node_from_all_workers_entry(worker_id, all_workers[worker_id], true)
		if not _is_guest_worker(worker):
			continue
		if bool(worker.get("is_guest_departing")):
			continue
		if get_guest_urgency_for_worker(worker) >= 1.0:
			to_depart.append(worker_id)
	for wid in to_depart:
		_begin_guest_departure(wid)


func _begin_guest_departure(worker_id: int) -> void:
	if not all_workers.has(worker_id):
		return
	var worker: Node2D = _worker_node_from_all_workers_entry(worker_id, all_workers[worker_id], true) as Node2D
	if not is_instance_valid(worker):
		return
	worker.is_guest_departing = true
	worker.assigned_job_type = ""
	worker.assigned_building_node = null
	if worker.has_method("get") and worker.get("current_state") != null:
		worker.current_state = 14  # Worker.State.GUEST_DEPARTING
	worker.move_target_x = worker.start_x_pos
	worker.visible = true
	_refresh_worker_guest_hourglass(worker)
	print("VillageManager: Misafir köylü köyden ayrılıyor: %s" % worker.name)


func remove_guest_villager_after_departure(worker_id: int) -> void:
	if not all_workers.has(worker_id):
		return
	var worker_data = all_workers[worker_id]
	var worker: Node = _worker_node_from_all_workers_entry(worker_id, worker_data, false)
	var display_name: String = "Köylü"
	if is_instance_valid(worker) and worker.get("NPC_Info") is Dictionary:
		var info: Dictionary = worker.NPC_Info
		if info.get("Info") is Dictionary:
			display_name = String(info["Info"].get("Name", display_name))
	all_workers.erase(worker_id)
	total_workers = maxi(0, total_workers - 1)
	idle_workers = maxi(0, idle_workers - 1)
	if is_instance_valid(worker):
		worker.queue_free()
	emit_signal("village_data_changed")
	emit_signal("worker_list_changed")
	_notify_guest_departed(display_name)


func _restore_guest_worker_from_snapshot(worker_entry: Dictionary) -> void:
	if not worker_scene or not workers_container:
		return
	var info_dict: Dictionary = worker_entry.get("npc_info", {}).duplicate(true)
	if info_dict.is_empty():
		info_dict = {"Info": {"Name": "Köylü"}, "Latest_news": [], "History": []}
	var worker_instance: Node2D = worker_scene.instantiate() as Node2D
	var desired_id: int = int(worker_entry.get("worker_id", -1))
	if desired_id >= 0:
		worker_id_counter = max(worker_id_counter, desired_id)
		worker_instance.worker_id = desired_id
		worker_instance.name = "Worker" + str(desired_id)
	else:
		worker_id_counter += 1
		worker_instance.worker_id = worker_id_counter
		worker_instance.name = "Worker" + str(worker_id_counter)
	workers_container.add_child(worker_instance)
	worker_instance.is_guest_villager = true
	worker_instance.is_guest_departing = false
	worker_instance.guest_arrival_day = int(worker_entry.get("guest_arrival_day", _get_current_game_day()))
	worker_instance.guest_arrival_total_minutes = int(worker_entry.get("guest_arrival_total_minutes", -1))
	if worker_instance.guest_arrival_total_minutes < 0:
		_stamp_guest_arrival_time(worker_instance)
	worker_instance.housing_node = null
	worker_instance.assigned_job_type = ""
	worker_instance.assigned_building_node = null
	_apply_worker_appearance(worker_instance, worker_entry.get("appearance", {}))
	_setup_guest_spawn_position(worker_instance)
	worker_instance.Initialize_Existing_Villager(info_dict)
	if "current_state" in worker_instance:
		worker_instance.current_state = 7
	all_workers[worker_instance.worker_id] = {
		"instance": worker_instance,
		"status": "guest",
		"assigned_building": null,
		"housing_node": null
	}
	total_workers += 1
	idle_workers += 1
	_refresh_worker_guest_hourglass(worker_instance)


func _notify_guest_departed(villager_name: String) -> void:
	if not is_instance_valid(village_scene_instance):
		return
	var toast: Node = village_scene_instance.get_node_or_null("TimeSkipNotification")
	if toast and toast.has_method("show_simple_toast"):
		toast.show_simple_toast(
			"Misafir ayrıldı",
			"%s barınak bulamadığı için köyden gitti." % villager_name
		)


func _should_prefer_standalone_house_build() -> bool:
	if get_guest_villager_count() > 0:
		return true
	return _find_available_housing() == null


func can_build_house_now() -> bool:
	if not can_meet_requirements(HOUSE_SCENE_PATH):
		return false
	if _should_prefer_standalone_house_build():
		var plot: Vector2 = find_free_building_plot()
		return plot != Vector2.INF and plot != Vector2.ZERO
	var floor_host: Node2D = _find_residential_floor_target()
	if is_instance_valid(floor_host):
		return true
	var plot2: Vector2 = find_free_building_plot()
	return plot2 != Vector2.INF and plot2 != Vector2.ZERO


## Köye yeni köylü eklenebilir mi? (Barınak kapasitesi)
func can_add_villager() -> bool:
	if debug_force_villager_capacity_full:
		return false
	if debug_force_villager_has_space:
		return true
	var scene_manager = get_node_or_null("/root/SceneManager")
	if scene_manager and scene_manager.get("current_scene_path") == "res://village/scenes/VillageScene.tscn":
		return _find_available_housing() != null
	return _cached_can_add_villager

## Köye yeni cariye eklenebilir mi? (Şu an sınırsız; ileride kapasite eklenebilir)
func can_add_cariye() -> bool:
	if debug_force_cariye_capacity_full:
		return false
	if debug_force_cariye_has_space:
		return true
	return _cached_can_add_cariye

## Zindana girmeden önce çağrılır; köy kapasitesini önbelleğe alır.
func record_village_capacity_for_dungeon() -> void:
	_cached_can_add_villager = _find_available_housing() != null
	# Cariye için şu an limit yok
	_cached_can_add_cariye = true

# --- Yeni Köylü Ekleme Fonksiyonu ---
func add_villager() -> void:
	# Barınak kontrolü yap - _add_new_worker() fonksiyonunu kullan
	if _add_new_worker():
		print("VillageManager: Yeni köylü eklendi. Toplam: %d, Boşta: %d" % [total_workers, idle_workers])
		emit_signal("village_data_changed") # UI güncellensin
	else:
		print("VillageManager: Yeni köylü eklenemedi - yeterli barınak yok!")

## Zindandan kurtarılan köylüyü belirli isim ve görünümle ekler. data boşsa rastgele köylü ekler.
func add_villager_with_data(data: Dictionary) -> void:
	if data.is_empty():
		add_villager()
		return
	if not worker_scene:
		return
	var worker_instance = worker_scene.instantiate()
	worker_id_counter += 1
	worker_instance.worker_id = worker_id_counter
	worker_instance.name = "Worker" + str(worker_id_counter)
	var appearance_from_data: Dictionary = {}
	if data.has("appearance") and data.appearance is Dictionary:
		appearance_from_data = data.appearance
	var npc_info := {
		"Info": {"Name": data.get("name", "Köylü")},
		"Latest_news": [],
		"History": []
	}
	if not workers_container:
		worker_instance.queue_free()
		return
	workers_container.add_child(worker_instance)
	_apply_worker_appearance(worker_instance, appearance_from_data)
	if _assign_housing(worker_instance):
		worker_instance.Initialize_Existing_Villager(npc_info)
		var worker_data: Dictionary = {
			"instance": worker_instance,
			"status": "idle",
			"assigned_building": null,
			"housing_node": worker_instance.housing_node
		}
		all_workers[worker_id_counter] = worker_data
		total_workers += 1
		idle_workers += 1
		emit_signal("village_data_changed")
		emit_signal("worker_list_changed")
		print("VillageManager: Kurtarılan köylü eklendi: %s. Toplam: %d" % [npc_info["Info"]["Name"], total_workers])
	else:
		_finalize_guest_villager(worker_instance, npc_info)


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

## Belirli bir ID ile cariye ekler (MissionManager ile senkron için; zindan kurtarma).
func add_cariye_with_id(id: int, cariye_data: Dictionary) -> void:
	cariyeler[id] = cariye_data.duplicate(true)
	cariyeler[id]["durum"] = "boşta"
	if id >= next_cariye_id:
		next_cariye_id = id + 1
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
func _ensure_time_manager_economy_hooks() -> void:
	var tm = get_node_or_null("/root/TimeManager")
	if tm == null:
		return
	if tm.has_signal("day_changed") and not tm.day_changed.is_connected(Callable(self, "_on_day_changed")):
		tm.connect("day_changed", Callable(self, "_on_day_changed"))
	if tm.has_signal("time_advanced") and not _time_advanced_connected:
		tm.connect("time_advanced", Callable(self, "_on_time_advanced"))
		_time_advanced_connected = true
	if tm.has_signal("batch_time_advance_started") and not _batch_time_advance_connected:
		tm.connect("batch_time_advance_started", Callable(self, "_on_batch_time_advance_started"))
		_batch_time_advance_connected = true
	if tm.has_method("get_day"):
		_last_econ_tick_day = tm.get_day()

func _on_day_changed(new_day: int) -> void:
	if _defer_economy_during_time_advance:
		if not _pending_economy_tick_days.has(new_day):
			_pending_economy_tick_days.append(new_day)
		return
	_apply_day_transition_economy(new_day)

func _daily_economy_tick(current_day: int) -> void:
	var demo_cfg := get_node_or_null("/root/DemoPackConfig")
	if demo_cfg and demo_cfg.has_method("on_village_day_tick"):
		demo_cfg.call("on_village_day_tick", current_day)
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
			if USE_DISTANCE_BASED_BASIC_GATHER and BASE_RESOURCE_TYPES.has(String(r)):
				produced[r] = 0
				continue
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
	var village_need := float(population) * daily_food_per_pop
	
	# Soldiers: ek günlük yiyecek ihtiyacı
	var soldier_count := _count_active_soldiers()
	if soldier_count > 0:
		var soldier_extra_food_per := 1.0
		var extra_need := float(soldier_count) * soldier_extra_food_per
		_consume_for_soldiers(extra_need)

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
		"wood", "stone", "food":
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
	var basic := ["wood", "stone", "food"]
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
	if event.get("_village_effects_applied", false):
		return
	event["_village_effects_applied"] = true
	
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
			var morale_penalty := int(effects.get("morale_penalty", 0))
			village_morale = max(0.0, village_morale + morale_penalty)
			_post_event_notification("Kıtlık başladı! Toplayıcılar bazen eli boş dönebilir.", "critical")
			
		"plague":
			village_morale = max(0.0, village_morale - PLAGUE_MORALE_PENALTY)
			_post_event_notification("Salgın hastalık! Moral düştü; köylüler hasta olabilir.", "critical")
			
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
	_check_morale_game_over()

func remove_world_event_effects(event: Dictionary) -> void:
	"""Remove world event effects when event expires"""
	if not events_enabled:
		return
	if not event.get("_village_effects_applied", false):
		return
	event["_village_effects_applied"] = false
	
	var event_type := String(event.get("type", ""))
	var effects: Dictionary = event.get("effects", {})
	
	match event_type:
		"trade_boom":
			var gold_mult := float(effects.get("gold_multiplier", 1.0))
			global_multiplier /= gold_mult
			_post_event_notification("Ticaret patlaması sona erdi.", "info")
			
		"famine":
			var morale_penalty := int(effects.get("morale_penalty", 0))
			village_morale = min(100.0, village_morale - morale_penalty)
			_post_event_notification("Kıtlık sona erdi.", "success")
			
		"plague":
			village_morale = min(100.0, village_morale + PLAGUE_MORALE_PENALTY)
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
	_check_morale_game_over()

func _enqueue_village_surface_news(
	source: String,
	facts: Dictionary,
	title: String,
	content: String,
	category: String = "village",
	color: Color = Color.ORANGE,
	subcategory: String = "info"
) -> void:
	var mm: Node = get_node_or_null("/root/MissionManager")
	if mm == null:
		return
	var news_override: Dictionary = {
		"title": title,
		"body": content,
		"category": category,
		"color": color,
		"subcategory": subcategory,
	}
	if mm.has_method("try_enqueue_news"):
		if mm.call("try_enqueue_news", source, facts, news_override):
			return
	if mm.has_method("post_news"):
		mm.call("post_news", category, title, content, color, subcategory)


func _post_event_notification(message: String, category: String) -> void:
	_enqueue_village_surface_news(
		"village_macro",
		{"macro_category": category, "message": message},
		"Dünya Olayı",
		message,
		"Köy",
		Color.WHITE,
		category
	)


func _post_village_news(title: String, content: String, subcategory: String = "warning", color: Color = Color.ORANGE) -> void:
	_enqueue_village_surface_news(
		"village_news",
		{"headline": title},
		title,
		content,
		"village",
		color,
		subcategory
	)

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

func _consume_for_soldiers(food_need: float) -> void:
	var food_need_int: int = int(food_need)
	var take_food: int = min(food_need_int, int(resource_levels.get("food", 0)))
	resource_levels["food"] = int(resource_levels.get("food", 0)) - take_food
	_last_day_shortages["soldier_food"] = max(0, food_need_int - take_food)

func _consume_for_village(village_need: float) -> void:
	var food_need_int: int = int(village_need)
	var take_food: int = min(food_need_int, int(resource_levels.get("food", 0)))
	resource_levels["food"] = int(resource_levels.get("food", 0)) - take_food
	_last_day_shortages["food"] = max(0, food_need_int - take_food)

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
		var have_medicine: int = int(resource_levels.get("medicine", 0))
		var have_food: int = int(resource_levels.get("food", 0))
		var take_med: int = min(want_med, have_medicine)
		if take_med > 0:
			resource_levels["medicine"] = have_medicine - take_med
			bonus_morale += float(take_med)
		elif have_food > 0:
			var take_food_bonus: int = min(want_med, have_food)
			resource_levels["food"] = have_food - take_food_bonus
			bonus_morale += float(take_food_bonus) * 0.5
	if pop >= 51:
		# Tea bonus
		var want_tea: int = int(ceil(float(pop) * 0.05))
		var have_tea: int = int(resource_levels.get("tea", 0))
		var have_food2: int = int(resource_levels.get("food", 0))
		var take_tea: int = min(want_tea, have_tea)
		if take_tea > 0:
			resource_levels["tea"] = have_tea - take_tea
			bonus_morale += float(take_tea)
		elif have_food2 > 0:
			var take_food_tea: int = min(want_tea, have_food2)
			resource_levels["food"] = have_food2 - take_food_tea
			bonus_morale += float(take_food_tea) * 0.5
	if bonus_morale > 0.0:
		village_morale = min(100.0, village_morale + min(5.0, bonus_morale))
	_check_morale_game_over()

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
	var take_bread: int = min(to_consume_bread, have_bread)
	resource_levels["bread"] = have_bread - take_bread
	to_consume_bread -= take_bread
	if to_consume_bread > 0:
		var take_food: int = min(to_consume_bread, have_food)
		resource_levels["food"] = have_food - take_food
		to_consume_bread -= take_food
		if to_consume_bread > 0:
			missing_any = true
			missing_bread = to_consume_bread
	if to_consume_tea > 0:
		var have_tea := int(resource_levels.get("tea", 0))
		have_food = int(resource_levels.get("food", 0))
		var take_tea: int = min(to_consume_tea, have_tea)
		if take_tea > 0:
			resource_levels["tea"] = have_tea - take_tea
			to_consume_tea -= take_tea
		if to_consume_tea > 0:
			var take_food_tea: int = min(to_consume_tea, have_food)
			resource_levels["food"] = have_food - take_food_tea
			if take_food_tea < to_consume_tea:
				missing_any = true
				missing_tea = to_consume_tea - take_food_tea
	if missing_any:
		village_morale = max(0.0, village_morale - 2.0)
		_check_morale_game_over()
		var msg := "Eksik haftalık cariye ihtiyaçları: "
		if missing_bread > 0:
			msg += "Ekmek %d " % missing_bread
		if missing_tea > 0:
			msg += "Çay %d" % missing_tea
		_enqueue_village_surface_news(
			"village_surface_cariye_shortage",
			{"missing_bread": missing_bread, "missing_tea": missing_tea},
			"Cariye ihtiyaçları karşılanamadı",
			msg.strip_edges(),
			"village",
			Color(1, 0.6, 0.2, 1),
			"warning"
		)

func _check_shortages_and_apply_morale_penalties() -> void:
	var penalty := 0.0
	var detail_lines: Array[String] = []
	for k in _last_day_shortages.keys():
		var missing := float(_last_day_shortages.get(k, 0))
		if missing > 0.0:
			penalty += 5.0 # -5 per missing type/day (simple)
			var km := String(k)
			var mi := int(missing)
			match km:
				"food":
					detail_lines.append("Yiyecek günlük ihtiyaçtan %d birim eksik kaldı." % mi)
				"soldier_food":
					detail_lines.append("Askerlerin erzakının %d birimi karşılanamadı." % mi)
	if penalty > 0.0:
		village_morale = max(0.0, village_morale - penalty)
		var body := "Temel erzak tam karşılanamadığı için köy morali düştü (toplam −%.0f)." % penalty
		if not detail_lines.is_empty():
			body += "\n\n" + "\n".join(detail_lines)
		_post_village_news("Erzak sıkıntısı", body, "warning", Color.ORANGE)
	else:
		# Slow recovery
		village_morale = min(100.0, village_morale + 1.0)
	_check_morale_game_over()
	# Reset shortages for next day
	_last_day_shortages = {"food": 0, "soldier_food": 0}

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

func _present_village_event_news(ev: Dictionary, event_level: int, dur: int, current_day: int) -> void:
	var t: String = String(ev.get("type", ""))
	var level_name: String = EVENT_LEVEL_NAMES.get(event_level, "Bilinmeyen")
	var title := "Yeni Olay: %s" % t.capitalize()
	var msg := "Seviye: %s, Süre: %d gün" % [level_name, dur]
	if t == "raid" and ev.has("raid_attack_day"):
		var days_until: int = int(ev["raid_attack_day"]) - current_day
		var attacker: String = String(ev.get("raid_attacker", "Bilinmeyen Haydutlar"))
		msg = "%s saldırısı %d gün sonra bekleniyor! Askerlerinizi hazırlayın!" % [attacker, days_until]
		title = "🚨 Baskın Uyarısı!"
	elif t == "worker_strike" and ev.has("strike_resource"):
		var res_names: Dictionary = {"wood": "Odun", "stone": "Taş", "food": "Yiyecek"}
		var reason_names: Dictionary = {
			"düşük_moral": "Düşük Moral",
			"kaynak_eksikliği": "Kaynak Eksikliği",
			"genel_hoşnutsuzluk": "Genel Hoşnutsuzluk",
		}
		msg = "%s - %s üretimi durdu (%s)" % [
			msg,
			res_names.get(ev["strike_resource"], ev["strike_resource"]),
			reason_names.get(ev.get("strike_reason", ""), ""),
		]
	var facts: Dictionary = {
		"event_type": t,
		"level": level_name,
		"duration_days": dur,
		"severity": float(ev.get("severity", 1.0)),
	}
	if t == "raid" and ev.has("raid_attack_day"):
		facts["raid_attacker"] = String(ev.get("raid_attacker", ""))
		facts["days_until"] = int(ev["raid_attack_day"]) - current_day
	if t == "worker_strike":
		facts["strike_resource"] = String(ev.get("strike_resource", ""))
		facts["strike_reason"] = String(ev.get("strike_reason", ""))
	_enqueue_village_surface_news(
		"village_event_%s" % t,
		facts,
		title,
		msg,
		"world",
		Color.ORANGE,
		"warning"
	)


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
			
			if current_morale < 40.0:
				strike_reason = "düşük_moral"
			elif food_shortage > 0:
				strike_reason = "kaynak_eksikliği"
			else:
				strike_reason = "genel_hoşnutsuzluk"
			
			# Grev yapılacak kaynak tipini seç (temel kaynaklardan biri)
			var resource_types: Array[String] = ["wood", "stone", "food"]
			resource_types.shuffle()
			ev["strike_resource"] = resource_types[0]
			ev["strike_reason"] = strike_reason
		
		# simple cooldown: 30 days
		_event_cooldowns[t] = current_day + 30
		if t != "bandit_activity":
			_present_village_event_news(ev, event_level, dur, current_day)
		return ev
	return {}

func _apply_event_effects(ev: Dictionary, from_save_load: bool = false) -> void:
	var t := String(ev.get("type", ""))
	if from_save_load and (t == "disease" or t == "raid"):
		return
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
			var fail_p: float = _event_level_empty_trip_chance(event_level)
			print("[EVENT DEBUG]   Drought: food boş sefer olasılığı %.0f%%" % (fail_p * 100.0))
		"famine":
			var fail_p2: float = _event_level_empty_trip_chance(event_level)
			print("[EVENT DEBUG]   Famine: food boş sefer olasılığı %.0f%%" % (fail_p2 * 100.0))
		"pest":
			var fail_p3: float = _event_level_empty_trip_chance(event_level)
			print("[EVENT DEBUG]   Pest: wood boş sefer olasılığı %.0f%%" % (fail_p3 * 100.0))
		"wolf_attack":
			var fail_p4: float = _event_level_empty_trip_chance(event_level)
			print("[EVENT DEBUG]   Wolf attack: stone boş sefer olasılığı %.0f%%" % (fail_p4 * 100.0))
		"severe_storm":
			var fail_p5: float = _event_level_empty_trip_chance(event_level)
			print("[EVENT DEBUG]   Severe storm: tüm temel kaynaklarda boş sefer %.0f%%" % (fail_p5 * 100.0))
			if WeatherManager:
				WeatherManager.set_storm_active(true, event_level)
		"weather_blessing":
			var bonus: int = _event_level_bonus_trip_yield(event_level)
			print("[EVENT DEBUG]   Weather blessing: temel kaynak seferine +%d bonus" % bonus)
		"worker_strike":
			var strike_resource: String = String(ev.get("strike_resource", "wood"))
			print("[EVENT DEBUG]   %s grevi: toplama seferleri eli boş (100%%)" % strike_resource.capitalize())
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
					sick_count = max(1, int(total_worker_count * 0.15))
				EventLevel.MEDIUM:
					sick_count = max(1, int(total_worker_count * 0.25))
				EventLevel.HIGH:
					sick_count = max(1, int(total_worker_count * 0.35))
			
			# Tüm işçileri hasta yapabilir (askerler dahil)
			var worker_ids_list: Array = []
			for worker_id in all_workers.keys():
				var worker_data = all_workers.get(worker_id, {})
				if not worker_data:
					continue
				var worker_instance: Node = _worker_node_from_all_workers_entry(worker_id, worker_data, true)
				if worker_instance == null:
					continue
				worker_ids_list.append(worker_id)
			
			worker_ids_list.shuffle()
			var actually_sick: int = 0
			for i in range(min(sick_count, worker_ids_list.size())):
				var worker_id = worker_ids_list[i]
				var worker_data = all_workers.get(worker_id, {})
				if not worker_data:
					continue
				var worker_instance: Node = _worker_node_from_all_workers_entry(worker_id, worker_data, true)
				if worker_instance == null:
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
			emit_signal("village_data_changed")
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
				if wm.has_method("_emit_pending_attacks_changed"):
					wm.call("_emit_pending_attacks_changed")
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
		"drought", "famine", "pest", "wolf_attack", "weather_blessing", "worker_strike":
			pass
		"severe_storm":
			print("[EVENT DEBUG]   Severe storm ended (boş sefer şansı kalktı)")
			if WeatherManager:
				WeatherManager.set_storm_active(false)
		"disease":
			# Disease event'i bittiğinde kalan hasta işçileri iyileştir
			var sick_worker_ids = ev.get("sick_worker_ids", [])
			var healed_count: int = 0
			for worker_id in sick_worker_ids:
				var worker_data = all_workers.get(worker_id, {})
				if not worker_data:
					continue
				var worker_instance: Node = _worker_node_from_all_workers_entry(worker_id, worker_data, true)
				if worker_instance == null:
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
	if day - _last_village_direct_event_day < VILLAGE_EVENT_MIN_GAP_DAYS:
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
				var final_chance = clamp(base_chance + relation_bonus, 0.02, 0.12)
				
				# Sadece tüccar eventi için özel şans
				if randf() < final_chance:
					_trigger_village_event("trade_caravan", day)
					_last_village_direct_event_day = day
					return true
	
	# Düşük moralde köy festivali şansı (mevsim döngüsü olmadan moral desteği)
	if village_morale < 45.0 and randf() < 0.06:
		var fest_cd: int = int(_village_event_cooldowns.get("village_festival", 0))
		if day >= fest_cd:
			_trigger_village_event("village_festival", day)
			_village_event_cooldowns["village_festival"] = day + 18
			_last_village_direct_event_day = day
			return true
	
	# Diğer eventler için normal şans kontrolü
	if randf() > village_daily_event_chance:
		return false
	
	# Select a random village event
	var event_pool: Array[String] = [
		"trade_caravan",      # Ticaret kervanı - altın bonusu
		"resource_discovery", # Kaynak keşfi - rastgele kaynak bonusu
		"windfall",          # Bolluk - küçük kaynak bonusu
		"village_festival",  # Köy festivali - moral + gıda
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
	_last_village_direct_event_day = day
	
	# Set cooldown (8-18 days depending on event)
	var cooldown_days: int = 8
	match selected_event:
		"trade_caravan":
			cooldown_days = 10
		"resource_discovery":
			cooldown_days = 14
		"traveler":
			cooldown_days = 12
		"immigration_wave":
			cooldown_days = 20
		"village_festival":
			cooldown_days = 18
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
			
			# Harita diplomasisi: oyuncuya dusmanca koylerden tüccar gelmez; iliski WM'den okunur.
			var eligible: Array = _build_trader_origin_candidates(settlements)
			if eligible.is_empty():
				_enqueue_village_surface_news(
					"village_surface_trade_caravan_miss",
					{"event_type": "trade_caravan_miss"},
					"📭 Karavan gelmedi",
					"Komşu yollarda gerilim var; tüccar kafilesi bu hafta köyünüze uğramadı.",
					"village",
					Color(0.85, 0.82, 0.55),
					"info"
				)
			else:
				var settlement: Dictionary = _select_settlement_for_trader(eligible)
				var trader_type = _select_trader_type_by_relation(settlement)
				if mm.has_method("add_active_trader"):
					mm.add_active_trader(settlement, day, 3, trader_type)
				print("[VillageManager] 🎉 Tüccar geldi: %s'den (Tip: %d)" % [settlement.get("name", "?"), trader_type])
		
		"resource_discovery":
			# Kaynak keşfi - rastgele kaynak bonusu
			var resource_pool: Array[String] = ["wood", "stone", "food"]
			resource_pool.shuffle()
			var discovered_resource: String = resource_pool[0]
			var amount: int = randi_range(5, 15)
			resource_levels[discovered_resource] = resource_levels.get(discovered_resource, 0) + amount
			var res_names: Dictionary = {
				"wood": "Odun",
				"stone": "Taş",
				"food": "Yiyecek",
			}
			var title := "🔍 Kaynak Keşfi"
			var content := "Köylüler bir %s deposu buldular! +%d %s eklendi." % [res_names.get(discovered_resource, discovered_resource), amount, res_names.get(discovered_resource, discovered_resource)]
			_enqueue_village_surface_news(
				"village_surface_resource_discovery",
				{"resource": discovered_resource, "amount": amount},
				title,
				content,
				"village",
				Color.CYAN,
				"info"
			)
			print("[VillageManager] 🎉 Resource discovery: +%d %s" % [amount, discovered_resource])
		
		"windfall":
			# Bolluk - küçük kaynak bonusu
			var bonus_wood: int = randi_range(2, 5)
			var bonus_stone: int = randi_range(2, 5)
			resource_levels["wood"] = resource_levels.get("wood", 0) + bonus_wood
			resource_levels["stone"] = resource_levels.get("stone", 0) + bonus_stone
			var title := "🍀 Bolluk"
			var content := "İyi bir hasat sezonu geçirdik! +%d odun, +%d taş eklendi." % [bonus_wood, bonus_stone]
			_enqueue_village_surface_news(
				"village_surface_windfall",
				{"wood": bonus_wood, "stone": bonus_stone},
				title,
				content,
				"village",
				Color.GREEN,
				"success"
			)
			print("[VillageManager] 🎉 Windfall event: +%d wood, +%d stone" % [bonus_wood, bonus_stone])
		
		"village_festival":
			var morale_bonus: int = randi_range(6, 12)
			village_morale = minf(100.0, village_morale + float(morale_bonus))
			var food_bonus: int = randi_range(4, 10)
			resource_levels["food"] = resource_levels.get("food", 0) + food_bonus
			var bread_bonus: int = randi_range(1, 3)
			if resource_levels.has("bread"):
				resource_levels["bread"] = resource_levels.get("bread", 0) + bread_bonus
			var gold_gift: int = 0
			if gpd and randf() < 0.45:
				gold_gift = randi_range(5, 18)
				if gpd.has_method("add_gold"):
					gpd.add_gold(gold_gift)
				elif "gold" in gpd:
					gpd.gold = int(gpd.gold) + gold_gift
			var title := tr("village.event.festival.title")
			var content: String = tr("village.event.festival.body") % [morale_bonus, food_bonus]
			if gold_gift > 0:
				content += " " + (tr("village.event.festival.gold_bonus") % gold_gift)
			_enqueue_village_surface_news(
				"village_surface_festival",
				{"morale_bonus": morale_bonus, "food_bonus": food_bonus, "gold_gift": gold_gift},
				title,
				content,
				"village",
				Color(1.0, 0.92, 0.55),
				"success"
			)
			var tm_fest := get_node_or_null("/root/TutorialManager")
			if tm_fest and tm_fest.has_method("enqueue_message"):
				tm_fest.enqueue_message(
					"village_festival_%d" % day,
					tr("mentor.festival.body"),
					"celebration",
					6
				)
			print("[VillageManager] 🎉 Village festival: +%d morale, +%d food" % [morale_bonus, food_bonus])
			_last_festival_day = day
		
		"traveler":
			var mission_name: String = "yeni bir görev"
			if mm and mm.has_method("offer_traveler_mission"):
				var traveler_mission = mm.offer_traveler_mission()
				if traveler_mission:
					mission_name = String(traveler_mission.name)
			var title := "🧳 Seyyah Ziyareti"
			var content := "Bir seyyah köyünüze uğradı. Görev merkezine bıraktığı not: %s." % mission_name
			_enqueue_village_surface_news(
				"village_surface_traveler",
				{"event_type": "traveler", "mission_name": mission_name},
				title,
				content,
				"village",
				Color.YELLOW,
				"info"
			)
			print("[VillageManager] 🎉 Traveler event — görev: %s" % mission_name)
		
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
			_enqueue_village_surface_news(
				"village_surface_minor_accident",
				{"resource": lost_resource, "loss": loss},
				title,
				content,
				"village",
				Color.ORANGE,
				"warning"
			)
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
				_enqueue_village_surface_news(
					"village_surface_immigration",
					{"added_count": added_count},
					title,
					content,
					"village",
					Color.CYAN,
					"success"
				)
				print("[VillageManager] 🎉 Immigration wave: +%d workers" % added_count)
			else:
				_enqueue_village_surface_news(
					"village_surface_immigration_failed",
					{"reason": "no_housing"},
					"Göç Dalgası",
					"Göçmenler geldi ama barınak yetersiz olduğu için geri döndüler.",
					"village",
					Color.YELLOW,
					"info"
				)
	var wm_world: Node = get_node_or_null("/root/WorldManager")
	if wm_world and wm_world.has_method("on_village_surface_event"):
		wm_world.call("on_village_surface_event", event_type, day)

	emit_signal("village_data_changed")

## MissionManager komsu listesi -> WM ile eslesen id'ler; hostile olanlari ele, relation'i guncelle.
func _build_trader_origin_candidates(settlements: Array) -> Array:
	var wm: Node = get_node_or_null("/root/WorldManager")
	var out: Array = []
	for s in settlements:
		if not (s is Dictionary):
			continue
		var sid: String = String(s.get("id", ""))
		if sid.is_empty():
			continue
		if wm and wm.has_method("is_settlement_hostile_to_player"):
			if bool(wm.call("is_settlement_hostile_to_player", sid)):
				continue
		var entry: Dictionary = (s as Dictionary).duplicate(true)
		if wm and wm.has_method("_get_settlement_display_name") and wm.has_method("get_relation"):
			var nm: String = String(wm.call("_get_settlement_display_name", sid))
			entry["relation"] = int(wm.call("get_relation", "Köy", nm))
		out.append(entry)
	return out

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

func reapply_active_event_effects(from_save_load: bool = false) -> void:
	"""Kayıt yüklemeden sonra çağrılır: Aktif event'lerin effect'lerini yeniden uygular (Bandit Activity → MM bayrakları vb.).
	from_save_load: true ise görevler/WM zaten kayıttan geldiği için disease (rastgele hasta) ve raid (çift saldırı zamanı) atlanır.
	Kayıtta üretim çarpanları varsa kuraklık vb. tekrar çarpılmaz (_production_multipliers_restored_from_save)."""
	const PROD_TYPES: Array[String] = ["drought", "famine", "pest", "wolf_attack", "severe_storm", "weather_blessing", "worker_strike"]
	for ev in events_active:
		var ev_type := String(ev.get("type", ""))
		if from_save_load and _production_multipliers_restored_from_save and ev_type in PROD_TYPES:
			continue
		_apply_event_effects(ev, from_save_load)

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
		var worker_data: Dictionary = all_workers[wid]
		var inst: Node = _worker_node_from_all_workers_entry(wid, worker_data, true)
		if inst == null:
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
		var worker_data: Dictionary = all_workers[wid]
		var inst: Node = _worker_node_from_all_workers_entry(wid, worker_data, true)
		if inst == null:
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
	if is_instance_valid(building):
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
	
	# İşçinin atamasını kaldır (bina geçersiz olsa bile)
	var was_working: bool = false
	if is_instance_valid(worker_instance) and "assigned_job_type" in worker_instance:
		was_working = not String(worker_instance.assigned_job_type).is_empty()
		worker_instance.assigned_job_type = ""
		worker_instance.assigned_building_node = null
	
	# Idle sayısını artır (eğer çalışıyorsa)
	if was_working:
		idle_workers += 1
	
	# Aktif toplama seferini iptal et (hasta köylü sahada çalışmaz).
	if basic_gather_expeditions_by_worker.has(worker_id):
		basic_gather_expeditions_by_worker.erase(worker_id)
	emit_signal("village_data_changed")

func _check_and_heal_sick_workers(current_day: int) -> void:
	"""Her gün hasta işçileri kontrol et: İlaç varsa iyileştir, yoksa moral düşür."""
	var sick_workers: Array = []
	var total_sick: int = 0
	
	# Tüm hasta işçileri bul
	for worker_id in all_workers.keys():
		var worker_data = all_workers.get(worker_id, {})
		if not worker_data:
			continue
		var worker_instance: Node = _worker_node_from_all_workers_entry(worker_id, worker_data, true)
		if worker_instance == null:
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
		_check_morale_game_over()
		_post_village_news(
			"Hastalık baskısı",
			"Yeterli ilaç olmadığı için %d işçi hala hasta. Bu durum köy morali üzerinde baskı yaratıyor (tahmini −%.0f)." % [still_sick, morale_loss],
			"warning",
			Color(1.0, 0.45, 0.35, 1.0)
		)
		print("[DISEASE DEBUG] %d işçi hala hasta, moral düştü: -%.1f (Toplam hasta: %d, İyileşen: %d)" % [still_sick, morale_loss, total_sick, healed_count])
	
	if healed_count > 0:
		print("[DISEASE DEBUG] %d işçi ilaçla iyileşti (Kalan ilaç: %d)" % [healed_count, medicine_count])
		emit_signal("village_data_changed")

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

func _check_morale_game_over() -> void:
	if village_morale <= 0.0:
		morale_game_over.emit()
		print("[VillageManager] Moral 0 - oyun kaybı (morale_game_over)")

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
		
		if current_morale < 40.0:
			strike_reason = "düşük_moral"
		elif food_shortage > 0:
			strike_reason = "kaynak_eksikliği"
		else:
			strike_reason = "genel_hoşnutsuzluk"
		
		var resource_types: Array[String] = ["wood", "stone", "food"]
		resource_types.shuffle()
		ev["strike_resource"] = resource_types[0]
		ev["strike_reason"] = strike_reason
	
	# Cooldown'u atla (test için)
	# _event_cooldowns[event_type] = day + 30
	
	if event_type != "bandit_activity":
		_present_village_event_news(ev, event_level, dur, day)
	
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
				for r in ["wood", "stone", "food"]:
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


func _add_new_worker(NPC_Info = {}, saved_appearance: Dictionary = {}) -> bool:
	if not worker_scene:
		#printerr("VillageManager: Worker scene not loaded!")
		return false
	
	var worker_instance = worker_scene.instantiate()
	worker_id_counter += 1
	worker_instance.worker_id = worker_id_counter
	worker_instance.name = "Worker" + str(worker_id_counter)
	
	var npc_dict: Dictionary = NPC_Info if NPC_Info is Dictionary else {}
	# Kayıtlı köylü: kimlik ve görünüm _ready'den önce — rastgele isim/görünüm üretimini önler.
	if not npc_dict.is_empty():
		worker_instance.NPC_Info = npc_dict.duplicate(true)
	if not saved_appearance.is_empty():
		_apply_worker_appearance(worker_instance, saved_appearance)
	elif npc_dict.is_empty():
		if worker_instance.has_method("update_visuals"):
			worker_instance.appearance = AppearanceDB.generate_random_appearance()

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
	worker_instance.Initialize_Existing_Villager(npc_dict)
	if not saved_appearance.is_empty() and worker_instance.has_method("update_visuals"):
		worker_instance.update_visuals()
		
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
	
	# Her çağrıda sahnedeki eski cariye instance'larını temizle ki
	# MissionManager.concubines'deki her ID için SADECE bir NPC olsun.
	for child in concubines_container.get_children():
		child.queue_free()
	
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

func _try_add_residential_floor() -> bool:
	var target := _find_residential_floor_target()
	if not is_instance_valid(target):
		print("[VillageManager] ⚠️ Kat eklenecek uygun bina bulunamadı")
		return false
	print("[VillageManager] 🎯 Kat ekleme hedefi: %s (%s)" % [target.name, target.scene_file_path])
	var housing := _get_or_create_residential_housing_for_building(target, true)
	if not is_instance_valid(housing):
		print("[VillageManager] ❌ ResidentialHousing bileşeni oluşturulamadı (hedef=%s)" % target.name)
		return false
	var success: bool = housing.add_floor()
	if not success:
		print("[VillageManager] ❌ add_floor() başarısız (hedef=%s, kat=%d/%d)" % [target.name, housing.get_current_floors(), housing.max_floors])
	return success

func _find_residential_floor_target() -> Node2D:
	if not is_instance_valid(village_scene_instance):
		print("[VillageManager] _find_residential_floor_target: village_scene_instance yok")
		return null
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		print("[VillageManager] _find_residential_floor_target: PlacedBuildings yok")
		return null

	var with_existing_floors: Array = []
	var without_floors: Array = []
	var total_checked := 0
	for building in placed_buildings.get_children():
		if not (building is Node2D):
			continue
		total_checked += 1
		var building_node := building as Node2D
		if not _can_build_residential_on(building_node):
			continue
		var housing = _get_or_create_residential_housing_for_building(building_node, false)
		if is_instance_valid(housing):
			if not housing.can_add_floor():
				continue
			if housing.get_current_floors() > 0:
				with_existing_floors.append(building_node)
			else:
				without_floors.append(building_node)
		else:
			without_floors.append(building_node)

	print("[VillageManager] _find_residential_floor_target: toplam=%d, mevcut katı olan=%d, katı olmayan=%d" % [total_checked, with_existing_floors.size(), without_floors.size()])
	if not with_existing_floors.is_empty():
		return with_existing_floors[0]
	if not without_floors.is_empty():
		return without_floors[0]
	return null

func _can_build_residential_on(building: Node2D) -> bool:
	if not is_instance_valid(building):
		return false
	var scene_path := String(building.scene_file_path)
	if scene_path.is_empty():
		return false
	if scene_path in RESIDENTIAL_BASE_EXCLUDED_SCENES:
		return false
	if scene_path == HOUSE_SCENE_PATH:
		return true
	for sp in VillageBuildingCategories.get_scenes_for_category(VillageBuildingCategories.Category.RESOURCE):
		if scene_path == sp:
			return true
	return false

func _get_or_create_residential_housing_for_building(building: Node2D, create_if_missing: bool) -> Node2D:
	if not is_instance_valid(building):
		return null
	if building is House:
		var house_housing := building as House
		if house_housing.max_floors != RESIDENTIAL_MAX_FLOORS or house_housing.capacity_per_floor != RESIDENTIAL_CAPACITY_PER_FLOOR:
			house_housing.configure_for_host(building, max(1, house_housing.get_current_floors()), RESIDENTIAL_MAX_FLOORS, RESIDENTIAL_CAPACITY_PER_FLOOR)
		return house_housing

	var existing = building.get_node_or_null(RESIDENTIAL_EXTENSION_NODE)
	if existing and existing is ResidentialHousing:
		return existing
	if not create_if_missing:
		return null

	# Dükkan / diğer bina üstüne ev katı ekleniyor: görsel House sahnesi kullan.
	var house_scene: PackedScene = load(HOUSE_SCENE_PATH)
	if house_scene:
		var extension: Node2D = house_scene.instantiate()
		extension.name = RESIDENTIAL_EXTENSION_NODE
		# Binanın görsel üstüne konumlandır
		extension.position = Vector2(0.0, _get_building_residential_y_offset(building))
		# Dükkanın üstüne gelen ilk kat kapılı zemin değil; pencereli üst kat olmalı.
		# is_extension=true → _sync_floor_instances() her katı upper_floor_scene ile oluşturur.
		# Bu bayrak _ready()'den önce set edilmeli.
		extension.set("is_extension", true)
		building.add_child(extension)
		# configure_for_host floors=0 → _sync_floor_instances _ready'de oluşan katı kaldırır;
		# ardından _try_add_residential_floor add_floor() çağırarak ilk katı ekler.
		if extension.has_method("configure_for_host"):
			extension.configure_for_host(building, 0, RESIDENTIAL_MAX_FLOORS, RESIDENTIAL_CAPACITY_PER_FLOOR)
		return extension
	else:
		# Fallback: görsel yoksa salt kapasite node'u
		var fallback := ResidentialHousing.new()
		fallback.name = RESIDENTIAL_EXTENSION_NODE
		fallback.position = Vector2.ZERO
		building.add_child(fallback)
		fallback.configure_for_host(building, 0, RESIDENTIAL_MAX_FLOORS, RESIDENTIAL_CAPACITY_PER_FLOOR)
		return fallback

## Binanın Sprite2D yüksekliğine bakarak, ev katlarının başlayacağı Y ofsetini döndürür.
## Negatif değer = binanın üstü.
func _get_building_residential_y_offset(building: Node2D) -> float:
	var best_top: float = INF
	for child in building.get_children():
		if child is Sprite2D:
			var spr := child as Sprite2D
			if spr.texture == null:
				continue
			var tex_h: float = float(spr.texture.get_height()) * abs(spr.scale.y)
			# Sprite2D merkezi position'da; üst kenar = position.y - tex_h/2
			var top_y: float = spr.position.y - tex_h / 2.0
			if top_y < best_top:
				best_top = top_y
	if best_top < INF:
		# RESIDENTIAL_EXTENSION_OVERLAP_PX kadar aşağı kaydırarak kat görselini
		# dükkan üst kenarıyla hizalarız (sprite kenarında şeffaf piksel payı).
		return best_top + RESIDENTIAL_EXTENSION_OVERLAP_PX
	return -100.0  # makul varsayılan

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
			var node_scene: String = ""
			if node2d.has_method("get_housing_snapshot_scene_path"):
				node_scene = String(node2d.get_housing_snapshot_scene_path())
			elif node2d.scene_file_path != "":
				node_scene = node2d.scene_file_path
			elif node2d.get_script() and node2d.get_script().resource_path.ends_with("CampFire.gd"):
				node_scene = "res://village/scenes/CampFire.tscn"
			else:
				var node_parent = node2d.get_parent()
				if node_parent is Node2D and (node_parent as Node2D).scene_file_path != "":
					node_scene = "%s#housing" % (node_parent as Node2D).scene_file_path
			if node_scene == scene_path:
				# Pozisyon yakınsa (10 piksel tolerans) eşleştir
				if node2d.global_position.distance_to(pos) < 10.0:
					return node2d
	
	return null

# Boş kapasitesi olan bir barınak (önce Ev, sonra CampFire) arar
func _find_available_housing() -> Node2D:
	_reconcile_housing_occupant_lists()
	# #print("DEBUG VillageManager: Searching for available housing...") #<<< Yorumlandı
	var housing_nodes = get_tree().get_nodes_in_group("Housing")
	# #print("DEBUG VillageManager: Found %d nodes in Housing group." % housing_nodes.size()) #<<< Yorumlandı

	# Önce kamp ateşi dışındaki tüm konut node'larını kontrol et
	for node in housing_nodes:
		if not is_instance_valid(node):
			continue
		if node == campfire_node:
			continue
		if node.has_method("can_add_occupant") and node.can_add_occupant():
			return node

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
			if _is_guest_worker(worker):
				continue
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
	var wdata: Dictionary = all_workers.get(worker_id_to_remove, {})
	var worker_instance: Node = _worker_node_from_all_workers_entry(worker_id_to_remove, wdata, true)
	if worker_instance == null:
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


func _setup_village_defense_ui() -> void:
	if village_scene_instance == null:
		return
	if is_instance_valid(_village_defense_alert):
		_village_defense_alert.queue_free()
		_village_defense_alert = null
	_village_defense_alert = VillageDefenseAlertScript.new()
	_village_defense_alert.name = "VillageDefenseAlert"
	village_scene_instance.add_child(_village_defense_alert)
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm and wm.has_method("get_pending_attacks_ui_summaries"):
		call_deferred("_on_pending_attacks_changed")


func _on_pending_attacks_changed() -> void:
	if is_instance_valid(_village_defense_alert):
		_village_defense_alert.refresh()
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm == null or not wm.has_method("get_pending_attacks_ui_summaries"):
		return
	var summaries: Array = wm.call("get_pending_attacks_ui_summaries")
	if summaries.size() <= _last_pending_attack_banner_count or summaries.is_empty() or village_scene_instance == null:
		_last_pending_attack_banner_count = summaries.size()
		return
	var urgent: Dictionary = summaries[0]
	var toast: Node = village_scene_instance.get_node_or_null("TimeSkipNotification")
	if toast and toast.has_method("show_simple_toast"):
		toast.show_simple_toast(
			"⚔ Saldırı uyarısı: %s" % String(urgent.get("attacker", "?")),
			"~%s içinde · tahmini başarı %%%d" % [
				String(urgent.get("hours_left_text", "?")),
				int(round(float(urgent.get("win_chance", 0.5)) * 100.0)),
			]
		)
	_last_pending_attack_banner_count = summaries.size()


func _on_playable_defense_required(context: Dictionary) -> void:
	if village_scene_instance == null:
		return
	var toast: Node = village_scene_instance.get_node_or_null("TimeSkipNotification")
	var attacker: String = String(context.get("attacker", "?"))
	if toast and toast.has_method("show_simple_toast"):
		toast.show_simple_toast(
			tr("defense.toast.playable.title") % attacker,
			tr("defense.toast.playable.body")
		)
	if is_instance_valid(_village_defense_alert):
		_village_defense_alert.refresh()


func try_start_playable_village_defense() -> void:
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm == null or village_scene_instance == null:
		return
	if wm.has_method("can_start_playable_defense") and not bool(wm.call("can_start_playable_defense")):
		return
	if is_instance_valid(_defense_battle_runner):
		return
	var context: Dictionary = wm.call("get_first_playable_defense_context") if wm.has_method("get_first_playable_defense_context") else {}
	if context.is_empty():
		return
	if int(context.get("soldier_count", 0)) <= 0:
		var toast: Node = village_scene_instance.get_node_or_null("TimeSkipNotification")
		if toast and toast.has_method("show_simple_toast"):
			toast.show_simple_toast(tr("defense.toast.no_soldiers.title"), tr("defense.toast.no_soldiers.body"))
		return
	if wm.has_method("mark_playable_defense_battle_started"):
		wm.call("mark_playable_defense_battle_started")
	_defense_battle_runner = VillageDefenseBattleRunnerScript.new()
	_defense_battle_runner.name = "VillageDefenseBattleRunner"
	get_tree().root.add_child(_defense_battle_runner)
	_defense_battle_runner.battle_finished.connect(_on_playable_defense_battle_finished)
	_defense_battle_runner.start_from_context(context)


func _on_playable_defense_battle_finished(outcome: Dictionary) -> void:
	_defense_battle_runner = null
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm and wm.has_method("finish_playable_defense_battle"):
		wm.call("finish_playable_defense_battle", outcome)


func _on_defense_outcome_report(report: Dictionary) -> void:
	if village_scene_instance == null:
		return
	var attacker: String = String(report.get("attacker", "?"))
	var victor: String = String(report.get("victor", "defender"))
	var defender_losses: int = int(report.get("defender_losses", 0))
	var gold_loss: int = int(report.get("gold_loss", 0))
	var morale_delta: int = int(report.get("morale_delta", 0))
	var won: bool = victor == "defender"
	var title: String = "✅ Savunma Başarılı" if won else "❌ Savunma Başarısız"
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s saldırısı sonuçlandı." % attacker)
	lines.append("")
	lines.append("Kayıp asker: %d" % defender_losses)
	if won:
		if morale_delta > 0:
			lines.append("Moral: +%d" % morale_delta)
		lines.append("Köy hasar görmedi.")
	else:
		if gold_loss > 0:
			lines.append("Kayıp altın: %d" % gold_loss)
		if morale_delta < 0:
			lines.append("Moral: %d" % morale_delta)
	if bool(report.get("alliance_defender", false)):
		lines.append("Muttefik desteği devreye girdi.")
	var dlg := AcceptDialog.new()
	dlg.title = title
	dlg.dialog_text = "\n".join(lines)
	dlg.ok_button_text = "Tamam"
	dlg.process_mode = Node.PROCESS_MODE_ALWAYS
	village_scene_instance.add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	var toast: Node = village_scene_instance.get_node_or_null("TimeSkipNotification")
	if toast and toast.has_method("show_simple_toast"):
		toast.show_simple_toast(title, lines[0])

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


## Kamp ateşi dinlen/uyu: zamanı ilerletir; köy/dünya simülasyonu time_advanced ile çalışır.
func perform_campfire_rest(total_minutes: int) -> Dictionary:
	var empty := {"ok": false}
	if total_minutes <= 0:
		return empty
	var tm := get_node_or_null("/root/TimeManager")
	if tm == null or not tm.has_method("advance_minutes"):
		return empty
	_is_leaving_village = false
	var start_day: int = tm.get_day() if tm.has_method("get_day") else 1
	var start_hour: int = tm.get_hour() if tm.has_method("get_hour") else 0
	var start_minute: int = tm.get_minute() if tm.has_method("get_minute") else 0
	_campfire_rest_skip_toast = true
	tm.advance_minutes(total_minutes)
	_campfire_rest_skip_toast = false
	return {
		"ok": true,
		"start_day": start_day,
		"start_hour": start_hour,
		"start_minute": start_minute,
		"end_day": tm.get_day() if tm.has_method("get_day") else start_day,
		"end_hour": tm.get_hour() if tm.has_method("get_hour") else start_hour,
		"end_minute": tm.get_minute() if tm.has_method("get_minute") else start_minute,
		"total_minutes": total_minutes,
	}

func sync_gather_deliveries_before_schedule() -> void:
	## Saat başı köylü rutini öncesi: sefer teslimi işaretlensin (22:00 uyku/dönüş yarışı).
	if not USE_DISTANCE_BASED_BASIC_GATHER:
		return
	var tm := get_node_or_null("/root/TimeManager")
	if tm == null or not tm.has_method("get_total_game_minutes"):
		return
	_gather_flush_completed_deliveries_up_to(int(tm.get_total_game_minutes()))


func _apply_time_of_day(hour: int) -> void:
	sync_gather_deliveries_before_schedule()
	# Worker'lar için saat kontrolü
	if workers_container != null:
		for child in workers_container.get_children():
			if child.is_in_group("cats"):
				continue
			var worker := child as Node2D
			if worker == null:
				continue
			# Önce check_hour_transition çağır (worker kendi state'ini ayarlasın)
			if worker.has_method("check_hour_transition"):
				worker.check_hour_transition(hour)
			
			# Saatlik state/konum görünürlük kararını Worker.gd yönetsin.
			# Burada zorla visible/global_position yazmak, her saat başı 1-frame kaymaya neden oluyordu
			# (kamp ateşinde uyurken sola kayma ve bina kapısında anlık görünme).
			# Bu yüzden sadece check_hour_transition çağrısı yeterli.
	
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
	basic_gather_expeditions_by_worker.clear()
	basic_gather_last_departure_day.clear()
	basic_resource_overflow.clear()
	_saved_basic_gather_expeditions.clear()
	_saved_basic_gather_last_departure_day.clear()
	_saved_basic_resource_overflow.clear()
	_saved_snapshot_time = {}
	pending_constructions.clear()
	reserved_build_plots.clear()
	_pending_constructions_load_buffer.clear()
	_last_construction_total_minutes = -1
	_pending_time_skip_notification = {}
	_is_leaving_village = false
	# New Game'de eski run'dan kalan anlik oyun-kaybi durumunu sifirla.
	village_morale = 80.0
	_last_day_shortages = {"food": 0, "soldier_food": 0}
	events_active.clear()
	_event_cooldowns.clear()
	_village_event_cooldowns.clear()
	_last_village_event_check_day = 0
	_last_festival_day = -9999
	_reset_worker_runtime_data()
	cariyeler.clear()
	gorevler.clear()
	active_missions.clear()
	next_cariye_id = 1
	next_gorev_id = 1
	worker_id_counter = 0
	# Autoload _ready() bir kez çalışır; canlı stok / ekonomi burada başlangıca çekilir.
	resource_levels = {
		"wood": 0,
		"stone": 0,
		"food": 0,
		"lumber": 0,
		"brick": 0,
		"metal": 0,
		"cloth": 0,
		"garment": 0,
		"bread": 0,
		"tea": 0,
		"medicine": 0,
		"soap": 0,
		"weapon_t1": 5,
		"weapon_t2": 0,
		"weapon_t3": 0
	}
	locked_resource_levels = {
		"wood": 0,
		"stone": 0,
		"food": 0,
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
	for _rk in BASE_RESOURCE_TYPES:
		base_production_progress[_rk] = 0.0
	global_multiplier = 1.0
	building_bonus = 0.0
	caregiver_bonus = 0.0
	resource_prod_multiplier = {
		"wood": 1.0,
		"stone": 1.0,
		"food": 1.0,
		"lumber": 1.0,
		"brick": 1.0,
		"metal": 1.0,
		"cloth": 1.0,
		"garment": 1.0,
		"bread": 1.0,
		"tea": 1.0,
		"medicine": 1.0,
		"soap": 1.0,
		"weapon_t1": 1.0,
		"weapon_t2": 1.0,
		"weapon_t3": 1.0
	}
	economy_stats_last_day = {"day": 0, "total_production": 0.0, "total_consumption": 0.0, "net": 0.0}
	_daily_production_counter = {
		"wood": 0,
		"stone": 0,
		"food": 0,
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
	_last_gather_processed_total_minutes = -1
	_production_multipliers_restored_from_save = false
	_last_econ_tick_day = 0
	_defer_economy_during_time_advance = false
	_pending_economy_tick_days.clear()
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
			if child.is_in_group("cats"):
				continue
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
			if child.is_in_group("cats"):
				continue
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


func _setup_npc_ambient_director() -> void:
	if is_instance_valid(_npc_ambient_director):
		return
	var director_script: Script = load("res://village/scripts/VillageNpcAmbientDirector.gd")
	if director_script == null:
		return
	_npc_ambient_director = Node.new()
	_npc_ambient_director.name = "NpcAmbientDirector"
	_npc_ambient_director.set_script(director_script)
	add_child(_npc_ambient_director)


func get_pending_attack_count() -> int:
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm == null or not ("pending_attacks" in wm):
		return 0
	var pending: Variant = wm.get("pending_attacks")
	if pending is Array:
		return (pending as Array).size()
	return 0


func was_village_festival_recent(within_days: int = 3) -> bool:
	if _last_festival_day < 0:
		return false
	var tm: Node = get_node_or_null("/root/TimeManager")
	if tm == null or not tm.has_method("get_current_day_count"):
		return false
	var day: int = int(tm.call("get_current_day_count"))
	return day - _last_festival_day <= within_days
