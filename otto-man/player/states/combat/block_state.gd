extends State

const PARRY_WINDOW := 0.1  # 0.1 seconds window for parry
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
	debug_enabled = true  # Enable debug logging for block state

func enter():
	
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
	
	# Play prepare animation
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

func physics_update(delta: float):
	# Don't process input during transitions or parrying
	if is_transitioning or is_parrying:
		return
		
	# Update parry window timer
	if parry_timer > 0:
		parry_timer -= delta
		if parry_timer <= 0:
			can_parry = false
			if not is_blocking and not is_in_impact_animation and not is_parrying:
				is_blocking = true
				animation_player.play("block")
	
	# Check if still blocking and has stamina
	if not Input.is_action_pressed("block") or (stamina_bar and not stamina_bar.has_charges() and not is_in_impact_animation):
		_start_finish_animation()
		return
	
	# Ensure player stays in place while blocking
	player.velocity.x = 0
	player.velocity.y = 0
	player.move_and_slide()

func _start_finish_animation():
	is_transitioning = true
	animation_player.play("block_finish")
	# Start safety timer
	finish_timer.start(0.25)  # Slightly longer than animation length

func _on_finish_timer_timeout():
	if is_transitioning:
		state_machine.transition_to("Idle")

func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	# Get timing window
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_block = current_time - block_start_time
	
	
	# Prevent double parry
	if is_parrying:
		return
	
	# Check if within parry window
	if time_since_block <= PARRY_WINDOW:
		player.hurtbox.last_damage = 0  # No damage on successful parry
		
		# Set parrying flag
		is_parrying = true
		
		# Play parry animation

		animation_player.play("parry")
		
		# Create parry effect
		var parry_effect = preload("res://effects/parry_effect.tscn").instantiate()
		player.add_child(parry_effect)
		parry_effect.global_position = hitbox.global_position
		
		# Reflect damage back to attacker
		var attacker = hitbox.get_parent()
		if attacker.has_method("take_damage"):
			var reflected_damage = hitbox.get_damage() * 1.5  # 50% more damage
			attacker.take_damage(reflected_damage)
	else:
		player.hurtbox.last_damage = hitbox.get_damage() * (1.0 - BLOCK_DAMAGE_REDUCTION)
		player.animation_player.play("block_impact")

func _on_animation_finished(anim_name: String):
	
	match anim_name:
		"parry":
			is_parrying = false  # Reset parrying flag
			if Input.is_action_pressed("block") and not is_transitioning and stamina_bar and stamina_bar.has_charges():
				animation_player.play("block")
		"block_prepare":
			if not is_transitioning:
				is_blocking = true
				animation_player.play("block")
		"block_impact":
			is_in_impact_animation = false
			stamina_consumed_this_hit = false  # Reset stamina consumption flag after impact
			if Input.is_action_pressed("block") and not is_transitioning and stamina_bar and stamina_bar.has_charges():
					animation_player.play("block")
			else:
				_start_finish_animation()
		"block_finish":
			state_machine.transition_to("Idle")
