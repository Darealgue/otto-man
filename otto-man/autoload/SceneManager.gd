extends Node

signal scene_change_started(target_path: String)
signal scene_change_completed(new_path: String)
signal load_menu_requested
signal settings_menu_requested

const MAIN_MENU_SCENE: String = "res://scenes/MainMenu.tscn"
const VILLAGE_SCENE: String = "res://village/scenes/VillageScene.tscn"
const DUNGEON_SCENE: String = "res://scenes/test_level.tscn"
const FOREST_SCENE: String = "res://scenes/forest.tscn"
const PortalAreaScript = preload("res://village/scripts/PortalArea.gd")
const LoadingScreenScene = preload("res://ui/LoadingScreen.tscn")
const TimeManagerPath := "/root/TimeManager"

var current_scene_path: String = ""
var previous_scene_path: String = ""
var current_payload: Dictionary = {}
var _level_entry_time: Dictionary = {}  # {scene_path: {day, hour, minute}} - Track when player entered each level
var _loading_screen_instance: CanvasLayer = null

func _ready() -> void:
	current_scene_path = _detect_initial_scene()
	print("[SceneManager] ready, current=", current_scene_path)

func start_new_game() -> void:
	current_payload = {}
	previous_scene_path = ""
	if is_instance_valid(VillageManager) and VillageManager.has_method("reset_saved_state_for_new_game"):
		VillageManager.reset_saved_state_for_new_game()
	_change_scene(VILLAGE_SCENE, true)

func return_to_main_menu() -> void:
	current_payload = {}
	_change_scene(MAIN_MENU_SCENE)

func open_load_menu() -> void:
	load_menu_requested.emit()

func open_settings() -> void:
	settings_menu_requested.emit()

func change_to_village(payload: Dictionary = {}, force_reload: bool = false) -> void:
	# Calculate time spent in previous level (forest/dungeon)
	var time_spent = _calculate_time_spent_in_level()
	if time_spent > 0.0:
		payload["time_spent_in_level"] = time_spent
	_handle_travel_time(payload)
	current_payload = payload.duplicate(true)
	_clear_level_entry_time()
	_change_scene(VILLAGE_SCENE, force_reload)

func change_to_dungeon(payload: Dictionary = {}, force_reload: bool = false) -> void:
	# When going TO dungeon, only advance travel time, don't simulate production
	# (because village production should continue while player is away)
	_handle_travel_time_out_only(payload)
	if PortalAreaScript:
		PortalAreaScript.reset_unique("dungeon_exit")
	current_payload = payload.duplicate(true)
	# Record entry time AFTER travel time has been applied (so we track time inside the level)
	_record_level_entry_time(DUNGEON_SCENE)
	_change_scene(DUNGEON_SCENE, force_reload)

func change_to_forest(payload: Dictionary = {}, force_reload: bool = false) -> void:
	# When going TO forest, only advance travel time, don't simulate production
	# (because village production should continue while player is away)
	_handle_travel_time_out_only(payload)
	current_payload = payload.duplicate(true)
	# Record entry time AFTER travel time has been applied (so we track time inside the level)
	_record_level_entry_time(FOREST_SCENE)
	_change_scene(FOREST_SCENE, force_reload)

func _handle_travel_time_out_only(payload: Dictionary) -> void:
	"""Handle travel time when LEAVING village (going to forest/dungeon).
	Only advances time, does NOT simulate production (production continues while away)."""
	var out_hours: float = float(payload.get("travel_hours_out", 0.0))
	
	# Validation: Check for invalid values
	if out_hours <= 0.0:
		return
	if is_nan(out_hours) or is_inf(out_hours):
		push_error("[SceneManager] ❌ Invalid travel_hours_out value: %f (NaN or Infinity). Skipping time advance." % out_hours)
		return
	# Check for extremely large values
	var max_hours: float = 1000.0 * 24.0
	if out_hours > max_hours:
		push_warning("[SceneManager] ⚠️ Very large travel time detected: %.1f hours. Capping to %.1f hours." % [out_hours, max_hours])
		out_hours = max_hours
	
	var time_manager: Node = get_node_or_null(TimeManagerPath)
	if not time_manager:
		push_error("[SceneManager] ❌ TimeManager not found!")
		return
	
	print("[SceneManager] _handle_travel_time_out_only: out=%.1f hours (no production simulation)" % out_hours)
	
	# Just advance time, no production simulation
	if time_manager.has_method("advance_hours"):
		time_manager.call("advance_hours", out_hours)

func _handle_travel_time(payload: Dictionary) -> void:
	"""Handle travel time when RETURNING to village.
	Advances time AND simulates production for the time spent away.
	
	Note: When returning, we simulate:
	- travel_hours_back: Time to travel back to village
	- time_spent_in_level: Time spent in forest/dungeon (already advanced by TimeManager, but we simulate production)
	
	We do NOT simulate travel_hours_out again because it was already advanced when leaving.
	"""
	var out_hours: float = float(payload.get("travel_hours_out", 0.0))
	var back_hours: float = float(payload.get("travel_hours_back", 0.0))
	var time_spent: float = float(payload.get("time_spent_in_level", 0.0))  # Time spent in forest/dungeon
	
	# Validation: Check for invalid values
	if is_nan(back_hours) or is_inf(back_hours):
		push_error("[SceneManager] ❌ Invalid travel_hours_back value: %f (NaN or Infinity). Skipping time advance." % back_hours)
		return
	if is_nan(time_spent) or is_inf(time_spent):
		push_warning("[SceneManager] ⚠️ Invalid time_spent_in_level value: %f (NaN or Infinity). Setting to 0." % time_spent)
		time_spent = 0.0
	if time_spent < 0.0:
		push_warning("[SceneManager] ⚠️ Negative time_spent_in_level detected: %f. Setting to 0." % time_spent)
		time_spent = 0.0
	
	# When returning, time_spent was already advanced by TimeManager during gameplay
	# So we only need to advance back_hours for the travel back
	# But we simulate production for (back_hours + time_spent) total time
	
	var time_to_advance: float = back_hours  # Only advance travel back time
	var time_to_simulate: float = back_hours + time_spent  # Simulate production for total time away
	
	# Check for extremely large values
	var max_hours: float = 1000.0 * 24.0
	if time_to_advance > max_hours:
		push_warning("[SceneManager] ⚠️ Very large travel back time detected: %.1f hours. Capping to %.1f hours." % [time_to_advance, max_hours])
		time_to_advance = max_hours
	if time_to_simulate > max_hours:
		push_warning("[SceneManager] ⚠️ Very large simulation time detected: %.1f hours. Capping to %.1f hours." % [time_to_simulate, max_hours])
		time_to_simulate = max_hours
	
	if time_to_advance <= 0.0:
		return
	var time_manager: Node = get_node_or_null(TimeManagerPath)
	if not time_manager:
		return
	
	var village_manager = get_node_or_null("/root/VillageManager")
	
	# Get start time for simulation - use snapshot time if available (when player left village)
	# Otherwise fall back to current time
	var start_day: int = 0
	var start_hour: int = 0
	var start_minute: int = 0
	
	if village_manager:
		var snapshot_time = village_manager.get("_saved_snapshot_time")
		if snapshot_time is Dictionary and not snapshot_time.is_empty():
			start_day = int(snapshot_time.get("day", 0))
			start_hour = int(snapshot_time.get("hour", 0))
			start_minute = int(snapshot_time.get("minute", 0))
			print("[SceneManager] Using snapshot time for simulation: Day %d, %02d:%02d" % [start_day, start_hour, start_minute])
		else:
			# Fallback to current time if snapshot time not available
			if time_manager.has_method("get_day"):
				start_day = time_manager.get_day()
			if time_manager.has_method("get_hour"):
				start_hour = time_manager.get_hour()
			if time_manager.has_method("get_minute"):
				start_minute = time_manager.get_minute()
			print("[SceneManager] No snapshot time found, using current time: Day %d, %02d:%02d" % [start_day, start_hour, start_minute])
	else:
		# Fallback if VillageManager not available
		if time_manager.has_method("get_day"):
			start_day = time_manager.get_day()
		if time_manager.has_method("get_hour"):
			start_hour = time_manager.get_hour()
		if time_manager.has_method("get_minute"):
			start_minute = time_manager.get_minute()
	
	print("[SceneManager] _handle_travel_time (RETURN): out=%.1f, back=%.1f, spent=%.1f" % [out_hours, back_hours, time_spent])
	print("[SceneManager] Will advance time: %.1f hours, simulate production: %.1f hours" % [time_to_advance, time_to_simulate])
	
	# Calculate total minutes for simulation
	var minutes_per_hour: int = 60
	if "MINUTES_PER_HOUR" in time_manager:
		minutes_per_hour = time_manager.MINUTES_PER_HOUR
	var total_minutes: int = int(round(time_to_simulate * float(minutes_per_hour)))
	
	# Check if VillageManager's time_advanced signal is connected BEFORE advancing time
	var signal_connected: bool = false
	if village_manager and time_manager.has_signal("time_advanced"):
		var connections = time_manager.time_advanced.get_connections()
		for conn in connections:
			if conn.get("target") == village_manager:
				signal_connected = true
				break
	
	# IMPORTANT: Restore saved resources BEFORE simulating production
	# This ensures we simulate based on the resources we had when leaving
	# We restore here because simulation happens before register_village_scene
	if village_manager:
		var saved_resources = village_manager.get("_saved_resource_levels")
		var saved_progress = village_manager.get("_saved_base_production_progress")
		if saved_resources is Dictionary and not saved_resources.is_empty():
			print("[SceneManager] Restoring resources before simulation: ", saved_resources)
			village_manager.resource_levels = (saved_resources as Dictionary).duplicate(true)
		if saved_progress is Dictionary and not saved_progress.is_empty():
			village_manager.base_production_progress = (saved_progress as Dictionary).duplicate(true)
	
	# Advance time (only travel back time, time_spent was already advanced during gameplay)
	# This will emit time_advanced signal if VillageManager is connected
	# If signal is connected, it will trigger simulation automatically
	# If NOT connected, we need to call simulation manually AFTER time advance
	if time_manager.has_method("advance_hours"):
		time_manager.call("advance_hours", time_to_advance)
		# Log end time
		var end_day: int = start_day
		var end_hour: int = start_hour
		if time_manager.has_method("get_day"):
			end_day = time_manager.get_day()
		if time_manager.has_method("get_hour"):
			end_hour = time_manager.get_hour()
		print("[SceneManager] End time after advance: Day %d, %02d:%02d" % [end_day, end_hour, time_manager.get_minute() if time_manager.has_method("get_minute") else 0])
	
	# Safety net: If signal is NOT connected, manually trigger simulation
	# This ensures resource production happens even if signal connection failed
	if village_manager and total_minutes > 0 and not signal_connected:
		if village_manager.has_method("_simulate_time_skip"):
			print("[SceneManager] ⚠️ Time_advanced signal not connected, calling simulation directly")
			village_manager.call("_simulate_time_skip", total_minutes, start_day, start_hour, start_minute)
		else:
			print("[SceneManager] ⚠️ VillageManager._simulate_time_skip method not found!")
	
	# Clear snapshot time after simulation (so it doesn't interfere with future trips)
	if village_manager:
		village_manager.set("_saved_snapshot_time", {})

func get_current_payload() -> Dictionary:
	return current_payload.duplicate(true)

func clear_payload() -> void:
	current_payload.clear()

func _change_scene(target_path: String, force_reload: bool = false) -> void:
	if target_path == "":
		push_warning("SceneManager: Hedef sahne yolu boş")
		return
	if not ResourceLoader.exists(target_path):
		push_error("SceneManager: Sahne bulunamadı -> %s" % target_path)
		return
	var same_scene := current_scene_path == target_path
	if same_scene and not force_reload:
		print("[SceneManager] same scene request, ignoring", target_path)
		return
	
	# Show loading screen
	_show_loading_screen(_get_scene_name(target_path))
	
	# Use call_deferred to ensure loading screen is visible before heavy operations
	call_deferred("_perform_scene_change", target_path, same_scene and force_reload)

func _show_loading_screen(scene_name: String = "") -> void:
	if not LoadingScreenScene:
		return
	
	# Create loading screen instance if it doesn't exist
	if not is_instance_valid(_loading_screen_instance):
		_loading_screen_instance = LoadingScreenScene.instantiate() as CanvasLayer
		get_tree().root.add_child(_loading_screen_instance)
	
	# Show loading screen
	var loading_text = "Yükleniyor"
	if not scene_name.is_empty():
		loading_text += "... " + scene_name
	else:
		loading_text += "..."
	
	# Script is attached to CanvasLayer, so methods are directly accessible
	if _loading_screen_instance.has_method("show_loading"):
		_loading_screen_instance.show_loading(loading_text)
	else:
		push_error("[SceneManager] LoadingScreen.show_loading() method not found!")

func _hide_loading_screen() -> void:
	if is_instance_valid(_loading_screen_instance):
		_loading_screen_instance.hide_loading()
		# Don't remove the instance, keep it for next use
		# The loading screen will handle its own fade out

func _perform_scene_change(target_path: String, is_reload: bool) -> void:
	# Allow the loading screen to render before heavy operations
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var same_scene := current_scene_path == target_path
	
	if same_scene and is_reload:
		print("[SceneManager] reloading current scene ->", target_path)
		scene_change_started.emit(target_path)
		previous_scene_path = current_scene_path
		Engine.time_scale = 1.0
		
		# Update progress
		if is_instance_valid(_loading_screen_instance):
			_loading_screen_instance.set_progress(25.0)
		
		var reload_err := get_tree().reload_current_scene()
		if reload_err != OK:
			var error_msg = "Sahne yeniden yüklenemedi: %s\nHata kodu: %d" % [target_path, reload_err]
			push_error("SceneManager: %s" % error_msg)
			_hide_loading_screen()
			_handle_scene_load_error(error_msg, target_path)
			return
		
		# Wait a frame for scene to be ready
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_hide_loading_screen()
		scene_change_completed.emit(target_path)
		return
	
	print("[SceneManager] changing scene ->", target_path)
	scene_change_started.emit(target_path)
	previous_scene_path = current_scene_path
	current_scene_path = target_path
	
	# Update progress
	if is_instance_valid(_loading_screen_instance):
		_loading_screen_instance.set_progress(25.0)
	
	# Reset time scale before scene change to prevent player state issues
	Engine.time_scale = 1.0
	
	# Change scene
	var err := get_tree().change_scene_to_file(target_path)
	if err != OK:
		var error_msg = "Sahne yüklenemedi: %s\nHata kodu: %d" % [target_path, err]
		push_error("SceneManager: %s" % error_msg)
		_hide_loading_screen()
		_handle_scene_load_error(error_msg, target_path)
		return
	
	# Wait for scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	# Update progress and hide
	if is_instance_valid(_loading_screen_instance):
		_loading_screen_instance.set_progress(100.0)
	
	# Small delay for progress to be visible, then fade out
	await get_tree().create_timer(0.2).timeout
	_hide_loading_screen()
	
	# Wait for fade out to complete
	if is_instance_valid(_loading_screen_instance):
		await _loading_screen_instance.fade_out_complete
	
	# Update UI visibility based on scene
	_update_ui_visibility(target_path)
	
	scene_change_completed.emit(target_path)

func _update_ui_visibility(scene_path: String) -> void:
	"""Show/hide health and stamina bars based on current scene."""
	var is_combat_scene = (scene_path == DUNGEON_SCENE or scene_path == FOREST_SCENE)
	var should_show_ui = is_combat_scene
	
	print("[SceneManager] 🎮 Updating UI visibility for scene: %s (show UI: %s)" % [scene_path, should_show_ui])
	
	# Wait a frame for scene to be fully loaded
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Find health display and stamina bar from game_ui scene
	var health_display = get_tree().get_first_node_in_group("health_display")
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	
	# Also check for UI nodes in current scene
	var current_scene = get_tree().current_scene
	var player = null  # Declare outside if block
	
	if current_scene:
		# Check for GameUI scene
		var game_ui = current_scene.get_node_or_null("GameUI")
		if game_ui:
			var hd = game_ui.get_node_or_null("Container/HealthDisplay")
			if hd and hd is Control:
				if should_show_ui:
					hd.show()
				else:
					hd.hide()
			
			var sb = game_ui.get_node_or_null("Container/StaminaBar")
			if sb and sb is Control:
				if should_show_ui:
					sb.show()
				else:
					sb.hide()
			
			# Update DungeonGoldDisplay visibility
			var dgd = game_ui.get_node_or_null("Container/DungeonGoldDisplay")
			if dgd and dgd is Control:
				# Visibility managed by DungeonGoldDisplay itself
				pass
		
		# Check for player UI (player.tscn has UI as child)
		player = current_scene.get_node_or_null("Player")
		if not player:
			# Try finding player in group
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				player = players[0]
		
		if player:
			var player_ui = player.get_node_or_null("UI")
			if player_ui:
				var hd_player = player_ui.get_node_or_null("HealthDisplay")
				if hd_player and hd_player is Control:
					if should_show_ui:
						hd_player.show()
					else:
						hd_player.hide()
				
				var sb_player = player_ui.get_node_or_null("StaminaBar")
				if sb_player and sb_player is Control:
					if should_show_ui:
						sb_player.show()
					else:
						sb_player.hide()
	
	# Update nodes found via groups (only if they are Control nodes)
	if health_display and health_display is Control:
		if "_force_visible" in health_display:
			health_display._force_visible = should_show_ui
		if should_show_ui:
			health_display.show()
		else:
			health_display.hide()
	
	if stamina_bar and stamina_bar is Control:
		if "_force_visible" in stamina_bar:
			stamina_bar._force_visible = should_show_ui
		if should_show_ui:
			stamina_bar.show()
		else:
			stamina_bar.hide()
	
	# Update player UI nodes if found
	if player and player.has_node("UI"):
		var player_ui = player.get_node("UI")
		var hd_player = player_ui.get_node_or_null("HealthDisplay")
		if hd_player and hd_player is Control:
			if "_force_visible" in hd_player:
				hd_player._force_visible = should_show_ui
			if should_show_ui:
				hd_player.show()
			else:
				hd_player.hide()
		
		var sb_player = player_ui.get_node_or_null("StaminaBar")
		if sb_player and sb_player is Control:
			if "_force_visible" in sb_player:
				sb_player._force_visible = should_show_ui
			if should_show_ui:
				sb_player.show()
			else:
				sb_player.hide()
	
	# Also update GameUI nodes
	if current_scene:
		var game_ui = current_scene.get_node_or_null("GameUI")
		if game_ui:
			var hd = game_ui.get_node_or_null("Container/HealthDisplay")
			if hd and hd is Control:
				if "_force_visible" in hd:
					hd._force_visible = should_show_ui
				if should_show_ui:
					hd.show()
				else:
					hd.hide()
			
			var sb = game_ui.get_node_or_null("Container/StaminaBar")
			if sb and sb is Control:
				if "_force_visible" in sb:
					sb._force_visible = should_show_ui
				if should_show_ui:
					sb.show()
				else:
					sb.hide()
			
			# Update DungeonGoldDisplay
			var dgd = game_ui.get_node_or_null("Container/DungeonGoldDisplay")
			if dgd and dgd is Control:
				if should_show_ui:
					# Visibility will be handled by DungeonGoldDisplay itself based on gold amount
					pass
				else:
					dgd.hide()
	
	print("[SceneManager] ✅ UI visibility updated")

func _get_scene_name(scene_path: String) -> String:
	if scene_path == MAIN_MENU_SCENE:
		return "Ana Menü"
	elif scene_path == VILLAGE_SCENE:
		return "Köy"
	elif scene_path == DUNGEON_SCENE:
		return "Zindan"
	elif scene_path == FOREST_SCENE:
		return "Orman"
	else:
		var filename = scene_path.get_file().get_basename()
		return filename.capitalize()

func _detect_initial_scene() -> String:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path != "":
		return scene.scene_file_path
	return ""

func _record_level_entry_time(scene_path: String) -> void:
	"""Record when player enters a level (forest/dungeon)"""
	var time_manager = get_node_or_null(TimeManagerPath)
	if not time_manager:
		return
	var entry_time: Dictionary = {}
	if time_manager.has_method("get_day"):
		entry_time["day"] = time_manager.get_day()
	if time_manager.has_method("get_hour"):
		entry_time["hour"] = time_manager.get_hour()
	if time_manager.has_method("get_minute"):
		entry_time["minute"] = time_manager.get_minute()
	_level_entry_time[scene_path] = entry_time
	print("[SceneManager] Recorded entry time for %s: Day %d, %02d:%02d" % [scene_path, entry_time.get("day", 0), entry_time.get("hour", 0), entry_time.get("minute", 0)])

func _calculate_time_spent_in_level() -> float:
	"""Calculate hours spent in the current level (forest/dungeon)"""
	var time_manager = get_node_or_null(TimeManagerPath)
	if not time_manager:
		return 0.0
	
	# Validate that we have valid entry time data
	var entry_key: String = ""
	if current_scene_path == FOREST_SCENE:
		entry_key = FOREST_SCENE
	elif current_scene_path == DUNGEON_SCENE:
		entry_key = DUNGEON_SCENE
	else:
		return 0.0
	
	if not _level_entry_time.has(entry_key):
		push_warning("[SceneManager] ⚠️ No entry time recorded for current level. Returning 0 hours.")
		return 0.0
	
	var entry_time = _level_entry_time[entry_key]
	var entry_day: int = entry_time.get("day", 0)
	var entry_hour: int = entry_time.get("hour", 0)
	var entry_minute: int = entry_time.get("minute", 0)
	
	var exit_day: int = 0
	var exit_hour: int = 0
	var exit_minute: int = 0
	if time_manager.has_method("get_day"):
		exit_day = time_manager.get_day()
	if time_manager.has_method("get_hour"):
		exit_hour = time_manager.get_hour()
	if time_manager.has_method("get_minute"):
		exit_minute = time_manager.get_minute()
	
	# Calculate total minutes difference
	var minutes_per_hour: int = 60
	if "MINUTES_PER_HOUR" in time_manager:
		minutes_per_hour = time_manager.MINUTES_PER_HOUR
	var hours_per_day: int = 24
	if "HOURS_PER_DAY" in time_manager:
		hours_per_day = time_manager.HOURS_PER_DAY
	
	# Convert to total minutes
	var entry_total_minutes: int = entry_day * hours_per_day * minutes_per_hour + entry_hour * minutes_per_hour + entry_minute
	var exit_total_minutes: int = exit_day * hours_per_day * minutes_per_hour + exit_hour * minutes_per_hour + exit_minute
	
	var diff_minutes: int = exit_total_minutes - entry_total_minutes
	if diff_minutes < 0:
		# This shouldn't happen, but handle it gracefully
		push_warning("[SceneManager] ⚠️ Negative time difference detected (exit time before entry time). This may indicate a time reset or bug. Returning 0 hours.")
		return 0.0
	
	var time_spent_hours: float = float(diff_minutes) / float(minutes_per_hour)
	print("[SceneManager] Time spent in level: %.2f hours (from Day %d %02d:%02d to Day %d %02d:%02d)" % [time_spent_hours, entry_day, entry_hour, entry_minute, exit_day, exit_hour, exit_minute])
	return time_spent_hours

func _clear_level_entry_time() -> void:
	"""Clear entry time tracking when returning to village"""
	_level_entry_time.clear()

func _handle_scene_load_error(error_message: String, failed_scene_path: String) -> void:
	"""Handle scene loading errors by showing error dialog and returning to village"""
	push_error("[SceneManager] Scene load error: %s" % error_message)
	
	# Try to show error dialog
	var error_dialog_scene = load("res://ui/ErrorDialog.tscn")
	if error_dialog_scene:
		var error_dialog = error_dialog_scene.instantiate()
		get_tree().root.add_child(error_dialog)
		if error_dialog.has_method("show_error"):
			error_dialog.show_error(
				"Sahne Yüklenemedi",
				"Oyun sahnesi yüklenirken bir hata oluştu.\n\nKöye dönülüyor..."
			)
			# Wait for dialog to close, then return to village
			if error_dialog.has_signal("dialog_closed"):
				error_dialog.dialog_closed.connect(func(): _return_to_village_on_error())
			else:
				# Fallback: return to village after a delay
				await get_tree().create_timer(2.0).timeout
				_return_to_village_on_error()
		else:
			_return_to_village_on_error()
	else:
		# Fallback: just return to village
		_return_to_village_on_error()

func _return_to_village_on_error() -> void:
	"""Return to village scene as fallback when scene loading fails"""
	if ResourceLoader.exists(VILLAGE_SCENE):
		print("[SceneManager] Returning to village due to scene load error")
		current_scene_path = VILLAGE_SCENE
		var err := get_tree().change_scene_to_file(VILLAGE_SCENE)
		if err != OK:
			push_error("[SceneManager] CRITICAL: Failed to return to village scene!")
	else:
		push_error("[SceneManager] CRITICAL: Village scene not found!")
