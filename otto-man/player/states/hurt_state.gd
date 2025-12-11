extends State

const HURT_DURATION := 0.268  # Match animation length exactly
const INVINCIBILITY_DURATION := 1.0  # Time player is invincible after getting hit
const MIN_KNOCKBACK_FORCE := 500.0  # Base minimum knockback force (only used if knockback is present)
const MIN_UP_FORCE := 300.0  # Base minimum upward force (only used if knockback is present)
const KNOCKBACK_MULTIPLIER := 1.0  # Normal multiplier for balanced knockback
const HORIZONTAL_DECAY := 0.3  # Lower value = slower horizontal velocity decay
const VERTICAL_DECAY := 1.0  # Normal gravity for vertical movement

var hurt_timer := 0.0
var invincibility_timer := 0.0
var knockback_direction := Vector2.ZERO
var flash_timer := 0.0
const FLASH_INTERVAL := 0.1
var is_red_flash := true  # Track current flash state
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
	is_red_flash = true  # Start with red flash
	
	# Get knockback data from the last hit
	var knockback_data = player.last_hit_knockback
	
	# Check if this hit should apply knockback
	has_knockback = knockback_data != null and (knockback_data.get("force", 0.0) > 0.0 or knockback_data.get("up_force", 0.0) > 0.0)
	
	if has_knockback and player.last_hit_position:
		var dir = (player.global_position - player.last_hit_position).normalized()
		knockback_direction = dir
		
		# Calculate direction TO enemy (opposite of knockback direction)
		var to_enemy_dir = (player.last_hit_position - player.global_position).normalized()
		
		# Make player face the enemy (direction TO enemy)
		# If enemy is on the left (to_enemy_dir.x < 0), player should face left (sprite.flip_h = true)
		# If enemy is on the right (to_enemy_dir.x > 0), player should face right (sprite.flip_h = false)
		player.sprite.flip_h = to_enemy_dir.x < 0
		
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
	
	# Start with red flash and ensure sprite is visible
	player.sprite.visible = true
	player.sprite.modulate = Color(1, 0, 0, 1)
	
	# Apply screen shake when taking damage
	_apply_screen_shake()

func update(delta: float) -> void:
	# Hit stun: Block all input during hurt state
	# Input handling is disabled - player cannot act during hit stun
	pass

func physics_update(delta: float) -> void:
	hurt_timer -= delta
	invincibility_timer -= delta
	
	# Keep player facing the enemy during knockback
	if has_knockback and player.last_hit_position:
		var to_enemy_dir = (player.last_hit_position - player.global_position).normalized()
		player.sprite.flip_h = to_enemy_dir.x < 0
	
	# Handle red flashing effect (keep sprite visible, toggle between red and white)
	flash_timer -= delta
	if flash_timer <= 0:
		flash_timer = FLASH_INTERVAL
		# Toggle between red and white
		is_red_flash = !is_red_flash
		if is_red_flash:
			player.sprite.modulate = Color(1, 0, 0, 1)  # Red
		else:
			player.sprite.modulate = Color(1, 1, 1, 1)  # White
	
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
		
		# Set timer to prevent auto-flipping for a short time after hurt state
		player.set_meta("hurt_exit_timer", 0.5)  # 0.5 seconds
		
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

func _apply_screen_shake() -> void:
	# Apply screen shake when player takes damage
	var screen_fx = get_node_or_null("/root/ScreenEffects")
	if not screen_fx or not screen_fx.has_method("shake"):
		return
	
	# Get damage from last hit to scale shake intensity
	var damage = 15.0  # Default damage value
	if player.hurtbox:
		# last_damage is a property of BaseHurtbox/PlayerHurtbox
		if player.hurtbox.last_damage > 0:
			damage = player.hurtbox.last_damage
	
	# Scale shake based on damage (similar to enemy hitbox system)
	var shake_duration: float
	var shake_strength: float
	
	if damage >= 31:
		shake_duration = 0.2
		shake_strength = 6.0
	else:
		shake_duration = 0.15
		shake_strength = 4.0
	
	screen_fx.shake(shake_duration, shake_strength)
