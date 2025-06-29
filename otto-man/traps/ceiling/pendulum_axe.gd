extends BaseTrap
class_name PendulumAxe

@export var sprite_vertical_offset: float = -30.0 # Use this in the editor to move the sprite up (-) or down (+) along the chain.

# Scene nodes (will be created in code or found if they exist)
var pivot_point: Node2D  # Sabit nokta - zincirin bağlandığı yer
var axe_sprite: AnimatedSprite2D  # Balta sprite'ı
var hitbox_area: Area2D  # Damage area

var swing_angle: float = 90.0  # Total swing angle in degrees (±45°)
var swing_speed: float = 2.0   # Speed of pendulum swing (faster)
var current_angle: float = 0.0
var swing_direction: int = 1
var swing_time: float = 0.0  # Time tracker for smooth pendulum motion
var damaged_players: Dictionary = {}  # Track players and their damage cooldown timers

# Knockback constants (stronger than cannonball projectile)
const KNOCKBACK_FORCE := 700.0
const KNOCKBACK_UP_FORCE := 400.0

# Sprite texture
var axe_trap_texture: Texture2D

enum PendulumState {
	IDLE,
	SWINGING,
	STOPPING
}

var pendulum_state: PendulumState = PendulumState.IDLE

var initial_sprite_distance: float = 150.0  # Use a fixed pendulum length

func _ready():
	super._ready()
	
	# Load axe texture
	_load_axe_texture()
	
	# Find existing nodes or create them
	_setup_nodes()
	
	# Setup axe animation if sprite exists
	if axe_sprite:
		if axe_trap_texture:
			_setup_axe_animation()
		else:
			_setup_fallback_axe_animation()
		axe_sprite.play("swing")
	
	# Setup hitbox area if it exists
	if hitbox_area:
		hitbox_area.monitoring = true
		hitbox_area.body_entered.connect(_on_pendulum_damage_area_entered)
		print("[PendulumAxe] Connected hitbox area signal")
	
	# Disable BaseTrap's default damage area
	if damage_area:
		damage_area.monitoring = false
		print("[PendulumAxe] Disabled BaseTrap damage area, using manual hitbox")
	
	# Disable proximity detection since we swing continuously
	if detection_area:
		detection_area.monitoring = false
	
	# Set the pivot point high above the trap origin
	pivot_point.position = Vector2(0, -150)
	print("[PendulumAxe] Set pivot position to %s" % pivot_point.position)

	# Start swinging immediately when ready
	_start_swinging()

func _setup_nodes():
	# Try to find existing nodes first
	pivot_point = get_node_or_null("pivot_point")
	axe_sprite = get_node_or_null("axe_sprite") 
	hitbox_area = get_node_or_null("hitbox_area")
	
	# If nodes don't exist, create them
	if not pivot_point:
		pivot_point = Node2D.new()
		pivot_point.name = "pivot_point"
		add_child(pivot_point)
		print("[PendulumAxe] Created pivot_point")
	
	if not axe_sprite:
		axe_sprite = AnimatedSprite2D.new()
		axe_sprite.name = "axe_sprite"
		axe_sprite.centered = true
		add_child(axe_sprite)
		print("[PendulumAxe] Created axe_sprite")
	
	if not hitbox_area:
		hitbox_area = Area2D.new()
		hitbox_area.name = "hitbox_area"
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(80, 60) # Larger hitbox for axe
		collision.shape = shape
		hitbox_area.add_child(collision)
		# Ensure the hitbox detects the player body (layer 2) and hurtbox (layer 4 -> value 8)
		# We keep the axe itself out of collision layers to avoid physics interference
		hitbox_area.collision_layer = 0
		hitbox_area.collision_mask = 2 + 8  # Player body (2) + player hurtbox (8)
		
		add_child(hitbox_area)
		print("[PendulumAxe] Created hitbox_area")
	
	# Ensure collision layers/mask detect player regardless of existing or new hitbox
	if hitbox_area:
		hitbox_area.collision_layer = 0
		hitbox_area.collision_mask = 2 + 8  # Player body + hurtbox
	
	# IMPORTANT: Reset all transforms to ensure a clean slate
	axe_sprite.offset = Vector2.ZERO
	axe_sprite.position = Vector2.ZERO
	axe_sprite.rotation = 0
	hitbox_area.position = Vector2.ZERO
	hitbox_area.rotation = 0
	
	print("[PendulumAxe] Nodes created and transforms reset.")

# Override initialize to position trap correctly
func initialize(level: int, spawner_position: Vector2) -> void:
	# First call parent initialize
	super.initialize(level, spawner_position)
	
	# Adjust trap position so pivot point aligns with spawner position
	if pivot_point:
		var offset_to_pivot = pivot_point.position
		global_position = spawner_position - offset_to_pivot
		print("[PendulumAxe] Adjusted trap position so pivot aligns with spawner")
		print("[PendulumAxe] Spawner: %s, Pivot offset: %s, Final trap pos: %s" % [spawner_position, offset_to_pivot, global_position])

func _load_axe_texture() -> void:
	# Try to load the new axe sprite with multiple possible paths
	var possible_paths = [
		"res://objects/dungeon/traps/axe_trap.png",
		"res://assets/traps/axe_trap.png",
		"res://traps/axe_trap.png",
		"res://assets/axe_trap.png"
	]
	
	# Try to load axe texture
	for path in possible_paths:
		if ResourceLoader.exists(path):
			axe_trap_texture = load(path)
			print("[PendulumAxe] ✅ Loaded axe_trap texture from: " + path)
			print("[PendulumAxe] Axe texture loaded successfully: " + str(axe_trap_texture.get_size()))
			break
	
	if not axe_trap_texture:
		print("[PendulumAxe] WARNING: axe_trap.png not found in any location, using fallback")

func _setup_axe_animation() -> void:
	axe_sprite.sprite_frames = SpriteFrames.new()
	axe_sprite.sprite_frames.add_animation("swing")
	
	# Calculate frame dimensions (assuming 7 frames horizontally)
	var frame_count = 7
	var frame_width = axe_trap_texture.get_width() / frame_count
	var frame_height = axe_trap_texture.get_height()
	
	print("[PendulumAxe] Setting up animation with " + str(frame_count) + " frames")
	print("[PendulumAxe] Individual frame size: " + str(frame_width) + "x" + str(frame_height))
	
	# Add all frames to the swing animation
	for i in range(frame_count):
		var frame = AtlasTexture.new()
		frame.atlas = axe_trap_texture
		frame.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		axe_sprite.sprite_frames.add_frame("swing", frame)
	
	# Set animation properties
	axe_sprite.sprite_frames.set_animation_speed("swing", 8.0)  # 8 FPS for smooth swing
	axe_sprite.sprite_frames.set_animation_loop("swing", true)  # Loop the animation
	
	print("[PendulumAxe] Axe animation setup complete")

func _setup_fallback_axe_animation() -> void:
	# Create simple fallback animation
	axe_sprite.sprite_frames = SpriteFrames.new()
	axe_sprite.sprite_frames.add_animation("swing")
	
	# Create simple axe texture as fallback
	var fallback_texture = _create_simple_axe_texture()
	axe_sprite.sprite_frames.add_frame("swing", fallback_texture)
	
	axe_sprite.sprite_frames.set_animation_speed("swing", 1.0)
	axe_sprite.sprite_frames.set_animation_loop("swing", true)
	
	print("[PendulumAxe] Fallback axe animation setup complete")

func _create_simple_axe_texture() -> ImageTexture:
	var texture = ImageTexture.new()
	var image = Image.create(80, 100, false, Image.FORMAT_RGB8)
	
	# Draw axe shape
	for x in range(80):
		for y in range(100):
			if (y >= 0 and y <= 15):  # Axe blade top
				image.set_pixel(x, y, Color.DARK_RED)
			elif (y >= 16 and y <= 30):  # Axe blade bottom
				image.set_pixel(x, y, Color.DARK_RED.darkened(0.2))
			elif (x >= 35 and x <= 45 and y >= 31 and y <= 100):  # Handle
				image.set_pixel(x, y, Color.SADDLE_BROWN)
	
	texture.set_image(image)
	return texture

func update_pendulum_position():
	if not axe_sprite or not pivot_point or not hitbox_area:
		return

	var angle_rad = deg_to_rad(current_angle)
	
	# The swinging point is at a fixed distance from the pivot.
	# We rotate a simple downward vector to get the swing position.
	const PENDULUM_LENGTH = 150.0
	var swing_offset = Vector2(0, PENDULUM_LENGTH).rotated(angle_rad)
	
	# The position of the blade is relative to the pivot's position.
	var blade_position = pivot_point.position + swing_offset
	
	# SET both sprite and hitbox to this EXACT position and rotation.
	# This guarantees they are always perfectly in sync.
	axe_sprite.position = blade_position + Vector2(0, sprite_vertical_offset).rotated(angle_rad)
	axe_sprite.rotation = angle_rad
	
	hitbox_area.position = blade_position # Hitbox stays at the tip of the pendulum
	hitbox_area.rotation = angle_rad

func _physics_process(delta):
	# Update damage cooldown timers for all players
	for player_id in damaged_players.keys():
		damaged_players[player_id] -= delta
		if damaged_players[player_id] <= 0:
			damaged_players.erase(player_id)
	
	if pendulum_state == PendulumState.SWINGING:
		# Update time for smooth pendulum motion
		swing_time += delta * swing_speed
		
		# Calculate pendulum angle using sine wave for natural physics
		# Sine wave naturally slows at peaks and speeds up at bottom
		current_angle = sin(swing_time) * (swing_angle / 2.0)
		
		update_pendulum_position()
		
		# Only use signal-based damage detection to prevent double damage

func _start_swinging():
	print("PendulumAxe starting continuous swing at position: ", global_position)
	pendulum_state = PendulumState.SWINGING
	
	# Start from random phase in the sine wave
	swing_time = randf() * PI * 2.0  # Random starting point in sine wave

func _execute_trap_behavior():
	# Override BaseTrap's behavior - but pendulum is already swinging
	print("PendulumAxe behavior executed (already swinging)")
	# No need to do anything, it's already swinging continuously

func deactivate():
	super.deactivate()
	pendulum_state = PendulumState.STOPPING
	
	# Gradually slow down the pendulum
	var tween = create_tween()
	tween.tween_method(_slow_down_swing, swing_speed, 0.0, 2.0)
	tween.tween_callback(_stop_pendulum_permanently)

func _slow_down_swing(speed: float):
	swing_speed = speed

func _stop_pendulum():
	pendulum_state = PendulumState.IDLE
	swing_speed = 1.5  # Reset for next activation
	swing_time = 0.0  # Reset time
	# Keep damage area active, pendulum will restart swinging after cooldown
	
	# Wait a moment then restart swinging
	await get_tree().create_timer(1.0).timeout
	if is_active:  # Only restart if trap is still active
		_start_swinging()

func _stop_pendulum_permanently():
	pendulum_state = PendulumState.IDLE
	swing_speed = 1.5
	swing_time = 0.0
	if damage_area:
		damage_area.monitoring = false

func _on_pendulum_damage_area_entered(body: Node2D) -> void:
	print("[PendulumAxe] Body entered damage area: ", body.name, " - Groups: ", body.get_groups())
	if body.is_in_group("player"):
		var player_id = body.get_instance_id()
		# Check if player is on damage cooldown
		if player_id in damaged_players:
			print("[PendulumAxe] Player on damage cooldown (%.2f seconds remaining), skipping damage" % damaged_players[player_id])
			return
		
		print("[PendulumAxe] Player detected in damage area, dealing damage: ", base_damage)
		deal_damage_to_player(body)
		# Apply stronger knockback using the existing system
		_apply_player_knockback(body)
		# Add player to damage cooldown (1.0 second cooldown)
		damaged_players[player_id] = 1.0
		print("[PendulumAxe] Player added to damage cooldown for 1.0 seconds")
	else:
		print("[PendulumAxe] Non-player body detected: ", body.name)

func get_trap_info() -> String:
	return "Pendulum Axe - Swings back and forth dealing %d damage" % int(base_damage) 

# --- Knockback helper ---

func _apply_player_knockback(player: Node):
	# Verify we're actually dealing with the player
	if not player.is_in_group("player"):
		print("[PendulumAxe] Attempted to apply knockback to non-player object: " + str(player.name))
		return

	# Ensure required fields exist
	if not ("last_hit_knockback" in player and "last_hit_position" in player):
		print("[PendulumAxe] Player missing knockback properties, cannot apply knockback")
		return

	# Direction from axe to player (horizontal component only for push)
	var direction = (player.global_position - global_position).normalized()

	var knockback_data = {
		"force": KNOCKBACK_FORCE,
		"up_force": KNOCKBACK_UP_FORCE
	}

	player.last_hit_knockback = knockback_data
	player.last_hit_position = global_position

	# Directly modify velocity if available
	if "velocity" in player and direction.x != 0:
		player.velocity = Vector2(direction.x * knockback_data.force, -knockback_data.up_force)

	# Force player into hurt state so their own system processes knockback properly
	var state_machine = player.get_node_or_null("StateMachine")
	if state_machine and state_machine.has_method("transition_to"):
		state_machine.transition_to("Hurt")
		print("[PendulumAxe] Forced player into Hurt state for knockback")

	print("[PendulumAxe] Applied knockback to player: force=" + str(knockback_data.force) + ", up_force=" + str(knockback_data.up_force))
 
 
