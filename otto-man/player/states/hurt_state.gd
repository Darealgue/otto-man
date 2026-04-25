extends State

const HURT_DURATION := 0.268  # Match animation length exactly
const INVINCIBILITY_DURATION := 1.0  # Time player is invincible after getting hit
const MIN_KNOCKBACK_FORCE := 500.0  # Base minimum knockback force (only used if knockback is present)
const MIN_UP_FORCE := 300.0  # Base minimum upward force (only used if knockback is present)
const KNOCKBACK_MULTIPLIER := 1.0  # Normal multiplier for balanced knockback
const HORIZONTAL_DECAY := 0.3  # Lower value = slower horizontal velocity decay
const VERTICAL_DECAY := 1.0  # Normal gravity for vertical movement
const FALL_TRANSITION_VELOCITY := 35.0
const LETHAL_LAUNCH_FORCE_X := 520.0
const LETHAL_LAUNCH_FORCE_Y := 360.0
const CHARGE_MIN_HORIZONTAL_KNOCKBACK := 560.0
const RECOVERY_CROUCH_DURATION := 0.35
const WALL_STUCK_DROP_SPEED := 240.0
const WALL_PUSHOUT_DISTANCE := 1.5

@export var launch_force_threshold: float = 700.0
@export var launch_up_force_threshold: float = 350.0
@export var launch_combined_threshold: float = 900.0
@export var horizontal_launch_force_threshold: float = 650.0
@export var lie_down_duration: float = 0.45
@export var lethal_lie_death_delay: float = 0.8
@export var lie_slide_speed_threshold: float = 45.0
@export var lie_slide_dust_distance_step: float = 22.0
@export var charge_hurt_duration: float = 0.45
@export var charge_horizontal_decay: float = 0.12
@export var charge_launch_up_force: float = 120.0
@export var charge_horizontal_knockback_multiplier: float = 1.25
@export var debug_knockback_recovery: bool = false
@export var debug_hurt_recovery_crouch: bool = false

var hurt_timer := 0.0
var invincibility_timer := 0.0
var knockback_direction := Vector2.ZERO
var flash_timer := 0.0
const FLASH_INTERVAL := 0.1
var is_red_flash := true  # Track current flash state
var original_flip_h := false
var is_charge_knockback := false  # Track if this is from a charge attack
var has_knockback := false  # Track if this hit should apply knockback at all
var is_launch_hurt := false
var launch_can_air_recover := true
var launch_recover_consumed := false
var launch_lie_timer := 0.0
var lethal_sequence_active := false
var lethal_death_timer := 0.0
var lie_slide_dust_distance_accum := 0.0
var active_hurt_duration := HURT_DURATION
var active_horizontal_decay := HORIZONTAL_DECAY
var transitioned_to_crouch_recovery := false

enum LaunchPhase {
	NONE,
	RISE,
	FALL,
	LIE_DOWN
}

var launch_phase: LaunchPhase = LaunchPhase.NONE

func enter() -> void:
	super.enter()
	
	# Store original facing direction immediately
	# original_flip_h = player.sprite.flip_h # <<< SAKLANABİLİR AMA ZORLAMAYACAĞIZ >>>
	original_flip_h = player.sprite.flip_h # Geçici olarak kalsın, belki başka yerde lazım olur
	
	# Reset attack state
	var attack_state = state_machine.get_node("Attack")
	if attack_state and attack_state.has_method("_reset_attack_state"):
		attack_state._reset_attack_state()
	
	# Always play hurt animation first
	animation_player.stop()  # Stop any current animation
	# Fall attack squash/offset veya kısılmış animasyon sprite'ı kaydırabiliyor; hurt animu position track etmiyor.
	player.reset_sprite_visual_to_default()
	animation_player.play("hurt")
	
	# Start timers
	hurt_timer = HURT_DURATION
	invincibility_timer = INVINCIBILITY_DURATION
	player.invincibility_timer = INVINCIBILITY_DURATION
	flash_timer = 0.0
	is_red_flash = true  # Start with red flash
	launch_lie_timer = 0.0
	launch_phase = LaunchPhase.NONE
	launch_recover_consumed = false
	lethal_sequence_active = false
	lethal_death_timer = 0.0
	lie_slide_dust_distance_accum = 0.0
	active_hurt_duration = HURT_DURATION
	active_horizontal_decay = HORIZONTAL_DECAY
	transitioned_to_crouch_recovery = false
	
	# Get knockback data from the last hit
	var knockback_data = player.last_hit_knockback
	
	# Check if this hit should apply knockback
	has_knockback = knockback_data != null and (knockback_data.get("force", 0.0) > 0.0 or knockback_data.get("up_force", 0.0) > 0.0)
	is_launch_hurt = _should_use_launch_recovery(knockback_data)
	launch_can_air_recover = bool(knockback_data.get("can_air_recover", true)) if knockback_data != null else true
	
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
			# Some charge hitboxes overlap near center and produce tiny dir.x; force a clear horizontal push.
			var horizontal_dir: float = dir.x
			if absf(horizontal_dir) < 0.25:
				horizontal_dir = -sign(to_enemy_dir.x)
			if horizontal_dir == 0.0:
				horizontal_dir = -1.0 if not player.sprite.flip_h else 1.0
			var forced_horizontal = maxf(knockback_force * charge_horizontal_knockback_multiplier, CHARGE_MIN_HORIZONTAL_KNOCKBACK)
			var launch_y := 0.0
			if is_launch_hurt:
				# Heavy charge should still enter rise/fall chain instead of plain hurt.
				launch_y = -charge_launch_up_force
			player.velocity = Vector2(horizontal_dir * forced_horizontal, launch_y)
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
	
	if is_launch_hurt:
		_set_launch_phase(LaunchPhase.RISE)
	elif has_knockback and not is_charge_knockback and player.velocity.y >= -FALL_TRANSITION_VELOCITY:
		_set_launch_phase(LaunchPhase.FALL)
	elif is_charge_knockback:
		# Charge hits should feel like strong ground drag.
		active_hurt_duration = charge_hurt_duration
		active_horizontal_decay = charge_horizontal_decay
		hurt_timer = active_hurt_duration

	# Force the sprite to keep its original direction # <<< BU SATIR KALDIRILDI >>>
	# player.sprite.flip_h = original_flip_h
	
	# Start with red flash and ensure sprite is visible
	player.sprite.visible = true
	player.sprite.modulate = Color(1, 0, 0, 1)
	
	# Apply screen shake when taking damage
	_apply_screen_shake()

	if not animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

	if debug_knockback_recovery:
		print("[Hurt] enter | launch=", is_launch_hurt, " profile=", knockback_data.get("profile", "n/a") if knockback_data else "n/a", " force=", knockback_data.get("force", 0.0) if knockback_data else 0.0, " up=", knockback_data.get("up_force", 0.0) if knockback_data else 0.0)

	if player.get("pending_death") == true:
		begin_lethal_sequence()

func update(delta: float) -> void:
	if not is_launch_hurt:
		return
	if launch_phase == LaunchPhase.RISE or launch_phase == LaunchPhase.FALL:
		_try_air_recover()

func physics_update(delta: float) -> void:
	hurt_timer -= delta
	invincibility_timer -= delta
	player.invincibility_timer = maxf(player.invincibility_timer, invincibility_timer)
	
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
	
	_apply_hurt_movement(delta)
	
	player.apply_move_and_slide()
	_resolve_wall_stuck()
	_update_launch_phase(delta)
	if transitioned_to_crouch_recovery:
		return

	# Launch akışında çıkışı fazlar yönetir.
	if is_launch_hurt:
		return
	if hurt_timer <= 0:
		_finish_hurt_state()

func exit() -> void:
	super.exit()
	
	# Reset knockback and visual effects
	knockback_direction = Vector2.ZERO
	player.sprite.visible = true
	player.sprite.modulate = Color(1, 1, 1, 1)
	player.reset_sprite_visual_to_default()
	
	# Ensure we keep the original facing direction # <<< BU SATIR KALDIRILDI >>>
	# player.sprite.flip_h = original_flip_h
	
	# Keep invincibility timer in player for other states to check
	player.invincibility_timer = invincibility_timer
	launch_phase = LaunchPhase.NONE
	is_launch_hurt = false
	launch_recover_consumed = false
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_finished)

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

func _apply_hurt_movement(delta: float) -> void:
	# Apply different physics based on knockback type
	if has_knockback:
		if is_charge_knockback:
			# Charge knockback yerde yatay gitmeli; havadaysa yercekimi calismali ki kilitlenmesin.
			player.velocity.x = move_toward(player.velocity.x, 0, player.friction * active_horizontal_decay * delta)
			if player.is_on_floor() and not is_launch_hurt:
				player.velocity.y = 0
			else:
				player.velocity.y += player.gravity * VERTICAL_DECAY * delta
		else:
			player.velocity.x = move_toward(player.velocity.x, 0, player.friction * HORIZONTAL_DECAY * delta)
			player.velocity.y += player.gravity * VERTICAL_DECAY * delta
	else:
		player.velocity.y += player.gravity * delta

func _should_use_launch_recovery(knockback_data: Dictionary) -> bool:
	if knockback_data == null:
		return false
	var profile := String(knockback_data.get("profile", "normal")).to_lower()
	if profile == "launch":
		return true
	var force := absf(float(knockback_data.get("force", 0.0)))
	var up_force := absf(float(knockback_data.get("up_force", 0.0)))
	# Heavy charge: allow launch chain even with near-zero vertical force.
	if up_force <= 0.01 and force >= horizontal_launch_force_threshold:
		return true
	return force >= launch_force_threshold or up_force >= launch_up_force_threshold or (force + up_force) >= launch_combined_threshold

func _set_launch_phase(next_phase: LaunchPhase) -> void:
	if launch_phase == next_phase:
		return
	launch_phase = next_phase
	if debug_hurt_recovery_crouch:
		print("[HurtDebug] phase -> ", launch_phase, " vel=", player.velocity, " on_floor=", player.is_on_floor())
	player.reset_sprite_visual_to_default()
	match launch_phase:
		LaunchPhase.RISE:
			if animation_player.has_animation("hurt_rise"):
				animation_player.play("hurt_rise")
			else:
				animation_player.play("hurt")
		LaunchPhase.FALL:
			if animation_player.has_animation("hurt_fall"):
				animation_player.play("hurt_fall")
			else:
				animation_player.play("fall")
		LaunchPhase.LIE_DOWN:
			launch_lie_timer = lie_down_duration
			if lethal_sequence_active:
				lethal_death_timer = lethal_lie_death_delay
			if animation_player.has_animation("lie_down"):
				animation_player.play("lie_down")
		_:
			pass

func _update_launch_phase(delta: float) -> void:
	if not is_launch_hurt:
		return
	match launch_phase:
		LaunchPhase.RISE:
			if player.velocity.y >= -FALL_TRANSITION_VELOCITY:
				_set_launch_phase(LaunchPhase.FALL)
		LaunchPhase.FALL:
			if player.is_on_floor():
				# Keep horizontal carry so lie_slide can trigger on impact skid.
				player.velocity.y = 0.0
				player.spawn_dust_cloud(player.get_foot_position(), "puff_down")
				_set_launch_phase(LaunchPhase.LIE_DOWN)
		LaunchPhase.LIE_DOWN:
			launch_lie_timer -= delta
			_update_lie_slide_animation(delta)
			if debug_hurt_recovery_crouch:
				print("[HurtDebug] LIE tick | lie_timer=", snapped(launch_lie_timer, 0.001), " lethal=", lethal_sequence_active, " lethal_timer=", snapped(lethal_death_timer, 0.001), " vel=", player.velocity, " anim=", animation_player.current_animation)
			if lethal_sequence_active:
				# Death finalization should happen after sliding settles and lie pose is visible.
				if absf(player.velocity.x) < lie_slide_speed_threshold * 0.6:
					lethal_death_timer -= delta
					if lethal_death_timer <= 0.0 and player.has_method("_finalize_player_death"):
						player.call_deferred("_finalize_player_death")
				else:
					# Keep timer parked while still sliding fast.
					lethal_death_timer = maxf(lethal_death_timer, lethal_lie_death_delay)
			elif launch_lie_timer <= 0.0:
				_enter_crouch_recovery()
		_:
			pass

func _try_air_recover() -> void:
	if lethal_sequence_active:
		return
	if launch_recover_consumed:
		return
	if not launch_can_air_recover:
		return
	if not Input.is_action_just_pressed("jump"):
		return
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar and stamina_bar.use_charge():
		launch_recover_consumed = true
		# Force next state to consume and play double jump consistently.
		player.set_meta("force_recovery_double_jump", true)
		player.enable_double_jump()
		player.is_jumping = false
		player.velocity.x *= 0.45
		player.velocity.y = min(player.velocity.y, -player.jump_velocity * 0.2)
		if debug_knockback_recovery:
			print("[Hurt] Air recover success")
		state_machine.transition_to("Jump")
	elif debug_knockback_recovery:
		print("[Hurt] Air recover failed (no stamina)")

func _on_animation_finished(anim_name: String) -> void:
	if not is_launch_hurt:
		return
	if launch_phase == LaunchPhase.LIE_DOWN and anim_name == "lie_down":
		# LieDown için minimum bekleme süresi ayrı timer ile tutuluyor.
		return

func _finish_hurt_state(force_air: bool = false) -> void:
	player.sprite.visible = true
	player.sprite.modulate = Color(1, 1, 1, 1)
	player.attack_cooldown_timer = 0.1
	player.set_meta("hurt_exit_timer", 0.5)
	if force_air:
		state_machine.transition_to("Fall")
		return
	if player.is_on_floor():
		state_machine.transition_to("Idle")
	else:
		state_machine.transition_to("Fall")

func _enter_crouch_recovery() -> void:
	player.sprite.visible = true
	player.sprite.modulate = Color(1, 1, 1, 1)
	player.attack_cooldown_timer = 0.1
	player.set_meta("hurt_exit_timer", 0.5)
	if debug_hurt_recovery_crouch:
		var state_name_before = state_machine.current_state.name if state_machine and state_machine.current_state else "<none>"
		print("[HurtDebug] _enter_crouch_recovery start | state=", state_name_before, " vel=", player.velocity, " on_floor=", player.is_on_floor())
	if lethal_sequence_active and player.has_method("_finalize_player_death"):
		if debug_hurt_recovery_crouch:
			print("[HurtDebug] lethal sequence active -> finalize death deferred")
		player.call_deferred("_finalize_player_death")
		return
	if state_machine.has_node("Crouch"):
		# Reuse normal slide-exit crouch flow for identical timing/feel.
		player.set_meta("hurt_recovery_use_slide_exit", true)
		if debug_hurt_recovery_crouch:
			print("[HurtDebug] set meta hurt_recovery_use_slide_exit=true | current_anim=", animation_player.current_animation, " vel=", player.velocity)
		transitioned_to_crouch_recovery = true
		state_machine.transition_to("Crouch")
		if debug_hurt_recovery_crouch:
			var state_name_after = state_machine.current_state.name if state_machine and state_machine.current_state else "<none>"
			print("[HurtDebug] transitioned to=", state_name_after)
		# Guarantee crouch visual on recovery frame (prevents occasional idle skip).
		if animation_player and animation_player.has_animation("crouch"):
			animation_player.play("crouch")
			if debug_hurt_recovery_crouch:
				print("[HurtDebug] forced animation_player.play('crouch')")
		# Return from hurt should keep combat stance, not normal idle.
		if player.has_method("enter_combat_state"):
			player.enter_combat_state()
			if debug_hurt_recovery_crouch:
				print("[HurtDebug] enter_combat_state called")
	else:
		if debug_hurt_recovery_crouch:
			print("[HurtDebug] Crouch state missing -> fallback _finish_hurt_state")
		_finish_hurt_state()

func begin_lethal_sequence() -> void:
	lethal_sequence_active = true
	is_launch_hurt = true
	launch_can_air_recover = false
	launch_recover_consumed = true
	is_charge_knockback = false
	has_knockback = true
	lethal_death_timer = 0.0

	var launch_dir_x := -1.0 if not player.sprite.flip_h else 1.0
	if player.last_hit_position != Vector2.ZERO:
		var from_hit = (player.global_position - player.last_hit_position).normalized()
		if absf(from_hit.x) > 0.01:
			launch_dir_x = sign(from_hit.x)
	player.velocity = Vector2(launch_dir_x * LETHAL_LAUNCH_FORCE_X, -LETHAL_LAUNCH_FORCE_Y)
	player.enable_double_jump()
	player.is_jumping = false
	_set_launch_phase(LaunchPhase.RISE)

func _resolve_wall_stuck() -> void:
	# Heavy charge / launch sırasında oyuncu duvara itilip havada kilitlenmesin.
	if not player.is_on_wall() or player.is_on_floor():
		return
	var wall_normal: Vector2 = player.get_wall_normal()
	if wall_normal == Vector2.ZERO:
		return
	# If moving into wall, cancel horizontal into-wall velocity.
	if player.velocity.x * wall_normal.x < 0.0:
		player.velocity.x = 0.0
	# Tiny push-out to avoid remaining interpenetration with continuous enemy pressure.
	player.global_position.x += wall_normal.x * WALL_PUSHOUT_DISTANCE
	# Force descent so FALL can eventually reach floor and transition out.
	player.velocity.y = maxf(player.velocity.y, WALL_STUCK_DROP_SPEED)

func _update_lie_slide_animation(delta: float) -> void:
	if not animation_player:
		return
	if not player.is_on_floor():
		return
	var should_slide = absf(player.velocity.x) >= lie_slide_speed_threshold
	if should_slide and animation_player.has_animation("lie_slide"):
		if animation_player.current_animation != "lie_slide":
			animation_player.play("lie_slide")
		lie_slide_dust_distance_accum += absf(player.velocity.x) * delta
		var step := maxf(1.0, lie_slide_dust_distance_step)
		while lie_slide_dust_distance_accum >= step:
			lie_slide_dust_distance_accum -= step
			player.spawn_dust_cloud(player.get_foot_position(), "puff_down")
	else:
		lie_slide_dust_distance_accum = 0.0
		if animation_player.current_animation != "lie_down" and animation_player.has_animation("lie_down"):
			animation_player.play("lie_down")
