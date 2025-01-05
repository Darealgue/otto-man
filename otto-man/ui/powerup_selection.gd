extends CanvasLayer

signal powerup_selected(powerup_scene: PackedScene)

@onready var powerup_container = $Control/CenterContainer/VBoxContainer/PowerupContainer

var powerup_buttons: Array[Button] = []
var selected_index: int = 0
var is_processing_selection := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	show_ui(false)

func _input(event: InputEvent) -> void:
	if !visible or is_processing_selection:
		return
		
	if event.is_action_pressed("powerup_up"):
		selected_index = (selected_index - 1) % powerup_buttons.size()
		if selected_index < 0:
			selected_index = powerup_buttons.size() - 1
		update_selection()
		
	elif event.is_action_pressed("powerup_down"):
		selected_index = (selected_index + 1) % powerup_buttons.size()
		update_selection()
		
	elif event.is_action_pressed("powerup_select"):
		if selected_index >= 0 and selected_index < powerup_buttons.size():
			select_powerup(selected_index)

func setup_powerups(powerup_scenes: Array[PackedScene]) -> void:
	for child in powerup_container.get_children():
		child.queue_free()
	powerup_buttons.clear()
	
	# Set states before starting any animations
	is_processing_selection = false
	selected_index = 0
	
	# Create buttons for each powerup
	for scene in powerup_scenes:
		var powerup = scene.instantiate() as PowerupEffect
		if !powerup:
			continue
			
		var button = Button.new()
		button.text = powerup.powerup_name + "\n" + powerup.description
		button.custom_minimum_size = Vector2(400, 80)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(_on_powerup_button_pressed.bind(powerup_scenes.find(scene)))
		
		powerup_container.add_child(button)
		powerup_buttons.append(button)
		
		powerup.queue_free()
	
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
	var powerup_scene = PowerupManager.POWERUP_SCENES[index]
	PowerupManager.activate_powerup(powerup_scene)
	
	# Clean up and unpause
	get_tree().paused = false
	queue_free()

func _on_powerup_button_pressed(index: int) -> void:
	selected_index = index
	update_selection()
	select_powerup(index)

func show_ui(show: bool) -> void:
	visible = show
