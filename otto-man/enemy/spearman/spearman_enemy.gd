class_name SpearmanEnemy
extends "res://enemy/base_enemy.gd"

@export var default_stats: EnemyStats

# Movement and behavior
const PATROL_SPEED := 60.0
const CHARGE_SPEED := 420.0
const CHARGE_TIME := 1.8      # toplam charge süresi; oyuncu kaçsa da bu kadar devam
const CRASH_BRAKE := 1600.0   # crash/durma sırasında x hızını düşürme ivmesi (daha uzun kayma)
const HURT_BRAKE := 2000.0
const STOP_TIME := 0.6        # charge biterken stop animasyonu süresi (daha uzun kayma)
const STOP_SLIDE_PX := 60.0   # stop sırasında minimum kayma mesafesi
const STOP_MIN_SPEED := 140.0 # stop kayarken taban hız
const MEMORY_TIME := 2.5      # oyuncuyu hatırlama süresi (sn)
const HITBOX_AHEAD := 40.0    # mızrak ucu ileri mesafe (merkeze kadar kapsama için kullanılır)
const LOST_IDLE_TIME := 0.8   # oyuncu kaybolunca bekleme süresi
const MEMORY_FACE_EPSILON := 24.0  # hatırlanan x'e çok yakınsa flip etme (jitter önleme)
const PATROL_TIME_MIN := 6.0
const PATROL_TIME_MAX := 10.0
const IDLE_TIME_MIN := 3.0
const IDLE_TIME_MAX := 5.0
const PARRY_RECOVERY_TIME := 1.1  # parry sonrası karşı saldırı penceresi

# Damage
const CHARGE_DAMAGE := 25.0
const CHARGE_KNOCKBACK := 2400.0
const CHARGE_UP_KNOCKBACK := 100.0

# Detection (front-only rectangle)
@export var detection_width: float = 520.0
@export var detection_height: float = 80.0
@export var detection_forward: float = 540.0

# State flags
var is_charging := false
var charge_time_left := 0.0
var crash_time_left := 0.0
var crash_slide_left := 0.0
var memory_time_left: float = 0.0
var remembered_target_x: float = 0.0
var next_crash_anim: String = ""
var idle_hold_timer: float = 0.0
var _prev_memory_time: float = 0.0
var turn_cooldown: float = 0.0
var patrol_time_left: float = 0.0
var post_hurt_charge_lock: float = 0.0
var face_delay_timer: float = 0.0
var pending_face_dir: int = 0
var parry_recovery_left: float = 0.0

# Charge direction is locked at start of charge
var charge_dir_x := 1.0

func _ready() -> void:
	if not stats:
		stats = default_stats

	super._ready()
	
	set_collision_layer_value(3, true)   # Enemy body on layer 3 (like other enemies)
	set_collision_mask_value(1, true)    # Collide with world
	set_collision_mask_value(2, false)   # Do NOT collide with player body (pass-through handled via hitboxes)
	set_collision_mask_value(10, true)   # Platforms

	direction = 1
	change_behavior("idle")

func _set_enemy_body_collision(enabled: bool) -> void:
	# Layer 3 is used as ENEMY body layer across enemies
	set_collision_mask_value(3, enabled)

func _is_position_safe(pos: Vector2) -> bool:
	# Check if position is safe (not inside walls/ground)
	var space_state = get_world_2d().direct_space_state
	
	# Check multiple points around the enemy
	var check_points = [
		pos,  # Center
		pos + Vector2(-15, -15),  # Top-left
		pos + Vector2(15, -15),   # Top-right
		pos + Vector2(-15, 15),   # Bottom-left
		pos + Vector2(15, 15)     # Bottom-right
	]
	
	for point in check_points:
		var query = PhysicsPointQueryParameters2D.new()
		query.position = point
		query.collision_mask = CollisionLayers.WORLD  # Only check world collision
		var result = space_state.intersect_point(query)
		if result:
			return false  # Position is inside world geometry
	
	return true  # Position is safe

func _physics_process(delta: float) -> void:
	# Hurt özel
	if current_behavior == "hurt":
		handle_hurt_behavior(delta)
		return

	super._physics_process(delta)

	# Hafıza zamanlayıcısını azalt
	_prev_memory_time = memory_time_left
	memory_time_left = max(0.0, memory_time_left - delta)
	if _prev_memory_time > 0.0 and memory_time_left <= 0.0:
		idle_hold_timer = LOST_IDLE_TIME
		if current_behavior == "patrol":
			change_behavior("idle")
	# Timers
	if idle_hold_timer > 0.0:
		idle_hold_timer -= delta
	if turn_cooldown > 0.0:
		turn_cooldown -= delta
	if post_hurt_charge_lock > 0.0:
		post_hurt_charge_lock -= delta
	if parry_recovery_left > 0.0:
		parry_recovery_left -= delta
	if face_delay_timer > 0.0:
		face_delay_timer -= delta
		if face_delay_timer <= 0.0 and pending_face_dir != 0:
			direction = pending_face_dir
			pending_face_dir = 0

func handle_behavior(delta: float) -> void:
	# Spearman kendi davranış akışını yönetir; base'in idle->patrol eşlemesini kullanma
	behavior_timer += delta
	# Global fall kontrolü: yerde değilse ve düşüyorsa fall'a geç
	if current_behavior != "dead":
		if not is_on_floor() and velocity.y > 10.0 and current_behavior != "fall":
			change_behavior("fall")
			return
		elif current_behavior == "fall" and is_on_floor():
			change_behavior("idle")
			return
	match current_behavior:
		"idle":
			handle_idle(delta)
		"patrol":
			handle_patrol(delta)
		"charge":
			handle_charge(delta)
		"crash":
			handle_crash(delta)
		"hurt":
			handle_hurt_behavior(delta)
		"fall":
			handle_fall(delta)
		"dead":
			return

func _handle_child_behavior(delta: float) -> void:
	match current_behavior:
		"idle":
			handle_idle(delta)
		"patrol":
			handle_patrol(delta)
		"charge":
			handle_charge(delta)
		"crash":
			handle_crash(delta)

func change_behavior(new_behavior: String, force: bool=false) -> void:
	var prev := current_behavior
	super.change_behavior(new_behavior, force)
	if new_behavior == prev and not force:
		return
	match new_behavior:
		"idle":
			_set_anim_safe("idle")
			# Rastgele idle süresi ekle (kaybolma beklemesi ile birleşik)
			idle_hold_timer = max(idle_hold_timer, randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX))
		"patrol":
			_set_anim_safe("patrol")
			patrol_time_left = randf_range(PATROL_TIME_MIN, PATROL_TIME_MAX)
		"charge":
			_set_anim_safe("charge")
		"crash":
			if next_crash_anim != "":
				_set_anim_safe(next_crash_anim)
				next_crash_anim = ""
			else:
				_set_anim_any(["stop", "crash"])  # stop varsa onu kullan
		"hurt":
			_set_anim_safe("hurt")
		"fall":
			_set_anim_safe("fall")
			if hitbox:
				hitbox.disable()

func _set_anim_safe(anim: String) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	if sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim:
			sprite.play(anim)

func _set_anim_any(anims: Array[String]) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	for a in anims:
		if sprite.sprite_frames.has_animation(a):
			if sprite.animation != a:
				sprite.play(a)
			return

func handle_fall(delta: float) -> void:
	# Düşerken x hızını yumuşat, flip'i koru
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	if sprite:
		sprite.flip_h = direction < 0

func handle_idle(delta: float) -> void:
	# Oyuncu hatırlanıyorsa yüzü o yöne çevir
	if memory_time_left > 0.0:
		var dx: float = remembered_target_x - global_position.x
		var dir_to_mem: int = int(sign(dx))
		if abs(dx) > MEMORY_FACE_EPSILON and dir_to_mem != 0 and dir_to_mem != direction and turn_cooldown <= 0.0:
			direction = dir_to_mem
			turn_cooldown = 0.3
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	velocity.y = 0
	_set_anim_safe("idle")
	if sprite:
		sprite.flip_h = direction < 0

	var p = get_player_in_front()
	if p and post_hurt_charge_lock <= 0.0 and parry_recovery_left <= 0.0:
		start_charge_towards(p)
		return

	if idle_hold_timer > 0.0:
		return
	if abs(velocity.x) < 5.0:
		change_behavior("patrol")

func handle_patrol(delta: float) -> void:
	# Oyuncu hatırdaysa sürekli o yöne bak
	if memory_time_left > 0.0:
		var dx: float = remembered_target_x - global_position.x
		var dir_to_mem: int = int(sign(dx))
		if abs(dx) > MEMORY_FACE_EPSILON and dir_to_mem != 0 and dir_to_mem != direction and turn_cooldown <= 0.0:
			direction = dir_to_mem
			turn_cooldown = 0.3
	velocity.x = PATROL_SPEED * direction
	velocity.y = 0
	_set_anim_safe("patrol")
	if sprite:
		sprite.flip_h = direction < 0

	# Hafıza varsa hedefe yaklaş; görürsen charge
	if memory_time_left > 0.0 and abs(remembered_target_x - global_position.x) < detection_forward and post_hurt_charge_lock <= 0.0 and parry_recovery_left <= 0.0:
		# Önümüzdeyse ve yakınsa detect fonksiyonunu zorla
		var p = get_player_in_front()
		if p:
			start_charge_towards(p)
			return

	# Rastgele devre: süre bitince idle'a dön
	patrol_time_left -= delta
	if patrol_time_left <= 0.0:
		change_behavior("idle")
		return

	if idle_hold_timer > 0.0:
		change_behavior("idle")
		return
	if (is_on_wall() or not is_on_floor()) and turn_cooldown <= 0.0:
		direction *= -1
		velocity.x = PATROL_SPEED * direction
		turn_cooldown = 0.4

	var p = get_player_in_front()
	if p:
		start_charge_towards(p)
		return

func handle_charge(delta: float) -> void:
	# Charge sırasında invulnerable ve unstoppable
	# Knockback/stun yok; ancak hasar alabilsin diye invulnerable kullanmıyoruz
	invulnerable = false
	
	# Yön kilitli: charge başladığında belirlenen yatay yön korunur
	velocity.x = CHARGE_SPEED * charge_dir_x
	# y eksenine yerçekimi uygulama, bu düşman zeminde koşsun
	velocity.y = 0

	# Hafızayı canlı tut: hedef görünüyorsa sürekli güncelle
	if target and is_instance_valid(target):
		remembered_target_x = target.global_position.x
		memory_time_left = MEMORY_TIME

	# Parry kontrolü: EnemyHitbox parrylenmişse saldırıyı derhal kes
	if hitbox and hitbox.has_method("setup_attack") and hitbox.get("is_parried") == true:
		# Hitbox'ı kapat ve crash'e geç (savrulma etkisi)
		hitbox.disable()
		hitbox.set("is_parried", false)
		parry_recovery_left = PARRY_RECOVERY_TIME
		do_crash("hit")
		return

	# Hitbox'u mızrak ucuna taşı ve açık tut
	if hitbox:
		if not hitbox.is_in_group("hitbox"):
			hitbox.add_to_group("hitbox")
		# Kullanıcının sahnede konumlandırdığı şekli esas al; sadece yöne göre ayna
		hitbox.scale.x = charge_dir_x

	# Çarpma/hit: Damage artık EnemyHitbox tarafından uygulanıyor
	# Burada sadece sinyal üzerinden crash tetiklenecek

	# Duvara çarparsa dur
	if is_on_wall():
		do_crash("wall")
		return

	# Süre dolunca dur
	charge_time_left -= delta
	if charge_time_left <= 0.0:
		do_crash("timeout")
		return

func handle_crash(delta: float) -> void:
	# Hızını hızla kes ve kısa süre sonra idle'a dön
	invulnerable = false
	# Kayma mesafesini say: bu frame'de kat edilecek yol tahmini
	var speed: float = abs(velocity.x)
	var moved: float = speed * delta
	crash_slide_left -= moved
	if crash_slide_left < 0.0:
		crash_slide_left = 0.0
	
	# Fren uygula ama minimum kayma hızını koru
	var sign_x: float = 1.0 if velocity.x >= 0.0 else -1.0
	var decel_speed: float = speed - CRASH_BRAKE * delta
	if decel_speed < 0.0:
		decel_speed = 0.0
	if crash_slide_left > 0.0 and decel_speed < STOP_MIN_SPEED:
		decel_speed = STOP_MIN_SPEED
	velocity.x = decel_speed * sign_x
	velocity.y = 0
	# stop penceresi - hafif kayma devam eder
	crash_time_left -= delta
	var slow_enough: bool = abs(velocity.x) <= 20.0 and crash_slide_left <= 0.0
	if crash_time_left <= 0.0 or slow_enough:
		change_behavior("idle")

func start_charge_towards(p: Node2D) -> void:
	if post_hurt_charge_lock > 0.0:
		# Şimdilik sadece hatırla ve yüzünü çevir
		remembered_target_x = p.global_position.x
		memory_time_left = MEMORY_TIME
		return
	target = p
	is_charging = true
	invulnerable = false
	charge_time_left = CHARGE_TIME
	# Oyuncuyu hatırla
	memory_time_left = MEMORY_TIME
	remembered_target_x = p.global_position.x
	# Başlangıçta yönü kilitle
	charge_dir_x = sign((p.global_position - global_position).x)
	if charge_dir_x == 0:
		charge_dir_x = direction
	direction = int(charge_dir_x)
	change_behavior("charge")
	# Allow passing through other enemies during charge
	_set_enemy_body_collision(false)
	# Sprite yönü sadece flip ile yönetilsin
	if sprite:
		sprite.flip_h = charge_dir_x < 0
	# Hitbox ayarları (oyuncu hurt state ve knockback için)
	if hitbox:
		if hitbox.has_method("setup_attack"):
			hitbox.damage = CHARGE_DAMAGE
			hitbox.knockback_force = CHARGE_KNOCKBACK
			hitbox.knockback_up_force = CHARGE_UP_KNOCKBACK
			hitbox.setup_attack("charge", true, 0.0)
			hitbox.set("is_parried", false)
			if not hitbox.hit_player.is_connected(_on_hit_player):
				hitbox.hit_player.connect(_on_hit_player)
		else:
			hitbox.damage = CHARGE_DAMAGE
			hitbox.knockback_force = CHARGE_KNOCKBACK
			hitbox.knockback_up_force = CHARGE_UP_KNOCKBACK
		hitbox.scale.x = charge_dir_x
		hitbox.set_meta("owner_id", get_instance_id())
		hitbox.enable()

func do_crash(cause: String = "timeout") -> void:
	is_charging = false
	invulnerable = false
	# Crash animasyonu seçimi: çarpışma (hit/wall) => "crash", süre biterse => "stop"
	if cause == "hit" or cause == "wall":
		next_crash_anim = "crash"
	else:
		next_crash_anim = "stop"
	change_behavior("crash")
	crash_time_left = STOP_TIME
	crash_slide_left = STOP_SLIDE_PX
	# Restore enemy collision immediately when charge ends
	_set_enemy_body_collision(true)
	# Hitbox'ı kapat
	if hitbox:
		hitbox.disable()
	# Crash'ten sonra hafıza devam etsin (oyuncuyu kovalasın)
	if target and is_instance_valid(target):
		remembered_target_x = target.global_position.x
		memory_time_left = MEMORY_TIME

func _on_hit_player(_player: Node) -> void:
	# EnemyHitbox bildirimi ile tek kez crash tetikle
	if current_behavior == "charge":
		do_crash("hit")

func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	# Darbe yönünü ve kaynağı hafızaya al, ama hemen şarj etme
	var src := hitbox.get_parent()
	if src and src is Node2D:
		var src_x := (src as Node2D).global_position.x
		remembered_target_x = src_x
		memory_time_left = MEMORY_TIME
		var dir_to_src: int = int(sign(src_x - global_position.x))
		if dir_to_src != 0 and dir_to_src != direction:
			pending_face_dir = dir_to_src
			face_delay_timer = 0.25  # anında arkasına dönmesin, oyuncuya kaçış şansı
			turn_cooldown = 0.3
		post_hurt_charge_lock = 0.7
	# Normal hasar akışı
	super._on_hurtbox_hurt(hitbox)

func handle_hurt_behavior(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, HURT_BRAKE * delta)
	velocity.y = 0
	behavior_timer += delta
	if behavior_timer >= 0.25 and abs(velocity.x) <= 25.0:
		behavior_timer = 0.0
		change_behavior("idle")
		if hurtbox:
			hurtbox.monitoring = true
			hurtbox.monitorable = true

func get_player_in_front() -> Node2D:
	# Sadece önündeki dikdörtgen alan: genişlik=detection_width, yükseklik=detection_height,
	# ileri mesafe=detection_forward. Arka ve üst/alt dışarıda kalır
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if not is_instance_valid(p):
			continue
		var rel = p.global_position - global_position
		var facing = sign(direction)
		if facing == 0:
			facing = 1
		# Önünde mi?
		if (facing > 0 and rel.x <= 0) or (facing < 0 and rel.x >= 0):
			continue
		# İleri mesafe ve yükseklik sınırları
		if abs(rel.y) <= detection_height * 0.5 and abs(rel.x) <= detection_forward:
			# Hatırlama için son görülen x'i güncelle
			memory_time_left = MEMORY_TIME
			remembered_target_x = p.global_position.x
			return p
	return null

func die() -> void:
	# Prevent flying away on death: no knockback, zero velocity
	if current_behavior == "dead":
		return
	current_behavior = "dead"
	if health_bar:
		health_bar.hide_bar()
	enemy_defeated.emit()
	PowerupManager.on_enemy_killed()
	if sprite:
		sprite.play("death")
		sprite.z_index = 6
	# Stop all movement and collisions
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	# Begin fade-out like base, without knockback
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	fade_out = true
