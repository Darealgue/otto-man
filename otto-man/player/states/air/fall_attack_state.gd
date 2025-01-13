extends State

const FALL_ATTACK_SPEED := 1200.0
const BOUNCE_VELOCITY := -1000.0
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
var hitbox_enabled := false

static func is_on_cooldown() -> bool:
	return cooldown_timer > 0.0

static func update_cooldown(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer = max(0.0, cooldown_timer - delta)

func enter():
	# Start cooldown
	cooldown_timer = COOLDOWN_DURATION
	
	# Reset flags and timer
	has_hit_enemy = false
	is_impacting = false
	impact_timer = 0.0
	hitbox_enabled = false
	original_sprite_position = player.sprite.position
	player.sprite.scale = Vector2.ONE
	player.sprite.position = original_sprite_position
	
	# Stop any current animation
	animation_player.stop()
	
	# Set up fall attack hitbox
	var fall_attack_hitbox = player.get_node_or_null("FallAttack")
	if fall_attack_hitbox and fall_attack_hitbox is PlayerHitbox:
		# Connect to hitbox signals
		if not fall_attack_hitbox.is_connected("area_entered", _on_hitbox_area_entered):
			fall_attack_hitbox.area_entered.connect(_on_hitbox_area_entered)
		
		# Set hitbox properties using fall attack damage from PlayerStats
		var fall_damage = PlayerStats.get_fall_attack_damage()
		print("[DEBUG] Fall Attack - Setting damage to: ", fall_damage)
		fall_attack_hitbox.damage = fall_damage
		fall_attack_hitbox.knockback_force = ATTACK_KNOCKBACK
		fall_attack_hitbox.knockback_up_force = ATTACK_UP_FORCE
		
		# Enable the hitbox
		fall_attack_hitbox.enable_combo("fall_attack", 1.0)
		fall_attack_hitbox.enable()
		hitbox_enabled = true
	else:
		push_error("[FallAttackState] Could not find FallAttack hitbox!")
	
	# Immediately set velocity and play fall attack animation
	player.velocity.y = FALL_ATTACK_SPEED
	animation_player.play("fall_attack")

func exit():
	# Reset sprite scale and position
	player.sprite.scale = Vector2.ONE
	player.sprite.position = original_sprite_position
	is_impacting = false
	impact_timer = 0.0
	
	# Disable fall attack hitbox and disconnect signals
	var fall_attack_hitbox = player.get_node_or_null("FallAttack")
	if fall_attack_hitbox and fall_attack_hitbox is PlayerHitbox:
		if fall_attack_hitbox.is_connected("area_entered", _on_hitbox_area_entered):
			fall_attack_hitbox.area_entered.disconnect(_on_hitbox_area_entered)
		fall_attack_hitbox.disable()
		fall_attack_hitbox.disable_combo()
		hitbox_enabled = false

func physics_update(delta: float):
	# Keep downward velocity constant during fall attack
	if not has_hit_enemy and not is_impacting:
		player.velocity.y = FALL_ATTACK_SPEED
	
	# Handle horizontal movement
	var input_dir = Input.get_axis("left", "right")
	if input_dir != 0 and not is_impacting:
		player.velocity.x = move_toward(player.velocity.x, input_dir * player.speed * 0.5, player.acceleration * delta)
		player.sprite.flip_h = input_dir < 0
		
		# Update fall attack hitbox direction
		var fall_attack_hitbox = player.get_node_or_null("FallAttack")
		if fall_attack_hitbox and fall_attack_hitbox is PlayerHitbox and hitbox_enabled:
			var collision_shape = fall_attack_hitbox.get_node("CollisionShape2D")
			if collision_shape:
				var position = collision_shape.position
				position.x = abs(position.x) * (-1 if player.sprite.flip_h else 1)
				collision_shape.position = position
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
		is_impacting = true
		impact_timer = 0.0
		player.sprite.scale = IMPACT_SQUASH_SCALE
		player.sprite.position = original_sprite_position + IMPACT_OFFSET
		
		# Disable hitbox on impact
		var fall_attack_hitbox = player.get_node_or_null("FallAttack")
		if fall_attack_hitbox and fall_attack_hitbox is PlayerHitbox:
			fall_attack_hitbox.disable()
			fall_attack_hitbox.disable_combo()
			hitbox_enabled = false
		
		animation_player.play("landing")

func _on_animation_finished(anim_name: String):
	if anim_name == "landing" and is_impacting:
		state_machine.transition_to("Idle")

func _on_hitbox_area_entered(area: Area2D):
	print("[DEBUG] Fall Attack - Area entered: ", area.name, " Groups: ", area.get_groups())
	print("[DEBUG] Fall Attack - Area class: ", area.get_class(), " Parent: ", area.get_parent().name if area.get_parent() else "None")
	print("[DEBUG] Fall Attack - Current damage: ", PlayerStats.get_fall_attack_damage())
	
	# Case-insensitive check for hurtbox group
	var is_in_hurtbox_group = false
	for group in area.get_groups():
		if group.to_lower() == "hurtbox":
			is_in_hurtbox_group = true
			break
	
	if (is_in_hurtbox_group or area.name.to_lower() == "hurtbox") and not has_hit_enemy:
		print("[DEBUG] Fall Attack - Hit valid hurtbox, attempting bounce")
		has_hit_enemy = true
		
		# Disable hitbox after hitting enemy
		var fall_attack_hitbox = player.get_node_or_null("FallAttack")
		if fall_attack_hitbox and fall_attack_hitbox is PlayerHitbox:
			print("[DEBUG] Fall Attack - Hitbox damage: ", fall_attack_hitbox.damage)
			fall_attack_hitbox.disable()
			fall_attack_hitbox.disable_combo()
			hitbox_enabled = false
		
		print("[DEBUG] Fall Attack - Applying bounce velocity: ", BOUNCE_VELOCITY)
		player.velocity.y = BOUNCE_VELOCITY  # Bounce off enemy
		player.enable_double_jump()  # Enable double jump after bounce
		animation_player.play("jump_upwards")  # Play jump animation when bouncing
		state_machine.transition_to("Fall")  # Switch to fall state after bounce 
