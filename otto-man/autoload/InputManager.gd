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

const SETTINGS_PATH := "user://settings.cfg"

const PRESET_WASD_NUMPAD := StringName("wasd_numpad")
const PRESET_ARROWS_QWEASD := StringName("arrows_qweasd")

# Mantıksal aksiyon -> InputMap aksiyon listesi
static var _ACTION_GROUPS := {
	StringName("ui_up"): [StringName("ui_up")],
	StringName("ui_down"): [StringName("ui_down")],
	StringName("ui_left"): [StringName("ui_left")],
	StringName("ui_right"): [StringName("ui_right")],
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

func _ready() -> void:
	_load_keyboard_preset_from_disk()

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
		KEY_ESCAPE: return "ESC"
		KEY_TAB: return "Tab"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		_: 
			# Harf ve sayı tuşları için
			var key_string = OS.get_keycode_string(keycode)
			if key_string != "":
				return key_string.to_upper()
			return "Key " + str(keycode)

## Gamepad butonu için isim döndürür
static func _get_joypad_button_name(event: InputEventJoypadButton) -> String:
	match event.button_index:
		0: return "A Button"
		1: return "B Button"
		2: return "X Button"
		3: return "Y Button"
		4: return "Left Shoulder"
		5: return "Right Shoulder"
		6: return "Left Trigger"
		7: return "Right Trigger"
		8: return "Select"
		9: return "Start"
		10: return "Left Stick"
		11: return "Right Stick"
		12: return "D-Pad Up"
		13: return "D-Pad Down"
		14: return "D-Pad Left"
		15: return "D-Pad Right"
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
