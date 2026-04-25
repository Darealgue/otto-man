extends Node2D

class_name ResidentialHousing

signal occupancy_visual_changed(window_states: Array, occupied_count: int, total_capacity: int)

@export var max_floors: int = 4
@export var capacity_per_floor: int = 2
@export var initial_floors: int = 1

var current_floors: int = 1
var _occupants: Array = []
var _host_building: Node2D = null

func _ready() -> void:
	if current_floors <= 0:
		current_floors = max(1, initial_floors)
	if not is_in_group("Housing"):
		add_to_group("Housing")
	_refresh_visual_state()

func configure_for_host(host_building: Node2D, floors: int, max_floor_limit: int, per_floor_capacity: int) -> void:
	_host_building = host_building
	max_floors = max(1, max_floor_limit)
	capacity_per_floor = max(1, per_floor_capacity)
	current_floors = clamp(floors, 0, max_floors)
	_refresh_visual_state()

func set_current_floors(floors: int) -> void:
	current_floors = clamp(floors, 0, max_floors)
	_refresh_visual_state()

func can_add_floor() -> bool:
	return current_floors < max_floors

func add_floor() -> bool:
	if not can_add_floor():
		print("[ResidentialHousing] ⚠️ Kat eklenemedi: max=%d, current=%d (host=%s)" % [max_floors, current_floors, _describe_host()])
		return false
	current_floors += 1
	print("[ResidentialHousing] 🏠 Kat eklendi: yeni kat sayısı=%d, kapasite=%d (host=%s)" % [current_floors, get_max_capacity(), _describe_host()])
	_refresh_visual_state()
	return true

func remove_top_floor() -> Array:
	if current_floors <= 0:
		return []
	current_floors -= 1
	var max_capacity := get_max_capacity()
	var displaced: Array = []
	_prune_invalid_occupants()
	while _occupants.size() > max_capacity:
		displaced.append(_occupants.pop_back())
	_refresh_visual_state()
	return displaced

func get_current_floors() -> int:
	return current_floors

# Evde kayıtlı kalıcı sakin sayısı (iş/dolaşma fark etmez).
func get_occupant_count() -> int:
	_prune_invalid_occupants()
	return _occupants.size()

# Şu an evde (uyuyor/dinleniyor) olan sakin sayısı; pencere aydınlatması vb. için.
func get_residents_at_home_count() -> int:
	_prune_invalid_occupants()
	var count := 0
	for occupant in _occupants:
		if _is_occupant_home(occupant):
			count += 1
	return count

func get_max_capacity() -> int:
	return max(0, current_floors * capacity_per_floor)

func can_add_occupant() -> bool:
	return get_occupant_count() < get_max_capacity()

func add_occupant(worker: Node) -> bool:
	_prune_invalid_occupants()
	if worker in _occupants:
		return true
	if not can_add_occupant():
		return false
	_occupants.append(worker)
	_refresh_visual_state()
	return true

func remove_occupant(worker: Node = null) -> bool:
	if worker == null:
		if _occupants.is_empty():
			return true
		_occupants.remove_at(_occupants.size() - 1)
		_refresh_visual_state()
		return true
	_occupants.erase(worker)
	_refresh_visual_state()
	return true

func get_window_states() -> Array:
	var at_home := get_residents_at_home_count()
	var slots := get_max_capacity()
	var states: Array = []
	for i in range(slots):
		states.append(i < at_home)
	return states

func get_housing_snapshot_scene_path() -> String:
	var host = _resolve_host_building()
	if is_instance_valid(host) and host.scene_file_path != "":
		return "%s#housing" % host.scene_file_path
	return "res://village/buildings/House.tscn#housing"

func _resolve_host_building() -> Node2D:
	if is_instance_valid(_host_building):
		return _host_building
	if get_parent() is Node2D:
		return get_parent() as Node2D
	return self

func _refresh_visual_state() -> void:
	var states := get_window_states()
	emit_signal("occupancy_visual_changed", states, get_occupant_count(), get_max_capacity())

func _prune_invalid_occupants() -> void:
	var i := _occupants.size() - 1
	while i >= 0:
		if not is_instance_valid(_occupants[i]):
			_occupants.remove_at(i)
		i -= 1

func _is_occupant_home(occupant) -> bool:
	if not is_instance_valid(occupant):
		return false
	var state_val = occupant.get("current_state") if occupant.has_method("get") else null
	if not (state_val is int):
		return true
	# Evde sayılacak state'ler: SLEEPING(0), AWAKE_IDLE(1), SOCIALIZING(7), SICK(12), GOING_HOME_SICK(13), GOING_TO_SLEEP(8)
	return int(state_val) in [0, 1, 7, 8, 12, 13]

func _describe_host() -> String:
	var host := _resolve_host_building()
	if is_instance_valid(host):
		return "%s (%s)" % [host.name, host.scene_file_path]
	return name
