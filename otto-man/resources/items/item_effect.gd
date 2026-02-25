# item_effect.gd
# Base class for all items in the game.

extends Node
class_name ItemEffect

enum ItemRarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY
}

enum ItemCategory {
	STAMINA,
	BLOCK,
	PARRY,
	LIGHT_ATTACK,
	HEAVY_ATTACK,
	FALL_ATTACK,
	WALL_SLIDE,
	SLIDE,
	CROUCH,
	JUMP,
	DODGE,
	SPECIAL,
	SYNERGY
}

var item_id: String = ""
var item_name: String = "Unnamed Item"
var description: String = "This item needs a description"
var flavor_text: String = ""
var rarity: ItemRarity = ItemRarity.COMMON
var category: ItemCategory = ItemCategory.SPECIAL
var affected_stats: Array[String] = []

@onready var player_stats = get_node("/root/PlayerStats")

func _ready() -> void:
	pass

func activate(player: CharacterBody2D) -> void:
	pass

func deactivate(player: CharacterBody2D) -> void:
	pass

func process(player: CharacterBody2D, delta: float) -> void:
	pass

func on_enemy_killed(enemy: Node2D) -> void:
	pass

# Signal handlers (override if needed)
func _on_player_dodged(direction: int, start_pos: Vector2, end_pos: Vector2) -> void:
	pass

func _on_player_slid(distance: float, duration: float) -> void:
	pass

func _on_player_blocked(blocked_damage: float, attacker: Node2D) -> void:
	pass

func _on_player_attack_landed(attack_type: String, damage: float, targets: Array, position: Vector2, effect_filter: String = "all") -> void:
	pass

func _on_player_light_attack_performed(direction: Vector2, position: Vector2, damage: float) -> void:
	pass

func _on_perfect_parry() -> void:
	pass

## Fall attack yere değdiğinde efekt uygula. is_decoy true ise gölge konumunda (cooldown uygulanmaz).
## Fall-attack itemleri bu metodu override eder; ItemManager decoy_fall_attack_impacted'da otomatik çağırır.
func apply_fall_attack_effect_at(_position: Vector2, _is_decoy: bool) -> void:
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
