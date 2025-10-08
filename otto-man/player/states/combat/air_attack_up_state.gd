extends State

const ATTACK_SPEED_MULTIPLIER = 0.7  # Biraz yavaş hareket yukarı saldırıda
const MOMENTUM_PRESERVATION = 0.9     # Momentum'u daha iyi koru
const ANIMATION_SPEED = 1.0          # Normal animasyon hızı
const UP_ATTACK_ANIMATIONS = ["air_attack_up1", "air_attack_up2"]  # Up attack varyasyonları

var current_attack := ""
var hitbox_enabled := false
var initial_velocity := Vector2.ZERO
var has_activated_hitbox := false
var up_attack_step := 0
var up_attack_timer := 0.0
var up_attack_reset_time := 0.8

func enter():
	hitbox_enabled = false
	has_activated_hitbox = false
	initial_velocity = player.velocity
	
	# Enter combat state when attacking
	player.enter_combat_state()
	
	# Disconnect previous animation signal if connected
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_finished)
	
	# Connect animation finished signal
	animation_player.animation_finished.connect(_on_animation_finished)
	
	# Up input kontrolü
	var up_strength = Input.get_action_strength("up")
	if up_strength > 0.6:
		# Up attack varyasyonu seç
		if up_attack_timer <= 0.0:
			up_attack_step = 0
		current_attack = UP_ATTACK_ANIMATIONS[min(up_attack_step, UP_ATTACK_ANIMATIONS.size() - 1)]
		
		# Animasyonu başlat
		animation_player.stop()
		if animation_player.has_animation(current_attack):
			animation_player.play(current_attack)
			animation_player.speed_scale = ANIMATION_SPEED
			print("[AirAttackUp] Starting up attack: ", current_attack)
		else:
			print("[AirAttackUp] ERROR: Animation not found: ", current_attack)
			state_machine.transition_to("Fall")
			return
	else:
		# Up input yoksa normal air attack'a geç
		state_machine.transition_to("Attack")
		return

func update(delta: float):
	# Yere değme kontrolü - up attack sırasında yere değerse iptal et
	if player.is_on_floor():
		print("[AirAttackUp] Player landed during up attack, canceling attack")
		# Hitbox'ı temizle
		if hitbox_enabled:
			var hitbox = player.get_node_or_null("Hitbox")
			if hitbox and hitbox is PlayerHitbox:
				# CollisionShape2D pozisyonunu sıfırla
				var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
				if collision_shape:
					collision_shape.position = Vector2(52.625, -22.5)  # Orijinal pozisyona döndür
					print("[AirAttackUp] Hitbox position reset on landing: ", collision_shape.position)
				
				hitbox.disable()
		state_machine.transition_to("Idle")
		return
	
	# Up input kontrolü - sürekli up basılı tutulmalı
	var up_strength = Input.get_action_strength("up")
	if up_strength <= 0.6:
		# Up input bırakıldıysa normal fall state'e geç
		state_machine.transition_to("Fall")
		return
	
	# Normal air attack hareket sistemi kullan
	_handle_movement(delta)
	
	# Hitbox kontrolü ve pozisyon güncelleme
	_update_hitbox()
	
	# Hitbox aktifse pozisyonunu güncelle (yön değişiklikleri için)
	if hitbox_enabled:
		_update_hitbox_position()
	
	# Up attack combo timer
	up_attack_timer = max(0.0, up_attack_timer - delta)

func _update_hitbox():
	if not animation_player.has_animation(current_attack):
		return
	
	var anim_length = animation_player.current_animation_length
	if anim_length <= 0.0:
		return
	
	var progress = animation_player.current_animation_position / anim_length
	
	# 3. frame hit frame (yaklaşık %40-50 arası)
	var hit_start = 0.4
	var hit_end = 0.6
	
	if progress >= hit_start and progress <= hit_end and not has_activated_hitbox:
		# Hitbox'ı aktif et
		hitbox_enabled = true
		has_activated_hitbox = true
		print("[AirAttackUp] Hitbox activated at frame 3")
		
		# Hitbox'ı player'ın üstünde konumlandır ve bakış yönüne göre ayarla
		var hitbox = player.get_node_or_null("Hitbox")
		if hitbox and hitbox is PlayerHitbox:
			# CollisionShape2D pozisyonunu ayarla
			var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
			if collision_shape:
				# Up attack için özel pozisyon (yukarı ve merkez)
				var base_position = Vector2(-10, -60)  # Base pozisyon (sağa bakarken)
				var position = base_position
				
				# Oyuncunun bakış yönüne göre X pozisyonunu ayarla
				position.x = abs(position.x) * (-1 if player.sprite.flip_h else 1)
				collision_shape.position = position
				
				# Debug: Hitbox positioned
				# print("[AirAttackUp] Hitbox positioned - facing: ", "left" if player.sprite.flip_h else "right", " x: ", position.x, " y: ", position.y, " collision_shape.position: ", collision_shape.position)
			
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
				print("[AirAttackUp] Hitbox position reset to: ", collision_shape.position)
			
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
				print("[AirAttackUp] Hitbox position reset to: ", collision_shape.position)
			
			hitbox.disable()
	
	# Up attack combo step'i ilerlet
	if up_attack_timer > 0.0:
		up_attack_step = (up_attack_step + 1) % UP_ATTACK_ANIMATIONS.size()
		up_attack_timer = up_attack_reset_time
		print("[AirAttackUp] Up attack combo step: ", up_attack_step)

func _on_animation_finished(anim_name: String):
	if anim_name == current_attack:
		# Up attack bitti, fall state'e geç
		state_machine.transition_to("Fall")

func _handle_movement(delta: float) -> void:
	# Get horizontal movement only
	var input_dir_x = Input.get_axis("ui_left", "ui_right")
	
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
			# Up attack için özel pozisyon (yukarı ve merkez)
			var base_position = Vector2(-10, -60)  # Base pozisyon (sağa bakarken)
			var position = base_position
			
			# Oyuncunun bakış yönüne göre X pozisyonunu ayarla
			position.x = abs(position.x) * (-1 if player.sprite.flip_h else 1)
			collision_shape.position = position
			
			# Debug: Hitbox position updated
			# print("[AirAttackUp] Hitbox position updated: x=", position.x, ", y=", position.y, " facing: ", "left" if player.sprite.flip_h else "right", " collision_shape.position: ", collision_shape.position)

func _on_enemy_hit(enemy: Node):
	if not has_activated_hitbox:
		has_activated_hitbox = true
		print("[AirAttackUp] Hit enemy: ", enemy.name)
