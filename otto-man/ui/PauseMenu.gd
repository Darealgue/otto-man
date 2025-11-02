extends Control

## PauseMenu - Oyun içi pause menüsü
## Start tuşu (veya ESC) ile açılır, oyunu durdurur

signal resume_requested()
signal save_requested()
signal load_requested()
signal settings_requested()
signal main_menu_requested()

@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var save_button: Button = $Panel/VBoxContainer/SaveButton
@onready var load_button: Button = $Panel/VBoxContainer/LoadButton
@onready var settings_button: Button = $Panel/VBoxContainer/SettingsButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton
@onready var load_game_menu: Control = $LoadGameMenu
@onready var save_game_menu: Control = $SaveGameMenu
@onready var confirm_dialog: Control = $ConfirmDialog

var is_paused: bool = false
var _camera_frozen_pos: Vector2 = Vector2.ZERO
var _camera_freeze_timer: Timer = null
var _camera_smoothing_was_enabled: bool = false

func _ready() -> void:
	_ensure_nodes()
	_connect_signals()
	_setup_load_game_menu()
	_setup_save_game_menu()
	_setup_confirm_dialog()
	visible = false
	# Force UI to ignore world transforms/cameras
	set_as_top_level(true)
	global_position = Vector2.ZERO
	# Set process mode to always so we can detect input even when paused
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	# Create timer to freeze camera position while menu is open
	_camera_freeze_timer = Timer.new()
	_camera_freeze_timer.wait_time = 0.016  # ~60 FPS
	_camera_freeze_timer.timeout.connect(_freeze_camera_position)
	_camera_freeze_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_camera_freeze_timer)

func _ensure_nodes() -> void:
	if not resume_button:
		push_error("[PauseMenu] ResumeButton not found!")
	if not save_button:
		push_error("[PauseMenu] SaveButton not found!")
	if not load_button:
		push_error("[PauseMenu] LoadButton not found!")
	if not settings_button:
		push_error("[PauseMenu] SettingsButton not found!")
	if not main_menu_button:
		push_error("[PauseMenu] MainMenuButton not found!")

func _connect_signals() -> void:
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

func _setup_load_game_menu() -> void:
	if not load_game_menu:
		# Try to load LoadGameMenu scene
		var load_menu_scene = load("res://ui/LoadGameMenu.tscn")
		if load_menu_scene:
			load_game_menu = load_menu_scene.instantiate()
			load_game_menu.name = "LoadGameMenu"
			add_child(load_game_menu)
		else:
			push_warning("[PauseMenu] Failed to load LoadGameMenu scene!")
			return
	
	if load_game_menu.has_signal("slot_selected"):
		load_game_menu.slot_selected.connect(_on_load_game_slot_selected)
	if load_game_menu.has_signal("back_requested"):
		load_game_menu.back_requested.connect(_on_load_game_back)
	
	if load_game_menu.has_method("hide_menu"):
		load_game_menu.hide_menu()

func _setup_save_game_menu() -> void:
	if not save_game_menu:
		# Try to load SaveGameMenu scene
		var save_menu_scene = load("res://ui/SaveGameMenu.tscn")
		if save_menu_scene:
			save_game_menu = save_menu_scene.instantiate()
			save_game_menu.name = "SaveGameMenu"
			add_child(save_game_menu)
		else:
			push_warning("[PauseMenu] Failed to load SaveGameMenu scene!")
			return
	
	if save_game_menu.has_signal("slot_selected"):
		save_game_menu.slot_selected.connect(_on_save_game_slot_selected)
	if save_game_menu.has_signal("back_requested"):
		save_game_menu.back_requested.connect(_on_save_game_back)
	
	if save_game_menu.has_method("hide_menu"):
		save_game_menu.hide_menu()

func _setup_confirm_dialog() -> void:
	if not confirm_dialog:
		push_warning("[PauseMenu] ConfirmDialog not found!")
		return
	
	if confirm_dialog.has_signal("confirmed"):
		confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	if confirm_dialog.has_signal("cancelled"):
		confirm_dialog.cancelled.connect(_on_confirm_dialog_cancelled)

var _pending_main_menu_action: bool = false
var _pending_save_slot: int = -1

func _input(event: InputEvent) -> void:
	# Check for pause input (ESC or Start button)
	# Only process if not already paused by tree
	if get_tree().paused:
		# If paused but menu not visible, ignore (another system paused)
		if not visible and not is_paused:
			return
	
	# ESC always toggles pause
	if event.is_action_pressed("ui_cancel"):
		if is_paused:
			_close_menu()
		else:
			_open_menu()
		return
	
	# Start button (gamepad) - button_index 6 or 10
	if event is InputEventJoypadButton:
		var joypad_event = event as InputEventJoypadButton
		# Start button: 6 (most controllers) or 10 (some controllers)
		if joypad_event.pressed and (joypad_event.button_index == 6 or joypad_event.button_index == 10):
			if is_paused:
				_close_menu()
			else:
				_open_menu()

func _open_menu() -> void:
	if is_paused:
		return
	
	is_paused = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Center player camera when menu opens
	_center_player_camera()
	
	if resume_button:
		resume_button.grab_focus()
	
	print("[PauseMenu] Menu opened, game paused")

func _center_player_camera() -> void:
	print("[PauseMenu] 🔍 DEBUG: Starting camera setup...")
	
	# Find player in the scene
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("[PauseMenu] ⚠️ DEBUG: Player not found!")
		return
	print("[PauseMenu] ✅ DEBUG: Player found at: %s" % player.global_position)
	
	# Disable ANY other cameras in the scene (including overview cameras and scene-level cameras)
	var scene_root = get_tree().current_scene
	if scene_root:
		print("[PauseMenu] 🔍 DEBUG: Scene root: %s" % scene_root.name)
		
		# CRITICAL: Disable scene-level Camera2D (VillageScene has one that might be enabled)
		var scene_camera = scene_root.get_node_or_null("Camera2D")
		if scene_camera and scene_camera is Camera2D:
			print("[PauseMenu] ⚠️ DEBUG: Found scene-level Camera2D, disabling it")
			(scene_camera as Camera2D).enabled = false
			print("[PauseMenu] ✅ DEBUG: Scene Camera2D disabled")
		
		# Check for LevelGenerator (dungeon)
		var level_gen = scene_root.get_node_or_null("LevelGenerator")
		if level_gen:
			print("[PauseMenu] 🔍 DEBUG: Found LevelGenerator")
			if "is_overview_active" in level_gen:
				var was_overview = level_gen.get("is_overview_active")
				print("[PauseMenu] 🔍 DEBUG: Overview was active: %s" % was_overview)
				level_gen.set("is_overview_active", false)
				# Disable overview camera
				if "overview_camera" in level_gen:
					var overview_cam = level_gen.get("overview_camera")
					if overview_cam is Camera2D:
						print("[PauseMenu] 🔍 DEBUG: Overview camera found at: %s" % (overview_cam as Camera2D).global_position)
						(overview_cam as Camera2D).enabled = false
						print("[PauseMenu] ✅ DEBUG: Overview camera disabled")
		
		# Check for ForestLevelGenerator
		var forest_gen = scene_root.get_node_or_null("ForestLevelGenerator")
		if forest_gen:
			print("[PauseMenu] 🔍 DEBUG: Found ForestLevelGenerator")
			if "is_overview_active" in forest_gen:
				var was_overview = forest_gen.get("is_overview_active")
				print("[PauseMenu] 🔍 DEBUG: Forest overview was active: %s" % was_overview)
				forest_gen.set("is_overview_active", false)
				# Disable overview camera
				if "overview_camera" in forest_gen:
					var overview_cam = forest_gen.get("overview_camera")
					if overview_cam is Camera2D:
						print("[PauseMenu] 🔍 DEBUG: Forest overview camera found at: %s" % (overview_cam as Camera2D).global_position)
						(overview_cam as Camera2D).enabled = false
						print("[PauseMenu] ✅ DEBUG: Forest overview camera disabled")
	
	# Find ALL cameras in the scene and disable any that aren't the player's camera
	# (Do this after we find player's camera so we can exclude it)
	var all_cameras: Array[Camera2D] = []
	if scene_root:
		all_cameras = _find_all_cameras(scene_root)
	
	# Find player's camera (don't move it, just make sure it's active)
	var camera: Camera2D = null
	if player.has_node("Camera2D"):
		camera = player.get_node("Camera2D") as Camera2D
		print("[PauseMenu] 🔍 DEBUG: Player has Camera2D node")
	
	if camera:
		var cam_pos_before = camera.global_position
		print("[PauseMenu] 🔍 DEBUG: Player camera position BEFORE: %s" % cam_pos_before)
		print("[PauseMenu] 🔍 DEBUG: Player camera enabled BEFORE: %s" % camera.enabled)
		print("[PauseMenu] 🔍 DEBUG: Player camera is_current BEFORE: %s" % camera.is_current())
		print("[PauseMenu] 🔍 DEBUG: Camera smoothing enabled BEFORE: %s" % camera.position_smoothing_enabled)
		
		# FREEZE camera position - save it and prevent any changes
		_camera_frozen_pos = cam_pos_before
		
		# CRITICAL: Disable position smoothing - this is what causes camera movement!
		_camera_smoothing_was_enabled = camera.position_smoothing_enabled
		camera.position_smoothing_enabled = false
		print("[PauseMenu] ✅ DEBUG: Camera smoothing DISABLED (was: %s)" % _camera_smoothing_was_enabled)
		
		camera.process_mode = Node.PROCESS_MODE_DISABLED  # Stop camera from processing
		
		# Enable and activate player camera
		camera.enabled = true
		camera.make_current()
		
		# Force camera to stay at frozen position
		camera.global_position = _camera_frozen_pos
		
		# Start timer to keep freezing position
		if _camera_freeze_timer:
			_camera_freeze_timer.start()
		
		# Check after setting
		var cam_pos_after = camera.global_position
		print("[PauseMenu] 🔍 DEBUG: Player camera position AFTER: %s" % cam_pos_after)
		print("[PauseMenu] 🔍 DEBUG: Player camera enabled AFTER: %s" % camera.enabled)
		print("[PauseMenu] 🔍 DEBUG: Player camera is_current AFTER: %s" % camera.is_current())
		print("[PauseMenu] ✅ DEBUG: Camera frozen at position: %s" % _camera_frozen_pos)
		
		# Now disable all other cameras (after we've set player's camera)
		for cam in all_cameras:
			if cam != camera:  # Don't disable player's camera
				print("[PauseMenu] ⚠️ DEBUG: Found other camera: %s at %s, disabling" % [cam.name, cam.global_position])
				cam.enabled = false
	else:
		print("[PauseMenu] ⚠️ DEBUG: Player camera not found, trying fallback...")
		# Fallback: try to find any camera but don't move it
		var active_camera: Camera2D = null
		var viewport = get_viewport()
		if viewport:
			active_camera = viewport.get_camera_2d()
			if active_camera:
				print("[PauseMenu] 🔍 DEBUG: Found active camera: %s at %s" % [active_camera.name, active_camera.global_position])
				# Just make sure it stays current, don't move
				active_camera.make_current()
				print("[PauseMenu] ✅ DEBUG: Active camera kept current")
		
		# Disable all other cameras if player camera not found
		for cam in all_cameras:
			if cam != active_camera:
				print("[PauseMenu] ⚠️ DEBUG: Found other camera: %s at %s, disabling" % [cam.name, cam.global_position])
				cam.enabled = false
	
	# Check what camera is actually active now
	var viewport = get_viewport()
	if viewport:
		var final_camera = viewport.get_camera_2d()
		if final_camera:
			print("[PauseMenu] ✅ DEBUG: Final active camera: %s at %s" % [final_camera.name, final_camera.global_position])
		else:
			print("[PauseMenu] ⚠️ DEBUG: No active camera found!")

func _find_all_cameras(node: Node) -> Array[Camera2D]:
	"""Recursively find all Camera2D nodes in the scene tree"""
	var cameras: Array[Camera2D] = []
	
	if node is Camera2D:
		cameras.append(node as Camera2D)
	
	for child in node.get_children():
		cameras.append_array(_find_all_cameras(child))
	
	return cameras

func _close_menu() -> void:
	if not is_paused:
		return
	
	# Stop freezing camera
	if _camera_freeze_timer:
		_camera_freeze_timer.stop()
	
	# Restore camera process mode and smoothing
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("Camera2D"):
		var camera = player.get_node("Camera2D") as Camera2D
		if camera:
			camera.process_mode = Node.PROCESS_MODE_INHERIT
			# Restore smoothing if it was enabled before
			camera.position_smoothing_enabled = _camera_smoothing_was_enabled
			print("[PauseMenu] ✅ DEBUG: Camera unfrozen, process mode and smoothing restored (smoothing: %s)" % _camera_smoothing_was_enabled)
	
	is_paused = false
	visible = false
	get_tree().paused = false
	
	# Hide load game menu if open
	if load_game_menu and load_game_menu.has_method("hide_menu"):
		load_game_menu.hide_menu()
	
	# Hide save game menu if open
	if save_game_menu and save_game_menu.has_method("hide_menu"):
		save_game_menu.hide_menu()
	
	print("[PauseMenu] Menu closed, game resumed")

func _freeze_camera_position() -> void:
	# Continuously freeze camera position while menu is open
	if not is_paused:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	if player.has_node("Camera2D"):
		var camera = player.get_node("Camera2D") as Camera2D
		if camera:
			# Always force camera to frozen position (even if it hasn't moved)
			# This prevents any system from moving it
			if camera.global_position.distance_to(_camera_frozen_pos) > 0.01:
				# Camera moved! Force it back
				print("[PauseMenu] ⚠️ DEBUG: Camera moved to %s, forcing back to %s (distance: %.2f)" % [camera.global_position, _camera_frozen_pos, camera.global_position.distance_to(_camera_frozen_pos)])
				camera.global_position = _camera_frozen_pos
			
			# Extra safety: Disable camera processing if not already disabled
			if camera.process_mode != Node.PROCESS_MODE_DISABLED:
				camera.process_mode = Node.PROCESS_MODE_DISABLED
				print("[PauseMenu] 🔒 DEBUG: Camera process_mode disabled (was not disabled)")
			
			# Ensure camera is current
			if not camera.is_current():
				camera.make_current()
				print("[PauseMenu] ✅ DEBUG: Camera made current again")

func _on_resume_pressed() -> void:
	_play_click()
	resume_requested.emit()
	_close_menu()

func _on_save_pressed() -> void:
	_play_click()
	save_requested.emit()
	_show_save_slots()

func _on_load_pressed() -> void:
	_play_click()
	load_requested.emit()
	_show_load_menu()

func _on_settings_pressed() -> void:
	_play_click()
	settings_requested.emit()
	# Placeholder - settings menu not implemented yet
	print("[PauseMenu] Settings menu not implemented yet")

func _on_main_menu_pressed() -> void:
	_play_click()
	# Show confirmation dialog
	_pending_main_menu_action = true
	if confirm_dialog and confirm_dialog.has_method("show_dialog"):
		confirm_dialog.show_dialog("Ana Menüye Dön", "Ana menüye dönmek istediğinizden emin misiniz?\n(Kaydedilmemiş ilerleme kaybolabilir)", true)
	else:
		# Fallback if dialog not available
		_do_return_to_main_menu()

func _show_save_slots() -> void:
	if save_game_menu and save_game_menu.has_method("show_menu"):
		save_game_menu.show_menu()
		save_game_menu.set_process_mode(Node.PROCESS_MODE_ALWAYS)

func _show_load_menu() -> void:
	if load_game_menu and load_game_menu.has_method("show_menu"):
		load_game_menu.show_menu()
		load_game_menu.set_process_mode(Node.PROCESS_MODE_ALWAYS)

func _on_load_game_slot_selected(slot_id: int) -> void:
	print("[PauseMenu] Loading game from slot %d..." % slot_id)
	if is_instance_valid(SaveManager):
		# Unpause before loading (loading will change scenes)
		get_tree().paused = false
		if SaveManager.load_game(slot_id):
			print("[PauseMenu] ✅ Game loaded successfully")
			# Menu will be closed when scene changes
		else:
			push_error("[PauseMenu] Failed to load game from slot %d" % slot_id)
			# Re-pause if load failed
			get_tree().paused = true
	else:
		push_error("[PauseMenu] SaveManager not available!")

func _on_load_game_back() -> void:
	if load_game_menu and load_game_menu.has_method("hide_menu"):
		load_game_menu.hide_menu()
	if resume_button:
		resume_button.grab_focus()

func _on_save_game_slot_selected(slot_id: int) -> void:
	print("[PauseMenu] Saving game to slot %d..." % slot_id)
	if is_instance_valid(SaveManager):
		if SaveManager.save_game(slot_id):
			print("[PauseMenu] ✅ Game saved successfully to slot %d" % slot_id)
			# Show success message
			if confirm_dialog and confirm_dialog.has_method("show_dialog"):
				confirm_dialog.show_dialog("Başarılı", "Oyun slot %d'ye kaydedildi!" % slot_id, false)
				_pending_save_slot = slot_id
			# Hide save menu after successful save
			if save_game_menu and save_game_menu.has_method("hide_menu"):
				save_game_menu.hide_menu()
			if resume_button:
				resume_button.grab_focus()
		else:
			push_error("[PauseMenu] Failed to save game to slot %d" % slot_id)
			# Show error message
			if confirm_dialog and confirm_dialog.has_method("show_dialog"):
				confirm_dialog.show_dialog("Hata", "Kayıt başarısız!", false)
	else:
		push_error("[PauseMenu] SaveManager not available!")

func _on_save_game_back() -> void:
	if save_game_menu and save_game_menu.has_method("hide_menu"):
		save_game_menu.hide_menu()
	if resume_button:
		resume_button.grab_focus()

func _on_confirm_dialog_confirmed() -> void:
	if _pending_main_menu_action:
		_pending_main_menu_action = false
		_do_return_to_main_menu()
	elif _pending_save_slot >= 0:
		_pending_save_slot = -1
		# Just acknowledge the save success, nothing else to do

func _on_confirm_dialog_cancelled() -> void:
	_pending_main_menu_action = false
	_pending_save_slot = -1

func _do_return_to_main_menu() -> void:
	get_tree().paused = false  # Unpause before changing scene
	if is_instance_valid(SceneManager):
		SceneManager.return_to_main_menu()
	else:
		push_error("[PauseMenu] SceneManager not available!")

func _play_click() -> void:
	if is_instance_valid(SoundManager) and SoundManager.has_method("play_ui"):
		SoundManager.play_ui("click")
