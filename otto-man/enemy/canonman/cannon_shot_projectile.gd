class_name CannonShotProjectile
extends CharacterBody2D

# Projectile properties
var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: float = 30.0
var lifetime: float = 3.0
var knockback_force: float = 200.0
var knockback_up_force: float = 100.0
var owner_id: int = 0

# Simple bounce physics
var gravity: float = 980.0
var bounce_damping: float = 0.7
var max_bounces: int = 3
var bounce_count: int = 0
var has_bounced: bool = false  # Track if projectile has bounced yet
var pre_bounce_gravity_scale: float = 0.05  # Very light gravity before first bounce (lands later)
var is_breaking: bool = false  # Prevent double break
var bounce_cooldown: float = 0.0  # Prevent rapid multiple bounces in place

# Node references
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
var hitbox: EnemyHitbox

func _ready() -> void:
	# Set initial velocity
	velocity = direction.normalized() * speed
	
	# Ensure sprite is visible and playing a non-break animation
	if is_instance_valid(sprite):
		sprite.visible = true
		if sprite.sprite_frames:
			var anim_to_play := ""
			if sprite.sprite_frames.has_animation("cannonball"):
				anim_to_play = "cannonball"
			elif sprite.sprite_frames.has_animation("cannonball_fly"):
				anim_to_play = "cannonball_fly"
			elif sprite.sprite_frames.has_animation("default"):
				anim_to_play = "default"
			else:
				# Pick the first animation that is not a break animation
				for a in sprite.sprite_frames.get_animation_names():
					if typeof(a) == TYPE_STRING and not String(a).contains("break"):
						anim_to_play = a
						break
			if anim_to_play != "":
				sprite.frame = 0
				sprite.play(anim_to_play)
	
	# Create hitbox for damage
	hitbox = EnemyHitbox.new()
	hitbox.damage = damage
	hitbox.knockback_force = knockback_force
	hitbox.knockback_up_force = knockback_up_force
	hitbox.add_to_group("hitbox")
	hitbox.add_to_group("enemy_hitbox")
	hitbox.collision_layer = CollisionLayers.ENEMY_HITBOX
	hitbox.collision_mask = CollisionLayers.PLAYER_HURTBOX
	hitbox.setup_attack("cannonball", true, 0.0)
	hitbox.set_meta("owner_id", owner_id)
	add_child(hitbox)
	hitbox.position = Vector2.ZERO
	
	# When we hit the player hurtbox, play break animation and remove
	hitbox.area_entered.connect(func(a: Area2D):
		if is_breaking:
			return
		if a and a.is_in_group("player_hurtbox"):
			break_and_free()
	)
	
	# Add collision shape
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	hitbox.add_child(shape)
	hitbox.enable()
	
	# Lifetime timer
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_lifetime_timeout)
	timer.start()
	
	print("[CannonShot] Spawned. hitbox layer:", hitbox.collision_layer, " mask:", hitbox.collision_mask)

func _physics_process(delta: float) -> void:
	# Apply gravity: light gravity before first bounce for a gentle arc, full after bounce
	if has_bounced:
		velocity.y += gravity * delta
	else:
		velocity.y += gravity * pre_bounce_gravity_scale * delta
	
	# Move projectile
	move_and_slide()
	
	# Update bounce cooldown
	if bounce_cooldown > 0.0:
		bounce_cooldown = max(0.0, bounce_cooldown - delta)

	# Follow the projectile with the internal hitbox
	if is_instance_valid(hitbox):
		hitbox.global_position = global_position
	
	# Rotate sprite to face movement direction
	if velocity.length() > 0.01 and is_instance_valid(sprite):
		sprite.rotation = velocity.angle()
	
	# Bounce detection (respect cooldown so we don't triple-bounce in the same spot)
	if bounce_cooldown <= 0.0 and (is_on_floor() or is_on_wall()):
		if bounce_count < max_bounces:
			bounce_count += 1
			has_bounced = true  # Enable gravity after first bounce
			bounce_cooldown = 0.12  # small cooldown between bounces
			
			if is_on_floor():
				# Ground bounce - create 45 degree upward angle
				var bounce_angle = 45.0  # 45 degrees
				var bounce_speed = velocity.length() * bounce_damping
				velocity.x = cos(deg_to_rad(bounce_angle)) * bounce_speed * sign(velocity.x)
				velocity.y = -sin(deg_to_rad(bounce_angle)) * bounce_speed
				print("[CannonShot] Ground bounce #", bounce_count, " 45° angle, New velocity:", velocity)
			elif is_on_wall():
				# Wall bounce - reverse X velocity
				velocity.x = -velocity.x * bounce_damping
				has_bounced = true  # Enable gravity for wall bounces too
				print("[CannonShot] Wall bounce #", bounce_count, " New velocity:", velocity)
		else:
			# Max bounces reached
			print("[CannonShot] Max bounces reached, breaking")
			break_and_free()

func _on_lifetime_timeout() -> void:
	break_and_free()

func set_direction(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	velocity = direction.normalized() * speed

func set_speed(new_speed: float) -> void:
	speed = new_speed
	velocity = direction.normalized() * speed

func set_damage(new_damage: float) -> void:
	damage = new_damage
	if is_instance_valid(hitbox):
		hitbox.damage = new_damage

func set_owner_id(id: int) -> void:
	owner_id = id
	if is_instance_valid(hitbox):
		hitbox.set_meta("owner_id", owner_id)

func break_and_free() -> void:
	if is_breaking:
		return
	is_breaking = true
	
	# Stop movement and disable damage
	velocity = Vector2.ZERO
	if is_instance_valid(hitbox):
		hitbox.disable()
	
	# Play break animation if it exists, then free
	var played := false
	if is_instance_valid(sprite) and sprite.sprite_frames:
		var break_anim := ""
		if sprite.sprite_frames.has_animation("cannonball_break"):
			break_anim = "cannonball_break"
		else:
			# Find any animation that contains 'break' (case-insensitive)
			for a in sprite.sprite_frames.get_animation_names():
				var name_str := String(a)
				if name_str.to_lower().find("break") != -1:
					break_anim = name_str
					break
		if break_anim != "":
			played = true
			sprite.rotation = 0.0
			sprite.frame = 0
			sprite.play(break_anim)
			print("[CannonShot] Playing break animation:", break_anim)
			# Free after animation
			sprite.animation_finished.connect(func():
				if is_instance_valid(self):
					queue_free()
			, CONNECT_ONE_SHOT)
	
	if not played:
		# Fallback small delay to avoid abrupt pop
		var t := get_tree().create_timer(0.15)
		t.timeout.connect(func():
			if is_instance_valid(self):
				queue_free()
		)
