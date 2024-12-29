extends Control

signal command_entered(command: String)
signal tab_pressed(current_text: String)

@onready var input_line = $VBoxContainer/InputLine
@onready var output_text = $VBoxContainer/OutputPanel/OutputText

func _ready() -> void:
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	if input_line:
		input_line.text_submitted.connect(_on_input_submitted)

func _input(event: InputEvent) -> void:
	if visible and input_line and input_line.has_focus():
		if event.is_action_pressed("ui_focus_next"):  # Tab key
			get_viewport().set_input_as_handled()
			tab_pressed.emit(input_line.text)

func _on_input_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	
	add_message("> " + text)
	command_entered.emit(text)
	input_line.clear()

func add_message(text: String) -> void:
	if output_text:
		output_text.text += text + "\n"
		# Auto-scroll to bottom
		output_text.scroll_vertical = INF

func focus_input() -> void:
	if input_line and is_instance_valid(input_line):
		input_line.grab_focus()
		input_line.clear()

func get_input() -> String:
	return input_line.text if input_line else ""

func set_input(text: String) -> void:
	if input_line:
		input_line.text = text
		input_line.caret_column = text.length() 
