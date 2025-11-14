extends Area2D

const PLAYER_GROUP: StringName = &"player"
const MissionResultDialogScene = preload("res://ui/MissionResultDialog.tscn")

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
@export var check_mission_status: bool = true  # Check mission status when returning to village

var _players_in_area: Array[Node] = []
var _transition_triggered: bool = false
var _hold_timer: float = 0.0
var _mission_result_dialog: CanvasLayer = null

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
	if _is_travel_input_pressed():
		_hold_timer += _delta
		if _hold_timer < hold_time_required:
			return
	else:
		_hold_timer = 0.0
		return
	_trigger_transition()

func _is_travel_input_pressed() -> bool:
	var logical_action := travel_action
	if logical_action == StringName(""):
		logical_action = StringName("portal_enter")
	if logical_action == StringName("portal_enter") or logical_action == StringName("ui_up"):
		return InputManager.is_portal_enter_pressed()
	if logical_action == StringName("interact"):
		return InputManager.is_interact_pressed()
	return InputManager.is_pressed(logical_action)

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
	
	# Check mission status if returning to village
	if destination == "village":
		# Transfer carried resources from forest to village before mission check
		if payload_source == "forest":
			_transfer_forest_resources_to_village()
		
		if check_mission_status:
			await _check_and_show_mission_result(payload)
		else:
			# Even without mission check, apply roguelike mechanics on return
			var player_stats = get_node_or_null("/root/PlayerStats")
			var is_dead: bool = false
			if player_stats:
				if "current_health" in player_stats:
					var health = player_stats.get("current_health")
					if health is float or health is int:
						is_dead = float(health) <= 0.0
			_apply_roguelike_mechanics(is_dead)
		return
	
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

func _check_and_show_mission_result(payload: Dictionary) -> void:
	"""Check mission status and show result dialog before returning to village."""
	var player := _get_active_player()
	var is_dead: bool = false
	
	# Check if player is dead
	var player_stats = get_node_or_null("/root/PlayerStats")
	if player_stats:
		if "current_health" in player_stats:
			var health = player_stats.get("current_health")
			if health is float or health is int:
				is_dead = float(health) <= 0.0
		elif "health" in player_stats:
			var health = player_stats.get("health")
			if health is float or health is int:
				is_dead = float(health) <= 0.0
	elif player:
		# Fallback: check player node directly
		if "current_health" in player:
			var health = player.get("current_health")
			if health is float or health is int:
				is_dead = float(health) <= 0.0
		elif "health" in player:
			var health = player.get("health")
			if health is float or health is int:
				is_dead = float(health) <= 0.0
	
	# Check active missions
	var active_missions: Dictionary = {}
	var mission_manager = get_node_or_null("/root/MissionManager")
	if mission_manager and mission_manager.has_method("get_active_missions"):
		active_missions = mission_manager.get_active_missions()
	
	# Determine result type
	var result_type: String = ""
	var mission_name: String = ""
	var rewards: Dictionary = {}
	var penalties: Dictionary = {}
	
	# Track inventory count before clearing (for death message)
	var inventory_count_before_death: int = 0
	var global_player_data = get_node_or_null("/root/GlobalPlayerData")
	if global_player_data and "envanter" in global_player_data:
		var envanter: Array = global_player_data.get("envanter")
		inventory_count_before_death = envanter.size()
	
	if is_dead:
		result_type = "death"
		mission_name = "Ölüm"
		# Store inventory count for death message
		payload["lost_items_count"] = inventory_count_before_death
	elif not active_missions.is_empty():
		# Manual return - mission cancelled
		result_type = "cancelled"
		# Get first active mission info
		var first_cariye_id = active_missions.keys()[0]
		var first_mission_id = active_missions[first_cariye_id]
		
		if mission_manager and "missions" in mission_manager:
			var missions_dict = mission_manager.get("missions")
			if missions_dict is Dictionary and first_mission_id in missions_dict:
				var mission = missions_dict[first_mission_id]
				if mission is Dictionary:
					mission_name = mission.get("name", first_mission_id)
					penalties = mission.get("penalties", {})
				elif mission.has_method("get"):
					mission_name = mission.get("name") if "name" in mission else first_mission_id
					penalties = mission.get("penalties", {}) if "penalties" in mission else {}
		
		# Cancel the mission
		if mission_manager and mission_manager.has_method("cancel_mission"):
			mission_manager.cancel_mission(first_cariye_id, first_mission_id)
	
	# Show dialog if there's a result (before applying roguelike mechanics)
	if not result_type.is_empty():
		_show_mission_result_dialog(result_type, mission_name, rewards, penalties, payload.get("lost_items_count", 0))
		await _mission_result_dialog.confirmed if is_instance_valid(_mission_result_dialog) else get_tree().create_timer(0.1).timeout
	
	# Apply roguelike mechanics AFTER dialog (clear inventory, powerups, reset health)
	_apply_roguelike_mechanics(is_dead)
	
	# Proceed with transition
	match destination:
		"village":
			SceneManager.change_to_village(payload)
		_:
			push_warning("PortalArea: Unexpected destination after mission check: %s" % destination)
	_hold_timer = 0.0

func _transfer_forest_resources_to_village() -> void:
	"""Transfer carried resources from PlayerStats to GameManager village resources.
	Only called when returning from forest to village."""
	var game_manager = get_node_or_null("/root/GameManager")
	if !game_manager:
		push_warning("[PortalArea] GameManager not found, cannot transfer resources")
		return
	var transferred = game_manager.transfer_carried_resources_to_village()
	if transferred.is_empty():
		return
	# Log transferred resources
	var log_parts := []
	for type in transferred.keys():
		var amount: int = int(transferred[type])
		if amount > 0:
			log_parts.append("%d %s" % [amount, type])
	if log_parts.size() > 0:
		print("[PortalArea] 🌲 Forest resources transferred to village: %s" % ", ".join(log_parts))

func _apply_roguelike_mechanics(is_dead: bool) -> void:
	"""
	Apply roguelike mechanics when returning to village:
	- If dead: Clear inventory, clear powerups, reset health
	- If alive: Clear powerups, reset health, keep inventory (items are brought back)
	"""
	var powerup_manager = get_node_or_null("/root/PowerupManager")
	var player_stats = get_node_or_null("/root/PlayerStats")
	var global_player_data = get_node_or_null("/root/GlobalPlayerData")
	
	# Track what was lost for death dialog
	var lost_items_count: int = 0
	
	# Clear powerups (always, both death and success)
	if powerup_manager and powerup_manager.has_method("clear_all_powerups"):
		powerup_manager.clear_all_powerups()
		print("[PortalArea] 🎮 Roguelike: All powerups cleared")
	
	# Reset health (always)
	if player_stats:
		var max_health = player_stats.get_stat("max_health")
		player_stats.current_health = max_health
		if player_stats.has_signal("health_changed"):
			player_stats.health_changed.emit(max_health)
		print("[PortalArea] 💚 Roguelike: Health reset to %.1f" % max_health)
	
	# Handle inventory and dungeon gold
	if is_dead:
		# Death: Clear inventory and dungeon gold
		if global_player_data and "envanter" in global_player_data:
			var envanter: Array = global_player_data.get("envanter")
			lost_items_count = envanter.size()
			global_player_data.set("envanter", [])
			print("[PortalArea] 💀 Roguelike: Inventory cleared (%d items lost)" % lost_items_count)
		
		# Clear dungeon gold on death
		if global_player_data and global_player_data.has_method("clear_dungeon_gold"):
			var lost_gold = 0
			if "dungeon_gold" in global_player_data:
				lost_gold = global_player_data.dungeon_gold
			global_player_data.clear_dungeon_gold()
			print("[PortalArea] 💀 Roguelike: Lost %d gold on death" % lost_gold)
	else:
		# Success: Keep inventory, transfer dungeon gold to global
		if global_player_data and "envanter" in global_player_data:
			var envanter: Array = global_player_data.get("envanter")
			print("[PortalArea] ✅ Roguelike: Successfully returned with %d items" % envanter.size())
		
		# Transfer dungeon gold to global gold on successful exit
		if global_player_data and global_player_data.has_method("transfer_dungeon_gold_to_global"):
			var transferred = global_player_data.transfer_dungeon_gold_to_global()
			if transferred > 0:
				print("[PortalArea] 💰 Roguelike: Transferred %d gold to global inventory" % transferred)
	
	# Reset kill count (for powerup system)
	if powerup_manager and "enemy_kill_count" in powerup_manager:
		powerup_manager.set("enemy_kill_count", 0)
		print("[PortalArea] 🎮 Roguelike: Kill count reset")

func _show_mission_result_dialog(result_type: String, mission_name: String, rewards: Dictionary, penalties: Dictionary, lost_items_count: int = 0) -> void:
	"""Show mission result dialog."""
	if not MissionResultDialogScene:
		return
	
	# Create dialog instance if needed
	if not is_instance_valid(_mission_result_dialog):
		_mission_result_dialog = MissionResultDialogScene.instantiate() as CanvasLayer
		get_tree().root.add_child(_mission_result_dialog)
	
	# Show result
	if _mission_result_dialog.has_method("show_result"):
		_mission_result_dialog.show_result(result_type, mission_name, rewards, penalties, lost_items_count)

func _find_nodes_with_property(parent: Node, property_name: String) -> Array[Node]:
	"""Find all nodes with a specific property."""
	var result: Array[Node] = []
	if property_name in parent or (parent.has_method("get") and parent.get(property_name) != null):
		result.append(parent)
	for child in parent.get_children():
		result.append_array(_find_nodes_with_property(child, property_name))
	return result
