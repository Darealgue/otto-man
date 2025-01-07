# PowerupManager.gd
# Central manager for all powerups in the game.
#
# Powerup System Design:
# 1. Stacking Rules:
#    - Same type powerups can stack if they don't conflict
#    - Different type powerups always stack
#    - Powerups must explicitly declare conflicts
#
# 2. Powerup Types:
#    - DAMAGE: Affects damage output
#    - DEFENSE: Affects health/defense
#    - UTILITY: Affects movement/utility abilities
#    - SPECIAL: Special effects (time slow, etc)
#
# 3. Stat Management:
#    - All stat changes go through PlayerStats
#    - Powerups can only modify their declared stats
#    - Stats track base value, bonuses, and multipliers

extends Node

signal powerup_activated(powerup: PowerupEffect)
signal powerup_deactivated(powerup: PowerupEffect)

var player: CharacterBody2D
var active_powerups: Array[PowerupEffect] = []
var enemy_kill_count: int = 0
const KILLS_PER_POWERUP: int = 1

const PowerupSelection = preload("res://ui/powerup_selection.tscn")
const POWERUP_SCENES: Array[PackedScene] = [
	preload("res://resources/powerups/scenes/damage_boost.tscn"),
	preload("res://resources/powerups/scenes/health_boost.tscn"),
	preload("res://resources/powerups/scenes/speed_demon.tscn"),
	preload("res://resources/powerups/scenes/momentum_master.tscn"),
	preload("res://resources/powerups/scenes/perfect_guard.tscn"),
	preload("res://resources/powerups/scenes/berserker_gambit.tscn")
]

func _ready() -> void:
	var container = Node.new()
	container.name = "ActivePowerups"
	add_child(container)

func activate_powerup(powerup_scene: PackedScene) -> void:
	if !player:
		return
		
	var powerup = powerup_scene.instantiate() as PowerupEffect
	if !powerup:
		push_error("Failed to instantiate powerup")
		return
			
	
	# Initialize powerup
	_initialize_powerup(powerup)
			
	# Add to scene tree and activate
	$ActivePowerups.add_child(powerup)
	active_powerups.append(powerup)
	powerup.activate(player)
	powerup_activated.emit(powerup)
	debug_print_status()  # Print status after activation

# Debug function to print current powerup status
func debug_print_status() -> void:
	
		
			
	if player and player.has_method("get_stats"):
		var stats = player.get_stats()
		

func register_player(p: CharacterBody2D) -> void:
	player = p
	# Reactivate any existing powerups for the new player
	for powerup in active_powerups:
		_initialize_powerup(powerup)
		powerup.activate(player)

func _process(delta: float) -> void:
	if !player:
		return
		
	# Update all active powerups
	for powerup in active_powerups:
		powerup.process(player, delta)

# Initialize a powerup before activation
func _initialize_powerup(powerup: PowerupEffect) -> void:
	
	# Ensure powerup has access to singletons
	if !powerup.player_stats:
		powerup.player_stats = get_node("/root/PlayerStats")
	
	# Connect signals if needed
	if powerup.has_method("_on_perfect_parry") and player.has_signal("perfect_parry"):
		
		# Disconnect any existing connection first
		if player.is_connected("perfect_parry", powerup._on_perfect_parry):
			player.disconnect("perfect_parry", powerup._on_perfect_parry)
		
		# Connect with CONNECT_PERSIST flag
		var result = player.connect("perfect_parry", powerup._on_perfect_parry, CONNECT_PERSIST)
		
		# Verify connection
		if !player.is_connected("perfect_parry", powerup._on_perfect_parry):
			push_error("Failed to connect perfect_parry signal for " + powerup.powerup_name)

func deactivate_powerup(powerup: PowerupEffect) -> void:
	if !player or !powerup:
		return
		
	# Disconnect signals if needed
	if powerup.has_method("_on_perfect_parry") and player.has_signal("perfect_parry"):
		if player.is_connected("perfect_parry", powerup._on_perfect_parry):
			player.disconnect("perfect_parry", powerup._on_perfect_parry)
	
	powerup.deactivate(player)
	active_powerups.erase(powerup)
	powerup.queue_free()
	powerup_deactivated.emit(powerup)
	debug_print_status()  # Print status after deactivation

func get_active_powerups() -> Array[PowerupEffect]:
	return active_powerups

func clear_all_powerups() -> void:
	if !player:
		return
		
	for powerup in active_powerups.duplicate():
		deactivate_powerup(powerup)
	active_powerups.clear()

# Helper function to check if a powerup is active by its scene path
func has_powerup(powerup_scene_path: String) -> bool:
	for powerup in active_powerups:
		if powerup.scene_file_path == powerup_scene_path:
			return true
	return false

# Called when an enemy is killed
func on_enemy_killed() -> void:
	enemy_kill_count += 1
	
	# Check if we've reached the kill threshold for a powerup
	if enemy_kill_count % KILLS_PER_POWERUP == 0:
		# Minimal delay before showing powerup selection
		await get_tree().create_timer(0.2).timeout
		show_powerup_selection()

func show_powerup_selection() -> void:
	if !player:
		return
		
	var selection_ui = PowerupSelection.instantiate()
	get_tree().root.add_child(selection_ui)
	selection_ui.setup_powerups(POWERUP_SCENES)
	get_tree().paused = true
