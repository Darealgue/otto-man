extends State

const ATTACK_SPEED_MULTIPLIER = 0.5  # 50% movement speed during attacks
const MOMENTUM_PRESERVATION = 0.8     # Preserve 80% of previous momentum
const ANIMATION_SPEED = 1.8          # 80% faster animations (Silksong style)
const GROUND_ATTACK_ANIMATIONS = ["attack_1.1", "up_light", "down_light"]  # Ground variants
const AIR_ATTACK_ANIMATIONS = ["air_attack1", "air_attack2", "air_attack3"]  # Attacks only available in air
const UP_ATTACK_ANIMATIONS = ["air_attack_up1", "air_attack_up2"]  # Up attacks in air
const LIGHT_COMBO_RESET_TIME := 0.4  # Faster combo timing (Silksong style)
const AIR_COMBO_RESET_TIME := 0.5    # Faster air combo timing
const DAMAGE_MULTIPLIER = 1  # Fixed damage multiplier for all attacks

var current_attack := ""
var hitbox_enabled := false
var initial_velocity := Vector2.ZERO
var has_activated_hitbox := false  # Track if we've already activated the hitbox in this attack
var entered_from_crouch := false  # Track if we came from crouch state
var can_use_attack_1_2 := false    # Track if attack_1.2 can be used (only after attack_1.1)
var next_attack_queued := ""       # For storing the next attack in the sequence
var hitbox_start_time := 0.0      # Track when the hitbox was enabled
var hitbox_end_time := 0.0        # Track when the hitbox was disabled
var await_release_for_second := false  # Enforce second hit requires a release-then-press
var jump_cancel_enabled := false
var jump_cancel_timer := 0.0
var can_use_attack_1_3 := false
var await_release_for_third := false
var light_combo_timer := 0.0
var air_combo_step := 0
var air_combo_timer := 0.0
var attack_buffer_timer := 0.0
var effect_spawned := false

func _choose_second_hit() -> String:
	# Randomly choose between legacy second hit (attack_1.2) and the paired variant (attack_1.4)
	var pool := ["attack_1.2", "attack_1.4"]
	return pool[randi() % pool.size()]

func enter():
	hitbox_start_time = 0.0
	hitbox_end_time = 0.0
	attack_buffer_timer = 0.0
	effect_spawned = false
	
	# Enter combat state when attacking
	player.enter_combat_state()
	
	# Check if we came from crouch state
	entered_from_crouch = (state_machine.previous_state.name == "Crouch")
	
	# If we came from crouch, maintain crouch collision shape
	if entered_from_crouch:
		_maintain_crouch_collision()
	
	# Store initial velocity for momentum preservation
	initial_velocity = player.velocity
	
	# Reset hitbox CollisionShape2D position (in case coming from up attack)
	var reset_hitbox = player.get_node_or_null("Hitbox")
	if reset_hitbox and reset_hitbox is PlayerHitbox:
		var collision_shape = reset_hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.position = Vector2(52.625, -22.5)  # Orijinal pozisyona döndür
			print("[AttackState] Hitbox CollisionShape2D position reset to: ", collision_shape.position)
	
	# Debug print disabled to reduce console spam
	# print("[AttackState] ENTER | on_floor=", player.is_on_floor())
	
	# Disconnect previous animation signal if connected
	if animation_player.is_connected("animation_finished", _on_animation_player_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_player_animation_finished)
	
	# Connect animation finished signal
	animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	# Debug: report presence of counter animation and number of animations
	if animation_player and animation_player.has_method("has_animation"):
		var has_counter: bool = animation_player.has_animation("counter_light")
		var anim_count: int = 0
		if animation_player.has_method("get_animation_list"):
			var lst: Array = animation_player.get_animation_list()
			anim_count = lst.size()
		# Debug print disabled to reduce console spam
		# print("[AttackState] Debug | has counter_light=", has_counter, " anim_count=", anim_count)
	
	
	# Use queued attack if available, otherwise choose based on input/counter
	if next_attack_queued == "attack_1.2" and can_use_attack_1_2:
		current_attack = "attack_1.2"
		next_attack_queued = ""
		can_use_attack_1_2 = false
		can_use_attack_1_3 = true
		await_release_for_third = true
	else:
		# Counter-specific animation if available (definitive)
		var used_counter := false
		if player.has_method("is_counter_window_active") and player.is_counter_window_active():
			if animation_player.has_animation("counter_light"):
				current_attack = "counter_light"
				used_counter = true
				# Debug print disabled to reduce console spam
				# print("[AttackState] Using counter_light animation")
			else:
				print("[AttackState][WARN] counter_light animation missing, fallback to normal")
		if not used_counter and player.is_on_floor():
			var up_strength = Input.get_action_strength("up")
			var down_strength = Input.get_action_strength("down")
			var is_crouching = state_machine.current_state.name == "Crouch"
			
			# Check if player is forced to crouch due to ceiling
			var is_forced_to_crouch = _is_player_forced_to_crouch()
			
			if up_strength > 0.6 and not is_forced_to_crouch:
				current_attack = "up_light"
			elif down_strength > 0.6 or is_crouching or is_forced_to_crouch:
				current_attack = "down_light"
				# Debug print disabled to reduce console spam
				# print("[AttackState] down_light selected | down_input=", down_strength > 0.6, " crouching=", is_crouching, " forced=", is_forced_to_crouch)
			else:
				current_attack = "attack_1.1"
			# Debug print disabled to reduce console spam  
			# print("[AttackState] SELECT | up=", String.num(up_strength,2), " down=", String.num(down_strength,2), " crouching=", is_crouching, " -> ", current_attack)
		elif not used_counter:
			# Air combo: follow a deterministic sequence while in air (advance on finish)
			if AIR_ATTACK_ANIMATIONS.size() > 0:
				if air_combo_timer <= 0.0:
					air_combo_step = 0
				current_attack = AIR_ATTACK_ANIMATIONS[min(air_combo_step, AIR_ATTACK_ANIMATIONS.size() - 1)]
			else:
				state_machine.transition_to("Fall")
				return
		
		# Reset attack_1.2 availability unless we're doing attack_1.1
		if current_attack == "attack_1.1":
			can_use_attack_1_2 = true
			await_release_for_second = true
		else:
			can_use_attack_1_2 = false
			await_release_for_second = false
	# Debug print disabled to reduce console spam
	# print("[AttackState] current_attack=", current_attack, " can_use_attack_1_2=", can_use_attack_1_2)
	
	# Ensure animation player is reset before playing new animation
	animation_player.stop()
	# Per-move speed tuning (up_light felt too fast)
	if current_attack == "up_light":
		animation_player.speed_scale = 0.9
	else:
		animation_player.speed_scale = ANIMATION_SPEED
	
	# Check if animation exists before playing
	if animation_player.has_animation(current_attack):
		animation_player.play(current_attack)
		animation_player.seek(0.0, true)
		# Debug print disabled to reduce console spam
		# print("[AttackState] PLAY | ", current_attack, " len=", animation_player.current_animation_length)
		# brief watchdog to confirm the animation stays active
		await get_tree().create_timer(0.05).timeout
		if animation_player.current_animation != current_attack:
			print("[AttackState][WARN] Anim interrupted early -> ", animation_player.current_animation)
	else:
		# Fall back to a default animation or return to previous state
		if player.is_on_floor():
			state_machine.transition_to("Idle")
		else:
			state_machine.transition_to("Fall")
		return
	
	# Reset hitbox state
	hitbox_enabled = false
	has_activated_hitbox = false
	light_combo_timer = LIGHT_COMBO_RESET_TIME
	if _is_air_attack(current_attack):
		air_combo_timer = AIR_COMBO_RESET_TIME
	
	# Set up hitbox for current attack and make sure it's disabled at start
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		hitbox.disable()  # Always start with hitbox disabled
		
		# Prepare the attack type based on whether it's an air attack or ground attack
		var attack_type = "light"
		hitbox.enable_combo(current_attack, DAMAGE_MULTIPLIER) 
		_update_hitbox_position(hitbox)
		if hitbox.hit_enemy.is_connected(_on_enemy_hit):
			hitbox.hit_enemy.disconnect(_on_enemy_hit)
		hitbox.hit_enemy.connect(_on_enemy_hit)
		# Debug print disabled to reduce console spam
		# print("[AttackState] HITBOX PREP | name=", current_attack)

func exit():
	
	# Disconnect animation finished signal
	if animation_player.is_connected("animation_finished", _on_animation_player_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_player_animation_finished)
	
	# Disable hitbox
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		hitbox.disable()
		hitbox.disable_combo()
	
	# Reset animation speed
	animation_player.speed_scale = 1.0

func update(delta: float):
	# Skip all processing if game is paused
	if get_tree().paused:
		return
	
	# Maintain crouch collision if we came from crouch
	if entered_from_crouch:
		_maintain_crouch_collision()
		
	# Handle movement during attack
	_handle_movement(delta)
	
	# Check for attack_1.2 input if we just performed attack_1.1 and still on ground
	# First, detect release between presses to avoid auto-chaining on a single press
	if can_use_attack_1_2 and await_release_for_second and Input.is_action_just_released("attack"):
		await_release_for_second = false
		# Debug print disabled to reduce console spam
		# print("[AttackState] Release detected; second hit now allowed")
	if can_use_attack_1_2 and not await_release_for_second and Input.is_action_just_pressed("attack") and player.is_on_floor():
		var next2 := _choose_second_hit()
		next_attack_queued = next2
		# Debug print disabled to reduce console spam
		# print("[AttackState] Input buffered for second hit: ", next2)
	# Fallback queue: if release algısı kaçtıysa, 1.1 sırasında basılı tutulan saldırıyı yine sıraya al
	if can_use_attack_1_2 and not await_release_for_second and player.is_on_floor():
		if current_attack == "attack_1.1" and next_attack_queued == "":
			var len: float = animation_player.current_animation_length
			if len > 0.0:
				var prog: float = animation_player.current_animation_position / len
				if prog >= 0.2 and prog <= 0.9 and Input.is_action_pressed("attack"):
					var next2b := _choose_second_hit()
					next_attack_queued = next2b
					print("[AttackState] Fallback buffer -> ", next2b, " during 1.1")
	# Third hit buffer (requires release again)
	if can_use_attack_1_3 and await_release_for_third and Input.is_action_just_released("attack"):
		await_release_for_third = false
		print("[AttackState] Release detected; third hit now allowed")
	# Only allow queuing 1.3 after 1.2 progressed enough
	var allow_third := false
	if animation_player.current_animation == "attack_1.2":
		var len3: float = animation_player.current_animation_length
		if len3 > 0.0:
			var prog3: float = animation_player.current_animation_position / len3
			allow_third = prog3 >= 0.35
	if can_use_attack_1_3 and not await_release_for_third and allow_third and Input.is_action_just_pressed("attack") and player.is_on_floor():
		# Down basılıysa eski 1.2 (yeni 1.4) tercih edilsin, aksi halde 1.3
		var want_old_second := Input.is_action_pressed("down")
		var next_name := "attack_1.3"
		if want_old_second and animation_player.has_animation("attack_1.4"):
			next_name = "attack_1.4"
		elif not animation_player.has_animation("attack_1.3") and animation_player.has_animation("attack_1.4"):
			next_name = "attack_1.4"
		next_attack_queued = next_name
		print("[AttackState] Input buffered for third hit: ", next_attack_queued)
	
	# Check for air attack input
	if Input.is_action_just_pressed("attack") and not player.is_on_floor() and not _is_air_attack(current_attack):
		# Check for up input to determine attack type
		var up_strength = Input.get_action_strength("up")
		if up_strength > 0.6:
			# Up attack - transition to AirAttackUp state
			state_machine.transition_to("AirAttackUp")
			return
		else:
			# Normal air attack
			state_machine.transition_to("Attack")
			return
	# General attack input buffer timer
	if Input.is_action_just_pressed("attack"):
		attack_buffer_timer = 0.2
	elif attack_buffer_timer > 0.0:
		attack_buffer_timer -= delta
	
	# Handle attack cancels
	# Update jump-cancel window decay
	if jump_cancel_enabled:
		jump_cancel_timer -= delta
		if jump_cancel_timer <= 0.0:
			jump_cancel_enabled = false
			jump_cancel_timer = 0.0
	if _check_cancel_conditions():
		return
	
	# Handle hitbox based on animation progress
	_update_hitbox()
	
	# Check if we need to transition to fall state if player is no longer on floor
	if not player.is_on_floor() and _is_ground_attack(current_attack) and animation_player.current_animation_position > 0.6:
		state_machine.transition_to("Fall")
		return
	# Air combo chaining after each air attack ends
	if _is_air_attack(current_attack):
		air_combo_timer = max(0.0, air_combo_timer - delta)

# Helper function to check if the current attack is an air attack
func _is_air_attack(attack_name: String) -> bool:
	var is_air = AIR_ATTACK_ANIMATIONS.has(attack_name) or UP_ATTACK_ANIMATIONS.has(attack_name)
	return is_air

# Helper function to check if the current attack is a ground attack
func _is_ground_attack(attack_name: String) -> bool:
	var is_ground = GROUND_ATTACK_ANIMATIONS.has(attack_name) or attack_name == "attack_1.2" or attack_name == "attack_1.3" or attack_name == "attack_1.4"
	return is_ground

func _update_hitbox():
	# If we've already activated the hitbox in this attack, don't activate it again
	if has_activated_hitbox:
		return
		
	# Get current animation progress as a percentage (0.0 to 1.0)
	var anim_progress = animation_player.current_animation_position / animation_player.current_animation_length
	
	var hitbox = player.get_node_or_null("Hitbox")
	if not hitbox or not hitbox is PlayerHitbox:
		return
	
	# Tune windows per light variant (Silksong style - tighter timing)
	var start := 0.35
	var finish := 0.45
	if current_attack == "up_light":
		start = 0.30
		finish = 0.45
	elif current_attack == "down_light":
		start = 0.35
		finish = 0.50
	elif current_attack == "attack_1.2":
		start = 0.32
		finish = 0.48
	# Enable hitbox during tuned window
	if anim_progress >= start and anim_progress <= finish and not hitbox_enabled:
		hitbox.disable()  # Ensure it's disabled first
		
		# Counter window bonus after parry
		var dmg_mult := DAMAGE_MULTIPLIER
		var kb_mult := 1.0
		var kb_up_mult := 1.0
		if player.has_method("is_counter_window_active") and player.is_counter_window_active():
			# Apply a modest bonus for light counters
			dmg_mult *= (1.0 + player.counter_damage_bonus)
			kb_mult *= (1.0 + player.counter_knockback_bonus)
			kb_up_mult *= (1.0 + player.counter_knockback_bonus)
			print("[Counter] Light counter bonus applied")
			player.consume_counter_window()
		# Update the hitbox with the current attack type
		hitbox.enable_combo(current_attack, dmg_mult, kb_mult, kb_up_mult)
		
		hitbox.enable()
		hitbox_enabled = true
		hitbox_start_time = Time.get_ticks_msec() / 1000.0
		# Debug print disabled to reduce console spam
		# print("[AttackState] HITBOX ON | ", current_attack, " at progress=", String.num(anim_progress, 2))
		
		# Set a timer to disable the hitbox after a short duration (Silksong style - faster)
		await get_tree().create_timer(0.08).timeout
		if hitbox and is_instance_valid(hitbox) and hitbox_enabled:
			hitbox.disable()
			hitbox_enabled = false
			hitbox_end_time = Time.get_ticks_msec() / 1000.0
			var duration = hitbox_end_time - hitbox_start_time
			# Debug print disabled to reduce console spam
			# print("[AttackState] HITBOX OFF | duration=", String.num(duration, 2))
	
	# Update hitbox position
	_update_hitbox_position(hitbox)

func _handle_movement(delta: float) -> void:
	# Get horizontal movement only
	var input_dir_x = InputManager.get_flattened_axis(&"ui_left", &"ui_right")
	
	# Calculate velocity with attack speed multiplier
	var target_velocity = Vector2(
		input_dir_x * player.speed * ATTACK_SPEED_MULTIPLIER,
		player.velocity.y  # Keep vertical velocity unchanged
	)
	
	# Apply momentum preservation
	player.velocity.x = lerp(player.velocity.x, target_velocity.x, 1.0 - MOMENTUM_PRESERVATION)
	
	# Update player facing direction if moving
	if input_dir_x != 0:
		player.sprite.flip_h = input_dir_x < 0
	
	# Apply movement
	player.move_and_slide()

func _check_cancel_conditions() -> bool:
	# Cancel into dodge (dash locked until powerup)
	if Input.is_action_just_pressed("dash") and state_machine.has_node("Dodge"):
		var dodge_state = state_machine.get_node("Dodge")
		if dodge_state and dodge_state.can_start_dodge():
			_cancel_into_state("Dodge")
			print("[AttackState] CANCEL -> Dodge")
			return true
	
	# Cancel into jump
	if Input.is_action_just_pressed("jump") and state_machine.has_node("Jump") and (
		(player.is_on_floor()) or jump_cancel_enabled
	):
		_cancel_into_state("Jump")
		print("[AttackState] CANCEL -> Jump")
		return true
	
	# Cancel into block
	if Input.is_action_just_pressed("block") and state_machine.has_node("Block"):
		_cancel_into_state("Block")
		print("[AttackState] CANCEL -> Block")
		return true
	
	return false

func _cancel_into_state(state_name: String) -> void:
	# Clean up current attack state
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		hitbox.disable()
		hitbox.disable_combo()
	
	# Transition to new state
	state_machine.transition_to(state_name)

func _update_hitbox_position(hitbox: Node2D) -> void:
	var collision_shape = hitbox.get_node("CollisionShape2D")
	if collision_shape:
		# Normal attack için orijinal pozisyonu kullan (oyuncunun önünde)
		var original_position = Vector2(52.625, -22.5)  # Player scene'deki orijinal pozisyon
		var position = original_position
		# X pozisyonunu oyuncunun bakış yönüne göre ayarla (önüne koy)
		position.x = abs(position.x) * (-1 if player.sprite.flip_h else 1)
		collision_shape.position = position
		# Debug: Hitbox position set
		print("[AttackState] Hitbox position set to: ", position, " facing: ", "left" if player.sprite.flip_h else "right")

func _on_animation_player_animation_finished(anim_name: String):

	if anim_name == current_attack:
		
		# Disable hitbox if still active
		if hitbox_enabled:
			var hitbox = player.get_node_or_null("Hitbox")
			if hitbox and hitbox is PlayerHitbox:
				hitbox.disable()
				hitbox_enabled = false
				# Debug print disabled to reduce console spam
				# print("[AttackState] FINISH | forced hitbox off")
		
		# If we have a queued attack_1.2/1.3/1.4 and still on ground, transition to it
		if (
			next_attack_queued == "attack_1.2" and can_use_attack_1_2 and player.is_on_floor()
		) or (
			next_attack_queued == "attack_1.3" and player.is_on_floor()
		) or (
			next_attack_queued == "attack_1.4" and player.is_on_floor()
		):
			# Avoid transitioning through the state machine to prevent animation glitches
			# Just play the new animation directly
			# Debug print disabled to reduce console spam
			# print("[AttackState] Queued combo -> playing ", next_attack_queued)
			current_attack = next_attack_queued
			next_attack_queued = ""
			if current_attack == "attack_1.2":
				can_use_attack_1_2 = false
				can_use_attack_1_3 = true
				await_release_for_third = true
			else:
				can_use_attack_1_3 = false
			
			# Reset hitbox state for new attack
			hitbox_enabled = false
			has_activated_hitbox = false
			var hitbox = player.get_node_or_null("Hitbox")
			if hitbox and hitbox is PlayerHitbox:
				hitbox.disable()
				hitbox.disable_combo()
				hitbox.enable_combo(current_attack, DAMAGE_MULTIPLIER)
			
			# Play the new animation
			animation_player.stop()
			animation_player.speed_scale = ANIMATION_SPEED
			if animation_player.has_animation(current_attack):
				animation_player.play(current_attack)
				animation_player.seek(0.0, true)
				# Debug print disabled to reduce console spam
				# print("[AttackState] Now playing:", animation_player.current_animation)
				# re-enable hitbox timing for second hit
				hitbox_enabled = false
				has_activated_hitbox = false
			else:
				print("[AttackState][WARN] Missing animation:", current_attack)

			return
		
		# If we finished an air attack and we're still airborne, advance air combo step
		if _is_air_attack(anim_name) and not player.is_on_floor():
			air_combo_step = (air_combo_step + 1) % AIR_ATTACK_ANIMATIONS.size()
			# Debug print disabled to reduce console spam
			# print("[AttackState] AIR STEP -> ", air_combo_step)
			# Keep the air combo window fresh while chaining
			air_combo_timer = AIR_COMBO_RESET_TIME
		# Return to appropriate state based on whether player is on ground
		if player.is_on_floor():
			# If we just finished down_light and (crouch is pressed OR player is forced to crouch), return to Crouch
			if current_attack == "down_light" and (Input.is_action_pressed("crouch") or _is_player_forced_to_crouch()):
				# Debug print disabled to reduce console spam
				# print("[AttackState] down_light finished, returning to Crouch (manual or forced)")
				state_machine.transition_to("Crouch")
			else:
				state_machine.transition_to("Idle")
		else:
			player.attack_cooldown_timer = 0.05 # <<< Air attack cooldown reduced to 0.05s >>>
			state_machine.transition_to("Fall")

func _on_enemy_hit(enemy: Node):
	if not has_activated_hitbox:
		has_activated_hitbox = true
		# Enable brief jump-cancel on up_light
		if current_attack == "up_light":
			jump_cancel_enabled = true
			jump_cancel_timer = 0.12

# Helper function to maintain crouch collision during attack
func _maintain_crouch_collision():
	if !player:
		return
		
	var collision_shape = player.get_node_or_null("CollisionShape2D")
	var hurtbox_shape = player.get_node_or_null("Hurtbox/CollisionShape2D")
	
	if not collision_shape or not hurtbox_shape:
		return
		
	if not (collision_shape.shape is CapsuleShape2D and hurtbox_shape.shape is CapsuleShape2D):
		return
	
	# Get crouch dimensions from crouch state
	var crouch_state = state_machine.get_node_or_null("Crouch")
	if crouch_state and crouch_state.has_method("apply_crouch_shape_now"):
		crouch_state.apply_crouch_shape_now()

# Helper function to check if player is forced to crouch due to ceiling
func _is_player_forced_to_crouch() -> bool:
	if !player:
		return false
	
	# Use the same logic as crouch state's can_stand_up method
	var space_state = player.get_world_2d().direct_space_state
	
	# Get original height from crouch state if available
	var crouch_state = state_machine.get_node_or_null("Crouch")
	var original_height = 44.0  # Default capsule height
	if crouch_state and "original_height" in crouch_state and crouch_state.original_height > 0:
		original_height = crouch_state.original_height
	
	# Check multiple points around the player to ensure no overlap with ceiling
	var check_points = [
		Vector2.UP * original_height,  # Top center
		Vector2.UP * original_height + Vector2.LEFT * 10,  # Top left
		Vector2.UP * original_height + Vector2.RIGHT * 10,  # Top right
	]
	
	for check in check_points:
		var query = PhysicsRayQueryParameters2D.new()
		query.from = player.global_position
		query.to = player.global_position + check
		query.exclude = [player]
		
		var result = space_state.intersect_ray(query)
		if result:
			# If any check hits something, player is forced to crouch
			return true
	
	return false
