extends PowerupEffect

const FALL_ATTACK_COUNT_FOR_AREA = 3
const AREA_DAMAGE_MULTIPLIER = 2.0  # 2x damage for area attack
const SYNERGY_AREA_DAMAGE_MULTIPLIER = 4.0  # 4x damage for area attack with synergy

var fall_attack_count := 0
var current_player: CharacterBody2D
var synergy_active := false

func _init() -> void:
	powerup_name = "Triple Strike"
	description = "3 fall attacks in air = 3rd deals area damage"
	duration = -1  # Permanent until death
	powerup_type = PowerupType.DAMAGE
	affected_stats = ["fall_attack_damage"]
	tree_name = "mobility"  # Mobility tree, Tier 2

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	
	current_player = player
	fall_attack_count = 0
	
	# Connect to synergy signals
	var powerup_manager = get_node("/root/PowerupManager")
	if powerup_manager:
		if !powerup_manager.is_connected("synergy_activated", _on_synergy_activated):
			powerup_manager.connect("synergy_activated", _on_synergy_activated)
	
	# Connect to fall attack signals
	if player.has_signal("fall_attack_performed"):
		if !player.is_connected("fall_attack_performed", _on_fall_attack_performed):
			player.connect("fall_attack_performed", _on_fall_attack_performed)
	
	print("[Triple Strike] Activated - 3 fall attacks for area damage")

func _on_fall_attack_performed() -> void:
	if !current_player or !is_instance_valid(current_player):
		return
	
	fall_attack_count += 1
	
	if fall_attack_count >= FALL_ATTACK_COUNT_FOR_AREA:
		_perform_area_attack()
		fall_attack_count = 0  # Reset counter

func _perform_area_attack() -> void:
	if !current_player or !is_instance_valid(current_player):
		return
	
	# Find all enemies in area around player
	var enemies = get_tree().get_nodes_in_group("enemies")
	var area_radius = 150.0  # Area damage radius
	var damage_multiplier = SYNERGY_AREA_DAMAGE_MULTIPLIER if synergy_active else AREA_DAMAGE_MULTIPLIER
	
	for enemy in enemies:
		if !enemy or !is_instance_valid(enemy):
			continue
		
		var distance = current_player.global_position.distance_to(enemy.global_position)
		if distance <= area_radius:
			# Deal area damage to enemy
			if enemy.has_method("take_damage"):
				var base_damage = player_stats.get_stat("base_damage")
				var area_damage = base_damage * damage_multiplier
				enemy.take_damage(area_damage)
				var synergy_text = " (Aerial Warrior synergy)" if synergy_active else ""
				print("[Triple Strike] Area damage dealt: " + str(area_damage) + synergy_text)
	
	var synergy_text = " (Aerial Warrior synergy)" if synergy_active else ""
	print("[Triple Strike] Area attack performed!" + synergy_text)

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
		print("[Triple Strike] Aerial Warrior synergy " + ("activated" if synergy_active else "deactivated"))

func deactivate(player: CharacterBody2D) -> void:
	if is_instance_valid(player):
		if player.has_signal("fall_attack_performed"):
			if player.is_connected("fall_attack_performed", _on_fall_attack_performed):
				player.disconnect("fall_attack_performed", _on_fall_attack_performed)
	
	# Disconnect synergy signals
	var powerup_manager = get_node("/root/PowerupManager")
	if powerup_manager and powerup_manager.is_connected("synergy_activated", _on_synergy_activated):
		powerup_manager.disconnect("synergy_activated", _on_synergy_activated)
	
	current_player = null
	fall_attack_count = 0
	
	print("[Triple Strike] Deactivated")
	super.deactivate(player)
