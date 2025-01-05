extends State

const AttackConfigClass = preload("res://autoload/attack_config.gd")

var attack_config_instance: Node
var current_attack_type = AttackConfigClass.AttackType.LIGHT
var combo_count := 0
var combo_window_timer := 0.0
var attack_cooldown_timer := 0.0
const COMBO_WINDOW := 0.8  # Increased from 0.5 to give more time for next input
const ATTACK_COOLDOWN := 0.1  # Reduced from 0.2 to make attacks more responsive
const INPUT_BUFFER_TIME := 0.2  # Time window to buffer the next attack input

# Track which frames should enable/disable hitbox for each attack
const ATTACK_FRAMES = {
	"light_attack1": {"enable": 2, "disable": 4},  # Enable on frame 2, disable on frame 4
	"light_attack2": {"enable": 4, "disable": 8},  # Adjusted to match the swing animation frames (frames 7-8)
	"light_attack3": {"enable": 4, "disable": 7}   # Enable during the strong swing
}

# Minimum animation progress required before allowing next combo (0.0 to 1.0)
const MIN_COMBO_PROGRESS = {
	"light_attack1": 0.6,  # 60% through the animation
	"light_attack2": 0.7,  # 70% through the animation
	"light_attack3": 0.8   # 80% through the animation
}

var current_attack_name := ""
var hitbox_enabled := false
var can_attack := true
var original_hitbox_position: Vector2
var buffered_attack := false
var buffer_timer := 0.0

func _ready():
	# Wait for player node to be ready
	await owner.ready
	
	attack_config_instance = AttackConfigClass.new()
	
	# Store original hitbox position if hitbox exists
	if player and player.has_node("Hitbox") and player.get_node("Hitbox").has_node("CollisionShape2D"):
		original_hitbox_position = player.get_node("Hitbox").get_node("CollisionShape2D").position
	else:
		push_error("[AttackState] Could not find hitbox or its collision shape")
	
	# Reset attack state when node is ready
	_reset_attack_state()

func enter():
	if not can_attack:
		state_machine.transition_to("Idle")
		return
		
	
	if animation_tree:
		animation_tree.active = true
		animation_tree.set("parameters/conditions/movement_to_combat", true)
	
	player.velocity.x = 0
	hitbox_enabled = false
	can_attack = false  # Start cooldown
	attack_cooldown_timer = ATTACK_COOLDOWN
	
	# Get attack configuration
	var config = attack_config_instance.get_attack_config(current_attack_type)
	
	# Set up hitbox for attack (but don't enable yet)
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox:
		# Get the combo multiplier for the current attack
		var damage_multiplier = 1.0
		var knockback_multiplier = 1.0
		
		if config.has("combo_multipliers"):
			match combo_count:
				0:
					damage_multiplier = config.combo_multipliers.light_attack1
					knockback_multiplier = 1.0
				1:
					damage_multiplier = config.combo_multipliers.light_attack2.damage
					knockback_multiplier = config.combo_multipliers.light_attack2.knockback
				2:
					damage_multiplier = config.combo_multipliers.light_attack3.damage
					knockback_multiplier = config.combo_multipliers.light_attack3.knockback
		
		# Apply damage and knockback with multipliers
		hitbox.damage = config.damage * damage_multiplier
		hitbox.knockback_force = config.knockback_force * knockback_multiplier
		hitbox.knockback_up_force = config.knockback_up_force * knockback_multiplier
		hitbox.disable()  # Ensure hitbox starts disabled
		
		# Update hitbox position based on player direction
		_update_hitbox_position()
		
	else:
		push_error("[AttackState] Could not find hitbox node")
	
	# Play the appropriate combo animation
	match combo_count:
		0: 
			current_attack_name = "light_attack1"
			animation_player.play(current_attack_name)
		1: 
			current_attack_name = "light_attack2"
			animation_player.play(current_attack_name)
		2: 
			current_attack_name = "light_attack3"
			animation_player.play(current_attack_name)
	
	combo_window_timer = COMBO_WINDOW

func physics_update(delta: float):
	# Update cooldown timer
	if not can_attack:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0:
			can_attack = true
			# Check for buffered attack
			if buffered_attack:
				buffered_attack = false
				if combo_count < 2:
					combo_count += 1
					enter()
					return
	
	# Update buffer timer
	if buffer_timer > 0:
		buffer_timer -= delta
		if buffer_timer <= 0:
			buffered_attack = false
	
	# Check current animation frame for hitbox timing
	if animation_player and animation_player.is_playing():
		var hitbox = player.get_node_or_null("Hitbox")
		if hitbox:
			var current_frame = animation_player.current_animation_position / animation_player.current_animation_length * animation_player.get_animation(current_attack_name).length
			var frame_number = int(current_frame / animation_player.get_animation(current_attack_name).step)
			
			if current_attack_name in ATTACK_FRAMES:
				var frames = ATTACK_FRAMES[current_attack_name]
				if frame_number >= frames["enable"] and frame_number < frames["disable"] and not hitbox_enabled:
					_update_hitbox_position()  # Update position before enabling
					hitbox.enable()
					hitbox_enabled = true
				elif frame_number >= frames["disable"] and hitbox_enabled:
					hitbox.disable()
					hitbox_enabled = false
	
	if combo_window_timer > 0:
		combo_window_timer -= delta
		
		# Check for next combo input during the window
		if Input.is_action_just_pressed("attack"):
			# Check if current animation has progressed enough
			var can_combo = true
			if animation_player and animation_player.is_playing() and current_attack_name in MIN_COMBO_PROGRESS:
				var progress = animation_player.current_animation_position / animation_player.current_animation_length
				can_combo = progress >= MIN_COMBO_PROGRESS[current_attack_name]
			
			if can_attack and can_combo and combo_count < 2:  # Max 3 hits in combo (0, 1, 2)
				combo_count += 1
				enter()  # Restart the state with next combo attack
				return
			elif not can_combo:  # Only buffer if we're not ready for combo yet
				# Buffer the attack input
				buffered_attack = true
				buffer_timer = INPUT_BUFFER_TIME
	
	if not player.is_on_floor():
		_end_combo()
		state_machine.transition_to("Fall")
		return
		
	if Input.is_action_just_pressed("jump"):
		_end_combo()
		state_machine.transition_to("Jump")
		return
		
	var input_dir = Input.get_axis("left", "right")
	if input_dir != 0:
		player.velocity.x = move_toward(player.velocity.x, player.speed * input_dir, player.acceleration * delta)
		player.sprite.flip_h = input_dir < 0
		_update_hitbox_position()  # Update hitbox position when player changes direction
	player.move_and_slide()

func _update_hitbox_position() -> void:
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox.has_node("CollisionShape2D"):
		var hitbox_shape = hitbox.get_node("CollisionShape2D")
		if player.sprite.flip_h:  # Facing left
			hitbox_shape.position.x = -abs(original_hitbox_position.x)
		else:  # Facing right
			hitbox_shape.position.x = abs(original_hitbox_position.x)

func _on_animation_player_animation_finished(anim_name: String):
	if anim_name.begins_with("light_attack"):
		
		# Ensure hitbox is disabled when animation ends
		var hitbox = player.get_node_or_null("Hitbox")
		if hitbox:
			hitbox.disable()
			hitbox_enabled = false
		
		# Always transition to idle after attack animation finishes
		# The combo can continue from idle state if within the window
		_end_combo()
		state_machine.transition_to("Idle")

func exit():
	if animation_tree:
		animation_tree.set("parameters/conditions/movement_to_combat", false)
	# Ensure hitbox is disabled when leaving state
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox:
		hitbox.disable()
		hitbox_enabled = false

func _end_combo():
	combo_count = 0
	combo_window_timer = 0.0
	current_attack_name = ""


func _reset_attack_state():
	can_attack = true
	attack_cooldown_timer = 0.0
	combo_count = 0
	combo_window_timer = 0.0
	current_attack_name = ""
	hitbox_enabled = false
	buffered_attack = false
	buffer_timer = 0.0


# Set the attack type before entering the state
func set_attack_type(type: int) -> void:
	current_attack_type = type
