extends Node

signal powerup_available
signal powerup_applied(powerup_name: String)
signal kill_count_changed(new_count: int)

const KILLS_FOR_POWERUP = 1

var available_powerups: Array[PowerupResource] = []
var active_powerups: Dictionary = {}  # id: PowerupResource
var kill_count: int = 0
var is_choosing_powerup: bool = false
var current_powerup_selection = null

# Called when the node enters the scene tree
func _ready() -> void:
	# Register all available powerups
	register_default_powerups()
	print("PowerupManager initialized with ", available_powerups.size(), " powerups")

func register_default_powerups() -> void:
	var powerup_scripts = [
		load("res://resources/powerups/damage_boost.gd"),
		load("res://resources/powerups/health_boost.gd"),
		load("res://resources/powerups/dash_strike.gd")
	]
	
	for script in powerup_scripts:
		if script:
			var powerup = script.new()
			available_powerups.append(powerup)
			print("Registered powerup: ", powerup.name)
		else:
			print("Failed to load powerup script!")

func add_kill() -> void:
	kill_count += 1
	kill_count_changed.emit(kill_count)
	print("Kill count increased to: ", kill_count)
	
	if kill_count >= KILLS_FOR_POWERUP:
		kill_count = 0
		print("Kill count reached ", KILLS_FOR_POWERUP, ", offering powerups...")
		offer_powerups()

func offer_powerups() -> void:
	if is_choosing_powerup:
		print("Already choosing powerup, skipping...")
		return
		
	print("Starting powerup selection...")
	is_choosing_powerup = true
	get_tree().paused = true
	
	# Clean up any existing powerup selection
	if current_powerup_selection:
		print("Removing existing powerup selection UI")
		current_powerup_selection.queue_free()
		current_powerup_selection = null
	
	# Find or create powerup selection UI
	var powerup_selection = get_tree().get_first_node_in_group("powerup_selection")
	if powerup_selection:
		print("Found powerup selection UI, emitting signal...")
		current_powerup_selection = powerup_selection
		powerup_available.emit()
	else:
		print("Creating new powerup selection UI...")
		var PowerupSelectionScene = load("res://ui/powerup_selection.tscn")
		if PowerupSelectionScene:
			powerup_selection = PowerupSelectionScene.instantiate()
			powerup_selection.add_to_group("powerup_selection")
			get_tree().root.add_child(powerup_selection)
			current_powerup_selection = powerup_selection
			powerup_available.emit()
		else:
			print("ERROR: Could not load powerup selection scene!")
			is_choosing_powerup = false
			get_tree().paused = false

func apply_powerup(powerup: PowerupResource, player: CharacterBody2D) -> void:
	print("Applying powerup: ", powerup.name)
	if powerup.id in active_powerups:
		if powerup.can_stack:
			active_powerups[powerup.id].stack_count += 1
			active_powerups[powerup.id].update_stack_effect(player)
			print("Increased stack count for: ", powerup.name)
	else:
		powerup.stack_count = 1
		active_powerups[powerup.id] = powerup
		powerup.apply_effect(player)
		print("Applied new powerup: ", powerup.name)
	
	powerup_applied.emit(powerup.name)
	is_choosing_powerup = false
	get_tree().paused = false
	
	# Clean up UI after applying powerup
	if current_powerup_selection:
		current_powerup_selection.queue_free()
		current_powerup_selection = null

func get_random_powerups(count: int = 3) -> Array[PowerupResource]:
	print("Getting ", count, " random powerups from ", available_powerups.size(), " available")
	var shuffled = available_powerups.duplicate()
	shuffled.shuffle()
	return shuffled.slice(0, count)

func reset_powerups(player: CharacterBody2D) -> void:
	print("Resetting all powerups")
	for powerup in active_powerups.values():
		powerup.remove_effect(player)
	
	active_powerups.clear()
	kill_count = 0
	is_choosing_powerup = false
	
	# Clean up any existing UI
	if current_powerup_selection:
		current_powerup_selection.queue_free()
		current_powerup_selection = null 