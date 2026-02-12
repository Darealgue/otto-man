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
			animation_player.speed_scale = ANIMATION_SPEED
		else:
			print("[AirAttackDown] ERROR: Animation not found: ", current_attack)
			state_machine.transition_to("Fall")
			return
	else:
		# Down input yoksa normal air attack'a geç
		state_machine.transition_to("Attack")
		return

func update(delta: float):
	# Yere değme kontrolü - down attack sırasında yere değerse iptal et
	if player.is_on_floor():
		# Hitbox'ı temizle
		if hitbox_enabled:
			var hitbox = player.get_node_or_null("Hitbox")
			if hitbox and hitbox is PlayerHitbox:
				# CollisionShape2D pozisyonunu sıfırla
				var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
				if collision_shape:
					collision_shape.position = Vector2(52.625, -22.5)  # Orijinal pozisyona döndür
				
				hitbox.disable()
		state_machine.transition_to("Idle")
		return
	
	# Down input kontrolü - sürekli down basılı tutulmalı
	var down_strength = Input.get_action_strength("down")
	if down_strength <= 0.6:
		# Down input bırakıldıysa normal fall state'e geç
		state_machine.transition_to("Fall")
		return
	
	# Normal air attack hareket sistemi kullan
	_handle_movement(delta)
	
	# Hitbox kontrolü ve pozisyon güncelleme
	_update_hitbox()
	
	# Hitbox aktifse pozisyonunu güncelle (yön değişiklikleri için)
	if hitbox_enabled:
		_update_hitbox_position()

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
		
		# Hitbox'ı player'ın altında konumlandır ve bakış yönüne göre ayarla
		var hitbox = player.get_node_or_null("Hitbox")
		if hitbox and hitbox is PlayerHitbox:
			# CollisionShape2D pozisyonunu ayarla
			var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
			if collision_shape:
				# Down attack için özel pozisyon (aşağı ve öne)
				var base_position = Vector2(25, 5)  # 25 piksel öne, 25 piksel yukarı (30-25=5)
				var position = base_position
				
				# Oyuncunun bakış yönüne göre X pozisyonunu ayarla
				position.x = abs(position.x) * (-1 if player.sprite.flip_h else 1)
				collision_shape.position = position
			
			# Enable combo with current attack
			hitbox.enable_combo(current_attack, 1.0)
			# Connect hit_enemy signal if not already connected
			if not hitbox.hit_enemy.is_connected(_on_enemy_hit):
				hitbox.hit_enemy.connect(_on_enemy_hit)
			hitbox.enable()
	elif progress > hit_end and hitbox_enabled:
		# Hitbox'ı deaktif et
		hitbox_enabled = false
		var hitbox = player.get_node_or_null("Hitbox")
		if hitbox and hitbox is PlayerHitbox:
			# CollisionShape2D pozisyonunu sıfırla
			var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
			if collision_shape:
				collision_shape.position = Vector2(52.625, -22.5)  # Orijinal pozisyona döndür
			
			hitbox.disable()

func exit():
	# Disconnect animation signal
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_finished)
	
	# Hitbox'ı temizle
	if hitbox_enabled:
		var hitbox = player.get_node_or_null("Hitbox")
		if hitbox and hitbox is PlayerHitbox:
			# CollisionShape2D pozisyonunu sıfırla
			var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
			if collision_shape:
				collision_shape.position = Vector2(52.625, -22.5)  # Orijinal pozisyona döndür
			
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
	
	# Apply movement
	player.move_and_slide()

func _update_hitbox_position():
	# Hitbox pozisyonunu oyuncunun bakış yönüne göre güncelle
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox and hitbox_enabled:
		var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape:
			# Down attack için özel pozisyon (aşağı ve öne)
			var base_position = Vector2(25, 5)  # 25 piksel öne, 25 piksel yukarı (30-25=5)
			var position = base_position
			
			# Oyuncunun bakış yönüne göre X pozisyonunu ayarla
			position.x = abs(position.x) * (-1 if player.sprite.flip_h else 1)
			collision_shape.position = position

func _on_enemy_hit(enemy: Node):
	if not has_activated_hitbox:
		has_activated_hitbox = true
