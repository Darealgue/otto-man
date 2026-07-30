extends CanvasLayer
## Ekran altı tutorial metni. Boyut 1920×1080 tasarımına göre ölçeklenir.

const DESIGN_VIEWPORT := Vector2(1920.0, 1080.0)
## 360px texture: yatay orta ~280px; 780 genişlik ≈ 2.5× esneme (1040 = 3.4× bozuyordu).
const DESIGN_BAR_SIZE := Vector2(780.0, 320.0)
## Box can grow taller than DESIGN_BAR_SIZE.y to fit longer messages, up to this design-space cap.
const DESIGN_BAR_MAX_HEIGHT := 620.0
## Bottom resource bar occupies the screen's bottom 56px (VillageStatusUI.tscn TopBarPanel) —
## this must clear that plus a visible gap, or the speech bar sits partially behind it.
const DESIGN_BOTTOM_MARGIN := 76.0
const DESIGN_FONT_SIZE := 22
## "Devam etmek için yukarı bas" ikonu — kutunun sağ-alt köşesinde, tasarım karesi 34px.
const DESIGN_CONTINUE_ICON_SIZE := 34.0
const DESIGN_CONTINUE_ICON_MARGIN := 16.0

@onready var _panel: Control = $Frame
@onready var _rich: RichTextLabel = %SpeechRichText
@onready var _continue_icon: TextureRect = %ContinueHintIcon

var _highlight: Control
var _current_scale: float = 1.0
## Design-space height added on top of DESIGN_BAR_SIZE.y to fit the current message's content.
var _content_extra_height: float = 0.0


func _ready() -> void:
	layer = 95
	if is_instance_valid(_rich):
		_rich.bbcode_enabled = true
		_rich.add_theme_color_override("default_color", TextOutline.FONT_COLOR)
		_rich.add_theme_constant_override("outline_size", 0)
		_rich.add_theme_constant_override("line_separation", 5)
	_setup_highlight()
	TextOutline.apply_to_tree(self)
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
	_current_scale = s
	var w := DESIGN_BAR_SIZE.x * s
	var design_h := clampf(DESIGN_BAR_SIZE.y + _content_extra_height, DESIGN_BAR_SIZE.y, DESIGN_BAR_MAX_HEIGHT)
	var h := design_h * s
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
		var fs := int(round(DESIGN_FONT_SIZE * s))
		_rich.add_theme_font_size_override("normal_font_size", fs)
		_rich.add_theme_font_size_override("bold_font_size", fs)
		_rich.add_theme_font_size_override("bold_italics_font_size", fs)
		_rich.add_theme_font_size_override("italics_font_size", fs)
	if is_instance_valid(_continue_icon):
		var icon_size := DESIGN_CONTINUE_ICON_SIZE * s
		var icon_margin := DESIGN_CONTINUE_ICON_MARGIN * s
		_continue_icon.anchor_left = 1.0
		_continue_icon.anchor_top = 1.0
		_continue_icon.anchor_right = 1.0
		_continue_icon.anchor_bottom = 1.0
		_continue_icon.offset_left = -(icon_size + icon_margin)
		_continue_icon.offset_top = -(icon_size + icon_margin)
		_continue_icon.offset_right = -icon_margin
		_continue_icon.offset_bottom = -icon_margin


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


func _setup_highlight() -> void:
	if not is_instance_valid(_panel):
		return
	var h := preload("res://ui/PulsingHighlight.gd").new()
	add_child(h)
	h.follow(_panel)
	_highlight = h


## Every caller in the game — new mentor lines, and in-place text swaps like the movement/
## combat tutorial progress prompts — funnels through this one function, so this is the single
## place that needs to notice "the text actually changed" and pulse, regardless of which
## system triggered the change.
func set_speech_bbcode(bbcode: String) -> void:
	if is_instance_valid(_rich):
		var normalized := _normalize_speech_bbcode(bbcode)
		var changed := normalized != _rich.text
		_rich.text = normalized
		if is_instance_valid(_highlight):
			if normalized.is_empty():
				_highlight.stop_pulse()
			elif changed:
				_highlight.pulse_once_then_hold()
		if normalized.is_empty():
			_content_extra_height = 0.0
			_apply_bar_layout()
		else:
			_refresh_content_height.call_deferred()
	_apply_visibility()


## Grows the box (up to DESIGN_BAR_MAX_HEIGHT) when the current message needs more room than
## it has, instead of silently clipping the tail of longer messages.
func _refresh_content_height() -> void:
	if not is_instance_valid(_rich) or not is_instance_valid(_panel):
		return
	await get_tree().process_frame
	var needed := _rich.get_content_height()
	var available := _rich.size.y
	if needed <= available + 1.0:
		return
	var overflow := needed - available
	var design_overflow := overflow / maxf(0.001, _current_scale)
	var new_extra := clampf(_content_extra_height + design_overflow, 0.0, DESIGN_BAR_MAX_HEIGHT - DESIGN_BAR_SIZE.y)
	if not is_equal_approx(new_extra, _content_extra_height):
		_content_extra_height = new_extra
		_apply_bar_layout()


func clear_speech() -> void:
	set_speech_bbcode("")


func _normalize_speech_bbcode(bbcode: String) -> String:
	# CSV çevirilerindeki literal "\n" (backslash+n) Godot'un import sürecinde gerçek
	# satır sonuna dönüşmüyor; burada elle çeviriyoruz, aksi halde metin tek satırda
	# kutunun dışına taşıyor ("\n" karakterleri de ekranda görünüyor).
	var out := bbcode.replace("\\n", "\n")
	var re := RegEx.new()
	if re.compile("(?i)\\[color=#c8c8c8\\](.*?)\\[/color\\]") != OK:
		return out
	return re.sub(out, "$1", true)


func _apply_visibility() -> void:
	var has_text := false
	if is_instance_valid(_rich):
		has_text = not String(_rich.text).strip_edges().is_empty()
	if is_instance_valid(_panel):
		_panel.visible = has_text
