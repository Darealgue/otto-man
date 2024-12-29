extends Node

# Base damage values
const BASE_ATTACK_DAMAGE := 10
const BASE_DASH_DAMAGE := 0  # Dash starts at 0 and is modified by powerups

# Get functions to ensure consistent access
static func get_base_attack_damage() -> int:
	return BASE_ATTACK_DAMAGE

static func get_base_dash_damage() -> int:
	return BASE_DASH_DAMAGE 