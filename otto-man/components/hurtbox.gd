extends Area2D

signal hurt(hitbox: Area2D)

var is_player := false
var last_damage := 0.0
var last_hitbox = null
var debug_enabled := true  # Enable debug for tracking
var hit_cooldown := 0.05  # Reduced cooldown for better hit detection
var slam_hit_cooldown := 0.5  # Longer cooldown for slam attacks
var recent_hits := {}  # Dictionary to track recent hits and their cooldowns

func _ready():
	area_entered.connect(_on_area_entered)

func _process(delta: float):
	# Update cooldowns and remove expired entries
	var expired_hits := []
	for hitbox in recent_hits:
		recent_hits[hitbox] -= delta
		if recent_hits[hitbox] <= 0:
			expired_hits.append(hitbox)
	
	for hitbox in expired_hits:
		recent_hits.erase(hitbox)

func _on_area_entered(hitbox: Area2D):
	if hitbox.is_in_group("hitbox"):
		# Ignore self damage: compare owner_id meta
		var my_owner = get_parent().get_instance_id() if is_instance_valid(get_parent()) else -1
		var hb_owner = hitbox.get_meta("owner_id") if hitbox.has_meta("owner_id") else null
		if hb_owner != null and hb_owner == my_owner:
			return
		# Check if this hitbox is on cooldown
		if hitbox in recent_hits:
			return
			
		# Store hitbox for potential parry reflection
		last_hitbox = hitbox
		
		# Add this hitbox to recent hits with appropriate cooldown
		var cooldown = slam_hit_cooldown if hitbox.get_parent().name.contains("HeavyEnemy") else hit_cooldown
		recent_hits[hitbox] = cooldown
		
		# Check if parent is in block state BEFORE setting damage
		var parent = get_parent()
		if parent.has_node("StateMachine") and parent.state_machine.has_method("get_current_state"):
			var current_state = parent.state_machine.get_current_state()
			if current_state and current_state.name == "Block":
				# Let block state handle the damage value
				await current_state._on_hurtbox_hurt(hitbox)
			else:
				# Normal damage handling
				last_damage = hitbox.damage
		else:
			# Normal damage handling (for enemies without state machine)
			last_damage = hitbox.damage
		
		# Emit hurt signal after damage is determined
		hurt.emit(hitbox)
