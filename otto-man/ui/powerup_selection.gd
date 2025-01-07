extends CanvasLayer

signal powerup_selected(powerup_scene: PackedScene)

@onready var powerup_container = $Control/CenterContainer/VBoxContainer/PowerupContainer

var powerup_buttons: Array[Button] = []
var selected_index: int = 0
var is_processing_selection := false
var selection_hold_time := 0.0
var scenes_to_show: Array[PackedScene] = []  # Store the selected scenes
const SELECTION_HOLD_DURATION := 0.2  # Reduced from 0.4 to 0.2 seconds

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	show_ui(false)

func _input(event: InputEvent) -> void:
	if !visible or is_processing_selection:
		return
		
	# Navigate up with W key
	if event.is_action_pressed("up"):
		selected_index = (selected_index - 1) % powerup_buttons.size()
		if selected_index < 0:
			selected_index = powerup_buttons.size() - 1
		update_selection()
		get_viewport().set_input_as_handled()
		
	# Navigate down with S key
	elif event.is_action_pressed("down"):
		selected_index = (selected_index + 1) % powerup_buttons.size()
		update_selection()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if !visible or is_processing_selection:
		return
		
	if Input.is_action_pressed("jump"):  # Using jump for selection
		selection_hold_time += delta
		if selection_hold_time >= SELECTION_HOLD_DURATION:
			if selected_index >= 0 and selected_index < powerup_buttons.size():
				select_powerup(selected_index)
		# Update button progress
		if selected_index >= 0 and selected_index < powerup_buttons.size():
			powerup_buttons[selected_index].set_progress(selection_hold_time / SELECTION_HOLD_DURATION)
	else:
		selection_hold_time = 0.0
		# Reset button progress
		if selected_index >= 0 and selected_index < powerup_buttons.size():
			powerup_buttons[selected_index].set_progress(0.0)

func setup_powerups(powerup_scenes: Array[PackedScene]) -> void:
	for child in powerup_container.get_children():
		child.queue_free()
	powerup_buttons.clear()
	
	# Set states before starting any animations
	is_processing_selection = false
	selected_index = 0
	selection_hold_time = 0.0
	
	# Randomly select 3 powerups
	var available_scenes = powerup_scenes.duplicate()
	available_scenes.shuffle()
	scenes_to_show = available_scenes.slice(0, 3)  # Store in class variable
	
	# Create buttons for each powerup
	for scene in scenes_to_show:
		var powerup = scene.instantiate() as PowerupEffect
		if !powerup:
			continue
			
		var button = preload("res://ui/powerup_button.tscn").instantiate()
		button.setup(scene)
		button.custom_minimum_size = Vector2(400, 80)
		button.pressed.connect(_on_powerup_button_pressed.bind(scenes_to_show.find(scene)))
		
		powerup_container.add_child(button)
		powerup_buttons.append(button)
		
		powerup.queue_free()
	
	# Start time slow effect
	if get_node_or_null("/root/ScreenEffects"):
		ScreenEffects.slow_time(0.3, 0.3)  # Reduced duration and increased speed
	show_ui(true)
	update_selection()

func update_selection() -> void:
	for i in powerup_buttons.size():
		var button = powerup_buttons[i]
		button.modulate = Color.WHITE if i != selected_index else Color(1, 0.8, 0)

func select_powerup(index: int) -> void:
	if is_processing_selection:
		return
		
	is_processing_selection = true
	var powerup_scene = scenes_to_show[index]  # Use the stored scenes
	PowerupManager.activate_powerup(powerup_scene)
	
	# Slow time again when exiting
	if get_node_or_null("/root/ScreenEffects"):
		ScreenEffects.slow_time(0.2, 0.3)  # Reduced duration and increased speed
	
	# Clean up and unpause after time slow
	await get_tree().create_timer(0.2).timeout
	get_tree().paused = false
	queue_free()

func _on_powerup_button_pressed(index: int) -> void:
	selected_index = index
	update_selection()

func show_ui(show: bool) -> void:
	visible = show
