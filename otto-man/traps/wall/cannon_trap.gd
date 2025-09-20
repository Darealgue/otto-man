extends BaseTrap
class_name CannonTrap

# Cannon trap specific configuration
@export var cannon_interval: float = 4.0  # Time between shots (slower than arrows)
@export var cannonball_speed: float = 300.0  # Cannonball velocity (slower than arrows)
@export var cannonball_range: float = 600.0  # How far cannonballs travel
@export var warning_duration: float = 1.0  # Warning time before shooting (longer)
@export var cannonball_damage: float = 50.0  # Damage per cannonball (higher than arrows)
@export var explosion_radius: float = 80.0  # Area damage radius

# Direction configuration (cannons only shoot horizontally)
@export_group("Shoot Direction")
@export var shoot_right: bool = false  # Shoot to the right →
@export var shoot_left: bool = false   # Shoot to the left ←
@export var shoot_up: bool = false     # NOT USED - cannons only shoot horizontally
@export var shoot_down: bool = false   # NOT USED - cannons only shoot horizontally

# Cannon state
enum CannonState {
	IDLE,
	WARNING,
	SHOOTING,
	COOLDOWN
}

var current_state: CannonState = CannonState.IDLE
var shoot_timer: Timer
var warning_timer: Timer
var cannon_sprite: AnimatedSprite2D
var cannon_animation_player: AnimationPlayer
var warning_light: ColorRect
var shoot_direction: Vector2 = Vector2.RIGHT  # Default direction

func _ready() -> void:
	super._ready()
	
	# Set trap category
	trap_category = TrapConfig.TrapCategory.WALL
	damage_type = TrapConfig.DamageType.PHYSICAL
	
	# Force correct damage values
	cannonball_damage = 50.0
	cannon_interval = 4.0
	cannonball_speed = 300.0
	warning_duration = 1.0
	
	# Create visual components
	_create_warning_light()
	
	# Setup timers
	shoot_timer = Timer.new()
	shoot_timer.wait_time = cannon_interval
	shoot_timer.timeout.connect(_start_warning)
	shoot_timer.autostart = true  # Start automatically
	add_child(shoot_timer)
	
	warning_timer = Timer.new()
	warning_timer.wait_time = warning_duration
	warning_timer.one_shot = true
	warning_timer.timeout.connect(_shoot_cannonball)
	add_child(warning_timer)
	
	print("[CannonTrap] Ready - interval: %.1fs, damage: %.1f, speed: %.1f" % [cannon_interval, cannonball_damage, cannonball_speed])

# Override base trap initialize to add direction determination
func initialize(level: int, spawner_position: Vector2) -> void:
	super.initialize(level, spawner_position)
	
	# Scale damage with level
	cannonball_damage = 50.0 + (level - 1) * 15.0  # 50, 65, 80, 95...
	
	# Slightly faster firing at higher levels
	cannon_interval = max(2.5, 4.0 - (level - 1) * 0.3)  # 4.0, 3.7, 3.4, 3.1...
	shoot_timer.wait_time = cannon_interval
	
	# Now determine shoot direction after properties are set
	_determine_shoot_direction()
	
	# Update visual after direction is determined
	_create_cannon_visual()

func _determine_shoot_direction() -> void:
	# Debug current property values
	print("[CannonTrap] Direction properties: R=%s L=%s U=%s D=%s" % [shoot_right, shoot_left, shoot_up, shoot_down])
	
	# Cannons only shoot horizontally (LEFT or RIGHT)
	if shoot_right:
		shoot_direction = Vector2.RIGHT
		print("[CannonTrap] Direction set to RIGHT →")
	elif shoot_left:
		shoot_direction = Vector2.LEFT
		print("[CannonTrap] Direction set to LEFT ←")
	elif shoot_up or shoot_down:
		# Force horizontal direction for vertical settings
		var screen_center_x = 1920 / 2
		if global_position.x < screen_center_x:
			shoot_direction = Vector2.RIGHT
			print("[CannonTrap] Vertical direction not allowed - forced to RIGHT →")
		else:
			shoot_direction = Vector2.LEFT
	else:
		# Default fallback - auto-detect based on position
		var screen_center_x = 1920 / 2
		if global_position.x < screen_center_x:
			shoot_direction = Vector2.RIGHT
		else:
			shoot_direction = Vector2.LEFT

func _start_warning() -> void:
	if not is_active:
		return
		
	current_state = CannonState.WARNING
	
	# Show warning light
	if warning_light:
		warning_light.color = Color.ORANGE  # Orange for cannon warning
		warning_light.visible = true
		
		# Blinking effect
		var tween = create_tween()
		tween.set_loops(int(warning_duration * 2))  # Blink 2 times per second
		tween.tween_property(warning_light, "modulate:a", 0.3, 0.25)
		tween.tween_property(warning_light, "modulate:a", 1.0, 0.25)
	
	# Start warning timer
	warning_timer.start()

func _shoot_cannonball() -> void:
	if not is_active:
		return
		
	current_state = CannonState.SHOOTING
	
	# Hide warning light
	if warning_light:
		warning_light.visible = false
	
	# Play fire animation
	if cannon_sprite:
		cannon_sprite.animation = "fire"
		cannon_sprite.play()
		# Connect to animation finished signal
		if not cannon_sprite.animation_finished.is_connected(_on_fire_animation_finished):
			cannon_sprite.animation_finished.connect(_on_fire_animation_finished)
	
	# Wait for frame 10 to fire cannonball
	_wait_for_frame_and_fire(10)
	
	# Brief cooldown before returning to idle (will be overridden by animation)
	await get_tree().create_timer(0.3).timeout
	current_state = CannonState.IDLE

func _wait_for_frame_and_fire(target_frame: int):
	# Calculate timing to fire at specific frame
	# Fire animation speed is 12.0 FPS, so each frame is 1/12 seconds
	var frame_duration = 1.0 / 12.0  # Animation speed from _create_cannon_visual
	var wait_time = (target_frame - 1) * frame_duration  # Frame 11 = index 10
	
	
	# Wait for the specific frame timing
	await get_tree().create_timer(wait_time).timeout
	
	# Fire cannonball at frame 10
	_create_and_fire_cannonball()

func _on_fire_animation_finished():
	# Return to idle animation after fire animation completes
	if cannon_sprite:
		cannon_sprite.animation = "idle"
		cannon_sprite.play()
	current_state = CannonState.IDLE

func _create_recoil_effect() -> void:
	if cannon_sprite:
		# Quick recoil animation
		var tween = create_tween()
		var recoil_offset = shoot_direction * -10  # Recoil backwards
		tween.tween_property(cannon_sprite, "position", cannon_sprite.position + recoil_offset, 0.1)
		tween.tween_property(cannon_sprite, "position", cannon_sprite.position, 0.2)

func _create_and_fire_cannonball() -> void:
	# Create cannonball projectile
	var cannonball = _create_cannonball(shoot_direction)
	if not cannonball:
		return
		
	# Add cannonball to scene
	get_tree().current_scene.add_child(cannonball)
	
	# Position cannonball at cannon muzzle with fine-tuning
	var muzzle_offset = shoot_direction * 35  # Forward offset
	var vertical_offset = Vector2(0, -10)  # Move up to align with muzzle
	
	# Adjust vertical offset based on direction
	match shoot_direction:
		Vector2.RIGHT:
			vertical_offset = Vector2(0, -8)  # Fine-tune for right-facing
		Vector2.LEFT:
			vertical_offset = Vector2(0, -8)  # Fine-tune for left-facing
	
	cannonball.global_position = global_position + muzzle_offset + vertical_offset
	
	# Set cannonball velocity
	if cannonball.has_method("set_velocity"):
		cannonball.set_velocity(shoot_direction * cannonball_speed)
	elif cannonball.has_method("set_direction_and_speed"):
		cannonball.set_direction_and_speed(shoot_direction, cannonball_speed)

func _create_cannonball(direction: Vector2) -> Node2D:
	# Create cannonball projectile using scene file
	var cannonball_scene = preload("res://traps/cannonball_projectile.tscn")
	if not cannonball_scene:
		return null
		
	var cannonball = cannonball_scene.instantiate()
	if not cannonball:
		return null
		
	cannonball.name = "Cannonball"
	
	# Set direction for sprite flipping and movement
	if cannonball.has_method("set_direction"):
		cannonball.set_direction(direction)
	
	return cannonball

func _create_cannon_visual() -> void:
	# Remove existing cannon sprite if any
	if cannon_sprite:
		cannon_sprite.queue_free()
	
	# Remove generic sprite
	if sprite:
		sprite.queue_free()
	
	# Create animated cannon sprite
	cannon_sprite = AnimatedSprite2D.new()
	cannon_sprite.name = "CannonSprite"
	
	# Load cannon sprite frames
	var sprite_frames = SpriteFrames.new()
	
	# Load the main cannon texture
	var cannon_texture = load("res://objects/dungeon/traps/cannon_trap.png") as Texture2D
	
	if cannon_texture:
		# Create idle animation (frame 1)
		sprite_frames.add_animation("idle")
		sprite_frames.set_animation_loop("idle", true)
		sprite_frames.set_animation_speed("idle", 1.0)
		
		# Frame 1 is idle (first frame of sprite sheet)
		# Estimate: 19 frames horizontally, so width = total_width/19
		var texture_width = cannon_texture.get_width()
		var texture_height = cannon_texture.get_height()
		var frame_width = texture_width / 19  # 19 frames total
		var frame_height = texture_height
		
		var frame_1 = _extract_frame_from_texture(cannon_texture, 0, 0, frame_width, frame_height)
		sprite_frames.add_frame("idle", frame_1)
		
		# Create fire animation (frames 2-19)
		sprite_frames.add_animation("fire")
		sprite_frames.set_animation_loop("fire", false)
		sprite_frames.set_animation_speed("fire", 12.0)  # Fast fire animation
		
		# Add frames 2-19 for fire animation
		for frame_index in range(1, 19):  # frames 2-19 (1-18 in 0-based)
			var fire_frame = _extract_frame_from_texture(cannon_texture, frame_index, 0, frame_width, frame_height)
			sprite_frames.add_frame("fire", fire_frame)
	else:
		print("[CannonTrap] Failed to load cannon texture, using placeholder")
		# Create placeholder if texture loading fails
		sprite_frames.add_animation("idle")
		sprite_frames.add_animation("fire")
	
	cannon_sprite.sprite_frames = sprite_frames
	cannon_sprite.animation = "idle"
	cannon_sprite.play()
	
	# Position adjustment - move cannon sprite up a bit
	cannon_sprite.position = Vector2(0, -8)  # Move up to align better with spawn point
	
	# Rotate cannon based on shoot direction (only horizontal)
	match shoot_direction:
		Vector2.RIGHT:
			cannon_sprite.rotation_degrees = 0
			cannon_sprite.scale.x = 1
			print("[CannonTrap] Cannon oriented for RIGHT →")
		Vector2.LEFT:
			cannon_sprite.rotation_degrees = 0
			cannon_sprite.scale.x = -1
			print("[CannonTrap] Cannon oriented for LEFT ←")
		_:
			# Fallback for any other direction (should not happen)
			cannon_sprite.rotation_degrees = 0
			cannon_sprite.scale.x = 1
			print("[CannonTrap] Unknown direction - defaulting to RIGHT →")
	
	add_child(cannon_sprite)

func _extract_frame_from_texture(texture: Texture2D, frame_x: int, frame_y: int, frame_width: int, frame_height: int) -> Texture2D:
	# Extract a specific frame from sprite sheet
	var atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.region = Rect2(frame_x * frame_width, frame_y * frame_height, frame_width, frame_height)
	return atlas_texture

func _create_warning_light() -> void:
	warning_light = ColorRect.new()
	warning_light.name = "WarningLight"
	warning_light.size = Vector2(12, 12)  # Bigger warning light
	warning_light.position = Vector2(-6, -25)
	warning_light.color = Color.ORANGE
	warning_light.visible = false
	add_child(warning_light)

# Override base trap behavior - we don't use proximity detection
func trigger_trap() -> void:
	# Cannon trap doesn't need manual triggering
	pass

func _on_detection_area_entered(body: Node2D) -> void:
	# Cannon trap doesn't use detection area
	pass

func _on_detection_area_exited(body: Node2D) -> void:
	# Cannon trap doesn't use detection area
	pass 
