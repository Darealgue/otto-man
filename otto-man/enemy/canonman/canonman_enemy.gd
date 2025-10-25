class_name CanonmanEnemy
extends "res://enemy/base_enemy.gd"

# Canonman specific constants
const ROCKET_JUMP_FORCE = 600.0  # Rocket jump gücü
const ROCKET_JUMP_HEIGHT = 300.0  # Maksimum yükseklik
const CANNON_SHOT_SPEED = 650.0  # Top atış hızı (artırıldı)
const CANNON_SHOT_DAMAGE = 30.0  # Top hasarı
const ROCKET_EXPLOSION_DAMAGE = 25.0  # Rocket patlama hasarı
const ROCKET_EXPLOSION_RADIUS = 80.0  # Patlama yarıçapı
const AIM_TIME = 1.0  # Nişan alma süresi
# const RELOAD_TIME = 2.0  # KALDIRILDI: Yeniden doldurma süresi
const GROUND_SHOT_ANGLE = 15.0  # Daha yatay atış (daha ileri düşsün)
const GROUND_SHOT_DISTANCE = 200.0  # Yere atış mesafesi
const GROUND_SHOT_AIM_OFFSET = 100.0  # Oyuncunun biraz arkasını hedeflemek için yatay offset
const RETREAT_MIN_DISTANCE = 140.0  # Çok yakınsa kaçış eşiği
const ROCKET_RETREAT_COOLDOWN = 2.0  # Kaçış sıklığı

# State tracking
var is_rocket_jumping: bool = false
var rocket_landing_position: Vector2
var cannon_ready: bool = true
var aim_timer: float = 0.0
# var reload_timer: float = 0.0  # KALDIRILDI
var state_lock: float = 0.0  # State changes are blocked while > 0
var attack_cooldown_timer: float = 0.0  # Prevent immediate attack switching
var retreat_cooldown_timer: float = 0.0  # Prevent frequent retreats
var explosion_cooldown_timer: float = 0.0  # Prevent double explosion damage

# Node references
@onready var wall_detector: RayCast2D = $WallDetector
@onready var ceiling_detector: RayCast2D = $CeilingDetector
@onready var floor_detector: RayCast2D = $FloorDetector

# Projectile scene
var cannon_shot_scene = preload("res://enemy/canonman/cannon_shot_projectile.tscn")
@export var launch_smoke_texture: Texture2D
@export var launch_smoke_frame_count: int = 5
@export var launch_smoke_horizontal: bool = true  # true: frames laid out horizontally, false: vertically
@export var landing_smoke_texture: Texture2D
@export var landing_smoke_frame_count: int = 5
@export var landing_smoke_horizontal: bool = true
@export var landing_smoke_offset_y: int = 100
@export var landing_smoke_fps: float = 16.0
const LAUNCH_SMOKE_CANDIDATE_PATHS := [
	"res://enemy/canonman/sprite/cannon_smoke_launch.png",
	"res://enemy/canonman/sprite/canon_smoke_launch.png",
	"res://enemy/canonman/sprite/cannon_smoke.png",
	"res://enemy/canonman/sprite/canon_smoke.png"
]

func _ready() -> void:
	super._ready()
	
	# Set sleep distances for performance optimization
	sleep_distance = 1500.0  # Distance at which enemy goes to sleep
	wake_distance = 1200.0  # Distance at which enemy wakes up
	
	# Try to load smoke texture lazily to avoid preload errors
	if launch_smoke_texture == null:
		for p in LAUNCH_SMOKE_CANDIDATE_PATHS:
			if ResourceLoader.exists(p):
				var tex := load(p)
				if tex is Texture2D:
					launch_smoke_texture = tex
					print("[Canonman] Launch smoke texture loaded:", p)
					break
	if launch_smoke_texture == null:
		print("[Canonman] Launch smoke texture NOT found. Candidates:", LAUNCH_SMOKE_CANDIDATE_PATHS)
	else:
		print("[Canonman] Launch smoke texture set via export or auto-load")
	
	# DEBUG: Collision info
	print("[Canonman] Collision Layer: ", collision_layer)
	print("[Canonman] Collision Mask: ", collision_mask)
	print("[Canonman] Position: ", global_position)
	
	# Initialize combat components
	if hitbox:
		hitbox.damage = stats.attack_damage
		hitbox.knockback_force = 200.0 * stats.knockback_resistance
		hitbox.enable()
	
	# Setup hurtbox
	var hurtbox_node = get_node_or_null("HurtBox")
	if not hurtbox_node:
		hurtbox_node = get_node_or_null("Hurtbox")
	if not hurtbox_node:
		hurtbox_node = get_node_or_null("hurtbox")
	
	if hurtbox_node:
		hurtbox = hurtbox_node
		hurtbox.add_to_group("hurtbox")
		hurtbox.add_to_group("HurtBox")
	
	change_behavior("idle")

func _physics_process(delta: float) -> void:
	# Skip all processing if position is invalid
	if global_position == Vector2.ZERO:
		return
	
	# Timers
	if state_lock > 0.0:
		state_lock = max(0.0, state_lock - delta)
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer = max(0.0, attack_cooldown_timer - delta)
	if retreat_cooldown_timer > 0.0:
		retreat_cooldown_timer = max(0.0, retreat_cooldown_timer - delta)
	if explosion_cooldown_timer > 0.0:
		explosion_cooldown_timer = max(0.0, explosion_cooldown_timer - delta)
	
	# Hurt state - yerde kal
	if current_behavior == "hurt":
		if not is_sleeping:
			handle_behavior(delta)
		# Hurt sırasında hareket etme
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Death state - düş ve yerde kal
	if current_behavior == "dead":
		if not is_sleeping:
			handle_behavior(delta)
		if not is_on_floor():
			velocity.y += GRAVITY * 0.3 * delta
			move_and_slide()
		else:
			velocity = Vector2.ZERO
		return
	
	# Rocket jump sırasında özel physics (launch animasyonu sırasında da uçsun)
	if current_behavior == "rocket_fire" or current_behavior == "rocket_rise" or current_behavior == "rocket_fall":
		if not is_sleeping:
			handle_behavior(delta)
		# Rocket jump physics
		# Launch öncesi (0.1s) yerde kalmak için gravity uygulama
		if current_behavior == "rocket_fire" and not has_meta("launch_applied"):
			# grounded hold
			pass
		else:
			velocity.y += GRAVITY * 0.8 * delta  # Hafif gravity
		move_and_slide()
		return
	
	# Normal base enemy physics
	super._physics_process(delta)

func handle_behavior(delta: float) -> void:
	# Override base behavior handling to prevent target reset thrashing
	behavior_timer += delta
	
	# Keep/refresh target without hard range cutoffs
	if not target or not is_instance_valid(target):
		target = get_nearest_player()
	
	# Delegate hurt handling to base implementation
	if current_behavior == "hurt":
		handle_hurt_behavior(delta)
		return
	
	# Let child-specific behavior drive
	_handle_child_behavior(delta)

func _handle_child_behavior(delta: float) -> void:
	match current_behavior:
		"idle":
			_handle_idle_state()
		"walk":
			_handle_walk_state(delta)
		"chase":
			# Engage only when grounded; otherwise wait
			if is_on_floor():
				_handle_rocket_charge_state(delta)
			else:
				# Stay in chase but don't trigger launch mid-air
				pass
		"rocket_charge":
			_handle_rocket_charge_state(delta)
		"rocket_fire":
			_handle_rocket_fire_state(delta)
		"rocket_rise":
			_handle_rocket_rise_state(delta)
		"rocket_fall":
			_handle_rocket_fall_state(delta)
		"rocket_land":
			_handle_rocket_land_state(delta)
		"aim":
			_handle_aim_state(delta)
		"shoot":
			_handle_shoot_state(delta)
		# "reload":  # KALDIRILDI
		# 	_handle_reload_state(delta)
		"ground_aim":
			_handle_ground_aim_state(delta)
		"ground_shot":
			_handle_ground_shot_state(delta)
		"hurt":
			_handle_hurt_state(delta)
		"dead":
			_handle_death_state(delta)
	
	_update_animation_state()

func _handle_idle_state() -> void:
	# Yerdeyken hareket etme
	velocity = Vector2.ZERO
	
	# Oyuncu tespit et
	var player = get_nearest_player()
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance <= stats.detection_range:
			target = player
			# Saldırı türü seç (rocket jump veya ground shot)
			_choose_attack_type()
		elif distance <= stats.detection_range * 1.5 and state_lock <= 0.0 and is_on_floor():  # Yakın mesafe - yürü
			target = player
			change_behavior("walk")

func _handle_walk_state(delta: float) -> void:
	# Oyuncuya doğru yürü (histerezis + smoothing)
	if not target or not is_instance_valid(target):
		change_behavior("idle")
		return
	
	var distance = global_position.distance_to(target.global_position)
	
	# Histerezis eşikleri
	var attack_enter = stats.detection_range * 0.9
	var idle_exit = stats.detection_range * 1.7
	
	# Minimum yürüyüş süresi (state flapping önle)
	var min_walk_time = 0.25
	
	# Çok yakınsa saldır (min süre dolduysa)
	if behavior_timer >= min_walk_time and distance <= attack_enter and state_lock <= 0.0:
		_choose_attack_type()
		return
	
	# Çok uzaksa idle'a dön (min süre dolduysa)
	if behavior_timer >= min_walk_time and distance > idle_exit and state_lock <= 0.0:
		change_behavior("idle")
		return
	
	# Oyuncuya doğru yürü - hız smoothing
	var direction_vec = global_position.direction_to(target.global_position)
	var target_speed = direction_vec.x * stats.movement_speed * 0.5
	velocity.x = lerp(velocity.x, target_speed, clamp(6.0 * delta, 0.0, 1.0))
	
	# Sprite yönünü ayarla yalnızca gerekli olduğunda
	if direction_vec.x > 0.1:
		sprite.flip_h = false
	elif direction_vec.x < -0.1:
		sprite.flip_h = true
	
	# Hareket: base physics halleder (burada move_and_slide yok)

func _handle_rocket_charge_state(delta: float) -> void:
	# Rocket jump hazırlığı (3-4 frame)
	velocity = Vector2.ZERO  # Yerde kal
	
	if behavior_timer >= 0.4:  # 4 frame sonra fire state'e geç
		change_behavior("rocket_fire")

func _handle_rocket_fire_state(delta: float) -> void:
	# Cannon'u yere doğru ateşleme (launch animasyonu sırasında havalan)
	if sprite and sprite.animation != "cannonman_launch":
		sprite.play("cannonman_launch")
	
	if not has_meta("launch_started"):
		# 0.1s yerde bekle sonra hızı uygula
		if behavior_timer >= 0.1:
			set_meta("launch_started", true)
			set_meta("launch_applied", true)
			# Rocket jump başlat - yay şeklinde hareket
			var jump_angle = 45.0
			var angle_rad = deg_to_rad(jump_angle)
			var to_player_sign := 1.0
			if target and is_instance_valid(target):
				to_player_sign = sign(target.global_position.x - global_position.x)
				if to_player_sign == 0.0:
					to_player_sign = 1.0
			var retreating := has_meta("rocket_retreat")
			var horizontal_sign = (-to_player_sign) if retreating else to_player_sign
			velocity.x = horizontal_sign * cos(angle_rad) * ROCKET_JUMP_FORCE * 0.7
			velocity.y = -sin(angle_rad) * ROCKET_JUMP_FORCE
			is_rocket_jumping = true
			rocket_landing_position = global_position
			_create_rocket_explosion(global_position)
			_spawn_launch_smoke(global_position)
			if retreating:
				retreat_cooldown_timer = ROCKET_RETREAT_COOLDOWN
				remove_meta("rocket_retreat")
			print("[Canonman] Rocket jump started during launch after hold! Velocity: ", velocity)
	
	# Launch animasyonu kısa bir süre oynadıktan sonra rise'a geç
	if behavior_timer >= 0.3:
		change_behavior("rocket_rise")

func _handle_rocket_rise_state(delta: float) -> void:
	# Havaya yükselme (4-5 frame)
	# Physics process'te gravity uygulanıyor
	
	# Maksimum yükseklik kontrolü
	if velocity.y >= 0:  # Yükselme bitti, düşmeye başladı
		change_behavior("rocket_fall")

func _handle_rocket_fall_state(delta: float) -> void:
	# Havada düşme (4-5 frame)
	# Physics process'te gravity uygulanıyor
	
	# Yere değdi mi kontrol et
	if is_on_floor():
		# İniş noktasında patlama hasarı - sadece iniş dumanı, hasar yok
		# _create_rocket_explosion(global_position)  # KALDIRILDI: Çift hasar önleme
		# İniş dumanı
		_spawn_landing_smoke(global_position)
		change_behavior("rocket_land")

func _handle_rocket_land_state(delta: float) -> void:
	# Yere iniş (3-4 frame)
	velocity = Vector2.ZERO  # Yerde kal
	
	if behavior_timer >= 0.3:  # 3 frame sonra aim state'e geç
		is_rocket_jumping = false
		change_behavior("aim")

func _handle_aim_state(delta: float) -> void:
	# Nişan alma (3-4 frame)
	velocity = Vector2.ZERO  # Yerde kal
	aim_timer += delta
	
	# Oyuncuya doğru dön
	if target and is_instance_valid(target):
		sprite.flip_h = target.global_position.x < global_position.x
	
	if behavior_timer >= 0.4 and attack_cooldown_timer <= 0.0:  # 4 frame sonra shoot state'e geç
		change_behavior("shoot")

func _handle_shoot_state(delta: float) -> void:
	# Top atışı (4-5 frame)
	velocity = Vector2.ZERO  # Yerde kal
	
	if behavior_timer >= 0.3 and not has_meta("cannon_fired"):  # 3 frame sonra top at
		_fire_cannon_shot()
		set_meta("cannon_fired", true)
		cannon_ready = false
	
	if behavior_timer >= 0.5:  # 5 frame sonra idle'a geç
		remove_meta("cannon_fired")
		cannon_ready = true
		attack_cooldown_timer = 0.6
		change_behavior("idle")

# KALDIRILDI
# func _handle_reload_state(delta: float) -> void:
# 	# Yeniden doldurma (5-6 frame)
# 	velocity = Vector2.ZERO  # Yerde kal
# 	reload_timer += delta
# 	
# 	if behavior_timer >= 0.6:  # 6 frame sonra idle'a dön
# 		cannon_ready = true
# 		reload_timer = 0.0
# 		attack_cooldown_timer = 0.6  # Ateşten sonra kısa bir bekleme koy
# 		change_behavior("idle")

func _handle_ground_aim_state(delta: float) -> void:
	# Yere doğru nişan alma (3-4 frame)
	velocity = Vector2.ZERO  # Yerde kal
	
	# Oyuncuya doğru dön
	if target and is_instance_valid(target):
		sprite.flip_h = target.global_position.x < global_position.x
	
	if behavior_timer >= 0.4:  # 4 frame sonra ground_shot state'e geç
		change_behavior("ground_shot")

func _handle_ground_shot_state(delta: float) -> void:
	# Yere doğru atış (4-5 frame)
	velocity = Vector2.ZERO  # Yerde kal
	
	if behavior_timer >= 0.3 and not has_meta("ground_shot_fired"):  # 3 frame sonra top at
		_fire_ground_shot()
		set_meta("ground_shot_fired", true)
		cannon_ready = false
	
	if behavior_timer >= 0.5:  # 5 frame sonra idle'a geç
		remove_meta("ground_shot_fired")
		cannon_ready = true
		attack_cooldown_timer = 0.6
		change_behavior("idle")

func _handle_hurt_state(delta: float) -> void:
	# Hasar alma animasyonu (3 frame)
	velocity = Vector2.ZERO  # Yerde kal
	
	print("[Canonman] Hurt state - behavior_timer: ", behavior_timer, " / 0.3")
	
	if behavior_timer >= 0.3:  # 3 frame sonra idle'a dön
		print("[Canonman] Hurt state finished, changing to idle")
		change_behavior("idle")

func _handle_death_state(delta: float) -> void:
	# Ölüm animasyonu - yerde ceset kalmalı
	if not is_on_floor():
		velocity.y += GRAVITY * 0.3 * delta
		move_and_slide()
		return
	
	# Yerdeyken tamamen dur
	velocity = Vector2.ZERO
	# collision_mask zaten sadece zemin ile
	# corpse kalır; silme yok

func _spawn_launch_smoke(pos: Vector2) -> void:
	_spawn_smoke_generic(pos, launch_smoke_texture, launch_smoke_frame_count, launch_smoke_horizontal, 100, 16.0, "launch")

func _spawn_landing_smoke(pos: Vector2) -> void:
	_spawn_smoke_generic(pos, landing_smoke_texture, landing_smoke_frame_count, landing_smoke_horizontal, landing_smoke_offset_y, landing_smoke_fps, "landing")

func _spawn_smoke_generic(pos: Vector2, tex: Texture2D, frame_count_in: int, horizontal_in: bool, offset_y: int, fps: float, tag: String) -> void:
	if not is_instance_valid(get_tree()) or tex == null:
		print("[Canonman] _spawn_smoke_generic skipped (", tag, ") texture missing or tree invalid")
		return
	# Ground point via raycast
	var ground_pos: Vector2 = pos
	var space := get_world_2d().direct_space_state
	var from_point: Vector2 = pos + Vector2(0, -10)
	var to_point: Vector2 = pos + Vector2(0, 2000)
	var query := PhysicsRayQueryParameters2D.create(from_point, to_point)
	query.exclude = [self]
	var hit := space.intersect_ray(query)
	if hit and hit.has("position"):
		ground_pos = hit.position
	elif is_instance_valid(floor_detector):
		floor_detector.force_raycast_update()
		if floor_detector.is_colliding():
			ground_pos = floor_detector.get_collision_point()
	ground_pos.y = int(ground_pos.y) - int(offset_y)

	var sprite := AnimatedSprite2D.new()
	sprite.centered = true
	sprite.global_position = ground_pos
	sprite.visible = true
	sprite.modulate = Color(1,1,1,1)
	sprite.scale = Vector2.ONE
	sprite.z_as_relative = false
	sprite.z_index = 100

	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation("smoke")
	frames.set_animation_loop("smoke", false)
	var tex_w: int = tex.get_width()
	var tex_h: int = tex.get_height()
	var frame_count: int = max(1, frame_count_in)
	var horizontal: bool = horizontal_in
	if frame_count > 1:
		horizontal = tex_w >= tex_h if horizontal_in else false
	if horizontal:
		var frame_w: int = int(tex_w / frame_count)
		for i in range(frame_count):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * frame_w, 0, frame_w, tex_h)
			frames.add_frame("smoke", atlas)
	else:
		var frame_h: int = int(tex_h / frame_count)
		for i in range(frame_count):
			var atlas_v: AtlasTexture = AtlasTexture.new()
			atlas_v.atlas = tex
			atlas_v.region = Rect2(0, i * frame_h, tex_w, frame_h)
			frames.add_frame("smoke", atlas_v)
	frames.set_animation_speed("smoke", fps)
	sprite.sprite_frames = frames
	var total := frames.get_frame_count("smoke")
	if is_instance_valid(get_parent()):
		get_parent().add_child(sprite)
	else:
		get_tree().current_scene.add_child(sprite)
	print("[Canonman] Spawned ", tag, " smoke at:", sprite.global_position, " frames:", total)
	if total > 0:
		sprite.play("smoke")
	else:
		var frames2: SpriteFrames = SpriteFrames.new()
		frames2.add_animation("smoke")
		frames2.set_animation_loop("smoke", false)
		var atlas_full: AtlasTexture = AtlasTexture.new()
		atlas_full.atlas = tex
		atlas_full.region = Rect2(0, 0, tex_w, tex_h)
		frames2.add_frame("smoke", atlas_full)
		frames2.set_animation_speed("smoke", fps)
		sprite.sprite_frames = frames2
		sprite.play("smoke")
	sprite.animation_finished.connect(func():
		if is_instance_valid(sprite):
			sprite.queue_free()
	, CONNECT_ONE_SHOT)
	sprite.animation_finished.connect(func():
		if is_instance_valid(sprite):
			sprite.queue_free()
	, CONNECT_ONE_SHOT)

func _create_rocket_explosion(pos: Vector2) -> void:
	# Cooldown kontrolü - çok hızlı ardışık patlamaları önle
	if explosion_cooldown_timer > 0.0:
		print("[Canonman] Explosion cooldown active, skipping explosion")
		return
	
	# Rocket patlama efekti oluştur (görsel)
	var explosion = preload("res://effects/explosion_range_visual.tscn").instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = pos
	explosion.set_radius(ROCKET_EXPLOSION_RADIUS)
	
	# Hasarı hitbox üzerinden uygula (parry/dodge uyumlu)
	_spawn_explosion_hitbox(pos)
	
	# Cooldown başlat (0.5 saniye)
	explosion_cooldown_timer = 0.5
	
	print("[Canonman] Rocket explosion at: ", pos)

func _spawn_explosion_hitbox(pos: Vector2) -> void:
	# Geçici bir EnemyHitbox oluştur ve çember çarpışma ekle (player tarafından algılanır)
	var hit := EnemyHitbox.new()
	hit.damage = ROCKET_EXPLOSION_DAMAGE
	hit.knockback_force = 250.0
	hit.knockback_up_force = 180.0
	hit.add_to_group("hitbox")
	hit.add_to_group("enemy_hitbox")
	# Enemy attack vs player hurtbox
	hit.collision_layer = CollisionLayers.ENEMY_HITBOX
	hit.collision_mask = CollisionLayers.PLAYER_HURTBOX  # Only target player, not other enemies
	hit.setup_attack("rocket_explosion", true, 0.0)
	# Kendi owner id'mizi ata ki kendimizi vurmayalım
	hit.set_meta("owner_id", get_instance_id())
	
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ROCKET_EXPLOSION_RADIUS
	shape.shape = circle
	hit.add_child(shape)
	
	hit.global_position = pos
	get_tree().current_scene.add_child(hit)
	# Ensure enabled immediately and after ready
	hit.monitoring = true
	hit.monitorable = true
	if hit.has_node("CollisionShape2D"):
		hit.get_node("CollisionShape2D").set_deferred("disabled", false)
	hit.call_deferred("enable")
	
	# Debug: log any area overlaps
	hit.area_entered.connect(func(a: Area2D):
		print("[RocketExplosion] overlapped area=", a.name, " groups=", a.get_groups())
		if a.is_in_group("player_hurtbox"):
			# Route damage through player's hurtbox so block/parry works
			if a.has_method("store_hit_data"):
				a.store_hit_data(hit)
			# If player is blocking, let state handle damage
			var parent = a.get_parent()
			if parent and parent.has_node("StateMachine") and parent.state_machine.current_state and parent.state_machine.current_state.name == "Block":
				await parent.state_machine.current_state._on_hurtbox_hurt(hit)
			# Start cooldown if available
			if a.has_method("start_cooldown"):
				a.start_cooldown(hit)
			# Emit hurt signal
			if a.has_signal("hurt"):
				a.hurt.emit(hit)
	)
	print("[RocketExplosion] spawned at ", pos, " layer=", hit.collision_layer, " mask=", hit.collision_mask)
	
	# Birkaç frame aktif kalsın (temas garantisi için)
	var t := get_tree().create_timer(0.35)
	t.timeout.connect(func():
		if is_instance_valid(hit):
			hit.queue_free()
	)

func _fire_cannon_shot() -> void:
	if not target:
		return
	
	# Get projectile from pool instead of instantiating
	var shot = ProjectilePool.get_projectile(cannon_shot_scene, "cannon_shot")
	
	# Sahiplik bilgisini ilet (hitbox oluşturulmadan önce)
	if shot.has_method("set_owner_id"):
		var my_id = get_instance_id()
		shot.set_owner_id(my_id)
	
	# Add to scene tree
	get_tree().current_scene.add_child(shot)
	
	# Top pozisyonu (düşmanın önünde)
	var shot_offset = Vector2(30, -10) if not sprite.flip_h else Vector2(-30, -10)
	shot.global_position = global_position + shot_offset
	
	# Hedef yönü hesapla
	var direction_to_player = global_position.direction_to(target.global_position)
	
	# Top hızı ve yönü
	var shot_speed = CANNON_SHOT_SPEED
	var shot_velocity = direction_to_player * shot_speed
	
	# Top ayarları
	shot.set_direction(direction_to_player)
	shot.set_speed(shot_speed)
	shot.set_damage(CANNON_SHOT_DAMAGE)
	
	print("[Canonman] Fired cannon shot at: ", target.global_position)

func _choose_attack_type() -> void:
	# Saldırı türü seç (rocket jump veya ground shot)
	var player = get_nearest_player()
	if not player:
		return
	
	# Saldırı kilidi varsa hiçbir şey yapma
	if attack_cooldown_timer > 0.0 or not cannon_ready:
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Çok yakınsa ve cooldown bittiyse bazen kaçış rocket jump yap
	if distance <= RETREAT_MIN_DISTANCE and retreat_cooldown_timer <= 0.0:
		if randi() % 100 < 50:  # %50 ihtimalle kaçış
			set_meta("rocket_retreat", true)
			change_behavior("rocket_charge")
			print("[Canonman] Chose ROCKET RETREAT")
			return
	
	# Mesafeye göre saldırı türü seç
	if distance > 300.0:  # Uzak mesafe - rocket jump (yaklaşma)
		change_behavior("rocket_charge")
		print("[Canonman] Chose rocket jump attack")
	else:  # Yakın mesafe - ground shot
		change_behavior("ground_aim")
		print("[Canonman] Chose ground shot attack")

func _fire_ground_shot() -> void:
	# Yere doğru 45 derece atış
	var shot = cannon_shot_scene.instantiate()
	
	# Sahiplik bilgisini ilet (hitbox oluşturulmadan önce)
	if shot.has_method("set_owner_id"):
		var my_id = get_instance_id()
		shot.set_owner_id(my_id)
	
	get_tree().current_scene.add_child(shot)
	
	# Top pozisyonu (düşmanın önünde)
	var shot_offset = Vector2(30, -10) if not sprite.flip_h else Vector2(-30, -10)
	shot.global_position = global_position + shot_offset
	
	# Yere doğru atış yönünü oyuncunun biraz ARKASINI hedefleyecek şekilde ayarla
	var player_pos = target.global_position
	var dir_sign = -1 if sprite.flip_h else 1
	var aim_x_offset = dir_sign * (GROUND_SHOT_DISTANCE + GROUND_SHOT_AIM_OFFSET)
	var aim_point = Vector2(player_pos.x + aim_x_offset, player_pos.y + 10)  # oyuncunun biraz arkasındaki yer
	var to_aim = (aim_point - shot.global_position).normalized()
	# Açı alt limite düşmesin diye biraz aşağıya yön ver (min sin ≈ 0.15)
	var min_down = 0.15
	if to_aim.y < min_down:
		to_aim.y = min_down
		to_aim = to_aim.normalized()
	var direction = to_aim
	
	# Top ayarları
	shot.set_direction(direction)
	shot.set_speed(CANNON_SHOT_SPEED)
	shot.set_damage(CANNON_SHOT_DAMAGE)
	
	print("[Canonman] Fired ground shot toward:", aim_point, " dir:", direction)

func change_behavior(new_behavior: String, force: bool = false) -> void:
	if (current_behavior == new_behavior and not force) or (state_lock > 0.0 and not force):
		return
	
	print("[Canonman] Behavior changed: ", current_behavior, " -> ", new_behavior)
	current_behavior = new_behavior
	behavior_timer = 0.0
	# Clear one-shot metas on state change
	if has_meta("launch_started"):
		remove_meta("launch_started")
	
	# Duruma özel giriş ayarları ve kilitler
	if new_behavior == "walk":
		sprite.speed_scale = 1.0
		state_lock = max(state_lock, 0.25)
	elif new_behavior == "idle":
		sprite.speed_scale = 1.0
		state_lock = max(state_lock, 0.2)
	elif new_behavior in ["rocket_charge", "rocket_fire", "rocket_rise", "rocket_fall", "rocket_land", "ground_aim", "ground_shot", "shoot"]:
		# Savaş animasyonları sırasında rastgele geçişleri önlemek için kısa kilit
		state_lock = max(state_lock, 0.2)
		# Enter-time actions
		if new_behavior == "rocket_fire":
			# Apply launch velocity immediately so the enemy lifts during launch
			var jump_angle = 45.0
			var angle_rad = deg_to_rad(jump_angle)
			var to_player_sign := 1.0
			if target and is_instance_valid(target):
				to_player_sign = sign(target.global_position.x - global_position.x)
				if to_player_sign == 0.0:
					to_player_sign = 1.0
			var retreating := has_meta("rocket_retreat")
			var horizontal_sign = (-to_player_sign) if retreating else to_player_sign
			velocity.x = horizontal_sign * cos(angle_rad) * ROCKET_JUMP_FORCE * 0.7
			velocity.y = -sin(angle_rad) * ROCKET_JUMP_FORCE
			is_rocket_jumping = true
			rocket_landing_position = global_position
			_create_rocket_explosion(global_position)
			# Spawn launch smoke right at takeoff
			_spawn_launch_smoke(global_position)
			if retreating:
				retreat_cooldown_timer = ROCKET_RETREAT_COOLDOWN
				remove_meta("rocket_retreat")
			set_meta("launch_started", true)
	elif new_behavior == "hurt":
		# Hurt durumunda kısa süre kilitle ve animasyonu zorla
		state_lock = max(state_lock, 0.3)
		if sprite:
			sprite.play("cannonman_hurt")
	
	# Meta flag'leri temizle
	if has_meta("cannon_fired"):
		remove_meta("cannon_fired")
	if has_meta("ground_shot_fired"):
		remove_meta("ground_shot_fired")

func _update_animation_state() -> void:
	var animation_name = ""
	
	match current_behavior:
		"idle":
			animation_name = "cannonman_idle"
		"walk":
			animation_name = "cannonman_walk"
		"chase":
			if is_on_floor():
				animation_name = "cannonman_walk"
			else:
				animation_name = "cannonman_idle"
		"rocket_charge":
			animation_name = "cannonman_charge"
		"rocket_fire":
			animation_name = "cannonman_launch"
		"rocket_rise":
			animation_name = "cannonman_rise"
		"rocket_fall":
			animation_name = "cannonman_fall"
		"rocket_land":
			animation_name = "cannonman_landing"
		"aim":
			animation_name = "cannonman_aim"
		"shoot":
			animation_name = "cannonman_fire"
		"ground_aim":
			animation_name = "cannonman_aim"
		"ground_shot":
			animation_name = "cannonman_fire"
		"hurt":
			animation_name = "cannonman_hurt"
		"dead":
			animation_name = "cannonman_death"

	# Global fall override: yüksekten düşerken fall animasyonu oynat
	var is_in_rocket := current_behavior.begins_with("rocket_")
	if not is_on_floor() and velocity.y > 120.0 and not is_in_rocket and current_behavior not in ["dead", "hurt"]:
		animation_name = "cannonman_fall"
	
	# Debug: Animasyon değişikliklerini logla ve sadece değiştiyse başlat
	if sprite.animation != animation_name:
		print("[Canonman] Animation changed: ", sprite.animation, " -> ", animation_name, " (State: ", current_behavior, ")")
		sprite.play(animation_name)

func handle_patrol(delta: float) -> void:
	_handle_idle_state()

func handle_alert(delta: float) -> void:
	_handle_rocket_charge_state(delta)

func handle_chase(delta: float) -> void:
	_handle_rocket_charge_state(delta)

func take_damage(amount: float, knockback_force: float = 200.0, knockback_up_force: float = -1.0) -> void:
	# Call base class take_damage to get blood particles and other effects
	super.take_damage(amount, knockback_force, knockback_up_force)
	
	# Canonman-specific damage handling
	if current_behavior == "dead" or invulnerable:
		return
	
	# Apply knockback - sadece yatay, dikey değil
	if knockback_force > 0:
		var knockback_direction = Vector2(1, 0)  # Default right
		if target and is_instance_valid(target):
			knockback_direction = global_position.direction_to(target.global_position)
		
		# Sadece yatay knockback, dikey yok
		velocity.x = knockback_direction.x * knockback_force * 0.5
	
	# Go to hurt state
	change_behavior("hurt")
	print("[Canonman] Took damage: ", amount, " Health: ", health)

func die() -> void:
	if current_behavior == "dead":
		return
	
	current_behavior = "dead"
	
	# Meta flag'leri temizle
	if has_meta("cannon_fired"):
		remove_meta("cannon_fired")
	
	# Hide health bar
	if health_bar:
		health_bar.hide_bar()
	
	# Play death animation
	if sprite:
		sprite.play("cannonman_death")
		sprite.z_index = 6
	
	# Disable collision - sadece ground collision'ı bırak
	collision_layer = 0
	collision_mask = 1  # Sadece ground tiles ile collision
	
	# Disable components
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	
	# Emit signals
	enemy_defeated.emit()
	PowerupManager.on_enemy_killed()
	
	# Apply death knockback - yavaşça düş
	velocity = Vector2(0, -100)  # Hafif yukarı, sonra gravity ile düşer
