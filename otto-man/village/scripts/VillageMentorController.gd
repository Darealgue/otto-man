extends Node2D
## Köy mentoru: çatı noktalarını tarar, CatPrototype çatı niyetini tetikler.

@export var mentor_path: NodePath = NodePath("../WorkersContainer/VillageMentor")
@export var roof_seek_chance_per_second: float = 0.038
@export var roof_upper_seek_chance_per_second: float = 0.032
@export var roof_lower_seek_chance_per_second: float = 0.055
@export var roof_rescan_interval: float = 2.5

var _mentor: Node
var _cached_roof_points: Array[Dictionary] = []
var _roof_scan_timer: float = 0.0


func _ready() -> void:
	call_deferred("_resolve_mentor")


func _resolve_mentor() -> void:
	_mentor = get_node_or_null(mentor_path)
	if _mentor == null:
		push_warning("[VillageMentorController] Mentor bulunamadı: %s" % str(mentor_path))


func _process(delta: float) -> void:
	if _mentor == null or not is_instance_valid(_mentor):
		return
	_roof_scan_timer -= delta
	if _roof_scan_timer <= 0.0:
		_roof_scan_timer = roof_rescan_interval
		_cached_roof_points = _collect_roof_points()
	if _cached_roof_points.is_empty():
		return
	if randf() < roof_seek_chance_per_second * delta:
		_mentor.try_seek_roof(_cached_roof_points)
	if randf() < roof_upper_seek_chance_per_second * delta:
		_mentor.try_seek_upper_roof(_cached_roof_points)
	if randf() < roof_lower_seek_chance_per_second * delta:
		_mentor.try_seek_lower_roof(_cached_roof_points)


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
	points.append({
		"left_x": left_x + 8.0,
		"right_x": right_x - 8.0,
		"center_x": (left_x + right_x) * 0.5,
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
