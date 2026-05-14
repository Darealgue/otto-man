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


func show_menu(intent: MenuIntent) -> void:
	_intent = intent
	match intent:
		MenuIntent.NEW_GAME:
			_title.text = "Yeni oyun"
			_sub.text = "Bu bilgisayarda üç ayrı oyuncu profili vardır. Her profilin kayıtları birbirinden bağımsızdır."
		MenuIntent.LOAD:
			_title.text = "Oyuncu profili"
			_sub.text = "Hangi profildeki kayıtları yüklemek istiyorsun?"
	_refresh_card_texts()
	visible = true
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	call_deferred("_focus_first_select_button")


func hide_menu() -> void:
	visible = false


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
		name_l.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
		name_l.text = "Profil %d" % profile_id
		var stats_l := Label.new()
		stats_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stats_l.add_theme_font_size_override("font_size", 16)
		stats_l.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		var btn := Button.new()
		btn.text = "Bu profili seç"
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
			lines.append("Kayıtlı slot: %d / 5" % int(s.get("used_slots", 0)))
			var lt: String = str(s.get("latest_save_date", ""))
			if not lt.is_empty():
				lines.append("Son kayıt: %s" % lt)
			lines.append("En uzun oyun: %s" % _format_playtime(int(s.get("max_playtime", 0))))
			lines.append("Slotlar toplam süre: %s" % _format_playtime(int(s.get("sum_playtime", 0))))
		else:
			lines.append("Henüz kayıt yok.")
			lines.append("Bu profil temiz — yeni maceraya hazır.")
		stats_l.text = "\n".join(lines)


func _format_playtime(seconds: int) -> String:
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	if hours > 0:
		return "%d sa %02d dk" % [hours, minutes]
	if minutes > 0:
		return "%d dk" % minutes
	return "%d sn" % maxi(1, seconds)


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
