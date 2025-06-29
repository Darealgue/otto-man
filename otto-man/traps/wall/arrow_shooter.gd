extends BaseTrap
class_name ArrowShooter

# Arrow shooter specific configuration
@export var arrow_interval: float = 2.0  # Time between arrows
@export var arrow_speed: float = 400.0  # Arrow velocity
@export var arrow_range: float = 500.0  # How far arrows travel
@export var warning_duration: float = 0.5  # Warning time before shooting
@export var arrow_damage: float = 20.0  # Damage per arrow

# Direction configuration (only one should be true)
@export_group("Shoot Direction")
@export var shoot_right: bool = false  # Shoot to the right →
@export var shoot_left: bool = false   # Shoot to the left ←
@export var shoot_up: bool = false     # Shoot upward ↑
@export var shoot_down: bool = false   # Shoot downward ↓

# Sprite positioning (editable in editor)
@export_group("Sprite Positioning")
@export var crossbow_offset_right: Vector2 = Vector2(0, 15)
@export var crossbow_offset_left: Vector2 = Vector2(0, 15)
@export var crossbow_offset_up: Vector2 = Vector2(14, 0)
@export var crossbow_offset_down: Vector2 = Vector2(14, 0)
@export var arrow_offset_right: Vector2 = Vector2(0, -15)
@export var arrow_offset_left: Vector2 = Vector2(0, -15)
@export var arrow_offset_up: Vector2 = Vector2(14, 0)
@export var arrow_offset_down: Vector2 = Vector2(14, 0)

# Shooter state
enum ShooterState {
	IDLE,
	WARNING,
	SHOOTING,
	COOLDOWN
}

var current_state: ShooterState = ShooterState.IDLE
var shoot_timer: Timer
var warning_timer: Timer
var shooter_sprite: AnimatedSprite2D
var shoot_direction: Vector2 = Vector2.RIGHT  # Default direction

# Arrow scene - we'll create this
var arrow_scene: PackedScene

# Sprite textures
var arrow_trap_texture: Texture2D
var arrow_trap_arrow_texture: Texture2D

# Visual layering
@export var arrow_z_index: int = 2  # Render order for arrow (above ground traps)

func _ready() -> void:
	super._ready()
	
	# Set trap category
	trap_category = TrapConfig.TrapCategory.WALL
	damage_type = TrapConfig.DamageType.PHYSICAL
	
	# Force correct damage values
	arrow_damage = 20.0
	arrow_interval = 2.0
	arrow_speed = 400.0
	warning_duration = 1.0  # Increased for better animation timing
	
	# Load sprite textures
	_load_textures()
	
	# Visual components (warning light removed for cleaner look)
	
	# Create editor preview (works in editor and runtime)
	_create_editor_preview()
	
	# Setup timers only in runtime
	if not Engine.is_editor_hint():
		shoot_timer = Timer.new()
		shoot_timer.wait_time = arrow_interval
		shoot_timer.timeout.connect(_start_warning)
		shoot_timer.autostart = true  # Start automatically
		add_child(shoot_timer)
		
		warning_timer = Timer.new()
		warning_timer.wait_time = warning_duration
		warning_timer.one_shot = true
		warning_timer.timeout.connect(_shoot_arrow)
		add_child(warning_timer)
	
	print("[ArrowShooter] Ready - interval: %.1fs, damage: %.1f, speed: %.1f" % [arrow_interval, arrow_damage, arrow_speed])

# Override base trap initialize to add direction determination
func initialize(level: int, spawner_position: Vector2) -> void:
	super.initialize(level, spawner_position)
	
	# Now determine shoot direction after properties are set
	_determine_shoot_direction()
	
	# Update visual after direction is determined
	_create_shooter_visual()

func _determine_shoot_direction() -> void:
	# Debug current property values
	print("[ArrowShooter] Direction properties: R=%s L=%s U=%s D=%s" % [shoot_right, shoot_left, shoot_up, shoot_down])
	
	# Determine direction based on bool settings
	if shoot_right:
		shoot_direction = Vector2.RIGHT
		print("[ArrowShooter] Direction set to RIGHT →")
	elif shoot_left:
		shoot_direction = Vector2.LEFT
		print("[ArrowShooter] Direction set to LEFT ←")
	elif shoot_up:
		shoot_direction = Vector2.UP
		print("[ArrowShooter] Direction set to UP ↑")
	elif shoot_down:
		shoot_direction = Vector2.DOWN
		print("[ArrowShooter] Direction set to DOWN ↓")
	else:
		# Default fallback - auto-detect based on position
		var screen_center_x = 1920 / 2
		if global_position.x < screen_center_x:
			shoot_direction = Vector2.RIGHT
			print("[ArrowShooter] No direction set - auto-detected RIGHT →")
		else:
			shoot_direction = Vector2.LEFT
			print("[ArrowShooter] No direction set - auto-detected LEFT ←")
	
	print("[ArrowShooter] Position: " + str(global_position) + ", Final Direction: " + str(shoot_direction))

func _start_warning() -> void:
	if not is_active:
		return
		
	current_state = ShooterState.WARNING
	print("[ArrowShooter] Warning phase started")
	
	# Play tension animation with slight delay for more natural feel
	if shooter_sprite:
		# Small delay before starting tension animation
		await get_tree().create_timer(0.1).timeout
		if current_state == ShooterState.WARNING:  # Make sure we're still in warning state
			shooter_sprite.play("tension")
	
	# Warning light removed for cleaner visuals
	
	# Start warning timer (reduced by the delay we added)
	warning_timer.wait_time = warning_duration - 0.1
	warning_timer.start()

func _shoot_arrow() -> void:
	if not is_active:
		return
		
	current_state = ShooterState.SHOOTING
	print("[ArrowShooter] Shooting arrow!")
	
	# Play shoot animation
	if shooter_sprite:
		shooter_sprite.play("shoot")
	
	# Warning light removed
	
	# Create and fire arrow
	_create_and_fire_arrow()
	
	# Brief cooldown before returning to idle
	await get_tree().create_timer(0.1).timeout
	current_state = ShooterState.IDLE
	
	# Return to idle animation
	if shooter_sprite:
		shooter_sprite.play("idle")

func _create_and_fire_arrow() -> void:
	# Create arrow projectile
	var arrow = _create_arrow()
	if not arrow:
		print("[ArrowShooter] Failed to create arrow")
		return
		
	# Add arrow to scene
	get_tree().current_scene.add_child(arrow)
	
	# Calculate arrow spawn position with offset from trap center
	var spawn_offset = _get_arrow_spawn_offset()
	arrow.global_position = global_position + spawn_offset
	
	# Set z-index for correct layering
	arrow.z_index = arrow_z_index
	
	# Set arrow velocity
	if arrow.has_method("set_velocity"):
		arrow.set_velocity(shoot_direction * arrow_speed)
	elif arrow.has_method("set_direction_and_speed"):
		arrow.set_direction_and_speed(shoot_direction, arrow_speed)
	
	print("[ArrowShooter] Arrow fired at position: %s, direction: %s" % [arrow.global_position, shoot_direction])
	
	# If arrow has a sprite child, apply same z-index
	var arrow_sprite = arrow.get_node_or_null("ArrowSprite")
	if arrow_sprite:
		arrow_sprite.z_index = arrow_z_index

func _get_arrow_spawn_offset() -> Vector2:
	# Calculate offset so arrow appears to come from the bow tip, not center
	var offset_distance = 15.0  # Distance from center to bow tip
	
	match shoot_direction:
		Vector2.RIGHT:
			return Vector2(offset_distance, 0)
		Vector2.LEFT:
			return Vector2(-offset_distance, 0)
		Vector2.UP:
			return Vector2(0, -offset_distance)
		Vector2.DOWN:
			return Vector2(0, offset_distance)
		_:
			return Vector2.ZERO

func _create_arrow() -> Node2D:
	# Create arrow projectile using the separate script
	var arrow = ArrowProjectile.new()
	arrow.name = "Arrow"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	collision.name = "ArrowCollision"
	var shape = RectangleShape2D.new()
	
	# Add animated sprite for arrow
	var sprite = AnimatedSprite2D.new()
	sprite.name = "ArrowSprite"
	
	# Set sprite to center-based positioning
	sprite.centered = true
	
	# Setup arrow animation
	if arrow_trap_arrow_texture:
		_setup_arrow_sprite_animation(sprite)
	else:
		_setup_fallback_arrow_sprite(sprite)
	
	# Configure collision shape and sprite based on direction
	# Note: Frame size is 100x100, but actual arrow content might not fill the entire frame
	match shoot_direction:
		Vector2.RIGHT:
			# Horizontal arrow
			shape.size = Vector2(30, 10)  # Adjust based on actual arrow size in frame
			sprite.rotation_degrees = 0
			sprite.scale.x = 1
			sprite.position = arrow_offset_right  # Use editable offset
			collision.position = Vector2(0, 0)  # Hitbox at center (reference point)
		Vector2.LEFT:
			# Horizontal arrow (flipped)
			shape.size = Vector2(30, 10)  # Adjust based on actual arrow size in frame
			sprite.rotation_degrees = 0
			sprite.scale.x = -1  # Flip horizontally for left
			sprite.position = arrow_offset_left  # Use editable offset
			collision.position = Vector2(0, 0)  # Hitbox at center (reference point)
		Vector2.UP:
			# Vertical arrow (pointing up)
			shape.size = Vector2(10, 30)  # Adjust based on actual arrow size in frame
			sprite.rotation_degrees = -90
			sprite.scale.x = 1
			sprite.position = arrow_offset_up  # Use editable offset
			collision.position = Vector2(0, 0)  # Hitbox at center (reference point)
		Vector2.DOWN:
			# Vertical arrow (pointing down)
			shape.size = Vector2(10, 30)  # Adjust based on actual arrow size in frame
			sprite.rotation_degrees = 90
			sprite.scale.x = 1
			sprite.position = arrow_offset_down  # Use editable offset
			collision.position = Vector2(0, 0)  # Hitbox at center (reference point)
	
	collision.shape = shape
	arrow.add_child(collision)
	arrow.add_child(sprite)
	
	# Debug collision shapes removed for clean visuals
	
	# Set arrow properties directly
	arrow.set_damage(arrow_damage)
	arrow.set_range(arrow_range)
	
	print("[ArrowShooter] Arrow created with collision size: " + str(shape.size) + " for direction: " + str(shoot_direction))
	print("[ArrowShooter] Sprite centered: " + str(sprite.centered) + ", position: " + str(sprite.position))
	
	return arrow

func _load_textures() -> void:
	# Try to load the new sprites with multiple possible paths
	var possible_paths = [
		"res://objects/dungeon/traps/arrow_trap.png",
		"res://assets/traps/arrow_trap.png",
		"res://traps/arrow_trap.png", 
		"res://assets/arrow_trap.png"
	]
	
	var arrow_possible_paths = [
		"res://objects/dungeon/traps/arrow_trap_arrow.png",
		"res://assets/traps/arrow_trap_arrow.png",
		"res://traps/arrow_trap_arrow.png",
		"res://assets/arrow_trap_arrow.png"
	]
	
	# Check what files exist
	for path in possible_paths:
		if ResourceLoader.exists(path):
			print("[ArrowShooter] Found: " + path)
	
	# Try to load arrow trap texture
	for path in possible_paths:
		if ResourceLoader.exists(path):
			arrow_trap_texture = load(path)
			print("[ArrowShooter] ✅ Loaded arrow_trap texture from: " + path)
			break
	
	# Try to load arrow texture  
	for path in arrow_possible_paths:
		if ResourceLoader.exists(path):
			arrow_trap_arrow_texture = load(path)
			print("[ArrowShooter] ✅ Loaded arrow_trap_arrow texture from: " + path)
			break
	
	if not arrow_trap_texture:
		print("[ArrowShooter] WARNING: arrow_trap.png not found in any location, using fallback")
	else:
		print("[ArrowShooter] Arrow trap texture loaded successfully: " + str(arrow_trap_texture.get_size()))
		
	if not arrow_trap_arrow_texture:
		print("[ArrowShooter] WARNING: arrow_trap_arrow.png not found in any location, using fallback")
	else:
		print("[ArrowShooter] Arrow texture loaded successfully: " + str(arrow_trap_arrow_texture.get_size()))

func _create_shooter_visual() -> void:
	# Remove existing shooter sprite if any
	if shooter_sprite:
		shooter_sprite.queue_free()
	
	# Remove generic sprite
	if sprite:
		sprite.queue_free()
	
	# Create animated shooter sprite
	shooter_sprite = AnimatedSprite2D.new()
	shooter_sprite.name = "ShooterSprite"
	
	# Setup sprite frames
	_setup_sprite_animations()
	
	# Rotate crossbow based on shoot direction (sprite is originally facing RIGHT)
	# Also adjust position using editable offset values
	match shoot_direction:
		Vector2.RIGHT:
			shooter_sprite.rotation_degrees = 0
			shooter_sprite.scale.x = 1
			shooter_sprite.position = crossbow_offset_right
			print("[ArrowShooter] Crossbow oriented for RIGHT → at offset: " + str(crossbow_offset_right))
		Vector2.LEFT:
			shooter_sprite.rotation_degrees = 0
			shooter_sprite.scale.x = -1  # Flip horizontally for left
			shooter_sprite.position = crossbow_offset_left
			print("[ArrowShooter] Crossbow oriented for LEFT ← at offset: " + str(crossbow_offset_left))
		Vector2.UP:
			shooter_sprite.rotation_degrees = -90
			shooter_sprite.scale.x = 1
			shooter_sprite.position = crossbow_offset_up
			print("[ArrowShooter] Crossbow oriented for UP ↑ at offset: " + str(crossbow_offset_up))
		Vector2.DOWN:
			shooter_sprite.rotation_degrees = 90
			shooter_sprite.scale.x = 1
			shooter_sprite.position = crossbow_offset_down
			print("[ArrowShooter] Crossbow oriented for DOWN ↓ at offset: " + str(crossbow_offset_down))
	
	add_child(shooter_sprite)
	
	# Start with idle animation
	shooter_sprite.play("idle")

func _setup_sprite_animations() -> void:
	if not shooter_sprite:
		return
		
	shooter_sprite.sprite_frames = SpriteFrames.new()
	
	if arrow_trap_texture:
		# Setup animations using the sprite sheet
		_setup_arrow_trap_animations()
	else:
		# Fallback: create simple animations
		_setup_fallback_animations()

func _setup_arrow_trap_animations() -> void:
	# Calculate frame dimensions (assuming 10 frames horizontally)
	var frame_width = arrow_trap_texture.get_width() / 10
	var frame_height = arrow_trap_texture.get_height()
	
	# Create idle animation (frames 1-8 for tension)
	shooter_sprite.sprite_frames.add_animation("idle")
	shooter_sprite.sprite_frames.add_animation("tension")
	shooter_sprite.sprite_frames.add_animation("shoot")
	
	# Idle animation (just frame 1)
	var idle_frame = AtlasTexture.new()
	idle_frame.atlas = arrow_trap_texture
	idle_frame.region = Rect2(0, 0, frame_width, frame_height)
	shooter_sprite.sprite_frames.add_frame("idle", idle_frame)
	
	# Tension animation (frames 1-8)
	for i in range(8):
		var frame = AtlasTexture.new()
		frame.atlas = arrow_trap_texture
		frame.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		shooter_sprite.sprite_frames.add_frame("tension", frame)
	
	# Shoot animation (frames 9-10)
	for i in range(8, 10):
		var frame = AtlasTexture.new()
		frame.atlas = arrow_trap_texture
		frame.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		shooter_sprite.sprite_frames.add_frame("shoot", frame)
	
	# Set animation speeds - calculate based on warning duration
	# Warning duration is 0.5 seconds, we have 8 frames for tension
	# So we need 8 frames / 0.5 seconds = 16 FPS
	var tension_fps = 8.0 / warning_duration  # 8 frames over warning duration
	
	shooter_sprite.sprite_frames.set_animation_speed("idle", 1.0)
	shooter_sprite.sprite_frames.set_animation_speed("tension", tension_fps)
	shooter_sprite.sprite_frames.set_animation_speed("shoot", 20.0)   # Fast shoot
	
	# Set animation loop settings
	shooter_sprite.sprite_frames.set_animation_loop("idle", true)
	shooter_sprite.sprite_frames.set_animation_loop("tension", false)  # Don't loop tension
	shooter_sprite.sprite_frames.set_animation_loop("shoot", false)    # Don't loop shoot
	
	print("[ArrowShooter] Tension animation set to " + str(tension_fps) + " FPS for " + str(warning_duration) + "s duration")
	print("[ArrowShooter] This means all 8 frames will play in " + str(8.0 / tension_fps) + " seconds")
	
	print("[ArrowShooter] Arrow trap animations setup complete")

func _setup_fallback_animations() -> void:
	# Create simple colored rectangles as fallback
	shooter_sprite.sprite_frames.add_animation("idle")
	shooter_sprite.sprite_frames.add_animation("tension")
	shooter_sprite.sprite_frames.add_animation("shoot")
	
	# Create simple textures
	var idle_texture = _create_simple_crossbow_texture(Color.SADDLE_BROWN)
	var tension_texture = _create_simple_crossbow_texture(Color.DARK_GOLDENROD)
	var shoot_texture = _create_simple_crossbow_texture(Color.ORANGE_RED)
	
	shooter_sprite.sprite_frames.add_frame("idle", idle_texture)
	shooter_sprite.sprite_frames.add_frame("tension", tension_texture)
	shooter_sprite.sprite_frames.add_frame("shoot", shoot_texture)
	
	shooter_sprite.sprite_frames.set_animation_speed("idle", 1.0)
	shooter_sprite.sprite_frames.set_animation_speed("tension", 2.0)
	shooter_sprite.sprite_frames.set_animation_speed("shoot", 5.0)
	
	print("[ArrowShooter] Fallback animations setup complete")

func _create_simple_crossbow_texture(color: Color) -> ImageTexture:
	var texture = ImageTexture.new()
	var image = Image.create(40, 30, false, Image.FORMAT_RGB8)
	
	# Draw crossbow shape
	for x in range(40):
		for y in range(30):
			if (x >= 10 and x <= 30 and y >= 12 and y <= 17):  # Main body
				image.set_pixel(x, y, color)
			elif (x >= 25 and x <= 35 and y >= 8 and y <= 21):  # Bow part
				image.set_pixel(x, y, color.darkened(0.3))
			elif (x >= 30 and x <= 38 and y >= 14 and y <= 15):  # Arrow slot
				image.set_pixel(x, y, Color.BLACK)
	
	texture.set_image(image)
	return texture

func _setup_arrow_sprite_animation(sprite: AnimatedSprite2D) -> void:
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.add_animation("fly")
	
	# Determine frame count from texture width (assuming square frames or known aspect ratio)
	# If you know the exact frame count, update this number
	var frame_count = 4  # Default, adjust based on your sprite sheet
	
	# Auto-detect frame count if texture is loaded
	if arrow_trap_arrow_texture:
		# Try to detect frame count (assuming frames are square or have known width)
		var texture_width = arrow_trap_arrow_texture.get_width()
		var texture_height = arrow_trap_arrow_texture.get_height()
		
		# If frames are square, frame count = width / height
		if texture_width > texture_height:
			frame_count = texture_width / texture_height
		else:
			frame_count = 1  # Single frame
		
		print("[ArrowShooter] Auto-detected frame count: " + str(frame_count) + " from texture size: " + str(texture_width) + "x" + str(texture_height))
	
	var frame_width = arrow_trap_arrow_texture.get_width() / frame_count
	var frame_height = arrow_trap_arrow_texture.get_height()
	
	print("[ArrowShooter] Individual frame size: " + str(frame_width) + "x" + str(frame_height))
	
	# Add frames for flying animation
	for i in range(frame_count):
		var frame = AtlasTexture.new()
		frame.atlas = arrow_trap_arrow_texture
		frame.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		sprite.sprite_frames.add_frame("fly", frame)
	
	sprite.sprite_frames.set_animation_speed("fly", 8.0)
	sprite.sprite_frames.set_animation_loop("fly", true)
	sprite.play("fly")
	
	print("[ArrowShooter] Arrow sprite animation setup complete")

func _setup_fallback_arrow_sprite(sprite: AnimatedSprite2D) -> void:
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.add_animation("fly")
	
	# Create simple arrow texture
	var texture = ImageTexture.new()
	var image = Image.create(20, 4, false, Image.FORMAT_RGB8)
	
	# Draw arrow shape
	for x in range(20):
		for y in range(4):
			if x < 15:  # Arrow shaft
				image.set_pixel(x, y, Color.BROWN)
			else:  # Arrow head
				if y == 1 or y == 2:
					image.set_pixel(x, y, Color.GRAY)
	
	texture.set_image(image)
	sprite.sprite_frames.add_frame("fly", texture)
	sprite.sprite_frames.set_animation_speed("fly", 1.0)
	sprite.play("fly")
	
	print("[ArrowShooter] Fallback arrow sprite setup complete")

func _create_editor_preview() -> void:
	# Determine direction for preview
	if shoot_right:
		shoot_direction = Vector2.RIGHT
	elif shoot_left:
		shoot_direction = Vector2.LEFT
	elif shoot_up:
		shoot_direction = Vector2.UP
	elif shoot_down:
		shoot_direction = Vector2.DOWN
	else:
		shoot_direction = Vector2.RIGHT  # Default
	
	# Create preview visuals
	_create_shooter_visual()
	
	# Add direction indicator in editor
	if Engine.is_editor_hint():
		var direction_label = Label.new()
		direction_label.name = "DirectionIndicator"
		direction_label.text = _get_direction_text()
		direction_label.position = Vector2(-30, -50)
		direction_label.add_theme_color_override("font_color", Color.CYAN)
		add_child(direction_label)

func _get_direction_text() -> String:
	match shoot_direction:
		Vector2.RIGHT:
			return "RIGHT →"
		Vector2.LEFT:
			return "LEFT ←"
		Vector2.UP:
			return "UP ↑"
		Vector2.DOWN:
			return "DOWN ↓"
		_:
			return "UNKNOWN"

# Override base trap behavior - we don't use proximity detection
func trigger_trap() -> void:
	# Arrow shooter doesn't need manual triggering
	pass

func _on_detection_area_entered(body: Node2D) -> void:
	# Arrow shooter doesn't use detection area
	pass

func _on_detection_area_exited(body: Node2D) -> void:
	# Arrow shooter doesn't use detection area
	pass 
 
