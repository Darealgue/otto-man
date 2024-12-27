extends PowerupResource

const DAMAGE_INCREASE_PER_STACK = 0.2  # 20% per stack

func _init() -> void:
	id = "damage_boost"
	name = "Damage Boost"
	description = "Increases damage dealt by 20%"
	can_stack = true

func apply_effect(player: CharacterBody2D) -> void:
	update_stack_effect(player)

func update_stack_effect(player: CharacterBody2D) -> void:
	# Get player's hitbox
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox:
		var base_damage = 10  # Default damage
		var damage_multiplier = 1 + (DAMAGE_INCREASE_PER_STACK * stack_count)
		hitbox.damage = int(base_damage * damage_multiplier)

func remove_effect(player: CharacterBody2D) -> void:
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox:
		hitbox.damage = 10  # Reset to base damage 