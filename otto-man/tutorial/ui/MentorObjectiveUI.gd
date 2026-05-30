extends CanvasLayer
## Ekranda iki öğe:
## 1) Üst-sol: aktif görev (objective) metni
## 2) Alt-orta: dinamik tuş kısayolları barı (klavye/gamepad'e göre değişir)
## Tuş bilgisi sadece tutorial aktifken veya köy sahnesindeyken görünür.

@onready var _objective_label: Label = $ObjectiveLabel
@onready var _keys_bar: Label = $KeysBar

var _raw_objective: String = ""


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	if _objective_label:
		_objective_label.modulate.a = 0.0
		TextOutline.apply_font_to_control(_objective_label)
	if _keys_bar:
		TextOutline.apply_font_to_control(_keys_bar)
	var tm := get_node_or_null("/root/TutorialManager")
	if tm and tm.has_signal("village_objective_changed"):
		tm.village_objective_changed.connect(_on_objective_changed)
		if not String(tm.active_objective).is_empty():
			_on_objective_changed(tm.active_objective)
	var im := get_node_or_null("/root/InputManager")
	if im and im.has_signal("input_device_changed"):
		im.input_device_changed.connect(_on_device_changed)
	_refresh_keys_bar()


func _on_objective_changed(text: String) -> void:
	_raw_objective = text
	_apply_objective()


func _on_device_changed(_is_joypad: bool) -> void:
	if not _raw_objective.is_empty():
		_apply_objective()
	_refresh_keys_bar()


func _apply_objective() -> void:
	if _objective_label == null:
		return
	if _raw_objective.is_empty():
		_objective_label.text = ""
		_objective_label.modulate.a = 0.0
		return
	_objective_label.text = "► " + _resolve_input_tokens(_raw_objective)
	_objective_label.modulate.a = 1.0


func _refresh_keys_bar() -> void:
	if _keys_bar == null:
		return
	var im := get_node_or_null("/root/InputManager")
	if im == null:
		_keys_bar.text = ""
		return
	var parts: Array[String] = []
	parts.append("Etkileşim: %s" % im.get_tutorial_ui_up_hint())
	parts.append("Menü: %s" % _get_pause_hint(im))
	_keys_bar.text = "    ".join(parts)


func _get_cancel_hint(im) -> String:
	if im.last_input_from_joypad:
		var g: String = im._tutorial_joypad_glyph_for_action(&"dash", "default")
		if not g.is_empty():
			return g
		return "B"
	return im.get_action_key_name(&"dash")


func _get_pause_hint(im) -> String:
	if im.last_input_from_joypad:
		return "Start"
	return "ESC"


func _resolve_input_tokens(text: String) -> String:
	var im := get_node_or_null("/root/InputManager")
	if im == null:
		return text
	var result := text
	if result.contains("{map}"):
		result = result.replace("{map}", "[%s]" % im.get_tutorial_open_map_hint())
	if result.contains("{move}"):
		result = result.replace("{move}", "[%s]" % im.get_tutorial_map_move_hint())
	if result.contains("{confirm}"):
		result = result.replace("{confirm}", "[%s]" % im.get_tutorial_map_confirm_hint())
	if result.contains("{hex_enter}"):
		result = result.replace("{hex_enter}", "[%s]" % im.get_tutorial_attack_heavy_hint())
	if result.contains("{interact}"):
		result = result.replace("{interact}", "[%s]" % im.get_tutorial_interact_hint())
	if result.contains("{ui_up}"):
		result = result.replace("{ui_up}", "[%s]" % im.get_tutorial_ui_up_hint())
	if result.contains("{page_left}"):
		result = result.replace("{page_left}", "[%s]" % im.get_tutorial_page_left_hint())
	if result.contains("{page_right}"):
		result = result.replace("{page_right}", "[%s]" % im.get_tutorial_page_right_hint())
	return result


func _process(delta: float) -> void:
	if _objective_label == null:
		return
	if _raw_objective.is_empty() and _objective_label.modulate.a > 0.0:
		_objective_label.modulate.a = maxf(0.0, _objective_label.modulate.a - 3.0 * delta)
	var sm := get_node_or_null("/root/SceneManager")
	var wm_active: bool = sm != null and sm.get("_world_map_overlay_instance") != null and is_instance_valid(sm._world_map_overlay_instance)
	if _keys_bar:
		_keys_bar.visible = not wm_active
