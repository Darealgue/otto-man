extends Node2D

# Silahçı Dükkanı (weapon üretimi)

@export var level: int = 1
@export var max_workers: int = 1
@export var assigned_workers: int = 0
@export var worker_stays_inside: bool = true

var is_upgrading: bool = false
var upgrade_timer: Timer = null
var upgrade_time_seconds: float = 15.0
@export var max_level: int = 3
const UPGRADE_COSTS = {
	2: {"gold": 40},
	3: {"gold": 80}
}

var required_resources: Dictionary = {"metal": 1, "wood": 1, "water": 1}
var produced_resource: String = "weapon"

# Fetch/buffer state
var input_buffer: Dictionary = {"metal": 0, "wood": 0, "water": 0}
var production_progress: float = 0.0
const PRODUCTION_TIME: float = 300.0
var fetch_timer: Timer = null
var fetch_target: String = ""
const FETCH_TIME_PER_UNIT: float = 3.0
var is_fetcher_out: bool = false

signal upgrade_started
signal upgrade_finished
signal state_changed

func _ready() -> void:
	upgrade_timer = Timer.new()
	upgrade_timer.one_shot = true
	upgrade_timer.timeout.connect(_on_upgrade_finished)
	add_child(upgrade_timer)
	fetch_timer = Timer.new()
	fetch_timer.one_shot = true
	fetch_timer.timeout.connect(_on_fetch_timeout)
	add_child(fetch_timer)

func get_next_upgrade_cost() -> Dictionary:
	var next_level = level + 1
	return UPGRADE_COSTS.get(next_level, {})

func start_upgrade() -> bool:
	if is_upgrading: return false
	if level >= max_level: return false
	var cost = get_next_upgrade_cost()
	var gold_cost = int(cost.get("gold", 0))
	if GlobalPlayerData.gold < gold_cost: return false
	GlobalPlayerData.add_gold(-gold_cost)
	is_upgrading = true
	upgrade_timer.wait_time = upgrade_time_seconds
	upgrade_timer.start()
	upgrade_started.emit()
	state_changed.emit()
	return true

func _on_upgrade_finished() -> void:
	is_upgrading = false
	level += 1
	max_workers = level
	upgrade_finished.emit()
	state_changed.emit()
	VillageManager.notify_building_state_changed(self)

func can_i_fetch() -> bool:
	if not is_fetcher_out:
		is_fetcher_out = true
		return true
	return false

func finished_fetching() -> void:
	is_fetcher_out = false

func _process(delta: float) -> void:
	var scaled = delta * Engine.time_scale
	if not TimeManager.is_work_time():
		return
	if assigned_workers <= 0:
		return
	for res in required_resources.keys():
		var need := int(required_resources[res])
		if int(input_buffer.get(res, 0)) < need and (fetch_timer == null or fetch_timer.is_stopped()) and not is_upgrading and not is_fetcher_out:
			if int(VillageManager.get_available_resource_level(res)) > 0 and can_i_fetch():
				fetch_target = res
				fetch_timer.wait_time = FETCH_TIME_PER_UNIT
				fetch_timer.start()
				break
	production_progress += scaled * float(assigned_workers)
	if production_progress >= PRODUCTION_TIME:
		var ok := true
		for r in required_resources.keys():
			if int(input_buffer.get(r, 0)) < int(required_resources[r]):
				ok = false
				break
		if ok:
			for r2 in required_resources.keys():
				input_buffer[r2] = int(input_buffer.get(r2, 0)) - int(required_resources[r2])
			VillageManager.resource_levels[produced_resource] = int(VillageManager.resource_levels.get(produced_resource, 0)) + 1
			VillageManager.emit_signal("village_data_changed")
		production_progress = 0.0

func _on_fetch_timeout() -> void:
	if fetch_target == "":
		finished_fetching()
		return
	var cur:int = int(VillageManager.resource_levels.get(fetch_target, 0))
	if cur > 0:
		VillageManager.resource_levels[fetch_target] = cur - 1
		input_buffer[fetch_target] = int(input_buffer.get(fetch_target, 0)) + 1
		VillageManager.emit_signal("village_data_changed")
	finished_fetching()
	fetch_target = ""

# Workers
var assigned_worker_ids: Array[int] = []
func add_worker() -> bool:
	if assigned_workers >= max_workers: return false
	var w: Node = VillageManager.register_generic_worker()
	if not is_instance_valid(w): return false
	assigned_workers += 1
	assigned_worker_ids.append(w.worker_id)
	w.assigned_job_type = "weapon"
	w.assigned_building_node = self
	VillageManager.notify_building_state_changed(self)
	return true

func remove_worker() -> bool:
	if assigned_workers <= 0 or assigned_worker_ids.is_empty(): return false
	var id = assigned_worker_ids.pop_back()
	assigned_workers -= 1
	if VillageManager.all_workers.has(id):
		var w = VillageManager.all_workers[id]["instance"]
		if is_instance_valid(w):
			w.assigned_job_type = ""
			w.assigned_building_node = null
	VillageManager.notify_building_state_changed(self)
	return true

func get_production_info() -> String:
	return "Lv." + str(level) + " • İşçi:" + str(assigned_workers) + " • Silah: (metal+odun+su)"


