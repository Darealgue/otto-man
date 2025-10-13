class_name FiremageEnemy
extends "res://enemy/base_enemy.gd"

# Firemage specific constants
const HOVER_HEIGHT = 200.0  # Yerden yükseklik
const MAINTAIN_DISTANCE = 250.0  # Oyuncudan mesafe
const FLY_SPEED = 200.0  # Uçuş hızı (daha hızlı)
const WALL_AVOIDANCE_DISTANCE = 50.0  # Duvar kaçınma mesafesi
const BOMB_COOLDOWN = 2.0  # Bomba atma sıklığı (daha sık)
const BOMB_SPEED = 300.0  # Bomba fırlatma hızı
const BOMB_DAMAGE = 25.0  # Bomba hasarı
const BOMB_RADIUS = 80.0  # Patlama yarıçapı

# State tracking
var is_flying: bool = false
var hover_height: float = 0.0
var target_distance: float = MAINTAIN_DISTANCE
var bomb_timer: float = 0.0
var last_bomb_time: float = 0.0

# Node references
@onready var wall_detector: RayCast2D = $WallDetector
@onready var ceiling_detector: RayCast2D = $CeilingDetector
@onready var floor_detector: RayCast2D = $FloorDetector

# Projectile scene
var fire_bomb_scene = preload("res://enemy/firemage/fire_bomb_projectile.tscn")

func _ready() -> void:
	super._ready()
	
	# DEBUG: Collision info
	print("[Firemage] Collision Layer: ", collision_layer)
	print("[Firemage] Collision Mask: ", collision_mask)
	print("[Firemage] Position: ", global_position)
	
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
	
	# Death state - yavaşça düş
	if current_behavior == "dead":
		if not is_sleeping:
			handle_behavior(delta)
		# Death sırasında hafif gravity uygula
		velocity.y += GRAVITY * 0.2 * delta
		move_and_slide()
		return
	
	# Hurt state - havada kalması için hafif gravity
	if current_behavior == "hurt":
		if not is_sleeping:
			handle_behavior(delta)
		# Hurt sırasında çok hafif gravity uygula
		if is_flying:
			velocity.y += GRAVITY * 0.1 * delta
		move_and_slide()
		return
	
	# Takeoff rise veya flying sırasında gravity uygulama
	if current_behavior == "takeoff_rise" or is_flying:
		# Sadece behavior ve hareket
		if not is_sleeping:
			handle_behavior(delta)
		# Sadece hareket et, gravity uygulama
		move_and_slide()
	elif current_behavior == "bombard":
		# Bombard sırasında hafif gravity uygula (çok yükseğe çıkmasın)
		if not is_sleeping:
			handle_behavior(delta)
		# Hafif gravity
		velocity.y += GRAVITY * 0.3 * delta
		move_and_slide()
	else:
		# Normal base enemy physics
		super._physics_process(delta)

func _handle_child_behavior(delta: float) -> void:
	match current_behavior:
		"idle":
			_handle_idle_state()
		"takeoff_prepare":
			_handle_takeoff_prepare_state(delta)
		"takeoff_rise":
			_handle_takeoff_rise_state(delta)
		"flying":
			_handle_flying_state(delta)
		"bombard":
			_handle_bombard_state(delta)
		"fall":
			_handle_fall_state(delta)
		"landing":
			_handle_landing_state(delta)
		"wall_bounce":
			_handle_wall_bounce_state(delta)
		"ceiling_bounce":
			_handle_ceiling_bounce_state(delta)
		"hurt":
			_handle_hurt_state(delta)
		"dead":
			_handle_death_state(delta)
	
	_update_animation_state()

func _handle_idle_state() -> void:
	# Yerdeyken hareket etme
	velocity = Vector2.ZERO
	
	# Hysteresis: sadece yakın mesafede tespit et
	var player = get_nearest_player()
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		# Sadece 400 piksel mesafede tespit et (detection_range'den daha az)
		if distance <= 400.0:
			target = player
			change_behavior("takeoff_prepare")

func _handle_takeoff_prepare_state(delta: float) -> void:
	# Yerde hazırlık animasyonu (3 frame)
	# 3 frame * 0.1 saniye = 0.3 saniye toplam animasyon
	velocity = Vector2.ZERO  # Yerde kal
	
	if behavior_timer >= 0.3:  # 3 frame sonra rise state'e geç
		# Meta flag'i temizle
		if has_meta("takeoff_jumped"):
			remove_meta("takeoff_jumped")
		change_behavior("takeoff_rise")

func _handle_takeoff_rise_state(delta: float) -> void:
	# Havada yükselme animasyonu (5 frame loop)
	# Sadece bir kez zıplama yap
	if not has_meta("takeoff_jumped"):
		velocity.y = -350.0  # Yukarı doğru zıplama (çok daha hızlı yükselme)
		velocity.x = 0.0  # Yatay hareket yok
		set_meta("takeoff_jumped", true)
		print("[Firemage] Takeoff Rise - Jumped! Velocity: ", velocity)
		print("[Firemage] Takeoff Rise - Ceiling detector: ", ceiling_detector.is_colliding())
	
	# DEBUG: Rise state - her 10 frame debug
	if Engine.get_physics_frames() % 10 == 0:
		print("[Firemage] Takeoff Rise - Timer: ", behavior_timer)
		print("[Firemage] Takeoff Rise - Position: ", global_position)
		print("[Firemage] Takeoff Rise - Velocity: ", velocity)
		print("[Firemage] Takeoff Rise - Ceiling detector: ", ceiling_detector.is_colliding())
	
	# Minimum 0.5 saniye bekle, sonra ceiling kontrolü yap
	if behavior_timer >= 0.5:
		# Tepesinde duvar varsa flying'e geç
		if ceiling_detector.is_colliding():
			print("[Firemage] Takeoff Rise - Ceiling detected after 0.5s, going to flying")
			is_flying = true
			change_behavior("flying")
			return
	
	# 0.5 saniye sonra flying'e geç
	if behavior_timer >= 0.5:  # 0.5 saniye rise animasyonu
		print("[Firemage] Takeoff Rise - Timer finished, going to flying")
		is_flying = true
		# Meta flag'i temizle
		if has_meta("takeoff_jumped"):
			remove_meta("takeoff_jumped")
		change_behavior("flying")

func _handle_flying_state(delta: float) -> void:
	if not target or not is_instance_valid(target):
		change_behavior("fall")
		return
	
	# Mesafe kontrolü - daha geniş range ile hysteresis
	var distance_to_player = global_position.distance_to(target.global_position)
	if distance_to_player > stats.detection_range * 2.0:  # Oyuncu çok uzaklaştı (2x range)
		change_behavior("fall")
		return
	
	# Hedef pozisyon hesapla
	var target_pos = _calculate_target_position()
	
	# Yumuşak hareket - mevcut velocity'yi yavaşça hedefe doğru yönlendir
	var direction = global_position.direction_to(target_pos)
	var target_velocity = direction * FLY_SPEED
	
	# Yumuşak geçiş (lerp) - daha smooth
	velocity = velocity.lerp(target_velocity, 2.0 * delta)
	
	# DEBUG: Flying state
	if Engine.get_physics_frames() % 60 == 0:  # Print every second
		print("[Firemage] Flying - Position: ", global_position)
		print("[Firemage] Flying - Velocity: ", velocity)
		print("[Firemage] Flying - Is on floor: ", is_on_floor())
	
	# Duvar kaçınma
	_avoid_obstacles()
	
	move_and_slide()
	
	# Sprite yönü
	sprite.flip_h = velocity.x < 0
	
	# Bomba atma kontrolü
	bomb_timer += delta
	if bomb_timer >= BOMB_COOLDOWN:
		change_behavior("bombard")

func _handle_bombard_state(delta: float) -> void:
	# Bomba atma animasyonu (6 frame: 1-3 prepare, 4-6 fırlatma)
	# 6 frame * 0.1 saniye = 0.6 saniye toplam animasyon
	if behavior_timer >= 0.3 and not has_meta("bomb_thrown"):  # 3 frame sonra (prepare bitince) bomba at
		_throw_fire_bomb()
		set_meta("bomb_thrown", true)
		print("[Firemage] Bomb thrown at timer: ", behavior_timer)
	if behavior_timer >= 0.6:  # 6 frame sonra (animasyon bitince) uçuşa dön
		remove_meta("bomb_thrown")
		print("[Firemage] Bombard finished, going to flying")
		change_behavior("flying")

func _handle_fall_state(delta: float) -> void:
	# Yere düşme - gravity uygula
	velocity.y += GRAVITY * delta
	velocity.x = move_toward(velocity.x, 0, 100 * delta)  # Yatay yavaşlama
	
	move_and_slide()
	
	# Yere değdi mi kontrol et
	if is_on_floor():
		change_behavior("landing")

func _handle_landing_state(delta: float) -> void:
	# Yere iniş animasyonu (3 frame)
	# 3 frame * 0.1 saniye = 0.3 saniye toplam animasyon
	if behavior_timer >= 0.3:  # 3 frame sonra idle'a geç
		is_flying = false
		# Meta flag'i temizle
		if has_meta("takeoff_jumped"):
			remove_meta("takeoff_jumped")
		change_behavior("idle")

func _handle_wall_bounce_state(delta: float) -> void:
	# Duvar çarpma animasyonu (3 frame)
	# 3 frame * 0.1 saniye = 0.3 saniye toplam animasyon
	if behavior_timer >= 0.3:  # 3 frame sonra uçuşa dön
		change_behavior("flying")

func _handle_ceiling_bounce_state(delta: float) -> void:
	# Tavan çarpma animasyonu (3 frame)
	# 3 frame * 0.1 saniye = 0.3 saniye toplam animasyon
	if behavior_timer >= 0.3:  # 3 frame sonra uçuşa dön
		change_behavior("flying")

func _handle_hurt_state(delta: float) -> void:
	# Hasar alma animasyonu (3 frame)
	# 3 frame * 0.1 saniye = 0.3 saniye toplam animasyon
	
	# Havada kalması için hafif gravity uygula
	if is_flying:
		velocity.y += GRAVITY * 0.1 * delta  # Çok hafif gravity
		move_and_slide()
	
	# Behavior timer kontrolü
	if behavior_timer >= 0.3:  # 3 frame sonra uçuşa dön
		if is_flying:
			change_behavior("flying")
		else:
			change_behavior("idle")

func _handle_death_state(delta: float) -> void:
	# Ölüm animasyonu - yavaşça aşağı düş
	velocity.y += GRAVITY * 0.2 * delta  # Hafif gravity
	velocity.x = move_toward(velocity.x, 0, 50 * delta)  # Yatay yavaşlama
	
	# Hareket et
	move_and_slide()
	
	# Death animasyonu 10 frame, 1.2 saniye sürer
	# Animasyon bittiğinde düşmanı yok et
	if behavior_timer >= 1.2:  # 10 frame * 0.12 saniye = 1.2 saniye
		queue_free()

func _calculate_target_position() -> Vector2:
	if not target:
		return global_position
	
	var player_pos = target.global_position
	var direction_to_player = global_position.direction_to(player_pos)
	var distance = global_position.distance_to(player_pos)
	
	# Yumuşak mesafe koruma - daha az agresif
	var target_distance = MAINTAIN_DISTANCE
	var distance_error = distance - target_distance
	
	# Çok daha yumuşak düzeltme
	var correction_factor = clamp(distance_error / (MAINTAIN_DISTANCE * 2.0), -0.2, 0.2)
	var target_pos = global_position + direction_to_player * correction_factor * FLY_SPEED * 0.05
	
	return target_pos

func _throw_fire_bomb() -> void:
	if not target:
		return
	
	# Bomba sahneyi oluştur
	var bomb = fire_bomb_scene.instantiate()
	get_tree().current_scene.add_child(bomb)
	
	# Bomba pozisyonu (düşmanın önünde)
	var bomb_offset = Vector2(30, -20) if not sprite.flip_h else Vector2(-30, -20)
	bomb.global_position = global_position + bomb_offset
	
	# Hedef yönü hesapla
	var direction_to_player = global_position.direction_to(target.global_position)
	
	# Bomba hızı ve yönü
	var bomb_speed = BOMB_SPEED
	var bomb_velocity = direction_to_player * bomb_speed
	
	# Bomba ayarları
	bomb.set_direction(direction_to_player)
	bomb.set_speed(bomb_speed)
	bomb.set_damage(BOMB_DAMAGE)
	bomb.set_radius(BOMB_RADIUS)
	bomb.set_owner_id(get_instance_id())  # Set owner ID for self-damage filtering
	
	# Timer sıfırla
	bomb_timer = 0.0
	
	print("[Firemage] Threw fire bomb at: ", target.global_position)

func _avoid_obstacles() -> void:
	# Duvar kaçınma
	if wall_detector.is_colliding():
		velocity = velocity.rotated(PI/4)  # 45 derece dön
	
	# Tavan kaçınma
	if ceiling_detector.is_colliding():
		velocity.y = abs(velocity.y)  # Aşağı doğru git
	
	# Zemin kaçınma
	if floor_detector.is_colliding():
		velocity.y = -abs(velocity.y)  # Yukarı doğru git


func _update_animation_state() -> void:
	match current_behavior:
		"idle":
			sprite.play("fire_idle")
		"takeoff_prepare":
			sprite.play("fire_takeoff_prepare")
		"takeoff_rise":
			sprite.play("fire_takeoff_rise")
		"flying":
			sprite.play("fire_fly")
		"bombard":
			sprite.play("fire_bomb")
		"fall":
			sprite.play("fire_fall")
		"landing":
			sprite.play("fire_landing")
		"wall_bounce":
			sprite.play("fire_bounce_wall")
		"ceiling_bounce":
			sprite.play("fire_bounce_ceiling")
		"hurt":
			sprite.play("fire_hurt")
		"dead":
			sprite.play("fire_death")

func handle_patrol(delta: float) -> void:
	_handle_idle_state()

func handle_alert(delta: float) -> void:
	_handle_flying_state(delta)

func handle_chase(delta: float) -> void:
	_handle_flying_state(delta)

func take_damage(amount: float, knockback_force: float = 200.0, knockback_up_force: float = -1.0) -> void:
	if current_behavior == "dead" or invulnerable:
		return
	
	# Update health
	health -= amount
	health = max(0, health)
	
	# Emit health changed signal
	health_changed.emit(health, stats.max_health)
	
	# Update health bar
	if health_bar:
		health_bar.update_health(health)
	
	# Spawn damage number
	var damage_number = preload("res://effects/damage_number.tscn").instantiate()
	add_child(damage_number)
	damage_number.global_position = global_position + Vector2(0, -50)
	damage_number.setup(int(amount))
	
	# Apply knockback - sadece yatay, dikey değil (havada kalması için)
	if knockback_force > 0:
		var knockback_direction = Vector2(1, 0)  # Default right
		if target and is_instance_valid(target):
			knockback_direction = global_position.direction_to(target.global_position)
		
		# Sadece yatay knockback, dikey yok (havada kalması için)
		velocity.x = knockback_direction.x * knockback_force * 0.5  # Daha az güçlü
		# velocity.y değiştirme - havada kalsın
	
	# Check if dead
	if health <= 0:
		die()
		return
	
	# Go to hurt state
	change_behavior("hurt")
	# Reset behavior timer for hurt state
	behavior_timer = 0.0
	print("[Firemage] Took damage: ", amount, " Health: ", health)

func apply_gravity(_delta: float) -> void:
	# Override to prevent gravity when flying
	if not is_flying:
		super.apply_gravity(_delta)



func die() -> void:
	if current_behavior == "dead":
		return
	
	current_behavior = "dead"
	
	# Meta flag'leri temizle
	if has_meta("takeoff_jumped"):
		remove_meta("takeoff_jumped")
	if has_meta("bomb_thrown"):
		remove_meta("bomb_thrown")
	
	# Hide health bar
	if health_bar:
		health_bar.hide_bar()
	
	# Play death animation
	if sprite:
		sprite.play("fire_death")
		sprite.z_index = 6
	
	# Disable collision
	collision_layer = 0
	collision_mask = 0
	
	# Disable components
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	
	# Emit signals
	enemy_defeated.emit()
	PowerupManager.on_enemy_killed()
	
	# Apply death knockback
	velocity = Vector2(0, 200)
