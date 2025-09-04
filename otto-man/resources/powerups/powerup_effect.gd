extends Node
class_name PowerupEffect

enum PowerupType {
	DAMAGE,      # Affects damage output
	DEFENSE,     # Affects defense/health
	MOVEMENT,    # Affects movement abilities
	UTILITY,     # Misc effects
	PASSIVE      # Always active effects
}

var powerup_name: String = "Unnamed Powerup"
var description: String = "This powerup needs a description"
var duration: float = 10.0
var timer: float = 0.0
var powerup_type: PowerupType = PowerupType.UTILITY
var affected_stats: Array[String] = []
var tree_name: String = ""  # Add tree_name property

@onready var player_stats = get_node("/root/PlayerStats")

func _ready() -> void:
	pass

func activate(player: CharacterBody2D) -> void:
	timer = duration
	debug_print_activation(player)

func deactivate(player: CharacterBody2D) -> void:
	debug_print_deactivation(player)

func process(player: CharacterBody2D, delta: float) -> void:
	if timer > 0:
		timer -= delta
		if timer <= 0:
			PowerupManager.deactivate_powerup(self)
			
	debug_print_process(player, delta)

func conflicts_with(other: PowerupEffect) -> bool:
	# By default, powerups of the same type conflict
	return powerup_type == other.powerup_type

# Debug print functions
func debug_print_activation(player: CharacterBody2D) -> void:
	print("\n[DEBUG] Powerup Activated: ", powerup_name)
	print("- Description: ", description)
	print("- Duration: ", "Permanent" if duration < 0 else str(duration))
	print("- Affected Stats: ", affected_stats)
	debug_print_stats_before(player)

func debug_print_deactivation(player: CharacterBody2D) -> void:
	print("\n[DEBUG] Powerup Deactivated: ", powerup_name)
	debug_print_stats_before(player)

func debug_print_process(player: CharacterBody2D, delta: float) -> void:
	# Only print every second to avoid spam
	if int(timer) != int(timer - delta):
		print("[DEBUG] ", powerup_name, " - Time remaining: ", timer)
		debug_print_stats_current(player)

func debug_print_stats_before(player: CharacterBody2D) -> void:
	if !player or !player.has_method("get_stats"):
		return
		
	var stats = player.get_stats()
	print("Stats before effect:")
	for stat in affected_stats:
		print("- ", stat, ": ", stats.get(stat, 0))

func debug_print_stats_current(player: CharacterBody2D) -> void:
	if !player or !player.has_method("get_stats"):
		return
		
	var stats = player.get_stats()
	print("Current stats:")
	for stat in affected_stats:
		print("- ", stat, ": ", stats.get(stat, 0))

func on_enemy_killed(enemy: Node2D) -> void:
	pass

# Stat modification helpers
func affects_stat(stat_name: String) -> bool:
	return affected_stats.has(stat_name)

func get_stat_value(stat_name: String) -> float:
	if player_stats:
		return player_stats.get_stat(stat_name)
	return 0.0

func modify_stat(stat_name: String, amount: float, is_multiplier: bool = false) -> void:
	if !player_stats:
		return
		
	if !affected_stats.has(stat_name):
		affected_stats.append(stat_name)
		
	if is_multiplier:
		player_stats.add_stat_multiplier(stat_name, amount)
	else:
		player_stats.add_stat_bonus(stat_name, amount)
