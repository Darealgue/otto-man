extends CanvasLayer

@onready var powerup_container = $Control/CenterContainer/VBoxContainer/PowerupContainer
@onready var background = $Control/ColorRect

const PowerupButton = preload("res://ui/powerup_button.tscn")

var current_selection := 0
var powerup_buttons: Array[Button] = []
var is_processing_selection := false
var input_buffer_timer := 0.0
var is_transitioning := false
var current_deadzone_state := false  # Track current deadzone state to prevent redundant updates

const INPUT_BUFFER_TIME := 0.1
const FADE_DURATION := 0.15
const TIME_SLOW_DURATION := 0.15
const MIN_TIME_SCALE := 0.1
const SLIDE_DURATION := 0.2
const SLIDE_DISTANCE := 600
const INPUT_COOLDOWN := 0.1
const SELECTION_DELAY := 0.0
const HOLD_DURATION := 0.5  # Increased time for more noticeable fill effect
var hold_timer := 0.0
var is_holding := false
var selected_button: Button = null

# Store original deadzone values
var original_jump_deadzone := 0.5
var original_powerup_select_deadzone := 0.5

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	show_ui(false)
	
	# Store original deadzone values
	for event in InputMap.action_get_events("jump"):
		if event is InputEventJoypadMotion:
			original_jump_deadzone = event.deadzone
			break
	
	for event in InputMap.action_get_events("powerup_select"):
		if event is InputEventJoypadMotion:
			original_powerup_select_deadzone = event.deadzone
			break

func _process(delta: float) -> void:
	if input_buffer_timer > 0:
		input_buffer_timer -= delta
		
	# Block all input processing during transitions
	if is_transitioning:
		set_input_deadzones(true)
		return
		
	if input_buffer_timer > 0:
		set_input_deadzones(true)
	else:
		set_input_deadzones(false)
	
	# Handle input for selection
	if !is_processing_selection and !is_transitioning:
		# Move selection up/down
		if Input.is_action_just_pressed("up") or Input.is_action_just_pressed("powerup_up"):
			navigate_selection(-1)
		elif Input.is_action_just_pressed("down") or Input.is_action_just_pressed("powerup_down"):
			navigate_selection(1)
		
		# Start hold timer when jump/attack is pressed
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack"):
			start_hold_timer()
		# Update hold timer while button is held
		elif Input.is_action_pressed("jump") or Input.is_action_pressed("attack"):
			update_hold_timer(delta)
		# Reset if button is released
		elif is_holding:
			reset_hold_timer()
	
func start_hold_timer() -> void:
	is_holding = true
	hold_timer = 0.0
	if is_instance_valid(selected_button):
		selected_button.set_progress(0.0)

func update_hold_timer(delta: float) -> void:
	if !is_holding or !is_instance_valid(selected_button):
		return
		
	hold_timer += delta / Engine.time_scale
	var progress = clamp(hold_timer / HOLD_DURATION, 0.0, 1.0)
	selected_button.set_progress(progress)
	
	if hold_timer >= HOLD_DURATION:
		confirm_selection()
		reset_hold_timer()

func reset_hold_timer() -> void:
	is_holding = false
	hold_timer = 0.0
	if is_instance_valid(selected_button):
		selected_button.set_progress(0.0)

func navigate_selection(direction: int) -> void:
	if powerup_buttons.is_empty():
		return
		
	# Reset hold timer when changing selection
	reset_hold_timer()
	
	# Update selection
	current_selection = (current_selection + direction) % powerup_buttons.size()
	if current_selection < 0:
		current_selection = powerup_buttons.size() - 1
	
	# Highlight new button but don't select it
	powerup_buttons[current_selection].grab_focus()
	selected_button = powerup_buttons[current_selection]

func set_input_deadzones(high_deadzone: bool) -> void:
	# Only update if the state actually changes
	if current_deadzone_state == high_deadzone:
		return
		
	current_deadzone_state = high_deadzone
	var deadzone = 1.1 if high_deadzone else original_jump_deadzone
	print("[Deadzone] Setting deadzone to: ", deadzone)
	
	# Clear and re-add events with new deadzone
	for action in ["jump", "powerup_select"]:
		var events = InputMap.action_get_events(action)
		InputMap.action_erase_events(action)
		for event in events:
			if event is InputEventJoypadMotion:
				event.deadzone = deadzone
			InputMap.action_add_event(action, event)
			
	# Force release inputs when setting high deadzone
	if high_deadzone:
		Input.action_release("jump")
		Input.action_release("powerup_select")
		Input.action_release("powerup_up")
		Input.action_release("powerup_down")

func setup_powerups(powerup_scenes: Array[PackedScene]) -> void:
	print("[Setup] Starting powerup setup")
	for child in powerup_container.get_children():
		child.queue_free()
	powerup_buttons.clear()
	
	# Set states before starting any animations
	is_processing_selection = false  # Allow selection immediately
	is_transitioning = false  # Don't block inputs
	current_selection = 1  # Start with middle button (changed from 0)
	
	print("[Setup] Creating ", powerup_scenes.size(), " powerup buttons")
	for scene in powerup_scenes:
		var button = PowerupButton.instantiate()
		powerup_container.add_child(button)
		button.setup(scene)
		button.pressed.connect(func(): _on_powerup_selected(scene))
		powerup_buttons.append(button)
		# Start buttons off-screen and invisible
		button.position.x = -SLIDE_DISTANCE
		button.modulate.a = 0.0
		button.scale = Vector2(0.8, 0.8)
		button.mouse_filter = Control.MOUSE_FILTER_STOP  # Enable interaction immediately
		print("[Setup] Button created at x=", button.position.x)
	
	if !powerup_buttons.is_empty():
		powerup_buttons[current_selection].grab_focus()  # Just focus, don't select
		selected_button = powerup_buttons[current_selection]
	
	# Combine time slow and button slide-in animations
	print("[Animation] Starting combined animations")
	show_ui(true)
	background.modulate.a = 0.0
	
	var combined_tween = create_tween()
	combined_tween.set_parallel(true)
	
	Engine.time_scale = 1.0
	combined_tween.tween_property(Engine, "time_scale", MIN_TIME_SCALE, TIME_SLOW_DURATION * 0.5)  # Faster time slow
	combined_tween.tween_property(background, "modulate:a", 1.0, TIME_SLOW_DURATION * 0.5)  # Faster fade in
	
	for button in powerup_buttons:
		combined_tween.tween_property(button, "position:x", 0, SLIDE_DURATION * 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		combined_tween.tween_property(button, "scale", Vector2(1, 1), SLIDE_DURATION * 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		combined_tween.tween_property(button, "modulate:a", 1.0, SLIDE_DURATION * 0.75)
	
	await combined_tween.finished
	print("[Animation] Combined animations complete")
	get_tree().paused = true
	
	# Enable button interaction only after animations complete
	for button in powerup_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Reset states after all animations complete
	is_transitioning = false
	is_processing_selection = false
	set_input_deadzones(false)
	print("[State] Setup complete - Ready for selection")

func _on_powerup_selected(powerup_scene: PackedScene) -> void:
	if is_processing_selection:
		return
		
	is_processing_selection = true
	print("[Selection] Processing powerup selection")
	
	# Start fade out animation
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(background, "modulate:a", 0.0, FADE_DURATION)
	fade_tween.tween_property(Engine, "time_scale", 1.0, FADE_DURATION)
	
	for button in powerup_buttons:
		fade_tween.tween_property(button, "modulate:a", 0.0, FADE_DURATION)
	
	await fade_tween.finished
	
	# Activate the powerup
	PowerupManager.activate_powerup(powerup_scene)
	
	# Clean up
	get_tree().paused = false
	show_ui(false)
	queue_free()  # Remove the selection UI

func confirm_selection() -> void:
	if current_selection >= 0 and current_selection < powerup_buttons.size():
		var button = powerup_buttons[current_selection]
		_on_powerup_selected(button.powerup_scene)

func show_ui(show: bool) -> void:
	visible = show
	if !show:
		get_tree().paused = false
