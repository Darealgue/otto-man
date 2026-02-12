extends State

const ATTACK_SPEED_MULTIPLIER = 0.65
const MOMENTUM_PRESERVATION = 0.85
const ANIMATION_SPEED = 1.0
const DAMAGE_MULTIPLIER = 2.0
const JUST_WINDOW_START = 0.0   # relative to active window start
const JUST_WINDOW_LENGTH = 0.06 # 60ms perfect window
const JUST_DAMAGE_BONUS = 1.25  # +25% damage
const JUST_KB_BONUS = 1.25      # +25% knockback

const GROUND_HEAVY_ANIMATIONS = ["heavy_neutral", "up_heavy", "down_heavy"]
const AIR_HEAVY_ANIMATIONS = ["air_heavy"]

var current_attack := ""
var hitbox_enabled := false
var has_activated_hitbox := false
var initial_velocity := Vector2.ZERO
var entered_from_crouch := false  # Track if we came from crouch state

var allow_jump_cancel := false
var jump_cancel_timer: float = 0.0
var just_input_timer: float = 0.0
var just_bonus_ready: bool = false

# Movement lock system
var movement_locked := false
var past_halfway_point := false
const HALFWAY_THRESHOLD = 0.5  # Lock movement after 50% of animation

func enter():
	initial_velocity = player.velocity
	hitbox_enabled = false
	has_activated_hitbox = false
	just_input_timer = 0.0
	just_bonus_ready = false
	
	# Enter combat state when attacking
	player.enter_combat_state()
	
	# Check if we came from crouch state
	entered_from_crouch = (state_machine.previous_state.name == "Crouch")
	
	# If we came from crouch, maintain crouch collision shape
	if entered_from_crouch:
		_maintain_crouch_collision()
	
	# Reset movement lock system
	movement_locked = false
	past_halfway_point = false
	# Debug print disabled to reduce console spam
	# print("[HeavyAttack] ENTER | on_floor=", player.is_on_floor())
	if animation_player.is_connected("animation_finished", _on_anim_finished):
		animation_player.animation_finished.disconnect(_on_anim_finished)
	animation_player.animation_finished.connect(_on_anim_finished)
	# Debug: report presence of counter_heavy animation
	if animation_player and animation_player.has_method("has_animation"):
		var has_counter_h: bool = animation_player.has_animation("counter_heavy")
		var anim_count: int = 0
		if animation_player.has_method("get_animation_list"):
			var lst: Array = animation_player.get_animation_list()
			anim_count = lst.size()
		# Debug print disabled to reduce console spam
		# print("[HeavyAttack] Debug | has counter_heavy=", has_counter_h, " anim_count=", anim_count)
	# choose variant (prefer counter-specific if exists)
	if player.is_on_floor():
		var used_counter := false
		if player.has_method("is_counter_window_active") and player.is_counter_window_active():
			if animation_player.has_animation("counter_heavy"):
				current_attack = "counter_heavy"
				used_counter = true
				# Debug print disabled to reduce console spam
				# print("[HeavyAttack] Using counter_heavy animation")
			else:
				print("[HeavyAttack][WARN] counter_heavy animation missing, fallback to normal")
		if not used_counter:
			var up_strength = Input.get_action_strength("up")
			var down_strength = Input.get_action_strength("down")
			
			# Check if player is forced to crouch due to ceiling
			var is_forced_to_crouch = _is_player_forced_to_crouch()
			
			if up_strength > 0.6 and not is_forced_to_crouch:
				current_attack = "up_heavy"
			elif down_strength > 0.6 or is_forced_to_crouch:
				current_attack = "down_heavy"
			else:
				current_attack = "heavy_neutral"
	else:
		current_attack = AIR_HEAVY_ANIMATIONS[0]
	animation_player.stop()
	animation_player.speed_scale = ANIMATION_SPEED
	if animation_player.has_animation(current_attack):
		animation_player.play(current_attack)
		animation_player.seek(0.0, true)
		print("[HeavyAttack] PLAY | ", current_attack, " len=", animation_player.current_animation_length)
	else:
		var target_state = "Idle"
		if not player.is_on_floor():
			target_state = "Fall"
		state_machine.transition_to(target_state)
		return
	# prep hitbox
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		hitbox.disable()
		hitbox.enable_combo(current_attack, DAMAGE_MULTIPLIER)
		_update_hitbox_facing(hitbox)
		if hitbox.hit_enemy.is_connected(_on_enemy_hit):
			hitbox.hit_enemy.disconnect(_on_enemy_hit)
		hitbox.hit_enemy.connect(_on_enemy_hit)
		print("[HeavyAttack] HITBOX PREP | ", current_attack)

func exit():
	if animation_player.is_connected("animation_finished", _on_anim_finished):
		animation_player.animation_finished.disconnect(_on_anim_finished)
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		hitbox.disable()
		hitbox.disable_combo()
	animation_player.speed_scale = 1.0

func update(delta: float):
	if get_tree().paused:
		return
	
	# Maintain crouch collision if we came from crouch
	if entered_from_crouch:
		_maintain_crouch_collision()
	
	# Check if we've passed the halfway point for movement locking
	_check_movement_lock()
	
	# Handle early canceling (before halfway point)
	if not past_halfway_point:
		if _check_early_cancel():
			return
	
	# Handle movement (respects lock)
	_handle_movement(delta)
	
	# Listen for a quick confirm tap before impact to activate JUST bonus
	if Input.is_action_just_pressed("attack_heavy"):
		just_input_timer = 0.12
		just_bonus_ready = true
	_update_hitbox_by_timing()
	# decay jump-cancel window
	if allow_jump_cancel:
		jump_cancel_timer -= delta
		if jump_cancel_timer <= 0.0:
			allow_jump_cancel = false
			jump_cancel_timer = 0.0
	# decay just window
	if just_input_timer > 0.0:
		just_input_timer -= delta
		if just_input_timer <= 0.0:
			just_input_timer = 0.0
	# jump-cancel after launcher (up_heavy) - only if movement not locked
	if allow_jump_cancel and not movement_locked and Input.is_action_just_pressed("jump") and state_machine.has_node("Jump"):
		print("[HeavyAttack] Jump-cancel!")
		state_machine.transition_to("Jump")
		return

func _check_movement_lock() -> void:
	var length: float = animation_player.current_animation_length
	if length <= 0.0:
		return
	var progress = animation_player.current_animation_position / length
	
	# Check if we've passed the halfway point
	if progress >= HALFWAY_THRESHOLD and not past_halfway_point:
		past_halfway_point = true
		movement_locked = true
		print("[HeavyAttack] Movement LOCKED at progress: ", String.num(progress, 2))

func _check_early_cancel() -> bool:
	# Only allow canceling if we haven't reached halfway point
	if past_halfway_point:
		return false
		
	# Check for movement input (cancel attack)
	var input_dir_x = InputManager.get_flattened_axis(&"ui_left", &"ui_right")
	if abs(input_dir_x) > 0.1:
		print("[HeavyAttack] Early cancel due to movement input")
		_cancel_attack()
		if player.is_on_floor():
			state_machine.transition_to("Run")
		else:
			state_machine.transition_to("Fall")
		return true
		
	# Check for jump input (cancel attack)
	if Input.is_action_just_pressed("jump"):
		print("[HeavyAttack] Early cancel due to jump input")
		_cancel_attack()
		if state_machine.has_node("Jump"):
			state_machine.transition_to("Jump")
		return true
		
	return false

func _cancel_attack() -> void:
	# Clean up heavy attack state when canceling early
	just_bonus_ready = false
	just_input_timer = 0.0
	allow_jump_cancel = false
	jump_cancel_timer = 0.0
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		hitbox.disable()
		hitbox.disable_combo()
	print("[HeavyAttack] Attack canceled, cleanup performed")

func _handle_movement(_delta: float) -> void:
	# If movement is locked, don't allow horizontal movement
	if movement_locked:
		player.velocity.x = lerp(player.velocity.x, 0.0, 0.8)  # Gradually stop
		player.move_and_slide()
		return
		
	var input_dir_x = InputManager.get_flattened_axis(&"ui_left", &"ui_right")
	var target_velocity = Vector2(
		input_dir_x * player.speed * ATTACK_SPEED_MULTIPLIER,
		player.velocity.y
	)
	player.velocity.x = lerp(player.velocity.x, target_velocity.x, 1.0 - MOMENTUM_PRESERVATION)
	if input_dir_x != 0:
		player.sprite.flip_h = input_dir_x < 0
	player.move_and_slide()

func _update_hitbox_by_timing() -> void:
	if has_activated_hitbox:
		return
	var length: float = animation_player.current_animation_length
	if length <= 0.0:
		return
	var progress = animation_player.current_animation_position / length
	var hitbox = player.get_node_or_null("Hitbox")
	if not (hitbox and hitbox is PlayerHitbox):
		return
	# heavy: tuned windows per variant based on frame timing
	var window_start := 0.67  # Frame 8/12 for heavy_neutral (8 * 0.067 / 0.8 = 0.67)
	var window_end := 0.75    # Frame 9/12 
	if current_attack == "up_heavy":
		window_start = 0.62   # Frame 8/13 for up_heavy (8 * 0.067 / 0.867 = 0.62)
		window_end = 0.69     # Frame 9/13
	elif current_attack == "down_heavy":
		window_start = 0.42
		window_end = 0.62
	if progress >= window_start and progress <= window_end and not hitbox_enabled:
		hitbox.disable()
		# Priority 1: parry counter window
		var dmg_mult := DAMAGE_MULTIPLIER
		var kb_mult := 1.0
		var kb_up_mult := 1.0
		if player.has_method("is_counter_window_active") and player.is_counter_window_active():
			dmg_mult *= (1.0 + player.counter_damage_bonus)
			kb_mult *= (1.0 + player.counter_knockback_bonus)
			kb_up_mult *= (1.0 + player.counter_knockback_bonus)
			print("[Counter] Heavy counter bonus applied")
			player.consume_counter_window()
		else:
			# Fallback: just-tap timing bonus if enabled
			var use_bonus = just_bonus_ready and just_input_timer > 0.0
			if use_bonus:
				var into_active = (progress - window_start) * animation_player.current_animation_length
				if into_active <= JUST_WINDOW_LENGTH:
					dmg_mult *= JUST_DAMAGE_BONUS
					kb_mult *= JUST_KB_BONUS
					kb_up_mult *= JUST_KB_BONUS
					print("[HeavyAttack] JUST bonus applied!")
					just_bonus_ready = false
		hitbox.enable_combo(current_attack, dmg_mult, kb_mult, kb_up_mult)
		hitbox.enable()
		hitbox_enabled = true
		await get_tree().create_timer(0.18).timeout
		if is_instance_valid(hitbox):
			hitbox.disable()
			hitbox_enabled = false
	_update_hitbox_facing(hitbox)

func _update_hitbox_facing(hitbox: Node2D) -> void:
	var collision_shape = hitbox.get_node("CollisionShape2D")
	if collision_shape:
		var pos = collision_shape.position
		if player.sprite.flip_h:
			pos.x = -abs(pos.x)
		else:
			pos.x = abs(pos.x)
		collision_shape.position = pos

func _on_anim_finished(anim_name: String) -> void:
	if anim_name != current_attack:
		return
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		hitbox.disable()
		hitbox_enabled = false
	var target_state = "Idle"
	if not player.is_on_floor():
		target_state = "Fall"
	elif current_attack == "down_heavy" and _is_player_forced_to_crouch():
		# If we finished down_heavy and player is forced to crouch, return to Crouch
		target_state = "Crouch"
	
	state_machine.transition_to(target_state)

func _on_enemy_hit(_enemy: Node) -> void:
	has_activated_hitbox = true
	if current_attack == "up_heavy":
		allow_jump_cancel = true
		jump_cancel_timer = 0.20

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
			# Ignore enemies (alive or dead) – they must not force crouch when on top of player
			var collider = result.get("collider")
			if collider:
				var parent = collider.get_parent() if collider else null
				if parent and "health" in parent:
					continue  # Ignore any enemy (ceiling check is for world/platform only)
				if "health" in collider:
					continue  # Ignore any enemy
			# If any check hits something that's not an enemy, player is forced to crouch
			return true
	
	return false
