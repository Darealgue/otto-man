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

@onready var player_stats = get_node("/root/PlayerStats")

func _ready() -> void:
	pass

func activate(player: CharacterBody2D) -> void:
	timer = duration

func deactivate(player: CharacterBody2D) -> void:
	pass

func process(player: CharacterBody2D, delta: float) -> void:
	if timer > 0:
		timer -= delta
		if timer <= 0:
			PowerupManager.deactivate_powerup(self)

func conflicts_with(other: PowerupEffect) -> bool:
	# By default, powerups of the same type conflict
	return powerup_type == other.powerup_type

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
