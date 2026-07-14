extends Control

var chat_history: Array = [] # Session chat log
var NpcInfo
var _pending_player_turns: Array[Dictionary] = []
## Only rows we create are cleared on rebuild — scene nodes (e.g. editor-sized Label) stay.
const _META_CHAT_DYNAMIC := "npc_chat_dynamic"
@onready var chat_vbox = $BackPanel/DialogueWindow/ChangeableWindow/ScrollContainer/VBoxContainer
@onready var chat_line_edit = $BackPanel/DialogueWindow/ChangeableWindow/ChatLineEdit
@onready var send_button = $BackPanel/DialogueWindow/ChangeableWindow/SendButton
@onready var chat_scroll = $BackPanel/DialogueWindow/ChangeableWindow/ScrollContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_setup_back_panel_parchment()
	# Connect send button
	send_button.connect("pressed", _on_send_button_pressed)


func _setup_back_panel_parchment() -> void:
	var back := get_node_or_null("BackPanel") as ParchmentFrame
	if back == null:
		return
	var tex := load("res://assets/UI/menu_ninepatchrect.png") as Texture2D
	if tex:
		back.parchment_texture = tex
		back.patch_margin = 28
		back.content_margin = 16
	back.apply_style_now()
	TextOutline.apply_to_tree(self)


func InitializeWindow(Info):
	NpcInfo = Info
	_pending_player_turns.clear()
	_ensure_npc_auxiliary_fields(NpcInfo)
	$BackPanel/NamePlate.text = Info["Info"]["Name"]
	# Clear existing history labels before adding new ones
	var history_container = $BackPanel/DiaryWindow/ScrollContainer/VBoxContainer
	for child in history_container.get_children():
		history_container.remove_child(child)
		child.queue_free()
	# Add history items
	for item in NpcInfo["History"]:
		var historylabel = Label.new()
		history_container.add_child(historylabel)
		historylabel.autowrap_mode = 3
		historylabel.text = item
	_rebuild_dialogue_ui_from_chat_log()
	print("INITIALIZED WORKER")
	print("WindowInfo: ", Info)


func _ensure_npc_auxiliary_fields(info: Dictionary) -> void:
	if not info.has("Chat_log") or typeof(info["Chat_log"]) != TYPE_ARRAY:
		info["Chat_log"] = []
	info.erase("History_summary")


func _clear_dynamic_chat_rows() -> void:
	for child in chat_vbox.get_children():
		if not child.get_meta(_META_CHAT_DYNAMIC, false):
			continue
		chat_vbox.remove_child(child)
		child.queue_free()


func _rebuild_dialogue_ui_from_chat_log() -> void:
	_clear_dynamic_chat_rows()
	chat_history.clear()
	if NpcInfo == null:
		return
	_ensure_npc_auxiliary_fields(NpcInfo)
	var npc_display_name = str(NpcInfo.get("Info", {}).get("Name", "NPC"))
	for entry in NpcInfo["Chat_log"]:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var role = str(entry.get("role", ""))
		var raw_text = str(entry.get("text", ""))
		var sanitized = _sanitize_dialogue_text(raw_text)
		if sanitized == "":
			continue
		var talker = npc_display_name if role == "npc" else "Player"
		chat_history.append("%s: %s" % [talker, sanitized])
		_add_chat_label_row(talker, sanitized)
	_append_pending_player_rows_to_chat_ui()

func _append_pending_player_rows_to_chat_ui() -> void:
	for turn in _pending_player_turns:
		var sanitized = str(turn.get("sanitized", "")).strip_edges()
		if sanitized == "":
			continue
		chat_history.append("Player: %s" % sanitized)
		_add_chat_label_row("Player", sanitized)
	if not _pending_player_turns.is_empty():
		_scroll_chat_to_bottom()


func _try_dispatch_pending_or_enable_send() -> void:
	while true:
		if NpcDialogueManager.is_npc_dialogue_busy():
			return
		if _pending_player_turns.is_empty():
			send_button.disabled = false
			return
		var turn: Dictionary = _pending_player_turns.pop_front()
		var raw_text := str(turn.get("raw", "")).strip_edges()
		var sanitized := str(turn.get("sanitized", "")).strip_edges()
		if raw_text == "" or sanitized == "":
			continue
		_ensure_npc_auxiliary_fields(NpcInfo)
		NpcInfo["Chat_log"].append({"role": "player", "speaker": "Player", "text": sanitized})
		send_button.disabled = true
		NpcDialogueManager.npc_chain_diag_ui_send(sanitized)
		NpcDialogueManager.process_dialogue(NpcInfo, raw_text, str(NpcInfo["Info"]["Name"]))
		return


func _submit_player_dialogue(raw_input: String) -> void:
	var text := raw_input.strip_edges()
	if text == "":
		return
	_ensure_npc_auxiliary_fields(NpcInfo)
	var sanitized := _sanitize_dialogue_text(raw_input)
	if NpcDialogueManager.is_npc_dialogue_busy():
		_pending_player_turns.append({"raw": text, "sanitized": sanitized})
		chat_history.append("Player: %s" % sanitized)
		_add_chat_label_row("Player", sanitized)
		chat_line_edit.text = ""
		_scroll_chat_to_bottom()
		return
	NpcInfo["Chat_log"].append({"role": "player", "speaker": "Player", "text": sanitized})
	_append_chat_row_to_ui("Player", sanitized)
	chat_line_edit.text = ""
	send_button.disabled = true
	NpcDialogueManager.npc_chain_diag_ui_send(sanitized)
	NpcDialogueManager.process_dialogue(NpcInfo, text, str(NpcInfo["Info"]["Name"]))


func _on_send_button_pressed():
	_submit_player_dialogue(chat_line_edit.text)


func _on_chat_line_edit_text_submitted(new_text: String) -> void:
	_submit_player_dialogue(new_text)

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

func _add_chat_label_row(talker: String, sanitized_message: String) -> void:
	var label := Label.new()
	label.set_meta(_META_CHAT_DYNAMIC, true)
	label.text = "%s : %s" % [talker, sanitized_message]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	chat_vbox.add_child(label)


func _append_chat_row_to_ui(talker: String, sanitized_message: String) -> void:
	if sanitized_message.strip_edges() == "":
		return
	chat_history.append("%s: %s" % [talker, sanitized_message])
	_add_chat_label_row(talker, sanitized_message)
	_scroll_chat_to_bottom()


func _add_chat_message(talker: String, message: String) -> void:
	if message.strip_edges() == "":
		return
	var sanitized_message = _sanitize_dialogue_text(message)
	_append_chat_row_to_ui(talker, sanitized_message)

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
	_clear_dynamic_chat_rows()
	for entry in chat_history:
		var sanitized_entry = _sanitize_dialogue_text(str(entry))
		var label := Label.new()
		label.set_meta(_META_CHAT_DYNAMIC, true)
		label.text = sanitized_entry
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		chat_vbox.add_child(label)
	_scroll_chat_to_bottom()


func NPCDialogueProcessed(npc_name: String, new_state: Dictionary, generated_dialogue: String, was_significant: bool):
	NpcInfo = new_state
	_ensure_npc_auxiliary_fields(NpcInfo)
	get_parent().NPC_Info = new_state
	get_parent().Update_Villager_Name()
	# Chat_log already includes NPC line from NPCDialogueManager; resync UI
	_rebuild_dialogue_ui_from_chat_log()
	# Re-initialize diary history if it changed
	var history_container = $BackPanel/DiaryWindow/ScrollContainer/VBoxContainer
	for child in history_container.get_children():
		history_container.remove_child(child)
		child.queue_free()
	for item in NpcInfo["History"]:
		var historylabel = Label.new()
		history_container.add_child(historylabel)
		historylabel.autowrap_mode = 3
		historylabel.text = item
	_try_dispatch_pending_or_enable_send()


func refresh_diary_from_npcinfo() -> void:
	if NpcInfo == null:
		return
	var history_container = $BackPanel/DiaryWindow/ScrollContainer/VBoxContainer
	for child in history_container.get_children():
		history_container.remove_child(child)
		child.queue_free()
	for item in NpcInfo.get("History", []):
		var historylabel = Label.new()
		history_container.add_child(historylabel)
		historylabel.autowrap_mode = 3
		historylabel.text = str(item)


func _on_diary_button_pressed() -> void:
	$BackPanel/DutiesWindow.hide()
	$BackPanel/MissionWindow.hide()
	$BackPanel/DiaryWindow.show()
	$BackPanel/DialogueWindow.hide()
	
	

func _on_dialogue_button_pressed() -> void:
	$BackPanel/DutiesWindow.hide()
	$BackPanel/MissionWindow.hide()
	$BackPanel/DiaryWindow.hide()
	$BackPanel/DialogueWindow.show()
	


func _on_close_button_pressed() -> void:
	# Close the window by calling the parent Worker's CloseNpcWindow method
	if get_parent() and get_parent().has_method("CloseNpcWindow"):
		get_parent().CloseNpcWindow()

func _input(event: InputEvent) -> void:
	# Allow ESC key to close the dialogue window
	if visible and InputManager.is_ui_cancel_pressed():
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()
