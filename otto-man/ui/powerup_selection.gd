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
const HOLD_DURATION := 0.25  # Increased from 0.15 to 0.25 seconds for slower fill
var hold_timer := 0.0
var is_holding := false
var selected_button: Button = null

# Store original deadzone values
var original_jump_deadzone := 0.5
var original_powerup_select_deadzone := 0.5

# Add variables for input handling
var last_input_time := 0.0
var last_input_direction := 0

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
	
	# Handle hold-to-select using unscaled delta time
	if is_holding and !is_processing_selection:
		hold_timer += delta / Engine.time_scale  # Use unscaled time
		if is_instance_valid(selected_button):  # Check if button is still valid
			# Update radial progress indicator
			var progress = clamp(hold_timer / HOLD_DURATION, 0.0, 1.0)
			selected_button.set_progress(progress)
			
			if hold_timer >= HOLD_DURATION:
				confirm_selection()
				is_holding = false
				hold_timer = 0.0
				if is_instance_valid(selected_button):  # Check again before setting progress
					selected_button.set_progress(0.0)

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

func setup_powerups(powerups: Array) -> void:
	print("[Setup] Starting powerup setup")
	for child in powerup_container.get_children():
		child.queue_free()
	powerup_buttons.clear()
	
	# Set states before starting any animations
	is_processing_selection = false  # Allow selection immediately
	is_transitioning = false  # Don't block inputs
	current_selection = 1  # Start with middle button (changed from 0)
	
	print("[Setup] Creating ", powerups.size(), " powerup buttons")
	for powerup in powerups:
		var button = PowerupButton.instantiate()
		powerup_container.add_child(button)
		button.setup(powerup)
		button.pressed.connect(func(): _on_powerup_selected(powerup))
		powerup_buttons.append(button)
		# Start buttons off-screen and invisible
		button.position.x = -SLIDE_DISTANCE
		button.modulate.a = 0.0
		button.scale = Vector2(0.8, 0.8)
		button.mouse_filter = Control.MOUSE_FILTER_STOP  # Enable interaction immediately
		print("[Setup] Button created at x=", button.position.x)
	
	if !powerup_buttons.is_empty():
		powerup_buttons[current_selection].button_pressed = true
	
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

func _unhandled_input(event: InputEvent) -> void:
	if !visible or is_processing_selection or is_transitioning:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if event is InputEventJoypadMotion:
		if event.axis == 1:  # Vertical axis
			var input_value = event.axis_value
			print("[Input] D-pad value: ", input_value)
			var input_direction = 0
			
			if abs(input_value) > 0.5:
				input_direction = 1 if input_value > 0 else -1
				print("[Input] D-pad direction: ", input_direction)
				
				if input_direction != last_input_direction or (current_time - last_input_time) > INPUT_COOLDOWN:
					change_selection(input_direction)
					last_input_time = current_time
					last_input_direction = input_direction
					get_viewport().set_input_as_handled()
					
					# Reset hold state when changing selection
					is_holding = false
					hold_timer = 0.0
					if is_instance_valid(selected_button):
						selected_button.set_progress(0.0)
			else:
				last_input_direction = 0
	
	elif event.is_action_pressed("powerup_up"):
		if (current_time - last_input_time) > INPUT_COOLDOWN:
			print("[Input] Up button pressed")
			change_selection(-1)
			last_input_time = current_time
			get_viewport().set_input_as_handled()
			
			# Reset hold state when changing selection
			is_holding = false
			hold_timer = 0.0
			if is_instance_valid(selected_button):
				selected_button.set_progress(0.0)
	
	elif event.is_action_pressed("powerup_down"):
		if (current_time - last_input_time) > INPUT_COOLDOWN:
			print("[Input] Down button pressed")
			change_selection(1)
			last_input_time = current_time
			get_viewport().set_input_as_handled()
			
			# Reset hold state when changing selection
			is_holding = false
			hold_timer = 0.0
			if is_instance_valid(selected_button):
				selected_button.set_progress(0.0)
	
	elif event.is_action_pressed("powerup_select"):
		print("[Input] Select button pressed")
		is_holding = true
		hold_timer = 0.0
		if current_selection >= 0 and current_selection < powerup_buttons.size():
			selected_button = powerup_buttons[current_selection]
			if is_instance_valid(selected_button):
				selected_button.set_progress(0.0)
		get_viewport().set_input_as_handled()
	
	elif event.is_action_released("powerup_select"):
		print("[Input] Select button released")
		is_holding = false
		hold_timer = 0.0
		if is_instance_valid(selected_button):
			selected_button.set_progress(0.0)
		get_viewport().set_input_as_handled()

func change_selection(direction: int) -> void:
	if powerup_buttons.is_empty():
		return
		
	if current_selection >= 0 and current_selection < powerup_buttons.size():
		powerup_buttons[current_selection].button_pressed = false
		
	current_selection = (current_selection + direction) % powerup_buttons.size()
	if current_selection < 0:
		current_selection = powerup_buttons.size() - 1
		
	powerup_buttons[current_selection].button_pressed = true
	selected_button = powerup_buttons[current_selection]

func _on_powerup_selected(powerup: PowerupResource) -> void:
	if is_processing_selection:
		return
		
	is_processing_selection = true
	
	# Reset input control immediately
	set_input_deadzones(false)
	is_processing_selection = false
	input_buffer_timer = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(background, "modulate:a", 0.0, FADE_DURATION)
	
	for button in powerup_buttons:
		tween.tween_property(button, "modulate:a", 0.0, FADE_DURATION)
	
	get_tree().paused = false
	tween.tween_property(Engine, "time_scale", 1.0, FADE_DURATION)
	
	await tween.finished
	is_transitioning = false
	
	show_ui(false)
	PowerupManager.apply_powerup(powerup)

func confirm_selection() -> void:
	if current_selection >= 0 and current_selection < powerup_buttons.size():
		print("[Selection] Confirming selection: ", current_selection)
		var selected_powerup = powerup_buttons[current_selection].powerup
		var selected_button = powerup_buttons[current_selection]
		
		# Set states before starting animations
		is_transitioning = true
		is_processing_selection = true
		set_input_deadzones(true)
		
		print("[Animation] Starting unselected button slide out")
		Engine.time_scale = 1.0
		var slide_tween = create_tween()
		slide_tween.set_parallel(true)
		
		for button in powerup_buttons:
			if button != selected_button:
				var direction = 1 if button.global_position.y > selected_button.global_position.y else -1
				slide_tween.tween_property(button, "position:x", SLIDE_DISTANCE * direction, SLIDE_DURATION * 0.75)
				slide_tween.tween_property(button, "modulate:a", 0.0, SLIDE_DURATION * 0.75)
		
		await slide_tween.finished
		print("[Animation] Unselected button slide out complete")
		
		print("[Animation] Starting fade out in slow motion")
		Engine.time_scale = MIN_TIME_SCALE
		get_tree().paused = false
		
		var fade_tween = create_tween()
		fade_tween.set_parallel(true)
		
		fade_tween.tween_property(background, "modulate:a", 0.0, FADE_DURATION)
		fade_tween.tween_property(selected_button, "modulate:a", 0.0, FADE_DURATION)
		fade_tween.tween_property(Engine, "time_scale", 1.0, FADE_DURATION)
		
		await fade_tween.finished
		print("[Animation] Fade out complete")
		
		# Reset states after all animations complete
		is_transitioning = false
		is_processing_selection = false
		show_ui(false)
		PowerupManager.apply_powerup(selected_powerup)

func show_ui(should_show: bool) -> void:
	print("[UI] ", "Showing" if should_show else "Hiding", " UI")
	visible = should_show
	$Control.visible = should_show
	
	if should_show:
		current_selection = 1  # Always start with middle button (changed from 0)
		is_processing_selection = false
		input_buffer_timer = 0.0
		
		background.modulate.a = 1.0
		for button in powerup_buttons:
			button.modulate.a = 1.0
			
		if !powerup_buttons.is_empty():
			powerup_buttons[current_selection].button_pressed = true
	else:
		set_input_deadzones(false)
