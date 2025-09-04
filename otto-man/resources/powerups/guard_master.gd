extends PowerupEffect

const BLOCK_CHARGES_BONUS = 1
const PARRY_WINDOW_BONUS = 0.2  # 20% wider parry window
const SYNERGY_BLOCK_CHARGES_BONUS = 3
const SYNERGY_PARRY_WINDOW_BONUS = 0.5  # 50% wider parry window

var synergy_active := false
var current_player: CharacterBody2D

func _init() -> void:
	powerup_name = "Guard Master"
	description = "Block charges +1, parry window 20% wider"
	duration = -1  # Permanent until death
	powerup_type = PowerupType.DEFENSE
	affected_stats = ["block_charges"]
	tree_name = "defense"  # Defense tree, Tier 1

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	
	current_player = player
	
	# Connect to synergy signals
	var powerup_manager = get_node("/root/PowerupManager")
	if powerup_manager:
		if !powerup_manager.is_connected("synergy_activated", _on_synergy_activated):
			powerup_manager.connect("synergy_activated", _on_synergy_activated)
	
	_apply_guard_master_effects()

func _apply_guard_master_effects() -> void:
	var block_bonus = SYNERGY_BLOCK_CHARGES_BONUS if synergy_active else BLOCK_CHARGES_BONUS
	var parry_bonus = SYNERGY_PARRY_WINDOW_BONUS if synergy_active else PARRY_WINDOW_BONUS
	
	# Add block charges
	player_stats.add_stat_bonus("block_charges", block_bonus)
	
	# Extend parry window if player has parry system
	if current_player and current_player.has_method("extend_parry_window"):
		current_player.extend_parry_window(parry_bonus)
	
	var synergy_text = " (Shield Master synergy)" if synergy_active else ""
	print("[Guard Master] Activated - +" + str(block_bonus) + " block charges, +" + str(int(parry_bonus * 100)) + "% parry window" + synergy_text)

func _on_synergy_activated(synergy_id: String) -> void:
	if synergy_id == "shield_master":
		_check_shield_master_synergy()

func _check_shield_master_synergy() -> void:
	var powerup_manager = get_node("/root/PowerupManager")
	if !powerup_manager:
		return
	
	var active_synergies = powerup_manager.get_active_synergies()
	var new_synergy_active = "shield_master" in active_synergies
	
	if new_synergy_active != synergy_active:
		synergy_active = new_synergy_active
		_apply_guard_master_effects()

func deactivate(player: CharacterBody2D) -> void:
	# Remove block charges
	var block_bonus = SYNERGY_BLOCK_CHARGES_BONUS if synergy_active else BLOCK_CHARGES_BONUS
	player_stats.add_stat_bonus("block_charges", -block_bonus)
	
	# Restore parry window if player has parry system
	var parry_bonus = SYNERGY_PARRY_WINDOW_BONUS if synergy_active else PARRY_WINDOW_BONUS
	if player.has_method("restore_parry_window"):
		player.restore_parry_window(parry_bonus)
	
	# Disconnect synergy signals
	var powerup_manager = get_node("/root/PowerupManager")
	if powerup_manager and powerup_manager.is_connected("synergy_activated", _on_synergy_activated):
		powerup_manager.disconnect("synergy_activated", _on_synergy_activated)
	
	current_player = null
	print("[Guard Master] Deactivated")
	super.deactivate(player)
