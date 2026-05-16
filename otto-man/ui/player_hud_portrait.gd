extends Control
## Oyuncu HUD portresi: 512x512 kaynaktan kirp + CPU daire maskesi (piksel-perfect).

enum PortraitMood { IDLE, HAPPY, ANGRY }

const DEBUG_PORTRAIT_HUD: bool = false

@export_group("Textures (512x512 kaynak)")
@export var texture_idle: Texture2D
@export var texture_happy: Texture2D
@export var texture_angry: Texture2D

@export_group("Crop")
@export var portrait_region: Rect2i = Rect2i(189, 303, 110, 110)

@export_group("Display")
@export_range(1, 4, 1) var pixel_scale: int = 1

@export_group("Frame")
@export var frame_border_width: int = 3
@export var frame_border_color: Color = Color(0.85, 0.72, 0.38, 1.0)

@export_group("Debug")
@export var debug_enabled: bool = false

@export_group("Timing")
@export var expression_hold_seconds: float = 2.5

@onready var _portrait: TextureRect = $PortraitImage
@onready var _frame: Panel = $PortraitFrame

var _portraits: Dictionary = {}
var _current: PortraitMood = PortraitMood.IDLE
var _hold_token: int = 0
var _display_size: int = 110
var _circle_mask_enabled: bool = true
var _debug_label: Label


func _ready() -> void:
	_portrait.material = null
	_sync_display_size()
	_apply_pixel_perfect_portrait()
	_apply_frame_style()
	_rebuild_portraits()
	set_expression(PortraitMood.IDLE, true)
	if _is_debug():
		set_process_unhandled_input(true)
		_setup_debug_label()
		call_deferred("_run_debug_pass", "ready")


func _is_debug() -> bool:
	return DEBUG_PORTRAIT_HUD or debug_enabled


func _dlog(msg: String) -> void:
	if _is_debug():
		print("[PortraitHUD] ", msg)


func _setup_debug_label() -> void:
	_debug_label = Label.new()
	_debug_label.name = "DebugLabel"
	_debug_label.z_index = 20
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
	_debug_label.add_theme_font_size_override("font_size", 11)
	add_child(_debug_label)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_debug():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			_run_debug_pass("F10")
		elif event.keycode == KEY_F11:
			_circle_mask_enabled = not _circle_mask_enabled
			_rebuild_portraits()
			set_expression(_current, true)
			_run_debug_pass("F11 mask=%s" % _circle_mask_enabled)


func _run_debug_pass(reason: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_debug_sample_texture_alpha(reason)


func _debug_sample_texture_alpha(reason: String) -> void:
	if not _is_debug() or _portrait == null or _portrait.texture == null:
		return
	var tex: Texture2D = _portrait.texture
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		_dlog("[%s] texture Image alinamadi" % reason)
		return
	var w: int = img.get_width()
	var h: int = img.get_height()
	var tl: float = img.get_pixel(0, 0).a
	var tr: float = img.get_pixel(w - 1, 0).a
	var bl: float = img.get_pixel(0, h - 1).a
	var br: float = img.get_pixel(w - 1, h - 1).a
	var ok: bool = tl < 0.05 and tr < 0.05 and bl < 0.05 and br < 0.05
	_dlog(
		"[%s] ALPHA %dx%d TL=%.2f TR=%.2f BL=%.2f BR=%.2f | %s"
		% [reason, w, h, tl, tr, bl, br, "DAIRE OK" if ok else "HATA"]
	)
	if _debug_label:
		_debug_label.text = (
			"mask=%s | %s\nALPHA corners TL%.2f TR%.2f BL%.2f BR%.2f"
			% [_circle_mask_enabled, "OK" if ok else "FAIL", tl, tr, bl, br]
		)
		_debug_label.position = Vector2(0, _display_size + 2)


func _sync_display_size() -> void:
	var src: Vector2i = portrait_region.size
	_display_size = src.x * pixel_scale
	custom_minimum_size = Vector2(_display_size, _display_size)
	size = custom_minimum_size


func _apply_pixel_perfect_portrait() -> void:
	if _portrait == null:
		return
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.offset_left = 0.0
	_portrait.offset_top = 0.0
	_portrait.offset_right = 0.0
	_portrait.offset_bottom = 0.0
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP
	_portrait.scale = Vector2.ONE * float(pixel_scale)


func _apply_frame_style() -> void:
	if _frame == null:
		return
	var r: float = float(_display_size) * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = frame_border_width
	style.border_width_top = frame_border_width
	style.border_width_right = frame_border_width
	style.border_width_bottom = frame_border_width
	style.border_color = frame_border_color
	style.set_corner_radius_all(int(r))
	style.draw_center = false
	_frame.add_theme_stylebox_override("panel", style)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.z_index = 1


func _rebuild_portraits() -> void:
	_portraits.clear()
	_portraits[PortraitMood.IDLE] = _build_portrait_texture(texture_idle)
	_portraits[PortraitMood.HAPPY] = _build_portrait_texture(texture_happy)
	_portraits[PortraitMood.ANGRY] = _build_portrait_texture(texture_angry)
	_apply_texture_for(_current)


func _build_portrait_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var full: Image = source.get_image()
	if full.is_empty():
		return null
	var cropped: Image = full.get_region(portrait_region)
	if cropped.is_empty():
		return null
	if cropped.get_format() != Image.FORMAT_RGBA8:
		cropped = cropped.duplicate()
		cropped.convert(Image.FORMAT_RGBA8)
	if _circle_mask_enabled:
		_apply_circle_mask_inplace(cropped)
	return ImageTexture.create_from_image(cropped)


func _apply_circle_mask_inplace(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var cx: float = (float(w) - 1.0) * 0.5
	var cy: float = (float(h) - 1.0) * 0.5
	var radius: float = minf(cx, cy)
	var radius_sq: float = radius * radius
	for y in h:
		for x in w:
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			if dx * dx + dy * dy > radius_sq:
				var c: Color = img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))


func set_expression(expr: PortraitMood, immediate: bool = false) -> void:
	_current = expr
	_apply_texture_for(expr)
	if immediate:
		return
	_hold_token += 1
	var token: int = _hold_token
	var t: SceneTreeTimer = get_tree().create_timer(expression_hold_seconds)
	t.timeout.connect(func() -> void:
		if token == _hold_token and _current == expr:
			set_expression(PortraitMood.IDLE, true)
	)


func flash_happy() -> void:
	set_expression(PortraitMood.HAPPY)


func flash_angry() -> void:
	set_expression(PortraitMood.ANGRY)


func _apply_texture_for(expr: PortraitMood) -> void:
	if _portrait == null:
		return
	_portrait.texture = _portraits.get(expr, null)


func refresh_atlases() -> void:
	_sync_display_size()
	_apply_pixel_perfect_portrait()
	_rebuild_portraits()
	_apply_texture_for(_current)
