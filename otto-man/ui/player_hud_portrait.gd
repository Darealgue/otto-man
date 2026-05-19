extends Control
## Oyuncu HUD portresi: 110px kaynak boyutu korunur, cerceve 1:1, yuz daire maskeli.

enum PortraitMood { IDLE, HAPPY, ANGRY, COIN }

@export_group("Textures (512x512 kaynak)")
@export var texture_idle: Texture2D
@export var texture_hurt1: Texture2D
@export var texture_hurt2: Texture2D
@export var texture_happy: Texture2D
@export var texture_angry: Texture2D
@export var texture_coin: Texture2D

@export_group("Health portrait")
@export_range(0.0, 1.0, 0.01) var hurt1_threshold: float = 0.66
@export_range(0.0, 1.0, 0.01) var hurt2_threshold: float = 0.33

@export_group("Crop")
@export var portrait_region: Rect2i = Rect2i(189, 303, 110, 110)

@export_group("Display")
@export_range(1, 4, 1) var pixel_scale: int = 1

@export_group("Frame")
@export var texture_frame: Texture2D
@export var frame_inner_offset: Vector2 = Vector2.ZERO

@export_group("Timing")
@export var expression_hold_seconds: float = 2.5 / 3.0

@onready var _portrait: TextureRect = $PortraitImage
@onready var _frame: TextureRect = $PortraitFrame

var _portraits: Dictionary = {}
var _current: PortraitMood = PortraitMood.IDLE
var _hold_token: int = 0
var _display_size: int = 110
var _circle_mask_enabled: bool = true
var _health_percent: float = 1.0


func _ready() -> void:
	_portrait.material = null
	_apply_layout()
	_rebuild_portraits()
	set_expression(PortraitMood.IDLE, true)


func _apply_layout() -> void:
	_sync_display_size()
	_apply_frame_sprite()
	_apply_pixel_perfect_portrait()


func _sync_display_size() -> void:
	_display_size = portrait_region.size.x * pixel_scale
	if texture_frame != null:
		custom_minimum_size = HudLayout.get_health_display_size()
	else:
		custom_minimum_size = Vector2(_display_size, _display_size)
	size = custom_minimum_size


func _apply_pixel_perfect_portrait() -> void:
	if _portrait == null:
		return
	var face: Rect2 = HudLayout.get_face_rect_local()
	face.position += frame_inner_offset
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP
	_portrait.scale = Vector2.ONE
	_portrait.position = face.position
	_portrait.size = face.size
	_portrait.z_index = 1


func _apply_frame_sprite() -> void:
	if _frame == null:
		return
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.z_index = 0
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_KEEP
	_frame.scale = Vector2.ONE
	if texture_frame == null:
		_frame.visible = false
		return
	_frame.visible = true
	_frame.texture = texture_frame
	_frame.position = HudLayout.get_frame_draw_offset()
	_frame.size = HudLayout.FRAME_TEXTURE_SIZE
	clip_contents = false


func _rebuild_portraits() -> void:
	_portraits.clear()
	_rebuild_idle_texture()
	_portraits[PortraitMood.HAPPY] = _build_portrait_texture(texture_happy)
	_portraits[PortraitMood.ANGRY] = _build_portrait_texture(texture_angry)
	_portraits[PortraitMood.COIN] = _build_portrait_texture(texture_coin)
	_apply_texture_for(_current)


func update_health_portrait(current_health: float, max_health: float) -> void:
	if not is_inside_tree():
		return
	var max_hp: float = maxf(max_health, 1.0)
	_health_percent = clampf(current_health / max_hp, 0.0, 1.0)
	_rebuild_idle_texture()
	if _current == PortraitMood.IDLE:
		_apply_texture_for(PortraitMood.IDLE)


func _rebuild_idle_texture() -> void:
	_portraits[PortraitMood.IDLE] = _build_portrait_texture(_get_idle_source_texture())


func _get_idle_source_texture() -> Texture2D:
	if _health_percent < hurt2_threshold and texture_hurt2 != null:
		return texture_hurt2
	if _health_percent <= hurt1_threshold and texture_hurt1 != null:
		return texture_hurt1
	return texture_idle


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
	if expr == PortraitMood.IDLE:
		_rebuild_idle_texture()
	_apply_texture_for(expr)
	if immediate or not _can_schedule_expression_hold():
		return
	_hold_token += 1
	var token: int = _hold_token
	var tree: SceneTree = get_tree()
	var t: SceneTreeTimer = tree.create_timer(expression_hold_seconds)
	t.timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		if token == _hold_token and _current == expr:
			set_expression(PortraitMood.IDLE, true)
	)


func _can_schedule_expression_hold() -> bool:
	return is_inside_tree() and get_tree() != null


func flash_happy() -> void:
	set_expression(PortraitMood.HAPPY)


func flash_coin() -> void:
	set_expression(PortraitMood.COIN)


func flash_angry() -> void:
	set_expression(PortraitMood.ANGRY)


func _apply_texture_for(expr: PortraitMood) -> void:
	if _portrait == null:
		return
	_portrait.texture = _portraits.get(expr, null)


func refresh_atlases() -> void:
	_apply_layout()
	_rebuild_portraits()
	_apply_texture_for(_current)
