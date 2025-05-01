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
	
	# Store original facing direction immediately
	# original_flip_h = player.sprite.flip_h # <<< SAKLANABİLİR AMA ZORLAMAYACAĞIZ >>>
	original_flip_h = player.sprite.flip_h # Geçici olarak kalsın, belki başka yerde lazım olur
	
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
	
	# Check if this hit should apply knockback
	has_knockback = knockback_data != null and (knockback_data.get("force", 0.0) > 0.0 or knockback_data.get("up_force", 0.0) > 0.0)
	
	if has_knockback and player.last_hit_position:
		var dir = (player.global_position - player.last_hit_position).normalized()
		knockback_direction = dir
		
		# Use the enemy's knockback values with increased minimums and multiplier
		var knockback_force = max(knockback_data.get("force", 0.0), MIN_KNOCKBACK_FORCE) * KNOCKBACK_MULTIPLIER
		var up_force = max(knockback_data.get("up_force", 0.0), MIN_UP_FORCE) * KNOCKBACK_MULTIPLIER
		
		# Check if this is a charge attack (no upward force)
		is_charge_knockback = knockback_data.get("up_force", 0.0) == 0 and knockback_data.get("force", 0.0) > 0
		
		# For charge attacks, ensure purely horizontal knockback
		if is_charge_knockback:
			player.velocity = Vector2(dir.x * knockback_force, 0)
		else:
			# For other attacks, apply both horizontal and vertical knockback
			player.velocity = Vector2(
				dir.x * knockback_force,
				-up_force
			)
			
			# Enable double jump when knocked into the air
			player.enable_double_jump()
			player.is_jumping = false  # Reset jumping state to allow double jump
	else:
		# No knockback, just keep current velocity
		is_charge_knockback = false
	
	# Force the sprite to keep its original direction # <<< BU SATIR KALDIRILDI >>>
	# player.sprite.flip_h = original_flip_h
	
	# Flash the sprite red
	player.sprite.modulate = Color(1, 0, 0, 1)

func physics_update(delta: float) -> void:
	hurt_timer -= delta
	invincibility_timer -= delta
	
	# Force sprite to maintain original direction # <<< BU SATIR KALDIRILDI >>>
	# player.sprite.flip_h = original_flip_h 
	
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
		
		player.sprite.visible = true  # Ensure sprite is visible
		player.sprite.modulate = Color(1, 1, 1, 1)  # Reset color
		
		# <<< YENİ SATIR: State'ten çıkmadan cooldown başlat >>>
		player.attack_cooldown_timer = 0.1 # Kısa bir bekleme süresi
		
		if player.is_on_floor():
			state_machine.transition_to("Idle")
		else:
			state_machine.transition_to("Fall")

func exit() -> void:
	
	# Reset knockback and visual effects
	knockback_direction = Vector2.ZERO
	player.sprite.visible = true
	player.sprite.modulate = Color(1, 1, 1, 1)
	
	# Ensure we keep the original facing direction # <<< BU SATIR KALDIRILDI >>>
	# player.sprite.flip_h = original_flip_h
	
	# Keep invincibility timer in player for other states to check
	player.invincibility_timer = invincibility_timer
