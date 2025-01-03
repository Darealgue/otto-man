extends State

const DASH_SPEED := 2500.0
const DASH_DURATION := 0.1
const DASH_COOLDOWN := 3.0
const DASH_END_SPEED_MULTIPLIER := 0.3  # Player will retain 30% of dash speed when ending
var dash_timer := 0.0
var cooldown_timer := 0.0
var can_dash := true
var original_collision_mask := 0  # Store original collision mask
var original_collision_layer := 0  # Store original collision layer

func enter():
	# Store original collision settings
	original_collision_mask = player.collision_mask
	original_collision_layer = player.collision_layer
	
	# Disable enemy collision (layer 3)
	player.collision_mask &= ~(1 << 2)  # Remove enemy collision mask (layer 3)
	player.collision_layer &= ~(1 << 2)  # Remove enemy collision layer (layer 3)
	
	# Start dash
	dash_timer = DASH_DURATION
	cooldown_timer = DASH_COOLDOWN
	can_dash = false
	animation_player.play("dash")
	
	# Set initial dash velocity based on facing direction
	var dash_direction = -1 if player.sprite.flip_h else 1
	player.velocity.x = DASH_SPEED * dash_direction
	player.velocity.y = 0

func physics_update(delta: float):
	dash_timer -= delta
	
	if dash_timer <= 0:
		# Reduce speed when ending dash to prevent excessive drift
		player.velocity.x *= DASH_END_SPEED_MULTIPLIER
		# Restore collision settings and end dash
		player.collision_mask = original_collision_mask
		player.collision_layer = original_collision_layer
		state_machine.transition_to("Fall")
		return
	
	player.move_and_slide()

func exit():
	# Ensure collision settings are restored when exiting state
	player.collision_mask = original_collision_mask
	player.collision_layer = original_collision_layer

func cooldown_update(delta: float):
	if not can_dash:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_dash = true
			cooldown_timer = 0.0
			# Flash yellow when dash is ready
			var tween = player.sprite.create_tween()
			tween.tween_property(player.sprite, "modulate", Color(1.5, 1.5, 0.5), 0.1)
			tween.tween_property(player.sprite, "modulate", Color(1, 1, 1), 0.1)

func can_start_dash() -> bool:
	# Only allow dash when on ground
	return can_dash and player.is_on_floor() 