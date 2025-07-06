extends Control

var chat_history: Array = [] # Session chat log

@onready var chat_vbox = $"BackPanel/ChangeableWindow/ChangeableWindow_DialogueWindow#ChatVBox/ScrollContainer/VBoxContainer/Label"
@onready var chat_line_edit = $"BackPanel/ChangeableWindow/ChangeableWindow_DialogueWindow#ChatVBox/ChatLineEdit"
@onready var send_button = $"BackPanel/ChangeableWindow/ChangeableWindow_DialogueWindow#ChatVBox/SendButton"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect send button
	send_button.connect("pressed",_on_send_button_pressed)
	
func get_NPC():
	pass
func _on_send_button_pressed():
	_add_chat_message("Player",chat_line_edit.text)
	chat_line_edit.text = ""

func _on_chat_line_edit_text_submitted(new_text: String) -> void:
	_add_chat_message("Player",new_text)
	chat_line_edit.text = ""

func _add_chat_message(talker : String , message: String) -> void:
	if message.strip_edges() == "":
		return
	# Add to session log
	chat_history.append(message)
	# Add to UI
	$"BackPanel/ChangeableWindow/ChangeableWindow_DialogueWindow#ChatVBox/ScrollContainer/VBoxContainer/Label".text = $"BackPanel/ChangeableWindow/ChangeableWindow_DialogueWindow#ChatVBox/ScrollContainer/VBoxContainer/Label".text + talker + " : " + message + "\n"
func save_chat_history(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_var(chat_history)
		file.close()

func load_chat_history(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var loaded = file.get_var()
		if loaded is Array:
			chat_history = loaded
			_update_chat_ui_from_history()
		file.close()

func _update_chat_ui_from_history():
	chat_vbox.clear()
	for message in chat_history:
		var label = Label.new()
		label.text = message
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		chat_vbox.add_child(label)
	# Scroll to bottom
	await get_tree().process_frame
	$BackPanel/ChangeableWindow/DialogueWindow.scroll_vertical = $BackPanel/ChangeableWindow/DialogueWindow.get_v_scroll_bar().max_value

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
