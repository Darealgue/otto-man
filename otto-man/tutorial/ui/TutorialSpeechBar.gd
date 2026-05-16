extends CanvasLayer
## Ekran altı tutorial metni. Boyut 1920×1080 tasarımına göre ölçeklenir.

const DESIGN_VIEWPORT := Vector2(1920.0, 1080.0)
## 360px texture: yatay orta ~280px; 780 genişlik ≈ 2.5× esneme (1040 = 3.4× bozuyordu).
const DESIGN_BAR_SIZE := Vector2(780.0, 264.0)
const DESIGN_BOTTOM_MARGIN := 36.0
const DESIGN_FONT_SIZE := 24

@onready var _panel: Control = $Frame
@onready var _rich: RichTextLabel = %SpeechRichText


func _ready() -> void:
	layer = 95
	if is_instance_valid(_rich):
		_rich.bbcode_enabled = true
		_rich.add_theme_color_override("default_color", TextOutline.FONT_COLOR)
		_rich.add_theme_constant_override("outline_size", 0)
	var root := get_tree().root
	if not root.size_changed.is_connected(_apply_bar_layout):
		root.size_changed.connect(_apply_bar_layout)
	_apply_bar_layout()
	_apply_visibility()


func _apply_bar_layout() -> void:
	var frame := $Frame as Control
	if frame == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var s := minf(vp.x / DESIGN_VIEWPORT.x, vp.y / DESIGN_VIEWPORT.y)
	s = maxf(s, 0.5)
	var w := DESIGN_BAR_SIZE.x * s
	var h := DESIGN_BAR_SIZE.y * s
	var bottom := DESIGN_BOTTOM_MARGIN * s
	frame.anchor_left = 0.5
	frame.anchor_top = 1.0
	frame.anchor_right = 0.5
	frame.anchor_bottom = 1.0
	frame.offset_left = -w * 0.5
	frame.offset_right = w * 0.5
	frame.offset_top = -(h + bottom)
	frame.offset_bottom = -bottom
	frame.custom_minimum_size = Vector2(520.0 * s, 168.0 * s)
	if is_instance_valid(_rich):
		_rich.add_theme_font_size_override("normal_font_size", int(round(DESIGN_FONT_SIZE * s)))


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_F9:
		return
	get_viewport().set_input_as_handled()
	var parchment := $Frame as ParchmentFrame
	if parchment == null:
		return
	parchment.debug_layout = not parchment.debug_layout
	var vp := get_viewport().get_visible_rect().size
	print(
		"[TutorialSpeechBar] debug=%s viewport=%.0fx%.0f bar=%.0fx%.0f (F9)"
		% [parchment.debug_layout, vp.x, vp.y, _panel.size.x, _panel.size.y]
	)


func set_speech_bbcode(bbcode: String) -> void:
	if is_instance_valid(_rich):
		_rich.text = bbcode
	_apply_visibility()


func clear_speech() -> void:
	set_speech_bbcode("")


func _apply_visibility() -> void:
	var has_text := false
	if is_instance_valid(_rich):
		has_text = not String(_rich.text).strip_edges().is_empty()
	if is_instance_valid(_panel):
		_panel.visible = has_text
