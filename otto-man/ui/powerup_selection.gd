extends CanvasLayer

signal powerup_selected(powerup_scene: PackedScene)

@onready var powerup_container = $Control/CenterContainer/VBoxContainer/PowerupContainer
@onready var tree_info_label = $Control/CenterContainer/VBoxContainer/TreeInfoLabel

var powerup_buttons: Array[Button] = []
var selected_index: int = 0
var is_processing_selection := false
var selection_hold_time := 0.0
var scenes_to_show: Array[PackedScene] = []  # Store the selected scenes
const SELECTION_HOLD_DURATION := 0.2  # Reduced from 0.4 to 0.2 seconds

var navigation_repeat_timer_up := 0.0
var navigation_repeat_timer_down := 0.0
const NAVIGATION_INITIAL_DELAY := 0.25
const NAVIGATION_REPEAT_DELAY := 0.12

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	show_ui(false)

func _input(event: InputEvent) -> void:
	if !visible or is_processing_selection:
		return
	
	if InputManager.is_event_action(event, &"ui_up") or InputManager.is_event_action(event, &"ui_down"):
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if !visible or is_processing_selection:
		return
	
	# Update navigation timers
	if navigation_repeat_timer_up > 0.0:
		navigation_repeat_timer_up -= delta
	if navigation_repeat_timer_down > 0.0:
		navigation_repeat_timer_down -= delta
	
	if InputManager.is_ui_up_just_pressed():
		_move_selection(-1)
		navigation_repeat_timer_up = NAVIGATION_INITIAL_DELAY
	elif InputManager.is_ui_up_pressed():
		if navigation_repeat_timer_up <= 0.0:
			_move_selection(-1)
			navigation_repeat_timer_up = NAVIGATION_REPEAT_DELAY
	else:
		navigation_repeat_timer_up = 0.0
	
	if InputManager.is_ui_down_just_pressed():
		_move_selection(1)
		navigation_repeat_timer_down = NAVIGATION_INITIAL_DELAY
	elif InputManager.is_ui_down_pressed():
		if navigation_repeat_timer_down <= 0.0:
			_move_selection(1)
			navigation_repeat_timer_down = NAVIGATION_REPEAT_DELAY
	else:
		navigation_repeat_timer_down = 0.0
	
	# Selection: Only use jump button (not interact or ui_accept to prevent conflicts)
	var selecting := InputManager.is_jump_pressed()
	if selecting:
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
	navigation_repeat_timer_up = 0.0
	navigation_repeat_timer_down = 0.0
	
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
	
	# Update tree info
	_update_tree_info()
	
	# Start time slow effect
	if get_node_or_null("/root/ScreenEffects"):
		ScreenEffects.slow_time(0.3, 0.3)  # Reduced duration and increased speed
	show_ui(true)
	update_selection()

func update_selection() -> void:
	for i in powerup_buttons.size():
		var button = powerup_buttons[i]
		button.modulate = Color.WHITE if i != selected_index else Color(1, 0.8, 0)

func _move_selection(direction: int) -> void:
	if powerup_buttons.is_empty():
		return
	
	var count := powerup_buttons.size()
	selected_index = (selected_index + direction + count) % count
	update_selection()
	get_viewport().set_input_as_handled()

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

func _update_tree_info() -> void:
	if !tree_info_label:
		return
	
	var powerup_manager = get_node("/root/PowerupManager")
	if !powerup_manager:
		return
	
	var tree_info = ""
	var unlocked_trees = powerup_manager.get_unlocked_trees()
	
	if unlocked_trees.size() > 0:
		tree_info = "Unlocked Trees:\n"
		for tree_name in unlocked_trees:
			var progress = powerup_manager.get_tree_progress(tree_name)
			var tree_def = powerup_manager.TREE_DEFINITIONS.get(tree_name, {})
			var tree_color = tree_def.get("color", Color.WHITE)
			var tree_display_name = tree_def.get("name", tree_name.capitalize())
			tree_info += "• " + tree_display_name + " (Level " + str(progress) + ")\n"
	else:
		tree_info = "No trees unlocked yet.\nChoose powerups to unlock trees!"
	
	# Add synergy info
	var active_synergies = powerup_manager.get_active_synergies()
	if active_synergies.size() > 0:
		tree_info += "\nActive Synergies:\n"
		for synergy_id in active_synergies:
			var synergy_info = powerup_manager.get_synergy_info(synergy_id)
			if synergy_info.has("name"):
				tree_info += "• " + synergy_info.name + "\n"
	
	tree_info_label.text = tree_info
