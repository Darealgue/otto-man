extends State

const HURT_DURATION := 0.5
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

@export var debug_enabled: bool = true  # Set to true by default for debugging

func enter():
	print("[HurtState] ====== HURT STATE DEBUG ======")
	print("[HurtState] Player position:", player.global_position)
	
	# Store original facing direction immediately
	original_flip_h = player.sprite.flip_h
	print("[HurtState] Original facing direction (flip_h):", original_flip_h)
	
	# Always play hurt animation first
	animation_player.play("hurt")
	hurt_timer = HURT_DURATION
	invincibility_timer = INVINCIBILITY_DURATION
	flash_timer = 0.0
	
	# Get knockback data from the last hit
	var knockback_data = player.last_hit_knockback
	print("[HurtState] Knockback data:", knockback_data)
	
	# Check if this hit should apply knockback
	has_knockback = knockback_data != null and (knockback_data.get("force", 0.0) > 0.0 or knockback_data.get("up_force", 0.0) > 0.0)
	
	if has_knockback and player.last_hit_position:
		print("[HurtState] Last hit position:", player.last_hit_position)
		var dir = (player.global_position - player.last_hit_position).normalized()
		knockback_direction = dir
		print("[HurtState] Calculated knockback direction:", dir)
		
		# Use the enemy's knockback values with increased minimums and multiplier
		var knockback_force = knockback_data.get("force", 0.0) * KNOCKBACK_MULTIPLIER
		var up_force = knockback_data.get("up_force", 0.0) * KNOCKBACK_MULTIPLIER
		
		print("[HurtState] Final knockback force:", knockback_force)
		print("[HurtState] Final up force:", up_force)
		
		# Check if this is a charge attack (no upward force)
		is_charge_knockback = up_force == 0 and knockback_force > 0
		
		# For charge attacks, ensure purely horizontal knockback
		if is_charge_knockback:
			player.velocity = Vector2(dir.x * knockback_force, 0)
		else:
			# For other attacks, apply both horizontal and vertical knockback
			player.velocity = Vector2(
				dir.x * knockback_force,
				-up_force
			)
		
		print("[HurtState] Applied velocity:", player.velocity)
	else:
		# No knockback, just keep current velocity
		print("[HurtState] No knockback applied")
		is_charge_knockback = false
	
	# Force the sprite to keep its original direction
	player.sprite.flip_h = original_flip_h
	
	# Flash the sprite red
	player.sprite.modulate = Color(1, 0, 0, 1)

func physics_update(delta: float):
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
	
	# Debug movement
	if abs(player.velocity.x) > 0.1 or abs(player.velocity.y) > 0.1:
		print("[HurtState] Current velocity:", player.velocity)
		print("[HurtState] Current position:", player.global_position)
		print("[HurtState] Current facing direction (flip_h):", player.sprite.flip_h)
	
	# Transition to fall state if hurt animation is done
	if hurt_timer <= 0:
		player.sprite.visible = true  # Ensure sprite is visible
		player.sprite.modulate = Color(1, 1, 1, 1)  # Reset color
		if player.is_on_floor():
			print("[HurtState] Transitioning to Idle")
			state_machine.transition_to("Idle")
		else:
			print("[HurtState] Transitioning to Fall")
			state_machine.transition_to("Fall")

func exit():
	# Reset knockback and visual effects
	knockback_direction = Vector2.ZERO
	player.sprite.visible = true
	player.sprite.modulate = Color(1, 1, 1, 1)
	
	# Ensure we keep the original facing direction
	player.sprite.flip_h = original_flip_h
	
	print("[HurtState] Exiting hurt state. Final position:", player.global_position)
	print("[HurtState] Final facing direction (flip_h):", player.sprite.flip_h)
	print("[HurtState] ====== END HURT STATE DEBUG ======")
	
	# Keep invincibility timer in player for other states to check
	player.invincibility_timer = invincibility_timer 