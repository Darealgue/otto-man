extends CanvasLayer

@onready var console = $Console
@onready var line_edit = $Console/VBoxContainer/LineEdit
@onready var output = $Console/VBoxContainer/RichTextLabel

var command_history: Array[String] = []
var history_index: int = -1
var is_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Make sure we have all required nodes
	if !console or !line_edit or !output:
		push_error("Dev console is missing required nodes!")
		return
		
	console.hide()
	line_edit.text_submitted.connect(_on_command_submitted)
	
	# Initial output
	print_output("Developer Console")
	print_output("Type 'help' for available commands")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_console"):
		toggle_console()
	elif is_open:
		if event.is_action_pressed("ui_up"):
			navigate_history(-1)
		elif event.is_action_pressed("ui_down"):
			navigate_history(1)

func toggle_console() -> void:
	is_open = !is_open
	if !console:
		return
		
	console.visible = is_open
	if is_open:
		line_edit.clear()
		line_edit.grab_focus()
		get_tree().paused = true
	else:
		get_tree().paused = false

func _on_command_submitted(command: String) -> void:
	if command.is_empty():
		return
		
	print_output("> " + command)
	command_history.append(command)
	history_index = command_history.size()
	line_edit.clear()
	
	var args = command.split(" ")
	var cmd = args[0].to_lower()
	args = args.slice(1)
	
	match cmd:
		"help":
			show_help()
		"clear":
			output.clear()
			print_output("Developer Console")
			print_output("Type 'help' for available commands")
		"powerup":
			handle_powerup_command(args)
		"heal":
			handle_heal_command(args)
		"damage":
			handle_damage_command(args)
		"kill":
			handle_kill_command()
		"god":
			handle_god_command()
		"reset":
			handle_reset_command()
		_:
			print_output("Unknown command: " + cmd)

func handle_powerup_command(args: Array) -> void:
	if args.is_empty():
		print_output("Usage: powerup <name>")
		return
		
	var file_name = args[0].to_snake_case() + ".tscn"
	var scene_path = "res://resources/powerups/scenes/" + file_name
	
	var powerup_scene = load(scene_path) as PackedScene
	if powerup_scene:
		PowerupManager.activate_powerup(powerup_scene)
		print_output("Activated powerup: " + args[0])
	else:
		print_output("Failed to load powerup: " + args[0])

func handle_heal_command(args: Array) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if !player or !player.has_method("heal"):
		print_output("No player found or player cannot heal")
		return
		
	var amount = 50.0  # Default heal amount
	if !args.is_empty():
		amount = float(args[0])
	
	player.heal(amount)
	print_output("Healed player for " + str(amount) + " health")

func handle_damage_command(args: Array) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if !player or !player.has_method("take_damage"):
		print_output("No player found or player cannot take damage")
		return
		
	var amount = 10.0  # Default damage amount
	if !args.is_empty():
		amount = float(args[0])
	
	player.take_damage(amount)
	print_output("Dealt " + str(amount) + " damage to player")

func handle_kill_command() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if !player or !player.has_method("take_damage"):
		print_output("No player found or player cannot take damage")
		return
		
	player.take_damage(99999)
	print_output("Killed player")

func handle_god_command() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if !player:
		print_output("No player found")
		return
		
	if player.has_method("toggle_god_mode"):
		player.toggle_god_mode()
		print_output("Toggled god mode")
	else:
		print_output("Player does not have god mode functionality")

func handle_reset_command() -> void:
	get_tree().reload_current_scene()
	print_output("Reset scene")

func show_help() -> void:
	var help_text = """Available commands:
	help - Show this help message
	clear - Clear console output
	powerup <name> - Activate a powerup
	heal [amount] - Heal the player (default: 50)
	damage [amount] - Damage the player (default: 10)
	kill - Instantly kill the player
	god - Toggle god mode
	reset - Reset the current scene"""
	print_output(help_text)

func print_output(text: String) -> void:
	if output:
		output.add_text(text + "\n")

func navigate_history(direction: int) -> void:
	if command_history.is_empty() or !line_edit:
		return
		
	history_index = clamp(history_index + direction, 0, command_history.size())
	
	if history_index < command_history.size():
		line_edit.text = command_history[history_index]
		line_edit.caret_column = line_edit.text.length()
	else:
		line_edit.clear() 
