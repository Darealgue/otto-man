class_name CannonShotProjectile
extends CharacterBody2D

# Projectile properties
var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: float = 30.0
var lifetime: float = 3.0

# Node references
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Set initial velocity
	velocity = direction * speed
	
	# Start lifetime timer
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_lifetime_timeout)
	timer.start()
	
	print("[CannonShot] Created with direction: ", direction, " speed: ", speed)

func _physics_process(delta: float) -> void:
	# Move projectile
	move_and_slide()
	
	# Check for collisions
	if is_on_wall():
		_handle_wall_hit()
	elif is_on_floor():
		_handle_ground_hit()
	
	# Check for player collision
	var collision_count = get_slide_collision_count()
	for i in collision_count:
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider.is_in_group("player"):
			_handle_player_hit(collider)

func _handle_wall_hit() -> void:
	print("[CannonShot] Hit wall, destroying")
	queue_free()

func _handle_ground_hit() -> void:
	print("[CannonShot] Hit ground, destroying")
	queue_free()

func _handle_player_hit(player: Node) -> void:
	print("[CannonShot] Hit player, dealing damage: ", damage)
	player.take_damage(damage)
	queue_free()

func _on_lifetime_timeout() -> void:
	print("[CannonShot] Lifetime expired, destroying")
	queue_free()

func set_direction(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	velocity = direction * speed

func set_speed(new_speed: float) -> void:
	speed = new_speed
	velocity = direction * speed

func set_damage(new_damage: float) -> void:
	damage = new_damage
