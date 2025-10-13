extends Area2D
class_name FireBombProjectile

const GRAVITY = 980.0
const BOUNCE_DAMPING = 0.8  # keep more energy per bounce
const MAX_BOUNCES = 4  # will be randomized between 1-4

var velocity: Vector2 = Vector2.ZERO
var damage: float = 25.0
var explosion_radius: float = 80.0
var bounce_count: int = 0
var max_bounces: int = 0  # randomized per bomb
var has_exploded: bool = false
var owner_id: int = 0

# Node references
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var explosion_timer: Timer = $ExplosionTimer
var hitbox: EnemyHitbox

# Explosion effect
var explosion_scene = preload("res://effects/explosion_shockwave.tscn")

func _ready() -> void:
	# Randomize bounce count for this bomb (1-4 bounces)
	max_bounces = randi_range(1, MAX_BOUNCES)
	
	# Setup collision
	collision_layer = CollisionLayers.NONE
	collision_mask = CollisionLayers.PLAYER | CollisionLayers.WORLD
	
	# Enable monitoring
	monitoring = true
	monitorable = true
	
	# Connect signals for Area2D overlaps (fallback)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Create internal EnemyHitbox so player Hurtbox can parry/block/dodge this projectile
	hitbox = EnemyHitbox.new()
	hitbox.add_to_group("hitbox")
	hitbox.add_to_group("enemy_hitbox")
	hitbox.collision_layer = CollisionLayers.ENEMY_HITBOX
	hitbox.collision_mask = CollisionLayers.PLAYER_HURTBOX
	hitbox.damage = damage
	hitbox.knockback_force = 200.0
	hitbox.knockback_up_force = 120.0
	hitbox.setup_attack("molotov", true, 0.0)  # parryable
	hitbox.set_meta("owner_id", owner_id)
	add_child(hitbox)
	# small circle shape
	var hshape := CollisionShape2D.new()
	var hcircle := CircleShape2D.new()
	hcircle.radius = 10
	hshape.shape = hcircle
	hitbox.add_child(hshape)
	hitbox.enable()
	
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
	
	# Predictive collision for walls/floor: ray to next position
	var next_pos = global_position + velocity * delta
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, next_pos)
	query.collision_mask = CollisionLayers.WORLD
	var ray = space_state.intersect_ray(query)
	if ray.size() > 0:
		# reflect by collision normal, apply damping
		var normal: Vector2 = ray.normal
		velocity = velocity.bounce(normal) * BOUNCE_DAMPING
		bounce_count += 1
		# slight horizontal retention for ground bounces
		if abs(normal.y) > 0.7 and abs(velocity.y) < 150:
			velocity.y = -150
		if bounce_count >= max_bounces:
			_explode()
	else:
		# Move when no hit
		global_position = next_pos
	
	# Rotate sprite based on velocity (tumbling effect)
	if sprite:
		var rotation_speed = velocity.length() * 0.01  # Rotation speed based on velocity
		sprite.rotation += rotation_speed * delta
	
	# Follow with internal hitbox
	if is_instance_valid(hitbox):
		hitbox.global_position = global_position

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
	# kept for potential external calls (unused with new reflection)
	if bounce_count < max_bounces:
		velocity.y = -velocity.y * BOUNCE_DAMPING
		velocity.x *= 0.95
		bounce_count += 1
	else:
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
	
	# Disable flight hitbox
	if is_instance_valid(hitbox):
		hitbox.disable()
	
	# Spawn explosion hitbox compatible with parry/block/dodge
	var eh := EnemyHitbox.new()
	eh.add_to_group("hitbox")
	eh.add_to_group("enemy_hitbox")
	eh.collision_layer = CollisionLayers.ENEMY_HITBOX
	eh.collision_mask = CollisionLayers.PLAYER_HURTBOX
	eh.damage = damage
	eh.knockback_force = 300.0
	eh.knockback_up_force = 180.0
	eh.setup_attack("molotov_explosion", true, 0.0)
	eh.set_meta("owner_id", owner_id)
	var ehs := CollisionShape2D.new()
	var ec := CircleShape2D.new()
	ec.radius = explosion_radius
	ehs.shape = ec
	eh.add_child(ehs)
	eh.global_position = global_position
	get_tree().current_scene.add_child(eh)
	eh.enable()
	# auto free after short duration
	var t := get_tree().create_timer(0.35)
	t.timeout.connect(func():
		if is_instance_valid(eh):
			eh.queue_free()
	)
	
	# Remove projectile
	queue_free()

func _deal_explosion_damage() -> void:
	pass  # replaced by EnemyHitbox system

func set_direction(dir: Vector2) -> void:
	velocity = dir * 350.0  # a bit faster initial speed

func set_speed(speed: float) -> void:
	velocity = velocity.normalized() * speed

func set_damage(dmg: float) -> void:
	damage = dmg

func set_radius(radius: float) -> void:
	explosion_radius = radius

func set_owner_id(id: int) -> void:
	owner_id = id
	if is_instance_valid(hitbox):
		hitbox.set_meta("owner_id", owner_id)
