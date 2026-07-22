extends Node

##
# Merkezi input yöneticisi.
# Tüm tuş sorguları buradan yapılır ki klavye ve gamepad eşit davranış göstersin.
#
# Notlar:
# - Fonksiyonlar kısa süreli olarak sadece InputMap'teki aksiyonları wrap eder,
#   fakat alias sistemini kullanarak bir mantıksal aksiyon birden fazla fiziksel
#   aksiyonu tetikleyebilir.
# - İleride kullanıcı tabanlı tuş ataması ve cihaz takibi eklemek için hazırdır.
##

signal input_device_changed(is_joypad: bool)

const SETTINGS_PATH := "user://settings.cfg"

const PRESET_WASD_NUMPAD := StringName("wasd_numpad")
const PRESET_ARROWS_QWEASD := StringName("arrows_qweasd")

# Mantıksal aksiyon -> InputMap aksiyon listesi
static var _ACTION_GROUPS := {
	StringName("ui_up"): [StringName("ui_up"), StringName("up")],
	StringName("ui_down"): [StringName("ui_down"), StringName("down")],
	StringName("ui_left"): [StringName("ui_left"), StringName("left")],
	StringName("ui_right"): [StringName("ui_right"), StringName("right")],
	StringName("ui_accept"): [StringName("ui_accept"), StringName("ui_forward")],
	StringName("ui_cancel"): [StringName("ui_cancel"), StringName("ui_back")],
	StringName("ui_select"): [StringName("ui_select")],
	StringName("ui_page_left"): [StringName("ui_page_left"), StringName("l2_trigger")],
	StringName("ui_page_right"): [StringName("ui_page_right"), StringName("r2_trigger")],
	StringName("portal_enter"): [StringName("portal_enter"), StringName("ui_up"), StringName("interact")],
	StringName("interact"): [StringName("interact"), StringName("ui_accept"), StringName("ui_forward")],
	StringName("move_left"): [StringName("move_left"), StringName("left")],
	StringName("move_right"): [StringName("move_right"), StringName("right")],
	StringName("move_up"): [StringName("up")],
	StringName("move_down"): [StringName("down")],
	StringName("jump"): [StringName("jump")],
	StringName("dash"): [StringName("dash")],
	StringName("attack"): [StringName("attack")],
	StringName("attack_heavy"): [StringName("attack_heavy")],
	StringName("block"): [StringName("block")],
}

const _KEYBOARD_PRESETS := {
	PRESET_WASD_NUMPAD: {
		StringName("move_left"): [KEY_A],
		StringName("move_right"): [KEY_D],
		StringName("move_up"): [KEY_W],
		StringName("move_down"): [KEY_S],
		StringName("left"): [KEY_A],
		StringName("right"): [KEY_D],
		StringName("up"): [KEY_W],
		StringName("down"): [KEY_S],
		StringName("ui_left"): [KEY_A],
		StringName("ui_right"): [KEY_D],
		StringName("ui_up"): [KEY_W],
		StringName("ui_down"): [KEY_S],
		StringName("jump"): [KEY_SPACE],
		StringName("dash"): [KEY_SHIFT],
		StringName("attack"): [KEY_KP_4],
		StringName("attack_heavy"): [KEY_KP_5],
		StringName("block"): [KEY_KP_6],
		StringName("ui_page_left"): [KEY_KP_7],
		StringName("ui_page_right"): [KEY_KP_9],
		StringName("interact"): [KEY_KP_8],
		StringName("crouch"): [KEY_S],
	},
	PRESET_ARROWS_QWEASD: {
		StringName("move_left"): [KEY_LEFT, KEY_KP_4],
		StringName("move_right"): [KEY_RIGHT, KEY_KP_6],
		StringName("move_up"): [KEY_UP, KEY_KP_8],
		StringName("move_down"): [KEY_DOWN, KEY_KP_5],
		StringName("left"): [KEY_LEFT, KEY_KP_4],
		StringName("right"): [KEY_RIGHT, KEY_KP_6],
		StringName("up"): [KEY_UP, KEY_KP_8],
		StringName("down"): [KEY_DOWN, KEY_KP_5],
		StringName("ui_left"): [KEY_LEFT, KEY_KP_4],
		StringName("ui_right"): [KEY_RIGHT, KEY_KP_6],
		StringName("ui_up"): [KEY_UP, KEY_KP_8],
		StringName("ui_down"): [KEY_DOWN, KEY_KP_5],
		StringName("jump"): [KEY_SPACE],
		StringName("dash"): [KEY_SHIFT],
		StringName("attack"): [KEY_A],
		StringName("attack_heavy"): [KEY_S],
		StringName("block"): [KEY_D],
		StringName("ui_page_left"): [KEY_Q],
		StringName("ui_page_right"): [KEY_E],
		StringName("interact"): [KEY_W],
		StringName("crouch"): [KEY_DOWN, KEY_KP_5],
	},
}

static var _current_keyboard_preset: StringName = PRESET_WASD_NUMPAD
## Tutorial metinleri: son anlamlı girdi gamepad mi (stick/d-pad) klavye mi.
var last_input_from_joypad: bool = false

## Oyun tamamen klavye/gamepad ile oynanıyor; mouse imleci hiç görünmesin ve
## hiçbir şeye tıklamak için kullanılamasın.
func _ready() -> void:
	_load_keyboard_preset_from_disk()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Tıklamaları UI/oyun mantığına ulaşmadan tamamen yut.
		get_viewport().set_input_as_handled()
		return
	var was_joypad := last_input_from_joypad
	if event is InputEventJoypadButton:
		if event.pressed:
			last_input_from_joypad = true
	elif event is InputEventJoypadMotion:
		if abs(event.axis_value) > 0.35:
			last_input_from_joypad = true
	elif event is InputEventKey and event.pressed:
		last_input_from_joypad = false
	if was_joypad != last_input_from_joypad:
		input_device_changed.emit(last_input_from_joypad)

# -- Genel yardımcılar -------------------------------------------------------------------------

static func is_pressed(logical_action: StringName) -> bool:
	return _query_action_group(logical_action, _QueryType.PRESSED)

static func is_just_pressed(logical_action: StringName) -> bool:
	return _query_action_group(logical_action, _QueryType.JUST_PRESSED)

static func is_just_released(logical_action: StringName) -> bool:
	return _query_action_group(logical_action, _QueryType.JUST_RELEASED)

enum _QueryType { PRESSED, JUST_PRESSED, JUST_RELEASED }

static func _query_action_group(logical_action: StringName, query_type: _QueryType) -> bool:
	if not _ACTION_GROUPS.has(logical_action):
		# Aksiyon tanımlı değilse direkt InputMap'te aramayı dene
		if InputMap.has_action(logical_action):
			return _query_single_action(logical_action, query_type)
		return false
	
	for action_name in _ACTION_GROUPS[logical_action]:
		if _query_single_action(action_name, query_type):
			return true
	return false

static func _query_single_action(action_name: StringName, query_type: _QueryType) -> bool:
	if not InputMap.has_action(action_name):
		return false
	match query_type:
		_QueryType.PRESSED:
			return Input.is_action_pressed(action_name)
		_QueryType.JUST_PRESSED:
			return Input.is_action_just_pressed(action_name)
		_QueryType.JUST_RELEASED:
			return Input.is_action_just_released(action_name)
	return false

static func _get_physical_actions(logical_action: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if _ACTION_GROUPS.has(logical_action):
		for action_name in _ACTION_GROUPS[logical_action]:
			result.append(action_name as StringName)
	else:
		result.append(logical_action)
	return result

static func _get_combined_action_strength(logical_action: StringName) -> float:
	var actions := _get_physical_actions(logical_action)
	var strength := 0.0
	for action_name in actions:
		if not InputMap.has_action(action_name):
			continue
		strength = max(strength, Input.get_action_strength(action_name))
	return strength

static func get_flattened_axis(negative_action: StringName, positive_action: StringName, deadzone: float = 0.2) -> float:
	var negative_pressed := is_pressed(negative_action)
	var positive_pressed := is_pressed(positive_action)
	
	if negative_pressed and not positive_pressed:
		return -1.0
	if positive_pressed and not negative_pressed:
		return 1.0
	if negative_pressed and positive_pressed:
		return 0.0
	
	var negative_strength := _get_combined_action_strength(negative_action)
	var positive_strength := _get_combined_action_strength(positive_action)
	var axis_value := positive_strength - negative_strength
	if abs(axis_value) < deadzone:
		return 0.0
	return 1.0 if axis_value > 0.0 else -1.0

# -- UI kısayollar -----------------------------------------------------------------------------

static func is_ui_up_pressed() -> bool:
	return is_pressed(&"ui_up")

static func is_ui_up_just_pressed() -> bool:
	return is_just_pressed(&"ui_up")

static func is_ui_down_pressed() -> bool:
	return is_pressed(&"ui_down")

static func is_ui_down_just_pressed() -> bool:
	return is_just_pressed(&"ui_down")

static func is_ui_left_pressed() -> bool:
	return is_pressed(&"ui_left")

static func is_ui_left_just_pressed() -> bool:
	return is_just_pressed(&"ui_left")

static func is_ui_right_pressed() -> bool:
	return is_pressed(&"ui_right")

static func is_ui_right_just_pressed() -> bool:
	return is_just_pressed(&"ui_right")

static func is_ui_accept_pressed() -> bool:
	return is_pressed(&"ui_accept")

static func is_ui_accept_just_pressed() -> bool:
	return is_just_pressed(&"ui_accept")

static func is_ui_cancel_pressed() -> bool:
	return is_pressed(&"ui_cancel")

static func is_ui_cancel_just_pressed() -> bool:
	return is_just_pressed(&"ui_cancel")

static func is_ui_select_pressed() -> bool:
	return is_pressed(&"ui_select")

static func is_ui_select_just_pressed() -> bool:
	return is_just_pressed(&"ui_select")

static func is_ui_page_left_pressed() -> bool:
	return is_pressed(&"ui_page_left")

static func is_ui_page_left_just_pressed() -> bool:
	return is_just_pressed(&"ui_page_left")

static func is_ui_page_right_pressed() -> bool:
	return is_pressed(&"ui_page_right")

static func is_ui_page_right_just_pressed() -> bool:
	return is_just_pressed(&"ui_page_right")

# -- Portal / Etkileşim ------------------------------------------------------------------------

static func is_portal_enter_pressed() -> bool:
	return is_pressed(&"portal_enter")

static func is_portal_enter_just_pressed() -> bool:
	return is_just_pressed(&"portal_enter")

static func is_interact_pressed() -> bool:
	return is_pressed(&"interact")

static func is_interact_just_pressed() -> bool:
	return is_just_pressed(&"interact")

# -- Oyun aksiyonları --------------------------------------------------------------------------

static func is_move_left_pressed() -> bool:
	return is_pressed(&"move_left")

static func is_move_right_pressed() -> bool:
	return is_pressed(&"move_right")

static func is_move_up_pressed() -> bool:
	return is_pressed(&"move_up")

static func is_move_down_pressed() -> bool:
	return is_pressed(&"move_down")

static func is_jump_pressed() -> bool:
	return is_pressed(&"jump")

static func is_jump_just_pressed() -> bool:
	return is_just_pressed(&"jump")

static func is_dash_pressed() -> bool:
	return is_pressed(&"dash")

static func is_dash_just_pressed() -> bool:
	return is_just_pressed(&"dash")

static func is_attack_pressed() -> bool:
	return is_pressed(&"attack")

static func is_attack_just_pressed() -> bool:
	return is_just_pressed(&"attack")

static func is_heavy_attack_pressed() -> bool:
	return is_pressed(&"attack_heavy")

static func is_heavy_attack_just_pressed() -> bool:
	return is_just_pressed(&"attack_heavy")

static func is_block_pressed() -> bool:
	return is_pressed(&"block")

static func is_block_just_pressed() -> bool:
	return is_just_pressed(&"block")

# -- Yardımcı API ------------------------------------------------------------------------------

## Event'in belirtilen mantıksal aksiyona ait olup olmadığını kontrol eder
## _input() callback'lerinde kullanım için
static func is_event_action(event: InputEvent, logical_action: StringName) -> bool:
	if not event:
		return false
	
	# Mantıksal aksiyonun fiziksel aksiyonlarını al
	var actions_to_check: Array[StringName] = []
	if _ACTION_GROUPS.has(logical_action):
		var source_array = _ACTION_GROUPS[logical_action]
		for action in source_array:
			actions_to_check.append(action as StringName)
	else:
		actions_to_check = [logical_action]
	
	# Event'in bu aksiyonlardan herhangi birine ait olup olmadığını kontrol et
	for action_name in actions_to_check:
		if event.is_action(action_name):
			return true
	
	return false

## Event'in belirtilen mantıksal aksiyon için basılı olup olmadığını kontrol eder
## _input() callback'lerinde kullanım için
## Not: Analog stick event'leri (InputEventJoypadMotion) için pressed kontrolü yapılmaz
static func is_event_action_pressed(event: InputEvent, logical_action: StringName) -> bool:
	if not event:
		return false
	
	# Analog stick event'leri için pressed kontrolü yapma (bunların pressed property'si yok)
	if event is InputEventJoypadMotion:
		return is_event_action(event, logical_action)
	# Mouse hareketi event'lerinde pressed özelliği yok, aksiyon tetiklemesin
	if event is InputEventMouseMotion:
		return false
	
	# Diğer event tipleri için (keyboard, gamepad button) pressed kontrolü yap
	if not event.pressed:
		return false
	
	return is_event_action(event, logical_action)

static func add_alias(logical_action: StringName, physical_action: StringName) -> void:
	# Runtime'da yeni alias eklemek için kullanılabilir (örn. tuş atama menüsü)
	if not _ACTION_GROUPS.has(logical_action):
		_ACTION_GROUPS[logical_action] = []
	if physical_action not in _ACTION_GROUPS[logical_action]:
		_ACTION_GROUPS[logical_action].append(physical_action)

static func remove_alias(logical_action: StringName, physical_action: StringName) -> void:
	if not _ACTION_GROUPS.has(logical_action):
		return
	_ACTION_GROUPS[logical_action].erase(physical_action)

# -- Tuş İsimleri (Menü Yardımcı Yazıları İçin) -----------------------------------------

## Bir aksiyon için kullanıcı dostu tuş ismini döndürür
## Öncelik sırası: Klavye tuşu > Gamepad tuşu
static func get_action_key_name(logical_action: StringName) -> String:
	var actions_to_check: Array[StringName] = []
	
	# Mantıksal aksiyonun fiziksel aksiyonlarını al
	if _ACTION_GROUPS.has(logical_action):
		var source_array = _ACTION_GROUPS[logical_action]
		# Tip güvenli kopyalama
		for action in source_array:
			actions_to_check.append(action as StringName)
	else:
		actions_to_check = [logical_action]
	
	# Her fiziksel aksiyon için InputMap'te ara
	for action_name in actions_to_check:
		if not InputMap.has_action(action_name):
			continue
		
		var events = InputMap.action_get_events(action_name)
		# Önce klavye tuşu ara
		for event in events:
			if event is InputEventKey:
				return _get_key_name(event as InputEventKey)
		
		# Klavye yoksa gamepad tuşu ara
		for event in events:
			if event is InputEventJoypadButton:
				return _get_joypad_button_name(event as InputEventJoypadButton)
			elif event is InputEventJoypadMotion:
				return _get_joypad_axis_name(event as InputEventJoypadMotion)
	
	# Hiçbir şey bulunamazsa aksiyon adını döndür
	return str(logical_action)

## Klavye tuşu için isim döndürür
static func _get_key_name(event: InputEventKey) -> String:
	var keycode = event.keycode
	if keycode == 0:
		keycode = event.physical_keycode
	
	# Özel tuşlar
	match keycode:
		KEY_SPACE: return "Space"
		KEY_ENTER: return "Enter"
		KEY_KP_ENTER: return "Num Enter"
		KEY_ESCAPE: return "ESC"
		KEY_TAB: return "Tab"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_KP_0: return "Num 0"
		KEY_KP_1: return "Num 1"
		KEY_KP_2: return "Num 2"
		KEY_KP_3: return "Num 3"
		KEY_KP_4: return "Num 4"
		KEY_KP_5: return "Num 5"
		KEY_KP_6: return "Num 6"
		KEY_KP_7: return "Num 7"
		KEY_KP_8: return "Num 8"
		KEY_KP_9: return "Num 9"
		_: 
			# Harf ve sayı tuşları için
			var key_string = OS.get_keycode_string(keycode)
			if key_string != "":
				return key_string.to_upper()
			return "Key " + str(keycode)

## Gamepad butonu için isim döndürür
static func _get_joypad_button_name(event: InputEventJoypadButton) -> String:
	match event.button_index:
		0: return "A"
		1: return "B"
		2: return "X"
		3: return "Y"
		4: return "Back"
		5: return "Guide"
		6: return "Start"
		7: return "L3"
		8: return "R3"
		9: return "LB"
		10: return "RB"
		# Kısa ok glifi (bkz. _tutorial_joy_button_short) — HUD ipuçlarında "D-Pad Up" gibi
		# uzun metin yerine sadece ok görünsün.
		11: return "↑"
		12: return "↓"
		13: return "←"
		14: return "→"
		_: return "Button " + str(event.button_index)

## Gamepad axis için isim döndürür
static func _get_joypad_axis_name(event: InputEventJoypadMotion) -> String:
	var axis_name := ""
	match event.axis:
		0: axis_name = "Left Stick X"
		1: axis_name = "Left Stick Y"
		2: axis_name = "Right Stick X"
		3: axis_name = "Right Stick Y"
		4: axis_name = "Left Trigger"
		5: axis_name = "Right Trigger"
		_: axis_name = "Axis " + str(event.axis)
	
	if event.axis_value < -0.5:
		axis_name += " (-)"
	elif event.axis_value > 0.5:
		axis_name += " (+)"
	
	return axis_name

## Özel aksiyonlar için kısayollar
static func get_accept_key_name() -> String:
	return get_action_key_name(&"ui_accept")

static func get_cancel_key_name() -> String:
	return get_action_key_name(&"ui_cancel")

static func get_jump_key_name() -> String:
	return get_action_key_name(&"jump")

static func get_dash_key_name() -> String:
	return get_action_key_name(&"dash")

static func get_interact_key_name() -> String:
	return get_action_key_name(&"interact")

# -- Keyboard Preset Yönetimi -----------------------------------------------------------------

static func apply_keyboard_preset(preset: StringName) -> void:
	if not _KEYBOARD_PRESETS.has(preset):
		push_warning("[InputManager] Unknown keyboard preset: %s" % str(preset))
		return
	for action_name in _KEYBOARD_PRESETS[preset].keys():
		_replace_action_keys(action_name, _KEYBOARD_PRESETS[preset][action_name])
	_current_keyboard_preset = preset

static func get_current_keyboard_preset() -> StringName:
	return _current_keyboard_preset

static func get_available_keyboard_presets() -> Array[StringName]:
	return _KEYBOARD_PRESETS.keys()

static func _replace_action_keys(action: StringName, keycodes: Array) -> void:
	if not InputMap.has_action(action):
		push_warning("[InputManager] Action not found: %s" % str(action))
		return
	var events = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	for keycode in keycodes:
		if typeof(keycode) != TYPE_INT:
			continue
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.keycode = keycode
		InputMap.action_add_event(action, event)

static func _load_keyboard_preset_from_disk() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err == OK:
		var preset_value = config.get_value("controls", "preset", PRESET_WASD_NUMPAD)
		var preset_name: String = preset_value if preset_value is String else str(preset_value)
		var preset := StringName(preset_name)
		if _KEYBOARD_PRESETS.has(preset):
			apply_keyboard_preset(preset)
			_current_keyboard_preset = preset
		else:
			apply_keyboard_preset(PRESET_WASD_NUMPAD)
	else:
		apply_keyboard_preset(PRESET_WASD_NUMPAD)


# -- Tutorial ipuçları --------------------------------------------------------------------------

const TUTORIAL_KEY_HINT_COLOR := "#a85a00"
const TUTORIAL_TITLE_COLOR := "#3d2008"


static func wrap_tutorial_hint_text(text: String) -> String:
	if text.is_empty():
		return text
	return "[b][color=%s]%s[/color][/b]" % [TUTORIAL_KEY_HINT_COLOR, text]


static func format_tutorial_title(text: String) -> String:
	return "[b][color=%s]%s[/color][/b]" % [TUTORIAL_TITLE_COLOR, text]

static func _tutorial_physical_action_names(logical: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if _ACTION_GROUPS.has(logical):
		for a in _ACTION_GROUPS[logical]:
			out.append(a as StringName)
	else:
		out.append(logical)
	return out


static func _tutorial_joy_button_short(btn_idx: int) -> String:
	match btn_idx:
		0: return "A"
		1: return "B"
		2: return "X"
		3: return "Y"
		4: return "Back"
		5: return "Guide"
		6: return "Start"
		7: return "L3"
		8: return "R3"
		9: return "LB"
		10: return "RB"
		11: return "↑"
		12: return "↓"
		13: return "←"
		14: return "→"
		_: return "B%d" % btn_idx


static func _tutorial_joy_motion_hint(axis: int, axis_value: float) -> String:
	var av := absf(axis_value)
	if av < 0.25:
		return ""
	match axis:
		0:
			return "← / →"
		1:
			if axis_value > 0.0:
				return "↓"
			return "↑"
		_:
			return ""


## Gamepad gösterimi: InputMap'te ilk event bazen sol çubuk / yanlış eksen oluyor — mod ile düzelt.
## İndeksler `_tutorial_joy_button_short` ile uyumlu (Godot 4: 9/10 LB/RB, 11–14 D-pad).
static func _tutorial_joypad_glyph_for_action(action_name: StringName, mode: String = "default") -> String:
	if not InputMap.has_action(action_name):
		return ""
	var buttons: Array[InputEventJoypadButton] = []
	var motions: Array[InputEventJoypadMotion] = []
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventJoypadButton:
			buttons.append(ev as InputEventJoypadButton)
		elif ev is InputEventJoypadMotion:
			motions.append(ev as InputEventJoypadMotion)
	# Dikey "aşağı" anlamı: tek yönlü platform, fall attack input, [b] eğilme[/b].
	# D-pad aşağı (13) varsa göster; yoksa joystick motion şablonu ↑/↓ karışmasın → ↓ yaz.
	# Yüz düğmesi atanmış squat varsa gerçek tuş ismini kullan (↓ sanma).
	if mode == "semantic_down":
		for b in buttons:
			if b.button_index == 12:
				return _tutorial_joy_button_short(12)
		if not motions.is_empty():
			return "↓"
		if not buttons.is_empty():
			var ls_only := buttons.size() == 1 and (buttons[0].button_index == 7 or buttons[0].button_index == 8)
			if ls_only:
				return "↓"
			buttons.sort_custom(func(a: InputEventJoypadButton, b: InputEventJoypadButton) -> bool:
				return _tutorial_joy_button_sort_key(a.button_index) < _tutorial_joy_button_sort_key(b.button_index)
			)
			return _tutorial_joy_button_short(buttons[0].button_index)
		return "↓"
	if mode == "semantic_up":
		for b in buttons:
			if b.button_index == 11:
				return _tutorial_joy_button_short(11)
		return "↑"
	# Blok: RB (sağ omuz); InputMap sırasından önce RB, sonra LB. LS/RS yanıltmaca.
	if mode == "prefer_shoulder":
		var has_lb := false
		var has_rb := false
		for b in buttons:
			match b.button_index:
				9:
					has_lb = true
				10:
					has_rb = true
		if has_rb:
			return _tutorial_joy_button_short(10)
		if has_lb:
			return _tutorial_joy_button_short(9)
		for b in buttons:
			if b.button_index != 7 and b.button_index != 8:
				return _tutorial_joy_button_short(b.button_index)
		if not buttons.is_empty():
			var only_sticks := true
			for b in buttons:
				if b.button_index != 7 and b.button_index != 8:
					only_sticks = false
					break
			if only_sticks:
				return "RB"
			return _tutorial_joy_button_short(buttons[0].button_index)
	# default: yüz düğmeleri / omuz önce, çubuk tıklaması en sonda
	if not buttons.is_empty():
		buttons.sort_custom(func(a: InputEventJoypadButton, b: InputEventJoypadButton) -> bool:
			return _tutorial_joy_button_sort_key(a.button_index) < _tutorial_joy_button_sort_key(b.button_index)
		)
		return _tutorial_joy_button_short(buttons[0].button_index)
	if not motions.is_empty():
		var jm: InputEventJoypadMotion = motions[0]
		var h := _tutorial_joy_motion_hint(jm.axis, jm.axis_value)
		if not h.is_empty():
			return h
	return ""


static func _tutorial_joy_button_sort_key(idx: int) -> int:
	match idx:
		0, 1, 2, 3:
			return 0
		4, 5, 6:
			return 1
		9, 10:
			return 2
		11, 12, 13, 14:
			return 3
		_:
			if idx == 7 or idx == 8:
				return 20
			return 10


static func _tutorial_first_joypad_glyph_for_map_action(action_name: StringName) -> String:
	return _tutorial_joypad_glyph_for_action(action_name, "default")


func get_tutorial_horizontal_move_hint() -> String:
	if last_input_from_joypad:
		var neg := ""
		var pos := ""
		for an in _tutorial_physical_action_names(&"move_left"):
			neg = _tutorial_first_joypad_glyph_for_map_action(an)
			if not neg.is_empty():
				break
		for an in _tutorial_physical_action_names(&"move_right"):
			pos = _tutorial_first_joypad_glyph_for_map_action(an)
			if not pos.is_empty():
				break
		if not neg.is_empty() and not pos.is_empty() and neg != pos:
			return "%s / %s" % [neg, pos]
		if not neg.is_empty():
			return neg
		if not pos.is_empty():
			return pos
		return "← / →"
	var preset := _current_keyboard_preset
	if preset == PRESET_ARROWS_QWEASD:
		return "← / →"
	return "A / D"


func get_tutorial_jump_hint() -> String:
	if last_input_from_joypad:
		for an in _tutorial_physical_action_names(&"jump"):
			var g := _tutorial_first_joypad_glyph_for_map_action(an)
			if not g.is_empty():
				return g
		return "A"
	return get_jump_key_name()


func get_tutorial_crouch_hint() -> String:
	if last_input_from_joypad:
		for an in _tutorial_physical_action_names(&"crouch"):
			# Çoğu projede crouch = aşağı yönü; stick şablonu ↑ göstermesin.
			var g := _tutorial_joypad_glyph_for_action(an, "semantic_down")
			if not g.is_empty():
				return g
		return "↓"
	return get_action_key_name(&"crouch")


func get_tutorial_move_down_hint() -> String:
	if last_input_from_joypad:
		for an in _tutorial_physical_action_names(&"move_down"):
			var g := _tutorial_joypad_glyph_for_action(an, "semantic_down")
			if not g.is_empty():
				return g
		return "↓"
	return get_action_key_name(&"move_down")


func get_tutorial_move_up_hint() -> String:
	if last_input_from_joypad:
		for an in _tutorial_physical_action_names(&"move_up"):
			var g := _tutorial_joypad_glyph_for_action(an, "semantic_up")
			if not g.is_empty():
				return g
		return "↑"
	return get_action_key_name(&"move_up")


func get_tutorial_block_hint() -> String:
	if last_input_from_joypad:
		var g := _tutorial_joypad_glyph_for_action(&"block", "prefer_shoulder")
		if not g.is_empty():
			return g
		return "RB"
	return get_action_key_name(&"block")


func get_tutorial_attack_hint() -> String:
	if last_input_from_joypad:
		for an in _tutorial_physical_action_names(&"attack"):
			var g := _tutorial_first_joypad_glyph_for_map_action(an)
			if not g.is_empty():
				return g
		return "X"
	return get_action_key_name(&"attack")


func get_tutorial_attack_heavy_hint() -> String:
	if last_input_from_joypad:
		for an in _tutorial_physical_action_names(&"attack_heavy"):
			var g := _tutorial_first_joypad_glyph_for_map_action(an)
			if not g.is_empty():
				return g
		return "Y"
	return get_action_key_name(&"attack_heavy")


func get_tutorial_dodge_hint() -> String:
	if last_input_from_joypad:
		for an in _tutorial_physical_action_names(&"dash"):
			var g := _tutorial_first_joypad_glyph_for_map_action(an)
			if not g.is_empty():
				return g
		return "B"
	return get_action_key_name(&"dash")


func get_tutorial_open_map_hint() -> String:
	if last_input_from_joypad:
		var g := _tutorial_joypad_glyph_for_action(&"open_world_map", "default")
		if not g.is_empty():
			return g
		return "Back"
	return get_action_key_name(&"open_world_map")


func get_tutorial_overview_camera_hint() -> String:
	if last_input_from_joypad:
		var g := _tutorial_joypad_glyph_for_action(&"toggle_camera", "default")
		if not g.is_empty():
			return g
		return "Back"
	return get_action_key_name(&"toggle_camera")


func get_tutorial_map_move_hint() -> String:
	if last_input_from_joypad:
		return "← → ↑ ↓"
	var preset := _current_keyboard_preset
	if preset == PRESET_ARROWS_QWEASD:
		return "← → ↑ ↓"
	return "W A S D"


func get_tutorial_map_confirm_hint() -> String:
	if last_input_from_joypad:
		var g := _tutorial_joypad_glyph_for_action(&"ui_accept", "default")
		if not g.is_empty():
			return g
		return "A"
	return get_action_key_name(&"ui_accept")


## Village'da "interact" tuşu klavye düzenine göre değişik fiziksel tuşlara bağlanabiliyor
## (WASD_NUMPAD'de Num8, ARROWS_QWEASD'de W — bkz. _KEYBOARD_PRESETS) ve gamepad'de D-Pad Up/sol
## çubuk yukarı. Hangi tuş olursa olsun anlamı hep "yukarı bas" olduğundan (bkz.
## NpcOverheadUi.apply_interact_hint_text'teki aynı karar), ham tuş adı yerine sabit ok
## karakteriyle gösteriyoruz — "Num 8" gibi kafa karıştırıcı isimler tutorial metinlerine sızmasın.
func get_tutorial_interact_hint() -> String:
	return "↑"


func get_tutorial_cancel_hint() -> String:
	if last_input_from_joypad:
		var g := _tutorial_joypad_glyph_for_action(&"ui_cancel", "default")
		if not g.is_empty():
			return g
		return "B"
	return get_action_key_name(&"ui_cancel")


func get_tutorial_page_left_hint() -> String:
	if last_input_from_joypad:
		# Sayfa gezinme L2 tetikleyicisi (InputMap'teki düğme indeksleri yanıltıcı).
		return "L2"
	return get_action_key_name(&"ui_page_left")


func get_tutorial_page_right_hint() -> String:
	if last_input_from_joypad:
		# Sayfa gezinme R2 tetikleyicisi (InputMap'teki düğme indeksleri yanıltıcı).
		return "R2"
	return get_action_key_name(&"ui_page_right")


func get_tutorial_ui_up_hint() -> String:
	if last_input_from_joypad:
		return _tutorial_joypad_glyph_for_action(&"ui_up", "semantic_up")
	var events := InputMap.action_get_events(&"ui_up")
	for ev in events:
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var keycode := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			match keycode:
				KEY_UP: return "↑"
				KEY_W: return "W"
				KEY_KP_8: return "Num 8"
			return _get_key_name(k)
	return "↑"


## village_worker_add InputMap'te birden fazla klavye tuşuna bağlı (bkz. project.godot) ve
## get_action_key_name ilk eşleşen event'i döndürüyor — bu bazı sistemlerde fiziksel keycode'u
## yanlış çözüp garip/okunaksız bir isim üretiyordu. VillagePlotInteractSpot.gd'deki üst simge
## ipucuyla aynı sebepten sabit "E" kullanıyoruz (bkz. project.godot'taki gerçek varsayılan bağlama).
func get_tutorial_village_worker_add_hint() -> String:
	if last_input_from_joypad:
		return "R2"
	return "E"
