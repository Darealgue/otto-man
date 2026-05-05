class_name BaseEnemy
extends CharacterBody2D

# Preload autoloads
@onready var object_pool = get_node("/root/ObjectPool")

# Blood particle system (preloaded, can't be null)
const BLOOD_PARTICLE_SCENE = preload("res://effects/blood_particle.tscn")
const BLOOD_SPLATTER_SCENE = preload("res://effects/blood_splatter.tscn")
@export var blood_particle_count: int = 16
@export var blood_particle_force: float = 120.0

signal enemy_defeated
signal health_changed(new_health: float, max_health: float)

# Core components
@export var stats: EnemyStats
@export var debug_enabled: bool = false

const GLOBAL_ENEMY_DEBUG: bool = false

# Sleep state management
var is_sleeping: bool = false
var sleep_distance: float = 1000.0  # Distance at which enemy goes to sleep
var wake_distance: float = 800.0    # Distance at which enemy wakes up
var last_position: Vector2          # Store position when going to sleep
var last_behavior: String          # Store behavior when going to sleep
# Spawn sonrası grace süresini sıfırla: sahne açılışında uzak düşmanlar hemen sleep'e girebilsin
var _sleep_grace_remaining: float = 0.0

# Debug ID
var enemy_id: String = ""

# Node references
@onready var sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
# Hurtbox can be HurtBox or Hurtbox (case sensitivity)
var hurtbox: Area2D = null
# StateMachine is optional - not all enemies have it
var state_machine: Node = null

# Basic state tracking
var current_behavior: String = "idle"
var target: Node2D = null
var can_attack: bool = true
var attack_timer: float = 0.0
var health: float
var direction: int = 1
var behavior_timer: float = 0.0  # Timer for behavior state changes
var health_bar = null  # Add health bar reference
var enemy_level: int = 1  # Zindan seviyesi (spawner atar), can barında "Lv X" olarak gösterilir

# Constants
const GRAVITY: float = 980.0
const FLOOR_SNAP: float = 32.0
const HURT_FLASH_DURATION := 0.1  # Duration of the red flash
const DEATH_KNOCKBACK_FORCE := 150.0  # Force applied when dying
const DEATH_UP_FORCE := 100.0  # Upward force when dying
const FALL_DELETE_TIME := 2.0  # Time after falling before deleting
const DEATH_FADE_INTERVAL := 0.4  # How often to fade in/out
const DEATH_FADE_MIN := 0.3  # Minimum opacity during fade
const DEATH_FADE_MAX := 0.8  # Maximum opacity during fade
const DEATH_FADE_SPEED := 2.0  # How fast to fade

var death_fade_timer: float = 0.0
var fade_out: bool = true  # Whether we're currently fading out or in

var invulnerable: bool = false
var invulnerability_timer: float = 0.0
const INVULNERABILITY_DURATION: float = 0.1  # Short invulnerability window

# Add debug print counter to avoid spam
var _debug_print_counter: int = 0
const DEBUG_PRINT_INTERVAL: int = 60  # Print every 60 frames

# Add static variable at class level
var _was_in_range := false

# Air hitstun float (juggle) - artık sadece freeze için kullanılmıyor, eski davranış
var air_float_timer: float = 0.0
@export var air_float_duration: float = 0.5
@export var air_float_gravity_scale: float = 0.35
@export var air_float_max_fall_speed: float = 420.0

# Poison DoT system
var poison_stacks: int = 0
var poison_tick_timer: float = 0.0
var poison_damage_per_stack: float = 1.0
var poison_tick_interval: float = 2.0  # Default 2 seconds

# Burn DoT: 1 dmg/s, 3 tick per stack, max 3 stacks (9 tick total)
var burn_remaining_ticks: int = 0
var burn_tick_timer: float = 0.0
const BURN_TICK_INTERVAL: float = 1.0

# Frost slow: stacks 1-5 → %20, 6-10 → %40, 11-15 → %60; decay 1/s
var frost_stacks: int = 0
var frost_decay_timer: float = 0.0
const FROST_DECAY_INTERVAL: float = 1.0

# Zemin debuff: buz/ateş zemininde duran düşman 1 stack'ın altına inemez
var standing_on_ice_ground: bool = false
var standing_on_fire_ground: bool = false

# Zehir + ateş = patlama (bu düşman merkezli AoE)
const POISON_FIRE_EXPLOSION_SCENE = preload("res://effects/poison_fire_explosion.tscn")

func _ready() -> void:
	add_to_group("enemies")
	enemy_id = "%s_%d" % [get_script().resource_path.get_file().get_basename(), get_instance_id()]
	
	if not GLOBAL_ENEMY_DEBUG:
		debug_enabled = false
	
	# Zemin yapışması: spawn'da hafif yukarıda olan düşmanlar move_and_slide ile zemine snap olur (fall state takılmasını önler)
	floor_snap_length = 32.0
	up_direction = Vector2.UP
	
	if stats:
		health = stats.max_health
	else:
		push_warning("No stats resource assigned to enemy!")
		health = 100.0
	
	var health_bar_scene = preload("res://ui/enemy_health_bar.tscn")
	health_bar = health_bar_scene.instantiate()
	add_child(health_bar)
	health_bar.position = Vector2(0, -60)
	health_bar.setup(health)
	health_bar.show_bar()  # Bar ve Lv yazısı spawn anından itibaren görünsün
	# Notify initial health for external UI (e.g., boss bar)
	_health_emit_changed()
	
	_initialize_components()
	
	last_position = global_position
	last_behavior = "idle"

func _process(delta: float) -> void:
	# Zehir DoT - _process'te çalıştır ki her sahnede kesin tetiklensin
	if poison_stacks > 0:
		if current_behavior == "dead":
			poison_stacks = 0
			poison_tick_timer = 0.0
		else:
			poison_tick_timer += delta
			if poison_tick_timer >= poison_tick_interval:
				var total_damage = poison_stacks * poison_damage_per_stack * _get_elemental_damage_mult()
				take_damage(total_damage, 0.0, 0.0, false)
				poison_tick_timer = 0.0
				print("[BaseEnemy:", enemy_id, "] ✅ Zehir hasarı: ", total_damage, " (", poison_stacks, " stack x ", poison_damage_per_stack, ")")
	
	# Burn DoT: 1 hasar/saniye, 3 tick per stack, max 3 stack
	if burn_remaining_ticks > 0 and current_behavior != "dead":
		burn_tick_timer += delta
		if burn_tick_timer >= BURN_TICK_INTERVAL:
			burn_tick_timer = 0.0
			var burn_dmg = 1.0 * _get_elemental_damage_mult()
			take_damage(burn_dmg, 0.0, 0.0, false)
			# Ateş zeminindeyken 1 stack (3 tick) altına inme
			if standing_on_fire_ground:
				burn_remaining_ticks = maxi(3, burn_remaining_ticks - 1)
			else:
				burn_remaining_ticks -= 1
	
	# Frost decay: her saniye 1 stack azalır; buz zeminindeyken 1 altına inme
	if frost_stacks > 0:
		frost_decay_timer += delta
		if frost_decay_timer >= FROST_DECAY_INTERVAL:
			frost_decay_timer = 0.0
			if standing_on_ice_ground:
				frost_stacks = maxi(1, frost_stacks - 1)
			else:
				frost_stacks = max(0, frost_stacks - 1)
	
	# Can barı üstünde seviye ve zehir/ateş/buz ikonlarını güncelle
	if health_bar and current_behavior != "dead":
		if health_bar.has_method("set_level"):
			health_bar.set_level(enemy_level)
		if health_bar.has_method("update_status_effects"):
			health_bar.update_status_effects(poison_stacks, burn_remaining_ticks, frost_stacks)

func _physics_process(delta: float) -> void:
	# Skip all processing if position is invalid
	if global_position == Vector2.ZERO:
		return
	
	# Check sleep state every frame (delta for per-enemy spawn grace)
	check_sleep_state(delta)
	
	# Gravity (always, so airborne sleeping enemies land)
	if not is_on_floor() and current_behavior != "dead":
		var g_scale := 1.0
		if current_behavior == "hurt" and air_float_timer > 0.0:
			g_scale = air_float_gravity_scale
			air_float_timer = max(0.0, air_float_timer - delta)
		velocity.y += GRAVITY * g_scale * delta
		if current_behavior == "hurt" and air_float_timer > 0.0:
			velocity.y = min(velocity.y, air_float_max_fall_speed)
	if is_on_floor() and current_behavior == "hurt" and velocity.y < 0.0:
		pass
	if frost_stacks > 0:
		velocity.x *= get_frost_speed_multiplier()
	move_and_slide()
	
	# Sleeping enemy just landed: fall→idle then freeze sprite
	if is_sleeping and is_on_floor() and sprite and "fall" in sprite.animation:
		var idle_anim := "idle"
		if sprite.sprite_frames and not sprite.sprite_frames.has_animation("idle"):
			for a in sprite.sprite_frames.get_animation_names():
				if "idle" in a:
					idle_anim = a
					break
		sprite.play(idle_anim)
		if sprite.has_method("pause"):
			sprite.pause()
		return
	
	# Only process behavior/AI if awake
	if not is_sleeping:
		handle_behavior(delta)

func handle_behavior(delta: float) -> void:
	# Remove sleep check from here since we're doing it in _physics_process
	if is_sleeping:
		return
		
	behavior_timer += delta
	
	# Get player within detection range for behavior
	target = get_nearest_player_in_range()
	
	match current_behavior:
		"patrol":
			handle_patrol(delta)
		"idle":
			handle_patrol(delta)
		"alert":
			handle_alert(delta)
		"chase":
			handle_chase(delta)
		"hurt":
			handle_hurt_behavior(delta)
		"dead":
			return
	
	# Handle hurt state in base class first
	if current_behavior == "hurt":
		behavior_timer += delta
		
		# Only exit hurt state if timer is up AND mostly stopped
		if behavior_timer >= 0.2 and abs(velocity.x) <= 25:  # Reduced hurt state duration
			change_behavior("chase")
			# Make sure hurtbox is re-enabled
			if hurtbox:
				hurtbox.monitoring = true
				hurtbox.monitorable = true
		return  # Don't let child classes override hurt behavior
	
	# Let child classes handle other behaviors
	_handle_child_behavior(delta)

# New function for child classes to override
func _handle_child_behavior(_delta: float) -> void:
	pass  # Child classes will override this

func get_nearest_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		if Engine.get_physics_frames() % 60 == 0:  # Only print every ~1 second
			print("[BaseEnemy:%s] No players found in scene" % enemy_id)
		return null
	
	var nearest_player = null
	var min_distance = INF
	
	for player in players:
		if not is_instance_valid(player) or not player.is_inside_tree():
			continue
		# Do not aggro dead/dying players.
		if ("is_dead" in player and bool(player.is_dead)) or ("pending_death" in player and bool(player.pending_death)):
			continue
			
		var distance = global_position.distance_to(player.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest_player = player
	
	
	return nearest_player

func get_nearest_player_in_range() -> Node2D:
	var player = get_nearest_player()
	if !player:
		return null
		
	var distance = global_position.distance_to(player.global_position)
	var detection_range = stats.detection_range if stats else 300.0
	
	# Only print when detection status changes
	var is_in_range = distance <= detection_range
	if is_in_range != _was_in_range:
		if debug_enabled:
			print("[BaseEnemy:%s] detection in_range=%s dist=%.1f range=%.1f pos=%s player=%s" % [
				enemy_id,
				str(is_in_range),
				distance,
				detection_range,
				str(global_position),
				str(player.global_position),
			])
		_was_in_range = is_in_range
	
	return player if is_in_range else null

func start_attack_cooldown() -> void:
	can_attack = false
	attack_timer = stats.attack_cooldown if stats else 2.0

func _get_elemental_damage_mult() -> float:
	var im = get_node_or_null("/root/ItemManager")
	if not im or not im.get("player"):
		return 1.0
	var p = im.player
	return p.get("elemental_damage_mult") if p and p.get("elemental_damage_mult") else 1.0

func add_poison_stack(max_stacks: int, damage_per_stack: float, tick_interval: float) -> void:
	# Add poison stack (cap at max_stacks)
	poison_stacks = min(poison_stacks + 1, max_stacks)
	poison_damage_per_stack = damage_per_stack
	poison_tick_interval = tick_interval
	# Reset tick timer when new stack is added
	poison_tick_timer = 0.0

func add_burn_stack() -> void:
	# Zehir + ateş = patlama: üzerinde zehir varken ateş alırsa AoE patlama (düşman + oyuncu hasar alabilir)
	if poison_stacks > 0:
		var explosion = POISON_FIRE_EXPLOSION_SCENE.instantiate()
		get_tree().current_scene.add_child(explosion)
		explosion.global_position = global_position
	# 3 tick per stack, max 3 stacks (9 tick), 1 dmg per tick per second
	burn_remaining_ticks = mini(burn_remaining_ticks + 3, 9)
	burn_tick_timer = 0.0

func add_frost_stack(amount: int = 1) -> void:
	frost_stacks = mini(frost_stacks + amount, 15)
	frost_decay_timer = 0.0

func set_standing_on_ice_ground(on: bool) -> void:
	standing_on_ice_ground = on

func set_standing_on_fire_ground(on: bool) -> void:
	standing_on_fire_ground = on

func get_frost_speed_multiplier() -> float:
	if frost_stacks <= 0:
		return 1.0
	if frost_stacks <= 5:
		return 0.80
	if frost_stacks <= 10:
		return 0.60
	return 0.40

# Alt sınıflar override edebilir: lethal hasar sonrası die() hemen mi çağrılsın?
# Örn. BasicEnemy havada/knockback'te ölümü erteler, yere inince die() çağrılır.
func _should_die_now_on_lethal() -> bool:
	return true

# Tüm düşmanlar için tek kaynak: apply_knockback=false (projectile, zehir vb.) burada işlenir.
# Hasar + çok hafif itme + hurt yok + gerekirse die(). Alt sınıflar super.take_damage çağırıp
# apply_knockback false ise return etmeli; böylece yeni düşmanlar da aynı davranışı otomatik alır.
func take_damage(amount: float, knockback_force: float = 200.0, knockback_up_force: float = -1.0, apply_knockback: bool = true) -> void:
	# print("[BaseEnemy] take_damage called with amount: ", amount)
	if current_behavior == "dead":
		print("[BaseEnemy] No damage: dead")
		return
		
	health -= amount
	
	# Update health bar
	if health_bar:
		health_bar.update_health(health)
	# Emit health changed for external listeners
	_health_emit_changed()
	
	
	# Spawn damage number
	var damage_number = preload("res://effects/damage_number.tscn").instantiate()
	add_child(damage_number)
	damage_number.global_position = global_position + Vector2(0, -50)
	damage_number.setup(int(amount))
	
	# Apply knockback only if requested (skip for poison DoT / projectile)
	if apply_knockback:
		# Apply knockback (use explicit up_force if provided)
		velocity.x = -direction * knockback_force
		if knockback_up_force >= 0.0:
			velocity.y = -knockback_up_force
		else:
			velocity.y = -knockback_force * 0.5
		# Havada vurulunca kısa float (juggle için)
		if velocity.y < 0.0:
			air_float_timer = air_float_duration
		elif not is_on_floor():
			air_float_timer = air_float_duration * 0.5
		
		# Enter hurt state only if knockback is applied
		change_behavior("hurt")
		behavior_timer = 0.0
	else:
		# Çok hafif geri itme (projectile vb.), hurt animasyonu yok
		velocity.x = -direction * 18.0
	
	# No invulnerability - allow continuous damage
	# invulnerable = true
	# invulnerability_timer = INVULNERABILITY_DURATION
	
	# Flash red
	if sprite:
		sprite.modulate = Color(1, 0, 0, 1)
		create_tween().tween_property(sprite, "modulate", Color(1, 1, 1, 1), HURT_FLASH_DURATION)
	
	# Spawn blood particles (exclude flying enemies and turtle)
	if _should_spawn_blood():
		if GLOBAL_ENEMY_DEBUG:
			print("[BaseEnemy] Spawning blood for: ", enemy_id, " (", get_script().resource_path.get_file().get_basename(), ")")
		_spawn_blood_particles(amount)
	else:
		if GLOBAL_ENEMY_DEBUG:
			print("[BaseEnemy] No blood for: ", enemy_id, " (", get_script().resource_path.get_file().get_basename(), ")")
	
	# Check for death (alt sınıf havada/knockback'te erteleyebilir)
	if health <= 0:
		if health_bar:
			health_bar.hide_bar()
		if _should_die_now_on_lethal():
			die()
	else:
		pass

func _flash_hurt() -> void:
	if sprite:
		sprite.modulate = Color(1, 0, 0, 1)  # Red flash
		await get_tree().create_timer(HURT_FLASH_DURATION).timeout
		sprite.modulate = Color(1, 1, 1, 1)  # Reset color

func _apply_death_knockback() -> void:
	# Get direction from the last hit (player position)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var dir = (global_position - player.global_position).normalized()
		
		# Apply knockback force
		velocity = Vector2(
			dir.x * DEATH_KNOCKBACK_FORCE,
			-DEATH_UP_FORCE  # Negative for upward force
		)
		
		# Start fall delete timer when off screen or after maximum time
		var fall_timer = get_tree().create_timer(FALL_DELETE_TIME)
		fall_timer.timeout.connect(_on_fall_timer_timeout)

func handle_hurt() -> void:
	if sprite:
		sprite.play("hurt")
	current_behavior = "hurt"
	behavior_timer = 0.0  # Reset behavior timer

func _on_hurt_animation_finished() -> void:
	pass  # No longer needed, behavior handles state changes

func die() -> void:
	if current_behavior == "dead":
		return
		
	current_behavior = "dead"
	
	# Can barını hemen gizle
	if health_bar:
		health_bar.hide_bar()
	
	enemy_defeated.emit()
	
	# PowerupManager.on_enemy_killed()  # DISABLED: Using new Item system
	
	# Notify ItemManager
	if has_node("/root/ItemManager"):
		ItemManager.on_enemy_killed(self)
	else:
		push_warning("[BaseEnemy] ItemManager not found!")
	
	if sprite:
		sprite.play("death")
		# Set z_index above player (player z_index = 5)
		sprite.z_index = 6
	
	# Disable ALL collision to ensure falling through platforms
	collision_layer = 0
	collision_mask = 0
	
	# Disable components
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	
	# Apply death knockback
	_apply_death_knockback()
	
	# Start fade out
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	fade_out = true
	
	# Don't return to pool - let corpses persist
	# await get_tree().create_timer(2.0).timeout
	# var scene_path = scene_file_path
	# var pool_name = scene_path.get_file().get_basename()
	# object_pool.return_object(self, pool_name)

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.y = minf(velocity.y, GRAVITY)

func change_behavior(new_behavior: String, force: bool = false) -> void:
	if current_behavior == "dead" and not force:
		return
		
	current_behavior = new_behavior
	behavior_timer = 0.0
	
	# Play appropriate animation if available
	if sprite and sprite.has_method("play"):
		sprite.play(new_behavior)
		
	# Reset attack cooldown when changing behavior
	if new_behavior != "attack":
		can_attack = true
		attack_timer = 0.0

func _on_fall_timer_timeout() -> void:
	# Check if we're off screen or far below the ground
	if not is_on_screen() or global_position.y > 1000:
		# If we're dead and off screen, just queue_free
		if current_behavior == "dead":
			queue_free()
		else:
			# Start another timer if still alive
			var fall_timer = get_tree().create_timer(FALL_DELETE_TIME)
			fall_timer.timeout.connect(_on_fall_timer_timeout)
	else:
		# Start another timer if still on screen
		var fall_timer = get_tree().create_timer(FALL_DELETE_TIME)
		fall_timer.timeout.connect(_on_fall_timer_timeout)

func is_on_screen() -> bool:
	if not is_instance_valid(self):
		return false
		
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return false
		
	var screen_rect = get_viewport_rect()
	var camera_pos = camera.get_screen_center_position()
	var top_left = camera_pos - screen_rect.size / 2
	var bottom_right = camera_pos + screen_rect.size / 2
	
	return global_position.x >= top_left.x - 100 and global_position.x <= bottom_right.x + 100 and \
		   global_position.y >= top_left.y - 100 and global_position.y <= bottom_right.y + 100

## Ceset vurulunca çağrılır (fall attack ramp, heavy vb.). Death animasyonunu frame 5'ten oynat.
func play_corpse_hit_animation() -> void:
	if not sprite or not sprite is AnimatedSprite2D:
		return
	var anim_sprite = sprite as AnimatedSprite2D
	if not anim_sprite.sprite_frames:
		return
	var anim_name = "death" if anim_sprite.sprite_frames.has_animation("death") else ("dead" if anim_sprite.sprite_frames.has_animation("dead") else "")
	if anim_name.is_empty():
		return
	anim_sprite.play(anim_name)
	var frame_count = anim_sprite.sprite_frames.get_frame_count(anim_name)
	anim_sprite.frame = mini(5, frame_count - 1) if frame_count > 0 else 0

func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	# print("[BaseEnemy] _on_hurtbox_hurt called")
	# Safety: enemies only take damage from PlayerHitbox, never from other enemies/projectiles
	if not (hitbox is PlayerHitbox):
		print("[BaseEnemy] Not PlayerHitbox, ignoring")
		return
	if current_behavior != "dead":
		var elemental_only: bool = hitbox.get_meta("elemental_only_no_physical", false)
		if not elemental_only:
			var damage: float = 10.0
			if hitbox.has_method("get_damage_for_target"):
				damage = hitbox.get_damage_for_target(self)
			elif hitbox.has_method("get_damage"):
				damage = hitbox.get_damage()
			var knockback_data = hitbox.get_knockback_data() if hitbox.has_method("get_knockback_data") else {"force": 200.0, "up_force": 100.0}
			take_damage(damage, knockback_data.force, knockback_data.get("up_force", -1.0))
			# Hit stop + screen shake tek yerden (yaşayan veya öldürücü vuruş; ceset vurulunca bu blok çalışmaz)
			if hitbox is PlayerHitbox and hitbox.has_method("apply_killing_blow_effects"):
				hitbox.apply_killing_blow_effects(damage)
		# Elemental efekt (decoy Hacivat vb.): hitbox'ta element meta varsa uygula
		var elem: String = hitbox.get_meta("element", "")
		if elem and elem.length() > 0 and has_node("/root/ElementalEffects"):
			ElementalEffects.apply_to_enemy(self, elem)
	else:
		pass  # Dead or invulnerable, no damage
		# print("[BaseEnemy] Dead or invulnerable, no damage")

func _health_emit_changed() -> void:
	var max_h = stats.max_health if stats else 100.0
	health_changed.emit(health, max_h)

# Blood particle system functions
func _should_spawn_blood() -> bool:
	# Don't spawn blood for flying enemies or turtle
	if _is_flying_enemy_runtime():
		print("[BaseEnemy] No blood: FlyingEnemy")
		return false
	
	# Check if this is a turtle enemy by checking the script name
	var script_name = get_script().resource_path.get_file().get_basename().to_lower()
	# print("[BaseEnemy] Script name: ", script_name)
	if "turtle" in script_name:
		print("[BaseEnemy] No blood: turtle enemy")
		return false
		
	# print("[BaseEnemy] Should spawn blood: true")
	return true

func _is_flying_enemy_runtime() -> bool:
	# Parser-safe: explicit class type referansi kullanma.
	# Flying enemy scriptleri genelde bu imzalardan birini tasir.
	if has_method("is_returning"):
		return true
	if scene_file_path:
		var scene_path_l := String(scene_file_path).to_lower()
		if "flying" in scene_path_l or "bird" in scene_path_l:
			return true
	var sc: Variant = get_script()
	if sc is Script:
		var script_path_l := String((sc as Script).resource_path).to_lower()
		if "flying" in script_path_l or "bird" in script_path_l:
			return true
	return false

func _spawn_blood_particles(damage_amount: float = 10.0) -> void:
	# Get the nearest player to determine hit direction
	var player = get_nearest_player()
	var hit_direction = Vector2.RIGHT  # Default direction
	
	if player:
		# Calculate direction from player to enemy
		hit_direction = (global_position - player.global_position).normalized()
	
	# Calculate particle count based on damage (2-5 particles)
	var particle_count = int(clamp(damage_amount / 5.0, 2, 5))  # 2 to 5 particles based on damage
	
	# Spawn blood particles around the enemy
	for i in range(particle_count):
		var particle = BLOOD_PARTICLE_SCENE.instantiate()
		get_tree().current_scene.add_child(particle)
		
		# Position particle at enemy center with slight random offset
		var offset = Vector2(
			randf_range(-15, 15),  # Increased spread
			randf_range(-10, 10)   # Increased spread
		)
		particle.global_position = global_position + offset
		
		# Set up blood splatter scene reference
		if particle.has_method("set_blood_splatter_scene"):
			particle.set_blood_splatter_scene(BLOOD_SPLATTER_SCENE)
		
		# Set hit direction and damage for the particle
		if particle.has_method("set_hit_direction"):
			particle.set_hit_direction(hit_direction)
		if particle.has_method("set_damage_amount"):
			particle.set_damage_amount(damage_amount)
 
func _initialize_components() -> void:
	# Try both HurtBox and Hurtbox (case sensitivity issue)
	hurtbox = get_node_or_null("HurtBox")
	if not hurtbox:
		hurtbox = get_node_or_null("Hurtbox")
	if not hurtbox:
		push_error("Hurtbox node not found in enemy (tried HurtBox and Hurtbox)")
		return
	# Connect hurt signal if not already and if hurt signal exists
	if hurtbox.has_signal("hurt") and not hurtbox.hurt.is_connected(_on_hurtbox_hurt):
		hurtbox.hurt.connect(_on_hurtbox_hurt)
		
	hitbox = $Hitbox
	if not hitbox:
		push_error("Hitbox node not found in enemy")
		return
		
	# StateMachine is optional - not all enemies have it
	# Check if StateMachine exists, but don't error if it doesn't
	state_machine = get_node_or_null("StateMachine")
	if state_machine:
		# StateMachine found, can be used
		pass
	# If state_machine is null, that's fine - not all enemies use it

func reset() -> void:
	# Reset all state when reusing from pool
	current_behavior = "idle"
	target = null
	can_attack = true
	attack_timer = 0.0
	health = stats.max_health if stats else 100.0
	direction = 1
	behavior_timer = 0.0
	invulnerable = false
	invulnerability_timer = 0.0
	velocity = Vector2.ZERO
	
	# Reset visuals
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
		if sprite.has_method("play"):
			sprite.play("idle")
	
	# Reset health bar
	if health_bar:
		health_bar.setup(health)
		
	# Re-enable components
	if hitbox:
		hitbox.enable()
	if hurtbox:
		hurtbox.monitoring = true
		hurtbox.monitorable = true
	

func handle_patrol(_delta: float) -> void:
	# Virtual function to be overridden by child classes
	pass

func handle_alert(_delta: float) -> void:
	# Virtual function to be overridden by child classes
	pass

func handle_chase(_delta: float) -> void:
	# Virtual function to be overridden by child classes
	pass

func handle_hurt_behavior(_delta: float) -> void:
	behavior_timer += _delta
	# Apply strong horizontal damping while hurt to avoid infinite drift
	velocity.x = move_toward(velocity.x, 0.0, 2000.0 * _delta)
	
	# Only exit hurt state if timer is up AND mostly stopped
	if behavior_timer >= 0.2 and abs(velocity.x) <= 25:  # Reduced hurt state duration
		change_behavior("chase")
		# Make sure hurtbox is re-enabled
		if hurtbox:
			hurtbox.monitoring = true
			hurtbox.monitorable = true

func check_sleep_state(delta: float = 0.0) -> void:
	if current_behavior == "dead" or not is_instance_valid(self):
		return
	# Her düşman kendi spawn'ından sonra grace süresi dolana kadar uyuyamaz (chunk'ta geç spawn = hemen sleep bug'ı önlenir)
	if _sleep_grace_remaining > 0.0:
		_sleep_grace_remaining -= delta
	var player = get_nearest_player()
	if !player:
		return
	var distance = global_position.distance_to(player.global_position)
	if is_sleeping and distance <= wake_distance:
		wake_up()
	elif !is_sleeping and distance >= sleep_distance and _sleep_grace_remaining <= 0.0:
		go_to_sleep()

func go_to_sleep() -> void:
	if is_sleeping or current_behavior == "dead":
		return
			
	is_sleeping = true
	last_position = global_position
	last_behavior = current_behavior
	
	if _is_flying_enemy_runtime():
		set_meta("last_velocity", velocity)
		set_meta("last_direction", direction)
	
	set_process(false)
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	
	if sprite:
		if sprite.animation == "fall" and is_on_floor():
			sprite.play("idle")
		elif sprite.animation in ["sit", "sit2", "sit3", "lay"]:
			# Don't freeze in ambient animation - show idle when sleeping
			if sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")
		if sprite.has_method("pause"):
			sprite.pause()

func wake_up() -> void:
	if !is_sleeping or current_behavior == "dead":
		return
			
	is_sleeping = false
	
	set_process(true)
	if hitbox:
		hitbox.enable()
	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
		hurtbox.set_deferred("monitorable", true)
	
	if _is_flying_enemy_runtime():
		if has_meta("last_velocity"):
			velocity = get_meta("last_velocity")
		if has_meta("last_direction"):
			direction = get_meta("last_direction")
	
	if sprite and sprite.has_method("play"):
		sprite.play()
	
	if _is_flying_enemy_runtime():
		if last_behavior == "neutral" and has_method("is_returning") and not get("is_returning"):
			change_behavior("chase")
		else:
			change_behavior(last_behavior)
	else:
		change_behavior(last_behavior)
