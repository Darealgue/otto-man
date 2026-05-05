extends Node2D

@export var cat_scene: PackedScene
@export var max_cats: int = 3
## Aciksa kedi sayisini köylü nüfusuna göre dinamik hesaplar (tam kesin oran degil).
@export var scale_cats_with_population: bool = true
## Yaklasik oran: bu kadar köylüye 1 kedi (rastgele sapma ile).
@export var workers_per_cat_mean: float = 5.0
## Orana eklenecek rastgele sapma payi (daha "asagi yukari" dagilim).
@export var workers_per_cat_jitter: float = 1.6
## Nüfustan bagimsiz taban kedi katkisi.
@export var base_cat_bias: float = 0.35
## Hesaplanan hedefe eklenecek rastgele kedi sapmasi.
@export var target_cat_jitter: float = 0.7
## Dinamik hedef alt/ust sinirlari.
@export var dynamic_min_cats: int = 1
@export var dynamic_max_cats: int = 9
@export var spawn_threshold: float = 0.60
@export var despawn_threshold: float = 0.40
@export var min_spawn_interval: float = 3.0
@export var max_spawn_interval: float = 8.0
@export var roof_seek_chance_per_second: float = 0.055
## Çatı ROAM iken üst one-way kata çıkma denemesi (saniye başına, kedi başına).
@export var roof_upper_seek_chance_per_second: float = 0.045
## Çatı ROAM iken alt kata kontrollü inme denemesi (saniye başına, kedi başına).
@export var roof_lower_seek_chance_per_second: float = 0.07
@export var roam_margin: float = 180.0
## Köylü yürüme bandı (Worker.gd içindeki VERTICAL_RANGE_MIN/MAX ile aynı olmalı).
@export var walk_band_y_min: float = 5.0
@export var walk_band_y_max: float = 30.0
## Aciksa kedi Y bandini sahnedeki koylulere bakarak dinamik ayarlar (daha dogal yayilim).
@export var derive_walk_band_from_workers: bool = true
@export var worker_band_padding: float = 4.0
## Açıkken konsola köy kedisi / roam_bounds bilgisi (Fizik sekmesinde VillageCatsController işaretlenir).
@export var debug_cat_controller: bool = true
## İki kedi yakınsa kovalama / kaçma dene (CatPrototype.begin_chase / begin_flee).
@export var cat_play_interval_min: float = 1.3
@export var cat_play_interval_max: float = 2.8
@export var cat_play_pair_chance: float = 0.58
@export var cat_play_max_distance: float = 420.0

var _spawn_timer: float = 0.0
var _cat_social_timer: float = 0.0
var _resource_poll_timer: float = 0.0
var _prosperity_score: float = 0.0
var _cached_roof_points: Array[Dictionary] = []
var _roof_scan_timer: float = 0.0
var _population_target_update_timer: float = 0.0
var _cached_population_target_cats: int = 1
var _cat_profiles: Dictionary = {}
var _active_cat_profile_ids: Dictionary = {}
var _next_cat_profile_seq: int = 1

var _cats_container: Node2D

func _ready() -> void:
	_cats_container = get_node_or_null("../WorkersContainer") as Node2D
	if _cats_container == null:
		push_error("VillageCatsController: ../WorkersContainer bulunamadı.")
		set_process(false)
		return
	randomize()
	if cat_scene == null:
		cat_scene = preload("res://village/scenes/CatPrototype.tscn")
	_spawn_timer = randf_range(min_spawn_interval, max_spawn_interval)
	_cat_social_timer = randf_range(cat_play_interval_min, cat_play_interval_max)
	_cached_population_target_cats = _compute_population_target_cats()
	_population_target_update_timer = randf_range(2.0, 4.0)

func _process(delta: float) -> void:
	if _cats_container == null:
		return
	_resource_poll_timer -= delta
	_roof_scan_timer -= delta
	_spawn_timer -= delta
	_cat_social_timer -= delta
	_population_target_update_timer -= delta

	if _population_target_update_timer <= 0.0:
		_population_target_update_timer = randf_range(2.0, 4.0)
		_cached_population_target_cats = _compute_population_target_cats()

	if _resource_poll_timer <= 0.0:
		_resource_poll_timer = 1.0
		_refresh_active_cat_profile_ids()
		_prosperity_score = _compute_prosperity_score()
		_sync_cat_roam_bounds()
		if debug_cat_controller:
			var b := _get_roam_bounds()
			print("[VillageCats] roam_bounds pos=%s size=%s prosper=%.2f cats=%d" % [b.position, b.size, _prosperity_score, _count_cats_in_workers_container()])

	if _roof_scan_timer <= 0.0:
		_roof_scan_timer = 2.5
		_cached_roof_points = _collect_roof_points()

	var current_cats: int = _count_cats_in_workers_container()
	var target_cats: int = _get_target_cat_count()

	if _prosperity_score >= spawn_threshold and current_cats < target_cats:
		_try_spawn_cat()
	elif _prosperity_score <= despawn_threshold and current_cats > target_cats:
		_despawn_one_cat()

	_update_cats_roof_intent(delta)
	_update_cats_upper_roof_intent(delta)
	_update_cats_lower_roof_intent(delta)

	if _cat_social_timer <= 0.0:
		_cat_social_timer = randf_range(cat_play_interval_min, cat_play_interval_max)
		_try_trigger_cat_play_social()

func _try_spawn_cat() -> void:
	var hard_cap: int = _get_spawn_cap()
	if _spawn_timer > 0.0 or _count_cats_in_workers_container() >= hard_cap:
		return
	if cat_scene == null:
		return

	var cat := cat_scene.instantiate()
	var profile_id: String = _acquire_profile_id_for_spawn()
	var profile_data: Dictionary = _cat_profiles.get(profile_id, {})
	if profile_data.has("color") and cat.has_method("set_persistent_identity"):
		cat.set_persistent_identity(profile_id, profile_data.get("color", Color(1.0, 1.0, 1.0, 1.0)))
	var roam_bounds := _get_roam_bounds()
	if cat.has_method("set_roam_bounds"):
		cat.set_roam_bounds(roam_bounds)
	var spawn_pos := Vector2(
		randf_range(roam_bounds.position.x, roam_bounds.end.x),
		randf_range(roam_bounds.position.y, roam_bounds.end.y)
	)
	if cat.has_method("set_spawn_position"):
		cat.set_spawn_position(spawn_pos)
	cat.debug_motion = debug_cat_controller
	_cats_container.add_child(cat)
	_active_cat_profile_ids[profile_id] = true
	if not profile_data.has("color") and cat.has_method("get_current_color_variant"):
		_cat_profiles[profile_id] = {
			"color": cat.get_current_color_variant()
		}
	_spawn_timer = randf_range(min_spawn_interval, max_spawn_interval)

func _despawn_one_cat() -> void:
	for child in _cats_container.get_children():
		if child.is_in_group("cats"):
			var profile_id: String = _get_profile_id_from_cat(child)
			if not profile_id.is_empty():
				_active_cat_profile_ids.erase(profile_id)
			child.queue_free()
			break
	_spawn_timer = randf_range(min_spawn_interval, max_spawn_interval)

func _try_trigger_cat_play_social() -> void:
	if _cats_container == null:
		return
	if randf() > cat_play_pair_chance:
		return
	var cats: Array[Node2D] = []
	for c in _cats_container.get_children():
		if not c.is_in_group("cats"):
			continue
		if not (c is Node2D):
			continue
		if c.has_method("can_start_social_play") and c.has_method("is_in_play_state"):
			if c.can_start_social_play() and not c.is_in_play_state():
				cats.append(c as Node2D)
	if cats.size() < 2:
		return
	var md2: float = cat_play_max_distance * cat_play_max_distance
	var pairs: Array = []
	for i in range(cats.size()):
		for j in range(i + 1, cats.size()):
			var d2: float = cats[i].global_position.distance_squared_to(cats[j].global_position)
			if d2 <= md2:
				pairs.append([cats[i], cats[j]])
	if pairs.is_empty():
		return
	var pick: Array = pairs[randi() % pairs.size()]
	var ca: Node2D = pick[0] as Node2D
	var cb: Node2D = pick[1] as Node2D
	if randf() < 0.5:
		var tmp: Node2D = ca
		ca = cb
		cb = tmp
	if ca.has_method("begin_chase") and cb.has_method("begin_flee"):
		ca.begin_chase(cb)
		cb.begin_flee(ca)


func _update_cats_roof_intent(delta: float) -> void:
	if _cached_roof_points.is_empty():
		return
	for cat in _cats_container.get_children():
		if not cat.is_in_group("cats"):
			continue
		if randf() < roof_seek_chance_per_second * delta and cat.has_method("try_seek_roof"):
			cat.try_seek_roof(_cached_roof_points)


func _update_cats_upper_roof_intent(delta: float) -> void:
	if _cached_roof_points.is_empty():
		return
	for cat in _cats_container.get_children():
		if not cat.is_in_group("cats"):
			continue
		if randf() < roof_upper_seek_chance_per_second * delta and cat.has_method("try_seek_upper_roof"):
			cat.try_seek_upper_roof(_cached_roof_points)


func _update_cats_lower_roof_intent(delta: float) -> void:
	if _cached_roof_points.is_empty():
		return
	for cat in _cats_container.get_children():
		if not cat.is_in_group("cats"):
			continue
		if randf() < roof_lower_seek_chance_per_second * delta and cat.has_method("try_seek_lower_roof"):
			cat.try_seek_lower_roof(_cached_roof_points)

func _compute_prosperity_score() -> float:
	var vm := get_node_or_null("/root/VillageManager")
	if vm == null:
		return 0.0
	var food := 0.0
	var workers := 1.0
	var morale := 50.0
	if "resource_levels" in vm and vm.resource_levels is Dictionary:
		food = float(vm.resource_levels.get("food", 0))
	if "total_workers" in vm:
		workers = maxf(1.0, float(vm.total_workers))
	if vm.has_method("get_morale"):
		morale = float(vm.get_morale())

	var food_ratio := clampf(food / (workers * 2.0), 0.0, 1.0)
	var morale_ratio := clampf(morale / 100.0, 0.0, 1.0)
	return (food_ratio * 0.65) + (morale_ratio * 0.35)

func _sync_cat_roam_bounds() -> void:
	var bounds := _get_roam_bounds()
	for cat in _cats_container.get_children():
		if not cat.is_in_group("cats"):
			continue
		if cat.has_method("set_roam_bounds"):
			cat.set_roam_bounds(bounds)


func _count_cats_in_workers_container() -> int:
	var n := 0
	for c in _cats_container.get_children():
		if c.is_in_group("cats"):
			n += 1
	return n


func _count_workers_in_workers_container() -> int:
	if _cats_container == null:
		return 0
	var n := 0
	for c in _cats_container.get_children():
		if c.is_in_group("cats"):
			continue
		if c is Node2D:
			n += 1
	return n


func _get_target_cat_count() -> int:
	if not scale_cats_with_population:
		return max(0, max_cats)
	return _cached_population_target_cats


func _get_spawn_cap() -> int:
	if not scale_cats_with_population:
		return max(0, max_cats)
	# Dinamik hedef ustune cikmasin; ama editor max_cats de mutlak tavan gibi calissin.
	var dynamic_cap: int = max(0, dynamic_max_cats)
	var editor_cap: int = max(0, max_cats)
	var target_cap: int = max(0, _cached_population_target_cats)
	return min(dynamic_cap, max(editor_cap, target_cap))


func _compute_population_target_cats() -> int:
	if not scale_cats_with_population:
		return max(0, max_cats)
	var workers: int = _count_workers_in_workers_container()
	var ratio: float = maxf(1.5, workers_per_cat_mean + randf_range(-workers_per_cat_jitter, workers_per_cat_jitter))
	var base: float = (float(workers) / ratio) + base_cat_bias
	var target_f: float = base + randf_range(-target_cat_jitter, target_cat_jitter)
	var target_i: int = int(round(target_f))
	return clampi(target_i, dynamic_min_cats, dynamic_max_cats)


func _acquire_profile_id_for_spawn() -> String:
	var inactive_ids: Array[String] = []
	for key in _cat_profiles.keys():
		var id: String = str(key)
		if not _active_cat_profile_ids.has(id):
			inactive_ids.append(id)
	if not inactive_ids.is_empty():
		return inactive_ids[randi() % inactive_ids.size()]
	return _create_new_profile_id()


func _create_new_profile_id() -> String:
	var new_id := "cat_%03d" % _next_cat_profile_seq
	_next_cat_profile_seq += 1
	_cat_profiles[new_id] = {}
	return new_id


func _get_profile_id_from_cat(cat_node: Node) -> String:
	if cat_node == null:
		return ""
	if cat_node.has_method("get_persistent_cat_id"):
		return str(cat_node.get_persistent_cat_id())
	return ""


func _refresh_active_cat_profile_ids() -> void:
	_active_cat_profile_ids.clear()
	if _cats_container == null:
		return
	for child in _cats_container.get_children():
		if not child.is_in_group("cats"):
			continue
		var profile_id: String = _get_profile_id_from_cat(child)
		if profile_id.is_empty():
			profile_id = _create_new_profile_id()
			var fallback_color := Color(1.0, 1.0, 1.0, 1.0)
			if _cat_profiles.has(profile_id) and _cat_profiles[profile_id] is Dictionary:
				var existing: Dictionary = _cat_profiles[profile_id]
				if existing.has("color"):
					fallback_color = existing.get("color", fallback_color)
			elif child.has_method("get_current_color_variant"):
				fallback_color = child.get_current_color_variant()
			if child.has_method("set_persistent_identity"):
				child.set_persistent_identity(profile_id, fallback_color)
			if not _cat_profiles.has(profile_id):
				_cat_profiles[profile_id] = {"color": fallback_color}
		_active_cat_profile_ids[profile_id] = true


func _get_roam_bounds() -> Rect2:
	var left := -4500.0
	var right := 4500.0
	var left_marker := get_parent().get_node_or_null("CameraLimits/CameraLeftLimit")
	var right_marker := get_parent().get_node_or_null("CameraLimits/CameraRightLimit")
	if left_marker and left_marker is Node2D:
		left = left_marker.global_position.x + roam_margin
	if right_marker and right_marker is Node2D:
		right = right_marker.global_position.x - roam_margin
	if right <= left:
		right = left + 400.0
	var y0 := minf(walk_band_y_min, walk_band_y_max)
	var y1 := maxf(walk_band_y_min, walk_band_y_max)
	if derive_walk_band_from_workers and _cats_container != null:
		var have_worker := false
		var min_worker_y: float = INF
		var max_worker_y: float = -INF
		for n in _cats_container.get_children():
			if n.is_in_group("cats"):
				continue
			if not (n is Node2D):
				continue
			var ny: float = (n as Node2D).global_position.y
			min_worker_y = minf(min_worker_y, ny)
			max_worker_y = maxf(max_worker_y, ny)
			have_worker = true
		if have_worker:
			y0 = min_worker_y - worker_band_padding
			y1 = max_worker_y + worker_band_padding
			if y1 - y0 < 10.0:
				y1 = y0 + 10.0
	# Alt sinir: oyuncu yurume cizgisinin ustune (negatif Y) cikmasinlar.
	y0 = maxf(y0, walk_band_y_min)
	y1 = minf(y1, walk_band_y_max)
	if y1 - y0 < 4.0:
		y1 = y0 + 4.0
	return Rect2(Vector2(left, y0), Vector2(right - left, y1 - y0))

func _collect_roof_points() -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw in get_tree().get_nodes_in_group("one_way_platforms"):
		if not (raw is Node2D):
			continue
		var platform_body: Node2D = raw
		for child in platform_body.get_children():
			if child is CollisionShape2D and child.one_way_collision and child.shape is SegmentShape2D:
				var seg: SegmentShape2D = child.shape
				var world_a: Vector2 = platform_body.to_global(seg.a + child.position)
				var world_b: Vector2 = platform_body.to_global(seg.b + child.position)
				_append_roof_segment(points, seen, world_a, world_b)

	# Fallback: group'a eklenmemis one-way platformlari da tara.
	# Boylece House/Bakery gibi scripti farkli binalar da catilarini kediye acabilir.
	var scene_root: Node = get_parent()
	if scene_root != null:
		_scan_roof_points_fallback(scene_root, points, seen)
	return points


func _append_roof_segment(points: Array[Dictionary], seen: Dictionary, world_a: Vector2, world_b: Vector2) -> void:
	var left_x := minf(world_a.x, world_b.x)
	var right_x := maxf(world_a.x, world_b.x)
	if right_x - left_x < 14.0:
		return
	var y := minf(world_a.y, world_b.y)
	var key := "%d:%d:%d" % [int(round(left_x)), int(round(right_x)), int(round(y))]
	if seen.has(key):
		return
	seen[key] = true
	var center_x := (left_x + right_x) * 0.5
	points.append({
		"left_x": left_x + 8.0,
		"right_x": right_x - 8.0,
		"center_x": center_x,
		"y": y
	})


func _scan_roof_points_fallback(root: Node, points: Array[Dictionary], seen: Dictionary) -> void:
	for child in root.get_children():
		_scan_roof_points_fallback(child, points, seen)
	if not (root is CollisionShape2D):
		return
	var cs: CollisionShape2D = root
	if not cs.one_way_collision or not (cs.shape is SegmentShape2D):
		return
	var parent_2d := cs.get_parent() as Node2D
	if parent_2d == null:
		return
	var seg: SegmentShape2D = cs.shape
	var world_a: Vector2 = parent_2d.to_global(seg.a + cs.position)
	var world_b: Vector2 = parent_2d.to_global(seg.b + cs.position)
	_append_roof_segment(points, seen, world_a, world_b)
