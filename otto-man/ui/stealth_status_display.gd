extends Control
## Zindan stealth / alarm HUD göstergesi (runtime oluşturulur).

const HudLayout = preload("res://ui/hud_layout.gd")

var _badge: PanelContainer
var _label: Label
var _toast: Label
var _vignette: ColorRect
var _pulse: float = 0.0
var _toast_timer: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40

	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0.55, 0.0, 0.0, 0.0)
	add_child(_vignette)

	_badge = PanelContainer.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_badge.add_child(_label)

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 13)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	_toast.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_toast.add_theme_constant_override("outline_size", 3)
	_toast.visible = false
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 96.0
	_toast.offset_left = -220.0
	_toast.offset_right = 220.0
	_toast.offset_bottom = 132.0
	add_child(_toast)

	_position_badge()

	var sm: Node = get_node_or_null("/root/StealthManager")
	if is_instance_valid(sm) and sm.has_signal("alarm_raised"):
		sm.alarm_raised.connect(_on_alarm_raised)
	_refresh()


func _position_badge() -> void:
	var top_y: float = HudLayout.get_hud_block_bottom(HudLayout.HUD_ORIGIN) + 10.0
	_badge.position = Vector2(12.0, top_y)
	_badge.custom_minimum_size = Vector2(108.0, 28.0)
	_badge.z_index = 120


func _process(delta: float) -> void:
	var sm: Node = get_node_or_null("/root/StealthManager")
	if not is_instance_valid(sm) or not sm.has_method("is_stealth_enabled") or not sm.is_stealth_enabled():
		visible = false
		return
	visible = true
	_refresh()
	if sm.segment_alarm:
		_pulse += delta * 3.0
		var alpha: float = 0.08 + absf(sin(_pulse)) * 0.1
		_vignette.color = Color(0.65, 0.02, 0.02, alpha)
	else:
		_pulse = 0.0
		_vignette.color = Color(0.55, 0.0, 0.0, 0.0)
	if _toast_timer > 0.0:
		_toast_timer = maxf(0.0, _toast_timer - delta)
		if _toast_timer <= 0.0:
			_toast.visible = false


func _on_alarm_raised(_reason: String) -> void:
	_refresh()


func refresh_fragile_status() -> void:
	_refresh()


func show_flee_toast(villagers_lost: int, cariyes_lost: int) -> void:
	var parts: PackedStringArray = PackedStringArray()
	if villagers_lost > 0:
		parts.append("%d köylü" % villagers_lost)
	if cariyes_lost > 0:
		parts.append("%d cariye" % cariyes_lost)
	if parts.is_empty():
		return
	_toast.text = "Korkup kaçtı: " + ", ".join(parts)
	_toast.visible = true
	_toast_timer = 3.5
	_refresh()


func _refresh() -> void:
	var sm: Node = get_node_or_null("/root/StealthManager")
	if not is_instance_valid(sm):
		return
	if sm.segment_alarm:
		_label.text = "ALARM"
		_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		if _badge:
			var alarm_style := StyleBoxFlat.new()
			alarm_style.bg_color = Color(0.35, 0.05, 0.05, 0.82)
			alarm_style.border_color = Color(0.95, 0.25, 0.2)
			alarm_style.set_border_width_all(1)
			alarm_style.set_corner_radius_all(4)
			_badge.add_theme_stylebox_override("panel", alarm_style)
	else:
		var fragile_text := _fragile_badge_suffix()
		_label.text = "Gizli" + fragile_text
		_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))
		if _badge:
			var stealth_style := StyleBoxFlat.new()
			stealth_style.bg_color = Color(0.04, 0.12, 0.08, 0.78)
			stealth_style.border_color = Color(0.35, 0.8, 0.45)
			stealth_style.set_border_width_all(1)
			stealth_style.set_corner_radius_all(4)
			_badge.add_theme_stylebox_override("panel", stealth_style)


func _fragile_badge_suffix() -> String:
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs) or not drs.has_method("count_fragile_rescued"):
		return ""
	var counts: Dictionary = drs.call("count_fragile_rescued")
	var total: int = int(counts.get("villagers", 0)) + int(counts.get("cariyes", 0))
	if total <= 0:
		return ""
	return " · %d⚠" % total
