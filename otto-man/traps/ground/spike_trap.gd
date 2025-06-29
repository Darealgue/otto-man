extends BaseTrap
class_name SpikeTrap

# Spike-specific configuration
@export var spike_height: float = 64.0  # How high spikes extend
@export var rise_duration: float = 0.2  # How fast spikes rise (back to original)
@export var stay_duration: float = 1.0  # How long spikes stay up (back to original)
@export var fall_duration: float = 0.3  # How fast spikes retract (back to original)
@export var warning_duration: float = 0.4  # Warning phase duration (shorter for faster gameplay)

# Sprite positioning (for fine-tuning)
@export_group("Sprite Positioning")
@export var sprite_offset: Vector2 = Vector2(0, 0)  # Fine-tune sprite position
@export var sprite_z_index: int = 1  # Z-index for layering (above tiles, below characters)

# Spike state
enum SpikeState {
	HIDDEN,
	RISING,
	ACTIVE,
	FALLING
}

var current_state: SpikeState = SpikeState.HIDDEN
var has_dealt_damage: bool = false  # Track if damage was already dealt this cycle
var rising_damage_timer: Timer  # Timer for delayed rising damage
var spike_sprite: Sprite2D
var status_indicator: ColorRect  # Visual indicator for testing

func _ready() -> void:
	super._ready()
	
	# Set trap category
	trap_category = TrapConfig.TrapCategory.GROUND
	damage_type = TrapConfig.DamageType.PHYSICAL
	
	# Override the damage area connection to use our own handler
	if damage_area:
		# Get all connected signals and disconnect the base class handler
		var connections = damage_area.body_entered.get_connections()
		for connection in connections:
			if connection.callable.get_object() == self:
				damage_area.body_entered.disconnect(connection.callable)
		
		# Connect our own handler
		damage_area.body_entered.connect(_on_damage_area_entered)
		
		# Keep damage area always enabled for spike trap
		damage_area.monitoring = true
		print("[SpikeTrap] Damage area set to always monitoring")
		
		# Create a timer to ensure damage area stays active
		var monitor_timer = Timer.new()
		monitor_timer.wait_time = 0.1  # Check every 0.1 seconds
		monitor_timer.timeout.connect(_ensure_damage_area_active)
		monitor_timer.autostart = true
		add_child(monitor_timer)
		print("[SpikeTrap] Monitor timer created to keep damage area active")
	
	# Create spike visual
	_create_spike_visual()
	
	# Create status indicator for testing
	_create_status_indicator()
	
	# Create rising damage timer
	rising_damage_timer = Timer.new()
	rising_damage_timer.wait_time = rise_duration / 2.0  # Half of rising duration
	rising_damage_timer.one_shot = true
	rising_damage_timer.timeout.connect(_on_rising_damage_ready)
	add_child(rising_damage_timer)
	print("[SpikeTrap] Rising damage timer created - delay: %.2fs" % rising_damage_timer.wait_time)
	
	print("[SpikeTrap] Ready - Sprite position: %s, Z-index: %d" % [sprite_offset, sprite_z_index])

func _create_spike_visual() -> void:
	# Remove the generic sprite node
	if sprite:
		sprite.queue_free()
	
	# Create spike sprite with real animation
	spike_sprite = Sprite2D.new()
	spike_sprite.name = "SpikeSprite"
	
	# Load the real spike animation sprite
	var spike_texture = load("res://objects/dungeon/traps/Spike_trap.png")
	if spike_texture:
		spike_sprite.texture = spike_texture
		# Configure sprite for animation frames
		spike_sprite.hframes = 18  # 18 frames horizontal
		spike_sprite.vframes = 1   # 1 row
		spike_sprite.frame = 0     # Start with idle frame (frame 0)
		print("[SpikeTrap] Loaded real sprite animation with 18 frames")
	else:
		print("[SpikeTrap] Could not load spike sprite, using placeholder")
		# Fallback to placeholder if sprite not found
		_create_placeholder_spike()
		return
	
	# Position sprite with fine-tuning offset
	spike_sprite.position = sprite_offset  # Use exported offset for fine-tuning
	
	# Set Z-index to appear above tiles
	spike_sprite.z_index = sprite_z_index  # Use exported z_index
	
	add_child(spike_sprite)
	
	# Update sprite reference
	sprite = spike_sprite
	
	# Add AnimationPlayer for smooth frame transitions
	_setup_spike_animations()

func _create_placeholder_spike() -> void:
	# Fallback placeholder (old system)
	var texture = ImageTexture.new()
	var image = Image.create(48, int(spike_height), false, Image.FORMAT_RGB8)
	image.fill(Color.RED)
	texture.create_from_image(image)
	spike_sprite.texture = texture
	spike_sprite.position = Vector2(0, spike_height / 2)
	spike_sprite.scale = Vector2(1.0, 0.0)

func _setup_spike_animations() -> void:
	# Create AnimationPlayer for smooth frame-based animations
	var anim_player = AnimationPlayer.new()
	anim_player.name = "SpikeAnimationPlayer"
	add_child(anim_player)
	
	# Create animation library
	var anim_library = AnimationLibrary.new()
	
	# Create individual animations
	_create_idle_animation(anim_library)
	_create_warning_animation(anim_library)
	_create_rising_animation(anim_library)
	_create_extended_animation(anim_library)
	_create_retracting_animation(anim_library)
	
	# Add library to player
	anim_player.add_animation_library("spike_anims", anim_library)
	
	# Start with idle
	anim_player.play("spike_anims/idle")

func _create_idle_animation(library: AnimationLibrary) -> void:
	var anim = Animation.new()
	anim.length = 1.0  # Loop duration
	
	# Frame track
	var frame_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(frame_track, NodePath("SpikeSprite:frame"))
	anim.track_insert_key(frame_track, 0.0, 0)  # Frame 0 (idle)
	
	library.add_animation("idle", anim)

func _create_warning_animation(library: AnimationLibrary) -> void:
	var anim = Animation.new()
	anim.length = warning_duration  # Use the exported warning duration
	
	var frame_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(frame_track, NodePath("SpikeSprite:frame"))
	
	# Frames 1-7 (warning sequence) - 0-based indexing
	for i in range(7):
		var time = (i / 6.0) * warning_duration  # Distribute over warning duration
		anim.track_insert_key(frame_track, time, i + 1)  # Frames 1-7
	
	library.add_animation("warning", anim)

func _create_rising_animation(library: AnimationLibrary) -> void:
	var anim = Animation.new()
	anim.length = rise_duration  # Use the exported rise duration
	
	var frame_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(frame_track, NodePath("SpikeSprite:frame"))
	
	# Frames 8-10 (rising sequence) - 0-based indexing
	for i in range(3):
		var time = (i / 2.0) * rise_duration  # Distribute over rise duration
		anim.track_insert_key(frame_track, time, i + 8)  # Frames 8-10
	
	library.add_animation("rising", anim)

func _create_extended_animation(library: AnimationLibrary) -> void:
	var anim = Animation.new()
	anim.length = stay_duration  # Use the exported stay duration
	
	var frame_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(frame_track, NodePath("SpikeSprite:frame"))
	anim.track_insert_key(frame_track, 0.0, 11)  # Frame 11 (extended) - 0-based indexing
	
	library.add_animation("extended", anim)

func _create_retracting_animation(library: AnimationLibrary) -> void:
	var anim = Animation.new()
	anim.length = fall_duration  # Use the exported fall duration
	
	var frame_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(frame_track, NodePath("SpikeSprite:frame"))
	
	# Frames 12-17 (retracting sequence) - 0-based indexing
	for i in range(6):
		var time = (i / 5.0) * fall_duration  # Distribute over fall duration
		anim.track_insert_key(frame_track, time, i + 12)  # Frames 12-17
	
	library.add_animation("retracting", anim)

func _create_status_indicator() -> void:
	# Create a status indicator to show trap state
	status_indicator = ColorRect.new()
	status_indicator.name = "StatusIndicator"
	status_indicator.size = Vector2(120, 30)
	status_indicator.position = Vector2(-60, -120)  # Above the trap
	status_indicator.color = Color.GRAY  # Default state
	add_child(status_indicator)
	
	# Add text label
	var label = Label.new()
	label.text = "HIDDEN"
	label.position = Vector2(5, 5)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 12)
	status_indicator.add_child(label)

func _update_status_indicator(state_text: String, color: Color) -> void:
	if status_indicator:
		status_indicator.color = color
		var label = status_indicator.get_child(0) as Label
		if label:
			label.text = state_text

func _execute_trap_behavior() -> void:
	if current_state != SpikeState.HIDDEN:
		print("[SpikeTrap] Cannot execute - current state: %s" % SpikeState.keys()[current_state])
		return
	
	print("[SpikeTrap] Executing spike behavior - starting activation")
	_activate_spikes()

func _activate_spikes() -> void:
	# Reset damage tracking for new cycle
	has_dealt_damage = false
	
	_update_status_indicator("WARNING", Color.ORANGE)
	print("[SpikeTrap] Spikes warning phase starting - damage tracking reset")
	
	# Get AnimationPlayer
	var anim_player = get_node("SpikeAnimationPlayer")
	if anim_player:
		# Play warning animation first
		anim_player.play("spike_anims/warning")
		await anim_player.animation_finished
		
		# Then rising animation
		current_state = SpikeState.RISING
		_update_status_indicator("RISING", Color.YELLOW)
		print("[SpikeTrap] Spikes rising - duration: %.1f seconds" % rise_duration)
		
		# Start the rising damage timer (damage after half of rising duration)
		rising_damage_timer.start()
		print("[SpikeTrap] Rising damage timer started - damage in %.2fs" % rising_damage_timer.wait_time)
		
		anim_player.play("spike_anims/rising")
		await anim_player.animation_finished
		
		_on_spikes_fully_risen()
	else:
		print("[SpikeTrap] No AnimationPlayer found, using fallback")
		# Fallback to old system
		var tween = create_tween()
		tween.tween_property(spike_sprite, "scale", Vector2(1.0, 1.0), rise_duration)
		tween.tween_callback(_on_spikes_fully_risen)

func _on_spikes_fully_risen() -> void:
	current_state = SpikeState.ACTIVE
	_update_status_indicator("ACTIVE - DANGER!", Color.RED)
	print("[SpikeTrap] ⚠️ SPIKES NOW ACTIVE AND DANGEROUS for %.1f seconds ⚠️" % stay_duration)
	print("[SpikeTrap] State changed to: %s" % SpikeState.keys()[current_state])
	
	# Check if any players are currently in damage area and damage them
	_check_players_in_damage_area()
	
	# Get AnimationPlayer and play extended animation
	var anim_player = get_node("SpikeAnimationPlayer")
	if anim_player:
		anim_player.play("spike_anims/extended")
		await anim_player.animation_finished
	else:
		# Fallback timing
		await get_tree().create_timer(stay_duration).timeout
	
	_retract_spikes()

func _retract_spikes() -> void:
	current_state = SpikeState.FALLING
	_update_status_indicator("RETRACTING", Color.YELLOW)
	print("[SpikeTrap] ✅ SPIKES RETRACTING - SAFE AGAIN - duration: %.1f seconds" % fall_duration)
	print("[SpikeTrap] State changed to: %s" % SpikeState.keys()[current_state])
	
	# Get AnimationPlayer and play retracting animation
	var anim_player = get_node("SpikeAnimationPlayer")
	if anim_player:
		anim_player.play("spike_anims/retracting")
		await anim_player.animation_finished
		_on_spikes_fully_retracted()
	else:
		print("[SpikeTrap] No AnimationPlayer found, using fallback")
		# Fallback animation
		var tween = create_tween()
		tween.tween_property(spike_sprite, "scale", Vector2(1.0, 0.0), fall_duration)
		tween.tween_callback(_on_spikes_fully_retracted)

func _on_spikes_fully_retracted() -> void:
	current_state = SpikeState.HIDDEN
	_update_status_indicator("HIDDEN", Color.GRAY)
	print("[SpikeTrap] Spikes retracted - waiting for cooldown")
	
	# Return to idle animation
	var anim_player = get_node("SpikeAnimationPlayer")
	if anim_player:
		anim_player.play("spike_anims/idle")

func _on_rising_damage_ready() -> void:
	print("[SpikeTrap] Rising damage timer finished - spikes now dangerous during RISING!")
	# This function is called when rising damage timer finishes
	# The actual damage check happens in _on_damage_area_entered

# Override damage dealing to only work when spikes are active
func deal_damage_to_player(player: Node) -> void:
	if current_state == SpikeState.ACTIVE:
		# Try different damage methods for compatibility
		var damage_dealt = false
		
		if player.has_method("take_damage"):
			player.take_damage(base_damage)
			damage_dealt = true
		elif player.has_method("damage"):
			player.damage(base_damage)
			damage_dealt = true
		elif player.has_method("hurt"):
			player.hurt(base_damage)
			damage_dealt = true
		
		if damage_dealt:
			player_damaged.emit(player, base_damage)
			print("[SpikeTrap] Dealt %.1f damage to player" % base_damage)
			_update_status_indicator("DAMAGE!", Color.WHITE)
		else:
			print("[SpikeTrap] Player has no compatible damage method")
	else:
		print("[SpikeTrap] Player hit spikes but they're not active")

func _on_damage_area_entered(body: Node2D) -> void:
	print("[SpikeTrap] Body entered damage area: %s" % body.name)
	print("[SpikeTrap] Body groups: %s" % body.get_groups())
	print("[SpikeTrap] Current spike state: %s" % SpikeState.keys()[current_state])
	print("[SpikeTrap] Is player in group: %s" % body.is_in_group("player"))
	
	if body.is_in_group("player"):
		print("[SpikeTrap] ✓ PLAYER CONFIRMED - State: %s" % SpikeState.keys()[current_state])
		
		# Only deal damage once per cycle and only when spikes are dangerous
		if not has_dealt_damage and (current_state == SpikeState.RISING or current_state == SpikeState.ACTIVE):
			# For RISING state, only deal damage if enough time has passed
			if current_state == SpikeState.RISING:
				if rising_damage_timer.is_stopped():  # Timer has finished
					print("[SpikeTrap] ✓ RISING SPIKES ARE DANGEROUS - DEALING DAMAGE!")
					_deal_damage_to_player(body)
					has_dealt_damage = true
				else:
					print("[SpikeTrap] ✗ Rising spikes not dangerous yet - waiting for timer")
			elif current_state == SpikeState.ACTIVE:
				print("[SpikeTrap] ✓ ACTIVE SPIKES ARE DANGEROUS - DEALING DAMAGE!")
				_deal_damage_to_player(body)
				has_dealt_damage = true
		elif has_dealt_damage:
			print("[SpikeTrap] ✗ Damage already dealt this cycle")
		else:
			print("[SpikeTrap] ✗ Spikes not dangerous yet - State: %s" % SpikeState.keys()[current_state])
	else:
		print("[SpikeTrap] ✗ Not a player body, ignoring")

func _ensure_damage_area_active() -> void:
	if damage_area and not damage_area.monitoring:
		damage_area.monitoring = true
		print("[SpikeTrap] ⚠️ Damage area was disabled, re-enabling it!")

func _check_players_in_damage_area() -> void:
	if not damage_area:
		print("[SpikeTrap] No damage area found!")
		return
		
	print("[SpikeTrap] Checking for players currently in damage area...")
	var bodies_in_area = damage_area.get_overlapping_bodies()
	print("[SpikeTrap] Found %d bodies in damage area" % bodies_in_area.size())
	
	for body in bodies_in_area:
		print("[SpikeTrap] Checking body: %s, groups: %s" % [body.name, body.get_groups()])
		if body.is_in_group("player"):
			print("[SpikeTrap] ✓ FOUND PLAYER IN DAMAGE AREA - DEALING DAMAGE!")
			_deal_damage_to_player(body)

func _deal_damage_to_player(player: Node2D) -> void:
	print("[SpikeTrap] Attempting to deal damage to player: %s" % player.name)
	print("[SpikeTrap] Player groups: %s" % player.get_groups())
	print("[SpikeTrap] Base damage: %s" % base_damage)
	
	if player.has_method("take_damage"):
		print("[SpikeTrap] Player has take_damage method - calling it with damage: %s" % base_damage)
		player.take_damage(base_damage)
		print("[SpikeTrap] take_damage called successfully")
		
		# Visual feedback
		_update_status_indicator("DAMAGE DEALT!", Color.MAGENTA)
		
		# Create damage number effect if available
		_show_damage_number(base_damage)
	else:
		print("[SpikeTrap] ERROR: Player doesn't have take_damage method!")
		print("[SpikeTrap] Available methods: %s" % player.get_method_list())
		
func _show_damage_number(damage: float) -> void:
	# Simple damage number display
	var damage_label = Label.new()
	damage_label.text = "-%d" % damage
	damage_label.position = Vector2(-20, -150)
	damage_label.add_theme_color_override("font_color", Color.RED)
	damage_label.add_theme_font_size_override("font_size", 16)
	add_child(damage_label)
	
	# Animate damage number
	var tween = create_tween()
	tween.parallel().tween_property(damage_label, "position", damage_label.position + Vector2(0, -50), 1.0)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(damage_label.queue_free)

# Debug functions for fine-tuning sprite position
func adjust_sprite_position(new_offset: Vector2) -> void:
	sprite_offset = new_offset
	if spike_sprite:
		spike_sprite.position = sprite_offset
		print("[SpikeTrap] Sprite position adjusted to: %s" % sprite_offset)

func adjust_sprite_z_index(new_z_index: int) -> void:
	sprite_z_index = new_z_index
	if spike_sprite:
		spike_sprite.z_index = sprite_z_index
		print("[SpikeTrap] Sprite z_index adjusted to: %d" % sprite_z_index)

func get_trap_info() -> String:
	return "Spike Trap - Deals %d damage when spikes are extended" % int(base_damage)
 
