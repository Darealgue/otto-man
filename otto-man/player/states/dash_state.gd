extends "res://player/states/state.gd"

const DASH_SPEED := 2500.0
const DASH_DURATION := 0.1
const DASH_COOLDOWN := 0.0  # Cooldown kaldırıldı (stamina ile sınırlı)
const DASH_END_SPEED_MULTIPLIER := 0.3  # Player will retain 30% of dash speed when ending
var dash_timer := 0.0
var cooldown_timer := 0.0
var can_dash := true
var dash_charges := 1  # Number of available dash charges
var max_dash_charges := 1  # Maximum dash charges
var original_collision_mask := 0  # Store original collision mask
var original_collision_layer := 0  # Store original collision layer

func _ready() -> void:
	await owner.ready  # Wait for owner to be ready
	if player:
		if !is_connected("state_entered", player._on_dash_state_entered):
			connect("state_entered", player._on_dash_state_entered)
		if !is_connected("state_exited", player._on_dash_state_exited):
			connect("state_exited", player._on_dash_state_exited)

func enter():
	
	# Call parent enter to emit signal
	super.enter()
	
	# Charges sistemi kaldırıldı - sadece stamina kontrolü
	
	# Store original collision settings
	original_collision_mask = player.collision_mask
	original_collision_layer = player.collision_layer
	
	# Disable enemy collision (layer 3)
	player.collision_mask &= ~(1 << 2)  # Remove enemy collision mask (layer 3)
	player.collision_layer &= ~(1 << 2)  # Remove enemy collision layer (layer 3)
	
	# Stamina tüket
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar:
		if stamina_bar.use_charge():
			print("[Dash] Stamina consumed for dash")
		else:
			print("[Dash] ERROR: No stamina available!")
			# Stamina yoksa dash yapamaz, idle'a dön
			state_machine.transition_to("Idle")
			return
	
	# Start dash
	dash_timer = DASH_DURATION
	can_dash = true  # Cooldown kaldırıldı, sadece stamina kontrolü
	animation_player.play("dash")
	
	# Set initial dash velocity based on facing direction
	var dash_direction = -1 if player.sprite.flip_h else 1
	player.velocity.x = DASH_SPEED * dash_direction
	player.velocity.y = 0

func physics_update(delta: float):
	dash_timer -= delta
	
	if dash_timer <= 0:
		# Reduce speed when ending dash to prevent excessive drift
		player.velocity.x *= DASH_END_SPEED_MULTIPLIER
		# Restore collision settings and end dash
		player.collision_mask = original_collision_mask
		player.collision_layer = original_collision_layer
		state_machine.transition_to("Fall")
		return
	
	player.move_and_slide()

func exit():
	# Call parent exit to emit signal
	super.exit()
	
	# Ensure collision settings are restored when exiting state
	player.collision_mask = original_collision_mask
	player.collision_layer = original_collision_layer

func cooldown_update(delta: float):
	# Cooldown kaldırıldı - sadece stamina kontrolü
	pass

func can_start_dash() -> bool:
	# Allow dash when on ground and we have stamina (charges sistemi kaldırıldı)
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	var has_stamina = stamina_bar and stamina_bar.has_charges()
	return can_dash and player.is_on_floor() and has_stamina

func set_dash_charges(charges: int) -> void:
	max_dash_charges = charges
	dash_charges = charges
	can_dash = dash_charges > 0
	print("[Dash State] Set dash charges: " + str(charges)) 
