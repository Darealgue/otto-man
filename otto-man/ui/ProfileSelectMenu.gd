extends Control
class_name ProfileSelectMenu
## Ana menü: 3 oyuncu profili kartı (ayrı save klasörleri).

signal profile_chosen(profile_id: int)
signal back_requested

enum MenuIntent { NEW_GAME, LOAD }

const CARD_COUNT: int = 3

@onready var _title: Label = $Center/RootVBox/TitleLabel
@onready var _sub: Label = $Center/RootVBox/SubLabel
@onready var _cards_row: HBoxContainer = $Center/RootVBox/CardsRow
@onready var _back_button: Button = $Center/RootVBox/BackButton

var _intent: MenuIntent = MenuIntent.NEW_GAME


func _ready() -> void:
	visible = false
	_back_button.pressed.connect(_on_back_pressed)
	_build_cards()
	TextOutline.apply_to_tree(self)
	if LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_refresh_locale)
	_refresh_locale()


func show_menu(intent: MenuIntent) -> void:
	_intent = intent
	_refresh_header()
	_refresh_card_texts()
	visible = true
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	call_deferred("_focus_first_select_button")


func hide_menu() -> void:
	visible = false


func _refresh_header() -> void:
	match _intent:
		MenuIntent.NEW_GAME:
			_title.text = tr("profile.new_game_title")
			_sub.text = tr("profile.new_game_sub")
		MenuIntent.LOAD:
			_title.text = tr("profile.load_title")
			_sub.text = tr("profile.load_sub")


func _refresh_locale(_locale: String = "") -> void:
	if _back_button:
		_back_button.text = tr("profile.back")
	for panel in _cards_row.get_children():
		var pid: int = int(panel.get_meta("profile_id", 1))
		var margin: MarginContainer = panel.get_child(0) as MarginContainer
		if margin == null:
			continue
		var vb: VBoxContainer = margin.get_child(0) as VBoxContainer
		if vb == null:
			continue
		for ch in vb.get_children():
			if ch is Label and ch.get_index() == 1:
				(ch as Label).text = tr("profile.card_name") % pid
			elif ch is Button:
				(ch as Button).text = tr("profile.select_button")
	if visible:
		_refresh_header()
		_refresh_card_texts()


func _on_back_pressed() -> void:
	_play_click()
	back_requested.emit()


func _on_profile_button(profile_id: int) -> void:
	_play_click()
	profile_chosen.emit(profile_id)


func _build_cards() -> void:
	for c in _cards_row.get_children():
		c.queue_free()
	for profile_id in range(1, CARD_COUNT + 1):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(280, 420)
		ParchmentTextures.apply_compact_panel_style(panel, 12)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 14)
		var accent := ColorRect.new()
		accent.custom_minimum_size = Vector2(0, 4)
		accent.color = Color(0.45, 0.65, 0.95, 1.0)
		var name_l := Label.new()
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_font_size_override("font_size", 28)
		name_l.add_theme_color_override("font_color", TextOutline.FONT_COLOR)
		name_l.text = tr("profile.card_name") % profile_id
		var stats_l := Label.new()
		stats_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stats_l.add_theme_font_size_override("font_size", 16)
		stats_l.add_theme_color_override("font_color", TextOutline.FONT_COLOR_MUTED)
		var btn := Button.new()
		btn.text = tr("profile.select_button")
		btn.custom_minimum_size = Vector2(0, 44)
		btn.pressed.connect(_on_profile_button.bind(profile_id))
		vb.add_child(accent)
		vb.add_child(name_l)
		vb.add_child(stats_l)
		vb.add_child(btn)
		margin.add_child(vb)
		panel.add_child(margin)
		panel.set_meta("profile_id", profile_id)
		panel.set_meta("stats_label", stats_l)
		_cards_row.add_child(panel)


func _refresh_card_texts() -> void:
	if not is_instance_valid(SaveManager):
		return
	for panel in _cards_row.get_children():
		if not panel.has_meta("stats_label"):
			continue
		var pid: int = int(panel.get_meta("profile_id", 1))
		var stats_l: Label = panel.get_meta("stats_label")
		var s: Dictionary = SaveManager.get_profile_summary(pid)
		var lines: PackedStringArray = PackedStringArray()
		if bool(s.get("has_saves", false)):
			lines.append(tr("profile.saved_slots") % int(s.get("used_slots", 0)))
			var lt: String = str(s.get("latest_save_date", ""))
			if not lt.is_empty():
				lines.append(tr("profile.latest_save") % lt)
			lines.append(tr("profile.longest_play") % LocaleManager.format_playtime_profile(int(s.get("max_playtime", 0))))
			lines.append(tr("profile.total_playtime") % LocaleManager.format_playtime_profile(int(s.get("sum_playtime", 0))))
		else:
			lines.append(tr("profile.no_saves_line1"))
			lines.append(tr("profile.no_saves_line2"))
		stats_l.text = "\n".join(lines)


func _focus_first_select_button() -> void:
	for panel in _cards_row.get_children():
		var margin: MarginContainer = panel.get_child(0) as MarginContainer
		if margin == null:
			continue
		var vb: VBoxContainer = margin.get_child(0) as VBoxContainer
		if vb == null:
			continue
		for ch in vb.get_children():
			if ch is Button:
				(ch as Button).grab_focus()
				return
	if _back_button:
		_back_button.grab_focus()


func _play_click() -> void:
	if is_instance_valid(SoundManager) and SoundManager.has_method("play_ui"):
		SoundManager.play_ui("click")
