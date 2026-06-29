class_name FlyingEnemy
extends "res://enemy/base_enemy.gd"

# Constants for movement
const CHASE_SPEED_MULTIPLIER = 1.78
const SWOOP_SPEED_MULTIPLIER = 2.28
const CIRCLE_RADIUS = 165.0
const CIRCLE_SPEED = 4.6
const NEUTRAL_SPEED = 150.0
const ESCAPE_SPEED = 400.0  # Speed when flying away after summoner death
const RETURN_SPEED = 400.0  # Speed when returning to summoner
const RETURN_COOLDOWN = 3.0  # Time before bird can return to summoner
const HP_MULTIPLIER = 0.5
const DODGE_BURST_SPEED_MULTIPLIER = 2.35
const DODGE_BURST_MIN_TIME = 0.18
const DODGE_BURST_MAX_TIME = 0.30
const DODGE_COOLDOWN_MIN = 0.55
const DODGE_COOLDOWN_MAX = 1.10
const FACING_MIN_VX := 6.0

# State tracking
var circle_angle: float = 0.0
var swoop_target_pos: Vector2
var is_neutral: bool = false
var neutral_direction: Vector2
var neutral_timer: float = 0.0
var is_escaping: bool = false  # Track if we're flying away after summoner death
var is_returning: bool = false  # Track if we're returning to summoner
var summoner: Node2D = null   # Reference to our summoner
var return_timer: float = RETURN_COOLDOWN  # Track time before allowing return
var dodge_burst_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_burst_velocity: Vector2 = Vector2.ZERO

# Node references
@onready var wall_detector: RayCast2D = $WallDetector
@onready var ceiling_detector: RayCast2D = $CeilingDetector
@onready var floor_detector: RayCast2D = $FloorDetector


func _ready() -> void:
	super._ready()
	# Kuslari daha cabuk dusur: cani yariya indir.
	health = maxf(1.0, health * HP_MULTIPLIER)
	if stats:
		stats.max_health = maxf(1.0, stats.max_health * HP_MULTIPLIER)
	if health_bar:
		health_bar.setup(health)
		health_bar.update_health(health)
	# Dead animasyonu loop'ta kalmasin.
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("dead"):
		sprite.sprite_frames.set_animation_loop("dead", false)
	
	# Set sleep distances for performance optimization
	sleep_distance = 1500.0  # Distance at which enemy goes to sleep
	wake_distance = 1200.0  # Distance at which enemy wakes up
	
	# Initialize combat components with our own stats
	if hitbox:
		var atk_damage: float = float(stats.attack_damage) if stats != null else 10.0
		var kb_resist: float = float(stats.knockback_resistance) if stats != null else 1.0
		hitbox.damage = atk_damage
		hitbox.knockback_force = 200.0 * kb_resist
		hitbox.enable()
	else:
		push_error("Flying enemy missing hitbox!")
	
	# Find and setup hurtbox - try both capitalization variants
	var hurtbox_node = get_node_or_null("HurtBox")
	if not hurtbox_node:
		hurtbox_node = get_node_or_null("Hurtbox")
	if not hurtbox_node:
		hurtbox_node = get_node_or_null("hurtbox")
	
	if hurtbox_node:
		hurtbox = hurtbox_node
		
		# Remove from any existing hurtbox groups to avoid duplicates
		if hurtbox.is_in_group("HurtBox"):
			hurtbox.remove_from_group("HurtBox")
		if hurtbox.is_in_group("hurtbox"):
			hurtbox.remove_from_group("hurtbox")
		if hurtbox.is_in_group("Hurtbox"):
			hurtbox.remove_from_group("Hurtbox")
		
		# Add to all common case variants to ensure compatibility
		hurtbox.add_to_group("hurtbox")
		hurtbox.add_to_group("HurtBox")
	else:
		push_error("Flying enemy missing hurtbox!")
	
	change_behavior("idle")

func _handle_child_behavior(delta: float) -> void:
	# Update return timer
	if return_timer > 0:
		return_timer -= delta
	if dodge_burst_timer > 0.0:
		dodge_burst_timer -= delta
		if dodge_burst_timer <= 0.0:
			dodge_burst_velocity = Vector2.ZERO
	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer -= delta
	
	match current_behavior:
		"idle":
			_handle_idle_state(delta)
		"chase":
			_handle_chase_state(delta)
		"swoop":
			_handle_swoop_state(delta)
		"neutral":
			if is_escaping:
				_handle_escape_state(delta)
			elif is_returning:
				_handle_return_state(delta)
			else:
				_handle_neutral_state(delta)
			
	_update_animation_state()

func _handle_idle_state(delta: float) -> void:
	target = update_stealth_target(delta)
	if target == null:
		target = get_nearest_player()
	if target and is_instance_valid(target):
		change_behavior("chase")
	elif not is_returning and summoner and is_instance_valid(summoner):
		# Only allow return if cooldown has elapsed
		if return_timer <= 0:
			is_returning = true
			change_behavior("neutral")
		else:
			change_behavior("chase")  # Keep chasing until cooldown is done

func _handle_return_state(delta: float) -> void:
	if not summoner or not is_instance_valid(summoner):
		queue_free()
		return
		
	# Disable collisions while returning
	set_collision_layer_value(3, false)  # Layer 3 is typically for enemy collision
	set_collision_mask_value(1, false)   # Layer 1 is typically for environment
	
	# Fly towards summoner - use stats-based speed
	var direction = global_position.direction_to(summoner.global_position)
	var return_speed = stats.movement_speed * 2.0  # 2x normal speed for return
	velocity = direction * return_speed
	
	# DEBUG: Print speed information (reduced frequency)
	if randf() < 0.01:  # Only print 1% of the time
		print("[FlyingEnemy] Return - Speed: %s" % return_speed)
	# Use move_and_slide() without collision
	position += velocity * delta
	
	_update_facing_from_velocity()
	
	# Check if we've reached the summoner
	if global_position.distance_to(summoner.global_position) < 50:
		# Tell summoner we're back
		if summoner.has_method("_on_bird_returned"):
			summoner.call("_on_bird_returned", self)
		queue_free()

func _handle_chase_state(delta: float) -> void:
	if not target or not is_instance_valid(target):
		change_behavior("idle")
		return
		
	# Calculate desired position on circle around player
	circle_angle += CIRCLE_SPEED * delta
	var circle_pos = target.global_position + Vector2(cos(circle_angle), sin(circle_angle)) * CIRCLE_RADIUS
	
	var to_player: Vector2 = global_position.direction_to(target.global_position)
	var tangent: Vector2 = Vector2(-to_player.y, to_player.x)
	# Move towards circle position + hafif tangential sürüş ile kıvrak yörünge.
	var to_circle: Vector2 = global_position.direction_to(circle_pos)
	var direction: Vector2 = (to_circle + tangent * 0.42).normalized()
	var final_speed = stats.movement_speed * CHASE_SPEED_MULTIPLIER
	
	# Kısa dodge burst: oyuncuya yakınken anlık sert kaçış manevrası.
	if dodge_burst_timer <= 0.0 and dodge_cooldown_timer <= 0.0:
		var dist_to_player := global_position.distance_to(target.global_position)
		if dist_to_player <= 240.0 and randf() < 2.4 * delta:
			var side_sign := -1.0 if randf() < 0.5 else 1.0
			var dodge_dir: Vector2 = (tangent * side_sign + (-to_player) * 0.30).normalized()
			dodge_burst_velocity = dodge_dir * (stats.movement_speed * DODGE_BURST_SPEED_MULTIPLIER)
			dodge_burst_timer = randf_range(DODGE_BURST_MIN_TIME, DODGE_BURST_MAX_TIME)
			dodge_cooldown_timer = randf_range(DODGE_COOLDOWN_MIN, DODGE_COOLDOWN_MAX)
	
	if dodge_burst_timer > 0.0:
		velocity = dodge_burst_velocity
	else:
		velocity = direction * final_speed
	
	
	# Check for obstacles
	if wall_detector.is_colliding() or ceiling_detector.is_colliding() or floor_detector.is_colliding():
		velocity = velocity.rotated(PI/4)  # Turn away from obstacle
	
	_update_facing_from_velocity()
	
	# Check if target is in range before attempting swoop
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target <= stats.detection_range:
		# Randomly decide to swoop
		if randf() < 0.01:  # 1% chance per frame
			swoop_target_pos = target.global_position
			change_behavior("swoop")
	else:
		change_behavior("idle")

func _handle_swoop_state(delta: float) -> void:
	if not target or not is_instance_valid(target):
		# If we lose target during swoop, check if we should return to summoner
		if not is_returning and summoner and is_instance_valid(summoner):
			is_returning = true
			change_behavior("neutral")
		else:
			change_behavior("idle")
		return
		
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target > stats.detection_range:
		if not is_returning and summoner and is_instance_valid(summoner):
			is_returning = true
			change_behavior("neutral")
		else:
			change_behavior("idle")
		return
		
	# Swoop hedefini biraz canlı güncelle ki hareket öngörülebilir olmasın.
	swoop_target_pos = swoop_target_pos.lerp(target.global_position, clampf(delta * 5.0, 0.0, 1.0))
	var direction = global_position.direction_to(swoop_target_pos)
	var final_speed = stats.movement_speed * SWOOP_SPEED_MULTIPLIER
	velocity = direction * final_speed
	_update_facing_from_velocity()
	
	# DEBUG: Print speed information (reduced frequency)
	if randf() < 0.01:  # Only print 1% of the time
		print("[FlyingEnemy] Swoop - Base Speed: %s, Final Speed: %s" % [stats.movement_speed, final_speed])
	
	# Check if we've reached the swoop target
	var distance_to_swoop_target = global_position.distance_to(swoop_target_pos)
	if distance_to_swoop_target < 20:
		change_behavior("chase")

func _handle_neutral_state(delta: float) -> void:
	neutral_timer += delta
	
	# Change direction occasionally
	if neutral_timer >= 2.0:
		neutral_timer = 0.0
		neutral_direction = Vector2(randf_range(-1, 1), -1).normalized()
	
	# Use stats-based speed instead of constant
	velocity = neutral_direction * stats.movement_speed
	
	# DEBUG: Print speed information (reduced frequency)
	if randf() < 0.01:  # Only print 1% of the time
		print("[FlyingEnemy] Neutral - Speed: %s" % stats.movement_speed)
	
	# Check for obstacles
	if wall_detector.is_colliding() or ceiling_detector.is_colliding() or floor_detector.is_colliding():
		neutral_direction = neutral_direction.rotated(PI/4)
		
	_update_facing_from_velocity()

func _handle_escape_state(delta: float) -> void:
	# Always fly upward and slightly to the side - use stats-based speed
	var escape_speed = stats.movement_speed * 2.0  # 2x normal speed for escape
	velocity = Vector2(neutral_direction.x * escape_speed * 0.3, -escape_speed)
	
	# DEBUG: Print speed information (reduced frequency)
	if randf() < 0.01:  # Only print 1% of the time
		print("[FlyingEnemy] Escape - Speed: %s" % escape_speed)
	
	# Check if we're off screen
	var viewport = get_viewport()
	if viewport:
		var screen_size = viewport.get_visible_rect().size
		var camera = viewport.get_camera_2d()
		if camera:
			var top_of_screen = camera.global_position.y - screen_size.y
			if global_position.y < top_of_screen - 100:  # 100 pixels above screen
				queue_free()

func handle_patrol(delta: float) -> void:
	_handle_idle_state(delta)

func handle_alert(delta: float) -> void:
	_handle_chase_state(delta)

func handle_chase(delta: float) -> void:
	_handle_chase_state(delta)

func handle_hurt_behavior(delta: float) -> void:
	behavior_timer += delta
	# Hurt durumunda hizin hizlica sonmesi, state'ten cikinca ters/yukari kacisi engeller.
	velocity = velocity.move_toward(Vector2.ZERO, 2400.0 * delta)
	
	# Kisa bir hitstun'dan sonra stabil sekilde chase'e don.
	if behavior_timer >= 0.16:
		velocity = Vector2.ZERO
		air_float_timer = 0.0
		change_behavior("chase")
		# Make sure hurtbox is re-enabled
		if hurtbox:
			hurtbox.monitoring = true
			hurtbox.monitorable = true

func take_damage(amount: float, knockback_force: float = 200.0, knockback_up_force: float = -1.0, apply_knockback: bool = true) -> void:
	if current_behavior == "dead":
		return
	# Projectile / DoT hasarini base'de isle; kusa ozel knockback/hurt'u biz yonetecegiz.
	super.take_damage(amount, knockback_force, knockback_up_force, false)
	if current_behavior == "dead":
		return
	if not apply_knockback:
		return
	if invulnerable:
		return
	# Apply knockback
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var dir = (global_position - player.global_position).normalized()
		var up = -knockback_force * 0.5
		if knockback_up_force >= 0.0:
			up = -knockback_up_force
		velocity = Vector2(dir.x * knockback_force, up)
		if up < 0.0:
			air_float_timer = air_float_duration
	change_behavior("hurt")
	behavior_timer = 0.0
	invulnerable = true
	invulnerability_timer = INVULNERABILITY_DURATION
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	if sprite:
		sprite.modulate = Color(1, 0, 0, 1)
		create_tween().tween_property(sprite, "modulate", Color(1, 1, 1, 1), HURT_FLASH_DURATION)
	

func _update_animation_state() -> void:
	match current_behavior:
		"idle":
			_play_anim_if_needed("idle")
		"chase":
			_play_anim_if_needed("fly")
		"swoop":
			_play_anim_if_needed("swoop")
		"neutral":
			_play_anim_if_needed("fly")
		"hurt":
			_play_anim_if_needed("hurt")
		"dead":
			_play_anim_if_needed("dead")

func set_neutral_state() -> void:
	
	is_neutral = true
	is_escaping = true
	change_behavior("neutral")
	
	# Pick a random direction to fly (left or right)
	neutral_direction = Vector2(randf_range(-1, 1), -1).normalized()
	
	# Disable only hitbox for combat
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	
	# Keep hurtbox active and explicitly set it to be monitorable for bouncing
	if hurtbox:
		hurtbox.monitoring = true
		hurtbox.monitorable = true
		if not hurtbox.is_in_group("hurtbox"):
			hurtbox.add_to_group("hurtbox")
	
	# Disable collision with environment
	set_collision_layer_value(3, false)  # Layer 3 is typically for enemy collision
	set_collision_mask_value(1, false)   # Layer 1 is typically for environment
	
	await get_tree().create_timer(0.1).timeout

func set_summoner(new_summoner: Node2D) -> void:
	summoner = new_summoner
	# Tile’da doğan kuşlar meta almaz; sadece summoner çağırınca altın drop’u kapatılır.
	if new_summoner != null:
		set_meta("summoner_summoned_bird", true)

func apply_gravity(_delta: float) -> void:
	# Override to prevent gravity from affecting flying enemies
	pass

func die() -> void:
	if current_behavior == "dead":
		return
		
	current_behavior = "dead"
	
	# Can barını hemen gizle
	if health_bar:
		health_bar.hide_bar()
	
	# Play death animation (anim adlari sahneler arasinda farkli olabiliyor)
	if sprite:
		_play_flying_death_animation()
		# Set z_index above player (player z_index = 5)
		sprite.z_index = 6
	
	# Set downward velocity for death fall (yatay yay cizmesini engelle)
	velocity = Vector2.ZERO
	
	# Disable ALL collision
	collision_layer = 0  # Nothing can collide with corpse
	collision_mask = 0   # Corpse can't collide with anything
	
	# Disable combat components
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	
	# Emit signals and notify systems
	enemy_defeated.emit()
	# PowerupManager.on_enemy_killed()  # DISABLED: Using new Item system
	if has_node("/root/ItemManager"):
		ItemManager.on_enemy_killed(self)
	
	# Don't fade out or return to pool - let corpses persist
	# await get_tree().create_timer(2.0).timeout
	# var tween = create_tween()
	# tween.tween_property(self, "modulate:a", 0.0, 1.0)
	# await tween.finished
	# var pool_name = scene_file_path.get_file().get_basename()
	# object_pool.return_object(self, pool_name)

func _physics_process(delta: float) -> void:
	# Skip all processing if position is invalid
	if global_position == Vector2.ZERO:
		return
	
	# Check sleep state every frame (delta for per-enemy spawn grace)
	check_sleep_state(delta)
	
	# Handle invulnerability timer
	if invulnerability_timer > 0:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0:
			invulnerable = false
			# Re-enable hurtbox when invulnerability ends
			if hurtbox:
				hurtbox.monitoring = true
				hurtbox.monitorable = true
	
	# Only process movement and behavior if awake
	if is_sleeping:
		return
	
	match current_behavior:
		"dead":
			# Olumde duz asagi dus; yatay arc yapmasin.
			velocity.x = move_toward(velocity.x, 0.0, 2600.0 * delta)
			position += velocity * delta
			# Gradually increase falling speed
			velocity.y = move_toward(velocity.y, 400, GRAVITY * delta * 0.5)
			return
		_:  # For all other states
			handle_behavior(delta)
			move_and_slide()
			_update_facing_from_velocity()

func change_behavior(new_behavior: String, force: bool = false) -> void:
	super.change_behavior(new_behavior, force)
	
	# Map behaviors to available animations
	match new_behavior:
		"idle":
			_play_anim_if_needed("idle")
		"chase", "patrol", "alert":
			_play_anim_if_needed("fly")
		"swoop":
			_play_anim_if_needed("swoop")
		"hurt":
			if sprite.sprite_frames and sprite.sprite_frames.has_animation("hurt"):
				_play_anim_if_needed("hurt")
			else:
				_play_anim_if_needed("fly")
		_:
			_play_anim_if_needed("idle")  # Default to idle for unknown states

func _play_flying_death_animation() -> void:
	if not sprite:
		return
	var frames = sprite.sprite_frames
	if frames:
		for anim_name in ["dead", "death", "die", "fall"]:
			if frames.has_animation(anim_name):
				sprite.play(anim_name)
				frames.set_animation_loop(anim_name, false)
				return
	# Son care: mevcut animde kalmak yerine idle'ye dusme.
	sprite.play("idle")

func _update_facing_from_velocity() -> void:
	if not sprite:
		return
	if absf(velocity.x) <= FACING_MIN_VX:
		return
	sprite.flip_h = velocity.x < 0.0

func _play_anim_if_needed(anim_name: String) -> void:
	if not sprite:
		return
	if sprite.animation == anim_name and sprite.is_playing():
		return
	sprite.play(anim_name)
