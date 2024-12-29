extends PowerupResource

const FIRE_DAMAGE = {
	"Common": 5,      # 5 damage per second
	"Rare": 10,      # 10 damage per second
	"Epic": 15,      # 15 damage per second
	"Legendary": 20   # 20 damage per second
}

const TRAIL_DURATION = 2.0  # How long each fire patch lasts
const TRAIL_SPAWN_INTERVAL = 0.02  # How often to spawn fire patches (decreased from 0.05)

func _init() -> void:
	name = "Fire Trail"
	description = "Leave a trail of fire when dashing that damages enemies"
	rarity = 0  # Start at Common
	weight = 0.3
	stackable = false
	max_stacks = 1
	powerup_type = PowerupType.FIRE_TRAIL

func apply_powerup(player: CharacterBody2D) -> void:
	if player.has_method("enable_fire_trail"):
		var rarity_name = get_rarity_name()
		var damage = FIRE_DAMAGE[rarity_name]
		print("[DEBUG] Fire Trail: Applying with damage ", damage, " per second for rarity ", rarity_name)
		player.enable_fire_trail(damage, TRAIL_DURATION, TRAIL_SPAWN_INTERVAL)

func remove_powerup(player: CharacterBody2D) -> void:
	if player.has_method("disable_fire_trail"):
		print("[DEBUG] Fire Trail: Removing")
		player.disable_fire_trail()

func get_rarity_name() -> String:
	return ["Common", "Rare", "Epic", "Legendary"][rarity]

func get_modified_description() -> String:
	var rarity_name = get_rarity_name()
	var damage = FIRE_DAMAGE[rarity_name]
	
	var desc = "Leave a trail of fire when dashing"
	desc += "\nDeals " + str(damage) + " damage per second"
	desc += "\nTrail lasts " + str(TRAIL_DURATION) + " seconds"
	desc += "\n[" + rarity_name + "]"
	return desc 