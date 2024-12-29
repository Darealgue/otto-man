extends Node

signal enemy_killed
signal powerup_applied(powerup: PowerupResource)

const KILLS_FOR_POWERUP := 1

var active_powerups: Array[PowerupResource] = []
var enemy_kill_count := 0
var player: CharacterBody2D
var powerup_selection_ui: CanvasLayer

func _ready() -> void:
	enemy_killed.connect(_on_enemy_killed)
	print("DEBUG: PowerupManager ready")
	var powerups = _get_available_powerups()
	print("DEBUG: Found " + str(powerups.size()) + " powerups")
	for p in powerups:
		print("DEBUG: Found powerup: " + p.name)

func register_player(p: CharacterBody2D) -> void:
	player = p
	print("DEBUG: Registered player: ", player)
	# Ensure player is still valid when applying powerups
	player.tree_exited.connect(func(): player = null)
	# Connect to player death signal
	if player.has_signal("died"):
		player.died.connect(_on_player_died)
		print("DEBUG: Connected to player death signal")

func _on_enemy_killed() -> void:
	enemy_kill_count += 1
	print("DEBUG: Enemy killed, count: ", enemy_kill_count, ", needed: ", KILLS_FOR_POWERUP)
	if enemy_kill_count >= KILLS_FOR_POWERUP:
		print("DEBUG: Triggering powerup selection")
		enemy_kill_count = 0
		_show_powerup_selection()

func _show_powerup_selection() -> void:
	print("DEBUG: Showing powerup selection")
	# Create powerup selection UI if it doesn't exist
	if !powerup_selection_ui or !is_instance_valid(powerup_selection_ui):
		print("DEBUG: Creating new powerup selection UI")
		powerup_selection_ui = preload("res://ui/powerup_selection.tscn").instantiate()
		get_tree().root.add_child(powerup_selection_ui)
		print("DEBUG: Added powerup selection UI to scene tree")
		await get_tree().process_frame
	
	# Get random powerups
	var powerups = get_random_powerups(3)
	print("DEBUG: Selected powerups for UI: ", powerups.map(func(p): return p.name))
	
	# Show UI and pause game
	if is_instance_valid(powerup_selection_ui) and powerup_selection_ui.has_method("setup_powerups"):
		print("DEBUG: Setting up powerups in UI")
		powerup_selection_ui.setup_powerups(powerups)
		powerup_selection_ui.show_ui(true)  # Make sure UI is visible
		print("DEBUG: Pausing game")
		get_tree().paused = true
	else:
		print("ERROR: PowerupSelection UI is not valid or missing setup_powerups method!")
		if !is_instance_valid(powerup_selection_ui):
			print("ERROR: UI instance is not valid")
		if !powerup_selection_ui.has_method("setup_powerups"):
			print("ERROR: UI instance missing setup_powerups method")

func get_random_powerups(count: int = 3) -> Array[PowerupResource]:
	var available_powerups := _get_available_powerups()
	print("DEBUG: Getting random powerups from ", available_powerups.size(), " available powerups")
	var selected: Array[PowerupResource] = []
	
	while selected.size() < count and available_powerups.size() > 0:
		# Create a new instance of a random powerup
		var index = randi() % available_powerups.size()
		var powerup = available_powerups[index].duplicate()
		available_powerups.erase(available_powerups[index])
		
		# Set rarity based on weights
		var total_weight = 0.0
		for weight in powerup.RARITY_CHANCES.values():
			total_weight += weight
		
		var random_value = randf() * total_weight
		var current_weight = 0.0
		
		for i in range(powerup.RARITY_CHANCES.size()):
			var rarity_name = ["Common", "Rare", "Epic", "Legendary"][i]
			current_weight += powerup.RARITY_CHANCES[rarity_name]
			if random_value <= current_weight:
				powerup.rarity = i
				break
		
		selected.append(powerup)
		print("DEBUG: Selected powerup: ", powerup.name, " (", ["Common", "Rare", "Epic", "Legendary"][powerup.rarity], ")")
	
	return selected

func apply_powerup(powerup: PowerupResource) -> void:
	if powerup == null:
		print("ERROR: Cannot apply null powerup")
		return
		
	if !is_instance_valid(player):
		print("ERROR: No valid player to apply powerup to")
		# Still unpause the game even if we can't apply the powerup
		if is_instance_valid(powerup_selection_ui):
			powerup_selection_ui.show_ui(false)
		get_tree().paused = false
		return
	
	print("DEBUG: Applying powerup: ", powerup.name, " to player: ", player)
	# Check if powerup already exists
	var existing_powerup := active_powerups.filter(func(p): return p.name == powerup.name)
	if existing_powerup.size() > 0:
		if existing_powerup[0].can_stack():
			# Update the existing powerup's stack count and rarity if the new one is better
			existing_powerup[0].stack_count += 1
			if powerup.rarity > existing_powerup[0].rarity:
				existing_powerup[0].rarity = powerup.rarity
				print("DEBUG: Upgraded powerup rarity to: ", ["Common", "Rare", "Epic", "Legendary"][existing_powerup[0].rarity])
			# Reapply the powerup to update its effects
			existing_powerup[0].apply_powerup(player)
			print("DEBUG: Stacked existing powerup with rarity: ", ["Common", "Rare", "Epic", "Legendary"][existing_powerup[0].rarity])
	else:
		powerup.stack_count = 1
		active_powerups.append(powerup)
		powerup.apply_powerup(player)
		print("DEBUG: Applied new powerup with rarity: ", ["Common", "Rare", "Epic", "Legendary"][powerup.rarity])
	
	powerup_applied.emit(powerup)
	
	# Hide UI and unpause game
	if is_instance_valid(powerup_selection_ui):
		powerup_selection_ui.show_ui(false)
		print("DEBUG: Hiding powerup UI and unpausing game")
	get_tree().paused = false

func _get_available_powerups() -> Array[PowerupResource]:
	# This will be populated with powerup resources from the filesystem
	var powerups: Array[PowerupResource] = []
	print("DEBUG: Looking for powerups in res://resources/powerups")
	var dir = DirAccess.open("res://resources/powerups")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				print("DEBUG: Attempting to load powerup: ", file_name)
				var powerup_path = "res://resources/powerups/" + file_name
				var powerup = load(powerup_path)
				if powerup and powerup is PowerupResource:
					powerups.append(powerup)
					print("DEBUG: Successfully loaded powerup: ", powerup.name, " from ", powerup_path)
				else:
					print("ERROR: Failed to load powerup from ", powerup_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("ERROR: Could not open powerups directory!")
		# Try direct loading of known powerups
		var known_powerups = [
			"res://resources/powerups/damage_boost.tres",
			"res://resources/powerups/health_boost.tres",
			"res://resources/powerups/shield.tres",
			"res://resources/powerups/dash_strike.tres",
			"res://resources/powerups/fire_trail.tres"
		]
		for path in known_powerups:
			print("DEBUG: Attempting to load known powerup: ", path)
			var powerup = load(path)
			if powerup and powerup is PowerupResource:
				powerups.append(powerup)
				print("DEBUG: Successfully loaded known powerup: ", powerup.name)
			else:
				print("ERROR: Failed to load known powerup from ", path)
	
	print("DEBUG: Total powerups loaded: ", powerups.size())
	return powerups

func reset_powerups() -> void:
	print("DEBUG: Resetting powerups due to player death")
	if is_instance_valid(player):
		for powerup in active_powerups:
			if powerup.has_method("remove_powerup"):
				powerup.remove_powerup(player)
	active_powerups.clear()
	enemy_kill_count = 0 

# Called when player dies
func _on_player_died() -> void:
	reset_powerups()
