extends Node

signal enemy_killed
signal powerup_applied(powerup: PowerupResource)

const KILLS_FOR_POWERUP := 1

var powerups: Array[PowerupResource] = []
var active_powerups: Array[PowerupResource] = []
var player: CharacterBody2D = null
var enemy_kill_count := 0
var powerup_selection_ui: CanvasLayer = null

func _ready() -> void:
	print("DEBUG: PowerupManager ready")
	load_powerups()
	enemy_killed.connect(_on_enemy_killed)

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
	
	# Show UI and let it handle the time slow effect
	if is_instance_valid(powerup_selection_ui) and powerup_selection_ui.has_method("setup_powerups"):
		print("DEBUG: Setting up powerups in UI")
		powerup_selection_ui.setup_powerups(powerups)
	else:
		print("ERROR: PowerupSelection UI is not valid or missing setup_powerups method!")

func load_powerups() -> void:
	print("DEBUG: Looking for powerups in res://resources/powerups")
	var dir = DirAccess.open("res://resources/powerups")
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				print("DEBUG: Attempting to load powerup: ", file)
				var powerup = load("res://resources/powerups/" + file)
				if powerup is PowerupResource:
					powerups.append(powerup)
					print("DEBUG: Successfully loaded powerup: ", powerup.name, " from ", "res://resources/powerups/" + file)
	
	print("DEBUG: Total powerups loaded: ", powerups.size())

func get_random_powerups(count: int = 3) -> Array[PowerupResource]:
	print("DEBUG: Getting random powerups from ", powerups.size(), " available powerups")
	var available_powerups: Array[PowerupResource] = []
	var current_powerup_types: Array[PowerupResource.PowerupType] = []
	
	# Get current powerup types
	for powerup in active_powerups:
		current_powerup_types.append(powerup.powerup_type)
	
	# Filter available powerups based on requirements and synergies
	for powerup in powerups:
		# Check if powerup can be stacked
		var existing = active_powerups.filter(func(p): return p.powerup_type == powerup.powerup_type)
		if !existing.is_empty() and !existing[0].can_stack():
			continue
			
		if powerup.is_available(current_powerup_types) and powerup.creates_valid_synergy(current_powerup_types):
			available_powerups.append(powerup)
	
	# If we don't have enough available powerups with synergies, add base powerups
	if available_powerups.size() < count:
		for powerup in powerups:
			if powerup.synergy_level == 0 and not powerup in available_powerups:
				available_powerups.append(powerup)
	
	var selected_powerups: Array[PowerupResource] = []
	while selected_powerups.size() < count and available_powerups:
		var index = randi() % available_powerups.size()
		var powerup = available_powerups[index].duplicate()  # Create a copy
		
		# Set rarity based on chances
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
		
		selected_powerups.append(powerup)
		print("DEBUG: Selected powerup: ", powerup.name, " (", powerup.get_modified_description(), ")")
		available_powerups.remove_at(index)
	
	return selected_powerups

func register_player(p: CharacterBody2D) -> void:
	print("DEBUG: Registered player: ", p)
	player = p
	player.tree_exiting.connect(_on_player_tree_exiting)
	# Connect to player death signal
	if player.has_signal("died"):
		player.died.connect(_on_player_died)
		print("DEBUG: Connected to player death signal")

func _on_player_tree_exiting() -> void:
	player = null
	active_powerups.clear()

func _on_player_died() -> void:
	reset_powerups()

func reset_powerups() -> void:
	print("DEBUG: Resetting powerups due to player death")
	if is_instance_valid(player):
		for powerup in active_powerups:
			if powerup.has_method("remove_powerup"):
				powerup.remove_powerup(player)
	active_powerups.clear()
	enemy_kill_count = 0

func apply_powerup(powerup: PowerupResource) -> void:
	if !player:
		return
	
	print("DEBUG: Applying powerup: ", powerup.name, " (Type: ", PowerupResource.PowerupType.keys()[powerup.powerup_type], ") to player: ", player)
	
	# Check if powerup already exists
	var existing = active_powerups.filter(func(p): return p.powerup_type == powerup.powerup_type)
	if !existing.is_empty():
		var existing_powerup = existing[0]
		if existing_powerup.can_stack():
			# Update stack count and rarity if new one is better
			existing_powerup.stack_count += 1
			if powerup.rarity > existing_powerup.rarity:
				existing_powerup.rarity = powerup.rarity
			# Reapply to update effects
			existing_powerup.apply_powerup(player)
			print("DEBUG: Stacked existing powerup. New stack count: ", existing_powerup.stack_count)
		return
	
	# New powerup
	powerup.stack_count = 1
	powerup.apply_powerup(player)
	active_powerups.append(powerup)
	powerup_applied.emit(powerup)
	print("DEBUG: Applied new powerup with rarity: ", ["Common", "Rare", "Epic", "Legendary"][powerup.rarity])
