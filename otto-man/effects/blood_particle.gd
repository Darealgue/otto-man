class_name BloodParticle
extends RigidBody2D

@export var blood_splatter_scene: PackedScene
@export var particle_lifetime: float = 2.0
@export var splatter_chance: float = 0.7  # 70% chance to create splatter

var lifetime_timer: float = 0.0
var has_splattered: bool = false
var hit_direction: Vector2 = Vector2.RIGHT
var damage_amount: float = 10.0

func set_blood_splatter_scene(scene: PackedScene) -> void:
	blood_splatter_scene = scene

func set_hit_direction(direction: Vector2) -> void:
	hit_direction = direction
	# Apply velocity based on hit direction
	apply_velocity_from_hit_direction()

func set_damage_amount(damage: float) -> void:
	damage_amount = damage
	# Reapply velocity with new damage amount
	apply_velocity_from_hit_direction()

func apply_velocity_from_hit_direction() -> void:
	# Calculate force based on damage amount
	var damage_multiplier = clamp(damage_amount / 10.0, 0.5, 2.0)  # 0.5x to 2x based on damage
	var base_force = randf_range(100.0, 200.0) * damage_multiplier  # Scale force with damage
	var random_spread = randf_range(-PI/3, PI/3)  # -60 to 60 degrees spread
	
	# Apply hit direction with some random spread
	var final_direction = hit_direction.rotated(random_spread)
	apply_central_impulse(final_direction * base_force)

func _ready() -> void:
	# Set up physics
	gravity_scale = 1.0
	linear_damp = 0.5
	angular_damp = 0.8
	
	# Set collision layers and masks
	# Blood particles should collide with ground (layer 1) and walls (layer 2)
	collision_layer = 32  # Layer 6 (blood particles)
	collision_mask = 1 | 2  # Ground (layer 1) and walls (layer 2)
	
	# Velocity will be set by set_hit_direction() when called
	
	# Random rotation
	angular_velocity = randf_range(-5.0, 5.0)
	
	# Random scale
	var scale_factor = randf_range(0.8, 1.2)
	scale = Vector2(scale_factor, scale_factor)
	
	# Random color variation
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var color_variation = randf_range(0.8, 1.0)
		sprite.modulate = Color(color_variation, color_variation * 0.7, color_variation * 0.7, 1.0)

func _physics_process(delta: float) -> void:
	lifetime_timer += delta
	
	# Check if particle has hit a surface and should create splatter
	if not has_splattered:
		# Check for floor collision - only floor blood when actually on floor
		if is_on_floor() and linear_velocity.length() < 100.0:
			create_floor_blood_splatter()
			has_splattered = true
		# Some particles explode in mid-air to create wall blood effect
		elif lifetime_timer > 0.4 and randf() < 0.01:  # 1% chance after 0.4 seconds
			create_wall_blood_splatter()
			has_splattered = true
	
	# Remove particle after lifetime
	if lifetime_timer >= particle_lifetime:
		queue_free()


func is_on_floor() -> bool:
	# More reliable floor detection using raycast
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, 30)
	)
	query.collision_mask = 1  # Ground layer
	
	var result = space_state.intersect_ray(query)
	if result.size() > 0:
		# Check if we're actually close to the ground
		var distance = global_position.distance_to(result.position)
		return distance < 25.0
	
	return false


func create_floor_blood_splatter() -> void:
	if has_splattered:
		return
		
	# Only create splatter with certain probability
	if randf() > splatter_chance:
		return
	
	_create_floor_blood_splatter()
	has_splattered = true

func create_wall_blood_splatter() -> void:
	if has_splattered:
		return
		
	# Only create splatter with certain probability
	if randf() > splatter_chance:
		return
	
	_create_wall_blood_splatter()
	has_splattered = true


func _create_floor_blood_splatter() -> void:
	# Create floor blood splatter using the new sprites
	var splatter = Node2D.new()
	get_tree().current_scene.add_child(splatter)
	splatter.global_position = global_position + Vector2(0, -5)  # 5 pixels up
	
	# Add sprite
	var sprite = Sprite2D.new()
	splatter.add_child(sprite)
	
	# Set z-index to be behind player and enemies but above ground
	sprite.z_index = 1  # Above ground, below player/enemies
	
	# Choose random floor blood sprite
	var floor_sprites = [
		"res://assets/effects/blood fx/blood_floor1.png",
		"res://assets/effects/blood fx/blood_floor2.png", 
		"res://assets/effects/blood fx/blood_floor3.png",
		"res://assets/effects/blood fx/blood_floor4.png"
	]
	var random_sprite = floor_sprites[randi() % floor_sprites.size()]
	sprite.texture = load(random_sprite)
	
	# NO rotation - keep blood splatter flat on floor
	splatter.rotation = 0.0
	
	# Random scale for variety
	var scale_factor = randf_range(0.8, 1.2)
	splatter.scale = Vector2(scale_factor, scale_factor)
	
	# Add fade out effect
	var tween = create_tween()
	tween.tween_property(splatter, "modulate:a", 0.0, 10.0)
	tween.tween_callback(func(): splatter.queue_free())

func _create_wall_blood_splatter() -> void:
	# Create wall blood splatter using the new sprites
	var splatter = Node2D.new()
	get_tree().current_scene.add_child(splatter)
	splatter.global_position = global_position
	
	# Add sprite
	var sprite = Sprite2D.new()
	splatter.add_child(sprite)
	
	# Set z-index to be behind ground tiles
	sprite.z_index = -1  # Behind ground tiles
	
	# Choose random wall blood sprite
	var wall_sprites = [
		"res://assets/effects/blood fx/blood_wall1.png",
		"res://assets/effects/blood fx/blood_wall2.png", 
		"res://assets/effects/blood fx/blood_wall3.png",
		"res://assets/effects/blood fx/blood_wall4.png"
	]
	var random_sprite = wall_sprites[randi() % wall_sprites.size()]
	sprite.texture = load(random_sprite)
	
	# Rotate based on wall direction
	var velocity_direction = linear_velocity.normalized()
	var wall_angle = velocity_direction.angle()
	splatter.rotation = wall_angle + PI/2  # Perpendicular to wall
	
	# Random scale for variety
	var scale_factor = randf_range(0.8, 1.2)
	splatter.scale = Vector2(scale_factor, scale_factor)
	
	# Add fade out effect
	var tween = create_tween()
	tween.tween_property(splatter, "modulate:a", 0.0, 10.0)
	tween.tween_callback(func(): splatter.queue_free())
