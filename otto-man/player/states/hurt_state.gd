extends State

const HURT_DURATION := 0.268  # Match animation length exactly
const INVINCIBILITY_DURATION := 1.0  # Time player is invincible after getting hit
const MIN_KNOCKBACK_FORCE := 500.0  # Base minimum knockback force (only used if knockback is present)
const MIN_UP_FORCE := 300.0  # Base minimum upward force (only used if knockback is present)
const KNOCKBACK_MULTIPLIER := 2.0  # Increased multiplier for more dramatic knockback
const HORIZONTAL_DECAY := 0.3  # Lower value = slower horizontal velocity decay
const VERTICAL_DECAY := 1.0  # Normal gravity for vertical movement

var hurt_timer := 0.0
var invincibility_timer := 0.0
var knockback_direction := Vector2.ZERO
var flash_timer := 0.0
const FLASH_INTERVAL := 0.1
var original_flip_h := false
var is_charge_knockback := false  # Track if this is from a charge attack
var has_knockback := false  # Track if this hit should apply knockback at all

func enter() -> void:
	if debug_enabled:
		print("[HurtState] Entering Hurt State")
	
	# Store original facing direction immediately
	original_flip_h = player.sprite.flip_h
	
	# Reset attack state
	var attack_state = state_machine.get_node("Attack")
	if attack_state and attack_state.has_method("_reset_attack_state"):
		attack_state._reset_attack_state()
	
	# Always play hurt animation first
	animation_player.stop()  # Stop any current animation
	animation_player.play("hurt")
	
	# Start timers
	hurt_timer = HURT_DURATION
	invincibility_timer = INVINCIBILITY_DURATION
	flash_timer = 0.0
	
	# Get knockback data from the last hit
	var knockback_data = player.last_hit_knockback
	if debug_enabled:
		print("[HurtState] Knockback data:", knockback_data)
	
	# Check if this hit should apply knockback
	has_knockback = knockback_data != null and (knockback_data.get("force", 0.0) > 0.0 or knockback_data.get("up_force", 0.0) > 0.0)
	if debug_enabled:
		print("[HurtState] Has knockback:", has_knockback)
	
	if has_knockback and player.last_hit_position:
		var dir = (player.global_position - player.last_hit_position).normalized()
		knockback_direction = dir
		if debug_enabled:
			print("[HurtState] Knockback direction:", dir)
		
		# Use the enemy's knockback values with increased minimums and multiplier
		var knockback_force = max(knockback_data.get("force", 0.0), MIN_KNOCKBACK_FORCE) * KNOCKBACK_MULTIPLIER
		var up_force = max(knockback_data.get("up_force", 0.0), MIN_UP_FORCE) * KNOCKBACK_MULTIPLIER
		
		# Check if this is a charge attack (no upward force)
		is_charge_knockback = knockback_data.get("up_force", 0.0) == 0 and knockback_data.get("force", 0.0) > 0
		if debug_enabled:
			print("[HurtState] Is charge knockback:", is_charge_knockback)
			print("[HurtState] Knockback force:", knockback_force)
			print("[HurtState] Up force:", up_force)
		
		# For charge attacks, ensure purely horizontal knockback
		if is_charge_knockback:
			player.velocity = Vector2(dir.x * knockback_force, 0)
			if debug_enabled:
				print("[HurtState] Applied charge knockback - Velocity:", player.velocity)
		else:
			# For other attacks, apply both horizontal and vertical knockback
			player.velocity = Vector2(
				dir.x * knockback_force,
				-up_force
			)
			if debug_enabled:
				print("[HurtState] Applied normal knockback - Velocity:", player.velocity)
			
			# Enable double jump when knocked into the air
			player.enable_double_jump()
			player.is_jumping = false  # Reset jumping state to allow double jump
			if debug_enabled:
				print("[HurtState] Enabled double jump after knockback")
	else:
		# No knockback, just keep current velocity
		is_charge_knockback = false
		if debug_enabled:
			print("[HurtState] No knockback applied - Current velocity:", player.velocity)
	
	# Force the sprite to keep its original direction
	player.sprite.flip_h = original_flip_h
	
	# Flash the sprite red
	player.sprite.modulate = Color(1, 0, 0, 1)

func physics_update(delta: float) -> void:
	hurt_timer -= delta
	invincibility_timer -= delta
	
	# Force sprite to maintain original direction
	player.sprite.flip_h = original_flip_h
	
	# Handle sprite flashing
	flash_timer -= delta
	if flash_timer <= 0:
		flash_timer = FLASH_INTERVAL
		player.sprite.visible = !player.sprite.visible
	
	# Apply different physics based on knockback type
	if has_knockback:
		if is_charge_knockback:
			# For charge knockback: maintain horizontal momentum, no vertical movement
			player.velocity.x = move_toward(player.velocity.x, 0, player.friction * HORIZONTAL_DECAY * delta)
			player.velocity.y = 0  # Keep it purely horizontal
		else:
			# For other knockbacks: slower horizontal decay, normal vertical physics
			player.velocity.x = move_toward(player.velocity.x, 0, player.friction * HORIZONTAL_DECAY * delta)
			player.velocity.y += player.gravity * VERTICAL_DECAY * delta
	else:
		# No knockback, just apply normal gravity
		player.velocity.y += player.gravity * delta
	
	player.move_and_slide()
	
	# Only transition after both the animation and hurt timer are done
	if hurt_timer <= 0:
		if debug_enabled:
			print("[HurtState] Hurt timer finished")
		
		player.sprite.visible = true  # Ensure sprite is visible
		player.sprite.modulate = Color(1, 1, 1, 1)  # Reset color
		if player.is_on_floor():
			if debug_enabled:
				print("[HurtState] On floor - Transitioning to Idle")
			state_machine.transition_to("Idle")
		else:
			if debug_enabled:
				print("[HurtState] In air - Transitioning to Fall")
			state_machine.transition_to("Fall")

func exit() -> void:
	if debug_enabled:
		print("[HurtState] Exiting Hurt State")
	
	# Reset knockback and visual effects
	knockback_direction = Vector2.ZERO
	player.sprite.visible = true
	player.sprite.modulate = Color(1, 1, 1, 1)
	
	# Ensure we keep the original facing direction
	player.sprite.flip_h = original_flip_h
	
	# Keep invincibility timer in player for other states to check
	player.invincibility_timer = invincibility_timer