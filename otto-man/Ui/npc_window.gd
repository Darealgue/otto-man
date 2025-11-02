extends Control

var chat_history: Array = [] # Session chat log
var NpcInfo 
@onready var chat_vbox = $BackPanel/DialogueWindow/ChangeableWindow/ScrollContainer/VBoxContainer
@onready var chat_line_edit = $BackPanel/DialogueWindow/ChangeableWindow/ChatLineEdit
@onready var send_button = $BackPanel/DialogueWindow/ChangeableWindow/SendButton
@onready var chat_scroll = $BackPanel/DialogueWindow/ChangeableWindow/ScrollContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect send button
	send_button.connect("pressed", _on_send_button_pressed)
	# text_submitted signal is connected via scene; keep both paths consistent
	pass

func InitializeWindow(Info):
	NpcInfo = Info
	print("WindowInfo: ", Info)
	

func _on_send_button_pressed():
	var text = chat_line_edit.text
	if text.strip_edges() == "":
		return
	_add_chat_message("Player", text)
	chat_line_edit.text = ""
	send_button.disabled = true
	NpcDialogueManager.process_dialogue(NpcInfo, text, NpcInfo["Info"]["Name"])
	
func _on_chat_line_edit_text_submitted(new_text: String) -> void:
	if new_text.strip_edges() == "":
		return
	_add_chat_message("Player", new_text)
	chat_line_edit.text = ""
	send_button.disabled = true
	NpcDialogueManager.process_dialogue(NpcInfo, new_text, NpcInfo["Info"]["Name"])

func _sanitize_dialogue_text(text: String) -> String:
	# Remove excessive newlines (replace multiple newlines/tabs with single space)
	text = text.replace("\n", " ").replace("\r", " ").replace("\t", " ")
	# Remove excessive spaces (replace multiple spaces with single space)
	var regex = RegEx.new()
	regex.compile("\\s+")
	text = regex.sub(text, " ")
	# Trim leading and trailing whitespace
	text = text.strip_edges()
	return text

func _add_chat_message(talker : String , message: String) -> void:
	if message.strip_edges() == "":
		return
	# Sanitize the message before storing and displaying
	var sanitized_message = _sanitize_dialogue_text(message)
	# Add to session log (store sanitized version)
	chat_history.append("%s: %s" % [talker, sanitized_message])
	# Add to UI as a new Label
	var label := Label.new()
	label.text = "%s : %s" % [talker, sanitized_message]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	chat_vbox.add_child(label)
	_scroll_chat_to_bottom()

func _scroll_chat_to_bottom() -> void:
	await get_tree().process_frame
	if is_instance_valid(chat_scroll) and chat_scroll.get_v_scroll_bar():
		chat_scroll.scroll_vertical = chat_scroll.get_v_scroll_bar().max_value
	
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
	# Clear existing message nodes
	for child in chat_vbox.get_children():
		chat_vbox.remove_child(child)
		child.queue_free()
	# Rebuild from history
	for entry in chat_history:
		var label := Label.new()
		# Sanitize the entry text in case history contains unsanitized data
		var sanitized_entry = _sanitize_dialogue_text(str(entry))
		label.text = sanitized_entry
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		chat_vbox.add_child(label)
	_scroll_chat_to_bottom()


func NPCDialogueProcessed(npc_name: String, new_state: Dictionary, generated_dialogue: String, was_significant: bool):
	# Append NPC reply to chat without resubmitting as player input
	_add_chat_message(npc_name, generated_dialogue)
	NpcInfo = new_state
	get_parent().NPC_Info = new_state
	get_parent().Update_Villager_Name()
	# No need to rebuild from history - _add_chat_message already handles adding to UI correctly
	
	send_button.disabled = false
