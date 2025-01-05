extends State

const FALL_ATTACK_SPEED := 1200.0
const BOUNCE_VELOCITY := -1000.0
const ATTACK_DAMAGE := 20.0
const ATTACK_KNOCKBACK := 200.0
const ATTACK_UP_FORCE := 300.0
const IMPACT_SQUASH_SCALE := Vector2(1.3, 0.7)
const IMPACT_DURATION := 0.15
const IMPACT_OFFSET := Vector2(0, 16)
const COOLDOWN_DURATION := 0.4

static var cooldown_timer := 0.0

var has_hit_enemy := false
var is_impacting := false
var impact_timer := 0.0
var original_sprite_position := Vector2.ZERO

static func is_on_cooldown() -> bool:
	return cooldown_timer > 0.0

static func update_cooldown(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer = max(0.0, cooldown_timer - delta)
		if OS.is_debug_build():
			print("[FallAttackState] Cooldown remaining:", cooldown_timer)

func enter():
	if OS.is_debug_build():
		print("[FallAttackState] Entering Fall Attack State")
	
	# Start cooldown
	cooldown_timer = COOLDOWN_DURATION
	
	# Reset flags and timer
	has_hit_enemy = false
	is_impacting = false
	impact_timer = 0.0
	original_sprite_position = player.sprite.position
	player.sprite.scale = Vector2.ONE
	player.sprite.position = original_sprite_position
	
	# Stop any current animation
	animation_player.stop()
	
	# Set up fall attack hitbox
	var fall_attack_hitbox = player.get_node("FallAttack")
	if fall_attack_hitbox:
		if OS.is_debug_build():
			print("[FallAttackState] Setting up fall attack hitbox")
		
		# Set hitbox properties
		fall_attack_hitbox.damage = ATTACK_DAMAGE
		fall_attack_hitbox.knockback_force = ATTACK_KNOCKBACK
		fall_attack_hitbox.knockback_up_force = ATTACK_UP_FORCE
		
		# Enable the hitbox using its enable() function
		fall_attack_hitbox.enable()
		
		if OS.is_debug_build():
			print("[FallAttackState] Fall attack hitbox enabled")
		
		# Connect to hit signal if not already connected
		if not fall_attack_hitbox.is_connected("area_entered", _on_hitbox_area_entered):
			fall_attack_hitbox.connect("area_entered", _on_hitbox_area_entered)
	
	# Connect to animation finished if not already connected
	if not animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.connect("animation_finished", _on_animation_finished)
	
	# Immediately set velocity and play fall attack animation
	player.velocity.y = FALL_ATTACK_SPEED
	animation_player.play("fall_attack")

func exit():
	if OS.is_debug_build():
		print("[FallAttackState] Exiting Fall Attack State")
	
	# Reset sprite scale and position
	player.sprite.scale = Vector2.ONE
	player.sprite.position = original_sprite_position
	is_impacting = false
	impact_timer = 0.0
	
	# Disable fall attack hitbox
	var fall_attack_hitbox = player.get_node("FallAttack")
	if fall_attack_hitbox:
		fall_attack_hitbox.disable()
		if OS.is_debug_build():
			print("[FallAttackState] Disabled fall attack hitbox")
		
		# Disconnect signals if connected
		if fall_attack_hitbox.is_connected("area_entered", _on_hitbox_area_entered):
			fall_attack_hitbox.disconnect("area_entered", _on_hitbox_area_entered)
	
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.disconnect("animation_finished", _on_animation_finished)

func physics_update(delta: float):
	# Keep downward velocity constant during fall attack
	if not has_hit_enemy and not is_impacting:
		player.velocity.y = FALL_ATTACK_SPEED
	
	# Handle horizontal movement
	var input_dir = Input.get_axis("left", "right")
	if input_dir != 0 and not is_impacting:
		player.velocity.x = move_toward(player.velocity.x, input_dir * player.speed * 0.5, player.acceleration * delta)
		player.sprite.flip_h = input_dir < 0
	else:
		player.apply_friction(delta)
	
	player.move_and_slide()
	
	# Handle impact animation
	if is_impacting:
		impact_timer += delta
		var t = impact_timer / IMPACT_DURATION
		if t >= 1.0:
			is_impacting = false
			player.sprite.scale = Vector2.ONE
			player.sprite.position = original_sprite_position
		else:
			# Interpolate scale and position for smooth animation
			var progress = 1.0 - (t * t)  # Quadratic easing
			player.sprite.scale = Vector2.ONE.lerp(IMPACT_SQUASH_SCALE, progress)
			player.sprite.position = original_sprite_position.lerp(original_sprite_position + IMPACT_OFFSET, progress)
	# Check for landing
	elif player.is_on_floor() and not has_hit_enemy:
		if OS.is_debug_build():
			print("[FallAttackState] Landing detected, starting impact animation")
		is_impacting = true
		impact_timer = 0.0
		player.sprite.scale = IMPACT_SQUASH_SCALE
		player.sprite.position = original_sprite_position + IMPACT_OFFSET
		animation_player.play("landing")  # Play landing animation

func _on_animation_finished(anim_name: String):
	if anim_name == "landing" and is_impacting:
		if OS.is_debug_build():
			print("[FallAttackState] Landing animation finished")
		state_machine.transition_to("Idle")

func _on_hitbox_area_entered(area: Area2D):
	if OS.is_debug_build():
		print("[FallAttackState] Hitbox entered area:", area.name)
	if area.is_in_group("hurtbox") and not has_hit_enemy:
		if OS.is_debug_build():
			print("[FallAttackState] Hit enemy! Bouncing with velocity:", BOUNCE_VELOCITY)
		has_hit_enemy = true
		player.velocity.y = BOUNCE_VELOCITY  # Bounce off enemy
		animation_player.play("jump_upwards")  # Transition to jump animation
		state_machine.transition_to("Fall")  # Switch to fall state after bounce 
