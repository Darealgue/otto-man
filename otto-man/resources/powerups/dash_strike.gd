extends PowerupResource

const DAMAGE_MULTIPLIER = 1.5  # Dash deals 150% of normal damage
const COOLDOWN_INCREASE = 0.3  # Seconds
const DASH_DURATION = 0.1  # Match the player's dash duration

func _init() -> void:
	id = "dash_strike"
	name = "Dash Strike"
	description = "Dash deals damage but has longer cooldown"
	can_stack = true

func apply_effect(player: CharacterBody2D) -> void:
	# Create a hitbox for the dash if it doesn't exist
	if not player.has_node("DashHitbox"):
		var hitbox = preload("res://components/hitbox.tscn").instantiate()
		hitbox.name = "DashHitbox"
		
		# Configure hitbox for dash
		hitbox.collision_layer = player.LAYERS.PLAYER_HITBOX
		hitbox.collision_mask = player.LAYERS.ENEMY_HURTBOX
		
		# Position the hitbox
		hitbox.position = Vector2(20, 0)  # Slightly in front of player
		
		# Connect the hitbox's area_entered signal
		hitbox.area_entered.connect(_on_dash_hit.bind(player))
		
		player.add_child(hitbox)
		
		# Connect to dash signal if it exists
		if player.has_signal("dash_started"):
			if not player.dash_started.is_connected(enable_dash_hitbox.bind(player)):
				player.dash_started.connect(enable_dash_hitbox.bind(player))
	
	update_stack_effect(player)

func update_stack_effect(player: CharacterBody2D) -> void:
	var dash_hitbox = player.get_node_or_null("DashHitbox")
	if dash_hitbox:
		# Use player's current damage for dash damage
		dash_hitbox.damage = int(player.current_damage * DAMAGE_MULTIPLIER * stack_count)
	
	# Update dash cooldown through script variable
	if player.has_method("set_dash_cooldown"):
		var new_cooldown = player.base_dash_cooldown + (COOLDOWN_INCREASE * stack_count)
		player.set_dash_cooldown(new_cooldown)

func remove_effect(player: CharacterBody2D) -> void:
	var dash_hitbox = player.get_node_or_null("DashHitbox")
	if dash_hitbox:
		# Disconnect the signal if it exists
		if player.has_signal("dash_started"):
			var connections = player.dash_started.get_connections()
			for conn in connections:
				if conn["callable"].get_object() == self:
					player.dash_started.disconnect(conn["callable"])
		
		dash_hitbox.queue_free()
	
	# Reset dash cooldown to base value
	if player.has_method("set_dash_cooldown"):
		player.set_dash_cooldown(player.base_dash_cooldown)

func enable_dash_hitbox(player: CharacterBody2D) -> void:
	var dash_hitbox = player.get_node_or_null("DashHitbox")
	if dash_hitbox:
		# Update hitbox position based on player direction
		var facing = -1 if player.get_node("AnimatedSprite2D").flip_h else 1
		dash_hitbox.position.x = abs(dash_hitbox.position.x) * facing
		
		# Enable the hitbox
		dash_hitbox.enable(DASH_DURATION)  # Enable for the duration of the dash

func _on_dash_hit(area: Area2D, player: CharacterBody2D) -> void:
	if area.is_in_group("hurtbox"):
		var target = area.get_parent()
		if target.has_method("take_damage"):
			var dash_hitbox = player.get_node_or_null("DashHitbox")
			if dash_hitbox:
				var damage = dash_hitbox.damage
				var knockback_dir = (area.global_position - player.global_position).normalized()
				target.take_damage(damage, knockback_dir)
				
				# Spawn damage number
				if player.has_method("spawn_damage_number"):
					player.spawn_damage_number(damage, target.global_position)
