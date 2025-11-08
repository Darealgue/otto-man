extends Node

## GameState - Oyun state yönetimi
## Beta Yol Haritası FAZ 4: Oyun State Yönetimi

enum State {
	MENU,      # Ana menü
	VILLAGE,   # Köy sahnesi
	DUNGEON,   # Zindan sahnesi (görev içinde)
	FOREST,    # Orman sahnesi (görev içinde)
	LOADING    # Sahne yükleniyor
}

signal state_changed(new_state, previous_state)
signal pause_requested()
signal resume_requested()

var current_state = State.MENU
var previous_state = State.MENU
var is_paused: bool = false

func _ready() -> void:
	# Detect initial state based on current scene
	_detect_initial_state()
	print("[GameState] Initialized with state: %s" % _state_to_string(current_state))
	
	# Connect to SceneManager signals if available
	if is_instance_valid(SceneManager):
		if SceneManager.has_signal("scene_change_started"):
			if not SceneManager.scene_change_started.is_connected(_on_scene_change_started):
				SceneManager.scene_change_started.connect(_on_scene_change_started)
		if SceneManager.has_signal("scene_change_completed"):
			if not SceneManager.scene_change_completed.is_connected(_on_scene_change_completed):
				SceneManager.scene_change_completed.connect(_on_scene_change_completed)

func _detect_initial_state() -> void:
	"""Detect initial state from current scene"""
	var scene = get_tree().current_scene
	if not scene:
		current_state = State.MENU
		return
	
	var scene_path = scene.scene_file_path
	if not scene_path.is_empty():
		if "MainMenu" in scene_path:
			current_state = State.MENU
		elif "VillageScene" in scene_path or "village" in scene_path.to_lower():
			current_state = State.VILLAGE
		elif "test_level" in scene_path or "dungeon" in scene_path.to_lower():
			current_state = State.DUNGEON
		elif "forest" in scene_path.to_lower():
			current_state = State.FOREST
		else:
			current_state = State.MENU
	else:
		current_state = State.MENU
	
	previous_state = current_state

func _on_scene_change_started(target_path: String) -> void:
	"""Called when scene change starts"""
	_change_state(State.LOADING)

func _on_scene_change_completed(new_path: String) -> void:
	"""Called when scene change completes"""
	# Determine new state from scene path
	var new_state = State.MENU
	
	if "MainMenu" in new_path:
		new_state = State.MENU
	elif "VillageScene" in new_path or "village" in new_path.to_lower():
		new_state = State.VILLAGE
	elif "test_level" in new_path or "dungeon" in new_path.to_lower():
		new_state = State.DUNGEON
	elif "forest" in new_path.to_lower():
		new_state = State.FOREST
	
	_change_state(new_state)

func _change_state(new_state) -> void:
	"""Change game state and emit signal"""
	if new_state == current_state:
		return
	
	previous_state = current_state
	current_state = new_state
	
	print("[GameState] State changed: %s -> %s" % [_state_to_string(previous_state), _state_to_string(new_state)])
	state_changed.emit(new_state, previous_state)
	
	# Auto-pause/unpause based on state
	_handle_state_pause()

func _handle_state_pause() -> void:
	"""Handle pause/unpause based on state"""
	match current_state:
		State.MENU, State.LOADING:
			# Always unpause in menu/loading
			if is_paused:
				resume()
		State.VILLAGE, State.DUNGEON, State.FOREST:
			# Game states - pause is handled by PauseMenu
			pass

func set_state(new_state) -> void:
	"""Public method to manually set state"""
	_change_state(new_state)

func get_state():
	"""Get current state"""
	return current_state

func get_state_string() -> String:
	"""Get current state as string"""
	return _state_to_string(current_state)

func is_in_menu() -> bool:
	"""Check if currently in menu"""
	return current_state == State.MENU

func is_in_game() -> bool:
	"""Check if currently in game (village, dungeon, or forest)"""
	return current_state == State.VILLAGE or current_state == State.DUNGEON or current_state == State.FOREST

func is_in_combat() -> bool:
	"""Check if currently in combat scene (dungeon or forest)"""
	return current_state == State.DUNGEON or current_state == State.FOREST

func is_loading() -> bool:
	"""Check if currently loading"""
	return current_state == State.LOADING

func pause() -> void:
	"""Pause the game"""
	if is_paused:
		return
	
	is_paused = true
	get_tree().paused = true
	pause_requested.emit()
	print("[GameState] Game paused")

func resume() -> void:
	"""Resume the game"""
	if not is_paused:
		return
	
	is_paused = false
	get_tree().paused = false
	resume_requested.emit()
	print("[GameState] Game resumed")

func toggle_pause() -> void:
	"""Toggle pause state"""
	if is_paused:
		resume()
	else:
		pause()

func _state_to_string(state) -> String:
	"""Convert state enum to string"""
	match state:
		State.MENU:
			return "MENU"
		State.VILLAGE:
			return "VILLAGE"
		State.DUNGEON:
			return "DUNGEON"
		State.FOREST:
			return "FOREST"
		State.LOADING:
			return "LOADING"
		_:
			return "UNKNOWN"
