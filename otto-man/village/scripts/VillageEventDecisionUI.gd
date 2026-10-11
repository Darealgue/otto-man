extends Node
## Felaket karar kartı: bir olay başlayınca oyuncuya 2-3 seçenek sunar (bedel/etki bilgisiyle).
## Karar verilmezse olay tam etkisiyle sürer. Kart "Sonra" ile kapatılabilir, üstteki olay şeridinden yeniden açılır.
## Emojiler PLACEHOLDER (VillageEventDecisions.EMOJI); ileride sprite ile değiştirilecek.

const _Decisions = preload("res://village/scripts/VillageEventDecisions.gd")
const _LAYER_INDEX := 12
const _CHECK_SEC := 0.5

var _layer: CanvasLayer = null
var _root: Control = null
var _current_type: String = ""
var _dismissed: Dictionary = {}
var _timer: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _vm() -> Node:
	return get_parent()


func _village_visible() -> bool:
	var vm: Node = _vm()
	return is_instance_valid(vm) and "village_scene_instance" in vm and is_instance_valid(vm.get("village_scene_instance"))


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _CHECK_SEC
	var vm: Node = _vm()
	if not is_instance_valid(vm) or not vm.has_method("get_pending_decisions"):
		return
	var pending: Array = vm.call("get_pending_decisions")
	if is_instance_valid(_root) and _root.visible:
		# açık kart: olay kendiliğinden bittiyse kapat
		if not pending.has(_current_type):
			_close()
		return
	if not _village_visible():
		return
	if "active_dialogue_npc" in vm and is_instance_valid(vm.get("active_dialogue_npc")):
		return
	if get_tree().paused:
		return
	for t in pending:
		if not _dismissed.has(String(t)):
			open_for(String(t))
			return


## Şeritteki çipe tıklayınca da çağrılır.
func open_for(event_type: String) -> void:
	if not _Decisions.has_decision(event_type):
		return
	var vm: Node = _vm()
	if not is_instance_valid(vm) or not (vm.get("_pending_decisions") as Array).has(event_type):
		return
	_dismissed.erase(event_type)
	_current_type = event_type
	_build_card(event_type)


func _close() -> void:
	if is_instance_valid(_root):
		_root.visible = false


func _dismiss() -> void:
	_dismissed[_current_type] = true
	_close()


func _ensure_layer() -> void:
	if is_instance_valid(_root):
		for c in _root.get_children():
			c.queue_free()
		_root.visible = true
		return
	_layer = CanvasLayer.new()
	_layer.name = "VillageEventDecisionLayer"
	_layer.layer = _LAYER_INDEX
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_root)


func _style_panel(accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.03, 0.03, 0.96)
	s.border_color = accent
	s.set_border_width_all(3)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	return s


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for res in cost.keys():
		var lm: Node = get_node_or_null("/root/LocaleManager")
		var name_text: String = String(res).capitalize()
		if String(res) == "gold":
			name_text = tr("village.decision.gold")
		elif lm != null and lm.has_method("get_resource_name"):
			name_text = String(lm.call("get_resource_name", String(res)))
		parts.append("%d %s" % [int(cost[res]), name_text])
	return ", ".join(parts)


func _build_card(event_type: String) -> void:
	_ensure_layer()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.85, 0.32, 0.25)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var emoji: String = String(_Decisions.EMOJI.get(event_type, "❗"))
	var vm: Node = _vm()
	var type_name: String = String(vm.call("_village_event_type_name", event_type)) if vm.has_method("_village_event_type_name") else event_type
	var title := Label.new()
	title.text = "%s %s" % [emoji, type_name]
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var prompt := Label.new()
	prompt.text = tr("village.decision.%s.prompt" % event_type)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.custom_minimum_size = Vector2(560, 0)
	prompt.add_theme_font_size_override("font_size", 18)
	box.add_child(prompt)

	var first_button: Button = null
	for opt in _Decisions.options_for(event_type):
		var oid := String(opt.get("id", ""))
		var label_text: String = tr("village.decision.%s.%s.label" % [event_type, oid])
		var hint_text: String = tr("village.decision.%s.%s.hint" % [event_type, oid])
		var cost: Dictionary = opt.get("cost", {})
		var extra := ""
		if not cost.is_empty():
			extra = "  ·  " + tr("village.decision.cost") % _cost_text(cost)
		var reason: String = _Decisions.unavailable_reason(vm, opt)
		var btn := Button.new()
		btn.text = "%s\n%s%s" % [label_text, hint_text, extra]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(560, 64)
		btn.add_theme_font_size_override("font_size", 17)
		if reason != "":
			btn.disabled = true
			btn.tooltip_text = tr("village.decision.unavailable.%s" % reason)
			if reason == "soldiers":
				btn.text += "  ·  " + tr("village.decision.need_soldiers") % int(opt.get("need_soldiers", 0))
		else:
			btn.pressed.connect(_on_option_pressed.bind(event_type, oid))
			if first_button == null:
				first_button = btn
		box.add_child(btn)

	var later := Button.new()
	later.text = tr("village.decision.later")
	later.custom_minimum_size = Vector2(0, 40)
	later.add_theme_font_size_override("font_size", 16)
	later.pressed.connect(_dismiss)
	box.add_child(later)
	(first_button if first_button != null else later).grab_focus()


func _on_option_pressed(event_type: String, option_id: String) -> void:
	var vm: Node = _vm()
	if is_instance_valid(vm) and vm.has_method("resolve_event_decision"):
		vm.call("resolve_event_decision", event_type, option_id)
	_dismissed.erase(event_type)
	_close()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_root) and _root.visible and event.is_action_pressed("ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()
