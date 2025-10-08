extends "res://player/states/state.gd"

const DODGE_SPEED := 800.0  # Daha yavaş hareket (Dash: 2500)
const DODGE_DURATION := 0.45  # Animasyon süresine eşit (0.45s)
const DODGE_COOLDOWN := 0.0   # Cooldown kaldırıldı (stamina ile sınırlı)
const DODGE_END_SPEED_MULTIPLIER := 0.4  # Dodge sonrası hız korunma
var dodge_timer := 0.0
var cooldown_timer := 0.0
var can_dodge := true
var dodge_charges := 1  # Number of available dodge charges
var max_dodge_charges := 1  # Maximum dodge charges
var original_collision_mask := 0  # Store original collision mask
var original_collision_layer := 0  # Store original collision layer

func _ready() -> void:
	await owner.ready  # Wait for owner to be ready
	if player:
		if !is_connected("state_entered", player._on_dodge_state_entered):
			connect("state_entered", player._on_dodge_state_entered)
		if !is_connected("state_exited", player._on_dodge_state_exited):
			connect("state_exited", player._on_dodge_state_exited)

func enter():
	# Call parent enter to emit signal
	super.enter()
	
	# Zıplama input'unu engelle
	player.jump_input_blocked = true
	
	# Charges sistemi kaldırıldı - sadece stamina kontrolü
	
	# Store original collision settings
	original_collision_mask = player.collision_mask
	original_collision_layer = player.collision_layer
	
	# Disable enemy collision (layer 3) - dodge sırasında düşmanlardan geçebilir
	player.collision_mask &= ~(1 << 2)  # Remove enemy collision mask (layer 3)
	player.collision_layer &= ~(1 << 2)  # Remove enemy collision layer (layer 3)
	
	# İnvincibility için hurtbox'ı devre dışı bırak
	var hurtbox = player.get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.monitoring = false
		print("[Dodge] Hurtbox disabled for invincibility")
	
	# Stamina tüket
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar:
		if stamina_bar.use_charge():
			print("[Dodge] Stamina consumed for dodge")
		else:
			print("[Dodge] ERROR: No stamina available!")
			# Stamina yoksa dodge yapamaz, idle'a dön
			state_machine.transition_to("Idle")
			return
	
	# Start dodge
	dodge_timer = DODGE_DURATION
	can_dodge = true  # Cooldown kaldırıldı, sadece stamina kontrolü
	# Play dodge animation
	var anim_player = player.get_node("AnimationPlayer")
	if anim_player:
		# Connect animation finished signal if not already connected
		if not anim_player.is_connected("animation_finished", _on_animation_finished):
			anim_player.connect("animation_finished", _on_animation_finished)
		
		# Check if dodge animation exists
		if anim_player.has_animation("dodge"):
			anim_player.play("dodge")
			print("[Dodge] Playing dodge animation - SUCCESS")
		else:
			print("[Dodge] ERROR: 'dodge' animation not found in AnimationPlayer!")
			print("[Dodge] Available animations: ", anim_player.get_animation_list())
	else:
		print("[Dodge] ERROR: AnimationPlayer not found!")
	
	# Set initial dodge velocity based on facing direction
	var dodge_direction = -1 if player.sprite.flip_h else 1
	player.velocity.x = DODGE_SPEED * dodge_direction
	# Yer çekimi çalışmaya devam etsin (dash'ten farklı olarak)
	# player.velocity.y = 0  # Bu satırı kaldırdık

func physics_update(delta: float):
	dodge_timer -= delta
	
	# Zıplama kontrolü: İlk yarıda zıplama engellensin, son yarıda serbest olsun
	var dodge_progress = 1.0 - (dodge_timer / DODGE_DURATION)  # 0.0 = başlangıç, 1.0 = bitiş
	var can_jump_during_dodge = dodge_progress >= 0.5  # Son yarıda zıplama serbest
	
	# Zıplama input kontrolü - EN YÜKSEK ÖNCELİK
	if Input.is_action_just_pressed("jump"):
		print("[Dodge] Jump input detected - progress: ", dodge_progress, " can_jump: ", can_jump_during_dodge, " on_floor: ", player.is_on_floor())
		if can_jump_during_dodge and player.is_on_floor():
			# Son yarıda zıplama yapılabilir - flag'i kaldır
			player.jump_input_blocked = false
			player.jump_block_timer = 0.0  # Timer'ı da sıfırla
			print("[Dodge] Jump allowed in second half - progress: ", dodge_progress)
			# Dodge'u iptal etmeden zıplama yap - dodge devam etsin
			player.start_jump()
			# Dodge state'den çıkma, sadece zıplama yap
			return
		else:
			# İlk yarıda zıplama engellensin
			print("[Dodge] Jump blocked - progress: ", dodge_progress, " can_jump: ", can_jump_during_dodge)
			# Input'u "tüket" - diğer state'lerin görmesini engelle
			# Bu input'u hiçbir şekilde işleme
			# Input'u tamamen engellemek için return yap
			return
	
	# Yer çekimi uygula (dodge sırasında da çalışsın)
	# İlk 0.1 saniye yer çekimi yok (hafif yukarı zıplama efekti)
	if not player.is_on_floor() and dodge_timer < (DODGE_DURATION - 0.1):
		player.velocity.y += player.gravity * delta
	
	if dodge_timer <= 0:
		# Reduce speed when ending dodge to prevent excessive drift
		player.velocity.x *= DODGE_END_SPEED_MULTIPLIER
		# Restore collision settings and end dodge
		player.collision_mask = original_collision_mask
		player.collision_layer = original_collision_layer
		
		# Transition to appropriate state based on player state
		if player.is_on_floor():
			print("[Dodge] Transitioning to Idle state")
			state_machine.transition_to("Idle")
		else:
			print("[Dodge] Transitioning to Fall state")
			state_machine.transition_to("Fall")
		return
	
	player.move_and_slide()

func exit():
	# Call parent exit to emit signal
	super.exit()
	
	# Zıplama input'unu timer ile serbest bırak
	# Input buffering sorununu çözmek için 0.05 saniye daha engelle
	player.jump_block_timer = 0.05
	print("[Dodge] Jump input will be unblocked after 0.05s timer")
	
	# Ensure collision settings are restored when exiting state
	player.collision_mask = original_collision_mask
	player.collision_layer = original_collision_layer
	
	# Hurtbox'ı geri aç
	var hurtbox = player.get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.monitoring = true
		print("[Dodge] Hurtbox re-enabled")

func cooldown_update(delta: float):
	# Cooldown kaldırıldı - sadece stamina kontrolü
	pass

func can_start_dodge() -> bool:
	# Allow dodge when on ground and we have stamina (charges sistemi kaldırıldı)
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	var has_stamina = stamina_bar and stamina_bar.has_charges()
	return can_dodge and player.is_on_floor() and has_stamina

func set_dodge_charges(charges: int) -> void:
	max_dodge_charges = charges
	dodge_charges = charges
	can_dodge = dodge_charges > 0
	print("[Dodge State] Set dodge charges: " + str(charges))

func _on_animation_finished(anim_name: String):
	if anim_name == "dodge":
		print("[Dodge] Animation finished, transitioning to appropriate state")
		# Animation finished, but physics_update will handle the actual transition
		# when dodge_timer reaches 0
