extends State

var is_double_jumping := false
var double_jump_animation_finished := false
var is_transitioning := false
var wall_transition_timer := 0.0
const WALL_TRANSITION_DELAY := 0.15
const MIN_WALL_CONTACT_TIME := 0.05
const WALL_DETACH_GRACE := 0.2  # Grace period after detaching from wall
const DODGE_AIR_CARRY_TIME := 0.5  # Dodge bittikten sonra uçuş animasyonunun havada sürdürüleceği süre
# Dodge havada biterken yayın kırılmaması için: yatay hız tek karede kesilmek yerine
# sabit ivmeyle yavaşlar, yer çekimi de dodge'un çarpanından normale yumuşak geçer.
const DODGE_EXIT_GRAVITY_MULT := 0.6  # dodge_state'teki uçuş yer çekimi çarpanıyla aynı
const DODGE_AIR_DECEL := 1550.0       # Uçuş penceresinde yatay yavaşlama (px/s^2)
const DODGE_AIR_MIN_SPEED := 95.0    # Bu hızın altına inmez; pencere bitince normal kurallar devralır
const POST_DODGE_CROUCH_DURATION := 0.15  # Havadan inen dodge sonrası toparlanma çömelmesi

# Dodge havada bittiğinde uçuş animasyonu burada devam eder, yere değince takla oynar.
# Tamamen görsel: fizik, girdi ve state geçişleri bu bayraklardan etkilenmez.
var dodge_carry_timer := 0.0
var dodge_rolling := false

var wall_contact_timer := 0.0
var wall_detach_grace_timer := 0.0
var last_wall_normal := Vector2.ZERO
var wall_slide_state = null  # Store reference to wall slide state

func enter():
	wall_transition_timer = WALL_TRANSITION_DELAY
	wall_contact_timer = 0.0
	
	# If coming from wall slide, start grace period
	if state_machine.previous_state and state_machine.previous_state.name == "WallSlide":
		wall_detach_grace_timer = WALL_DETACH_GRACE
		last_wall_normal = player.wall_normal  # Store the wall normal we detached from
		
		# WALLSLIDE FIX: Wallslide'den geldiğinde zıplama haklarını düzelt
		# Oyuncu hem normal zıplama hem de double jump hakkını kullanabilsin
		player.enable_double_jump()  # Her zaman double jump'ı etkinleştir
		player.has_double_jumped = false  # Double jump hakkını sıfırla
	else:
		wall_detach_grace_timer = 0.0
		last_wall_normal = Vector2.ZERO
	
	# IMPROVED WALLSLIDE DETECTION: Wallslide'den geldiğini daha güvenilir şekilde tespit et
	# Eğer wall_normal varsa ve is_wall_sliding false ise, wallslide'den geliyor demektir
	if player.wall_normal != Vector2.ZERO and not player.is_wall_sliding:
		wall_detach_grace_timer = WALL_DETACH_GRACE
		last_wall_normal = player.wall_normal
		
		# Zıplama haklarını düzelt - her zaman sıfırla
		player.enable_double_jump()  # Her zaman double jump'ı etkinleştir
		player.has_double_jumped = false  # Double jump hakkını sıfırla
	
	# Get reference to wall slide state
	wall_slide_state = get_parent().get_node("WallSlide")
	
	# Reset hitbox position ve rotasyon (air up/down sonrası)
	var reset_hitbox = player.get_node_or_null("Hitbox")
	if reset_hitbox and reset_hitbox is PlayerHitbox:
		reset_hitbox.position = Vector2.ZERO
		reset_hitbox.rotation = 0.0
		var collision_shape = reset_hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.position = Vector2(52.625, -22.5)
	
	# Dodge havada bitti mi? Öyleyse uçuş loop'unu burada devral.
	dodge_carry_timer = 0.0
	dodge_rolling = false
	if player.dodge_air_carry:
		player.dodge_air_carry = false
		if animation_player.has_animation("dodge_air") and not player.is_on_floor():
			dodge_carry_timer = DODGE_AIR_CARRY_TIME

	# Only play fall animation if we're not in a special animation
	var current_anim = animation_player.current_animation

	# If we're in the middle of a transition animation, let it finish
	if dodge_carry_timer > 0.0:
		animation_player.play("dodge_air")
	elif current_anim == "jump_to_fall":
		is_transitioning = true
	elif current_anim == "double_jump" or current_anim == "double_jump_alt":
		is_double_jumping = true
	elif current_anim == "ledge_grab" or current_anim == "ledge_mount":
		# Coming from ledge grab, check if we're on floor
		if player.is_on_floor():
			state_machine.transition_to("Idle")
			return
		else:
			animation_player.play("fall")
	elif current_anim != "fall" and current_anim != "jump_upwards" and current_anim != "double_jump" and current_anim != "double_jump_alt":
		animation_player.play("fall")
	
	# Enable double jump if we walked off a platform and have coyote time
	if not player.is_jumping and not player.has_double_jumped and player.has_coyote_time():
		player.enable_double_jump()
	
	# Connect to animation finished signal
	if not animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.connect("animation_finished", _on_animation_finished)

func physics_update(delta: float):
	# Dodge uçuş devri: süre dolunca normal düşüş animasyonuna dön
	if dodge_carry_timer > 0.0:
		dodge_carry_timer -= delta
		if dodge_carry_timer <= 0.0 and animation_player.current_animation == "dodge_air":
			animation_player.play("fall")

	# Wall slide cooldown'ı artık player.gd _physics_process içinde merkezi olarak işliyor.

	# Update grace period timer
	if wall_detach_grace_timer > 0:
		wall_detach_grace_timer -= delta
	
	# PRIORITY 1: Check for wall slide FIRST - highest priority for consistent wall sliding
	if player.is_on_wall():
		# Track wall contact time
		wall_contact_timer += delta
		# print("[WALL_SLIDE_DEBUG] Fall State: Wall detected, contact_time: ", wall_contact_timer, " min_time: ", MIN_WALL_CONTACT_TIME)
		
		# Only transition if:
		# 1. We've been in contact with the wall for minimum time
		# 2. The wall slide state is available and can be entered (not on cooldown)
		if wall_contact_timer >= MIN_WALL_CONTACT_TIME and wall_slide_state and wall_slide_state.can_enter():
			# print("[WALL_SLIDE_DEBUG] Fall State: Wall slide can enter, transitioning to WallSlide")
			wall_slide_state.reset_cooldown()  # Reset cooldown before entering
			state_machine.transition_to("WallSlide")
			return
		else:
			pass
	else:
		wall_contact_timer = 0.0
	
	# PRIORITY 1.5: Check for dodge/dash input (dash if item allows, otherwise air dodge)
	if Input.is_action_just_pressed("dash"):
		# Check if dash item is active (Rüzgar Hançeri)
		var dash_state = state_machine.get_node_or_null("Dash")
		if dash_state and dash_state.has_method("can_start_dash") and dash_state.can_start_dash():
			state_machine.transition_to("Dash")
			return
		
		# Otherwise check for air dodge
		var dodge_state = state_machine.get_node("Dodge")
		if dodge_state and dodge_state.can_start_dodge():
			state_machine.transition_to("Dodge")
			return
	
	# PRIORITY 2: Check for attack input - high priority for responsive controls
	if Input.is_action_just_pressed("attack") and player.attack_cooldown_timer <= 0:
		# Check for up/down input to determine attack type
		var up_strength = Input.get_action_strength("up")
		var down_strength = Input.get_action_strength("down")
		if up_strength > 0.6:
			# Up attack - transition to AirAttackUp state
			state_machine.transition_to("AirAttackUp")
			return
		elif down_strength > 0.6:
			# Down attack - transition to AirAttackDown state
			state_machine.transition_to("AirAttackDown")
			return
		else:
			# Normal air attack
			state_machine.transition_to("Attack")
			return
	
	# PRIORITY 3: Check for fall attack input (special air attack)
	if Input.is_action_pressed("down") and player.can_use_fall_attack():
		# Make fall attack easier to execute by checking for jump input more frequently
		if Input.is_action_just_pressed("jump") and not player.jump_input_blocked and player.jump_block_timer <= 0:
			var fall_attack_state = get_parent().get_node("FallAttack")
			if fall_attack_state and not fall_attack_state.is_on_cooldown():
				# Force immediate transition to fall attack
				is_double_jumping = false
				is_transitioning = false
				double_jump_animation_finished = true
				animation_player.stop()  # Stop any current animation
				
				# Almost eliminate horizontal momentum for more vertical fall attack
				player.velocity.x *= 0.1  # Reduced from 0.5 to 0.1
				
				state_machine.transition_to("FallAttack")
				return
	
	# Handle jump during fall (if we have coyote time or can double jump)
	if Input.is_action_just_pressed("jump") and not player.jump_input_blocked and player.jump_block_timer <= 0:
		# WALLSLIDE FIX: Wallslide'den geldiğinde özel zıplama kontrolü
		var coming_from_wallslide = (state_machine.previous_state and state_machine.previous_state.name == "WallSlide")
		# IMPROVED: Daha güvenilir wallslide detection
		var has_wall_normal = (player.wall_normal != Vector2.ZERO and not player.is_wall_sliding)
		var improved_wallslide_detection = coming_from_wallslide or has_wall_normal
		
		if player.has_coyote_time() and not player.has_double_jumped:
			player.start_jump()
			state_machine.transition_to("Jump")
			return
		elif player.can_double_jump and not player.has_double_jumped:
			player.has_double_jumped = true
			is_double_jumping = true
			# Use player's double jump function instead of setting velocity directly
			player.start_double_jump()
			animation_player.play("double_jump")
			return
		elif improved_wallslide_detection and not player.has_double_jumped:
			# Wallslide'den geldiğinde double jump'ı zorla etkinleştir
			player.enable_double_jump()
			player.has_double_jumped = true
			is_double_jumping = true
			player.start_double_jump()
			animation_player.play("double_jump")
			return
		elif player.has_double_jumped and player.get_meta("cift_ziplama_available", false) and has_node("/root/ItemManager") and ItemManager.has_active_item("cift_ziplama"):
			# Çift Zıplama: 3. zıplama - patlama altında + can gider
			player.set_meta("cift_ziplama_available", false)
			var tree = get_tree()
			if tree and tree.current_scene:
				var explosion_pos = player.global_position + Vector2(0, 28)
				var expl = Node2D.new()
				expl.set_script(load("res://effects/third_jump_explosion.gd") as GDScript)
				tree.current_scene.add_child(expl)
				expl.global_position = explosion_pos
			var stats = get_tree().root.get_node_or_null("PlayerStats")
			if stats and not ExplosionModifiers.player_immune_to_explosions():
				var cost = max(1.0, stats.get_max_health() * 0.08)
				stats.set_current_health(stats.get_current_health() - cost, false)
			player.start_double_jump()
			is_double_jumping = true
			animation_player.play("double_jump")
			return
	elif Input.is_action_just_pressed("jump") and (player.jump_input_blocked or player.jump_block_timer > 0):
		pass  # Jump input blocked
	elif Input.is_action_just_pressed("jump"):
		pass  # Jump input detected but conditions not met
	
	# Get input for horizontal movement
	var input_dir = InputManager.get_flattened_axis(&"left", &"right")
	
	# Handle horizontal movement using new air movement system
	if dodge_carry_timer > 0.0 and input_dir == 0:
		# Dodge uçuşu sürerken apply_movement'in ani momentum kesmesi (velocity.x *= 0.85,
		# saniyede ~%99.99) devreye girmesin: süzülme pozu oynarken yatay hareketin bir
		# anda durması "görünmez duvara çarpma" hissi veriyordu. Bunun yerine sabit ivmeyle
		# yavaşlasın. Yön tuşuna basılırsa hava kontrolü normal işler.
		if absf(player.velocity.x) > DODGE_AIR_MIN_SPEED:
			var floor_speed: float = DODGE_AIR_MIN_SPEED * signf(player.velocity.x)
			player.velocity.x = move_toward(player.velocity.x, floor_speed, DODGE_AIR_DECEL * delta)
	elif dodge_rolling:
		# Takla kendi itişini sürüyor (_drive_dodge_roll); apply_movement yön tuşuna göre
		# hızı normal koşu hızına çekmeye çalışıp itişle çekişmesin.
		pass
	else:
		player.apply_movement(delta, input_dir)
	
	# Only flip sprite if:
	# 1. We're not in wall detach grace period, OR
	# 2. We're pressing in the opposite direction of our last wall
	# 3. Takla oynarken yön tuşu sprite'ı çevirmesin - karakter ileri yuvarlanırken
	#    geriye bakmış olurdu.
	if input_dir != 0 and not dodge_rolling:
		if wall_detach_grace_timer <= 0:
			# Normal sprite control
			player.sprite.flip_h = input_dir < 0
		elif (last_wall_normal.x < 0 and input_dir > 0):
			# Only flip if explicitly moving away from the wall we detached from
			player.sprite.flip_h = false  # Face right when moving right
		elif (last_wall_normal.x > 0 and input_dir < 0):
			# Only flip if explicitly moving away from the wall we detached from
			player.sprite.flip_h = true  # Face left when moving left
	
	# Vuruş anında kısa sabitlenme (Street Fighter) - gravity uygulama
	if player.get("air_hit_freeze_timer") != null and player.air_hit_freeze_timer > 0.0:
		player.velocity.y = 0.0
	else:
		# Apply gravity with Hollow Knight style, except during double jump
		if is_double_jumping:
			# Use normal gravity during double jump
			player.velocity.y += player.gravity * delta
		else:
			var gravity_multiplier = player.calculate_hollow_knight_gravity()
			# Air-combo float (only after successful hit).
			if player.get("air_combo_float_timer") != null and player.air_combo_float_timer > 0.0:
				gravity_multiplier *= player.air_combo_gravity_scale
			# Havada Kal: jump basılıyken düşerken süzülme (düşük yer çekimi)
			if player.velocity.y > 0 and Input.is_action_pressed("jump") and has_node("/root/ItemManager") and ItemManager.has_active_item("havada_kal"):
				gravity_multiplier *= 0.28
			# Dodge uçuşundan çıkarken yer çekimini yumuşak devral. Doğrudan Hollow Knight
			# eğrisine geçmek yayı bozuyordu: çarpan önce dodge'un 0.6'sından apex'in 0.3'üne
			# DÜŞÜP (bir anlık ters bükülme) sonra ~0.17s içinde 3.5'e fırlıyordu.
			if dodge_carry_timer > 0.0:
				var carry_t: float = clampf(1.0 - (dodge_carry_timer / DODGE_AIR_CARRY_TIME), 0.0, 1.0)
				gravity_multiplier = lerpf(DODGE_EXIT_GRAVITY_MULT, float(gravity_multiplier), carry_t)
			player.velocity.y += player.gravity * gravity_multiplier * delta
		
		# Apply maximum fall speed
		var max_fall = player.max_fall_speed
		if player.get("air_combo_float_timer") != null and player.air_combo_float_timer > 0.0:
			max_fall = min(max_fall, player.air_combo_max_fall_speed)
		if player.velocity.y > max_fall:
			player.velocity.y = max_fall
	
	player.apply_move_and_slide()
	
	# Check for ledge grab (LedgeGrab.can_ledge_grab filters velocity + block + geometry)
	var ledge_state = get_parent().get_node("LedgeGrab")
	if ledge_state and ledge_state.can_ledge_grab():
		# print("[FallState] LedgeGrab condition MET! Transitioning.") # DEBUG
		state_machine.transition_to("LedgeGrab")
		return
	# else:
		# DEBUG: Print why it failed if ledge_state exists
		# if ledge_state:
			# print("[FallState] LedgeGrab condition FAILED.")
		# else:
			# print("[FallState] LedgeGrab state node not found.")
	
	# Wall slide check moved to top priority above
	
	# Finally check for landing
	if player.is_on_floor():
		if dodge_carry_timer > 0.0 and animation_player.has_animation("dodge_roll"):
			# Dodge uçuşundan iniş: normal landing yerine takla oynat
			dodge_carry_timer = 0.0
			dodge_rolling = true
			animation_player.play("dodge_roll")
			_drive_dodge_roll()
		elif dodge_rolling:
			# Yön tuşu taklayı KESMEZ. Kestiğinde ileri basılı tutan oyuncu (yani normal
			# durum) taklayı hiç göremiyor, doğrudan koşuya geçip saçma duruyordu.
			# Takla zaten kendi hızıyla ilerlediği için "yürürken yuvarlanma" sorunu da yok.
			# Saldırı ve zıplama yukarıdaki bloklarda hâlâ kesiyor.
			_drive_dodge_roll()
		elif animation_player.current_animation != "landing":
			# Only play landing animation if we're not already playing it
			animation_player.play("landing")
		return

# Havadan inen dodge'un taklası sonuna kadar oynadıysa kısa bir toparlanma çömelmesi
# yaptırır: slide çıkışındaki hissin aynısı, "yere düşüp doğruluyor" izlenimi verir ve
# dodge'u boşluğa savurmanın küçük bir zaman bedeli olur.
# Takla saldırı/zıplama/yön tuşuyla kesilirse buraya hiç gelinmez - ceza da olmaz.
# Düz zemindeki dodge bu yoldan geçmez; onun taklası Dodge state'inin içinde bitiyor.
func _finish_dodge_landing() -> void:
	var crouch = state_machine.get_node_or_null("Crouch")
	if crouch == null or not crouch.has_method("force_crouch") or not player.is_on_floor():
		state_machine.transition_to("Idle")
		return
	state_machine.transition_to("Crouch")
	crouch.force_crouch(POST_DODGE_CROUCH_DURATION)


# Dodge inişindeki taklaya, Dodge state'inin kullandığı hızın aynısını uygular.
# Hız tek yerde tanımlı (dodge_state.gd), burada kopyalanmıyor.
func _drive_dodge_roll() -> void:
	# Tip verilmiyor: sabite ancak dinamik erisimle ulasilabiliyor (Node tipinde statik analiz reddediyor)
	var dodge = state_machine.get_node_or_null("Dodge")
	if dodge == null:
		return
	player.velocity.x = float(dodge.DODGE_ROLL_SPEED) * player.dodge_air_carry_dir


func _on_animation_finished(anim_name: String):
	match anim_name:
		"double_jump":
			double_jump_animation_finished = true
			is_double_jumping = false
			animation_player.play("fall")
		"jump_to_fall":
			is_transitioning = false
			animation_player.play("fall")
		"landing":
			# Always transition to idle when landing animation finishes
			state_machine.transition_to("Idle")
		"dodge_roll":
			# Dodge inişi taklası bitti - kısa toparlanma çömelmesine geç
			dodge_rolling = false
			_finish_dodge_landing()
		"fall":
			# If we're on the floor and fall animation finishes, play landing
			if player.is_on_floor():
				animation_player.play("landing")

func exit():
	# print("[WALL_SLIDE_DEBUG] Fall State: EXITING fall state")
	is_double_jumping = false
	double_jump_animation_finished = false
	is_transitioning = false
	wall_contact_timer = 0.0
	wall_detach_grace_timer = 0.0
	last_wall_normal = Vector2.ZERO
	dodge_carry_timer = 0.0
	dodge_rolling = false
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.disconnect("animation_finished", _on_animation_finished)
