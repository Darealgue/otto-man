extends Control
class_name VillageCardDraftUI
## Köy roguelite kart sistemi — yol seçimi + kart draft popup'ı.
## Mentor'un sunduğu bir öneri gibi sunulur; parşömen temalı, tam ekran.
## Zorunlu seçim: ESC/dim-click ile kapatılamaz (draft/yol seçimi mutlaka yapılmalı).

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")

const PATH_TAGLINES := {
	"eskiya": "Yağma, risk, hızlı kazanç. Köyün gölgede büyür.",
	"pasa": "Diplomasi, altın, prestij. Köyün sarayın gölgesinde büyür.",
	"koylu": "Emek, denge, sabır. Köyün kendi gücüyle büyür.",
}

var _panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _card_row: HBoxContainer
var _is_open := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = _MEDIEVAL_THEME
	_build_ui()
	visible = false
	call_deferred("_reapply_full_rect")
	call_deferred("_connect_card_manager")


func _reapply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _connect_card_manager() -> void:
	var cm = get_node_or_null("/root/VillageCardManager")
	if cm == null:
		return
	if not cm.path_choice_ready.is_connected(_on_path_choice_ready):
		cm.path_choice_ready.connect(_on_path_choice_ready)
	if not cm.draft_ready.is_connected(_on_draft_ready):
		cm.draft_ready.connect(_on_draft_ready)
	# Yükleme sonrası bekleyen bir seçim varsa hemen göster.
	if cm.pending_choice_type == "path":
		_on_path_choice_ready()
	elif cm.pending_choice_type == "draft" and not cm.pending_draft_cards.is_empty():
		_on_draft_ready(cm.pending_draft_cards)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.02, 0.01, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5; _panel.anchor_right = 0.5
	_panel.anchor_top = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left = -560
	_panel.offset_right = 560
	_panel.offset_top = -320
	_panel.offset_bottom = 320
	ParchmentTextures.apply_large_panel_style(_panel, 24)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	_panel.add_child(root)

	_title_label = Label.new()
	_title_label.text = "Mentor'un Önerisi"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	root.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 14)
	_subtitle_label.modulate = Color(1, 1, 1, 0.75)
	root.add_child(_subtitle_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	root.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 480)
	root.add_child(scroll)

	_card_row = HBoxContainer.new()
	_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.add_theme_constant_override("separation", 16)
	scroll.add_child(_card_row)

	var hint := Label.new()
	hint.text = "Bir seçenek belirle — görülüp seçilmeyenler bu oyunda bir daha çıkmaz."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.5)
	root.add_child(hint)

	TextOutline.apply_to_tree(self)


func _clear_cards() -> void:
	for child in _card_row.get_children():
		child.queue_free()


func _make_option_card(name_text: String, desc_text: String, tag_text: String, on_press: Callable) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 420)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.12, 0.08, 0.85)
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.7, 0.55, 0.3, 0.9)
	sb.corner_radius_top_left = 10; sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10; sb.corner_radius_bottom_right = 10
	sb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	if tag_text != "":
		var tag := Label.new()
		tag.text = tag_text
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 11)
		tag.modulate = Color(0.95, 0.78, 0.4)
		col.add_child(tag)

	var title := Label.new()
	title.text = name_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 18)
	col.add_child(title)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.6, 0.47, 0.28, 0.5)
	col.add_child(sep)

	var desc := Label.new()
	desc.text = desc_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.modulate = Color(1, 1, 1, 0.85)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(desc)

	var btn := Button.new()
	btn.text = "Seç"
	btn.custom_minimum_size = Vector2(0, 40)
	btn.pressed.connect(on_press)
	col.add_child(btn)

	return card


# ─── Yol seçimi ─────────────────────────────────────────────────────────────

func _on_path_choice_ready() -> void:
	_title_label.text = "Köyün Yolu"
	_subtitle_label.text = "Nüfusun büyüdü. Köyün nasıl büyüyeceğini seç — bu seçim, önünde açılacak kart yolunu belirler."
	_clear_cards()
	for path_key in ["eskiya", "pasa", "koylu"]:
		var pname := VillageCardDatabase.get_path_display_name(path_key)
		var tagline := String(PATH_TAGLINES.get(path_key, ""))
		var card := _make_option_card(pname, tagline, "YOL", _on_path_selected.bind(path_key))
		_card_row.add_child(card)
	_show()


func _on_path_selected(path_key: String) -> void:
	var cm = get_node_or_null("/root/VillageCardManager")
	if cm:
		cm.choose_path(path_key)
	# start_draft() aynı çağrı içinde draft_ready sinyalini tetikleyip _on_draft_ready'yi çağırır.


# ─── Kart draftı ────────────────────────────────────────────────────────────

func _on_draft_ready(cards: Array) -> void:
	var cm = get_node_or_null("/root/VillageCardManager")
	var is_dilemma: bool = bool(cm.pending_is_dilemma_draft) if cm else false
	var path_name: String = VillageCardDatabase.get_path_display_name(String(cm.chosen_path)) if cm else ""

	if is_dilemma:
		_title_label.text = "İkilem"
		_subtitle_label.text = "%s yolunun bir dönüm noktası — sadece biri seçilebilir." % path_name
	else:
		_title_label.text = "Yeni Kart"
		_subtitle_label.text = "%s yolundan bir kart seç." % path_name

	_clear_cards()
	for card in cards:
		var cid := String(card.get("id", ""))
		var cname := String(card.get("name", "?"))
		var cdesc := String(card.get("desc", ""))
		var card_path := String(card.get("path", ""))
		var tag := "İKİLEM" if is_dilemma else VillageCardDatabase.get_path_display_name(card_path).to_upper()
		if not is_dilemma and card_path != cm.chosen_path:
			tag = "WILDCARD · " + VillageCardDatabase.get_path_display_name(card_path).to_upper()
		var option := _make_option_card(cname, cdesc, tag, _on_card_selected.bind(cid))
		_card_row.add_child(option)
	_show()


func _on_card_selected(card_id: String) -> void:
	var cm = get_node_or_null("/root/VillageCardManager")
	if cm:
		cm.choose_card(card_id)
	_hide()


# ─── Görünürlük ─────────────────────────────────────────────────────────────

func _show() -> void:
	_reapply_full_rect()
	_is_open = true
	visible = true
	call_deferred("_grab_initial_focus")


func _hide() -> void:
	_is_open = false
	visible = false


func _grab_initial_focus() -> void:
	for child in _card_row.get_children():
		var btn := _find_first_button(child)
		if btn:
			btn.grab_focus()
			return


func _find_first_button(node: Node) -> Button:
	if node is Button:
		return node as Button
	for child in node.get_children():
		var found := _find_first_button(child)
		if found:
			return found
	return null


# Zorunlu seçim: dim-click ve ESC bilerek bağlanmadı — kart/yol seçimi
# yapılmadan bu popup kapanmaz. ui_cancel/ui_back'i (ESC de buraya dahil) burada tüketip
# alttaki menülerin (pause menüsü dahil) açılmasını da önlüyoruz.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		get_viewport().set_input_as_handled()
