extends State

const PARRY_WINDOW := 0.2  # Wider parry window (seconds)
const BLOCK_DAMAGE_REDUCTION := 0.5  # 50% damage reduction when blocking
const STAMINA_RECHARGE_TIME := 5.0  # Time to recharge one stamina segment
const PARRY_DAMAGE_MULTIPLIER := 1.5  # 50% more damage reflected on successful parry

var is_blocking := false
var parry_timer := 0.0
var can_parry := false
var stamina_recharge_timer := 0.0
var current_stamina := 3  # Start with 3 stamina segments
var is_in_impact_animation := false
var stamina_bar = null
var is_transitioning := false
var finish_timer: Timer = null
var stamina_consumed_this_hit := false  # Track if stamina was consumed for current hit
var block_start_time: float = 0.0  # Track when block started
var is_parrying := false  # Add this at the top with other vars

func _ready():
	pass

func enter():
	
	# Enter combat state when blocking
	player.enter_combat_state()
	
	# Get stamina bar reference
	stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar:
		stamina_bar.show_bar()  # Show the stamina bar when entering block state
	
	# Only allow blocking if on ground and has stamina
	if not player.is_on_floor() or (stamina_bar and not stamina_bar.has_charges()):
		state_machine.transition_to("Idle")
		return
		
	is_blocking = false
	can_parry = true
	parry_timer = PARRY_WINDOW
	is_in_impact_animation = false
	is_transitioning = false
	stamina_consumed_this_hit = false
	block_start_time = Time.get_ticks_msec() / 1000.0  # Set block start time
	
	# Create finish timer if not exists
	if not finish_timer:
		finish_timer = Timer.new()
		finish_timer.one_shot = true
		
		finish_timer.timeout.connect(_on_finish_timer_timeout)
		add_child(finish_timer)
	
	# Normal giriş - prepare animasyonu oynat
	animation_player.play("block_prepare")
	
	# Connect to animation finished signal
	if not animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	
	# Connect to hurtbox signal if not already connected
	if not player.hurtbox.is_connected("hurt", _on_hurtbox_hurt):
		player.hurtbox.connect("hurt", _on_hurtbox_hurt)
	

func exit():
	is_blocking = false
	can_parry = false
	is_in_impact_animation = false
	is_transitioning = false
	stamina_consumed_this_hit = false
	
	# Stop any pending timers
	if finish_timer:
		finish_timer.stop()
	
	# Hide stamina bar if not recharging
	if stamina_bar and not stamina_bar.is_recharging():
		stamina_bar.hide_bar()
	
	# Disconnect signals
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_finished)
	if player.hurtbox.is_connected("hurt", _on_hurtbox_hurt):
		player.hurtbox.disconnect("hurt", _on_hurtbox_hurt)
	
	# Block state'den çıkarken was_on_floor'u true yap - landing tespit edilmesini engelle
	if player.is_on_floor():
		player.was_on_floor = true

func physics_update(delta: float):
	# Don't process input during transitions
	if is_transitioning:
		return
	
	# During parry, allow immediate cancel into counter attack
	if is_parrying:
		if Input.is_action_just_pressed("attack_heavy") and state_machine.has_node("HeavyAttack"):
			print("[Block] Counter cancel -> HeavyAttack")
			# End parry immediately and transition
			is_parrying = false
			state_machine.transition_to("HeavyAttack")
			return
		elif Input.is_action_just_pressed("attack") and state_machine.has_node("Attack"):
			print("[Block] Counter cancel -> Attack")
			is_parrying = false
			state_machine.transition_to("Attack")
			return
		
	# If player taps block again, re-arm parry window
	if Input.is_action_just_pressed("block"):
		can_parry = true
		parry_timer = PARRY_WINDOW
		block_start_time = Time.get_ticks_msec() / 1000.0
		print("[Block] Parry window re-armed")
		
	# Update parry window timer
	if parry_timer > 0:
		parry_timer -= delta
		if parry_timer <= 0:
			can_parry = false
			print("[Block] Parry window closed")
			if not is_blocking and not is_in_impact_animation and not is_parrying:
				is_blocking = true
				animation_player.play("block")
	
	# Check if still blocking and has stamina
	# Allow tap-parry: during active parry window, ignore block release
	var can_end_block := parry_timer <= 0.0 and not is_parrying
	if can_end_block and (not Input.is_action_pressed("block") or (stamina_bar and not stamina_bar.has_charges() and not is_in_impact_animation)):
		print("[Block] Exiting block (release or no stamina), parry window over")
		_start_finish_animation()
		return
	
	# Ensure player stays in place while blocking
	player.velocity.x = 0
	player.velocity.y = 0
	player.move_and_slide()

func _start_finish_animation():
	if is_transitioning:  # Don't start finish animation if already transitioning
		return
	is_transitioning = true
	
	# Block state'den çıkarken was_on_floor'u hemen true yap - landing tespit edilmesini engelle
	if player.is_on_floor():
		player.was_on_floor = true
	
	animation_player.play("block_finish")
	# Start safety timer
	finish_timer.start(0.25)  # Slightly longer than animation length

func _on_finish_timer_timeout():
	if is_transitioning:
		state_machine.transition_to("Idle")

func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	# Prevent double parry
	if is_parrying:
		return
	
	# Check if within parry window and can parry
	if can_parry:
		print("[Block] PARRY SUCCESS")
		
		# Consume stamina for parry if not already consumed for this hit
		if not stamina_consumed_this_hit and stamina_bar:
			if stamina_bar.use_charge():
				stamina_consumed_this_hit = true
			else:
				# If no stamina, treat as normal block
				player.hurtbox.last_damage = hitbox.get_damage() * (1.0 - BLOCK_DAMAGE_REDUCTION)
				is_in_impact_animation = true
				animation_player.play("block_impact")
				return
		
		player.hurtbox.last_damage = 0  # No damage on successful parry
		
		# Set parrying flag
		is_parrying = true
		
		# Play parry animation
		animation_player.play("parry")
		
		# Create parry effect
		var parry_effect = preload("res://effects/parry_effect.tscn").instantiate()
		player.add_child(parry_effect)
		parry_effect.global_position = hitbox.global_position
		
		# Instead of reflecting damage, open counter-attack window
		if player and player.has_method("start_counter_window"):
			player.start_counter_window(0.8)  # Slightly longer counter chance
		# Emit perfect parry signal for powerups
		player._on_successful_parry()  # Call the function that emits the signal
		# Close parry window immediately after success
		can_parry = false
		parry_timer = 0.0
	else:
		# Consume stamina for normal blocks if not already consumed for this hit
		if not stamina_consumed_this_hit and stamina_bar:
			if stamina_bar.use_charge():
				stamina_consumed_this_hit = true
			else:
				# If no stamina, take full damage
				player.hurtbox.last_damage = hitbox.get_damage()
				_start_finish_animation()
				return
		
		# Apply reduced damage if we had stamina
		if stamina_consumed_this_hit:
			var reduced_damage = hitbox.get_damage() * (1.0 - BLOCK_DAMAGE_REDUCTION)
			player.hurtbox.last_damage = reduced_damage
		else:
			var full_damage = hitbox.get_damage()
			player.hurtbox.last_damage = full_damage  # Full damage if no stamina
		
		is_in_impact_animation = true
		animation_player.play("block_impact")

func _on_animation_finished(anim_name: String):
	match anim_name:
		"parry":
			is_parrying = false  # Reset parrying flag
			is_transitioning = false  # Reset transitioning flag
			if Input.is_action_pressed("block") and stamina_bar and stamina_bar.has_charges():
				animation_player.play("block")
			else:
				_start_finish_animation()
		"block_prepare":
			is_transitioning = false  # Reset transitioning flag
			if not Input.is_action_pressed("block"):
				_start_finish_animation()
			else:
				is_blocking = true
				animation_player.play("block")
		"block_impact":
			is_in_impact_animation = false
			is_transitioning = false  # Reset transitioning flag
			stamina_consumed_this_hit = false  # Reset stamina consumption flag after impact
			if Input.is_action_pressed("block") and stamina_bar and stamina_bar.has_charges():
				animation_player.play("block")
			else:
				_start_finish_animation()
		"block_finish":
			is_transitioning = false  # Reset transitioning flag
			state_machine.transition_to("Idle")
