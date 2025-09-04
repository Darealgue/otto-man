extends PowerupEffect

const FALL_ATTACK_DAMAGE_BONUS = 0.5  # 50% damage increase
const SYNERGY_FALL_ATTACK_DAMAGE_BONUS = 1.0  # 100% damage increase

var synergy_active := false
var current_multiplier := 1.0

func _init() -> void:
	powerup_name = "Aerial Assassin"
	description = "Fall attack damage +50%"
	duration = -1  # Permanent until death
	powerup_type = PowerupType.DAMAGE
	affected_stats = ["fall_attack_damage"]
	tree_name = "mobility"  # Mobility tree, Tier 1

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	
	# Connect to synergy signals
	var powerup_manager = get_node("/root/PowerupManager")
	if powerup_manager:
		if !powerup_manager.is_connected("synergy_activated", _on_synergy_activated):
			powerup_manager.connect("synergy_activated", _on_synergy_activated)
	
	_apply_aerial_assassin_effects()

func _apply_aerial_assassin_effects() -> void:
	var damage_bonus = SYNERGY_FALL_ATTACK_DAMAGE_BONUS if synergy_active else FALL_ATTACK_DAMAGE_BONUS
	
	# Remove current multiplier first
	if current_multiplier != 1.0:
		player_stats.add_stat_multiplier("fall_attack_damage", 1.0 / current_multiplier)
	
	# Apply new multiplier
	current_multiplier = 1.0 + damage_bonus
	player_stats.add_stat_multiplier("fall_attack_damage", current_multiplier)
	
	var synergy_text = " (Aerial Warrior synergy)" if synergy_active else ""
	print("[Aerial Assassin] Activated - Fall attack damage +" + str(int(damage_bonus * 100)) + "%" + synergy_text)

func _on_synergy_activated(synergy_id: String) -> void:
	if synergy_id == "aerial_warrior":
		_check_aerial_warrior_synergy()

func _check_aerial_warrior_synergy() -> void:
	var powerup_manager = get_node("/root/PowerupManager")
	if !powerup_manager:
		return
	
	var active_synergies = powerup_manager.get_active_synergies()
	var new_synergy_active = "aerial_warrior" in active_synergies
	
	if new_synergy_active != synergy_active:
		synergy_active = new_synergy_active
		_apply_aerial_assassin_effects()

func deactivate(player: CharacterBody2D) -> void:
	# Remove fall attack damage multiplier
	if current_multiplier != 1.0:
		player_stats.add_stat_multiplier("fall_attack_damage", 1.0 / current_multiplier)
	
	# Disconnect synergy signals
	var powerup_manager = get_node("/root/PowerupManager")
	if powerup_manager and powerup_manager.is_connected("synergy_activated", _on_synergy_activated):
		powerup_manager.disconnect("synergy_activated", _on_synergy_activated)
	
	print("[Aerial Assassin] Deactivated")
	super.deactivate(player)
