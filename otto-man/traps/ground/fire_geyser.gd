extends BaseTrap
class_name FireGeyser

# Fire Geyser States
enum GeyserState {
	IDLE,
	WARNING,
	RISING,
	ACTIVE,
	COOLING
}

var current_state: GeyserState = GeyserState.IDLE
var has_dealt_initial_damage: bool = false  # Track if initial damage was dealt
var dot_timer: Timer  # Timer for DOT damage
var rising_damage_timer: Timer  # Timer for delayed rising damage

# Fire Geyser configuration
@export var geyser_height: float = 80.0  # How high flames extend
@export var warning_duration: float = 0.6  # Warning phase duration (10 frames) - faster warning
@export var rising_duration: float = 0.25  # Rising phase duration (3 frames) - faster rising
@export var active_duration: float = 2.0  # Active phase duration (4 frame loop)
@export var cooling_duration: float = 0.3  # Cooling phase duration (4 frames) - faster cooling
@export var dot_interval: float = 0.5  # DOT damage every 0.5 seconds
@export var dot_damage_percent: float = 60.0  # DOT damage as % of base damage
@export var initial_damage_percent: float = 100.0  # Initial damage as % of base damage

# Sprite positioning and area configuration
@export_group("Sprite Positioning")
@export var sprite_offset: Vector2 = Vector2(0, -40)  # Fine-tune sprite position
@export var sprite_z_index: int = 1  # Z-index for layering (above tiles, below characters)

# Area sizes are now configured directly in the scene editor

var geyser_sprite: Sprite2D
var status_indicator: ColorRect  # Visual indicator for testing

func _ready() -> void:
	super._ready()
	
	# Set trap category
	trap_category = TrapConfig.TrapCategory.GROUND
	damage_type = TrapConfig.DamageType.FIRE
	
	# Setup trigger area for activation
	var trigger_area = get_node_or_null("TriggerArea")
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_area_entered)
		print("[FireGeyser] Trigger area connected")
	else:
		print("[FireGeyser] Warning: No TriggerArea found!")
	
	# Override the damage area connection to use our own handler
	if damage_area:
		# Get all connected signals and disconnect the base class handler
		var connections = damage_area.body_entered.get_connections()
		for connection in connections:
			if connection.callable.get_object() == self:
				damage_area.body_entered.disconnect(connection.callable)
		
		# Connect our own handler
		damage_area.body_entered.connect(_on_damage_area_entered)
		
		# Keep damage area always enabled for fire geyser
		damage_area.monitoring = true
		print("[FireGeyser] Damage area set to always monitoring")
		
		# Create a timer to ensure damage area stays active
		var monitor_timer = Timer.new()
		monitor_timer.wait_time = 0.1  # Check every 0.1 seconds
		monitor_timer.timeout.connect(_ensure_damage_area_active)
		monitor_timer.autostart = true
		add_child(monitor_timer)
		print("[FireGeyser] Monitor timer created to keep damage area active")
	
	# Create fire geyser visual
	_create_geyser_visual()
	
	# Create status indicator for testing
	_create_status_indicator()
	
	# Create DOT damage timer
	dot_timer = Timer.new()
	dot_timer.wait_time = dot_interval
	dot_timer.timeout.connect(_deal_dot_damage)
	add_child(dot_timer)
	print("[FireGeyser] DOT timer created - interval: %.2fs" % dot_interval)
	
	# Create rising damage timer
	rising_damage_timer = Timer.new()
	rising_damage_timer.wait_time = rising_duration / 2.0  # Half of rising duration (now 0.125s)
	rising_damage_timer.one_shot = true
	rising_damage_timer.timeout.connect(_on_rising_damage_ready)
	add_child(rising_damage_timer)
	print("[FireGeyser] Rising damage timer created - delay: %.3fs" % rising_damage_timer.wait_time)
	
	print("[FireGeyser] Ready - Sprite position: %s, Z-index: %d" % [sprite_offset, sprite_z_index])

func _create_geyser_visual() -> void:
	geyser_sprite = Sprite2D.new()
	geyser_sprite.name = "GeyserSprite"  # Give it a proper name for NodePath
	geyser_sprite.texture = load("res://objects/dungeon/traps/Fire_geyser_trap.png")
	geyser_sprite.position = sprite_offset
	geyser_sprite.z_index = sprite_z_index
	
	# Set up sprite sheet (22 frames total, assuming horizontal layout)
	geyser_sprite.hframes = 22
	geyser_sprite.vframes = 1
	geyser_sprite.frame = 0  # Start with idle frame
	
	add_child(geyser_sprite)
	
	# Create animation library and player
	_create_geyser_animations()
	
	print("[FireGeyser] Loaded sprite with 22 frames")

func _create_geyser_animations() -> void:
	var anim_player = AnimationPlayer.new()
	anim_player.name = "GeyserAnimationPlayer"
	add_child(anim_player)
	
	var anim_library = AnimationLibrary.new()
	
	# Create all animations
	_create_idle_animation(anim_library)
	_create_warning_animation(anim_library)
	_create_rising_animation(anim_library)
	_create_active_animation(anim_library)
	_create_cooling_animation(anim_library)
	
	anim_player.add_animation_library("geyser_anims", anim_library)
	
	# Start with idle animation
	anim_player.play("geyser_anims/idle")

func _create_idle_animation(library: AnimationLibrary) -> void:
	var anim = Animation.new()
	anim.length = 1.0  # Static frame
	
	var frame_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(frame_track, NodePath("GeyserSprite:frame"))
	anim.track_insert_key(frame_track, 0.0, 0)  # Frame 0 (idle)
	
	library.add_animation("idle", anim)

func _create_warning_animation(library: AnimationLibrary) -> void:
	var anim = Animation.new()
	anim.length = warning_duration
	
	var frame_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(frame_track, NodePath("GeyserSprite:frame"))
	
	# Frames 1-10 (warning sequence) - 0-based indexing
	var frame_duration = warning_duration / 10.0  # Equal time per frame
	for i in range(10):
		var time = i * frame_duration
		anim.track_insert_key(frame_track, time, i + 1)  # Frames 1-10
	
	library.add_animation("warning", anim)

func _create_rising_animation(library: AnimationLibrary) -> void:
	var anim = Animation.new()
	anim.length = rising_duration
	
	var frame_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(frame_track, NodePath("GeyserSprite:frame"))
	
	# Frames 11-13 (rising sequence) - 0-based indexing
	var frame_duration = rising_duration / 3.0  # Equal time per frame
	for i in range(3):
		var time = i * frame_duration
		anim.track_insert_key(frame_track, time, i + 11)  # Frames 11-13
	
	library.add_animation("rising", anim)

func _create_active_animation(library: AnimationLibrary) -> void:
	var anim = Animation.new()
	anim.length = 0.4  # 2x faster loop duration (0.8 -> 0.4)
	anim.loop_mode = Animation.LOOP_LINEAR
	
	var frame_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(frame_track, NodePath("GeyserSprite:frame"))
	
	# Frames 14-17 (active loop sequence) - 0-based indexing
	# 2x faster animation with smoother frame timing
	var frame_duration = anim.length / 4.0  # Equal time per frame (0.1s each)
	for i in range(4):
		var time = i * frame_duration
		anim.track_insert_key(frame_track, time, i + 14)  # Frames 14-17
	
	# Add the first frame again at the end for smooth loop transition
	anim.track_insert_key(frame_track, anim.length, 14)  # Back to first frame
	
	print("[FireGeyser] Active animation created - Duration: %.2fs, Frame duration: %.3fs" % [anim.length, frame_duration])
	
	library.add_animation("active", anim)

func _create_cooling_animation(library: AnimationLibrary) -> void:
	var anim = Animation.new()
	anim.length = cooling_duration
	
	var frame_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(frame_track, NodePath("GeyserSprite:frame"))
	
	# Frames 18-21 (cooling sequence) - 0-based indexing
	var frame_duration = cooling_duration / 4.0  # Equal time per frame
	for i in range(4):
		var time = i * frame_duration
		anim.track_insert_key(frame_track, time, i + 18)  # Frames 18-21
	
	library.add_animation("cooling", anim)

func _create_status_indicator() -> void:
	status_indicator = ColorRect.new()
	status_indicator.size = Vector2(60, 20)
	status_indicator.position = Vector2(-30, -120)
	status_indicator.color = Color.GRAY
	add_child(status_indicator)
	
	var label = Label.new()
	label.text = "IDLE"
	label.position = Vector2(5, 2)
	label.add_theme_font_size_override("font_size", 12)
	status_indicator.add_child(label)

func _update_status_indicator(text: String, color: Color) -> void:
	if status_indicator:
		status_indicator.color = color
		var label = status_indicator.get_child(0) as Label
		if label:
			label.text = text

# Override execute trap behavior
func _execute_trap_behavior() -> void:
	if current_state != GeyserState.IDLE:
		print("[FireGeyser] Cannot execute - current state: %s" % GeyserState.keys()[current_state])
		return
	
	print("[FireGeyser] Executing geyser behavior - starting activation")
	_activate_geyser()

func _activate_geyser() -> void:
	# Reset damage tracking for new cycle
	has_dealt_initial_damage = false
	
	_update_status_indicator("WARNING", Color.ORANGE)
	print("[FireGeyser] Geyser warning phase starting - damage tracking reset")
	
	# Get AnimationPlayer
	var anim_player = get_node("GeyserAnimationPlayer")
	if anim_player:
		# Play warning animation first
		current_state = GeyserState.WARNING
		anim_player.play("geyser_anims/warning")
		await anim_player.animation_finished
		
		# Then rising animation
		current_state = GeyserState.RISING
		_update_status_indicator("RISING", Color.YELLOW)
		print("[FireGeyser] Flames rising - duration: %.1f seconds" % rising_duration)
		
		# Start the rising damage timer (damage after half of rising duration)
		rising_damage_timer.start()
		print("[FireGeyser] Rising damage timer started - damage in %.2fs" % rising_damage_timer.wait_time)
		
		anim_player.play("geyser_anims/rising")
		await anim_player.animation_finished
		
		_on_geyser_fully_erupted()
	else:
		print("[FireGeyser] No AnimationPlayer found, using fallback")

func _on_geyser_fully_erupted() -> void:
	current_state = GeyserState.ACTIVE
	_update_status_indicator("ACTIVE - FIRE!", Color.RED)
	print("[FireGeyser] 🔥 GEYSER NOW ACTIVE AND DANGEROUS for %.1f seconds 🔥" % active_duration)
	print("[FireGeyser] State changed to: %s" % GeyserState.keys()[current_state])
	
	# Start DOT damage timer
	dot_timer.start()
	print("[FireGeyser] DOT damage started - every %.1fs" % dot_interval)
	
	# Check if any players are currently in damage area and damage them
	_check_players_in_damage_area()
	
	# Get AnimationPlayer and play active animation (looped)
	var anim_player = get_node("GeyserAnimationPlayer")
	if anim_player:
		anim_player.play("geyser_anims/active")
		await get_tree().create_timer(active_duration).timeout
	else:
		# Fallback timing
		await get_tree().create_timer(active_duration).timeout
	
	_cool_down_geyser()

func _cool_down_geyser() -> void:
	current_state = GeyserState.COOLING
	_update_status_indicator("COOLING", Color.BLUE)
	print("[FireGeyser] ❄️ GEYSER COOLING DOWN - SAFE AGAIN - duration: %.1f seconds" % cooling_duration)
	print("[FireGeyser] State changed to: %s" % GeyserState.keys()[current_state])
	
	# Stop DOT damage
	dot_timer.stop()
	print("[FireGeyser] DOT damage stopped")
	
	# Get AnimationPlayer and play cooling animation
	var anim_player = get_node("GeyserAnimationPlayer")
	if anim_player:
		anim_player.play("geyser_anims/cooling")
		await anim_player.animation_finished
		_on_geyser_fully_cooled()
	else:
		print("[FireGeyser] No AnimationPlayer found, using fallback")
		await get_tree().create_timer(cooling_duration).timeout
		_on_geyser_fully_cooled()

func _on_geyser_fully_cooled() -> void:
	current_state = GeyserState.IDLE
	_update_status_indicator("IDLE", Color.GRAY)
	print("[FireGeyser] Geyser cooled down - waiting for cooldown")
	
	# Return to idle animation
	var anim_player = get_node("GeyserAnimationPlayer")
	if anim_player:
		anim_player.play("geyser_anims/idle")

func _on_rising_damage_ready() -> void:
	print("[FireGeyser] Rising damage timer finished - flames now dangerous during RISING!")

func _on_trigger_area_entered(body: Node2D) -> void:
	print("[FireGeyser] Trigger area entered by: %s" % body.name)
	print("[FireGeyser] Body groups: %s" % body.get_groups())
	
	if body.is_in_group("player") and current_state == GeyserState.IDLE:
		print("[FireGeyser] ✓ PLAYER TRIGGERED GEYSER!")
		_execute_trap_behavior()
	else:
		if not body.is_in_group("player"):
			print("[FireGeyser] ✗ Not a player, ignoring trigger")
		else:
			print("[FireGeyser] ✗ Geyser not idle (current state: %s)" % GeyserState.keys()[current_state])

func _on_damage_area_entered(body: Node2D) -> void:
	print("[FireGeyser] Body entered damage area: %s" % body.name)
	print("[FireGeyser] Body groups: %s" % body.get_groups())
	print("[FireGeyser] Current geyser state: %s" % GeyserState.keys()[current_state])
	print("[FireGeyser] Is player in group: %s" % body.is_in_group("player"))
	
	if body.is_in_group("player"):
		print("[FireGeyser] ✓ PLAYER CONFIRMED - State: %s" % GeyserState.keys()[current_state])
		
		# Only deal initial damage once per cycle and only when geyser is dangerous
		if not has_dealt_initial_damage and (current_state == GeyserState.RISING or current_state == GeyserState.ACTIVE):
			# For RISING state, only deal damage if enough time has passed
			if current_state == GeyserState.RISING:
				if rising_damage_timer.is_stopped():  # Timer has finished
					print("[FireGeyser] ✓ RISING FLAMES ARE DANGEROUS - DEALING INITIAL DAMAGE!")
					_deal_initial_damage_to_player(body)
					has_dealt_initial_damage = true
				else:
					print("[FireGeyser] ✗ Rising flames not dangerous yet - waiting for timer")
			elif current_state == GeyserState.ACTIVE:
				print("[FireGeyser] ✓ ACTIVE FLAMES ARE DANGEROUS - DEALING INITIAL DAMAGE!")
				_deal_initial_damage_to_player(body)
				has_dealt_initial_damage = true
		elif has_dealt_initial_damage:
			print("[FireGeyser] ✗ Initial damage already dealt this cycle")
		else:
			print("[FireGeyser] ✗ Flames not dangerous yet - State: %s" % GeyserState.keys()[current_state])
	else:
		print("[FireGeyser] ✗ Not a player body, ignoring")

func _deal_dot_damage() -> void:
	if current_state != GeyserState.ACTIVE:
		return
	
	print("[FireGeyser] DOT damage tick!")
	_check_players_in_damage_area_for_dot()

func _check_players_in_damage_area() -> void:
	if not damage_area:
		print("[FireGeyser] No damage area found!")
		return
		
	print("[FireGeyser] Checking for players currently in damage area...")
	var bodies_in_area = damage_area.get_overlapping_bodies()
	print("[FireGeyser] Found %d bodies in damage area" % bodies_in_area.size())
	
	for body in bodies_in_area:
		print("[FireGeyser] Checking body: %s, groups: %s" % [body.name, body.get_groups()])
		if body.is_in_group("player"):
			print("[FireGeyser] ✓ FOUND PLAYER IN DAMAGE AREA - DEALING INITIAL DAMAGE!")
			_deal_initial_damage_to_player(body)

func _check_players_in_damage_area_for_dot() -> void:
	if not damage_area:
		return
		
	var bodies_in_area = damage_area.get_overlapping_bodies()
	
	for body in bodies_in_area:
		if body.is_in_group("player"):
			print("[FireGeyser] ✓ FOUND PLAYER IN DAMAGE AREA - DEALING DOT DAMAGE!")
			_deal_dot_damage_to_player(body)

func _deal_initial_damage_to_player(player: Node2D) -> void:
	var initial_damage = base_damage * (initial_damage_percent / 100.0)
	print("[FireGeyser] Dealing initial damage: %.1f" % initial_damage)
	
	if player.has_method("take_damage"):
		player.take_damage(initial_damage)
		print("[FireGeyser] Initial damage dealt successfully")
		
		# Visual feedback
		_update_status_indicator("INITIAL DMG!", Color.MAGENTA)
		_show_damage_number(initial_damage)
	else:
		print("[FireGeyser] ERROR: Player doesn't have take_damage method!")

func _deal_dot_damage_to_player(player: Node2D) -> void:
	var dot_damage = base_damage * (dot_damage_percent / 100.0)
	print("[FireGeyser] Dealing DOT damage: %.1f" % dot_damage)
	
	if player.has_method("take_damage"):
		player.take_damage(dot_damage)
		print("[FireGeyser] DOT damage dealt successfully")
		
		# Visual feedback
		_update_status_indicator("DOT DMG!", Color.RED)
		_show_damage_number(dot_damage)
	else:
		print("[FireGeyser] ERROR: Player doesn't have take_damage method!")

func _show_damage_number(damage: float) -> void:
	# Simple damage number display
	var damage_label = Label.new()
	damage_label.text = "-%d" % damage
	damage_label.position = Vector2(-20, -150)
	damage_label.add_theme_color_override("font_color", Color.ORANGE)
	damage_label.add_theme_font_size_override("font_size", 16)
	add_child(damage_label)
	
	# Animate damage number
	var tween = create_tween()
	tween.parallel().tween_property(damage_label, "position", damage_label.position + Vector2(0, -50), 1.0)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(damage_label.queue_free)

func _ensure_damage_area_active() -> void:
	if damage_area and not damage_area.monitoring:
		damage_area.monitoring = true
		print("[FireGeyser] ⚠️ Damage area was disabled, re-enabling it!")

# Debug functions for fine-tuning
func adjust_sprite_position(new_offset: Vector2) -> void:
	sprite_offset = new_offset
	if geyser_sprite:
		geyser_sprite.position = sprite_offset
		print("[FireGeyser] Sprite position adjusted to: %s" % sprite_offset)

func adjust_sprite_z_index(new_z_index: int) -> void:
	sprite_z_index = new_z_index
	if geyser_sprite:
		geyser_sprite.z_index = sprite_z_index
		print("[FireGeyser] Sprite z_index adjusted to: %d" % sprite_z_index)

func adjust_damage_area_size(new_size: Vector2) -> void:
	if damage_area:
		var damage_collision = damage_area.get_node_or_null("CollisionShape2D")
		if damage_collision and damage_collision.shape is RectangleShape2D:
			damage_collision.shape.size = new_size
			print("[FireGeyser] Damage area size adjusted to: %s" % new_size)

func adjust_trigger_area_size(new_size: Vector2) -> void:
	var trigger_area = get_node_or_null("TriggerArea")
	if trigger_area:
		var trigger_collision = trigger_area.get_node_or_null("CollisionShape2D")
		if trigger_collision:
			if trigger_collision.shape is RectangleShape2D:
				trigger_collision.shape.size = new_size
			elif trigger_collision.shape is CircleShape2D:
				trigger_collision.shape.radius = new_size.x / 2.0  # Use width as diameter
			print("[FireGeyser] Trigger area size adjusted to: %s" % new_size)

func get_trap_info() -> String:
	return "Fire Geyser - Deals initial + DOT fire damage"

# Debug info function
func print_debug_info() -> void:
	print("=== FireGeyser Debug Info ===")
	print("Sprite offset: %s" % sprite_offset)
	print("Sprite z_index: %d" % sprite_z_index)
	
	# Get current area sizes from scene
	if damage_area:
		var damage_collision = damage_area.get_node_or_null("CollisionShape2D")
		if damage_collision and damage_collision.shape is RectangleShape2D:
			print("Damage area size: %s" % damage_collision.shape.size)
	
	var trigger_area = get_node_or_null("TriggerArea")
	if trigger_area:
		var trigger_collision = trigger_area.get_node_or_null("CollisionShape2D")
		if trigger_collision:
			if trigger_collision.shape is RectangleShape2D:
				print("Trigger area size: %s" % trigger_collision.shape.size)
			elif trigger_collision.shape is CircleShape2D:
				print("Trigger area radius: %s" % trigger_collision.shape.radius)
	
	print("Current state: %s" % GeyserState.keys()[current_state])
	print("==============================")
 
 
