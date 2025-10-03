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
@export var debug_rate_ms: int = 250

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
var min_discovered_index: int = 0
var max_discovered_index: int = -1
var _last_dbg_ms: int = 0
var _last_dbg_text: String = ""

var scenes := {
	# Each key holds an array of variants
	"start": [preload("res://chunks/forest/start_2x1.tscn")],
	"linear": [
		preload("res://chunks/forest/linear_2x1.tscn"),
		preload("res://chunks/forest/linear_2x1-2.tscn"),
		preload("res://chunks/forest/linear_2x1-3.tscn"),
		preload("res://chunks/forest/linear_2x1-4.tscn")
	],
	"ramp_up": [
		preload("res://chunks/forest/ramp_up_1x2.tscn"),
		preload("res://chunks/forest/ramp_up_1x2-2.tscn"),
		preload("res://chunks/forest/ramp_up_1x2-3.tscn"),
		preload("res://chunks/forest/ramp_up_1x2-4.tscn")
	],
	"ramp_down": [
		preload("res://chunks/forest/ramp_down_1x2.tscn"),
		preload("res://chunks/forest/ramp_down_1x2-2.tscn"),
		preload("res://chunks/forest/ramp_down_1x2-3.tscn"),
		preload("res://chunks/forest/ramp_down_1x2-4.tscn")
	],
	"ramp_up_wide": [
		preload("res://chunks/forest/ramp_up_2x2.tscn"),
		preload("res://chunks/forest/ramp_up_2x2-2.tscn"),
		preload("res://chunks/forest/ramp_up_2x2-3.tscn"),
		preload("res://chunks/forest/ramp_up_2x2-4.tscn")
	],
	"ramp_down_wide": [
		preload("res://chunks/forest/ramp_down_2x2.tscn"),
		preload("res://chunks/forest/ramp_down_2x2-2.tscn"),
		preload("res://chunks/forest/ramp_down_2x2-3.tscn"),
		preload("res://chunks/forest/ramp_down_2x2-4.tscn")
	]
}

func _ready() -> void:
	add_to_group("level_generator")
	player = get_tree().get_first_node_in_group("player")
	_spawn_initial_path()
	_setup_overview_camera()
	_setup_day_night_system()
	_spawn_or_move_player_to_start()
	level_started.emit()

func _physics_process(_delta: float) -> void:
	if not player:
		return
	_sweep_invalid_active_chunks()
	_sort_active_by_x()
	_enforce_player_window()
	if is_overview_active:
		_update_overview_camera_fit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		toggle_camera()
	if event.is_action_pressed("dump_level_debug"):
		_debug_dump_active_chunks("manual")
	# Mirror village time controls: 1/2/3 to set time scale, T to cycle
	if event is InputEventKey and event.pressed and not event.is_echo():
		var tm = get_node_or_null("/root/TimeManager")
		if event.keycode == KEY_1:
			if tm and tm.has_method("set_time_scale_index"):
				tm.set_time_scale_index(0)
		elif event.keycode == KEY_2:
			if tm and tm.has_method("set_time_scale_index"):
				tm.set_time_scale_index(1)
		elif event.keycode == KEY_3:
			if tm and tm.has_method("set_time_scale_index"):
				tm.set_time_scale_index(2)
		elif event.keycode == KEY_T:
			if tm and tm.has_method("cycle_time_scale"):
				tm.cycle_time_scale()

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
	var start_idx: int = _record_entry(start, "start")
	first_active_index = 0
	last_active_index = 0
	min_discovered_index = 0
	max_discovered_index = 0
	last_end_x = start.position.x + _get_size(start).x
	for i in range(spawn_ahead_count - 1):
		_add_next_segment()
	_sort_active_by_x()

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
	_sort_active_by_x()
	var player_idx: int = _find_player_chunk_index()
	if debug_enabled:
		var left_idx_dbg := (int(active_chunks[0].get_meta("entry_index")) if active_chunks.size()>0 and active_chunks[0].has_meta("entry_index") else -1)
		var right_idx_dbg := (int(active_chunks.back().get_meta("entry_index")) if active_chunks.size()>0 and active_chunks.back().has_meta("entry_index") else -1)
		_dbg("[Window] start: player_idx=%s size=%s left_x=%s right_x=%s left_idx=%s right_idx=%s discovered=[%s..%s]" % [
			str(player_idx), str(active_chunks.size()),
			str(active_chunks[0].position.x if active_chunks.size()>0 else 0),
			str(active_chunks.back().position.x if active_chunks.size()>0 else 0),
			str(left_idx_dbg), str(right_idx_dbg), str(min_discovered_index), str(max_discovered_index)
		])
	# Ensure enough on the right
	var safety := 32
	while (active_chunks.size() - 1 - player_idx) < window_right_count and safety > 0:
		if not _restore_right_once():
			if debug_enabled:
				_dbg("[Window] right: restore failed -> add_next")
			_add_next_segment()
		_sort_active_by_x()
		player_idx = _find_player_chunk_index()
		safety -= 1
		if debug_enabled:
			var r_idx := (int(active_chunks.back().get_meta("entry_index")) if active_chunks.size()>0 and active_chunks.back().has_meta("entry_index") else -1)
			_dbg("[Window] right: player_idx=%s size=%s right_idx=%s" % [str(player_idx), str(active_chunks.size()), str(r_idx)])
	# Ensure enough on the left
	safety = 32
	while player_idx < window_left_count and safety > 0:
		var before_left_x := (active_chunks[0].position.x if active_chunks.size() > 0 else 0.0)
		var before_count := active_chunks.size()
		if not _restore_left_once():
			if debug_enabled:
				_dbg("[Window] left: restore failed -> add_prev (left generation)")
			_add_prev_segment()
		_sort_active_by_x()
		player_idx = _find_player_chunk_index()
		# If nothing changed, break to avoid infinite loop
		if active_chunks.size() == before_count and (active_chunks.size() == 0 or is_equal_approx(active_chunks[0].position.x, before_left_x)):
			if debug_enabled:
				_dbg("[Window] left: no progress -> break")
			break
		safety -= 1
		if debug_enabled:
			var l_idx := (int(active_chunks[0].get_meta("entry_index")) if active_chunks.size()>0 and active_chunks[0].has_meta("entry_index") else -1)
			_dbg("[Window] left: player_idx=%s size=%s left_idx=%s" % [str(player_idx), str(active_chunks.size()), str(l_idx)])
	# Trim extras on the left
	safety = 32
	while player_idx > window_left_count and safety > 0:
		if debug_enabled:
			_dbg("[Trim] remove leftmost")
		_remove_leftmost_chunk()
		_sort_active_by_x()
		player_idx = _find_player_chunk_index()
		safety -= 1
	# Trim extras on the right
	safety = 32
	while (active_chunks.size() - 1 - player_idx) > window_right_count and safety > 0:
		if debug_enabled:
			_dbg("[Trim] remove rightmost")
		_remove_rightmost_chunk()
		_sort_active_by_x()
		player_idx = _find_player_chunk_index()
		safety -= 1

func _cleanup_behind() -> void:
	var cutoff: float = player.global_position.x - despawn_distance
	while active_chunks.size() > 0:
		_sort_active_by_x()
		var c: Node2D = active_chunks[0]
		if c == null or not is_instance_valid(c):
			active_chunks.remove_at(0)
			continue
		if c.global_position.x + _get_size(c).x >= cutoff:
			break
		# remove oldest chunk but keep archive
		var idx: int = int(c.get_meta("entry_index") if c.has_meta("entry_index") else first_active_index)
		if is_instance_valid(c):
			c.queue_free()
		active_chunks.remove_at(0)
		index_to_node.erase(idx)
		first_active_index = max(first_active_index, idx + 1)

func _add_next_segment() -> void:
	_sort_active_by_x()
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
	_sort_active_by_x()
	var first: Node2D = active_chunks[0]
	# Use first's row to keep path flat unless a ramp is chosen
	var row_est: int = int(round(first.position.y / float(unit_size)))
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
	_sort_active_by_x()
	var c: Node2D = active_chunks[0]
	var idx: int = int(c.get_meta("entry_index") if c.has_meta("entry_index") else first_active_index)
	if is_instance_valid(c):
		c.queue_free()
	active_chunks.remove_at(0)
	index_to_node.erase(idx)
	first_active_index = max(first_active_index, idx + 1)

func _remove_rightmost_chunk() -> void:
	if active_chunks.size() == 0:
		return
	_sort_active_by_x()
	var c: Node2D = active_chunks.back()
	var idx: int = int(c.get_meta("entry_index") if c.has_meta("entry_index") else last_active_index)
	if is_instance_valid(c):
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
		if ch == null or not is_instance_valid(ch):
			continue
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
	var prev_right: Vector2 = _get_conn_global(prev, "right")
	var next_left_local: Vector2 = _get_conn_local(next, "left")
	next.position = prev_right - next_left_local
	active_chunks.append(next)
	var prev_idx := int(prev.get_meta("entry_index") if prev.has_meta("entry_index") else -1)
	var new_idx := _record_entry(next, "linear")
	if prev_idx != -1:
		_link_after(prev_idx, new_idx)
	last_end_x = next.position.x + _get_size(next).x
	if debug_enabled:
		_debug_dump_active_chunks("place_continue")

func _place_continue_left(first: Node2D, row_est: int) -> void:
	var next: Node2D = _spawn_scene("linear")
	var first_left: Vector2 = _get_conn_global(first, "left")
	var next_right_local: Vector2 = _get_conn_local(next, "right")
	# Align next.right to first.left so it sits to the left
	next.position = first_left - next_right_local
	active_chunks.insert(0, next)
	var first_idx := int(first.get_meta("entry_index") if first.has_meta("entry_index") else -1)
	var next_idx := _record_entry(next, "linear")
	if first_idx != -1:
		_link_before(first_idx, next_idx)
	if debug_enabled:
		_debug_dump_active_chunks("place_continue_left")

func _place_up(prev: Node2D) -> void:
	var ramp_key: String = ("ramp_up_wide" if randf() < prob_wide_ramp else "ramp_up")
	var ramp: Node2D = _spawn_scene(ramp_key)
	# Align prev.right to ramp.left
	var prev_right: Vector2 = _get_conn_global(prev, "right")
	var ramp_left_local: Vector2 = _get_conn_local(ramp, "left")
	ramp.position = prev_right - ramp_left_local
	active_chunks.append(ramp)
	var prev_idx := int(prev.get_meta("entry_index") if prev.has_meta("entry_index") else -1)
	var ramp_idx := _record_entry(ramp, ramp_key)
	var next: Node2D = _spawn_scene("linear")
	# Align ramp.right to next.left (top connection on ramp_up)
	var ramp_right: Vector2 = _get_conn_global(ramp, "right")
	var next_left_local: Vector2 = _get_conn_local(next, "left")
	next.position = ramp_right - next_left_local
	active_chunks.append(next)
	var next_idx := _record_entry(next, "linear")
	if prev_idx != -1:
		_link_after(prev_idx, ramp_idx)
	_link_after(ramp_idx, next_idx)
	if debug_enabled:
		var expected_y := _get_conn_global(ramp, "right").y - _get_conn_local(next, "left").y + next.position.y
		print("[PlaceUp] prev_y=", prev.position.y, " ramp=", ramp_key, " next_y=", next.position.y)
	current_row -= 1
	last_end_x = next.position.x + _get_size(next).x
	if debug_enabled:
		_debug_dump_active_chunks("place_up")

func _place_up_left(first: Node2D, row_est: int) -> void:
	var ramp_key: String = ("ramp_down_wide" if randf() < prob_wide_ramp else "ramp_down")
	var ramp: Node2D = _spawn_scene(ramp_key)
	# Align ramp.right to first.left
	var first_left: Vector2 = _get_conn_global(first, "left")
	var ramp_right_local: Vector2 = _get_conn_local(ramp, "right")
	ramp.position = first_left - ramp_right_local
	active_chunks.insert(0, ramp)
	var first_idx := int(first.get_meta("entry_index") if first.has_meta("entry_index") else -1)
	var ramp_idx := _record_entry(ramp, ramp_key)
	var next: Node2D = _spawn_scene("linear")
	# Align next.right to ramp.left (top connection on ramp_down to the left)
	var ramp_left: Vector2 = _get_conn_global(ramp, "left")
	var next_right_local: Vector2 = _get_conn_local(next, "right")
	next.position = ramp_left - next_right_local
	active_chunks.insert(0, next)
	var next_idx := _record_entry(next, "linear")
	if first_idx != -1:
		# Link spatially: next (leftmost) -> ramp -> first
		_link_before(first_idx, next_idx)
		_link_before(first_idx, ramp_idx)
	if debug_enabled:
		print("[PlaceUpLeft] first_y=", first.position.y, " ramp=", ramp_key, " next_y=", next.position.y)
	if debug_enabled:
		_debug_dump_active_chunks("place_up_left")

func _place_down(prev: Node2D) -> void:
	var ramp_key: String = ("ramp_down_wide" if randf() < prob_wide_ramp else "ramp_down")
	var ramp: Node2D = _spawn_scene(ramp_key)
	# Align prev.right to ramp.left (top connection on ramp_down)
	var prev_right: Vector2 = _get_conn_global(prev, "right")
	var ramp_left_local: Vector2 = _get_conn_local(ramp, "left")
	ramp.position = prev_right - ramp_left_local
	active_chunks.append(ramp)
	var prev_idx := int(prev.get_meta("entry_index") if prev.has_meta("entry_index") else -1)
	var ramp_idx := _record_entry(ramp, ramp_key)
	var next: Node2D = _spawn_scene("linear")
	# Align ramp.right to next.left (bottom connection on ramp_down)
	var ramp_right: Vector2 = _get_conn_global(ramp, "right")
	var next_left_local: Vector2 = _get_conn_local(next, "left")
	next.position = ramp_right - next_left_local
	active_chunks.append(next)
	var next_idx := _record_entry(next, "linear")
	if prev_idx != -1:
		_link_after(prev_idx, ramp_idx)
	_link_after(ramp_idx, next_idx)
	if debug_enabled:
		print("[PlaceDown] prev_y=", prev.position.y, " ramp=", ramp_key, " next_y=", next.position.y)
	current_row += 1
	last_end_x = next.position.x + _get_size(next).x
	if debug_enabled:
		_debug_dump_active_chunks("place_down")

func _place_down_left(first: Node2D, row_est: int) -> void:
	var ramp_key: String = ("ramp_up_wide" if randf() < prob_wide_ramp else "ramp_up")
	var ramp: Node2D = _spawn_scene(ramp_key)
	# Align ramp.right to first.left (top connection on ramp_up to the left)
	var first_left: Vector2 = _get_conn_global(first, "left")
	var ramp_right_local: Vector2 = _get_conn_local(ramp, "right")
	ramp.position = first_left - ramp_right_local
	active_chunks.insert(0, ramp)
	var first_idx := int(first.get_meta("entry_index") if first.has_meta("entry_index") else -1)
	var ramp_idx := _record_entry(ramp, ramp_key)
	var next: Node2D = _spawn_scene("linear")
	# Align next.right to ramp.left (bottom connection on ramp_up)
	var ramp_left: Vector2 = _get_conn_global(ramp, "left")
	var next_right_local: Vector2 = _get_conn_local(next, "right")
	next.position = ramp_left - next_right_local
	active_chunks.insert(0, next)
	var next_idx := _record_entry(next, "linear")
	if first_idx != -1:
		# Link spatially: next (leftmost) -> ramp -> first
		_link_before(first_idx, next_idx)
		_link_before(first_idx, ramp_idx)
	if debug_enabled:
		print("[PlaceDownLeft] prev_y=", first.position.y, " ramp=", ramp_key, " next_y=", next.position.y)
	if debug_enabled:
		_debug_dump_active_chunks("place_down_left")


func _spawn_scene(key: String) -> Node2D:
	var scene: PackedScene = null
	var arr = scenes.get(key, [])
	if typeof(arr) == TYPE_ARRAY and (arr as Array).size() > 0:
		var i := randi() % (arr as Array).size()
		scene = (arr as Array)[i]
	else:
		# Backward compatibility if a single PackedScene was left
		scene = scenes.get(key, null)
		if typeof(scene) != TYPE_OBJECT:
			return null
	var inst: Node2D = scene.instantiate() as Node2D
	add_child(inst)
	# Force unit_size sync to avoid per-scene mismatches
	_apply_unit_size(inst)
	# Populate forest tile-based decorations for this chunk (deferred to ensure TileMap is ready)
	call_deferred("_populate_forest_decorations_for_chunk", inst)
	return inst

func _get_size(node: Node2D) -> Vector2:
	# All forest chunks provide size via unit_size and size_in_units
	if node == null or not is_instance_valid(node):
		return Vector2.ZERO
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
		if c == null or not is_instance_valid(c) or not (c is Node2D):
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

# --- Day/Night system (mirror of village) ---
func _setup_day_night_system() -> void:
	# Avoid duplicating background if already exists
	if get_node_or_null("ParallaxBackground"):
		return
	var pb := ParallaxBackground.new()
	pb.name = "ParallaxBackground"
	pb.layer = -1
	add_child(pb)

	# Sky gradient
	var sky_layer := ParallaxLayer.new()
	sky_layer.name = "sky"
	sky_layer.z_index = -100
	sky_layer.motion_scale = Vector2(0.0, 0.0)
	pb.add_child(sky_layer)
	var sky_sprite := Sprite2D.new()
	sky_sprite.name = "Sky"
	# Use a simple gradient texture similar to village defaults
	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	grad.set_color(0, Color(0.5, 0.7, 1.0, 1.0))
	grad.set_color(1, Color(0.75, 0.95, 1.0, 1.0))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	# Ensure vertical gradient (top -> bottom), like village
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	sky_sprite.texture = grad_tex
	# Keep parallax sky for compatibility, but also add a screen-space sky to guarantee coverage
	# Parallax sprite (large, world-space)
	sky_sprite.centered = false
	sky_sprite.position = Vector2(-8192, -8192)
	sky_sprite.scale = Vector2(16, 16)
	sky_layer.add_child(sky_sprite)
	# Screen-space sky using CanvasLayer + TextureRect (fills viewport)
	var sky_canvas := CanvasLayer.new()
	sky_canvas.name = "SkyCanvas"
	sky_canvas.layer = -1000
	add_child(sky_canvas)
	var sky_rect := TextureRect.new()
	sky_rect.name = "SkyRect"
	sky_rect.texture = grad_tex
	sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
	sky_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky_canvas.add_child(sky_rect)

	# Stars layer
	var stars_layer := ParallaxLayer.new()
	stars_layer.name = "StarsLayer"
	stars_layer.z_index = -40
	stars_layer.motion_scale = Vector2(0.001, 0.001)
	stars_layer.position = Vector2(10, 642)
	pb.add_child(stars_layer)
	# StarsContainer from village
	var stars_container := Node2D.new()
	stars_container.name = "StarsContainer"
	var stars_script := load("res://village/scripts/StarsContainer.gd")
	if stars_script:
		stars_container.set_script(stars_script)
		# Mirror village defaults
		stars_container.set("num_stars", 200)
		stars_container.set("center", Vector2(800, 0))
		stars_container.set("max_radius", 1000.0)
		stars_container.set("min_speed", 0.005)
		stars_container.set("max_speed", 0.008)
		var star_tex := load("res://village/assets/star/star1.png")
		if star_tex:
			stars_container.set("star_texture", star_tex)
	stars_layer.add_child(stars_container)

	# Background tint CanvasModulate for day-night controller to adjust
	var bg_tint := CanvasModulate.new()
	bg_tint.name = "BackgroundTint"
	bg_tint.z_index = -50
	pb.add_child(bg_tint)

	# Celestial path (sun/moon)
	var celestial_layer := ParallaxLayer.new()
	celestial_layer.name = "CelestialLayer"
	celestial_layer.z_index = -30
	celestial_layer.motion_scale = Vector2(0.001, 0.001)
	celestial_layer.position = Vector2(10, 642)
	pb.add_child(celestial_layer)
	var path := Path2D.new()
	path.name = "SunMoonPath"
	path.position = Vector2(599, -98)
	path.scale = Vector2(0.543478, 0.543478)
	var curve := Curve2D.new()
	# Arc approximating village path
	curve.add_point(Vector2(-1200, 200))
	curve.add_point(Vector2(-800, -200))
	curve.add_point(Vector2(-400, -600))
	curve.add_point(Vector2(0, -800))
	curve.add_point(Vector2(400, -600))
	curve.add_point(Vector2(800, -200))
	curve.add_point(Vector2(1200, 200))
	path.curve = curve
	celestial_layer.add_child(path)
	var sun_follow := PathFollow2D.new(); sun_follow.name = "SunFollower"; path.add_child(sun_follow)
	var sun_sprite := Sprite2D.new(); sun_sprite.name = "SunSprite"; sun_follow.add_child(sun_sprite); sun_sprite.scale = Vector2(0.6, 0.6)
	var sun_tex = load("res://village/assets/sun,moon/sun.png")
	if sun_tex:
		sun_sprite.texture = sun_tex
	var moon_follow := PathFollow2D.new(); moon_follow.name = "MoonFollower"; path.add_child(moon_follow)
	var moon_sprite := Sprite2D.new(); moon_sprite.name = "MoonSprite"; moon_follow.add_child(moon_sprite); moon_sprite.scale = Vector2(0.6, 0.6)
	var moon_tex = load("res://village/assets/sun,moon/moon.png")
	if moon_tex:
		moon_sprite.texture = moon_tex
	# Match village parallax feel (slight movement with camera)
	celestial_layer.motion_scale = Vector2(0.001, 0.001)
	# Basic small lights (optional; can be left disabled)
	var sun_light := PointLight2D.new(); sun_light.name = "PointLight2D"; sun_follow.add_child(sun_light); sun_light.visible = false
	sun_light.texture_scale = 10.05
	var moon_light := PointLight2D.new(); moon_light.name = "PointLight2D"; moon_follow.add_child(moon_light); moon_light.visible = false
	moon_light.texture_scale = 5.76

	# DayNightController
	var dnc := CanvasModulate.new()
	dnc.name = "DayNightController"
	# Ensure it modulates the whole canvas and sits behind gameplay
	dnc.z_index = -200
	# Attach script and configure BEFORE adding to tree so _ready sees NodePaths
	var script := load("res://village/scripts/DayNightController.gd")
	if script:
		dnc.set_script(script)
		# Exported fields wiring via NodePaths
		dnc.set("sky_gradient_resource", grad_tex)
		dnc.set("transition_speed", 0.3)
		dnc.set("sun_follower_path", NodePath("../ParallaxBackground/CelestialLayer/SunMoonPath/SunFollower"))
		dnc.set("moon_follower_path", NodePath("../ParallaxBackground/CelestialLayer/SunMoonPath/MoonFollower"))
		dnc.set("sun_sprite_path", NodePath("../ParallaxBackground/CelestialLayer/SunMoonPath/SunFollower/SunSprite"))
		dnc.set("moon_sprite_path", NodePath("../ParallaxBackground/CelestialLayer/SunMoonPath/MoonFollower/MoonSprite"))
		dnc.set("sun_light_path", NodePath("../ParallaxBackground/CelestialLayer/SunMoonPath/SunFollower/PointLight2D"))
		dnc.set("moon_light_path", NodePath("../ParallaxBackground/CelestialLayer/SunMoonPath/MoonFollower/PointLight2D"))
		dnc.set("sun_sunset_hour", 19.5)
		dnc.set("moon_set_hour", 6.0)
		dnc.set("celestial_fade_duration", 0.3)
	# Add to tree last -> triggers _ready with correct paths
	add_child(dnc)

	# --- Forest Parallax (mountains, trees) ---
	# Mountains - far background
	var mountains_layer := ParallaxLayer.new()
	mountains_layer.name = "ForestMountains"
	mountains_layer.z_index = -12
	mountains_layer.position = Vector2(0, -200)
	mountains_layer.motion_scale = Vector2(0.05, 0.0)
	pb.add_child(mountains_layer)
	var mountains_sprite := Sprite2D.new()
	mountains_sprite.name = "MountainsSprite"
	var mountains_tex := load("res://background/parallax/forest parallax/forest parallax mountain.png")
	if mountains_tex:
		mountains_sprite.texture = mountains_tex
	mountains_sprite.centered = false
	mountains_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mountains_layer.add_child(mountains_sprite)
	if mountains_tex and mountains_tex is Texture2D:
		var mw := (mountains_tex as Texture2D).get_width()
		mountains_layer.motion_mirroring = Vector2(float(mw), 0.0)

	# Trees - nearer background
	var trees_layer := ParallaxLayer.new()
	trees_layer.name = "ForestTrees"
	trees_layer.z_index = -9
	trees_layer.position = Vector2(0, -350)
	trees_layer.motion_scale = Vector2(0.15, 0.060)
	pb.add_child(trees_layer)
	var trees_sprite := Sprite2D.new()
	trees_sprite.name = "TreesSprite"
	var trees_tex := load("res://background/parallax/forest parallax/forest parallax trees.png")
	if trees_tex:
		trees_sprite.texture = trees_tex
	trees_sprite.centered = false
	trees_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	trees_layer.add_child(trees_sprite)
	if trees_tex and trees_tex is Texture2D:
		var tw := (trees_tex as Texture2D).get_width()
		trees_layer.motion_mirroring = Vector2(float(tw), 0.0)

	# Trees Front - nearest background strip with tiny vertical motion
	var trees_front_layer := ParallaxLayer.new()
	trees_front_layer.name = "ForestTreesFront"
	trees_front_layer.z_index = -8
	trees_front_layer.position = Vector2(0, -400)
	trees_front_layer.motion_scale = Vector2(0.35, 0.100)
	pb.add_child(trees_front_layer)
	var trees_front_sprite := Sprite2D.new()
	trees_front_sprite.name = "TreesFrontSprite"
	var trees_front_tex := load("res://background/parallax/forest parallax/forest parallax trees_front.png")
	if trees_front_tex:
		trees_front_sprite.texture = trees_front_tex
	trees_front_sprite.centered = false
	trees_front_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	trees_front_layer.add_child(trees_front_sprite)
	if trees_front_tex and trees_front_tex is Texture2D:
		var tfw := (trees_front_tex as Texture2D).get_width()
		trees_front_layer.motion_mirroring = Vector2(float(tfw), 0.0)

	# Optional: simple clouds layer using same manager if available later
	# Cloud parallax layers
	var layer_far := ParallaxLayer.new(); layer_far.name = "ParallaxLayerFar"; layer_far.z_index = -19; layer_far.position = Vector2(0, -1); layer_far.motion_scale = Vector2(0.0, 0.02); pb.add_child(layer_far)
	var layer_mid := ParallaxLayer.new(); layer_mid.name = "ParallaxLayerMid"; layer_mid.z_index = -18; layer_mid.position = Vector2(0, -1); layer_mid.motion_scale = Vector2(0.0, 0.02); pb.add_child(layer_mid)
	var layer_near := ParallaxLayer.new(); layer_near.name = "ParallaxLayerNear"; layer_near.z_index = -17; layer_near.position = Vector2(0, -1); layer_near.motion_scale = Vector2(0.0, 0.02); pb.add_child(layer_near)

	# CloudManager from village
	var cloud_manager := Node2D.new(); cloud_manager.name = "CloudManager"; cloud_manager.z_index = -3
	var cloud_script := load("res://levels/ForestCloudManager.gd")
	if cloud_script:
		cloud_manager.set_script(cloud_script)
		cloud_manager.set("cloud_scene", load("res://village/scenes/cloud.tscn"))
		cloud_manager.set("cloud_textures", [
			load("res://village/assets/clouds/cloud1.png"),
			load("res://village/assets/clouds/cloud2.png"),
			load("res://village/assets/clouds/cloud3.png"),
			load("res://village/assets/clouds/cloud4.png"),
			load("res://village/assets/clouds/cloud5.png"),
			load("res://village/assets/clouds/cloud6.png"),
			load("res://village/assets/clouds/cloud7.png"),
			load("res://village/assets/clouds/cloud8.png")
		])
		cloud_manager.set("parallax_layer_paths", [
			NodePath("../ParallaxBackground/ParallaxLayerFar"),
			NodePath("../ParallaxBackground/ParallaxLayerMid"),
			NodePath("../ParallaxBackground/ParallaxLayerNear")
		])
		cloud_manager.set("min_spawn_interval", 5.0)
		cloud_manager.set("max_spawn_interval", 20.0)
		cloud_manager.set("cloud_y_position_min", 50.0)
		cloud_manager.set("cloud_y_position_max", 200.0)
	add_child(cloud_manager)
	# Kick one immediate spawn to verify visibility without relying on timer init
	cloud_manager.call_deferred("_spawn_cloud")

# --- Backtracking helpers ---
func _record_entry(node: Node2D, key: String) -> int:
	var entry: Dictionary = {
		"key": key,
		"position": node.position,
		"size": _get_size(node),
		"left": _get_conn_local(node, "left"),
		"right": _get_conn_local(node, "right"),
		"up": _get_conn_local(node, "up"),
		"down": _get_conn_local(node, "down"),
		"seed": randi(), # keep per-entry seed if stochastic content appears later
		"prev": -1,
		"next": -1,
		"scene_path": (node.get_scene_file_path() if node.has_method("get_scene_file_path") else "")
	}
	chunk_entries.append(entry)
	var idx: int = chunk_entries.size() - 1
	node.set_meta("entry_index", idx)
	index_to_node[idx] = node
	last_active_index = idx
	max_discovered_index = max(max_discovered_index, idx)
	if debug_enabled:
		_dbg("[Archive] added idx=" + str(idx) + " key=" + key + " pos=" + str(node.position))
	return idx

func _link_after(prev_idx: int, new_idx: int) -> void:
	if prev_idx >= 0 and prev_idx < chunk_entries.size():
		chunk_entries[prev_idx]["next"] = new_idx
	if new_idx >= 0 and new_idx < chunk_entries.size():
		chunk_entries[new_idx]["prev"] = prev_idx

func _link_before(target_idx: int, new_idx: int) -> void:
	var old_prev := -1
	if target_idx >= 0 and target_idx < chunk_entries.size():
		old_prev = int(chunk_entries[target_idx].get("prev", -1))
		chunk_entries[target_idx]["prev"] = new_idx
	if new_idx >= 0 and new_idx < chunk_entries.size():
		chunk_entries[new_idx]["next"] = target_idx
		chunk_entries[new_idx]["prev"] = old_prev
	if old_prev != -1:
		chunk_entries[old_prev]["next"] = new_idx

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
		var cached = index_to_node[idx]
		if cached != null and is_instance_valid(cached):
			return cached
	var entry: Dictionary = chunk_entries[idx]
	var key: String = String(entry.get("key", "linear"))
	var scene: PackedScene = null
	var stored_path: String = String(entry.get("scene_path", ""))
	if stored_path != "":
		scene = load(stored_path) as PackedScene
	else:
		var arr = scenes.get(key, [])
		if typeof(arr) == TYPE_ARRAY and (arr as Array).size() > 0:
			scene = (arr as Array)[randi() % (arr as Array).size()]
	if not scene:
		return null
	var inst: Node2D = scene.instantiate() as Node2D
	add_child(inst)
	inst.position = entry.get("position", Vector2.ZERO)
	inst.set_meta("entry_index", idx)
	_apply_unit_size(inst)
	# Rebuild forest decorations on restore as they are not archived
	call_deferred("_populate_forest_decorations_for_chunk", inst)
	# Optional future: apply stored seed to any stochastic sub-systems in the chunk
	if inst.has_method("set_meta") and entry.has("seed"):
		inst.set_meta("seed", entry["seed"]) 
	# Restore connection anchors if needed
	var leftp := inst.get_node_or_null("ConnectionPoints/left")
	if leftp and leftp is Node2D:
		(leftp as Node2D).position = entry.get("left", (leftp as Node2D).position)
	var rightp := inst.get_node_or_null("ConnectionPoints/right")
	if rightp and rightp is Node2D:
		(rightp as Node2D).position = entry.get("right", (rightp as Node2D).position)
	var upp := inst.get_node_or_null("ConnectionPoints/up")
	if upp and upp is Node2D:
		(upp as Node2D).position = entry.get("up", (upp as Node2D).position)
	var downp := inst.get_node_or_null("ConnectionPoints/down")
	if downp and downp is Node2D:
		(downp as Node2D).position = entry.get("down", (downp as Node2D).position)
	index_to_node[idx] = inst
	return inst

func _sweep_invalid_active_chunks() -> void:
	for i in range(active_chunks.size() - 1, -1, -1):
		var n := active_chunks[i]
		if n == null or not is_instance_valid(n):
			active_chunks.remove_at(i)

func _sort_active_by_x() -> void:
	if active_chunks.size() <= 1:
		return
	active_chunks.sort_custom(Callable(self, "_cmp_by_x"))

func _cmp_by_x(a, b) -> bool:
	if a == null or not is_instance_valid(a):
		return true
	if b == null or not is_instance_valid(b):
		return false
	return (a as Node2D).position.x < (b as Node2D).position.x
# Apply generator unit_size to known chunk types
func _apply_unit_size(inst: Node2D) -> void:
	if inst is ForestLinearChunk:
		(inst as ForestLinearChunk).unit_size = unit_size
	elif inst is ForestRampChunk:
		(inst as ForestRampChunk).unit_size = unit_size

# Try restore one chunk from archive to the left of current leftmost
func _restore_left_once() -> bool:
	if active_chunks.size() == 0:
		return false
	var left_node: Node2D = active_chunks[0]
	var left_idx: int = int(left_node.get_meta("entry_index") if left_node.has_meta("entry_index") else -1)
	if left_idx < 0 or left_idx >= chunk_entries.size():
		if debug_enabled:
			_dbg("[RestoreLeft] no more left to restore (left_idx<=0)")
		return false
	var target_idx: int = int(chunk_entries[left_idx].get("prev", -1))
	if target_idx == -1:
		if debug_enabled:
			_dbg("[RestoreLeft] prev link is -1 for left_idx=" + str(left_idx))
		return false
	# If prev is known but not discovered yet (index >= chunk_entries.size()), stop
	if target_idx >= chunk_entries.size():
		if debug_enabled:
			_dbg("[RestoreLeft] prev link points beyond discovered: target_idx=" + str(target_idx))
		return false
	if index_to_node.has(target_idx):
		var cached = index_to_node[target_idx]
		if cached != null and is_instance_valid(cached):
			if not active_chunks.has(cached):
				active_chunks.insert(0, cached)
				if debug_enabled:
					_dbg("[RestoreLeft] target alive but not active, inserted idx=" + str(target_idx))
			else:
				if debug_enabled:
					_dbg("[RestoreLeft] target already active idx=" + str(target_idx))
			return true
	var node: Node2D = _spawn_from_archive(target_idx)
	if node:
		active_chunks.insert(0, node)
		first_active_index = min(first_active_index, target_idx)
		if debug_enabled:
			_dbg("[RestoreLeft] restored idx=" + str(target_idx))
		return true
	if debug_enabled:
		_dbg("[RestoreLeft] failed to spawn idx=" + str(target_idx))
	return false

# Try restore one chunk from archive to the right of current rightmost
func _restore_right_once() -> bool:
	if active_chunks.size() == 0:
		return false
	var right_node: Node2D = active_chunks.back()
	var right_idx: int = int(right_node.get_meta("entry_index") if right_node.has_meta("entry_index") else -1)
	if right_idx < 0 or right_idx >= chunk_entries.size():
		return false
	var target_idx: int = int(chunk_entries[right_idx].get("next", -1))
	if target_idx == -1:
		if debug_enabled:
			_dbg("[RestoreRight] next link is -1 for right_idx=" + str(right_idx))
		return false
	var node: Node2D = _spawn_from_archive(target_idx)
	if node:
		active_chunks.append(node)
		last_end_x = node.position.x + _get_size(node).x
		if debug_enabled:
			_dbg("[RestoreRight] restored idx=" + str(target_idx))
		return true
	if debug_enabled:
		_dbg("[RestoreRight] failed idx=" + str(target_idx))
	return false

# --- Debug helpers ---
func _debug_dump_active_chunks(reason: String) -> void:
	print("\n[ForestDebug] Dump due to:", reason)
	var px := -1.0
	if player != null and is_instance_valid(player):
		px = player.global_position.x
	print("  player.x=", px, " current_row=", current_row, " window L/R=", window_left_count, "/", window_right_count)
	for i in range(active_chunks.size()):
		var n: Node2D = active_chunks[i]
		var key := _get_chunk_key(n)
		var sz := _get_size(n)
		var row := int(round(n.position.y / float(unit_size)))
		var cons := _get_chunk_connections(n)
		print("  [", i, "] key=", key, " pos=", n.position, " size=", sz, " row=", row, " cons=", cons)
	print("  last_end_x=", last_end_x, " entries=", chunk_entries.size(), " first_active_index=", first_active_index, " last_active_index=", last_active_index)

func _dbg(msg: String) -> void:
	if not debug_enabled:
		return
	var now := Time.get_ticks_msec()
	if msg == _last_dbg_text and now - _last_dbg_ms < debug_rate_ms:
		return
	_last_dbg_text = msg
	_last_dbg_ms = now
	print(msg)

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
	# Fallback: try reading a `connections` property if exposed
	var cons = null
	if n.has_method("get"):
		cons = n.get("connections")
	if cons is Array:
		for d in cons:
			result.append(str(d))
	return result

# --- Connection point helpers ---
func _get_conn_global(n: Node2D, name: String) -> Vector2:
	var node := n.get_node_or_null("ConnectionPoints/" + name)
	if node and node is Node2D:
		return (node as Node2D).global_position
	# Fallback to default midpoints if not present
	var sz := _get_size(n)
	match name:
		"left":
			return n.global_position + Vector2(0, sz.y * 0.5)
		"right":
			return n.global_position + Vector2(sz.x, sz.y * 0.5)
		"up":
			return n.global_position + Vector2(sz.x * 0.5, 0)
		"down":
			return n.global_position + Vector2(sz.x * 0.5, sz.y)
	return n.global_position

func _get_conn_local(n: Node2D, name: String) -> Vector2:
	var node := n.get_node_or_null("ConnectionPoints/" + name)
	if node and node is Node2D:
		return (node as Node2D).position
	# Fallback to default midpoints in local space
	var sz := _get_size(n)
	match name:
		"left":
			return Vector2(0, sz.y * 0.5)
		"right":
			return Vector2(sz.x, sz.y * 0.5)
		"up":
			return Vector2(sz.x * 0.5, 0)
		"down":
			return Vector2(sz.x * 0.5, sz.y)
	return Vector2.ZERO

# --- Forest tile-based decoration pass (3-tile wide footprint) ---
func _populate_forest_decorations_for_chunk(chunk_node: Node2D) -> void:
	if chunk_node == null or not is_instance_valid(chunk_node):
		return
	# Ensure we only populate once per chunk lifetime
	if chunk_node.get_meta("forest_decor_done", false):
		return
	var tile_map = chunk_node.find_child("TileMapLayer", true, false)
	if tile_map == null:
		return
	var tile_set: TileSet = null
	if tile_map.has_method("get"): # access as property via get("tile_set") to support TileMapLayer/TileMap
		tile_set = tile_map.get("tile_set")
	if tile_set == null:
		return
	# Find custom data layer index for decor anchors
	var decor_layer_name := "decor_anchor"
	var decor_layer_index := -1
	for i in range(tile_set.get_custom_data_layers_count()):
		if tile_set.get_custom_data_layer_name(i) == decor_layer_name:
			decor_layer_index = i
			break
	if decor_layer_index == -1:
		return
	# Iterate cells and place forest decors on tagged anchors (TileMap layer 0)
	var used_cells: Array[Vector2i] = tile_map.get_used_cells()
	if used_cells.is_empty():
		chunk_node.set_meta("forest_decor_done", true)
		return
	var rng_chance := 0.28 # overall placement chance per valid 3-tile span
	var placed_spans := {} # key by center cell to avoid duplicates
	for cell in used_cells:
		var td: TileData = tile_map.get_cell_tile_data(cell) as TileData
		if td == null:
			continue
		var tag = td.get_custom_data(decor_layer_name)
		if typeof(tag) != TYPE_STRING:
			continue
		var tag_s := String(tag)
		if tag_s != "forest_floor_surface" and tag_s != "floor_surface":
			continue
		# Validate 3-tile horizontal span centered at this cell
		var left := cell + Vector2i(-1, 0)
		var right := cell + Vector2i(1, 0)
		if not _forest_cell_has_decor_tag(tile_map, left, decor_layer_name, tag_s):
			continue
		if not _forest_cell_has_decor_tag(tile_map, right, decor_layer_name, tag_s):
			continue
		# Optional vertical clearance for taller assets (e.g., trunks)
		if not _forest_has_vertical_clearance(tile_map, cell, 3, 2):
			# Still allow low-profile assets if ground-only clearance fails; keep trying others
			pass
		# Random gate to reduce density
		if randf() > rng_chance:
			continue
		# Avoid double placement on the same span
		var key := str(cell.x, ":", cell.y)
		if placed_spans.has(key):
			continue
		placed_spans[key] = true
		# Pick a forest decor
		var decor_name: String = _forest_pick_decor_name()
		if decor_name.is_empty():
			continue
		# Create decoration via DecorationSpawner factory to reuse visuals/anchors
		var spawner := DecorationSpawner.new()
		add_child(spawner) # keep signals alive if any
		var decoration := spawner.create_decoration_instance(decor_name, DecorationConfig.DecorationType.BACKGROUND)
		if decoration == null:
			spawner.queue_free()
			continue
		add_child(decoration)
		# Compute span-centered position and set; bottom-center anchoring will sit on ground; fixup will snap
		var spawn_pos: Vector2 = _forest_compute_span_center(tile_map, left, right)
		# Lift up by 45px per request
		spawn_pos.y -= 30.0
		decoration.global_position = spawn_pos
		# Render behind tiles: negative z
		if decoration is CanvasItem:
			(decoration as CanvasItem).z_as_relative = true
			(decoration as CanvasItem).z_index = -5
		var spr: Sprite2D = decoration.get_node_or_null("Sprite") as Sprite2D
		if spr:
			spr.z_as_relative = true
			spr.z_index = -5
	# Mark done for this chunk
	chunk_node.set_meta("forest_decor_done", true)

func _forest_cell_has_decor_tag(tile_map, cell: Vector2i, layer_name: String, expected: String) -> bool:
	var td: TileData = tile_map.get_cell_tile_data(cell) as TileData
	if td == null:
		return false
	var tag = td.get_custom_data(layer_name)
	if typeof(tag) != TYPE_STRING:
		return false
	var s := String(tag)
	return (s == expected or s == "forest_floor_surface" or s == "floor_surface")

func _forest_has_vertical_clearance(tile_map, center: Vector2i, w_tiles: int, h_tiles: int) -> bool:
	# Ensure empty space above the base row for tall decors across the span
	var half_left := int(floor((w_tiles - 1) / 2.0))
	var half_right := w_tiles - 1 - half_left
	for dy in range(1, h_tiles + 1):
		for dx in range(-half_left, half_right + 1):
			var c := center + Vector2i(dx, -dy)
			var sid: int = int(tile_map.get_cell_source_id(c))
			if sid != -1:
				return false
	return true

func _forest_compute_span_center(tile_map, left_cell: Vector2i, right_cell: Vector2i) -> Vector2:
	var ts: Vector2 = Vector2((tile_map.get("tile_set") as TileSet).tile_size)
	var left_px: Vector2 = tile_map.to_global(tile_map.map_to_local(left_cell)) + ts * 0.5
	var right_px: Vector2 = tile_map.to_global(tile_map.map_to_local(right_cell)) + ts * 0.5
	var mid: Vector2 = (left_px + right_px) * 0.5
	# Slight downward settle so bottom-anchored sprites hug the floor; fixup will refine
	return mid + Vector2(0, 5)

func _forest_pick_decor_name() -> String:
	# Weighted random among registered forest background decors
	var cfg := DecorationConfig.new()
	var pool: Dictionary = cfg.get_decorations_for_type(DecorationConfig.DecorationType.BACKGROUND)
	var names = ["forest_bush", "forest_grass", "forest_trunk", "forest_rock"]
	var total := 0
	for n in names:
		if pool.has(n):
			var d: Dictionary = pool.get(n, {})
			total += int(d.get("weight", 1))
	if total <= 0:
		return ""
	var roll := randi() % total
	var acc := 0
	for n in names:
		if pool.has(n):
			var d2: Dictionary = pool.get(n, {})
			acc += int(d2.get("weight", 1))
			if roll < acc:
				return n
	return names[0]
