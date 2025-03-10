extends "../state.gd"

const CEILING_CHECK_OFFSET := 44.0  # Height to check for ceiling (should match player's standing height)
const CROUCH_HEIGHT_RATIO := 0.5  # How much to reduce height during crouch
const CRAWL_SPEED := 150.0  # Speed while crawling
const MIN_SPEED_TO_SLIDE := 200.0  # Minimum speed required to initiate a slide

var original_height: float = 44.0  # Actual height from scene
var original_position_y: float = -22.0  # Actual position from scene
var original_hurtbox_height: float = 44.0  # Actual hurtbox height from scene
var original_hurtbox_position_y: float = -22.0  # Actual hurtbox position from scene
var has_initialized := false
var entered_from_slide := false  # Track if we entered from slide state

func _ready() -> void:
	# Initialize dimensions when the state is ready
	if player:
		var collision_shape = player.get_node("CollisionShape2D")
		var hurtbox_shape = player.get_node("Hurtbox/CollisionShape2D")
		
		if collision_shape and collision_shape.shape is CapsuleShape2D and hurtbox_shape and hurtbox_shape.shape is CapsuleShape2D:
			original_height = collision_shape.shape.height
			original_position_y = collision_shape.position.y
			original_hurtbox_height = hurtbox_shape.shape.height
			original_hurtbox_position_y = hurtbox_shape.position.y
			has_initialized = true

func enter():
	if !player:
		return
		
	# Check if we're entering from slide state
	entered_from_slide = state_machine.previous_state.name == "Slide"
		
	# Initialize dimensions if not done yet
	var collision_shape = player.get_node("CollisionShape2D")
	var hurtbox_shape = player.get_node("Hurtbox/CollisionShape2D")
	
	if collision_shape and collision_shape.shape is CapsuleShape2D and hurtbox_shape and hurtbox_shape.shape is CapsuleShape2D:

		if !has_initialized:
			original_height = collision_shape.shape.height
			original_position_y = collision_shape.position.y
			original_hurtbox_height = hurtbox_shape.shape.height
			original_hurtbox_position_y = hurtbox_shape.position.y
			has_initialized = true
		
		# Calculate new heights for crouching
		var new_height = original_height * CROUCH_HEIGHT_RATIO
		var new_hurtbox_height = original_hurtbox_height * CROUCH_HEIGHT_RATIO
		
		# Reduce heights and adjust positions to keep bottom at same level
		collision_shape.shape.height = new_height
		collision_shape.position.y = original_position_y + (original_height - new_height) * 0.5
		
		hurtbox_shape.shape.height = new_hurtbox_height
		hurtbox_shape.position.y = original_hurtbox_position_y + (original_hurtbox_height - new_hurtbox_height) * 0.5
		
	
	# Play initial crouch animation
	animation_player.play("crouch")

func exit():
	if !player:
		return
		
	# Restore original collision shape and hurtbox height and position
	var collision_shape = player.get_node("CollisionShape2D")
	var hurtbox_shape = player.get_node("Hurtbox/CollisionShape2D")
	
	if collision_shape and collision_shape.shape is CapsuleShape2D and hurtbox_shape and hurtbox_shape.shape is CapsuleShape2D:
		
		# Restore original dimensions
		collision_shape.shape.height = original_height
		collision_shape.position.y = original_position_y
		
		hurtbox_shape.shape.height = original_hurtbox_height
		hurtbox_shape.position.y = original_hurtbox_position_y
		

func can_stand_up() -> bool:
	if !player:
		return false
		
	# Get the space state for raycasting
	var space_state = player.get_world_2d().direct_space_state
	
	# Create parameters for the raycast
	var query = PhysicsRayQueryParameters2D.new()
	query.from = player.global_position
	query.to = player.global_position + Vector2.UP * CEILING_CHECK_OFFSET
	query.exclude = [player]
	
	# Perform the raycast
	var result = space_state.intersect_ray(query)
	
	# If there's no collision, we can stand up
	var can_stand = !result
	return can_stand

func physics_update(delta: float):
	if !player:
		return
		
	# Apply gravity
	player.velocity.y += player.gravity * delta
	
	# Get movement input
	var input_dir = Input.get_axis("left", "right")
	
	# Handle movement and animation
	if input_dir != 0:
		# Set immediate velocity for crawling
		player.velocity.x = input_dir * CRAWL_SPEED
		
		# Check if we should transition to slide
		if not entered_from_slide and (abs(player.velocity.x) >= MIN_SPEED_TO_SLIDE or state_machine.previous_state.name == "Run"):
			state_machine.transition_to("Slide")
			return
			
		# Play crawl animation if moving
		if animation_player.current_animation != "crawl":
			animation_player.play("crawl")
	else:
		# Stop immediately when no input
		player.velocity.x = 0
		# Return to crouch animation if not moving
		if animation_player.current_animation != "crouch":
			animation_player.play("crouch")
	
	
	# Check for state transitions
	if not player.is_on_floor():
		state_machine.transition_to("Fall")
		return
		
	if Input.is_action_just_pressed("jump"):
		state_machine.transition_to("Jump")
		return
		
	# Check if we should stand up
	if not Input.is_action_pressed("crouch") and can_stand_up():
		state_machine.transition_to("Idle")
		return
	
	player.move_and_slide() 
