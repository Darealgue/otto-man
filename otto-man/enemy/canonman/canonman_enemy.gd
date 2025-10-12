class_name CanonmanEnemy
extends "res://enemy/base_enemy.gd"

# Canonman specific constants
const ROCKET_JUMP_FORCE = 600.0  # Rocket jump gücü
const ROCKET_JUMP_HEIGHT = 300.0  # Maksimum yükseklik
const CANNON_SHOT_SPEED = 400.0  # Top atış hızı
const CANNON_SHOT_DAMAGE = 30.0  # Top hasarı
const ROCKET_EXPLOSION_DAMAGE = 25.0  # Rocket patlama hasarı
const ROCKET_EXPLOSION_RADIUS = 80.0  # Patlama yarıçapı
const AIM_TIME = 1.0  # Nişan alma süresi
const RELOAD_TIME = 2.0  # Yeniden doldurma süresi
const GROUND_SHOT_ANGLE = 45.0  # Yere doğru atış açısı (derece)
const GROUND_SHOT_DISTANCE = 200.0  # Yere atış mesafesi

# State tracking
var is_rocket_jumping: bool = false
var rocket_landing_position: Vector2
var cannon_ready: bool = true
var aim_timer: float = 0.0
var reload_timer: float = 0.0

# Node references
@onready var wall_detector: RayCast2D = $WallDetector
@onready var ceiling_detector: RayCast2D = $CeilingDetector
@onready var floor_detector: RayCast2D = $FloorDetector

# Projectile scene
var cannon_shot_scene = preload("res://enemy/canonman/cannon_shot_projectile.tscn")

func _ready() -> void:
	super._ready()
	
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
	
	# Hurt state - yerde kal
	if current_behavior == "hurt":
		if not is_sleeping:
			handle_behavior(delta)
		# Hurt sırasında hareket etme
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Death state - hafif gravity ile yavaşça düş
	if current_behavior == "dead":
		if not is_sleeping:
			handle_behavior(delta)
		# Death sırasında hafif gravity uygula
		velocity.y += GRAVITY * 0.3 * delta
		velocity.x = move_toward(velocity.x, 0, 50 * delta)
		move_and_slide()
		return
	
	# Rocket jump sırasında özel physics
	if current_behavior == "rocket_rise" or current_behavior == "rocket_fall":
		if not is_sleeping:
			handle_behavior(delta)
		# Rocket jump physics
		velocity.y += GRAVITY * 0.8 * delta  # Hafif gravity
		move_and_slide()
		return
	
	# Normal base enemy physics
	super._physics_process(delta)

func _handle_child_behavior(delta: float) -> void:
	match current_behavior:
		"idle":
			_handle_idle_state()
		"walk":
			_handle_walk_state(delta)
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
		"reload":
			_handle_reload_state(delta)
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
		elif distance <= stats.detection_range * 1.5:  # Yakın mesafe - yürü
			target = player
			change_behavior("walk")

func _handle_walk_state(delta: float) -> void:
	# Oyuncuya doğru yürü
	if not target or not is_instance_valid(target):
		change_behavior("idle")
		return
	
	var distance = global_position.distance_to(target.global_position)
	
	# Çok yakınsa saldır
	if distance <= stats.detection_range:
		_choose_attack_type()
		return
	
	# Çok uzaksa idle'a dön
	if distance > stats.detection_range * 1.5:
		change_behavior("idle")
		return
	
	# Oyuncuya doğru yürü
	var direction = global_position.direction_to(target.global_position)
	velocity.x = direction.x * stats.movement_speed * 0.5  # Yavaş yürüme
	
	# Sprite yönünü ayarla
	if direction.x > 0:
		sprite.flip_h = false
	elif direction.x < 0:
		sprite.flip_h = true
	
	# Hareket et
	move_and_slide()

func _handle_rocket_charge_state(delta: float) -> void:
	# Rocket jump hazırlığı (3-4 frame)
	velocity = Vector2.ZERO  # Yerde kal
	
	if behavior_timer >= 0.4:  # 4 frame sonra fire state'e geç
		change_behavior("rocket_fire")

func _handle_rocket_fire_state(delta: float) -> void:
	# Cannon'u yere doğru ateşleme (4-5 frame)
	velocity = Vector2.ZERO  # Yerde kal
	
	print("[Canonman] Rocket fire state - behavior_timer: ", behavior_timer, " / 0.4")
	
	if behavior_timer >= 0.4:  # 4 frame sonra rise state'e geç
		# Rocket jump başlat - yay şeklinde hareket
		var jump_angle = 45.0  # 45 derece açıyla zıpla
		var angle_rad = deg_to_rad(jump_angle)
		
		# Yatay ve dikey hız hesapla
		velocity.x = cos(angle_rad) * ROCKET_JUMP_FORCE * 0.7  # Yatay hız
		velocity.y = -sin(angle_rad) * ROCKET_JUMP_FORCE  # Dikey hız
		
		# Sprite yönüne göre yatay hızı ayarla
		if sprite.flip_h:
			velocity.x = -velocity.x
		
		is_rocket_jumping = true
		rocket_landing_position = global_position  # İniş pozisyonunu kaydet
		
		# Kalkış noktasında patlama hasarı
		_create_rocket_explosion(global_position)
		
		change_behavior("rocket_rise")
		print("[Canonman] Rocket jump started! Velocity: ", velocity)

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
		# İniş noktasında patlama hasarı
		_create_rocket_explosion(global_position)
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
	
	if behavior_timer >= 0.4:  # 4 frame sonra shoot state'e geç
		change_behavior("shoot")

func _handle_shoot_state(delta: float) -> void:
	# Top atışı (4-5 frame)
	velocity = Vector2.ZERO  # Yerde kal
	
	if behavior_timer >= 0.3 and not has_meta("cannon_fired"):  # 3 frame sonra top at
		_fire_cannon_shot()
		set_meta("cannon_fired", true)
		cannon_ready = false
	
	if behavior_timer >= 0.5:  # 5 frame sonra reload state'e geç
		remove_meta("cannon_fired")
		change_behavior("reload")

func _handle_reload_state(delta: float) -> void:
	# Yeniden doldurma (5-6 frame)
	velocity = Vector2.ZERO  # Yerde kal
	reload_timer += delta
	
	if behavior_timer >= 0.6:  # 6 frame sonra idle'a dön
		cannon_ready = true
		reload_timer = 0.0
		change_behavior("idle")

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
	
	if behavior_timer >= 0.5:  # 5 frame sonra reload state'e geç
		remove_meta("ground_shot_fired")
		change_behavior("reload")

func _handle_hurt_state(delta: float) -> void:
	# Hasar alma animasyonu (3 frame)
	velocity = Vector2.ZERO  # Yerde kal
	
	print("[Canonman] Hurt state - behavior_timer: ", behavior_timer, " / 0.3")
	
	if behavior_timer >= 0.3:  # 3 frame sonra idle'a dön
		print("[Canonman] Hurt state finished, changing to idle")
		change_behavior("idle")

func _handle_death_state(delta: float) -> void:
	# Ölüm animasyonu - hafif gravity ile yavaşça düş
	velocity.y += GRAVITY * 0.3 * delta  # Hafif gravity
	velocity.x = move_toward(velocity.x, 0, 50 * delta)  # Yatay yavaşlama
	
	# Hareket et
	move_and_slide()
	
	# Death animasyonu 10 frame, 1.2 saniye sürer
	if behavior_timer >= 1.2:  # 10 frame * 0.12 saniye = 1.2 saniye
		queue_free()

func _create_rocket_explosion(pos: Vector2) -> void:
	# Rocket patlama efekti oluştur
	var explosion = preload("res://effects/explosion_range_visual.tscn").instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = pos
	explosion.set_radius(ROCKET_EXPLOSION_RADIUS)
	
	# Oyuncuya hasar ver
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.global_position.distance_to(pos) <= ROCKET_EXPLOSION_RADIUS:
			player.take_damage(ROCKET_EXPLOSION_DAMAGE)
	
	print("[Canonman] Rocket explosion at: ", pos)

func _fire_cannon_shot() -> void:
	if not target:
		return
	
	# Top sahneyi oluştur
	var shot = cannon_shot_scene.instantiate()
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
	
	var distance = global_position.distance_to(player.global_position)
	
	# Mesafeye göre saldırı türü seç
	if distance > 300.0:  # Uzak mesafe - rocket jump
		change_behavior("rocket_charge")
		print("[Canonman] Chose rocket jump attack")
	else:  # Yakın mesafe - ground shot
		change_behavior("ground_aim")
		print("[Canonman] Chose ground shot attack")

func _fire_ground_shot() -> void:
	# Yere doğru 45 derece atış
	var shot = cannon_shot_scene.instantiate()
	get_tree().current_scene.add_child(shot)
	
	# Top pozisyonu (düşmanın önünde)
	var shot_offset = Vector2(30, -10) if not sprite.flip_h else Vector2(-30, -10)
	shot.global_position = global_position + shot_offset
	
	# 45 derece açıyla yere doğru atış
	var angle_rad = deg_to_rad(GROUND_SHOT_ANGLE)
	var direction = Vector2(cos(angle_rad), sin(angle_rad))
	if sprite.flip_h:
		direction.x = -direction.x
	
	# Top ayarları
	shot.set_direction(direction)
	shot.set_speed(CANNON_SHOT_SPEED)
	shot.set_damage(CANNON_SHOT_DAMAGE)
	
	print("[Canonman] Fired ground shot at angle: ", GROUND_SHOT_ANGLE)

func change_behavior(new_behavior: String, force: bool = false) -> void:
	if current_behavior == new_behavior and not force:
		return
	
	print("[Canonman] Behavior changed: ", current_behavior, " -> ", new_behavior)
	current_behavior = new_behavior
	behavior_timer = 0.0
	
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
		"reload":
			animation_name = "cannonman_charge"  # Reload için charge animasyonu kullan
		"ground_aim":
			animation_name = "cannonman_aim"
		"ground_shot":
			animation_name = "cannonman_fire"
		"hurt":
			animation_name = "cannonman_hurt"
		"dead":
			animation_name = "cannonman_death"
	
	# Debug: Animasyon değişikliklerini logla
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
	
	# Apply knockback - sadece yatay, dikey değil
	if knockback_force > 0:
		var knockback_direction = Vector2(1, 0)  # Default right
		if target and is_instance_valid(target):
			knockback_direction = global_position.direction_to(target.global_position)
		
		# Sadece yatay knockback, dikey yok
		velocity.x = knockback_direction.x * knockback_force * 0.5
	
	# Check if dead
	if health <= 0:
		die()
		return
	
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
