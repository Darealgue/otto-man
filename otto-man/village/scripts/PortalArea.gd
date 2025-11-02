extends Area2D

const PLAYER_GROUP: StringName = &"player"

static var _unique_registry: Dictionary = {}

@export_enum("forest", "dungeon", "village") var destination: String = "forest"
@export var travel_action: StringName = &"ui_up"
@export var hold_time_required: float = 0.1
@export_range(0.0, 24.0, 0.1) var travel_hours_out: float = 0.0
@export_range(0.0, 24.0, 0.1) var travel_hours_back: float = 0.0
@export var use_level_based_return_time: bool = false  # If true, calculate return time based on dungeon level
@export_range(0.0, 24.0, 0.1) var base_return_hours: float = 4.0  # Base return time for level 1
@export_range(0.0, 10.0, 0.5) var hours_per_level_increase: float = 1.0  # Additional hours per level beyond 1
@export var payload_source: String = ""
@export var payload_reason: String = ""
@export var payload_extra: Dictionary = {}
@export var unique_key: String = ""

var _players_in_area: Array[Node] = []
var _transition_triggered: bool = false
var _hold_timer: float = 0.0

static func reset_unique(key: String = "") -> void:
	if key.is_empty():
		_unique_registry.clear()
	else:
		_unique_registry.erase(key)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process(true)
	if not unique_key.is_empty():
		if _unique_registry.has(unique_key):
			queue_free()
			return
		_unique_registry[unique_key] = true

func _process(_delta: float) -> void:
	if _transition_triggered:
		return
	if _players_in_area.is_empty():
		return
	if travel_action != StringName(""):
		if Input.is_action_pressed(travel_action):
			_hold_timer += _delta
			if _hold_timer < hold_time_required:
				return
		else:
			_hold_timer = 0.0
			return
	_trigger_transition()

func _trigger_transition() -> void:
	var player := _get_active_player()
	if player == null:
		return
	if not is_instance_valid(SceneManager):
		push_warning("SceneManager autoload bulunamadı (portal)")
		return
	_transition_triggered = true
	var payload: Dictionary = {}
	for key in payload_extra.keys():
		payload[key] = payload_extra[key]
	if travel_hours_out != 0.0:
		payload["travel_hours_out"] = travel_hours_out
	
	# Calculate return time (level-based or fixed)
	var calculated_return_hours: float = travel_hours_back
	if use_level_based_return_time and destination == "village" and payload_source == "dungeon":
		var dungeon_level: int = _get_dungeon_level()
		if dungeon_level > 0:
			calculated_return_hours = base_return_hours + float(dungeon_level - 1) * hours_per_level_increase
			print("[PortalArea] 📊 Level-based return time: Level %d -> %.1f hours (base: %.1f + %.1f per level)" % [dungeon_level, calculated_return_hours, base_return_hours, hours_per_level_increase])
		else:
			print("[PortalArea] ⚠️ Could not find dungeon level, using fixed return time: %.1f hours" % travel_hours_back)
	
	if calculated_return_hours > 0.0:
		payload["travel_hours_back"] = calculated_return_hours
	
	if not payload_source.is_empty():
		payload["source"] = payload_source
	if not payload_reason.is_empty():
		payload["reason"] = payload_reason
	match destination:
		"forest":
			SceneManager.change_to_forest(payload)
		"dungeon":
			SceneManager.change_to_dungeon(payload)
		"village":
			SceneManager.change_to_village(payload)
		_:
			push_warning("PortalArea: bilinmeyen hedef '%s'" % destination)
	_hold_timer = 0.0

func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if not body.is_in_group(PLAYER_GROUP):
		return
	if body in _players_in_area:
		return
	_players_in_area.append(body)

func _on_body_exited(body: Node) -> void:
	if body == null:
		return
	if not body.is_in_group(PLAYER_GROUP):
		return
	_players_in_area.erase(body)
	if _players_in_area.is_empty():
		_transition_triggered = false
		_hold_timer = 0.0

func _get_active_player() -> Node:
	for candidate in _players_in_area:
		if is_instance_valid(candidate):
			return candidate
	return null

func _get_dungeon_level() -> int:
	"""Find the current dungeon level by searching for LevelGenerator node."""
	var scene_root := get_tree().current_scene
	if not scene_root:
		return 0
	
	# Try to find LevelGenerator node directly
	var level_gen := scene_root.get_node_or_null("LevelGenerator")
	if level_gen and "current_level" in level_gen:
		var level: int = level_gen.current_level
		return level
	
	# Try to find it recursively
	level_gen = _find_node_recursive(scene_root, "LevelGenerator")
	if level_gen and "current_level" in level_gen:
		var level: int = level_gen.current_level
		return level
	
	# Fallback: try to find any node with current_level property
	var candidates := _find_nodes_with_property(scene_root, "current_level")
	for candidate in candidates:
		if candidate.has_method("get") or "current_level" in candidate:
			var level_val = candidate.get("current_level") if candidate.has_method("get") else candidate.current_level
			if level_val is int or level_val is float:
				return int(level_val)
	
	return 0

func _find_node_recursive(parent: Node, node_name: String) -> Node:
	"""Recursively search for a node by name."""
	if parent.name == node_name:
		return parent
	for child in parent.get_children():
		var found := _find_node_recursive(child, node_name)
		if found:
			return found
	return null

func _find_nodes_with_property(parent: Node, property_name: String) -> Array[Node]:
	"""Find all nodes with a specific property."""
	var result: Array[Node] = []
	if property_name in parent or (parent.has_method("get") and parent.get(property_name) != null):
		result.append(parent)
	for child in parent.get_children():
		result.append_array(_find_nodes_with_property(child, property_name))
	return result

