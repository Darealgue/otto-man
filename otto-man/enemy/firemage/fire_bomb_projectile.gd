extends Area2D
class_name FireBombProjectile

const GRAVITY = 980.0
const BOUNCE_DAMPING = 0.6
const MAX_BOUNCES = 2

var velocity: Vector2 = Vector2.ZERO
var damage: float = 25.0
var explosion_radius: float = 80.0
var bounce_count: int = 0
var has_exploded: bool = false

# Node references
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var explosion_timer: Timer = $ExplosionTimer

# Explosion effect
var explosion_scene = preload("res://effects/explosion_shockwave.tscn")

func _ready() -> void:
	# Setup collision
	collision_layer = CollisionLayers.NONE
	collision_mask = CollisionLayers.PLAYER | CollisionLayers.WORLD
	
	# Enable monitoring
	monitoring = true
	monitorable = true
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Setup explosion timer
	explosion_timer.wait_time = 3.0  # 3 saniye sonra patla
	explosion_timer.timeout.connect(_explode)
	explosion_timer.start()
	
	# Play rotation animation
	if sprite:
		sprite.play("rotate")

func _physics_process(delta: float) -> void:
	if has_exploded:
		return
	
	# Apply gravity
	velocity.y += GRAVITY * delta
	
	# Move
	global_position += velocity * delta
	
	# Rotate sprite based on velocity (tumbling effect)
	if sprite:
		var rotation_speed = velocity.length() * 0.01  # Rotation speed based on velocity
		sprite.rotation += rotation_speed * delta
	
	# Check for ground collision
	if is_on_floor():
		_handle_ground_impact()

func is_on_floor() -> bool:
	# Simple ground check using raycast
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, 20)
	)
	query.collision_mask = CollisionLayers.WORLD
	
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func _handle_ground_impact() -> void:
	if bounce_count < MAX_BOUNCES:
		# Bounce
		velocity.y = -velocity.y * BOUNCE_DAMPING
		velocity.x *= 0.8  # Reduce horizontal velocity
		bounce_count += 1
	else:
		# Explode on final impact
		_explode()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_explode()

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent and parent.is_in_group("player"):
		_explode()

func _explode() -> void:
	if has_exploded:
		return
	
	has_exploded = true
	
	# Create explosion effect
	var explosion = explosion_scene.instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position
	
	# Deal damage to nearby players
	_deal_explosion_damage()
	
	# Remove projectile
	queue_free()

func _deal_explosion_damage() -> void:
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if not is_instance_valid(player):
			continue
		
		var distance = global_position.distance_to(player.global_position)
		if distance <= explosion_radius:
			# Calculate damage based on distance
			var damage_multiplier = 1.0 - (distance / explosion_radius)
			var final_damage = damage * damage_multiplier
			
			# Apply damage to player
			if player.has_method("take_damage"):
				player.take_damage(final_damage)
			elif player.has_method("hurt"):
				player.hurt(final_damage)

func set_direction(dir: Vector2) -> void:
	velocity = dir * 300.0  # Initial speed

func set_speed(speed: float) -> void:
	velocity = velocity.normalized() * speed

func set_damage(dmg: float) -> void:
	damage = dmg

func set_radius(radius: float) -> void:
	explosion_radius = radius
