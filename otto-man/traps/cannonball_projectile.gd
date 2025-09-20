extends Area2D

const SPEED = 600.0
const EXPLOSION_RADIUS = 150.0  # Daha büyük patlama çapı (80'den 150'ye)
const DAMAGE = 50.0
const LIFETIME = 3.0

# Knockback properties - Heavy enemy'nin değerlerini base alıyorum
const KNOCKBACK_FORCE = 500.0    # Horizontal knockback
const KNOCKBACK_UP_FORCE = 300.0 # Vertical knockback (yukarı itme)

var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2
var explosion_scene = preload("res://effects/hit_effect.tscn")
var direct_hit_target: Node = null
var has_hit_anything: bool = false  # Çifte hasar önleme için

# Patlama range gösterimi için
var explosion_range_visual_scene = preload("res://effects/explosion_range_visual.tscn")
var explosion_shockwave_scene = preload("res://effects/explosion_shockwave.tscn")
var explosion_multi_shockwave_scene = preload("res://effects/explosion_multi_shockwave.tscn")

# Shockwave effect seçimi (0=tek ring, 1=çoklu ring)
var shockwave_type: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready():
	# 4-frame rotating animation setup
	if sprite:
		sprite.sprite_frames = SpriteFrames.new()
		sprite.sprite_frames.add_animation("rotate")
		
		var texture = preload("res://objects/dungeon/traps/cannon_trap_ball.png")
		if texture:
			var frame_width = texture.get_width() / 4
			var frame_height = texture.get_height()
			
			for i in range(4):
				var atlas = AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
				sprite.sprite_frames.add_frame("rotate", atlas)
			
			sprite.sprite_frames.set_animation_speed("rotate", 8.0)
			sprite.play("rotate")
			
			# Direction-based flipping for smoke trail
			if direction.x < 0:
				sprite.scale.x = -1
		else:
			# Fallback: create a simple colored circle
			_create_fallback_sprite()
	else:
		# Create a simple sprite as fallback
		_create_fallback_sprite()
	
	# Set initial velocity
	velocity = direction * SPEED
	
	# Set up collision detection
	collision_layer = CollisionLayers.NONE  # Cannonball doesn't need to be in any layer
	collision_mask = CollisionLayers.PLAYER_HURTBOX | CollisionLayers.PLAYER | CollisionLayers.WORLD
	
	# Enable both monitoring types
	monitoring = true
	monitorable = true
	
	# Auto-destroy after lifetime
	var timer = get_tree().create_timer(LIFETIME)
	timer.timeout.connect(_explode.bind(null))
	
	# Connect collision for both areas and bodies
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	position += velocity * delta

func set_velocity(vel: Vector2):
	velocity = vel

func set_direction(dir: Vector2):
	direction = dir.normalized()
	velocity = direction * SPEED
	
	# Update sprite flipping
	if sprite and direction.x < 0:
		sprite.scale.x = -1
	elif sprite:
		sprite.scale.x = 1

func _on_area_entered(area):
	if has_hit_anything:
		return # Çifte hasar önleme
		
	
	# Safe collision layer check
	var area_collision_layer = 0
	if area.has_method("get") and "collision_layer" in area:
		area_collision_layer = area.collision_layer
	
	# Player hurtbox layer 4 (8) veya hurtbox grubunda olanları kontrol et
	# But also verify the parent is actually a player
	var is_player_hurtbox = ((area_collision_layer == CollisionLayers.PLAYER_HURTBOX or area.is_in_group("hurtbox") or area.name == "Hurtbox") and
							area.get_parent() != null and
							area.get_parent().is_in_group("player") and
							not area.get_parent().is_in_group("trap") and
							not area.get_parent().is_in_group("enemy"))
	
	if is_player_hurtbox:
		
		has_hit_anything = true
		direct_hit_target = area.get_parent()
		
		# Apply damage and knockback to player directly
		_apply_direct_hit_to_player(direct_hit_target)
		
		# Then explode (which will skip this target)
		_explode(direct_hit_target)

func _on_body_entered(body):
	if has_hit_anything:
		return # Çifte hasar önleme
		
	
	# Safe collision layer check - some objects like TileMap don't have collision_layer
	var body_collision_layer = 0
	if body.has_method("get") and "collision_layer" in body:
		body_collision_layer = body.collision_layer
	
	# Player ile çarpışma kontrolü - be more specific about what constitutes a player
	var is_actual_player = (body.is_in_group("player") and 
							(body.name == "Player" or body.name.to_lower().contains("player")) and
							not body.is_in_group("trap") and not body.is_in_group("enemy"))
	
	if body_collision_layer == CollisionLayers.PLAYER and is_actual_player:
		
		has_hit_anything = true
		direct_hit_target = body
		
		# Apply damage and knockback to player directly
		_apply_direct_hit_to_player(body)
		
		# Then explode (which will skip this target)
		_explode(body)
	elif is_actual_player:
		# Player detected by group even if collision_layer check failed
		
		has_hit_anything = true
		direct_hit_target = body
		
		# Apply damage and knockback to player directly
		_apply_direct_hit_to_player(body)
		
		# Then explode (which will skip this target)
		_explode(body)
	else:
		# Hit wall, ground, or any other body - explode
		has_hit_anything = true
		_explode()

func _apply_direct_hit_to_player(player: Node):
	# Verify this is actually a player object
	if not player.is_in_group("player") and player.name != "Player":
		# Still apply damage if the object can take it
		if player.has_method("take_damage"):
			player.take_damage(DAMAGE)
		return
	
	# Direct damage
	if player.has_method("take_damage"):
		player.take_damage(DAMAGE)
		
		# Show damage number for direct hit (optional - comment out if causing issues)
		# _show_damage_number(player.global_position, DAMAGE)
	
	# Apply knockback using player's system
	_apply_player_knockback(player, 1.0)  # Full force for direct hit

func _explode(excluded_target: Node = null):
	
	# Create explosion effect
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		get_tree().current_scene.add_child(explosion)
		explosion.global_position = global_position
	
	# Show explosion range visual
	_show_explosion_range()
	
	# Show shockwave effect
	_show_shockwave_effect()
	
	# Area damage with knockback using multiple collision masks
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = EXPLOSION_RADIUS
	query.shape = circle_shape
	query.transform = Transform2D(0, global_position)
	
	# Check both player hurtbox (layer 4) and player body (layer 2)
	query.collision_mask = CollisionLayers.PLAYER_HURTBOX | CollisionLayers.PLAYER
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result.collider
		if body == excluded_target:
			continue # Skip the direct hit target to prevent double damage
		
		# Safe collision layer check
		var body_collision_layer = 0
		if body.has_method("get") and "collision_layer" in body:
			body_collision_layer = body.collision_layer
			
		
		# Check if it's player (by layer or group or name) - but be more specific
		var is_player = ((body_collision_layer == CollisionLayers.PLAYER or body_collision_layer == CollisionLayers.PLAYER_HURTBOX or 
						body.is_in_group("player") or body.name == "Player") and
						(body.name == "Player" or body.name.to_lower().contains("player")) and
						not body.is_in_group("trap") and not body.is_in_group("enemy"))
		var is_enemy = body.is_in_group("enemy")
		
		if is_player or is_enemy:
			var distance = global_position.distance_to(body.global_position)
			var damage_multiplier = 1.0 - (distance / EXPLOSION_RADIUS)
			damage_multiplier = clamp(damage_multiplier, 0.1, 1.0)
			
			var explosion_damage = DAMAGE * damage_multiplier
			var knockback_force = _calculate_knockback_force(body) * damage_multiplier
			
			
			# Apply damage with knockback
			if body.has_method("take_damage"):
				body.take_damage(explosion_damage, knockback_force)
				
				# Show damage number (optional - comment out if causing issues)
				# _show_damage_number(body.global_position, explosion_damage)
			
			# Additional knockback for player using the existing system
			if is_player:
				_apply_player_knockback(body, damage_multiplier)
	
	queue_free()

func _calculate_knockback_force(target: Node) -> float:
	# Heavy enemy örneğini takip ediyorum
	var base_force = KNOCKBACK_FORCE
	
	# Distance-based force calculation
	var distance = global_position.distance_to(target.global_position)
	var force_multiplier = 1.0 - (distance / EXPLOSION_RADIUS)
	force_multiplier = clamp(force_multiplier, 0.3, 1.0)
	
	return base_force * force_multiplier

func _apply_player_knockback(player: Node, force_multiplier: float = 1.0):
	# Verify this is actually a player object before applying knockback
	if not player.is_in_group("player") and player.name != "Player":
		return
	
	# Check if player has the required knockback properties
	if not player.has_method("set") or not player.has_method("get"):
		return
	
	# Check if player has the knockback properties we need
	if not "last_hit_knockback" in player or not "last_hit_position" in player:
		return
	
	# Knockback direction calculation
	var knockback_direction = (player.global_position - global_position).normalized()
	
	# Set up knockback data like heavy enemy does
	var knockback_data = {
		"force": KNOCKBACK_FORCE * force_multiplier,
		"up_force": KNOCKBACK_UP_FORCE * force_multiplier
	}
	
	# Store knockback data in player (hurt_state.gd will use this)
	player.last_hit_knockback = knockback_data
	player.last_hit_position = global_position
	
	# Apply velocity directly like heavy enemy does
	if "velocity" in player and knockback_direction.x != 0:
		player.velocity = Vector2(
			knockback_direction.x * knockback_data.force,
			-knockback_data.up_force  # Negative for upward force
		)
	
	# Force player into hurt state to process knockback properly
	if player.has_method("get_node"):
		var state_machine = player.get_node_or_null("StateMachine")
		if state_machine and state_machine.has_method("transition_to"):
			state_machine.transition_to("Hurt")
			print("[Cannonball] Forced player into Hurt state for knockback")
	
	print("[Cannonball] Applied knockback to player: force=" + str(knockback_data.force) + ", up_force=" + str(knockback_data.up_force))

func _create_fallback_sprite():
	print("[Cannonball] Creating fallback sprite")
	# Remove any existing sprite
	if sprite:
		sprite.queue_free()
	
	# Create a simple Sprite2D as fallback
	var fallback_sprite = Sprite2D.new()
	fallback_sprite.name = "FallbackSprite"
	
	# Create a simple black circle texture
	var image = Image.create(16, 16, false, Image.FORMAT_RGB8)
	image.fill(Color.TRANSPARENT)
	
	# Draw a black circle
	for x in range(16):
		for y in range(16):
			var center = Vector2(8, 8)
			var distance = Vector2(x, y).distance_to(center)
			if distance <= 7:
				image.set_pixel(x, y, Color.BLACK)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	fallback_sprite.texture = texture
	
	add_child(fallback_sprite)
	print("[Cannonball] Fallback sprite created and added")

func _show_explosion_range():
	# Create explosion range visual
	var explosion_range_visual = explosion_range_visual_scene.instantiate()
	get_tree().current_scene.add_child(explosion_range_visual)
	explosion_range_visual.global_position = global_position
	
	# Scale the visual to match the explosion radius (base texture is 300px for 150 radius)
	var scale_factor = EXPLOSION_RADIUS / 150.0
	explosion_range_visual.scale = Vector2(scale_factor, scale_factor)

func _show_shockwave_effect():
	# Create shockwave effect based on type
	var shockwave
	if shockwave_type == 1:
		shockwave = explosion_multi_shockwave_scene.instantiate()
	else:
		shockwave = explosion_shockwave_scene.instantiate()
	
	get_tree().current_scene.add_child(shockwave)
	shockwave.global_position = global_position
	
	# Set explosion radius if the method exists
	if shockwave.has_method("set_explosion_radius"):
		shockwave.set_explosion_radius(EXPLOSION_RADIUS)

func _show_damage_number(position: Vector2, damage: float):
	# Create damage number using existing system
	var damage_number_scene = preload("res://effects/damage_number.tscn")
	if damage_number_scene:
		var damage_number = damage_number_scene.instantiate()
		get_tree().current_scene.add_child(damage_number)
		damage_number.global_position = position
		
		# Try to call setup safely
		if damage_number.has_method("setup"):
			# Use call_deferred to avoid timing issues
			damage_number.call_deferred("setup", int(damage), false, true)
		else:
			print("[Cannonball] Warning: damage_number doesn't have setup method")
	
