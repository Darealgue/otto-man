extends Control

@onready var powerup_container = $VBoxContainer/PowerupContainer

var powerup_button_scene = preload("res://ui/powerup_button.tscn")
var current_powerups: Array[PowerupResource] = []
var selected_index: int = 0

func _ready() -> void:
	PowerupManager.powerup_available.connect(_on_powerups_available)
	hide()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_action_pressed("up") or event.is_action_pressed("left"):
		select_previous()
	elif event.is_action_pressed("down") or event.is_action_pressed("right"):
		select_next()
	elif event.is_action_pressed("jump") or event.is_action_pressed("attack"):
		confirm_selection()

func select_previous() -> void:
	if powerup_container.get_child_count() == 0:
		return
	
	selected_index = (selected_index - 1 + powerup_container.get_child_count()) % powerup_container.get_child_count()
	update_selection()

func select_next() -> void:
	if powerup_container.get_child_count() == 0:
		return
	
	selected_index = (selected_index + 1) % powerup_container.get_child_count()
	update_selection()

func update_selection() -> void:
	for i in powerup_container.get_child_count():
		var button = powerup_container.get_child(i)
		if i == selected_index:
			button.grab_focus()
		else:
			button.release_focus()

func confirm_selection() -> void:
	if powerup_container.get_child_count() == 0:
		return
	
	var powerup = current_powerups[selected_index]
	apply_powerup(powerup)

func _on_powerups_available() -> void:
	show()
	clear_powerups()
	
	current_powerups = PowerupManager.get_random_powerups()
	
	for i in current_powerups.size():
		var powerup = current_powerups[i]
		var button = powerup_button_scene.instantiate()
		powerup_container.add_child(button)
		button.setup(powerup)
		button.pressed.connect(_on_button_pressed.bind(i))
	
	selected_index = 0
	update_selection()

func _on_button_pressed(index: int) -> void:
	if index >= 0 and index < current_powerups.size():
		apply_powerup(current_powerups[index])

func apply_powerup(powerup: PowerupResource) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		PowerupManager.apply_powerup(powerup, player)
	hide()

func clear_powerups() -> void:
	for child in powerup_container.get_children():
		child.queue_free() 
