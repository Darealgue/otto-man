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
## Normal balon şeffaflığı; combat objective adımlarından bazıları (ör. düşüş saldırısı) balonu
## geçici olarak bunun altına indirir, çünkü balon o an düşmanın önüne geçebiliyor.
const NORMAL_PANEL_ALPHA := 1.0

@onready var _panel: Control = $Frame
## Resolved in _ready() rather than via `@onready var x = %Name`.
##
## Both of these nodes live INSIDE the instanced parchment_frame.tscn sub-scene, and a node added
## into an instanced sub-scene does not reliably keep its unique-name registration once the scene
## is loaded from the binary .scn in an exported build. In the editor `%SpeechRichText` resolved
## fine; in the export it failed with "Node not found", leaving _rich null — and because
## _apply_visibility() hides the panel whenever the text is empty, the entire mentor speech bar
## silently never appeared. Nothing was logged beyond that one line.
##
## _resolve_child_nodes() therefore tries the unique name, then the explicit path, then a
## recursive search by name, so a future scene reshuffle cannot reintroduce this either.
var _rich: RichTextLabel = null
var _continue_icon: TextureRect = null

var _highlight: Control
var _current_scale: float = 1.0
## Design-space height added on top of DESIGN_BAR_SIZE.y to fit the current message's content.
var _content_extra_height: float = 0.0


## Finds a descendant by unique name, then by explicit path, then by recursive search.
## `owned = false` on the recursive search matters: nodes living inside an instanced sub-scene are
## not owned by this scene root, so an owned-only search would miss exactly the nodes at issue.
func _resolve_child(unique_name: String, explicit_path: String) -> Node:
	var found := get_node_or_null("%" + unique_name)
	if found != null:
		return found
	found = get_node_or_null(explicit_path)
	if found != null:
		return found
	return find_child(unique_name, true, false)


func _resolve_child_nodes() -> void:
	_rich = _resolve_child("SpeechRichText", "Frame/Margin/SpeechRichText") as RichTextLabel
	_continue_icon = _resolve_child("ContinueHintIcon", "Frame/ContinueHintIcon") as TextureRect
	if _rich == null:
		_rich = _create_rich_label()


## Builds the speech label from scratch when the scene's own copy is missing.
##
## TutorialSpeechBar.tscn declares SpeechRichText with parent="Frame/Margin" — that is, parented
## INTO the instanced parchment_frame.tscn rather than onto the instance's root. Godot only keeps
## such a node if the instance is marked `editable_instance`, and this scene is not. The editor
## honours it anyway, so it works in-editor; the exporter drops the node, and the mentor speech bar
## silently never appeared in the exported build (empty text hides the whole panel).
##
## Rather than depend on that scene-format subtlety continuing to behave, the bar recreates the
## label with the same properties the .tscn sets. If the scene copy is ever fixed or restored, the
## resolver above finds it first and this never runs.
func _create_rich_label() -> RichTextLabel:
	var slot: Node = get_node_or_null("Frame/Margin")
	if slot == null:
		slot = get_node_or_null("Frame")
	if slot == null:
		push_error("[TutorialSpeechBar] No Frame to attach the speech label to; mentor lines cannot display.")
		return null

	var label := RichTextLabel.new()
	label.name = "SpeechRichText"
	# Mirrors TutorialSpeechBar.tscn's own settings for this node.
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.bbcode_enabled = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.scroll_active = false
	label.text = ""
	slot.add_child(label)
	print("[TutorialSpeechBar] Scene copy of SpeechRichText was missing; rebuilt it under %s." % slot.name)
	return label


func _ready() -> void:
	_resolve_child_nodes()
	layer = 95
	# This bar overlays live gameplay (dungeon/combat behind it), unlike full-screen menus, so
	# it uses a translucent background instead of the default opaque parchment fill.
	var parchment_frame := _panel as ParchmentFrame
	if parchment_frame:
		parchment_frame.parchment_texture = ParchmentTextures.get_flat_panel_texture_translucent()
		parchment_frame.apply_style_now()
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
	if not is_inside_tree():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var vp := viewport.get_visible_rect().size
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
	if not is_inside_tree() or get_viewport() == null:
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
	if not is_instance_valid(_rich) or not is_instance_valid(_panel) or not is_inside_tree():
		return
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


## Balonun saydamlığını ayarlar (0.0-1.0). Ör. düşüş saldırısı adımında balon düşmanın önüne
## geçebildiği için Director burayı geçici olarak düşürür, adım bitince NORMAL_PANEL_ALPHA'ya
## geri döner.
func set_panel_opacity(alpha: float) -> void:
	if is_instance_valid(_panel):
		_panel.modulate.a = alpha


func clear_speech() -> void:
	set_speech_bbcode("")
	set_panel_opacity(NORMAL_PANEL_ALPHA)


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
