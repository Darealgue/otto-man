extends Node

var console_visible := false
var command_history: Array[String] = []
var history_index := -1
var current_input := ""

var console_ui: Control
var available_commands := {
	"powerup": "Force apply a powerup",
	"powerups": "Show powerup selection UI",
	"kill": "Kill all enemies",
	"health": "Set player health",
	"god": "Toggle god mode",
	"help": "Show this help message",
	"list": "List all available powerups"
}

var available_powerups: Array[String] = []

func _ready() -> void:
	# Wait a frame to ensure the scene tree is ready
	await get_tree().process_frame
	
	# Create and add the console UI
	console_ui = preload("res://ui/dev_console.tscn").instantiate()
	get_tree().root.add_child(console_ui)
	console_ui.hide()
	
	# Connect signals
	if console_ui:
		console_ui.command_entered.connect(_on_command_entered)
		console_ui.tab_pressed.connect(_on_tab_pressed)
	
	# Load available powerups
	load_available_powerups()

func load_available_powerups() -> void:
	available_powerups.clear()
	var powerups_dir = DirAccess.open("res://resources/powerups")
	if powerups_dir:
		powerups_dir.list_dir_begin()
		var file_name = powerups_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var powerup = load("res://resources/powerups/" + file_name) as PowerupResource
				if powerup:
					available_powerups.append(powerup.name)
			file_name = powerups_dir.get_next()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_console"):
		toggle_console()
	
	if console_visible:
		if event.is_action_pressed("ui_up"):
			cycle_history(1)
		elif event.is_action_pressed("ui_down"):
			cycle_history(-1)

func toggle_console() -> void:
	if !console_ui:
		return
		
	console_visible = !console_visible
	console_ui.visible = console_visible
	
	if console_visible:
		get_tree().paused = true
		console_ui.focus_input()
	else:
		get_tree().paused = false

func _on_command_entered(command: String) -> void:
	if command.is_empty() or !console_ui:
		return
		
	# Add to history
	command_history.push_front(command)
	if command_history.size() > 20:  # Keep last 20 commands
		command_history.pop_back()
	history_index = -1
	
	# Parse and execute command
	var parts = command.split(" ")
	var cmd = parts[0].to_lower()
	var args = parts.slice(1)
	
	match cmd:
		"powerup":
			if args.size() > 0:
				force_powerup(args.join(" "))
		"powerups":
			show_powerup_selection()
		"kill":
			kill_enemies()
		"health":
			if args.size() > 0:
				set_player_health(args[0].to_int())
		"god":
			toggle_god_mode()
		"help":
			show_help()
		"list":
			list_powerups()
		_:
			console_ui.add_message("Unknown command. Type 'help' for available commands.")
	
	# Auto-hide console after command
	toggle_console()

func _on_tab_pressed(current_text: String) -> void:
	if current_text.is_empty():
		return
	
	var parts = current_text.split(" ")
	var current_word = parts[-1].to_lower()
	
	if parts.size() == 1:
		# Auto-complete commands
		for cmd in available_commands.keys():
			if cmd.begins_with(current_word):
				console_ui.set_input(cmd)
				return
	elif parts[0] == "powerup" and parts.size() == 2:
		# Auto-complete powerup names
		for powerup in available_powerups:
			if powerup.to_lower().begins_with(current_word):
				console_ui.set_input("powerup \"" + powerup + "\"")
				return

func cycle_history(direction: int) -> void:
	if command_history.is_empty() or !console_ui:
		return
	
	history_index = clamp(history_index + direction, -1, command_history.size() - 1)
	
	if history_index == -1:
		console_ui.set_input(current_input)
	else:
		if history_index == 0:
			current_input = console_ui.get_input()
		console_ui.set_input(command_history[history_index])

func force_powerup(powerup_name: String) -> void:
	if !console_ui:
		return
	
	# Remove quotes if present
	powerup_name = powerup_name.strip_edges()
	if powerup_name.begins_with("\"") and powerup_name.ends_with("\""):
		powerup_name = powerup_name.substr(1, powerup_name.length() - 2)
		
	var powerups_dir = DirAccess.open("res://resources/powerups")
	if powerups_dir:
		powerups_dir.list_dir_begin()
		var file_name = powerups_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var powerup = load("res://resources/powerups/" + file_name) as PowerupResource
				if powerup and powerup.name.to_lower() == powerup_name.to_lower():
					PowerupManager.apply_powerup(powerup)
					console_ui.add_message("Applied powerup: " + powerup.name)
					return
			file_name = powerups_dir.get_next()
	
	console_ui.add_message("Powerup not found: " + powerup_name)

func show_powerup_selection() -> void:
	if !console_ui:
		return
		
	console_ui.add_message("DEBUG: Attempting to show powerup selection UI...")
	
	# Check if PowerupManager exists
	if !PowerupManager:
		console_ui.add_message("ERROR: PowerupManager not found!")
		return
	
	# Check if signal exists
	if !PowerupManager.has_signal("powerup_selection_ready"):
		console_ui.add_message("ERROR: powerup_selection_ready signal not found in PowerupManager!")
		return
	
	# Check if any connections exist
	var connections = PowerupManager.get_signal_connection_list("powerup_selection_ready")
	console_ui.add_message("DEBUG: Found " + str(connections.size()) + " connections to powerup_selection_ready signal")
	
	# Emit the signal
	PowerupManager.powerup_selection_ready.emit()
	console_ui.add_message("DEBUG: Signal emitted")

func list_powerups() -> void:
	if !console_ui:
		return
		
	console_ui.add_message("Available powerups:")
	for powerup in available_powerups:
		console_ui.add_message("- " + powerup)

func kill_enemies() -> void:
	if !console_ui:
		return
		
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(99999)
	console_ui.add_message("Killed " + str(enemies.size()) + " enemies")

func set_player_health(amount: int) -> void:
	if !console_ui:
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health = amount
		player.health_changed.emit(amount)
		console_ui.add_message("Set player health to " + str(amount))

func toggle_god_mode() -> void:
	if !console_ui:
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.is_invincible = !player.is_invincible
		console_ui.add_message("God mode: " + ("ON" if player.is_invincible else "OFF"))

func show_help() -> void:
	if !console_ui:
		return
		
	console_ui.add_message("Available commands:")
	for cmd in available_commands:
		console_ui.add_message("- " + cmd + ": " + available_commands[cmd]) 