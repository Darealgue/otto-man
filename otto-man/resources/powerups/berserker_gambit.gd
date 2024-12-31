extends PowerupEffect

const DAMAGE_BOOST = 50.0  # +50 damage when triggered
const HEALTH_THRESHOLD = 0.3  # Trigger at 30% health
const BOOST_DURATION = 5.0  # Boost lasts 5 seconds

var is_active := false
var boost_timer := 0.0
var current_player: CharacterBody2D

func _init() -> void:
	powerup_name = "Berserker's Gambit"
	description = "When health drops below 30%, gain massive damage boost for 5 seconds"
	duration = -1  # Permanent upgrade
	powerup_type = PowerupType.DAMAGE

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	current_player = player  # Store player reference
	# Connect to health changed signal if player has it
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)

func deactivate(player: CharacterBody2D) -> void:
	# Only deactivate if player dies
	if !is_instance_valid(player):
		super.deactivate(player)
	current_player = null  # Clear player reference

func process(player: CharacterBody2D, delta: float) -> void:
	if is_active:
		boost_timer -= delta
		if boost_timer <= 0:
			is_active = false
			if player.has_method("modify_damage"):
				player.modify_damage(-DAMAGE_BOOST)  # Remove the boost

func _on_health_changed(new_health: int) -> void:
	if !is_instance_valid(current_player):
		return
		
	# Calculate health percentage - safely get max health or use default
	var max_health = 100  # Default value
	if "current_max_health" in current_player:
		max_health = current_player.current_max_health
	
	var health_percent = float(new_health) / float(max_health)
	
	# Check if we should activate the boost
	if health_percent <= HEALTH_THRESHOLD and !is_active:
		is_active = true
		boost_timer = BOOST_DURATION
		if current_player.has_method("modify_damage"):
			current_player.modify_damage(DAMAGE_BOOST)

# Synergize with damage and defense powerups
func conflicts_with(other: PowerupEffect) -> bool:
	return false  # Allow stacking with other powerups 
