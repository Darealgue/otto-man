extends Node2D
class_name ForestLevelGenerator

signal level_started
signal level_completed

@export var current_level: int = 1
@export var unit_size: int = 2048
@export var spawn_ahead_count: int = 6
@export var despawn_distance: float = 8192.0
@export var prob_continue: float = 0.6
@export var prob_up: float = 0.2
@export var prob_down: float = 0.2
@export var min_row: int = -2
@export var max_row: int = 2
@export var window_left_count: int = 3
@export var window_right_count: int = 3
@export var prob_wide_ramp: float = 0.5
@export var debug_enabled: bool = false

var player: Node2D
var active_chunks: Array[Node2D] = []
var current_row: int = 0
var last_end_x: float = 0.0

# Overview camera (zoom-out) like dungeon
var overview_camera: Camera2D
var is_overview_active: bool = false

# Archive for backtracking support
var chunk_entries: Array[Dictionary] = [] # { "key": String, "position": Vector2, "size": Vector2 }
var index_to_node: Dictionary = {} # entry_index -> Node2D (only for currently active ones)
var first_active_index: int = 0
var last_active_index: int = -1

var scenes := {
	"start": preload("res://chunks/forest/start_2x1.tscn"),
	"linear": preload("res://chunks/forest/linear_2x1.tscn"),
	"ramp_up": preload("res://chunks/forest/ramp_up_1x2.tscn"),
	"ramp_down": preload("res://chunks/forest/ramp_down_1x2.tscn"),
	"ramp_up_wide": preload("res://chunks/forest/ramp_up_2x2.tscn"),
	"ramp_down_wide": preload("res://chunks/forest/ramp_down_2x2.tscn")
}

func _ready() -> void:
	add_to_group("level_generator")
	player = get_tree().get_first_node_in_group("player")
	_spawn_initial_path()
	_setup_overview_camera()
	_spawn_or_move_player_to_start()
	level_started.emit()

func _physics_process(_delta: float) -> void:
	if not player:
		return
	_enforce_player_window()
	if is_overview_active:
		_update_overview_camera_fit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		toggle_camera()
	if event.is_action_pressed("dump_level_debug"):
		_debug_dump_active_chunks("manual")

func toggle_camera() -> void:
	is_overview_active = !is_overview_active
	if is_overview_active:
		_update_overview_camera_fit()
		if overview_camera:
			overview_camera.make_current()
	elif player and player.has_node("Camera2D"):
		var cam = player.get_node("Camera2D")
		if cam and cam is Camera2D:
			(cam as Camera2D).enabled = true
			(cam as Camera2D).make_current()

func _spawn_initial_path() -> void:
	active_chunks.clear()
	current_row = 0
	last_end_x = 0.0
	chunk_entries.clear()
	index_to_node.clear()
	first_active_index = 0
	last_active_index = -1
	var start: Node2D = _spawn_scene("start")
	start.position = Vector2(0, _row_to_y(current_row))
	active_chunks.append(start)
	_record_entry(start, "start")
	first_active_index = 0
	last_active_index = 0
	last_end_x = start.position.x + _get_size(start).x
	for i in range(spawn_ahead_count - 1):
		_add_next_segment()

func _spawn_ahead_as_needed() -> void:
	var need_until: float = player.global_position.x + float(unit_size) * 6.0
	while last_end_x < need_until:
		_add_next_segment()

func _spawn_left_as_needed() -> void:
	if active_chunks.size() == 0:
		return
	# Spawn left until we cover at least just beyond the cleanup cutoff,
	# otherwise freshly spawned chunks could be immediately cleaned up.
	var cutoff: float = player.global_position.x - despawn_distance
	var target_left: float = cutoff + float(unit_size) * 2.0
	while active_chunks.size() > 0 and active_chunks[0].position.x > target_left:
		_add_prev_segment()

func _enforce_player_window() -> void:
	if active_chunks.size() == 0:
		return
	var player_idx: int = _find_player_chunk_index()
	# Spawn right until enough
	while (active_chunks.size() - 1 - player_idx) < window_right_count:
		_add_next_segment()
		player_idx = _find_player_chunk_index()
	# Spawn left until enough
	while player_idx < window_left_count:
		_add_prev_segment()
		player_idx = _find_player_chunk_index()
	# Remove extra on left
	while player_idx > window_left_count:
		_remove_leftmost_chunk()
		player_idx -= 1
	# Remove extra on right
	while (active_chunks.size() - 1 - player_idx) > window_right_count:
		_remove_rightmost_chunk()

func _cleanup_behind() -> void:
	var cutoff: float = player.global_position.x - despawn_distance
	while active_chunks.size() > 0:
		var c: Node2D = active_chunks[0]
		if c.global_position.x + _get_size(c).x >= cutoff:
			break
		# remove oldest chunk but keep archive
		var idx: int = int(c.get_meta("entry_index") if c.has_meta("entry_index") else first_active_index)
		c.queue_free()
		active_chunks.remove_at(0)
		index_to_node.erase(idx)
		first_active_index = max(first_active_index, idx + 1)

func _add_next_segment() -> void:
	var prev: Node2D = active_chunks.back()
	# Derive the current row from the last chunk's y to avoid drift after window removals
	current_row = int(round(prev.position.y / float(unit_size)))
	var roll: float = randf()
	var up_allowed: bool = current_row > min_row
	var down_allowed: bool = current_row < max_row
	var p_cont: float = prob_continue
	var p_up: float = (prob_up if up_allowed else 0.0)
	var p_down: float = (prob_down if down_allowed else 0.0)
	var total: float = p_cont + p_up + p_down
	if total <= 0.0:
		p_cont = 1.0; p_up = 0.0; p_down = 0.0; total = 1.0
	roll *= total
	if roll < p_cont:
		_place_continue(prev)
	elif roll < p_cont + p_up:
		_place_up(prev)
	else:
		_place_down(prev)

func _add_prev_segment() -> void:
	if active_chunks.size() == 0:
		return
	var first: Node2D = active_chunks[0]
	var row_est: int = _estimate_row_for_left(first)
	var roll: float = randf()
	var up_allowed: bool = row_est > min_row
	var down_allowed: bool = row_est < max_row
	var p_cont: float = prob_continue
	var p_up: float = (prob_up if up_allowed else 0.0)
	var p_down: float = (prob_down if down_allowed else 0.0)
	var total: float = p_cont + p_up + p_down
	if total <= 0.0:
		p_cont = 1.0; p_up = 0.0; p_down = 0.0; total = 1.0
	roll *= total
	if roll < p_cont:
		_place_continue_left(first, row_est)
	elif roll < p_cont + p_up:
		_place_up_left(first, row_est)
	else:
		_place_down_left(first, row_est)

func _estimate_row_for_left(first: Node2D) -> int:
	# Estimate the "current path row" from the leftmost chunk strictly by geometry
	var top_row: int = int(round(first.position.y / float(unit_size)))
	var h_units: int = int(round(_get_size(first).y / float(unit_size)))
	if h_units < 1:
		h_units = 1
	# Use the bottom row index of the chunk, which matches straight path alignment
	return top_row + (h_units - 1)

func _remove_leftmost_chunk() -> void:
	if active_chunks.size() == 0:
		return
	var c: Node2D = active_chunks[0]
	var idx: int = int(c.get_meta("entry_index") if c.has_meta("entry_index") else first_active_index)
	c.queue_free()
	active_chunks.remove_at(0)
	index_to_node.erase(idx)
	first_active_index = max(first_active_index, idx + 1)

func _remove_rightmost_chunk() -> void:
	if active_chunks.size() == 0:
		return
	var c: Node2D = active_chunks.back()
	var idx: int = int(c.get_meta("entry_index") if c.has_meta("entry_index") else last_active_index)
	c.queue_free()
	active_chunks.remove_at(active_chunks.size() - 1)
	index_to_node.erase(idx)
	# Recompute last_end_x from new rightmost
	if active_chunks.size() > 0:
		var r: Node2D = active_chunks.back()
		last_end_x = r.position.x + _get_size(r).x
	else:
		last_end_x = 0.0

func _find_player_chunk_index() -> int:
	var px: float = player.global_position.x
	var best_idx: int = 0
	var best_dist: float = INF
	for i in range(active_chunks.size()):
		var ch: Node2D = active_chunks[i]
		var sz: Vector2 = _get_size(ch)
		var start_x: float = ch.position.x
		var end_x: float = start_x + sz.x
		if px >= start_x and px <= end_x:
			return i
		var center_x: float = start_x + sz.x * 0.5
		var d: float = abs(px - center_x)
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx

func _place_continue(prev: Node2D) -> void:
	var next: Node2D = _spawn_scene("linear")
	var prev_size: Vector2 = _get_size(prev)
	# Lock y to prev's y so linear never changes row
	next.position = Vector2(prev.position.x + prev_size.x, prev.position.y)
	active_chunks.append(next)
	_record_entry(next, "linear")
	last_end_x = next.position.x + _get_size(next).x
	if debug_enabled:
		_debug_dump_active_chunks("place_continue")

func _place_continue_left(first: Node2D, row_est: int) -> void:
	var next: Node2D = _spawn_scene("linear")
	var next_size: Vector2 = _get_size(next)
	# Lock y to first's y so linear never changes row on the left
	next.position = Vector2(first.position.x - next_size.x, first.position.y)
	active_chunks.insert(0, next)
	_record_entry(next, "linear")
	if debug_enabled:
		_debug_dump_active_chunks("place_continue_left")

func _place_up(prev: Node2D) -> void:
	var ramp_key: String = ("ramp_up_wide" if randf() < prob_wide_ramp else "ramp_up")
	var ramp: Node2D = _spawn_scene(ramp_key)
	var prev_size: Vector2 = _get_size(prev)
	var ramp_size: Vector2 = _get_size(ramp)
	# Align bottoms of prev and ramp
	ramp.position = Vector2(prev.position.x + prev_size.x, prev.position.y + prev_size.y - ramp_size.y)
	active_chunks.append(ramp)
	_record_entry(ramp, ramp_key)
	var next: Node2D = _spawn_scene("linear")
	# Move exactly one row up from previous linear's row
	next.position = Vector2(ramp.position.x + ramp_size.x, prev.position.y - float(unit_size))
	active_chunks.append(next)
	_record_entry(next, "linear")
	current_row -= 1
	last_end_x = next.position.x + _get_size(next).x
	if debug_enabled:
		_debug_dump_active_chunks("place_up")

func _place_up_left(first: Node2D, row_est: int) -> void:
	var ramp_key: String = ("ramp_down_wide" if randf() < prob_wide_ramp else "ramp_down")
	var ramp: Node2D = _spawn_scene(ramp_key)
	var ramp_size: Vector2 = _get_size(ramp)
	# Align bottoms of first and ramp, ramp on the left
	ramp.position = Vector2(first.position.x - ramp_size.x, first.position.y + (unit_size - ramp_size.y))
	active_chunks.insert(0, ramp)
	_record_entry(ramp, ramp_key)
	var next: Node2D = _spawn_scene("linear")
	var next_size: Vector2 = _get_size(next)
	# Move exactly one row up from previous linear's row (to the left)
	next.position = Vector2(ramp.position.x - next_size.x, first.position.y - float(unit_size))
	active_chunks.insert(0, next)
	_record_entry(next, "linear")
	if debug_enabled:
		_debug_dump_active_chunks("place_up_left")

func _place_down(prev: Node2D) -> void:
	var ramp_key: String = ("ramp_down_wide" if randf() < prob_wide_ramp else "ramp_down")
	var ramp: Node2D = _spawn_scene(ramp_key)
	var prev_size: Vector2 = _get_size(prev)
	var ramp_size: Vector2 = _get_size(ramp)
	# Align tops of prev and ramp
	ramp.position = Vector2(prev.position.x + prev_size.x, prev.position.y)
	active_chunks.append(ramp)
	_record_entry(ramp, ramp_key)
	var next: Node2D = _spawn_scene("linear")
	var next_size: Vector2 = _get_size(next)
	# Move exactly one row down from previous linear's row
	next.position = Vector2(ramp.position.x + ramp_size.x, prev.position.y + float(unit_size))
	active_chunks.append(next)
	_record_entry(next, "linear")
	current_row += 1
	last_end_x = next.position.x + next_size.x
	if debug_enabled:
		_debug_dump_active_chunks("place_down")

func _place_down_left(first: Node2D, row_est: int) -> void:
	var ramp_key: String = ("ramp_up_wide" if randf() < prob_wide_ramp else "ramp_up")
	var ramp: Node2D = _spawn_scene(ramp_key)
	var ramp_size: Vector2 = _get_size(ramp)
	# Align tops of first and ramp, ramp on the left
	ramp.position = Vector2(first.position.x - ramp_size.x, first.position.y)
	active_chunks.insert(0, ramp)
	_record_entry(ramp, ramp_key)
	var next: Node2D = _spawn_scene("linear")
	var next_size: Vector2 = _get_size(next)
	# Move exactly one row down from previous linear's row (to the left)
	next.position = Vector2(ramp.position.x - next_size.x, first.position.y + float(unit_size))
	active_chunks.insert(0, next)
	_record_entry(next, "linear")
	if debug_enabled:
		_debug_dump_active_chunks("place_down_left")

func _spawn_scene(key: String) -> Node2D:
	var scene: PackedScene = scenes[key] as PackedScene
	var inst: Node2D = scene.instantiate() as Node2D
	add_child(inst)
	return inst

func _get_size(node: Node2D) -> Vector2:
	# All forest chunks provide size via unit_size and size_in_units
	if node.has_method("get_chunk_size"):
		return node.call("get_chunk_size") as Vector2
	# Fallback to unit grid if missing
	return Vector2(2 * unit_size, unit_size)

func _row_to_y(row: int) -> float:
	return row * unit_size

func get_spawn_position() -> Vector2:
	if active_chunks.is_empty():
		return Vector2.ZERO
	var first := active_chunks[0]
	var sz := _get_size(first)
	return Vector2(first.position.x + unit_size * 0.5, first.position.y + sz.y - unit_size * 0.5)

func _spawn_or_move_player_to_start() -> void:
	var spawn_pos: Vector2 = get_spawn_position()
	if player == null:
		var player_scene: PackedScene = load("res://player/player.tscn") as PackedScene
		if player_scene:
			player = player_scene.instantiate() as Node2D
			if player:
				player.name = "Player"
				add_child(player)
	if player:
		player.global_position = spawn_pos
		if player.has_node("Camera2D"):
			var cam = player.get_node("Camera2D")
			if cam and cam is Camera2D:
				(cam as Camera2D).enabled = true
				(cam as Camera2D).make_current()

func _setup_overview_camera() -> void:
	overview_camera = Camera2D.new()
	add_child(overview_camera)
	overview_camera.enabled = true
	_update_overview_camera_fit()
	if is_overview_active:
		overview_camera.make_current()

func _update_overview_camera_fit() -> void:
	if not overview_camera:
		return
	if active_chunks.is_empty():
		overview_camera.position = Vector2.ZERO
		overview_camera.zoom = Vector2.ONE
		return
	var merged: Rect2
	var first_set: bool = false
	for c in active_chunks:
		if not (c is Node2D):
			continue
		var sz: Vector2 = _get_size(c)
		var r := Rect2(c.position, sz)
		if not first_set:
			merged = r
			first_set = true
		else:
			merged = merged.merge(r)
	var center := merged.position + merged.size * 0.5
	overview_camera.position = center
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var zoom_x: float = viewport_size.x / max(merged.size.x, 1.0)
	var zoom_y: float = viewport_size.y / max(merged.size.y, 1.0)
	var ratio: float = min(zoom_x, zoom_y) * 0.9
	overview_camera.zoom = Vector2(ratio, ratio)

# --- Backtracking helpers ---
func _record_entry(node: Node2D, key: String) -> void:
	var entry: Dictionary = {
		"key": key,
		"position": node.position,
		"size": _get_size(node)
	}
	chunk_entries.append(entry)
	var idx: int = chunk_entries.size() - 1
	node.set_meta("entry_index", idx)
	index_to_node[idx] = node
	last_active_index = idx

func _ensure_back_coverage() -> void:
	if active_chunks.size() == 0:
		return
	var need_from_x: float = player.global_position.x - float(unit_size) * 6.0
	while active_chunks.size() > 0 and active_chunks[0].position.x > need_from_x and first_active_index > 0:
		var idx: int = first_active_index - 1
		var node: Node2D = _spawn_from_archive(idx)
		if node:
			active_chunks.insert(0, node)
			first_active_index = idx
		else:
			break

func _spawn_from_archive(idx: int) -> Node2D:
	if idx < 0 or idx >= chunk_entries.size():
		return null
	if index_to_node.has(idx):
		return index_to_node[idx]
	var entry: Dictionary = chunk_entries[idx]
	var key: String = String(entry.get("key", "linear"))
	var scene: PackedScene = scenes[key] as PackedScene
	if not scene:
		return null
	var inst: Node2D = scene.instantiate() as Node2D
	add_child(inst)
	inst.position = entry.get("position", Vector2.ZERO)
	inst.set_meta("entry_index", idx)
	index_to_node[idx] = inst
	return inst

# --- Debug helpers ---
func _debug_dump_active_chunks(reason: String) -> void:
	print("\n[ForestDebug] Dump due to:", reason)
	print("  player.x=", player.global_position.x, " current_row=", current_row, " window L/R=", window_left_count, "/", window_right_count)
	for i in range(active_chunks.size()):
		var n: Node2D = active_chunks[i]
		var key := _get_chunk_key(n)
		var sz := _get_size(n)
		var row := int(round(n.position.y / float(unit_size)))
		var cons := _get_chunk_connections(n)
		print("  [", i, "] key=", key, " pos=", n.position, " size=", sz, " row=", row, " cons=", cons)
	print("  last_end_x=", last_end_x, " entries=", chunk_entries.size(), " first_active_index=", first_active_index, " last_active_index=", last_active_index)

func _get_chunk_key(n: Node2D) -> String:
	if n.has_meta("entry_index"):
		var idx: int = int(n.get_meta("entry_index"))
		if idx >= 0 and idx < chunk_entries.size():
			var e := chunk_entries[idx]
			return String(e.get("key", "unknown"))
	if "scene_file_path" in n:
		return String(n.scene_file_path).get_file().get_basename()
	return n.get_class()

func _get_chunk_connections(n: Node2D) -> Array:
	var result: Array = []
	if n.has_method("get_available_connections"):
		var arr = n.call("get_available_connections")
		if typeof(arr) == TYPE_ARRAY:
			for d in arr:
				result.append(str(d))
			return result
	var cons = null
	if n.has_method("get"):
		cons = n.get("connections")
	if cons is Array:
		for d in cons:
			result.append(str(d))
	return result
