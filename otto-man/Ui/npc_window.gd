extends Control

var chat_history: Array = [] # Session chat log
var NpcInfo
var _pending_player_turns: Array[Dictionary] = []
## Only rows we create are cleared on rebuild — scene nodes (e.g. editor-sized Label) stay.
const _META_CHAT_DYNAMIC := "npc_chat_dynamic"
## Letter-by-letter reveal for a freshly-arrived NPC line — softens the multi-second TP0-TP5
## wait by not dumping the whole reply on screen instantly the moment it lands.
const _NPC_REVEAL_DURATION_SEC := 1.4
const _NPC_REVEAL_MIN_CHARS_PER_SEC := 18.0
## "Thinking" indicator while TP0-TP5 are running — cycles "." -> ".." -> "..." so the wait
## isn't a dead silent chat box.
const _THINKING_DOT_STATES := ["·", "··", "···"]
const _THINKING_DOT_INTERVAL_SEC := 0.45
var _thinking_label: Label = null
var _thinking_anim_id: int = 0
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


func _rebuild_dialogue_ui_from_chat_log(animate_last_npc_line: bool = false) -> void:
	_clear_dynamic_chat_rows()
	chat_history.clear()
	if NpcInfo == null:
		return
	_ensure_npc_auxiliary_fields(NpcInfo)
	var npc_display_name = str(NpcInfo.get("Info", {}).get("Name", "NPC"))
	var entries: Array = NpcInfo["Chat_log"]
	var last_npc_index := -1
	if animate_last_npc_line:
		for i in range(entries.size() - 1, -1, -1):
			var e = entries[i]
			if typeof(e) == TYPE_DICTIONARY and str(e.get("role", "")) == "npc":
				last_npc_index = i
				break
	for i in range(entries.size()):
		var entry = entries[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var role = str(entry.get("role", ""))
		var raw_text = str(entry.get("text", ""))
		var sanitized = _sanitize_dialogue_text(raw_text)
		if sanitized == "":
			continue
		var talker = npc_display_name if role == "npc" else "Player"
		chat_history.append("%s: %s" % [talker, sanitized])
		_add_chat_label_row(talker, sanitized, i == last_npc_index)
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
		NpcInfo["Chat_log"] = NpcDialogueManager.trim_chat_log_to_storage_cap(NpcInfo["Chat_log"])
		send_button.disabled = true
		NpcDialogueManager.npc_chain_diag_ui_send(sanitized)
		NpcDialogueManager.process_dialogue(NpcInfo, raw_text, str(NpcInfo["Info"]["Name"]))
		_show_thinking_indicator()
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
	NpcInfo["Chat_log"] = NpcDialogueManager.trim_chat_log_to_storage_cap(NpcInfo["Chat_log"])
	_append_chat_row_to_ui("Player", sanitized)
	chat_line_edit.text = ""
	send_button.disabled = true
	NpcDialogueManager.npc_chain_diag_ui_send(sanitized)
	NpcDialogueManager.process_dialogue(NpcInfo, text, str(NpcInfo["Info"]["Name"]))
	_show_thinking_indicator()


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

func _add_chat_label_row(talker: String, sanitized_message: String, animate: bool = false) -> void:
	var label := Label.new()
	label.set_meta(_META_CHAT_DYNAMIC, true)
	var full_text := "%s : %s" % [talker, sanitized_message]
	label.text = full_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	chat_vbox.add_child(label)
	if animate:
		_reveal_label_letter_by_letter(label, full_text)


## Progressively reveals `full_text` on `label` (letter by letter, not an instant pop-in) —
## masks the multi-second TP0-TP5 wait a little once the reply actually lands. Text is set in
## full up front so autowrap/layout sizing (and scroll position) never jumps mid-reveal; only
## `visible_characters` climbs over time. Never takes longer than _NPC_REVEAL_DURATION_SEC, and
## never crawls below _NPC_REVEAL_MIN_CHARS_PER_SEC on long lines.
func _reveal_label_letter_by_letter(label: Label, full_text: String) -> void:
	var total_chars := full_text.length()
	if total_chars == 0:
		return
	var duration := minf(_NPC_REVEAL_DURATION_SEC, total_chars / _NPC_REVEAL_MIN_CHARS_PER_SEC)
	if duration <= 0.0:
		label.visible_characters = -1
		return
	label.visible_characters = 0
	var elapsed := 0.0
	while is_instance_valid(label) and elapsed < duration:
		await get_tree().process_frame
		if not is_instance_valid(label):
			return
		elapsed += get_process_delta_time()
		var shown := int(ceil((elapsed / duration) * total_chars))
		label.visible_characters = mini(shown, total_chars)
		if chat_scroll and is_instance_valid(chat_scroll):
			var bar: ScrollBar = chat_scroll.get_v_scroll_bar()
			if bar and chat_scroll.scroll_vertical >= bar.max_value - bar.page - 4.0:
				chat_scroll.scroll_vertical = bar.max_value
	if is_instance_valid(label):
		label.visible_characters = -1


## Shows a "{Name} : ." row that cycles to ".." then "..." while TP0-TP5 are running for this
## turn. Safe to call even if one's already showing (replaces it).
func _show_thinking_indicator() -> void:
	_hide_thinking_indicator()
	var npc_display_name = str(NpcInfo.get("Info", {}).get("Name", "NPC")) if NpcInfo != null else "NPC"
	var label := Label.new()
	label.set_meta(_META_CHAT_DYNAMIC, true)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	chat_vbox.add_child(label)
	_thinking_label = label
	_scroll_chat_to_bottom()
	_animate_thinking_indicator(label, npc_display_name)


func _animate_thinking_indicator(label: Label, npc_display_name: String) -> void:
	_thinking_anim_id += 1
	var my_id := _thinking_anim_id
	var i := 0
	while is_instance_valid(label) and my_id == _thinking_anim_id:
		label.text = "%s : %s" % [npc_display_name, _THINKING_DOT_STATES[i % _THINKING_DOT_STATES.size()]]
		i += 1
		await get_tree().create_timer(_THINKING_DOT_INTERVAL_SEC).timeout


## Removes the thinking indicator (if any) and stops its animation loop. Call right before the
## real reply row gets added, and on window close.
func _hide_thinking_indicator() -> void:
	_thinking_anim_id += 1  # invalidates any running _animate_thinking_indicator loop
	if is_instance_valid(_thinking_label):
		_thinking_label.queue_free()
	_thinking_label = null


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
	_hide_thinking_indicator()
	NpcInfo = new_state
	_ensure_npc_auxiliary_fields(NpcInfo)
	get_parent().NPC_Info = new_state
	get_parent().Update_Villager_Name()
	# Chat_log already includes NPC line from NPCDialogueManager; resync UI.
	# animate_last_npc_line=true: the fresh reply reveals letter by letter instead of popping in.
	_rebuild_dialogue_ui_from_chat_log(true)
	_scroll_chat_to_bottom()
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
