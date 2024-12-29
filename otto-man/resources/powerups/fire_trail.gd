extends PowerupResource

func _init() -> void:
	name = "Fire Trail"
	description = "Leave a trail of fire when dashing that damages enemies"
	rarity = 2  # Epic
	weight = 0.3
	stackable = false
	max_stacks = 1

func _apply(player: CharacterBody2D) -> void:
	if player.has_method("enable_dash_damage"):
		player.enable_dash_damage(20.0)  # 20 damage per dash

func _remove(player: CharacterBody2D) -> void:
	if player.has_method("disable_dash_damage"):
		player.disable_dash_damage()

func get_modified_description() -> String:
	var rarity_name = ["Common", "Rare", "Epic", "Legendary"][rarity]
	var desc = description
	desc += "\n[" + rarity_name + "]"
	return desc 