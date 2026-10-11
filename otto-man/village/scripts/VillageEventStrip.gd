extends Node
## Köy sahnesinin üstünde aktif event şeridi: her aktif felaket/nimet bir çip (emoji + ad + kalan gün).
## Emojiler PLACEHOLDER: ileride sprite ile değiştirilecek (EVENT_ICONS değerleri yerine Texture konabilir).
## Çipin üstüne gelince etkisi tooltip olarak görünür.

const _LAYER_INDEX := 5
const _REFRESH_SEC := 1.0

## Tür -> [emoji, iyi mi (true = nimet), çeviri anahtarı soneki]
const EVENT_ICONS: Dictionary = {
	"famine": ["🌾", false],
	"drought": ["🏜️", false],
	"pest": ["🐛", false],
	"wolf_attack": ["🐺", false],
	"severe_storm": ["⛈️", false],
	"weather_blessing": ["☀️", true],
	"worker_strike": ["✊", false],
	"disease": ["🤒", false],
	"plague": ["☠️", false],
	"bandit_activity": ["🗡️", false],
	"rebellion": ["🔥", false],
	"trade_boom": ["💰", true],
	"war_declaration": ["⚔️", false],
}

const _BAD_COLOR := Color(0.85, 0.32, 0.25, 1.0)
const _GOOD_COLOR := Color(0.9, 0.78, 0.3, 1.0)

var _layer: CanvasLayer = null
var _row: HBoxContainer = null
var _timer: float = 0.5
var _last_signature: String = ""


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _REFRESH_SEC
	_refresh()


func _village_visible() -> bool:
	var vm: Node = get_parent()
	return is_instance_valid(vm) and "village_scene_instance" in vm and is_instance_valid(vm.get("village_scene_instance"))


func _current_day() -> int:
	var tm: Node = get_node_or_null("/root/TimeManager")
	return int(tm.call("get_day")) if tm != null and tm.has_method("get_day") else 0


## [{type, days_left}] — aynı tür bir kez görünür (en uzun kalan gün).
func collect_events() -> Array:
	var day := _current_day()
	var best: Dictionary = {}
	var vm: Node = get_parent()
	var sources: Array = []
	if is_instance_valid(vm) and vm.has_method("get_active_events"):
		sources.append_array(vm.call("get_active_events"))
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm != null and wm.get("active_events") != null:
		sources.append_array(wm.get("active_events"))
	for ev in sources:
		if not (ev is Dictionary):
			continue
		var t := String(ev.get("type", ""))
		if not EVENT_ICONS.has(t):
			continue
		var left: int = int(vm.call("_disaster_event_days_left", ev, day)) if vm.has_method("_disaster_event_days_left") else 0
		if not best.has(t) or left > int(best[t]):
			best[t] = left
	var out: Array = []
	for t in best.keys():
		out.append({"type": t, "days_left": int(best[t])})
	return out


func _ensure_layer() -> void:
	if is_instance_valid(_row):
		return
	_layer = CanvasLayer.new()
	_layer.name = "VillageEventStripLayer"
	_layer.layer = _LAYER_INDEX
	add_child(_layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(root)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 8)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_row.anchor_left = 0.0
	_row.anchor_right = 1.0
	_row.offset_left = 0.0
	_row.offset_right = 0.0
	_row.offset_top = 10.0
	_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_row)


func _refresh() -> void:
	if not _village_visible():
		if is_instance_valid(_row) and _row.visible:
			_row.visible = false
		return
	var events: Array = collect_events()
	var vm: Node = get_parent()
	if is_instance_valid(vm) and vm.has_method("get_forecast_events"):
		for f in vm.call("get_forecast_events"):
			events.append({"type": String(f.get("type", "")), "days_left": 0, "forecast": true})
	events.sort_custom(func(a, b): return String(a["type"]) < String(b["type"]))
	var signature := ""
	for e in events:
		signature += "%s:%d:%s;" % [e["type"], e["days_left"], str(e.get("forecast", false))]
	if is_instance_valid(vm) and vm.has_method("get_pending_decisions"):
		signature += "|" + str(vm.call("get_pending_decisions"))
	if signature == _last_signature and is_instance_valid(_row):
		_row.visible = not events.is_empty()
		return
	_last_signature = signature
	_ensure_layer()
	for c in _row.get_children():
		c.queue_free()
	_row.visible = not events.is_empty()
	for e in events:
		_row.add_child(_make_chip(String(e["type"]), int(e["days_left"]), bool(e.get("forecast", false))))


func _make_chip(event_type: String, days_left: int, forecast: bool = false) -> Control:
	var info: Array = EVENT_ICONS.get(event_type, ["❔", false])
	var good: bool = bool(info[1])
	var accent: Color = _GOOD_COLOR if good else _BAD_COLOR
	if forecast:
		accent = Color(0.95, 0.75, 0.3, 1.0)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.82)
	style.border_color = accent
	style.set_border_width_all(2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var name_text: String = _event_name(event_type)
	var text := "%s %s" % [String(info[0]), name_text]
	if forecast:
		text = "❗ " + text + "  " + tr("village.event.strip.tomorrow")
	elif days_left > 0:
		text += "  " + tr("village.event.strip.days") % days_left
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", accent.lightened(0.25))
	panel.add_child(label)
	var desc_key := "village.event.desc.%s" % event_type
	var desc := tr(desc_key)
	panel.tooltip_text = desc if desc != desc_key else name_text
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var vm: Node = get_parent()
	if not forecast and is_instance_valid(vm) and vm.has_method("get_pending_decisions") and (vm.call("get_pending_decisions") as Array).has(event_type):
		label.text += "  ❓"
		panel.tooltip_text += "\n" + tr("village.decision.strip_hint")
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				var ui: Node = vm.get_node_or_null("EventDecisionUI")
				if ui != null and ui.has_method("open_for"):
					ui.call("open_for", event_type))
	return panel


func _event_name(event_type: String) -> String:
	var vm: Node = get_parent()
	if is_instance_valid(vm) and vm.has_method("_village_event_type_name"):
		var key := "village.event.name.%s" % event_type
		var t := tr(key)
		if t != key:
			return t
	var key2 := "village.event.name.%s" % event_type
	var t2 := tr(key2)
	return t2 if t2 != key2 else event_type.capitalize()
