extends State

const ATTACK_SPEED_MULTIPLIER = 0.7  # Biraz yavaş hareket aşağı saldırıda
const MOMENTUM_PRESERVATION = 0.9     # Momentum'u daha iyi koru
const ANIMATION_SPEED = 1.3          # 30% faster animations (same as other attacks)
const DOWN_ATTACK_ANIMATIONS = ["air_attack_down1", "air_attack_down2"]  # Down attack varyasyonları

var current_attack := ""
var hitbox_enabled := false
var initial_velocity := Vector2.ZERO
var has_activated_hitbox := false
var rng := RandomNumberGenerator.new()  # RNG for random attack selection

func enter():
	hitbox_enabled = false
	has_activated_hitbox = false
	initial_velocity = player.velocity
	
	# Randomize RNG for random attack selection
	rng.randomize()
	
	# Enter combat state when attacking
	player.enter_combat_state()
	
	# Disconnect previous animation signal if connected
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_finished)
	
	# Connect animation finished signal
	animation_player.animation_finished.connect(_on_animation_finished)
	
	# Down input kontrolü
	var down_strength = Input.get_action_strength("down")
	if down_strength > 0.6:
		# Down attack varyasyonu rastgele seç
		current_attack = DOWN_ATTACK_ANIMATIONS[rng.randi() % DOWN_ATTACK_ANIMATIONS.size()]
		
		# Animasyonu başlat
		animation_player.stop()
		if animation_player.has_animation(current_attack):
			animation_player.play(current_attack)
			animation_player.speed_scale = ANIMATION_SPEED * player.attack_speed_multiplier
		else:
			print("[AirAttackDown] ERROR: Animation not found: ", current_attack)
			state_machine.transition_to("Fall")
			return
	else:
		# Down input yoksa normal air attack'a geç
		state_machine.transition_to("Attack")
		return

func update(delta: float):
	if player.is_on_floor():
		if hitbox_enabled:
			var hitbox = player.get_node_or_null("Hitbox")
			if hitbox and hitbox is PlayerHitbox:
				hitbox.position = Vector2.ZERO
				hitbox.rotation = 0.0
				var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
				if collision_shape:
					collision_shape.position = Vector2(52.625, -22.5)
				hitbox.disable()
		state_machine.transition_to("Idle")
		return
	
	# Down input kontrolü - sürekli down basılı tutulmalı
	var down_strength = Input.get_action_strength("down")
	if down_strength <= 0.6:
		# Down input bırakıldıysa normal fall state'e geç
		state_machine.transition_to("Fall")
		return
	
	# Hitbox kontrolü ve pozisyon güncelleme
	_update_hitbox()
	
	# Hitbox aktifse pozisyonunu güncelle (yön değişiklikleri için)
	if hitbox_enabled:
		_update_hitbox_position()

func physics_update(delta: float) -> void:
	# Movement + gravity must run in physics for consistent feel.
	if get_tree().paused:
		return
	
	_handle_movement(delta)
	
	if not player.is_on_floor():
		if player.get("air_hit_freeze_timer") != null and player.air_hit_freeze_timer > 0.0:
			player.velocity.y = 0.0
		else:
			var gravity_multiplier: float = player.calculate_hollow_knight_gravity()
			if player.get("air_combo_float_timer") != null and player.air_combo_float_timer > 0.0:
				gravity_multiplier *= player.air_combo_gravity_scale
			if player.velocity.y > 0 and Input.is_action_pressed("jump") and has_node("/root/ItemManager") and ItemManager.has_active_item("havada_kal"):
				gravity_multiplier *= 0.28
			player.velocity.y += player.gravity * gravity_multiplier * delta
			var max_fall = player.max_fall_speed
			if player.get("air_combo_float_timer") != null and player.air_combo_float_timer > 0.0:
				max_fall = min(max_fall, player.air_combo_max_fall_speed)
			if player.velocity.y > max_fall:
				player.velocity.y = max_fall
	
	player.apply_move_and_slide()

func _update_hitbox():
	if not animation_player.has_animation(current_attack):
		return
	
	var anim_length = animation_player.current_animation_length
	if anim_length <= 0.0:
		return
	
	var progress = animation_player.current_animation_position / anim_length
	
	# Hit frame (yaklaşık %40-50 arası)
	var hit_start = 0.4
	var hit_end = 0.6
	
	if progress >= hit_start and progress <= hit_end and not has_activated_hitbox:
		# Hitbox'ı aktif et
		hitbox_enabled = true
		has_activated_hitbox = true
		
		# Yer aşağı saldırı (down_light) ile aynı konum: önde + 45° aşağı
		var hitbox = player.get_node_or_null("Hitbox")
		if hitbox and hitbox is PlayerHitbox:
			hitbox.position = Vector2.ZERO
			var facing_left = player.sprite.flip_h
			var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
			if collision_shape:
				var pos = Vector2(52.625, -22.5)  # attack_state ile aynı
				pos.x = abs(pos.x) * (-1 if facing_left else 1)
				collision_shape.position = pos
			var facing_sign = -1.0 if facing_left else 1.0
			hitbox.rotation = deg_to_rad(45.0 * facing_sign)
			hitbox.enable_combo(current_attack, player.light_attack_damage_multiplier)
			var use_ranged_only := has_node("/root/ItemManager") and ItemManager.has_active_item("uzun_menzil")
			if use_ranged_only and player.has_signal("player_light_attack_performed"):
				var facing := -1.0 if facing_left else 1.0
				var dir := Vector2(facing, 1.0).normalized()
				var spawn_center: Vector2 = _get_projectile_spawn_near_edge(hitbox, collision_shape)
				player.emit_signal("player_light_attack_performed", dir, spawn_center, hitbox.damage)
			else:
				if not hitbox.hit_enemy.is_connected(_on_enemy_hit):
					hitbox.hit_enemy.connect(_on_enemy_hit)
				hitbox.enable()
			if player.has_signal("player_attack_performed"):
				player.emit_signal("player_attack_performed", current_attack, hitbox.damage)
	elif progress > hit_end and hitbox_enabled:
		hitbox_enabled = false
		var hitbox = player.get_node_or_null("Hitbox")
		if hitbox and hitbox is PlayerHitbox:
			hitbox.position = Vector2.ZERO
			hitbox.rotation = 0.0
			var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
			if collision_shape:
				collision_shape.position = Vector2(52.625, -22.5)
			hitbox.disable()

func exit():
	# Disconnect animation signal
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_finished)
	
	# Koşu animasyonu hızlanma bug'ını önle: speed_scale sıfırla
	animation_player.speed_scale = 1.0
	
	if hitbox_enabled:
		var hitbox = player.get_node_or_null("Hitbox")
		if hitbox and hitbox is PlayerHitbox:
			hitbox.position = Vector2.ZERO
			hitbox.rotation = 0.0
			var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
			if collision_shape:
				collision_shape.position = Vector2(52.625, -22.5)
			hitbox.disable()

func _on_animation_finished(anim_name: String):
	if anim_name == current_attack:
		# Down attack bitti, fall state'e geç
		state_machine.transition_to("Fall")

func _handle_movement(delta: float) -> void:
	# Get horizontal movement only
	var input_dir_x = InputManager.get_flattened_axis(&"ui_left", &"ui_right")
	
	# Calculate velocity with attack speed multiplier
	var target_velocity = Vector2(
		input_dir_x * player.speed * ATTACK_SPEED_MULTIPLIER,
		player.velocity.y  # Keep vertical velocity unchanged
	)
	
	# Apply momentum preservation
	player.velocity.x = lerp(player.velocity.x, target_velocity.x, 1.0 - MOMENTUM_PRESERVATION)
	
	# Update player facing direction if moving
	if input_dir_x != 0:
		player.sprite.flip_h = input_dir_x < 0
	# NOTE: movement is applied in physics_update()

func _update_hitbox_position():
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox and hitbox_enabled:
		hitbox.position = Vector2.ZERO
		var facing_left = player.sprite.flip_h
		var facing_sign = -1.0 if facing_left else 1.0
		hitbox.rotation = deg_to_rad(45.0 * facing_sign)
		var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape:
			var pos = Vector2(52.625, -22.5)
			pos.x = abs(pos.x) * (-1 if facing_left else 1)
			collision_shape.position = pos

func _get_projectile_spawn_near_edge(hitbox: Node2D, collision_shape: Node2D) -> Vector2:
	if not collision_shape:
		return hitbox.global_position
	var player_node: Node = hitbox.get_parent()
	var shape_center_local: Vector2 = collision_shape.position
	var player_local: Vector2 = hitbox.to_local(player_node.global_position)
	var to_player_local: Vector2 = (player_local - shape_center_local).normalized()
	const HALF_X := 52.375
	const HALF_Y := 24.5
	var face_offset: Vector2
	if abs(to_player_local.x) >= abs(to_player_local.y):
		face_offset = Vector2(52.375 * sign(to_player_local.x), 0.0)
	else:
		face_offset = Vector2(0.0, 24.5 * sign(to_player_local.y))
	return hitbox.to_global(shape_center_local + face_offset)

func _on_enemy_hit(enemy: Node):
	if not has_activated_hitbox:
		has_activated_hitbox = true
