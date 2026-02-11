extends "../state.gd"

const CEILING_CHECK_OFFSET := 44.0  # Height to check for ceiling (should match player's standing height)
const CROUCH_HEIGHT_RATIO := 0.5  # How much to reduce height during crouch
const CRAWL_SPEED := 150.0  # Speed while crawling
const MIN_SPEED_TO_SLIDE := 200.0  # Minimum speed required to initiate a slide
const POST_SLIDE_CROUCH_DURATION := 0.1  # Duration to stay crouched after slide
const POST_LEDGEGRAB_CROUCH_DURATION := 0.1  # Duration to stay crouched after ledgegrab

var original_height: float = 44.0  # Actual height from scene
var original_position_y: float = -22.0  # Actual position from scene
var original_hurtbox_height: float = 44.0  # Actual hurtbox height from scene
var original_hurtbox_position_y: float = -22.0  # Actual hurtbox position from scene
var has_initialized := false
var entered_from_slide := false  # Track if we entered from slide state
var post_slide_timer := 0.0  # Timer for post-slide crouch duration
var post_ledgegrab_timer := 0.0  # Timer for post-ledgegrab crouch duration
var entered_from_ledgegrab := false  # Track if we entered from ledgegrab
var floor_grace_timer := 0.0  # small grace to avoid immediate fall after teleport

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
	
	# Check if we're entering from ledgegrab (directly or via jump)
	entered_from_ledgegrab = (state_machine.previous_state.name == "Jump" and player.ledge_grab_cooldown_timer > 0) or state_machine.previous_state.name == "LedgeGrab"
	
	# Debug prints disabled to reduce console spam
	# print("[Crouch] Entering from state: ", state_machine.previous_state.name)
	# print("[Crouch] Entered from slide: ", entered_from_slide)
	# print("[Crouch] Entered from ledgegrab: ", entered_from_ledgegrab)
	# print("[Crouch] Ledgegrab cooldown timer: ", player.ledge_grab_cooldown_timer)
	
	# Reset post-slide timer if entering from slide
	if entered_from_slide:
		post_slide_timer = max(post_slide_timer, POST_SLIDE_CROUCH_DURATION)
		
	# Reset post-ledgegrab timer if entering from ledgegrab
	if entered_from_ledgegrab:
		post_ledgegrab_timer = max(post_ledgegrab_timer, POST_LEDGEGRAB_CROUCH_DURATION)
		
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
		
		# Simple physics update to ensure proper collision detection
		player.move_and_slide()
		

func can_stand_up() -> bool:
	if !player:
		return false
		
	# Get the space state for raycasting
	var space_state = player.get_world_2d().direct_space_state
	
	# Check multiple points around the player's collision shape to ensure no overlap
	var check_points = [
		Vector2.UP * original_height,  # Top center
		Vector2.UP * original_height + Vector2.LEFT * 2,  # Top left (reduced to 2 pixels)
		Vector2.UP * original_height + Vector2.RIGHT * 2,  # Top right (reduced to 2 pixels)
		Vector2.LEFT * 2,  # Left side (reduced to 2 pixels)
		Vector2.RIGHT * 2,  # Right side (reduced to 2 pixels)
		Vector2.UP * original_height + Vector2.LEFT * 2,  # Top left corner (reduced to 2 pixels)
		Vector2.UP * original_height + Vector2.RIGHT * 2   # Top right corner (reduced to 2 pixels)
	]
	
	for check in check_points:
		var query = PhysicsRayQueryParameters2D.new()
		query.from = player.global_position
		query.to = player.global_position + check
		query.exclude = [player]
		
		var result = space_state.intersect_ray(query)
		if result:
			# Check if the hit object is a dead enemy - if so, ignore it
			var collider = result.get("collider")
			if collider:
				# Check if collider is part of a dead enemy
				var parent = collider.get_parent() if collider else null
				if parent and "health" in parent:
					if parent.health <= 0:
						continue  # Ignore dead enemies
				# Also check if collider itself is a dead enemy (CharacterBody2D)
				elif "health" in collider:
					if collider.health <= 0:
						continue  # Ignore dead enemies
			# If any check hits something (that's not a dead enemy), we can't stand up
			return false
	
	# If all checks pass, we can stand up
	return true

func physics_update(delta: float):
	if !player:
		return
		
	# Update post-slide timer
	if post_slide_timer > 0:
		post_slide_timer -= delta
		
	# Update post-ledgegrab timer
	if post_ledgegrab_timer > 0:
		post_ledgegrab_timer -= delta
	
	# Update floor grace timer
	if floor_grace_timer > 0:
		floor_grace_timer -= delta
		
	# Apply gravity
	player.velocity.y += player.gravity * delta
	
	# Get movement input
	var input_dir = InputManager.get_flattened_axis(&"left", &"right")
	
	# If ceiling blocks standing, keep collider forced to crouch size (safety)
	var head_blocked := not can_stand_up()
	if head_blocked:
		apply_crouch_shape_now()
		# Optional debug
		# print("[Crouch] Keeping crouch collider due to ceiling.")
	
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
	if floor_grace_timer <= 0 and not player.is_on_floor():
		state_machine.transition_to("Fall")
		return
		
	# Check for attack input while crouched (enables down_light)
	if Input.is_action_just_pressed("attack"):
		# Debug print disabled to reduce console spam
		# print("[Crouch] Attack pressed while crouched, transitioning to Attack for down_light")
		state_machine.transition_to("Attack")
		return
		
	# Disable jumping while crouched to prevent jams in tight tunnels
	if Input.is_action_just_pressed("jump"):
		# Debug print disabled to reduce console spam  
		# print("[Crouch] Jump pressed while crouched. Suppressed. can_stand_up=", can_stand_up(), " post_ledgegrab_timer=", post_ledgegrab_timer, " floor_grace=", floor_grace_timer)
		return
		
	# Check if we should stand up
	# Don't allow standing up during post-slide or post-ledgegrab crouch periods
	var can_stand := can_stand_up()
	if not Input.is_action_pressed("crouch") and can_stand and post_slide_timer <= 0 and post_ledgegrab_timer <= 0:
		# Debug print disabled to reduce console spam
		# print("[Crouch] Standing up to Idle. can_stand=", can_stand, " timers slide=", post_slide_timer, " ledge=", post_ledgegrab_timer)
		state_machine.transition_to("Idle")
		return
	else:
		if not Input.is_action_pressed("crouch") and not can_stand:
			# Debug print disabled to reduce console spam - this can happen frequently
			# Only log occasionally to avoid spam
			pass # print("[Crouch] Stand blocked: ceiling present. can_stand=", can_stand)
	
	player.move_and_slide() 

func force_crouch(duration: float) -> void:
	# Extend crouch hold time (used by LedgeGrab mount)
	entered_from_ledgegrab = true
	post_ledgegrab_timer = max(post_ledgegrab_timer, duration)
	floor_grace_timer = max(floor_grace_timer, 0.1)
	# Ensure we are visually crouching
	if animation_player and animation_player.current_animation != "crouch":
		animation_player.play("crouch") 

func apply_crouch_shape_now() -> void:
	# Immediately apply crouch-sized collider/hurtbox without state transition
	if !player:
		return
	var collision_shape = player.get_node("CollisionShape2D")
	var hurtbox_shape = player.get_node("Hurtbox/CollisionShape2D")
	if collision_shape and collision_shape.shape is CapsuleShape2D and hurtbox_shape and hurtbox_shape.shape is CapsuleShape2D:
		if !has_initialized:
			original_height = collision_shape.shape.height
			original_position_y = collision_shape.position.y
			original_hurtbox_height = hurtbox_shape.shape.height
			original_hurtbox_position_y = hurtbox_shape.position.y
			has_initialized = true
		var new_height = original_height * CROUCH_HEIGHT_RATIO
		var new_hurtbox_height = original_hurtbox_height * CROUCH_HEIGHT_RATIO
		collision_shape.shape.height = new_height
		collision_shape.position.y = original_position_y + (original_height - new_height) * 0.5
		hurtbox_shape.shape.height = new_hurtbox_height
		hurtbox_shape.position.y = original_hurtbox_position_y + (original_hurtbox_height - new_hurtbox_height) * 0.5 
