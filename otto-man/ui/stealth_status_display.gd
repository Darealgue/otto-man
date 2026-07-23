extends Control
## Zindan stealth / alarm HUD göstergesi (runtime oluşturulur).

const HudLayout = preload("res://ui/hud_layout.gd")

var _badge: PanelContainer
var _label: Label
var _toast: Label
var _alarm_banner: Label
var _key_panel: PanelContainer
var _key_icon: Label
var _key_count: Label
var _key_arrow: Label
var _vignette: ColorRect
var _pulse: float = 0.0
var _toast_timer: float = 0.0
var _alarm_banner_timer: float = 0.0
const ALARM_BANNER_HOLD_SEC: float = 4.5


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

	_alarm_banner = Label.new()
	_alarm_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alarm_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_alarm_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alarm_banner.add_theme_font_size_override("font_size", 20)
	_alarm_banner.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	_alarm_banner.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.02))
	_alarm_banner.add_theme_constant_override("outline_size", 4)
	_alarm_banner.visible = false
	_alarm_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_alarm_banner.offset_top = 72.0
	_alarm_banner.offset_left = -280.0
	_alarm_banner.offset_right = 280.0
	_alarm_banner.offset_bottom = 140.0
	add_child(_alarm_banner)

	_key_panel = PanelContainer.new()
	_key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_panel.visible = false
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color(0.12, 0.1, 0.06, 0.88)
	key_style.border_color = Color(0.95, 0.78, 0.28, 1.0)
	key_style.set_border_width_all(2)
	key_style.set_corner_radius_all(6)
	key_style.content_margin_left = 10
	key_style.content_margin_right = 10
	key_style.content_margin_top = 4
	key_style.content_margin_bottom = 4
	_key_panel.add_theme_stylebox_override("panel", key_style)
	add_child(_key_panel)

	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 6)
	key_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_key_panel.add_child(key_row)

	_key_icon = Label.new()
	_key_icon.text = "🔑"
	_key_icon.add_theme_font_size_override("font_size", 18)
	key_row.add_child(_key_icon)

	_key_count = Label.new()
	_key_count.text = "0/1"
	_key_count.add_theme_font_size_override("font_size", 16)
	_key_count.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	key_row.add_child(_key_count)

	_key_arrow = Label.new()
	_key_arrow.text = "➤"
	_key_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_arrow.add_theme_font_size_override("font_size", 30)
	_key_arrow.add_theme_color_override("font_color", Color(1.0, 0.82, 0.18))
	_key_arrow.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.0))
	_key_arrow.add_theme_constant_override("outline_size", 4)
	_key_arrow.visible = false
	_key_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_arrow.z_index = 130
	add_child(_key_arrow)

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 13)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	_toast.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_toast.add_theme_constant_override("outline_size", 3)
	_toast.visible = false
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 150.0
	_toast.offset_left = -220.0
	_toast.offset_right = 220.0
	_toast.offset_bottom = 186.0
	add_child(_toast)

	_position_badge()
	_position_key_panel()

	var sm: Node = get_node_or_null("/root/StealthManager")
	if is_instance_valid(sm) and sm.has_signal("alarm_raised"):
		sm.alarm_raised.connect(_on_alarm_raised)
	_refresh()


func _position_badge() -> void:
	var top_y: float = HudLayout.get_hud_block_bottom(HudLayout.HUD_ORIGIN) + 10.0
	_badge.position = Vector2(12.0, top_y)
	_badge.custom_minimum_size = Vector2(108.0, 28.0)
	_badge.z_index = 120


func _position_key_panel() -> void:
	var top_y: float = HudLayout.get_hud_block_bottom(HudLayout.HUD_ORIGIN) + 10.0
	_key_panel.position = Vector2(128.0, top_y)
	_key_panel.custom_minimum_size = Vector2(72.0, 28.0)
	_key_panel.z_index = 120


func _process(delta: float) -> void:
	var sm: Node = get_node_or_null("/root/StealthManager")
	if not is_instance_valid(sm) or not sm.has_method("is_stealth_enabled") or not sm.is_stealth_enabled():
		visible = false
		return
	visible = true
	_refresh()
	_refresh_key_counter()
	_update_key_holder_arrow()
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
	if _alarm_banner_timer > 0.0:
		_alarm_banner_timer = maxf(0.0, _alarm_banner_timer - delta)
		var fade_start: float = 1.2
		if _alarm_banner_timer <= fade_start:
			_alarm_banner.modulate.a = clampf(_alarm_banner_timer / fade_start, 0.0, 1.0)
		if _alarm_banner_timer <= 0.0:
			_alarm_banner.visible = false
			_alarm_banner.modulate.a = 1.0


func _on_alarm_raised(_reason: String) -> void:
	_refresh()
	show_alarm_banner()


func refresh_fragile_status() -> void:
	_refresh()


func show_alarm_banner() -> void:
	_alarm_banner.text = tr("stealth.alarm_banner")
	_alarm_banner.visible = true
	_alarm_banner.modulate.a = 1.0
	_alarm_banner_timer = ALARM_BANNER_HOLD_SEC
	_refresh_key_counter()


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


func show_key_obtained_toast() -> void:
	_toast.text = tr("stealth.key_obtained_toast")
	_toast.visible = true
	_toast_timer = 3.5
	_refresh_key_counter()


func show_exit_key_required_toast() -> void:
	_toast.text = tr("stealth.exit_key_required_toast")
	_toast.visible = true
	_toast_timer = 3.5
	_refresh_key_counter()


func _refresh_key_counter() -> void:
	if _key_panel == null:
		return
	var sm: Node = get_node_or_null("/root/StealthManager")
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(sm) or not is_instance_valid(drs):
		_key_panel.visible = false
		return
	var needs_key: bool = bool(drs.get("segment_exit_requires_key")) and sm.segment_alarm
	if not needs_key:
		_key_panel.visible = false
		return
	_key_panel.visible = true
	var has_key := false
	if drs.has_method("has_dungeon_key"):
		has_key = bool(drs.call("has_dungeon_key", drs.get("SEGMENT_EXIT_KEY_ID")))
	_key_count.text = "1/1" if has_key else "0/1"
	if has_key:
		_key_count.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	else:
		_key_count.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))


func _update_key_holder_arrow() -> void:
	if _key_arrow == null:
		return
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs) or not drs.has_method("should_show_key_holder_arrow"):
		_key_arrow.visible = false
		return
	if not bool(drs.call("should_show_key_holder_arrow")):
		_key_arrow.visible = false
		return
	var target: Node = null
	if drs.has_method("get_key_target_node"):
		target = drs.call("get_key_target_node")
	if not is_instance_valid(target) or not target is Node2D:
		_key_arrow.visible = false
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		_key_arrow.visible = false
		return
	var target_world: Vector2 = (target as Node2D).global_position
	var screen_pos: Vector2 = viewport.get_canvas_transform() * target_world
	var screen_size: Vector2 = viewport.get_visible_rect().size
	const EDGE_PADDING: float = 36.0
	var on_screen: bool = (
		screen_pos.x >= EDGE_PADDING
		and screen_pos.x <= screen_size.x - EDGE_PADDING
		and screen_pos.y >= EDGE_PADDING
		and screen_pos.y <= screen_size.y - EDGE_PADDING
	)
	if on_screen:
		_key_arrow.visible = false
		return
	var edge: Dictionary = _screen_edge_arrow(screen_pos, screen_size, EDGE_PADDING)
	_key_arrow.position = edge["pos"] - Vector2(15, 15)
	_key_arrow.rotation = float(edge["angle"])
	_key_arrow.visible = true
	_key_arrow.tooltip_text = tr("stealth.key_holder_arrow_tooltip")


func _screen_edge_arrow(target_screen: Vector2, screen_size: Vector2, padding: float) -> Dictionary:
	var center: Vector2 = screen_size * 0.5
	var offset: Vector2 = target_screen - center
	if offset.length_squared() < 1.0:
		return {"pos": center, "angle": 0.0}
	var half: Vector2 = screen_size * 0.5 - Vector2(padding, padding)
	var tx: float = half.x / absf(offset.x) if absf(offset.x) > 0.001 else 99999.0
	var ty: float = half.y / absf(offset.y) if absf(offset.y) > 0.001 else 99999.0
	var scale: float = minf(tx, ty)
	var edge_pos: Vector2 = center + offset * scale
	return {"pos": edge_pos, "angle": offset.angle()}


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
