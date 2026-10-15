extends Control
class_name ConcubineMissionPopupUI
## Cariye üzerinden görev atama + rol seçimi — portre + görev kartları + rol sekmesi, parşömen temalı.

signal closed

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")
const _KeyChipScript := preload("res://ui/KeyChip.gd")
const _PortraitRenderer := preload("res://ui/ConcubinePortraitRenderer.gd")

enum Tab { MISSIONS, ROLES, OVERVIEW }

# Layout
var _panel: PanelContainer
var _portrait_rect: TextureRect
var _portrait_color: ColorRect
var _portrait_initial: Label
var _name_label: Label
var _status_chip: Label
var _role_label: Label
var _stamina_label: Label
var _stamina_bar: ProgressBar
var _level_label: Label
var _stats_label: RichTextLabel
var _dismiss_btn: Button
var _dismiss_armed: bool = false

var _tab_missions_btn: Button
var _tab_roles_btn: Button
var _tab_overview_btn: Button
var _overview_tab_box: VBoxContainer
var _overview_list: VBoxContainer
var _overview_scroll: ScrollContainer
var _overview_nav_buttons: Array[Button] = []

var _missions_tab_box: VBoxContainer
var _special_actions_box: VBoxContainer

var _roles_tab_box: VBoxContainer
var _role_button_row: HBoxContainer
var _point_button_row: HBoxContainer
var _role_info_label: Label
var _drop_role_btn: Button

var _info_label: Label
var _nav_hint_label: Label

# Controller / keyboard navigation — sekmeye göre değişen dört ayrı grup, tek listede birleşir
# (bkz. _all_nav_buttons). Mouse yok, tüm gezinme klavye/gamepad ile.
var _tab_nav_buttons: Array[Button] = []
var _special_action_nav_buttons: Array[Button] = []
var _roles_nav_buttons: Array[Button] = []
var _active_tab: int = Tab.MISSIONS
var _focused_nav_row: int = 0
var _focus_generation: int = 0
var _suppress_nav_until_msec: int = 0
var _portrait_generation: int = 0

# State
var _concubine: Concubine = null
var _is_open := false

## Roller sekmesinde yan yana gösterilecek gerçek roller (Yok hariç).
const _ROLE_BUTTONS_ORDER: Array[int] = [
	Concubine.Role.KOMUTAN,
	Concubine.Role.AJAN,
	Concubine.Role.DİPLOMAT,
	Concubine.Role.TÜCCAR,
	Concubine.Role.TIBBIYECI,
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = _MEDIEVAL_THEME
	UiFontFloor.attach(self)
	_build_ui()
	visible = false
	var viewport := get_viewport()
	if viewport and not viewport.gui_focus_changed.is_connected(_on_gui_focus_changed):
		viewport.gui_focus_changed.connect(_on_gui_focus_changed)
	call_deferred("_reapply_full_rect")


func _reapply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# ─── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.02, 0.01, 0.52)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left   = 0.5; _panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.5; _panel.anchor_bottom = 0.5
	# Sabit boyut, tam ortada: içerik uzayınca aşağı taşmasın diye iki yana büyür ve kırpılır;
	# uzun metinler kaydırma alanlarında kalır (özellikler, rol bilgisi, cariye listesi).
	_panel.offset_left   = -760
	_panel.offset_top    = -420
	_panel.offset_right  = 760
	_panel.offset_bottom = 420
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.clip_contents = true
	ParchmentTextures.apply_large_panel_style(_panel, 22)
	add_child(_panel)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	_panel.add_child(root)

	# ── Left column ──────────────────────────────────────────────────────────
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)

	# Portrait box
	var portrait_wrapper := PanelContainer.new()
	portrait_wrapper.custom_minimum_size = Vector2(170, 170)
	portrait_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var portrait_sb := StyleBoxFlat.new()
	portrait_sb.bg_color = Color(0.12, 0.09, 0.06, 0.7)
	portrait_sb.border_width_left   = 2
	portrait_sb.border_width_top    = 2
	portrait_sb.border_width_right  = 2
	portrait_sb.border_width_bottom = 2
	portrait_sb.border_color = Color(0.6, 0.45, 0.25, 0.9)
	portrait_sb.corner_radius_top_left     = 8
	portrait_sb.corner_radius_top_right    = 8
	portrait_sb.corner_radius_bottom_left  = 8
	portrait_sb.corner_radius_bottom_right = 8
	# İçerik çerçevenin içinde kalsın (kenarlık çocukların altında kalıp görünmüyordu)
	portrait_sb.set_content_margin_all(4)
	portrait_wrapper.clip_contents = true
	portrait_wrapper.add_theme_stylebox_override("panel", portrait_sb)
	left.add_child(portrait_wrapper)

	_portrait_color = ColorRect.new()
	_portrait_color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_color.color = Color(0.18, 0.13, 0.08, 1.0)
	portrait_wrapper.add_child(_portrait_color)

	_portrait_rect = TextureRect.new()
	_portrait_rect.name = "Portrait"
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
	_portrait_initial.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_portrait_initial.add_theme_font_size_override("font_size", 64)
	_portrait_initial.modulate = Color(0.85, 0.68, 0.38, 0.7)
	portrait_wrapper.add_child(_portrait_initial)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 32)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	left.add_child(_name_label)

	_role_label = Label.new()
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_label.add_theme_font_size_override("font_size", 22)
	_role_label.add_theme_color_override("font_color", Color(0.9, 0.72, 0.38))
	left.add_child(_role_label)

	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55))
	left.add_child(_level_label)

	_status_chip = Label.new()
	_status_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_chip.add_theme_font_size_override("font_size", 15)
	left.add_child(_status_chip)

	# Dinçlik: görevlerle düşer, köyde yemek yiyerek dolar.
	_stamina_label = Label.new()
	_stamina_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamina_label.add_theme_font_size_override("font_size", 15)
	left.add_child(_stamina_label)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(0, 12)
	_stamina_bar.min_value = 0
	_stamina_bar.max_value = Concubine.STAMINA_MAX
	_stamina_bar.show_percentage = false
	left.add_child(_stamina_bar)

	var stats_sep := ColorRect.new()
	stats_sep.custom_minimum_size = Vector2(0, 1)
	stats_sep.color = Color(0.6, 0.47, 0.28, 0.5)
	left.add_child(stats_sep)

	_stats_label = RichTextLabel.new()
	_stats_label.bbcode_enabled = true
	_stats_label.fit_content = true
	_stats_label.scroll_active = false
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.add_theme_font_size_override("normal_font_size", 15)
	_stats_label.add_theme_font_size_override("bold_font_size", 15)
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Özellikler uzun olabilir: sol sütun paneli büyütmesin, kendi kaydırma alanında kalsın.
	var stats_scroll := ScrollContainer.new()
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left.add_child(stats_scroll)
	stats_scroll.add_child(_stats_label)

	# ── Divider ──────────────────────────────────────────────────────────────
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(2, 0)
	divider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	root.add_child(divider)

	# ── Right column ─────────────────────────────────────────────────────────
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	right.add_child(tab_row)

	tab_row.add_child(_make_key_chip("Q", "L2"))

	_tab_missions_btn = Button.new()
	_tab_missions_btn.text = tr("dm.tab_dispatch")
	_tab_missions_btn.focus_mode = Control.FOCUS_ALL
	_tab_missions_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_missions_btn.pressed.connect(_switch_tab.bind(Tab.MISSIONS))
	_style_focus(_tab_missions_btn)
	tab_row.add_child(_tab_missions_btn)
	_tab_nav_buttons.append(_tab_missions_btn)

	_tab_roles_btn = Button.new()
	_tab_roles_btn.text = tr("cm_popup.tab_roles")
	_tab_roles_btn.focus_mode = Control.FOCUS_ALL
	_tab_roles_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_roles_btn.pressed.connect(_switch_tab.bind(Tab.ROLES))
	_style_focus(_tab_roles_btn)
	tab_row.add_child(_tab_roles_btn)
	_tab_nav_buttons.append(_tab_roles_btn)

	_tab_overview_btn = Button.new()
	_tab_overview_btn.text = tr("cm_popup.tab_overview")
	_tab_overview_btn.focus_mode = Control.FOCUS_ALL
	_tab_overview_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_overview_btn.pressed.connect(_switch_tab.bind(Tab.OVERVIEW))
	_style_focus(_tab_overview_btn)
	tab_row.add_child(_tab_overview_btn)
	_tab_nav_buttons.append(_tab_overview_btn)

	tab_row.add_child(_make_key_chip("E", "R2"))

	var tab_divider := ColorRect.new()
	tab_divider.custom_minimum_size = Vector2(0, 1)
	tab_divider.color = Color(0.6, 0.47, 0.28, 0.5)
	right.add_child(tab_divider)

	# ── Görevler sekmesi içeriği ─────────────────────────────────────────────
	_missions_tab_box = VBoxContainer.new()
	_missions_tab_box.add_theme_constant_override("separation", 6)
	right.add_child(_missions_tab_box)

	_special_actions_box = VBoxContainer.new()
	_special_actions_box.add_theme_constant_override("separation", 4)
	_missions_tab_box.add_child(_special_actions_box)

	# ── Roller sekmesi içeriği ───────────────────────────────────────────────
	_roles_tab_box = VBoxContainer.new()
	_roles_tab_box.add_theme_constant_override("separation", 8)
	_roles_tab_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roles_tab_box.visible = false
	right.add_child(_roles_tab_box)

	# ── Cariyeler (genel bakış) sekmesi: köydeki tüm cariyeler tek listede ────────
	_overview_tab_box = VBoxContainer.new()
	_overview_tab_box.add_theme_constant_override("separation", 6)
	_overview_tab_box.visible = false
	_overview_tab_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_overview_tab_box)
	_overview_scroll = ScrollContainer.new()
	_overview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overview_scroll.follow_focus = true
	_overview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overview_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_overview_tab_box.add_child(_overview_scroll)
	_overview_list = VBoxContainer.new()
	_overview_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overview_list.add_theme_constant_override("separation", 6)
	_overview_scroll.add_child(_overview_list)

	var roles_title := Label.new()
	roles_title.text = tr("cm_popup.assign_role")
	roles_title.add_theme_font_size_override("font_size", 16)
	_roles_tab_box.add_child(roles_title)

	_role_button_row = HBoxContainer.new()
	_role_button_row.add_theme_constant_override("separation", 6)
	_roles_tab_box.add_child(_role_button_row)

	# Gelişim puanı satırı: her rolün altında "+ ●●○○○" düğmesi (boş puanı o role verir).
	_point_button_row = HBoxContainer.new()
	_point_button_row.add_theme_constant_override("separation", 6)
	_roles_tab_box.add_child(_point_button_row)

	var info_wrapper := PanelContainer.new()
	var info_sb := StyleBoxFlat.new()
	info_sb.bg_color = Color(0.14, 0.11, 0.08, 0.7)
	info_sb.corner_radius_top_left = 6
	info_sb.corner_radius_top_right = 6
	info_sb.corner_radius_bottom_left = 6
	info_sb.corner_radius_bottom_right = 6
	info_sb.set_content_margin_all(10)
	info_wrapper.add_theme_stylebox_override("panel", info_sb)
	info_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roles_tab_box.add_child(info_wrapper)

	# Rol bilgisi uzun olabilir: kendi kaydırma alanında kalsın, panel büyümesin.
	var info_scroll := ScrollContainer.new()
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	info_wrapper.add_child(info_scroll)
	_role_info_label = Label.new()
	_role_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_role_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_role_info_label.add_theme_font_size_override("font_size", 15)
	_role_info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	info_scroll.add_child(_role_info_label)

	# Alt satır: rolü bırak (ücretsiz) + köyden yolla (iki basışla onay).
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	_roles_tab_box.add_child(bottom_row)

	_drop_role_btn = Button.new()
	_drop_role_btn.text = tr("cm_popup.drop_role")
	_drop_role_btn.focus_mode = Control.FOCUS_ALL
	_drop_role_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drop_role_btn.visible = false
	_drop_role_btn.pressed.connect(_on_drop_role_pressed)
	_style_focus(_drop_role_btn)
	bottom_row.add_child(_drop_role_btn)

	_dismiss_btn = Button.new()
	_dismiss_btn.text = tr("cm_popup.dismiss")
	_dismiss_btn.focus_mode = Control.FOCUS_ALL
	_dismiss_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dismiss_btn.pressed.connect(_on_dismiss_pressed)
	_style_focus(_dismiss_btn)
	bottom_row.add_child(_dismiss_btn)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.modulate = Color(1, 0.55, 0.5, 1)
	right.add_child(_info_label)

	var hint_lbl := Label.new()
	hint_lbl.name = "NavHint"
	_nav_hint_label = hint_lbl
	_update_nav_hint()
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.modulate = Color(1, 1, 1, 0.45)
	right.add_child(hint_lbl)

	TextOutline.apply_to_tree(self)


# ─── Public API ───────────────────────────────────────────────────────────────

func show_for_concubine(concubine: Concubine) -> void:
	_concubine = concubine
	_reapply_full_rect()
	_is_open = true
	_focus_generation += 1
	_focused_nav_row = 0
	_suppress_nav_until_msec = Time.get_ticks_msec() + 250
	_info_label.text = ""
	_info_label.modulate = Color(1, 0.55, 0.5, 1)
	_update_nav_hint()
	get_viewport().gui_release_focus()
	_refresh_concubine_info()
	_switch_tab(Tab.MISSIONS)
	visible = true
	call_deferred("_focus_first_nav_button")
	_set_player_ui_locked(true)
	VillageManager.register_npc_dialogue_window_shown()


func hide_popup() -> void:
	_is_open = false
	_focus_generation += 1
	_portrait_generation += 1
	if is_instance_valid(_portrait_rect):
		_PortraitRenderer.clear(_portrait_rect)
	visible = false
	_concubine = null
	_roles_nav_buttons.clear()
	get_viewport().gui_release_focus()
	closed.emit()
	_set_player_ui_locked(false)
	VillageManager.register_npc_dialogue_window_hidden()


## Mentor/Tüccar/Kamp Ateşi popup'larının aksine bu popup açıkken oyuncu _is_any_menu_open()'ın
## "yumuşak" korumasına (sadece velocity sıfırlama) rağmen hareket edip diyaloğu kapatabiliyordu —
## state machine kendi input okumasıyla player.gd'nin sıfırlamasını eziyordu. Worker.gd'nin
## npc_window akışıyla aynı sert kilidi (state machine'i tamamen durduran set_ui_locked) kullanıyoruz.
func _set_player_ui_locked(locked: bool) -> void:
	var vm := get_node_or_null("/root/VillageManager")
	if vm and vm.get("Village_Player"):
		vm.Village_Player.set_ui_locked(locked)


func hide_if_for_concubine(concubine_id: int) -> void:
	if not _is_open or _concubine == null:
		return
	if _concubine.id == concubine_id:
		hide_popup()


func is_open_for(concubine_id: int) -> bool:
	return _is_open and _concubine != null and _concubine.id == concubine_id


# ─── Info panel ───────────────────────────────────────────────────────────────

func _refresh_concubine_info() -> void:
	if _concubine == null:
		return

	var first_char: String = _concubine.name.substr(0, 1).to_upper() if not _concubine.name.is_empty() else "?"
	_portrait_initial.text = first_char
	_portrait_color.color = _role_color(_concubine.role)
	_portrait_generation += 1
	var portrait_gen: int = _portrait_generation
	if _concubine.appearance != null:
		_portrait_initial.visible = false
		_portrait_rect.visible = true
		_render_concubine_portrait(portrait_gen)
	else:
		_PortraitRenderer.clear(_portrait_rect)
		_portrait_rect.visible = false
		_portrait_initial.visible = true

	_name_label.text = _concubine.name

	var status_text: String
	var status_color: Color
	match _concubine.status:
		Concubine.Status.BOŞTA:
			status_text = tr("cm_popup.status_available")
			status_color = Color(0.45, 0.85, 0.4)
		Concubine.Status.GÖREVDE:
			status_text = tr("cm_popup.status_on_mission")
			status_color = Color(0.95, 0.72, 0.25)
		Concubine.Status.YARALI:
			status_text = tr("cm_popup.status_injured")
			status_color = Color(0.9, 0.3, 0.3)
		Concubine.Status.DİNLENİYOR:
			status_text = tr("cm_popup.status_resting")
			status_color = Color(0.55, 0.72, 0.95)
		_:
			status_text = "?"
			status_color = Color(1, 1, 1, 0.6)
	_status_chip.text = status_text
	_status_chip.modulate = status_color

	# Önem sırası: ad (büyük) > rol > seviye > durum > boş puan > özellikler (küçük).
	_role_label.text = _role_name(int(_concubine.role))
	_level_label.text = tr("cm_popup.level_short") % _concubine.level
	_stamina_label.text = tr("cm_popup.stamina") % [_concubine.stamina, Concubine.STAMINA_MAX]
	_stamina_bar.value = _concubine.stamina
	var low: bool = _concubine.stamina < Concubine.STAMINA_MIN_FOR_MISSION
	_stamina_label.modulate = Color(0.95, 0.45, 0.4) if low else Color(0.85, 0.8, 0.65)
	_stamina_bar.modulate = Color(0.95, 0.45, 0.4) if low else Color(0.6, 0.85, 0.5)

	var lines: PackedStringArray = []
	if _concubine.unspent_points > 0:
		lines.append("[center][color=#f0d27a][font_size=17]%s[/font_size][/color][/center]" % (tr("cm_popup.points_free") % _concubine.unspent_points))
		lines.append("")
	# Doğuştan özellikler (0-3, renkli: yeşil artı, kehribar çift taraflı, kırmızı eksi).
	var traits: Array[String] = _concubine.get_traits()
	lines.append("[b][font_size=18]%s[/font_size][/b]" % tr("cm_popup.traits_title"))
	lines.append("")
	if traits.is_empty():
		lines.append("[color=#8a7a58][font_size=14]%s[/font_size][/color]" % tr("cm_popup.traits_none"))
	for t in traits:
		var kind: String = String(Concubine.TRAIT_KINDS.get(t, "good"))
		var col: String = "#8fd08a"
		if kind == "bad":
			col = "#e08a7a"
		elif kind == "mixed":
			col = "#e8c46a"
		lines.append("[color=%s][b]%s[/b][/color]" % [col, tr("concubine.trait.%s.name" % t)])
		lines.append("[color=#9c8d6c][font_size=13]%s[/font_size][/color]" % tr("concubine.trait.%s.desc" % t))
		lines.append("")
	_stats_label.text = "\n".join(lines).strip_edges()


func _role_color(role: int) -> Color:
	match role:
		Concubine.Role.KOMUTAN:    return Color(0.35, 0.12, 0.12, 1.0)
		Concubine.Role.AJAN:       return Color(0.1, 0.22, 0.18, 1.0)
		Concubine.Role.DİPLOMAT:  return Color(0.15, 0.18, 0.35, 1.0)
		Concubine.Role.TÜCCAR:    return Color(0.28, 0.22, 0.08, 1.0)
		Concubine.Role.TIBBIYECI: return Color(0.1, 0.28, 0.18, 1.0)
	return Color(0.14, 0.10, 0.07, 1.0)


func _render_concubine_portrait(portrait_gen: int) -> void:
	if _concubine == null:
		return
	await _PortraitRenderer.render(
		_portrait_rect,
		_concubine,
		self,
		func() -> bool:
			return portrait_gen != _portrait_generation or not _is_open
	)


# ─── Sekmeler ─────────────────────────────────────────────────────────────────

func _switch_tab(tab: int) -> void:
	_active_tab = tab
	_style_tab_button(_tab_missions_btn, tab == Tab.MISSIONS)
	_style_tab_button(_tab_roles_btn, tab == Tab.ROLES)
	_style_tab_button(_tab_overview_btn, tab == Tab.OVERVIEW)
	_missions_tab_box.visible = tab == Tab.MISSIONS
	_roles_tab_box.visible = tab == Tab.ROLES
	_overview_tab_box.visible = tab == Tab.OVERVIEW
	if tab == Tab.MISSIONS:
		_refresh_special_actions()
	elif tab == Tab.ROLES:
		_refresh_roles_tab()
	else:
		_refresh_overview()
	call_deferred("_focus_first_nav_button")


## Cariyeler sekmesi: köydeki herkes, durumuyla birlikte. Birine basınca pencere o cariyeye geçer
## (10 cariyeyi tek tek köyde aramadan yönetmek için).
func _refresh_overview() -> void:
	_overview_nav_buttons.clear()
	for child in _overview_list.get_children():
		child.queue_free()
	var mm := get_node_or_null("/root/MissionManager")
	if mm == null or not ("concubines" in mm):
		return
	var ids: Array = mm.concubines.keys()
	ids.sort()
	if ids.is_empty():
		var empty := Label.new()
		empty.text = tr("cm_popup.overview_empty")
		empty.modulate = Color(1, 1, 1, 0.55)
		_overview_list.add_child(empty)
		return
	for cid in ids:
		var c: Concubine = mm.concubines[cid]
		if c == null:
			continue
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_ALL
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 17)
		_style_focus(btn)
		var mark: String = "▶ " if (_concubine != null and _concubine.id == c.id) else "   "
		var status_text: String = c.get_status_name()
		match c.status:
			Concubine.Status.YARALI:
				if c.injured_days_left > 0:
					status_text += " (%s)" % (tr("cm_popup.overview_days") % c.injured_days_left)
			Concubine.Status.GÖREVDE:
				var mref: Variant = mm.missions.get(c.current_mission_id, null)
				if mref is Mission:
					status_text += ": " + String(mm.get_mission_display_name(mref))
		var parts: PackedStringArray = PackedStringArray()
		parts.append("%s%s" % [mark, c.name])
		var row_dots: String = ""
		if int(c.role) != Concubine.Role.NONE:
			var row_pts: int = c.get_role_points(int(c.role))
			for di in range(Concubine.ROLE_POINT_CAP):
				row_dots += "●" if di < row_pts else "○"
		parts.append("%s %s" % [_role_name(int(c.role)), row_dots])
		parts.append(status_text)
		if c.unspent_points > 0:
			parts.append(tr("cm_popup.overview_points") % c.unspent_points)
		btn.text = "  ·  ".join(parts)
		btn.set_meta("cid", c.id)
		btn.pressed.connect(_select_concubine.bind(c.id))
		_overview_list.add_child(btn)
		_overview_nav_buttons.append(btn)


## Cariyeler sekmesinden birini seç: pencere o cariyeye geçer ve görev sekmesine döner.
func _select_concubine(cid: int) -> void:
	var mm := get_node_or_null("/root/MissionManager")
	if mm == null or not mm.concubines.has(cid):
		return
	_concubine = mm.concubines[cid]
	_info_label.text = ""
	_refresh_concubine_info()
	_switch_tab(Tab.MISSIONS)


## Sekmeler arası Q/E (klavye) veya L2/R2 (gamepad) ile geçiş — MentorBriefPopupUI'deki
## "Q/E sekme" konvansiyonuyla tutarlı.
func _cycle_tab(direction: int) -> void:
	var tabs := [Tab.MISSIONS, Tab.ROLES, Tab.OVERVIEW]
	var idx := tabs.find(_active_tab)
	idx = wrapi(idx + direction, 0, tabs.size())
	_switch_tab(tabs[idx])


## Sekme değiştirme tuş rozeti. Ortak widget: ui/KeyChip.gd — oyuncunun O ANDA kullandığı
## cihaza göre klavye tuşunu VEYA gamepad karşılığını gösterir, cihaz değişince kendini
## günceller. Eskiden ikisi alt alta yazılıyor ve sığdırmak için punto 13/9'a düşürülüyordu.
func _make_key_chip(keyboard_text: String, joypad_text: String) -> Control:
	var chip: PanelContainer = _KeyChipScript.new()
	chip.setup(keyboard_text, joypad_text)
	return chip


func _style_tab_button(btn: Button, active: bool) -> void:
	if active:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.32, 0.24, 0.12, 1.0)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.9, 0.78, 0.35)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", sb)
	else:
		btn.remove_theme_stylebox_override("normal")


# ─── Rol-özel aksiyonlar (Görevler sekmesinde, mevcut role bağlı) ──────────────

func _refresh_special_actions() -> void:
	if not is_instance_valid(_special_actions_box):
		return
	for child in _special_actions_box.get_children():
		child.queue_free()
	_special_action_nav_buttons.clear()
	if _concubine == null:
		return
	_add_dispatch_action()
	match _concubine.role:
		Concubine.Role.TIBBIYECI:
			_add_healer_treat_action()
		Concubine.Role.KOMUTAN:
			_add_commander_info_line()


## "Göreve Yolla": haritayı seçim modunda açar; hedef hex'i ve görevi orada seçeriz.
func _add_dispatch_action() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_special_actions_box.add_child(row)

	var btn := Button.new()
	btn.text = tr("dm.dispatch_action")
	btn.disabled = _concubine.status != Concubine.Status.BOŞTA
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_on_dispatch_pressed)
	_style_focus(btn)
	row.add_child(btn)
	_special_action_nav_buttons.append(btn)


func _on_dispatch_pressed() -> void:
	if _concubine == null:
		return
	var cid: int = _concubine.id
	hide_popup()
	var sm := get_node_or_null("/root/SceneManager")
	if sm and sm.has_method("change_to_world_map"):
		sm.change_to_world_map({"source": "village", "select_mission_concubine_id": cid})


func _add_healer_treat_action() -> void:
	var can_treat: bool = VillageManager.can_healer_concubine_treat(_concubine.id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_special_actions_box.add_child(row)

	var btn := Button.new()
	btn.text = tr("cm_popup.healer_treat_action")
	btn.disabled = not can_treat
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_healer_treat_pressed)
	_style_focus(btn)
	row.add_child(btn)
	_special_action_nav_buttons.append(btn)

	if not can_treat:
		var reason := Label.new()
		reason.text = tr("cm_popup.no_treat_needed")
		reason.add_theme_font_size_override("font_size", 10)
		reason.modulate = Color(1, 1, 1, 0.5)
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_special_actions_box.add_child(reason)


func _on_healer_treat_pressed() -> void:
	if _concubine == null:
		return
	var result: Dictionary = VillageManager.try_healer_concubine_treatment(_concubine.id)
	_info_label.text = String(result.get("message", ""))
	_info_label.modulate = Color(0.6, 0.95, 0.55, 1) if bool(result.get("ok", false)) else Color(1, 0.55, 0.5, 1)
	_refresh_special_actions()


func _add_commander_info_line() -> void:
	var lbl := Label.new()
	lbl.text = tr("cm_popup.commander_info")
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.95, 0.75, 0.45, 0.9)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_special_actions_box.add_child(lbl)




# ─── Soldier stepper ──────────────────────────────────────────────────────────













# ─── Helpers ──────────────────────────────────────────────────────────────────























func _role_name(role: int) -> String:
	match role:
		Concubine.Role.NONE:      return tr("cm_popup.role_none")
		Concubine.Role.KOMUTAN:   return tr("cm_popup.role_commander")
		Concubine.Role.AJAN:      return tr("cm_popup.role_agent")
		Concubine.Role.DİPLOMAT: return tr("cm_popup.role_diplomat")
		Concubine.Role.TÜCCAR:   return tr("cm_popup.role_trader")
		Concubine.Role.TIBBIYECI: return tr("cm_popup.role_physician")
	return tr("cm_popup.role_unspecified")


# ─── Roller sekmesi ─────────────────────────────────────────────────────────────
# Roller ağır bir karar: her buton kilitli başlar, fokuslanınca maliyet + fayda bilgisi
# gösterir. Seçilince bedel ödenir ve Görevler sekmesi SADECE o rolü kazandıracak göreve
# (Eğitim görevi kalktı: rol anında verilir, yalnız altın ödenir.)

func _refresh_roles_tab() -> void:
	if not is_instance_valid(_role_button_row):
		return
	for child in _role_button_row.get_children():
		child.queue_free()
	if is_instance_valid(_point_button_row):
		for child in _point_button_row.get_children():
			child.queue_free()
	_roles_nav_buttons.clear()
	if _concubine == null:
		return
	for role in _ROLE_BUTTONS_ORDER:
		var btn := _make_role_button(role)
		_role_button_row.add_child(btn)
		_roles_nav_buttons.append(btn)

	# Rol altındaki gelişim puanı düğmeleri: "+ ●●○○○" (boş puan varsa ve tavan dolmadıysa basılır).
	if is_instance_valid(_point_button_row):
		for role in _ROLE_BUTTONS_ORDER:
			var pbtn := _make_point_button(role)
			_point_button_row.add_child(pbtn)
			_roles_nav_buttons.append(pbtn)

	_drop_role_btn.visible = int(_concubine.role) != Concubine.Role.NONE
	if _drop_role_btn.visible:
		_drop_role_btn.disabled = _concubine.status != Concubine.Status.BOŞTA
		_roles_nav_buttons.append(_drop_role_btn)
	_dismiss_armed = false
	_dismiss_btn.text = tr("cm_popup.dismiss")
	_dismiss_btn.disabled = _concubine.status != Concubine.Status.BOŞTA
	_roles_nav_buttons.append(_dismiss_btn)

	_update_role_info_panel(_ROLE_BUTTONS_ORDER[0])


## "+" düğmesi: o role 1 boş puan verir (geri alınamaz, rol başına en çok 5). Noktalar rol
## düğmesinin altında görünür.
func _make_point_button(role: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 40)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL
	btn.set_meta("role", role)
	_style_focus(btn)
	var can: bool = _concubine.can_spend_point(role)
	btn.text = "+"
	btn.add_theme_font_size_override("font_size", 24)
	btn.disabled = not can
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	if can:
		sb.bg_color = Color(0.16, 0.3, 0.14, 0.9)
		sb.border_color = Color(0.55, 0.9, 0.45)
	else:
		sb.bg_color = Color(0.1, 0.09, 0.08, 0.5)
		sb.border_color = Color(0.3, 0.28, 0.25, 0.6)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("disabled", sb)
	btn.pressed.connect(_on_point_button_pressed.bind(role))
	return btn


## Rol düğmesinin altındaki puan noktaları: ●●○○○
func _points_dots(role: int) -> String:
	var pts: int = _concubine.get_role_points(role)
	var dots: String = ""
	for i in range(Concubine.ROLE_POINT_CAP):
		dots += "●" if i < pts else "○"
	return dots


func _on_point_button_pressed(role: int) -> void:
	if _concubine == null:
		return
	if not _concubine.spend_point(role):
		return
	_info_label.text = tr("cm_popup.point_given") % _role_name(role)
	_info_label.modulate = Color(0.6, 0.95, 0.55, 1)
	_refresh_concubine_info()
	_refresh_roles_tab()
	call_deferred("_focus_first_nav_button")


func _make_role_button(role: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 56)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL
	btn.clip_text = true
	btn.set_meta("role", role)
	_style_focus(btn)

	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.set_content_margin_all(6)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2

	var is_current: bool = int(_concubine.role) == role
	var dots: String = _points_dots(role)
	btn.custom_minimum_size = Vector2(100, 66)
	if is_current:
		btn.text = "✓ %s\n%s" % [_role_name(role), dots]
		sb.bg_color = Color(0.18, 0.32, 0.18, 0.85)
		sb.border_color = Color(0.5, 0.9, 0.45)
		btn.disabled = true
	else:
		btn.text = "%s\n%s" % [_role_name(role), dots]
		sb.bg_color = Color(0.12, 0.1, 0.08, 0.6)
		sb.border_color = Color(0.4, 0.36, 0.3, 0.7)
		btn.disabled = _concubine.status != Concubine.Status.BOŞTA
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("disabled", sb)
	btn.pressed.connect(_on_role_button_pressed.bind(role))
	return btn


func _on_role_button_pressed(role: int) -> void:
	if _concubine == null:
		return
	var mm := get_node_or_null("/root/MissionManager")
	if mm == null or not mm.has_method("request_concubine_role"):
		_info_label.text = tr("cm_popup.role_assign_failed")
		_info_label.modulate = Color(1, 0.55, 0.5, 1)
		return
	var result: Dictionary = mm.request_concubine_role(_concubine.id, role)
	var ok: bool = bool(result.get("ok", false))
	_info_label.text = String(result.get("message", ""))
	_info_label.modulate = Color(0.6, 0.95, 0.55, 1) if ok else Color(1, 0.55, 0.5, 1)
	if not ok:
		return
	# Rol anında değişti: aynı sekmede kal, bilgi ve düğmeleri tazele.
	_refresh_concubine_info()
	_refresh_roles_tab()


func _on_drop_role_pressed() -> void:
	if _concubine == null:
		return
	var mm := get_node_or_null("/root/MissionManager")
	if mm == null or not mm.has_method("request_concubine_role"):
		return
	var result: Dictionary = mm.request_concubine_role(_concubine.id, Concubine.Role.NONE)
	_info_label.text = String(result.get("message", ""))
	_info_label.modulate = Color(0.6, 0.95, 0.55, 1) if bool(result.get("ok", false)) else Color(1, 0.55, 0.5, 1)
	if bool(result.get("ok", false)):
		_refresh_concubine_info()
		_refresh_roles_tab()


func _update_role_info_panel(role: int) -> void:
	if not is_instance_valid(_role_info_label) or _concubine == null:
		return
	var mm := get_node_or_null("/root/MissionManager")
	var vm := get_node_or_null("/root/VillageManager")
	var lines: PackedStringArray = []
	lines.append(_role_name(role))
	lines.append("")
	# Aktif yetenekler: cariye görevde yaparsa; pasif yetenekler: rol köyde olduğu sürece geçerli.
	var ab: Dictionary = _role_abilities(role, mm)
	lines.append("▸ " + tr("cm_popup.abilities_active"))
	lines.append(String(ab.get("active", "")))
	lines.append("")
	lines.append("▸ " + tr("cm_popup.abilities_passive"))
	lines.append(String(ab.get("passive", "")))
	if not bool(ab.get("held", true)):
		lines.append(tr("cm_popup.role_missing_line"))
	lines.append("")
	lines.append(tr("cm_popup.role_points_line") % [_concubine.get_role_points(role), Concubine.ROLE_POINT_CAP])
	lines.append(tr("cm_popup.points_free_line") % _concubine.unspent_points)
	lines.append("")
	if int(_concubine.role) == role:
		lines.append(tr("cm_popup.current_role_note"))
	else:
		var cost: Dictionary = vm.get_role_training_cost(role) if vm and vm.has_method("get_role_training_cost") else {}
		if not cost.is_empty():
			lines.append(tr("cm_popup.cost_line") % _format_role_cost_display(cost))
	_role_info_label.text = "\n".join(lines)


## Rolün aktif (görev) ve pasif (köyde bulunduğu sürece) yetenekleri, güncel sayılarla.
## {"active": String, "passive": String, "held": bool (köyde bu rolde cariye var mı)}
func _role_abilities(role: int, mm: Node) -> Dictionary:
	var held: bool = false
	var strength: int = 0
	var best_points: int = 0
	if mm != null and mm.has_method("has_role"):
		held = bool(mm.call("has_role", role))
		strength = int(mm.call("get_role_strength", role))
		for c in mm.get_concubines_by_role(role):
			best_points = maxi(best_points, int(c.get_role_points(role)))
	var out := {"active": "", "passive": "", "held": held}
	match role:
		Concubine.Role.KOMUTAN:
			out["active"] = tr("cm_popup.ab.komutan.active")
			var norm: float = float(20 + 16 * best_points) / 100.0
			var atk: int = int(round((0.10 + 0.30 * norm) * 100.0))
			var def: int = int(round((0.08 + 0.22 * norm) * 100.0))
			var cap: int = int(mm.call("get_leadership_cap")) if mm != null and mm.has_method("get_leadership_cap") else 3
			out["passive"] = tr("cm_popup.ab.komutan.passive") % [atk, def, cap]
		Concubine.Role.AJAN:
			out["active"] = tr("cm_popup.ab.ajan.active")
			var n: int = int(mm.call("get_intel_visible_count")) if mm != null and mm.has_method("get_intel_visible_count") else 1
			out["passive"] = tr("cm_popup.ab.ajan.passive") % n
		Concubine.Role.DİPLOMAT:
			out["active"] = tr("cm_popup.ab.diplomat.active")
			out["passive"] = tr("cm_popup.ab.diplomat.passive3") % (10 * strength)
		Concubine.Role.TÜCCAR:
			out["active"] = tr("cm_popup.ab.tuccar.active")
			out["passive"] = tr("cm_popup.ab.tuccar.passive") % (10 * strength)
		Concubine.Role.TIBBIYECI:
			out["active"] = tr("cm_popup.ab.tibbiyeci.active")
			var cas: float = float(mm.call("get_casualty_multiplier")) if mm != null and mm.has_method("get_casualty_multiplier") else 1.0
			var heal: float = float(mm.call("get_healing_time_multiplier")) if mm != null and mm.has_method("get_healing_time_multiplier") else 1.0
			out["passive"] = tr("cm_popup.ab.tibbiyeci.passive") % [int(round((cas - 1.0) * 100.0)), int(round((heal - 1.0) * 100.0))]
	return out




func _format_role_cost_display(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(cost.get("gold", 0)) > 0:
		parts.append(tr("cm_popup.cost_gold") % int(cost["gold"]))
	for k in cost.keys():
		if str(k) == "gold":
			continue
		var amt: int = int(cost[k])
		if amt > 0:
			parts.append("%d %s" % [amt, LocaleManager.get_resource_name(str(k))])
	return ", ".join(parts)


# ─── Assign ───────────────────────────────────────────────────────────────────



# ─── Styling ──────────────────────────────────────────────────────────────────

func _style_focus(button: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.22, 0.1, 0.9)
	sb.border_width_left   = 2
	sb.border_width_top    = 2
	sb.border_width_right  = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.85, 0.35, 1.0)
	sb.corner_radius_top_left     = 6
	sb.corner_radius_top_right    = 6
	sb.corner_radius_bottom_left  = 6
	sb.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("focus", sb)


## Sekme butonları + (aktif sekmeye göre) özel aksiyon/görev/rol butonlarının tek, sıralı
## gezinme listesi.
func _all_nav_buttons() -> Array[Button]:
	var combined: Array[Button] = []
	combined.append_array(_tab_nav_buttons)
	if _active_tab == Tab.MISSIONS:
		combined.append_array(_special_action_nav_buttons)
	elif _active_tab == Tab.OVERVIEW:
		combined.append_array(_overview_nav_buttons)
	else:
		combined.append_array(_roles_nav_buttons)
	return combined


func _focus_first_nav_button() -> void:
	# Görevler sekmesinde görev varsa doğrudan ilk göreve odaklan (en sık kullanılan aksiyon);
	# Roller sekmesinde ilk rol butonuna odaklan. Yukarı basınca sekme butonlarına dönülür.
	var start_idx: int = 0
	if _active_tab == Tab.MISSIONS and not _special_action_nav_buttons.is_empty():
		# İlk özel aksiyon "Göreve Yolla": en sık kullanılan, doğrudan ona odaklan.
		start_idx = _tab_nav_buttons.size()
	elif _active_tab == Tab.ROLES and not _roles_nav_buttons.is_empty():
		start_idx = _tab_nav_buttons.size()
	elif _active_tab == Tab.OVERVIEW and not _overview_nav_buttons.is_empty():
		# Şu an seçili cariyenin satırına odaklan.
		start_idx = _tab_nav_buttons.size()
		for i in range(_overview_nav_buttons.size()):
			if _concubine != null and int(_overview_nav_buttons[i].get_meta("cid", -1)) == _concubine.id:
				start_idx = _tab_nav_buttons.size() + i
				break
	_focus_nearest_nav_button(start_idx)


func _focus_nearest_nav_button(preferred_index: int) -> bool:
	var all := _all_nav_buttons()
	if all.is_empty():
		return false
	var count := all.size()
	for offset in range(count):
		var idx := wrapi(preferred_index + offset, 0, count)
		var btn: Button = all[idx]
		if not is_instance_valid(btn) or btn.disabled:
			continue
		_focused_nav_row = idx
		get_viewport().gui_release_focus()
		btn.grab_focus()
		return true
	return false


func _move_nav_focus(direction: int) -> void:
	var all := _all_nav_buttons()
	if all.is_empty():
		return
	var count := all.size()
	for step in range(count):
		var idx := wrapi(_focused_nav_row + direction * (step + 1), 0, count)
		var btn: Button = all[idx]
		if not is_instance_valid(btn) or btn.disabled:
			continue
		_focused_nav_row = idx
		get_viewport().gui_release_focus()
		btn.grab_focus()
		return


func _on_gui_focus_changed(control: Control) -> void:
	if not visible or not _is_open:
		return
	# "Köyden yolla" onayı başka düğmeye geçilince sıfırlanır (yanlışlıkla ikinci basış olmasın).
	if _dismiss_armed and control != _dismiss_btn:
		_dismiss_armed = false
		if is_instance_valid(_dismiss_btn):
			_dismiss_btn.text = tr("cm_popup.dismiss")
	if control != null and control is Button:
		var all := _all_nav_buttons()
		var idx := all.find(control)
		if idx >= 0:
			_focused_nav_row = idx
			if control.has_meta("role"):
				_update_role_info_panel(int(control.get_meta("role")))
			return
	call_deferred("_reclaim_nav_focus")


func _reclaim_nav_focus() -> void:
	if not visible or not _is_open:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner is Button and _all_nav_buttons().find(owner) >= 0:
		return
	_focus_nearest_nav_button(_focused_nav_row)


func _update_nav_hint() -> void:
	if _nav_hint_label == null:
		return
	var im := get_node_or_null("/root/InputManager")
	var is_pad := im != null and bool(im.get("last_input_from_joypad"))
	if is_pad:
		_nav_hint_label.text = tr("cm_popup.nav_hint_gamepad2")
	else:
		_nav_hint_label.text = tr("cm_popup.nav_hint_keyboard2")


func _find_first_button(node: Node) -> Button:
	if node is Button:
		return node as Button
	for child in node.get_children():
		var found := _find_first_button(child)
		if found:
			return found
	return null


func _grab_initial_focus() -> void:
	_focus_first_nav_button()


# ─── Input ────────────────────────────────────────────────────────────────────

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hide_popup()


## Roller sekmesinin satırları: rol düğmeleri, "+" düğmeleri, alt düğmeler (rolü bırak / köyden yolla).
func _roles_grid_rows() -> Array:
	var role_row: Array = []
	for c in _role_button_row.get_children():
		if c is Button:
			role_row.append(c)
	var point_row: Array = []
	for c in _point_button_row.get_children():
		if c is Button:
			point_row.append(c)
	var bottom: Array = []
	if _drop_role_btn.visible:
		bottom.append(_drop_role_btn)
	bottom.append(_dismiss_btn)
	return [role_row, point_row, bottom]


func _roles_grid_focus(btn: Button) -> void:
	_focused_nav_row = _all_nav_buttons().find(btn)
	get_viewport().gui_release_focus()
	btn.grab_focus()


## Izgarada bir adım: dx sütun, dy satır. Devre dışı düğmeler atlanır.
func _roles_grid_move(dx: int, dy: int) -> void:
	var rows: Array = _roles_grid_rows()
	var owner := get_viewport().gui_get_focus_owner()
	var ri: int = -1
	var ci: int = -1
	for r in range(rows.size()):
		var idx: int = (rows[r] as Array).find(owner)
		if idx >= 0:
			ri = r
			ci = idx
			break
	if ri < 0:
		_focus_first_nav_button()
		return
	if dx != 0:
		var row: Array = rows[ri]
		for step in range(1, row.size()):
			var cand: Button = row[wrapi(ci + dx * step, 0, row.size())]
			if is_instance_valid(cand) and not cand.disabled:
				_roles_grid_focus(cand)
				return
		return
	# Satır değiştir: hedef satırda aynı sütuna en yakın etkin düğme.
	for step in range(1, rows.size()):
		var nr: int = wrapi(ri + dy * step, 0, rows.size())
		var target_row: Array = rows[nr]
		var best: Button = null
		var best_dist: int = 9999
		for j in range(target_row.size()):
			var b: Button = target_row[j]
			if not is_instance_valid(b) or b.disabled:
				continue
			var d: int = absi(j - mini(ci, target_row.size() - 1))
			if d < best_dist:
				best_dist = d
				best = b
		if best != null:
			_roles_grid_focus(best)
			return


## "Köyden yolla": iki basışla onay. Cariye köyden ayrılır (geri alınamaz).
func _on_dismiss_pressed() -> void:
	if _concubine == null:
		return
	if not _dismiss_armed:
		_dismiss_armed = true
		_dismiss_btn.text = tr("cm_popup.dismiss_confirm")
		return
	var vm := get_node_or_null("/root/VillageManager")
	var cid: int = _concubine.id
	var nm: String = _concubine.name
	hide_popup()
	if vm != null and vm.has_method("dismiss_cariye"):
		vm.call("dismiss_cariye", cid)


func _input(event: InputEvent) -> void:
	if not visible or not _is_open:
		return
	# ui_back = ESC'nin bağlı olduğu ayrı aksiyon (ui_cancel sadece META/gamepad B içeriyor).
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		get_viewport().set_input_as_handled()
		hide_popup()
		return
	var nav_blocked := Time.get_ticks_msec() < _suppress_nav_until_msec
	if not nav_blocked:
		# Roller sekmesi iki boyutlu: sol/sağ satır içinde, yukarı/aşağı satırlar arasında gezer.
		if _active_tab == Tab.ROLES:
			var gx: int = 0
			var gy: int = 0
			if event.is_action_pressed("ui_left"):
				gx = -1
			elif event.is_action_pressed("ui_right"):
				gx = 1
			elif event.is_action_pressed("ui_up"):
				gy = -1
			elif event.is_action_pressed("ui_down"):
				gy = 1
			if gx != 0 or gy != 0:
				get_viewport().set_input_as_handled()
				_roles_grid_move(gx, gy)
				return
		if event.is_action_pressed("ui_down"):
			get_viewport().set_input_as_handled()
			_move_nav_focus(1)
			return
		if event.is_action_pressed("ui_up"):
			get_viewport().set_input_as_handled()
			_move_nav_focus(-1)
			return
		if event.is_action_pressed("ui_page_left") or InputManager.is_ui_page_left_just_pressed():
			get_viewport().set_input_as_handled()
			_cycle_tab(-1)
			return
		if event.is_action_pressed("ui_page_right") or InputManager.is_ui_page_right_just_pressed():
			get_viewport().set_input_as_handled()
			_cycle_tab(1)
			return
		if event.is_action_pressed("ui_accept"):
			var owner := get_viewport().gui_get_focus_owner()
			if owner is Button and _all_nav_buttons().find(owner) >= 0:
				get_viewport().set_input_as_handled()
				(owner as Button).pressed.emit()
				return
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
