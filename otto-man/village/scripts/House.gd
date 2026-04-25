extends ResidentialHousing

class_name House

@export var ground_floor_scene: PackedScene = preload("res://village/buildings/HouseFloorGround.tscn")
@export var upper_floor_scene: PackedScene = preload("res://village/buildings/HouseFloorUpper.tscn")
@export var floor_height: float = 123.0
# Dükkan gibi başka bir binanın üstüne ev eklendiğinde true olur.
# Bu durumda zemin kat (kapılı) yerine üst kat (pencereli) sahnesi kullanılır;
# çünkü gerçek zemin katı dükkanın kendisidir.
@export var is_extension: bool = false

# Gece sayılacak saat aralığı (dahil-dışında mantığı: hour >= NIGHT_START_HOUR veya hour < NIGHT_END_HOUR)
const NIGHT_START_HOUR: int = 20
const NIGHT_END_HOUR: int = 6

var _floor_instances: Array[Node2D] = []
var _floors_container: Node2D = null
var _time_manager_ref: Node = null

func _ready() -> void:
	initial_floors = max(1, initial_floors)
	_ensure_floors_container()
	super._ready()
	_sync_floor_instances()
	_connect_time_manager()

func configure_for_host(host_building: Node2D, floors: int, max_floor_limit: int, per_floor_capacity: int) -> void:
	_ensure_floors_container()
	super.configure_for_host(host_building, floors, max_floor_limit, per_floor_capacity)
	_sync_floor_instances()

func set_current_floors(floors: int) -> void:
	super.set_current_floors(floors)
	_sync_floor_instances()

func add_floor() -> bool:
	var result := super.add_floor()
	if result:
		_sync_floor_instances()
	return result

func remove_top_floor() -> Array:
	var displaced := super.remove_top_floor()
	_sync_floor_instances()
	return displaced

# MissionCenter / VillageManager tarafından çağrılır.
# Ev için "yıkım" = en üst katı söküp düşür. Son kat da sökülürse binayı tamamen kaldır.
func demolish() -> bool:
	var vm := get_node_or_null("/root/VillageManager")
	if current_floors > 1:
		var displaced: Array = remove_top_floor()
		_release_displaced_occupants(displaced)
		print("🏗️ Üst kat kaldırıldı. Kalan kat: %d, kapasite: %d" % [current_floors, get_max_capacity()])
		if vm and vm.has_signal("village_data_changed"):
			vm.emit_signal("village_data_changed")
		return true
	# Son kat: tüm sakinleri boşalt ve binayı DEFERRED olarak sil.
	# Anında queue_free() çağrısı; aynı frame'de çalışan _apply_time_of_day gibi
	# fonksiyonların freed-instance hatasına yol açmasını önler.
	_evict_all_occupants()
	print("🏚️ Ev tamamen yıkıldı: ", name)
	call_deferred("queue_free")
	if vm and vm.has_signal("village_data_changed"):
		vm.call_deferred("emit_signal", "village_data_changed")
	return true

func _refresh_visual_state() -> void:
	super._refresh_visual_state()
	_refresh_windows()

func _ensure_floors_container() -> void:
	if _floors_container != null and is_instance_valid(_floors_container):
		return
	var existing := get_node_or_null("FloorsContainer")
	if existing is Node2D:
		_floors_container = existing
	else:
		_floors_container = Node2D.new()
		_floors_container.name = "FloorsContainer"
		add_child(_floors_container)

func _sync_floor_instances() -> void:
	_ensure_floors_container()
	while _floor_instances.size() > current_floors:
		var last: Node2D = _floor_instances.pop_back()
		if is_instance_valid(last):
			last.queue_free()
	while _floor_instances.size() < current_floors:
		var idx := _floor_instances.size()
		# is_extension=true olduğunda tüm katlar pencereli (üst kat) sprite kullanır;
		# zemin katını dükkanın kendi görseli temsil eder.
		var is_ground: bool = (idx == 0) and not is_extension
		var scene: PackedScene = ground_floor_scene if is_ground else upper_floor_scene
		if scene == null:
			break
		var instance: Node2D = scene.instantiate()
		instance.position = Vector2(0, -floor_height * idx)
		_floors_container.add_child(instance)
		_floor_instances.append(instance)
	_refresh_windows()

func _refresh_windows() -> void:
	if _floor_instances.is_empty():
		return
	var remaining := get_residents_at_home_count()
	var is_night := _is_night_now()
	for i in _floor_instances.size():
		var floor_node: Node2D = _floor_instances[i]
		if not is_instance_valid(floor_node):
			continue
		var states: Array = []
		for j in capacity_per_floor:
			if remaining > 0:
				states.append(true)
				remaining -= 1
			else:
				states.append(false)
		if floor_node.has_method("apply_window_states"):
			floor_node.apply_window_states(states, is_night)

# ------------------- TimeManager entegrasyonu -------------------

func _connect_time_manager() -> void:
	_time_manager_ref = get_node_or_null("/root/TimeManager")
	if _time_manager_ref and _time_manager_ref.has_signal("hour_changed"):
		if not _time_manager_ref.hour_changed.is_connected(_on_hour_changed):
			_time_manager_ref.hour_changed.connect(_on_hour_changed)
	# İlk kurulumda mevcut saate göre renkleri hizala
	_refresh_windows()

func _on_hour_changed(_new_hour: int) -> void:
	# Sadece gündüz/gece geçişlerinde güncelleme yapmak yeterli, ama saatlik refresh de pahalı değil.
	_refresh_windows()

func _is_night_now() -> bool:
	if _time_manager_ref == null or not is_instance_valid(_time_manager_ref):
		_time_manager_ref = get_node_or_null("/root/TimeManager")
	if _time_manager_ref == null:
		return false
	var hour := 12
	if _time_manager_ref.has_method("get_hour"):
		hour = int(_time_manager_ref.get_hour())
	elif "hours" in _time_manager_ref:
		hour = int(_time_manager_ref.hours)
	return hour >= NIGHT_START_HOUR or hour < NIGHT_END_HOUR

# ------------------- Demolish yardımcıları -------------------

func _release_displaced_occupants(workers: Array) -> void:
	for w in workers:
		if is_instance_valid(w):
			# housing_node referansını temizle → VillageManager sonraki döngüde yeniden atar
			if "housing_node" in w:
				w.housing_node = null

func _evict_all_occupants() -> void:
	# ResidentialHousing._occupants private gibi görünse de aynı sınıfı miras aldığımız için erişilebilir.
	for w in _occupants:
		if is_instance_valid(w) and "housing_node" in w:
			w.housing_node = null
	_occupants.clear()
