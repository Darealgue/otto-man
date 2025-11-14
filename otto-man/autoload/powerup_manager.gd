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
#
# 4. Tree System:
#    - Powerups are organized into trees (Combat, Defense, Mobility)
#    - Each tree has tiers (Base, Tier 1, Tier 2, Tier 3)
#    - Synergies between powerups create special effects

extends Node

signal powerup_activated(powerup: PowerupEffect)
signal powerup_deactivated(powerup: PowerupEffect)
signal tree_progress_updated(tree_name: String, new_progress: int)
signal synergy_activated(synergy_name: String)

var player: CharacterBody2D
var active_powerups: Array[PowerupEffect] = []
var enemy_kill_count: int = 0
const KILLS_PER_POWERUP: int = 10

# Tree System Variables
var tree_progress: Dictionary = {
	"combat": 0,
	"defense": 0,
	"mobility": 0
}

var unlocked_trees: Array[String] = []
var active_synergies: Array[String] = []

# Tree Definitions
const TREE_DEFINITIONS = {
	"combat": {
		"name": "Combat",
		"color": Color.RED,
		"description": "Increase your damage and combat effectiveness"
	},
	"defense": {
		"name": "Defense", 
		"color": Color.BLUE,
		"description": "Improve your survivability and health"
	},
	"mobility": {
		"name": "Mobility",
		"color": Color.GREEN, 
		"description": "Enhance your movement and agility"
	}
}

# Synergy Definitions
const SYNERGY_DEFINITIONS = {
	"vampire_lord": {
		"name": "Vampire Lord",
		"description": "Bloodthirsty + Regeneration: Killing enemies restores 25% health",
		"required_powerups": ["bloodthirsty", "regeneration"],
		"effect": "healing_boost"
	},
	"time_master": {
		"name": "Time Master", 
		"description": "Time Walker + Critical Strike: 100% crit chance during time slow",
		"required_powerups": ["time_walker", "critical_strike"],
		"effect": "time_crit"
	},
	"berserker_king": {
		"name": "Berserker King",
		"description": "Berserker Gambit + Iron Will: Low health grants massive damage boost",
		"required_powerups": ["berserker_gambit", "iron_will"],
		"effect": "berserker_boost"
	},
	"shield_master": {
		"name": "Shield Master",
		"description": "Guard Master + Endurance: Block charges +3, parry window 50% wider",
		"required_powerups": ["guard_master", "endurance"],
		"effect": "shield_boost"
	},
	"aerial_warrior": {
		"name": "Aerial Warrior",
		"description": "Aerial Assassin + Triple Strike: Fall attack damage +100%, area damage +300%",
		"required_powerups": ["aerial_assassin", "triple_strike"],
		"effect": "aerial_boost"
	}
}

const PowerupSelection = preload("res://ui/powerup_selection.tscn")
const POWERUP_SCENES: Array[PackedScene] = [
	preload("res://resources/powerups/scenes/damage_boost.tscn"),
	preload("res://resources/powerups/scenes/health_boost.tscn"),
	preload("res://resources/powerups/scenes/speed_demon.tscn"),
	preload("res://resources/powerups/scenes/momentum_master.tscn"),
	preload("res://resources/powerups/scenes/perfect_guard.tscn"),
	preload("res://resources/powerups/scenes/berserker_gambit.tscn"),
	# New tree powerups
	preload("res://resources/powerups/scenes/critical_strike.tscn"),
	preload("res://resources/powerups/scenes/regeneration.tscn"),
	preload("res://resources/powerups/scenes/double_dash.tscn"),
	preload("res://resources/powerups/scenes/bloodthirsty.tscn"),
	# New block/fall attack powerups
	preload("res://resources/powerups/scenes/guard_master.tscn"),
	preload("res://resources/powerups/scenes/aerial_assassin.tscn"),
	preload("res://resources/powerups/scenes/endurance.tscn"),
	preload("res://resources/powerups/scenes/triple_strike.tscn")
]

# New Tree Powerup Scenes (will be created)
const TREE_POWERUP_SCENES: Dictionary = {
	"combat": [
		preload("res://resources/powerups/scenes/damage_boost.tscn"), # Base
		preload("res://resources/powerups/scenes/critical_strike.tscn"), # Tier 1
		preload("res://resources/powerups/scenes/bloodthirsty.tscn"), # Tier 2
	],
	"defense": [
		preload("res://resources/powerups/scenes/health_boost.tscn"), # Base
		preload("res://resources/powerups/scenes/regeneration.tscn"), # Tier 1
		preload("res://resources/powerups/scenes/guard_master.tscn"), # Tier 1
		preload("res://resources/powerups/scenes/endurance.tscn"), # Tier 1
	],
	"mobility": [
		preload("res://resources/powerups/scenes/speed_demon.tscn"), # Base
		preload("res://resources/powerups/scenes/double_dash.tscn"), # Tier 1
		preload("res://resources/powerups/scenes/aerial_assassin.tscn"), # Tier 1
		preload("res://resources/powerups/scenes/triple_strike.tscn"), # Tier 2
	]
}

# Tier requirements for powerups
const POWERUP_TIERS: Dictionary = {
	"damage_upgrade": 0,      # Base tier
	"health_upgrade": 0,      # Base tier
	"speed_demon": 0,         # Base tier
	"critical_strike": 1,     # Tier 1 - requires 1 combat powerup
	"regeneration": 1,        # Tier 1 - requires 1 defense powerup
	"double_dash": 1,         # Tier 1 - requires 1 mobility powerup
	"bloodthirsty": 2,        # Tier 2 - requires 2 combat powerups
	"perfect_guard": 0,       # Base tier
	"momentum_master": 0,     # Base tier
	"berserker_gambit": 0,    # Base tier
	# New block/fall attack powerups
	"guard_master": 1,        # Tier 1 - requires 1 defense powerup
	"aerial_assassin": 1,     # Tier 1 - requires 1 mobility powerup
	"endurance": 1,           # Tier 1 - requires 1 defense powerup
	"triple_strike": 2        # Tier 2 - requires 2 mobility powerups
}

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
	
	# Update tree progress
	_update_tree_progress(powerup)
	
	# Check for synergies
	_check_synergies()
	
	# debug_print_status()  # Print status after activation

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
	
	# Recheck synergies after powerup removal
	_check_synergies()
	
	# debug_print_status()  # Print status after deactivation

func get_active_powerups() -> Array[PowerupEffect]:
	return active_powerups

func clear_all_powerups() -> void:
	if !player:
		return
		
	for powerup in active_powerups.duplicate():
		deactivate_powerup(powerup)
	active_powerups.clear()
	
	# Clear tree progress and synergies
	tree_progress = {"combat": 0, "defense": 0, "mobility": 0}
	unlocked_trees.clear()
	active_synergies.clear()

# Helper function to check if a powerup is active by its scene path
func has_powerup(powerup_scene_path: String) -> bool:
	for powerup in active_powerups:
		if powerup.scene_file_path == powerup_scene_path:
			return true
	return false

# Helper function to check if a powerup is active by its name
func has_powerup_by_name(powerup_name: String) -> bool:
	for powerup in active_powerups:
		if powerup.powerup_name == powerup_name:
			return true
	return false

# Called when an enemy is killed
func on_enemy_killed(enemy: Node2D = null) -> void:
	enemy_kill_count += 1
	
	# Notify Bloodthirsty powerups
	for powerup in active_powerups:
		if powerup.has_method("on_enemy_killed"):
			powerup.on_enemy_killed(enemy)
	
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
	
	# Get tier-appropriate powerups
	var available_powerups = get_tier_appropriate_powerups()
	selection_ui.setup_powerups(available_powerups)
	get_tree().paused = true

# Get powerups appropriate for current tier progress
func get_tier_appropriate_powerups() -> Array[PackedScene]:
	var available_powerups: Array[PackedScene] = []
	
	# Get current tree progress
	var combat_progress = get_tree_progress("combat")
	var defense_progress = get_tree_progress("defense")
	var mobility_progress = get_tree_progress("mobility")
	
	# Add all powerups that meet tier requirements
	for powerup_scene in POWERUP_SCENES:
		var powerup = powerup_scene.instantiate() as PowerupEffect
		if !powerup:
			continue
		
		var powerup_name = powerup.powerup_name.to_lower().replace(" ", "_")
		var required_tier = POWERUP_TIERS.get(powerup_name, 0)
		var tree_name = powerup.tree_name
		
		# Check if player meets tier requirements
		var can_select = false
		match tree_name:
			"combat":
				can_select = combat_progress >= required_tier
			"defense":
				can_select = defense_progress >= required_tier
			"mobility":
				can_select = mobility_progress >= required_tier
			_:
				can_select = true  # Default powerups always available
		
		if can_select:
			available_powerups.append(powerup_scene)
		
		powerup.queue_free()
	
	# If no tier-appropriate powerups, fall back to base powerups
	if available_powerups.is_empty():
		for powerup_scene in POWERUP_SCENES:
			var powerup = powerup_scene.instantiate() as PowerupEffect
			if !powerup:
				continue
			
			var powerup_name = powerup.powerup_name.to_lower().replace(" ", "_")
			var required_tier = POWERUP_TIERS.get(powerup_name, 0)
			
			if required_tier == 0:  # Base tier only
				available_powerups.append(powerup_scene)
			
			powerup.queue_free()
	
	return available_powerups

# Tree System Functions
func _update_tree_progress(powerup: PowerupEffect) -> void:
	var tree_name = powerup.tree_name
	if tree_name != "" and tree_name in tree_progress:
		tree_progress[tree_name] += 1
		tree_progress_updated.emit(tree_name, tree_progress[tree_name])
		
		# Unlock tree if it's the first powerup
		if tree_progress[tree_name] == 1:
			unlocked_trees.append(tree_name)

func get_tree_progress(tree_name: String) -> int:
	return tree_progress.get(tree_name, 0)

func get_unlocked_trees() -> Array[String]:
	return unlocked_trees

func get_available_powerups_for_tree(tree_name: String) -> Array[PackedScene]:
	if tree_name not in TREE_POWERUP_SCENES:
		return []
	
	var progress = get_tree_progress(tree_name)
	var available_scenes: Array[PackedScene] = []
	
	# Add base powerups (always available)
	available_scenes.append_array(TREE_POWERUP_SCENES[tree_name])
	
	# Add tier powerups based on progress
	# This will be expanded as we add more powerups
	if progress >= 1: # Tier 1 unlocked
		# Add tier 1 powerups here
		pass
	
	return available_scenes

# Synergy System Functions
func _check_synergies() -> void:
	var current_powerup_names: Array[String] = []
	for powerup in active_powerups:
		current_powerup_names.append(powerup.powerup_name)
	
	# Check each synergy
	for synergy_id in SYNERGY_DEFINITIONS:
		var synergy = SYNERGY_DEFINITIONS[synergy_id]
		var required_powerups = synergy.required_powerups
		
		# Check if all required powerups are active
		var has_all_required = true
		for required_powerup in required_powerups:
			if not has_powerup_by_name(required_powerup):
				has_all_required = false
				break
		
		# Activate or deactivate synergy
		if has_all_required and not synergy_id in active_synergies:
			_activate_synergy(synergy_id)
		elif not has_all_required and synergy_id in active_synergies:
			_deactivate_synergy(synergy_id)

func _activate_synergy(synergy_id: String) -> void:
	if synergy_id in active_synergies:
		return
		
	active_synergies.append(synergy_id)
	synergy_activated.emit(synergy_id)
	
	# Apply synergy effect
	var synergy = SYNERGY_DEFINITIONS[synergy_id]
	match synergy.effect:
		"healing_boost":
			_apply_healing_boost_synergy()
		"time_crit":
			_apply_time_crit_synergy()
		"berserker_boost":
			_apply_berserker_boost_synergy()
		"shield_boost":
			_apply_shield_boost_synergy()
		"aerial_boost":
			_apply_aerial_boost_synergy()
	
	#print("[SYNERGY] Activated: " + synergy.name + " - " + synergy.description)

func _deactivate_synergy(synergy_id: String) -> void:
	if not synergy_id in active_synergies:
		return
		
	active_synergies.erase(synergy_id)
	
	# Remove synergy effect
	var synergy = SYNERGY_DEFINITIONS[synergy_id]
	match synergy.effect:
		"healing_boost":
			_remove_healing_boost_synergy()
		"time_crit":
			_remove_time_crit_synergy()
		"berserker_boost":
			_remove_berserker_boost_synergy()
		"shield_boost":
			_remove_shield_boost_synergy()
		"aerial_boost":
			_remove_aerial_boost_synergy()
	
	#print("[SYNERGY] Deactivated: " + synergy.name)

# Synergy Effect Implementations
func _apply_healing_boost_synergy() -> void:
	# Vampire Lord: Increase healing from kills
	# This will be implemented in the bloodthirsty powerup
	pass

func _remove_healing_boost_synergy() -> void:
	# Remove Vampire Lord effect
	pass

func _apply_time_crit_synergy() -> void:
	# Time Master: 100% crit chance during time slow
	# This will be implemented in the critical_strike powerup
	pass

func _remove_time_crit_synergy() -> void:
	# Remove Time Master effect
	pass

func _apply_berserker_boost_synergy() -> void:
	# Berserker King: Enhanced low health damage boost
	# This will be implemented in the berserker_gambit powerup
	pass

func _remove_berserker_boost_synergy() -> void:
	# Remove Berserker King effect
	pass

func _apply_shield_boost_synergy() -> void:
	# Shield Master: Block charges +3, parry window 50% wider
	# This will be implemented in the guard_master powerup
	pass

func _remove_shield_boost_synergy() -> void:
	# Remove Shield Master effect
	pass

func _apply_aerial_boost_synergy() -> void:
	# Aerial Warrior: Fall attack damage +100%, area damage +300%
	# This will be implemented in the aerial_assassin powerup
	pass

func _remove_aerial_boost_synergy() -> void:
	# Remove Aerial Warrior effect
	pass

func get_active_synergies() -> Array[String]:
	return active_synergies

func get_synergy_info(synergy_id: String) -> Dictionary:
	return SYNERGY_DEFINITIONS.get(synergy_id, {})
