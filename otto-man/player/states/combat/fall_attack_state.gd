extends State

const AttackConfigClass = preload("res://autoload/attack_config.gd")

var attack_config_instance: Node
var hitbox_enabled := false
var has_hit_ground := false
var is_bouncing := false

func _ready():
	await owner.ready
	attack_config_instance = AttackConfigClass.new()

func enter() -> void:
	# Get attack configuration with player's damage multiplier
	var config = attack_config_instance.get_attack_config(AttackConfigClass.AttackType.FALL, player.damage_multiplier)
	
	# Set up hitbox
	var hitbox = player.get_node_or_null("FallAttack")
	if hitbox:
		hitbox.damage = config.damage
		hitbox.knockback_force = config.knockback_force
		hitbox.knockback_up_force = config.knockback_up_force
		hitbox_enabled = true
	
	# Start fall attack animation
	animation_player.play("fall_attack")
	
	# Apply downward velocity for the attack
	player.velocity.y = 600.0  # Fast downward strike
	has_hit_ground = false
	is_bouncing = false

func physics_update(delta: float):
	if not is_bouncing:
		# Keep applying downward force until we hit something
		player.velocity.y = minf(player.velocity.y + player.gravity * delta, 600.0)
	
	player.move_and_slide()
	
	# Check for ground collision
	if player.is_on_floor() and not has_hit_ground:
		_handle_ground_impact()
	
	# Allow horizontal movement during fall
	var input_dir = Input.get_axis("left", "right")
	if input_dir != 0:
		player.velocity.x = move_toward(player.velocity.x, player.speed * 0.5 * input_dir, player.acceleration * delta)
		player.sprite.flip_h = input_dir < 0

func _handle_ground_impact():
	has_hit_ground = true
	var config = attack_config_instance.get_attack_config(AttackConfigClass.AttackType.FALL)
	
	# Create ground impact effect if enabled
	if config.effects.ground_impact:
		_create_impact_effect()
	
	# Screen shake if enabled
	if config.effects.screen_shake:
		_apply_screen_shake()
	
	# Bounce up if enabled
	if config.effects.bounce_up:
		is_bouncing = true
		player.velocity.y = -config.effects.bounce_force
	
	# Disable hitbox
	var hitbox = player.get_node_or_null("FallAttack")
	if hitbox:
		hitbox.disable()
		hitbox_enabled = false
	
	# Transition to fall state after bounce
	await get_tree().create_timer(0.2).timeout
	state_machine.transition_to("Fall")

func _create_impact_effect():
	# TODO: Implement impact effect (particles, animation, etc.)
	pass

func _apply_screen_shake():
	# TODO: Implement screen shake effect
	pass

func exit():
	# Ensure hitbox is disabled
	var hitbox = player.get_node_or_null("FallAttack")
	if hitbox:
		hitbox.disable()
		hitbox_enabled = false 