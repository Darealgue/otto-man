extends Control
class_name VirtualKeyboardUI
## Gamepad ile bir LineEdit'e metin yazmak için basit ekran üstü klavye.
## Gerçek OS/metin fokusu her zaman hedef LineEdit'te kalır (imleç orada yanıp söner);
## bu bileşen sadece kendi görsel imlecini (row/col) InputManager ui_* aksiyonlarıyla gezdirir
## ve seçili tuşu ui_accept ile "basar".

signal closed

const _KEY_ROWS: Array = [
	["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
	["q", "w", "e", "r", "t", "y", "u", "ı", "o", "p"],
	["a", "s", "d", "f", "g", "h", "j", "k", "l", "ş"],
	["z", "x", "c", "v", "b", "n", "m", "ö", "ü", "ç"],
]

var _target: LineEdit = null
var _key_buttons: Array = [] # Array[Array[Button]]
var _action_row: Array = []  # [space_btn, backspace_btn, send_btn]
var _cursor_row: int = 0
var _cursor_col: int = 0
var _in_action_row: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()


func attach(line_edit: LineEdit) -> void:
	_target = line_edit


func open_keyboard() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	visible = true
	_cursor_row = 0
	_cursor_col = 0
	_in_action_row = false
	_refresh_cursor_style()


func close_keyboard() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


# ─── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var panel := PanelContainer.new()
	ParchmentTextures.apply_compact_panel_style(panel, 10)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	for row in _KEY_ROWS:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(hbox)
		var btn_row: Array = []
		for ch in row:
			var btn := _make_key_button(str(ch), 32)
			hbox.add_child(btn)
			btn_row.append(btn)
		_key_buttons.append(btn_row)

	var action_hbox := HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 6)
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(action_hbox)

	var space_btn := _make_key_button("Boşluk", 140)
	var backspace_btn := _make_key_button("⌫", 60)
	var send_btn := _make_key_button("Gönder ✓", 100)
	action_hbox.add_child(space_btn)
	action_hbox.add_child(backspace_btn)
	action_hbox.add_child(send_btn)
	_action_row = [space_btn, backspace_btn, send_btn]

	var hint := Label.new()
	hint.text = "[Yön] Gez   [A] Seç   [B] Klavyeyi kapat"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(1, 1, 1, 0.55)
	vbox.add_child(hint)

	TextOutline.apply_to_tree(self)


func _make_key_button(label_text: String, min_w: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(min_w, 34)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_key_activated.bind(btn))
	return btn


# ─── Key activation ───────────────────────────────────────────────────────────

func _on_key_activated(btn: Button) -> void:
	match btn.text:
		"Boşluk":
			_insert(" ")
		"⌫":
			_backspace()
		"Gönder ✓":
			_send()
		_:
			_insert(btn.text)


func _insert(s: String) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_target.insert_text_at_caret(s)


func _backspace() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_target.delete_char_at_caret()


func _send() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_target.text_submitted.emit(_target.text)


# ─── Navigation ───────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if InputManager.is_ui_cancel_pressed():
		get_viewport().set_input_as_handled()
		close_keyboard()
		return
	if InputManager.is_ui_accept_just_pressed():
		get_viewport().set_input_as_handled()
		_activate_cursor()
		return
	if InputManager.is_ui_left_just_pressed():
		get_viewport().set_input_as_handled()
		_move_cursor(0, -1)
		return
	if InputManager.is_ui_right_just_pressed():
		get_viewport().set_input_as_handled()
		_move_cursor(0, 1)
		return
	if InputManager.is_ui_up_just_pressed():
		get_viewport().set_input_as_handled()
		_move_cursor(-1, 0)
		return
	if InputManager.is_ui_down_just_pressed():
		get_viewport().set_input_as_handled()
		_move_cursor(1, 0)
		return


func _activate_cursor() -> void:
	var btn := _current_button()
	if btn:
		btn.pressed.emit()


func _current_button() -> Button:
	if _in_action_row:
		if _cursor_col >= 0 and _cursor_col < _action_row.size():
			return _action_row[_cursor_col]
		return null
	if _cursor_row >= 0 and _cursor_row < _key_buttons.size():
		var row: Array = _key_buttons[_cursor_row]
		if _cursor_col >= 0 and _cursor_col < row.size():
			return row[_cursor_col]
	return null


func _move_cursor(d_row: int, d_col: int) -> void:
	if d_row != 0:
		if _in_action_row and d_row < 0:
			_in_action_row = false
			_cursor_row = _key_buttons.size() - 1
			_cursor_col = mini(_cursor_col, _key_buttons[_cursor_row].size() - 1)
		elif not _in_action_row and d_row > 0 and _cursor_row == _key_buttons.size() - 1:
			_in_action_row = true
			_cursor_col = 0
		elif not _in_action_row:
			_cursor_row = clampi(_cursor_row + d_row, 0, _key_buttons.size() - 1)
			_cursor_col = mini(_cursor_col, _key_buttons[_cursor_row].size() - 1)
	elif d_col != 0:
		var count: int = _action_row.size() if _in_action_row else _key_buttons[_cursor_row].size()
		_cursor_col = wrapi(_cursor_col + d_col, 0, count)
	_refresh_cursor_style()


func _refresh_cursor_style() -> void:
	for row in _key_buttons:
		for btn in row:
			(btn as Button).remove_theme_stylebox_override("normal")
	for btn in _action_row:
		(btn as Button).remove_theme_stylebox_override("normal")
	var current := _current_button()
	if current == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.22, 0.1, 0.9)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.85, 0.35, 1.0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	current.add_theme_stylebox_override("normal", sb)
