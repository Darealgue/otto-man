# item_selection.gd
# UI for selecting items (adapted from powerup_selection)

extends CanvasLayer

signal item_selected(item_scene: PackedScene)

@onready var item_container = $Control/CenterContainer/VBoxContainer/ItemContainer
@onready var info_label = $Control/CenterContainer/VBoxContainer/InfoLabel

var item_buttons: Array[Button] = []
var selected_index: int = 0
var is_processing_selection := false
var selection_hold_time := 0.0
var scenes_to_show: Array[PackedScene] = []
const SELECTION_HOLD_DURATION := 0.2

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
	
	# Selection: Use jump button
	var selecting := InputManager.is_jump_pressed()
	if selecting:
		selection_hold_time += delta
		if selection_hold_time >= SELECTION_HOLD_DURATION:
			if selected_index >= 0 and selected_index < item_buttons.size():
				select_item(selected_index)
		# Update button progress
		if selected_index >= 0 and selected_index < item_buttons.size():
			item_buttons[selected_index].set_progress(selection_hold_time / SELECTION_HOLD_DURATION)
	else:
		selection_hold_time = 0.0
		# Reset button progress
		if selected_index >= 0 and selected_index < item_buttons.size():
			item_buttons[selected_index].set_progress(0.0)

func setup_items(item_scenes: Array[PackedScene]) -> void:
	for child in item_container.get_children():
		child.queue_free()
	
	# Set states before starting any animations
	is_processing_selection = false
	selected_index = 0
	selection_hold_time = 0.0
	navigation_repeat_timer_up = 0.0
	navigation_repeat_timer_down = 0.0
	
	item_buttons.clear()
	
	is_processing_selection = false
	selected_index = 0
	selection_hold_time = 0.0
	navigation_repeat_timer_up = 0.0
	navigation_repeat_timer_down = 0.0
	
	scenes_to_show = item_scenes.duplicate()
	
	# Create buttons for each item
	for scene in scenes_to_show:
		var item = scene.instantiate() as ItemEffect
		if !item:
			continue
			
		var button = preload("res://ui/item_button.tscn").instantiate()
		button.setup(scene)
		button.custom_minimum_size = Vector2(400, 80)
		button.pressed.connect(_on_item_button_pressed.bind(scenes_to_show.find(scene)))
		
		item_container.add_child(button)
		item_buttons.append(button)
		
		item.queue_free()
	
	_update_info()
	show_ui(true)
	update_selection()

func update_selection() -> void:
	for i in item_buttons.size():
		var button = item_buttons[i]
		button.modulate = Color.WHITE if i != selected_index else Color(1, 0.8, 0)

func _move_selection(direction: int) -> void:
	if item_buttons.is_empty():
		return
	
	var count := item_buttons.size()
	selected_index = (selected_index + direction + count) % count
	update_selection()
	get_viewport().set_input_as_handled()

func select_item(index: int) -> void:
	if is_processing_selection:
		return
		
	is_processing_selection = true
	var item_scene = scenes_to_show[index]
	ItemManager.activate_item(item_scene)
	
	# Slow time effect when exiting
	if get_node_or_null("/root/ScreenEffects"):
		ScreenEffects.slow_time(0.2, 0.3)
	
	await get_tree().create_timer(0.2).timeout
	get_tree().paused = false
	queue_free()

func _on_item_button_pressed(index: int) -> void:
	selected_index = index
	update_selection()

func show_ui(show: bool) -> void:
	visible = show

func _update_info() -> void:
	if !info_label:
		return
	
	var active_count = ItemManager.get_active_items().size()
	info_label.text = "Aktif Item'lar: " + str(active_count)
