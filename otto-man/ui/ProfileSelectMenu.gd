extends Control
class_name ProfileSelectMenu
## Ana menü: 3 oyuncu profili kartı (ayrı save klasörleri).

signal profile_chosen(profile_id: int)
signal back_requested

enum MenuIntent { NEW_GAME, LOAD }

const CARD_COUNT: int = 3
const _ConfirmDialogScene := preload("res://ui/ConfirmDialog.tscn")

@onready var _title: Label = $Center/RootVBox/TitleLabel
@onready var _sub: Label = $Center/RootVBox/SubLabel
@onready var _cards_row: HBoxContainer = $Center/RootVBox/CardsRow
@onready var _back_button: Button = $Center/RootVBox/BackButton

var _intent: MenuIntent = MenuIntent.NEW_GAME
var _status_label: Label
var _confirm_dialog: Control
var _pending_delete_profile: int = -1


func _ready() -> void:
	visible = false
	_back_button.pressed.connect(_on_back_pressed)
	_setup_status_label()
	_setup_confirm_dialog()
	_build_cards()
	TextOutline.apply_to_tree(self)
	if LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_refresh_locale)
	_refresh_locale()


func show_menu(intent: MenuIntent) -> void:
	_intent = intent
	_set_status("")
	_refresh_header()
	_refresh_card_texts()
	visible = true
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	call_deferred("_focus_first_select_button")


func hide_menu() -> void:
	visible = false
	_pending_delete_profile = -1
	if _confirm_dialog and _confirm_dialog.has_method("hide_dialog"):
		_confirm_dialog.hide_dialog()


func _setup_status_label() -> void:
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45, 1.0))
	_status_label.text = ""
	var root: VBoxContainer = _back_button.get_parent() as VBoxContainer
	if root:
		root.add_child(_status_label)
		root.move_child(_status_label, _back_button.get_index())


func _setup_confirm_dialog() -> void:
	if _confirm_dialog:
		return
	if not _ConfirmDialogScene:
		push_warning("[ProfileSelectMenu] ConfirmDialog.tscn yüklenemedi")
		return
	_confirm_dialog = _ConfirmDialogScene.instantiate()
	_confirm_dialog.name = "ConfirmDialog"
	add_child(_confirm_dialog)
	if _confirm_dialog.has_signal("confirmed"):
		_confirm_dialog.confirmed.connect(_on_confirm_delete)
	if _confirm_dialog.has_signal("cancelled"):
		_confirm_dialog.cancelled.connect(_on_cancel_delete)


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
			elif ch is Button and ch.get_meta("is_delete_button", false):
				(ch as Button).text = tr("profile.delete_button")
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


func _on_delete_pressed(profile_id: int) -> void:
	_play_click()
	if not is_instance_valid(SaveManager):
		return
	if not SaveManager.profile_has_data(profile_id):
		_set_status(tr("profile.delete_empty"))
		return
	_pending_delete_profile = profile_id
	var current_focus := get_viewport().gui_get_focus_owner()
	if current_focus:
		current_focus.release_focus()
	if _confirm_dialog and _confirm_dialog.has_method("show_dialog"):
		_confirm_dialog.show_dialog(
			tr("profile.delete_title"),
			tr("profile.delete_confirm") % profile_id,
			true
		)
	else:
		_do_delete_profile(profile_id)


func _on_confirm_delete() -> void:
	if _pending_delete_profile >= 1:
		var pid := _pending_delete_profile
		_pending_delete_profile = -1
		_do_delete_profile(pid)
	call_deferred("_focus_first_select_button")


func _on_cancel_delete() -> void:
	_pending_delete_profile = -1
	call_deferred("_focus_first_select_button")


func _do_delete_profile(profile_id: int) -> void:
	if not is_instance_valid(SaveManager):
		return
	if SaveManager.delete_profile(profile_id):
		_set_status(tr("profile.delete_success") % profile_id)
		_refresh_card_texts()
	else:
		_set_status(tr("profile.delete_failed") % profile_id)


func _set_status(message: String) -> void:
	if _status_label:
		_status_label.text = message


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
		var delete_btn := Button.new()
		delete_btn.text = tr("profile.delete_button")
		delete_btn.custom_minimum_size = Vector2(0, 36)
		delete_btn.set_meta("is_delete_button", true)
		delete_btn.add_theme_color_override("font_color", Color(0.95, 0.55, 0.5, 1.0))
		delete_btn.pressed.connect(_on_delete_pressed.bind(profile_id))
		vb.add_child(accent)
		vb.add_child(name_l)
		vb.add_child(stats_l)
		vb.add_child(btn)
		vb.add_child(delete_btn)
		margin.add_child(vb)
		panel.add_child(margin)
		panel.set_meta("profile_id", profile_id)
		panel.set_meta("stats_label", stats_l)
		panel.set_meta("delete_button", delete_btn)
		_cards_row.add_child(panel)


func _refresh_card_texts() -> void:
	if not is_instance_valid(SaveManager):
		return
	for panel in _cards_row.get_children():
		if not panel.has_meta("stats_label"):
			continue
		var pid: int = int(panel.get_meta("profile_id", 1))
		var stats_l: Label = panel.get_meta("stats_label")
		var has_data := SaveManager.profile_has_data(pid)
		var s: Dictionary = SaveManager.get_profile_summary(pid)
		var lines: PackedStringArray = PackedStringArray()
		if bool(s.get("has_saves", false)):
			lines.append(tr("profile.saved_slots") % int(s.get("used_slots", 0)))
			var lt: String = str(s.get("latest_save_date", ""))
			if not lt.is_empty():
				lines.append(tr("profile.latest_save") % lt)
			lines.append(tr("profile.longest_play") % LocaleManager.format_playtime_profile(int(s.get("max_playtime", 0))))
			lines.append(tr("profile.total_playtime") % LocaleManager.format_playtime_profile(int(s.get("sum_playtime", 0))))
		elif has_data:
			var v_auto: Dictionary = SaveManager.validate_autosave_file(pid)
			if bool(v_auto.get("valid", false)):
				var metadata: Dictionary = v_auto.get("metadata", {})
				var save_date: String = str(metadata.get("save_date", ""))
				var playtime: int = int(metadata.get("playtime_seconds", 0))
				var scene: String = str(metadata.get("scene", ""))
				var scene_name: String = LocaleManager.get_scene_display_name(scene)
				var playtime_str: String = LocaleManager.format_playtime_slot(playtime)
				var reason: String = str(metadata.get("autosave_reason", ""))
				var reason_suffix: String = (" | " + reason) if not reason.is_empty() else ""
				lines.append(tr("autosave.label_info") % [save_date, scene_name, playtime_str, reason_suffix])
			else:
				lines.append(tr("profile.no_saves_line1"))
				lines.append(tr("profile.no_saves_line2"))
		else:
			lines.append(tr("profile.no_saves_line1"))
			lines.append(tr("profile.no_saves_line2"))
		stats_l.text = "\n".join(lines)
		if panel.has_meta("delete_button"):
			var delete_btn: Button = panel.get_meta("delete_button")
			delete_btn.disabled = not has_data


func _focus_first_select_button() -> void:
	for panel in _cards_row.get_children():
		var margin: MarginContainer = panel.get_child(0) as MarginContainer
		if margin == null:
			continue
		var vb: VBoxContainer = margin.get_child(0) as VBoxContainer
		if vb == null:
			continue
		for ch in vb.get_children():
			if ch is Button and not bool(ch.get_meta("is_delete_button", false)):
				(ch as Button).grab_focus()
				return
	if _back_button:
		_back_button.grab_focus()


func _play_click() -> void:
	if is_instance_valid(SoundManager) and SoundManager.has_method("play_ui"):
		SoundManager.play_ui("click")
