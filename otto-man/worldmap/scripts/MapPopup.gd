class_name MapPopup
extends Control
## Dünya haritası diyalogları için ortak kutu: karartma + ortalanmış koyu panel, altın başlık,
## ayraç, içerik ve ortalı butonlar. Oyunun diğer popup'larıyla (kamp ateşi, falcı) aynı dil.
## ConfirmationDialog/AcceptDialog yüzeyini taklit eder (title, dialog_text, get_ok_button...),
## böylece WorldMapScene'deki çağrı noktaları neredeyse olduğu gibi kalır.

signal confirmed
signal canceled

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")

const COLOR_TITLE := Color(0.96, 0.84, 0.52, 1.0)
const COLOR_TEXT := Color(0.93, 0.91, 0.86, 1.0)
const COLOR_MUTED := Color(0.72, 0.69, 0.63, 1.0)
const COLOR_WARNING := Color(0.95, 0.52, 0.45, 1.0)
const COLOR_DIVIDER := Color(0.6, 0.47, 0.28, 0.85)

const TITLE_FONT_SIZE := 34
const BODY_FONT_SIZE := 22
const BUTTON_FONT_SIZE := 22
const CHIP_FONT_SIZE := 20
const BUTTON_MIN_SIZE := Vector2(190, 52)
const PANEL_MARGIN := 30

var title: String = "":
	set(v):
		title = v
		if _title_label:
			_title_label.text = v
var dialog_text: String = "":
	set(v):
		dialog_text = v
		if _body_label:
			_body_label.text = v
			_body_label.visible = not v.is_empty()
## Panelin iç genişliği; uzun metinler bu genişliğe göre sarılır.
var panel_width: int = 760:
	set(v):
		panel_width = v
		if _panel:
			_panel.custom_minimum_size.x = v
## OK'a basınca kendiliğinden kapansın mı? (zar penceresi kapanmaz, kendi akışını yürütür)
var hide_on_ok: bool = true

var _dim: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _content: VBoxContainer
var _button_row: HBoxContainer
var _ok_button: Button
var _cancel_button: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = _MEDIEVAL_THEME
	z_index = 50
	visible = false
	_build()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.04, 0.03, 0.02, 0.6)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(panel_width, 0)
	ParchmentTextures.apply_large_panel_style(_panel, PANEL_MARGIN)
	center.add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	_panel.add_child(root)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE)
	root.add_child(_title_label)

	root.add_child(make_divider())

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	root.add_child(_content)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	_body_label.add_theme_color_override("font_color", COLOR_TEXT)
	_body_label.visible = false
	_content.add_child(_body_label)

	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", 20)
	root.add_child(_button_row)

	_ok_button = _make_button(true)
	_ok_button.pressed.connect(_on_ok_pressed)
	_button_row.add_child(_ok_button)
	_cancel_button = _make_button(false)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_button_row.add_child(_cancel_button)
	_cancel_button.visible = false

	_ok_button.focus_neighbor_right = _ok_button.get_path_to(_cancel_button)
	_cancel_button.focus_neighbor_left = _cancel_button.get_path_to(_ok_button)


func _make_button(primary: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = BUTTON_MIN_SIZE
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	if primary:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.36, 0.26, 0.1, 1.0)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.85, 0.68, 0.3, 1.0)
		sb.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal", sb)
	return b


## --- AcceptDialog/ConfirmationDialog uyumluluk yüzeyi ---

func get_ok_button() -> Button:
	return _ok_button


func get_cancel_button() -> Button:
	return _cancel_button


## Tek butonlu (AcceptDialog benzeri) kullanım için iptal butonunu kapatır/açar.
func set_cancel_enabled(enabled: bool) -> void:
	_cancel_button.visible = enabled


## Mission penceresi gibi kendi butonlarını içeriğe koyan kullanımlar için.
func set_buttons_visible(shown: bool) -> void:
	_button_row.visible = shown


func set_ok_text(text: String) -> void:
	_ok_button.text = text


func set_cancel_text(text: String) -> void:
	_cancel_button.text = text
	_cancel_button.visible = true


## Düz metin gövdesi yerine kendi içeriğini koymak için.
func add_content(node: Control) -> void:
	_content.add_child(node)


func set_body_visible(shown: bool) -> void:
	_body_label.visible = shown and not dialog_text.is_empty()


func popup_centered(_size: Vector2i = Vector2i.ZERO) -> void:
	_show()


func popup_centered_clamped(_size: Vector2i = Vector2i.ZERO, _ratio: float = 0.8) -> void:
	_show()


func hide_popup() -> void:
	hide()


func _show() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = true
	call_deferred("_grab_focus")


func _grab_focus() -> void:
	if not visible:
		return
	if _button_row.visible and _ok_button.visible and not _ok_button.disabled:
		_ok_button.grab_focus()
		return
	var first := _find_first_enabled_button(_content)
	if first:
		first.grab_focus()


func _find_first_enabled_button(node: Node) -> Button:
	if node is Button and not (node as Button).disabled and (node as Button).focus_mode != Control.FOCUS_NONE:
		return node as Button
	for c in node.get_children():
		var found := _find_first_enabled_button(c)
		if found:
			return found
	return null


func _on_ok_pressed() -> void:
	if hide_on_ok:
		hide()
	confirmed.emit()


func _on_cancel_pressed() -> void:
	hide()
	canceled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# ui_back = ESC'nin bağlı olduğu aksiyon (ui_cancel yalnızca META/gamepad B içeriyor).
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()
		return
	# Kutu açıkken harita girdisi arkaya sızmasın.
	get_viewport().set_input_as_handled()


## --- Ortak yapı taşları (çağıran sahneler de kullanır) ---

static func make_divider() -> ColorRect:
	var d := ColorRect.new()
	d.custom_minimum_size = Vector2(0, 2)
	d.color = COLOR_DIVIDER
	return d


## Küçük bilgi etiketi: kenarlıklı koyu hap.
static func make_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.15, 0.08, 0.95)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.78, 0.64, 0.32, 1.0)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	chip.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", CHIP_FONT_SIZE)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	chip.add_child(lbl)
	return chip
