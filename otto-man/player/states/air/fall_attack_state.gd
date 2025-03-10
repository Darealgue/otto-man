extends State

const FALL_ATTACK_SPEED := 1200.0
const BOUNCE_VELOCITY := -1000.0
const ATTACK_KNOCKBACK := 200.0
const ATTACK_UP_FORCE := 300.0
const IMPACT_SQUASH_SCALE := Vector2(1.3, 0.7)
const IMPACT_DURATION := 0.15
const IMPACT_OFFSET := Vector2(0, 16)
const COOLDOWN_DURATION := 0.2  # Reduced cooldown duration

static var cooldown_timer := 0.0
static var was_double_jumping := false

var has_hit_enemy := false
var is_impacting := false
var impact_timer := 0.0
var original_sprite_position := Vector2.ZERO
var hitbox_enabled := false

static func is_on_cooldown() -> bool:
	# Only check cooldown if we weren't double jumping
	if was_double_jumping:
		return false
	return cooldown_timer > 0.0

static func update_cooldown(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer = max(0.0, cooldown_timer - delta)

static func reset_cooldown() -> void:
	cooldown_timer = COOLDOWN_DURATION

static func set_was_double_jumping(value: bool) -> void:
	was_double_jumping = value

func enter():
	
	# Reset flags and state
	has_hit_enemy = false
	is_impacting = false
	impact_timer = 0.0
	hitbox_enabled = false
	
	# Reset sprite position and scale
	original_sprite_position = player.sprite.position
	player.sprite.scale = Vector2.ONE
	player.sprite.position = original_sprite_position
	
	# Stop any current animation and play fall attack
	animation_player.stop()
	animation_player.play("fall_attack")
	
	# Set up fall attack hitbox
	var fall_attack_hitbox = player.get_node_or_null("FallAttack")
	if fall_attack_hitbox and fall_attack_hitbox is PlayerHitbox:
		# Connect to hitbox signals if not already connected
		if not fall_attack_hitbox.is_connected("area_entered", _on_hitbox_area_entered):
			fall_attack_hitbox.area_entered.connect(_on_hitbox_area_entered)
		
		# Set hitbox properties
		var fall_damage = PlayerStats.get_fall_attack_damage()
		fall_attack_hitbox.damage = fall_damage
		fall_attack_hitbox.knockback_force = ATTACK_KNOCKBACK
		fall_attack_hitbox.knockback_up_force = ATTACK_UP_FORCE
		
		# Enable the hitbox
		fall_attack_hitbox.enable_combo("fall_attack", 1.0)
		fall_attack_hitbox.enable()
		hitbox_enabled = true
	
	# Set initial fall attack velocity
	player.velocity.y = FALL_ATTACK_SPEED
	
	# Reset double jump tracking
	was_double_jumping = false

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

func start_impact():
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

func physics_update(delta: float):
	# Keep fall attack velocity constant unless impacting
	if not is_impacting:
		player.velocity.y = FALL_ATTACK_SPEED
	
	# Handle impact state
	if is_impacting:
		impact_timer += delta
		if impact_timer >= IMPACT_DURATION:
			state_machine.transition_to("Fall")
			return
	
	# Check for landing
	if player.is_on_floor() and not is_impacting:
		start_impact()
		return
	
	# Move the player
	player.move_and_slide()
	
	# Update cooldown
	update_cooldown(delta)

func _on_animation_finished(anim_name: String):
	if anim_name == "landing" and is_impacting:
		state_machine.transition_to("Idle")

func _on_hitbox_area_entered(area: Area2D):
	if area.is_in_group("hurtbox") and not has_hit_enemy:
		has_hit_enemy = true
		player.velocity.y = BOUNCE_VELOCITY
		start_impact()
