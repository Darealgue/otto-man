extends Control
## Köylü etkileşim penceresi — ortalı, karartmalı, tek parça modal. Sol sütun: portre + isim +
## tüm tanımlayıcı bilgiler (yaş, cinsiyet, eski mesleği, şu an köyde ne iş yaptığı, ruh hali,
## sağlığı) ve altında Günlük (yaşadığı önemli olaylar) — hepsi aynı anda görünür, sekme yok.
## Sağ sütun: Sohbet (chat log + mesaj kutusu). Klavye/gamepad dostu: ESC/B ile kapanır,
## PageUp/PageDown veya gamepad d-pad/stick ile sohbet kaydırılır.

## class_name yerine dosya yoluyla preload ediyoruz: bu iki script proje editörü tarafından
## henüz taranmamış/yeni eklenmiş olabilir ve Godot'un global class_name kaydı editör taraması
## gerektirir — bare isimle kullanmak "not declared in the current scope" parse hatası verip
## npc_window.gd'nin tamamen yüklenmesini engelliyordu (pencere içeriksiz .show() oluyor,
## oyuncu kilidi devrede kalıyordu). preload ile bu bağımlılık ortadan kalkıyor.
const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")
const _VirtualKeyboardScript := preload("res://ui/VirtualKeyboardUI.gd")
const _NpcPortraitRenderer := preload("res://ui/NpcPortraitRenderer.gd")

var chat_history: Array = [] # Session chat log
var NpcInfo
var _pending_player_turns: Array[Dictionary] = []
## Only rows we create are cleared on rebuild — scene nodes stay.
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

var _owner_npc: Node2D = null
var _portrait_generation: int = 0

# Built nodes
var _dim: ColorRect
var _back_panel: PanelContainer
var _portrait_rect: TextureRect
var _portrait_color: ColorRect
var _portrait_initial: Label
var _name_label: Label
var _stats_label: Label
var _diary_empty_label: Label
var _diary_vbox: VBoxContainer
var _diary_scroll: ScrollContainer
var _nav_hint_label: Label
var _virtual_keyboard: Control

var chat_vbox: VBoxContainer
var chat_line_edit: LineEdit
var send_button: Button
var chat_scroll: ScrollContainer


func _ready() -> void:
	# Diğer scriptler (kamera, oyuncu vb.) tuşları bizden önce tüketip set_input_as_handled()
	# çağırmasın diye input işleme önceliğini en öne alıyoruz.
	process_priority = -1000
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _MEDIEVAL_THEME
	_owner_npc = get_parent() as Node2D
	_build_ui()
	send_button.pressed.connect(_on_send_button_pressed)
	chat_line_edit.text_submitted.connect(_on_chat_line_edit_text_submitted)
	TextOutline.apply_to_tree(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not InputManager.input_device_changed.is_connected(_on_input_device_changed):
		InputManager.input_device_changed.connect(_on_input_device_changed)
	# Worker (Node2D) altında dünya kamerasına tabi doğardık; kamera zoom/pan'dan bağımsız,
	# gerçek ekran-uzayı bir modal olmak için ayrı bir CanvasLayer'a taşınıyoruz. _owner_npc
	# zaten cache'lendiği ve Worker.gd de artık $NpcWindow yerine kendi cache'ini kullandığı
	# için bu reparent, dışarıdan bakan hiçbir NodePath'i bozmuyor.
	call_deferred("_move_to_canvas_layer")


func _move_to_canvas_layer() -> void:
	if not is_instance_valid(self):
		return
	var layer := _resolve_canvas_layer()
	if layer == null or get_parent() == layer:
		return
	reparent(layer, false)


const _CANVAS_LAYER_NAME := "NpcWindowCanvas"


func _resolve_canvas_layer() -> CanvasLayer:
	var existing := get_tree().root.get_node_or_null(_CANVAS_LAYER_NAME) as CanvasLayer
	if is_instance_valid(existing):
		return existing
	var layer := CanvasLayer.new()
	layer.name = _CANVAS_LAYER_NAME
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	return layer


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			_on_window_shown()
		else:
			_on_window_hidden()


func _on_window_shown() -> void:
	VillageManager.register_npc_dialogue_window_shown()
	_refresh_info_panel()
	_refresh_portrait()
	refresh_diary_from_npcinfo()
	_update_nav_hint()
	_sync_virtual_keyboard_visibility()
	_scroll_chat_to_bottom()
	if is_instance_valid(chat_line_edit):
		chat_line_edit.grab_focus()


func _on_window_hidden() -> void:
	VillageManager.register_npc_dialogue_window_hidden()
	if is_instance_valid(_virtual_keyboard):
		_virtual_keyboard.close_keyboard()


# ─── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.04, 0.02, 0.01, 0.52)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_gui_input)
	add_child(_dim)

	_back_panel = PanelContainer.new()
	_back_panel.anchor_left = 0.5
	_back_panel.anchor_right = 0.5
	_back_panel.anchor_top = 0.5
	_back_panel.anchor_bottom = 0.5
	_back_panel.offset_left = -420
	_back_panel.offset_top = -300
	_back_panel.offset_right = 420
	_back_panel.offset_bottom = 300
	ParchmentTextures.apply_large_panel_style(_back_panel, 16)
	add_child(_back_panel)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	_back_panel.add_child(root)

	_build_left_column(root)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(2, 0)
	divider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	root.add_child(divider)

	_build_right_column(root)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.anchor_left = 0.5
	close_btn.anchor_right = 0.5
	close_btn.anchor_top = 0.5
	close_btn.anchor_bottom = 0.5
	close_btn.offset_left = 382
	close_btn.offset_top = -296
	close_btn.offset_right = 414
	close_btn.offset_bottom = -264
	close_btn.pressed.connect(_on_close_button_pressed)
	add_child(close_btn)

	_virtual_keyboard = _VirtualKeyboardScript.new()
	_virtual_keyboard.name = "VirtualKeyboard"
	_virtual_keyboard.anchor_left = 0.5
	_virtual_keyboard.anchor_right = 0.5
	_virtual_keyboard.anchor_top = 1.0
	_virtual_keyboard.anchor_bottom = 1.0
	_virtual_keyboard.offset_left = -280
	_virtual_keyboard.offset_right = 280
	_virtual_keyboard.offset_top = -210
	_virtual_keyboard.offset_bottom = -16
	add_child(_virtual_keyboard)
	_virtual_keyboard.attach(chat_line_edit)
	_virtual_keyboard.closed.connect(_on_virtual_keyboard_closed)


func _build_left_column(root: HBoxContainer) -> void:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)

	var portrait_wrapper := PanelContainer.new()
	portrait_wrapper.custom_minimum_size = Vector2(190, 190)
	portrait_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var portrait_sb := StyleBoxFlat.new()
	portrait_sb.bg_color = Color(0.12, 0.09, 0.06, 0.7)
	portrait_sb.border_width_left = 2
	portrait_sb.border_width_top = 2
	portrait_sb.border_width_right = 2
	portrait_sb.border_width_bottom = 2
	portrait_sb.border_color = Color(0.6, 0.45, 0.25, 0.9)
	portrait_sb.corner_radius_top_left = 8
	portrait_sb.corner_radius_top_right = 8
	portrait_sb.corner_radius_bottom_left = 8
	portrait_sb.corner_radius_bottom_right = 8
	portrait_sb.set_content_margin_all(0)
	portrait_wrapper.add_theme_stylebox_override("panel", portrait_sb)
	left.add_child(portrait_wrapper)

	_portrait_color = ColorRect.new()
	_portrait_color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_color.color = Color(0.18, 0.13, 0.08, 1.0)
	portrait_wrapper.add_child(_portrait_color)

	_portrait_rect = TextureRect.new()
	_portrait_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_rect.visible = false
	portrait_wrapper.add_child(_portrait_rect)

	_portrait_initial = Label.new()
	_portrait_initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_initial.add_theme_font_size_override("font_size", 64)
	_portrait_initial.modulate = Color(0.85, 0.68, 0.38, 0.7)
	portrait_wrapper.add_child(_portrait_initial)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.text = "NPC"
	left.add_child(_name_label)

	var top_sep := ColorRect.new()
	top_sep.custom_minimum_size = Vector2(0, 1)
	top_sep.color = Color(0.6, 0.47, 0.28, 0.5)
	left.add_child(top_sep)

	# Portre + isim sabit kalır; altındaki bilgiler + günlük tek bir kaydırılabilir alanda —
	# oyuncu tek pencerede her şeyi (yaş/cinsiyet, eski/şimdiki meslek, ruh hali, sağlık, ve
	# yaşadığı önemli olaylar) sekme değiştirmeden görebilsin diye.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	scroll.add_child(inner)

	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.add_theme_font_size_override("font_size", 12)
	inner.add_child(_stats_label)

	var diary_sep := ColorRect.new()
	diary_sep.custom_minimum_size = Vector2(0, 1)
	diary_sep.color = Color(0.6, 0.47, 0.28, 0.5)
	inner.add_child(diary_sep)

	var diary_title := Label.new()
	diary_title.text = "📖 Günlük"
	diary_title.add_theme_font_size_override("font_size", 13)
	inner.add_child(diary_title)

	_diary_empty_label = Label.new()
	_diary_empty_label.text = "Henüz kayda değer bir hikâyesi yok."
	_diary_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diary_empty_label.add_theme_font_size_override("font_size", 11)
	_diary_empty_label.modulate = Color(1, 1, 1, 0.55)
	_diary_empty_label.visible = false
	inner.add_child(_diary_empty_label)

	_diary_vbox = VBoxContainer.new()
	_diary_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diary_vbox.add_theme_constant_override("separation", 4)
	inner.add_child(_diary_vbox)

	_diary_scroll = scroll


func _build_right_column(root: HBoxContainer) -> void:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)

	var title := Label.new()
	title.text = "Sohbet"
	title.add_theme_font_size_override("font_size", 15)
	right.add_child(title)

	chat_scroll = ScrollContainer.new()
	chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(chat_scroll)

	chat_vbox = VBoxContainer.new()
	chat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_scroll.add_child(chat_vbox)

	# Sohbet her zaman en son mesaja odaklı kalsın — kaydırma çubuğu her büyüdüğünde (yeni
	# mesaj, pencere yeniden açılıp geçmiş yeniden çizildiğinde vb.) otomatik en alta atlar.
	# Kontrolcü/klavye ile yukarı kaydırıp okumak yerine hep "canlı sohbete" odaklanmayı tercih
	# ediyoruz.
	chat_scroll.get_v_scroll_bar().changed.connect(_snap_chat_scroll_to_bottom)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	right.add_child(input_row)

	chat_line_edit = LineEdit.new()
	chat_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_line_edit.placeholder_text = "Mesajınızı yazın..."
	input_row.add_child(chat_line_edit)

	send_button = Button.new()
	send_button.text = "Gönder"
	input_row.add_child(send_button)

	_nav_hint_label = Label.new()
	_nav_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_nav_hint_label.add_theme_font_size_override("font_size", 10)
	_nav_hint_label.modulate = Color(1, 1, 1, 0.45)
	right.add_child(_nav_hint_label)
	_update_nav_hint()


# ─── Info panel / portrait ─────────────────────────────────────────────────────

func _refresh_info_panel() -> void:
	if NpcInfo == null:
		return
	var info: Dictionary = NpcInfo.get("Info", {}) if NpcInfo is Dictionary else {}
	var name_str := str(info.get("Name", "?"))
	_name_label.text = name_str
	_portrait_initial.text = name_str.substr(0, 1).to_upper() if not name_str.is_empty() else "?"

	var age_gender: PackedStringArray = []
	var age := str(info.get("Age", "")).strip_edges()
	if age != "":
		age_gender.append("%s yaş" % age)
	var gender_tr := _translate_gender(str(info.get("Gender", "")))
	if gender_tr != "":
		age_gender.append(gender_tr)

	var lines: PackedStringArray = []
	if not age_gender.is_empty():
		lines.append("  •  ".join(age_gender))
	var occupation := str(info.get("Occupation", "")).strip_edges()
	if occupation != "":
		lines.append("Eskiden: %s" % occupation)
	lines.append("Şu an: %s" % _resolve_workplace())
	var mood := str(info.get("Mood", "")).strip_edges()
	if mood != "":
		lines.append("Ruh hali: %s" % mood)
	var health := str(info.get("Health", "")).strip_edges()
	if health != "":
		lines.append("Sağlık: %s" % health)
	_stats_label.text = "\n".join(lines)


func _translate_gender(g: String) -> String:
	match g:
		"Male":
			return "Erkek"
		"Female":
			return "Kadın"
		_:
			return g


func _resolve_workplace() -> String:
	if _owner_npc == null or not is_instance_valid(_owner_npc):
		return "Boşta"
	if "assigned_job_type" in _owner_npc and str(_owner_npc.get("assigned_job_type")) == "soldier":
		return "Asker"
	if "assigned_building_node" in _owner_npc:
		var building = _owner_npc.get("assigned_building_node")
		if building != null and is_instance_valid(building):
			var vm := get_node_or_null("/root/VillageManager")
			if vm and vm.has_method("get_building_display_name_for_scene"):
				return str(vm.get_building_display_name_for_scene(building.scene_file_path))
			return str(building.name)
	return "Boşta"


func _refresh_portrait() -> void:
	_portrait_generation += 1
	var gen := _portrait_generation
	var has_appearance := _owner_npc != null and is_instance_valid(_owner_npc) \
		and "appearance" in _owner_npc and _owner_npc.get("appearance") != null
	if not has_appearance:
		_NpcPortraitRenderer.clear(_portrait_rect)
		_portrait_rect.visible = false
		_portrait_initial.visible = true
		return
	_portrait_initial.visible = false
	_portrait_rect.visible = true
	_NpcPortraitRenderer.render(
		_portrait_rect,
		_owner_npc,
		self,
		func() -> bool: return gen != _portrait_generation or not visible
	)


# ─── Public API (called by Worker.gd) ──────────────────────────────────────────

func InitializeWindow(Info):
	NpcInfo = Info
	_pending_player_turns.clear()
	_ensure_npc_auxiliary_fields(NpcInfo)
	refresh_diary_from_npcinfo()
	_rebuild_dialogue_ui_from_chat_log()
	_refresh_info_panel()
	print("INITIALIZED WORKER")
	print("WindowInfo: ", Info)


func _ensure_npc_auxiliary_fields(info: Dictionary) -> void:
	if not info.has("Chat_log") or typeof(info["Chat_log"]) != TYPE_ARRAY:
		info["Chat_log"] = []
	info.erase("History_summary")


func refresh_diary_from_npcinfo() -> void:
	if NpcInfo == null or not is_instance_valid(_diary_vbox):
		return
	for child in _diary_vbox.get_children():
		_diary_vbox.remove_child(child)
		child.queue_free()
	var history: Array = NpcInfo.get("History", [])
	_diary_empty_label.visible = history.is_empty()
	for item in history:
		var historylabel := Label.new()
		_diary_vbox.add_child(historylabel)
		historylabel.autowrap_mode = TextServer.AUTOWRAP_WORD
		historylabel.add_theme_font_size_override("font_size", 11)
		historylabel.text = "• %s" % str(item)


func NPCDialogueProcessed(npc_name: String, new_state: Dictionary, generated_dialogue: String, was_significant: bool):
	_hide_thinking_indicator()
	NpcInfo = new_state
	_ensure_npc_auxiliary_fields(NpcInfo)
	if _owner_npc:
		_owner_npc.NPC_Info = new_state
		_owner_npc.Update_Villager_Name()
	# Chat_log already includes NPC line from NPCDialogueManager; resync UI.
	# animate_last_npc_line=true: the fresh reply reveals letter by letter instead of popping in.
	_rebuild_dialogue_ui_from_chat_log(true)
	_scroll_chat_to_bottom()
	refresh_diary_from_npcinfo()
	_refresh_info_panel()
	_try_dispatch_pending_or_enable_send()


# ─── Chat log rendering ──────────────────────────────────────────────────────

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
	TextOutline.apply_to_tree(chat_vbox)


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
	text = text.replace("\n", " ").replace("\r", " ").replace("\t", " ")
	var regex = RegEx.new()
	regex.compile("\\s+")
	text = regex.sub(text, " ")
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


func _scroll_chat_to_bottom() -> void:
	await get_tree().process_frame
	_snap_chat_scroll_to_bottom()


## v_scroll_bar.changed sinyaline bağlı — kaydırma aralığı her büyüdüğünde (yeni satır eklendi,
## pencere yeniden açılıp geçmiş yeniden çizildi vb.) anında en alta sabitler.
func _snap_chat_scroll_to_bottom() -> void:
	if is_instance_valid(chat_scroll) and chat_scroll.get_v_scroll_bar():
		chat_scroll.scroll_vertical = chat_scroll.get_v_scroll_bar().max_value


# ─── Virtual keyboard (gamepad text entry) ─────────────────────────────────────

func _on_input_device_changed(_is_joypad: bool) -> void:
	_update_nav_hint()
	_sync_virtual_keyboard_visibility()


func _sync_virtual_keyboard_visibility() -> void:
	if not is_instance_valid(_virtual_keyboard):
		return
	var want_open := visible and InputManager.last_input_from_joypad
	if want_open and not _virtual_keyboard.visible:
		_virtual_keyboard.open_keyboard()
	elif not want_open and _virtual_keyboard.visible:
		_virtual_keyboard.close_keyboard()


func _on_virtual_keyboard_closed() -> void:
	if is_instance_valid(chat_line_edit):
		chat_line_edit.grab_focus()


# ─── Close / input ──────────────────────────────────────────────────────────────

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	if _owner_npc and _owner_npc.has_method("CloseNpcWindow"):
		_owner_npc.CloseNpcWindow()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if is_instance_valid(_virtual_keyboard) and _virtual_keyboard.visible:
		return
	if InputManager.is_ui_cancel_pressed():
		get_viewport().set_input_as_handled()
		_on_close_button_pressed()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_PAGEUP:
			chat_scroll.scroll_vertical -= 200
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_PAGEDOWN:
			chat_scroll.scroll_vertical += 200
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or not InputManager.last_input_from_joypad:
		return
	if is_instance_valid(_virtual_keyboard) and _virtual_keyboard.visible:
		return
	if not is_instance_valid(chat_scroll):
		return
	var dir := 0.0
	if InputManager.is_ui_down_pressed():
		dir += 1.0
	if InputManager.is_ui_up_pressed():
		dir -= 1.0
	if dir != 0.0:
		chat_scroll.scroll_vertical += int(dir * 900.0 * delta)


func _update_nav_hint() -> void:
	if _nav_hint_label == null:
		return
	_nav_hint_label.text = "[%s] Kapat" % InputManager.get_tutorial_cancel_hint()
