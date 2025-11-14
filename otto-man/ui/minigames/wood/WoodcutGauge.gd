extends Node2D

@export var gauge_width: float = 180.0
@export var gauge_height: float = 20.0
@export var base_color: Color = Color(0.1, 0.1, 0.1, 0.85)
@export var border_color: Color = Color(0.9, 0.9, 0.9, 0.2)
@export var sweet_color: Color = Color(0.3, 0.8, 0.4, 0.75)
@export var fail_color: Color = Color(0.8, 0.25, 0.25, 0.75)
@export var indicator_color: Color = Color(1, 1, 1, 0.95)
@export var text_color: Color = Color(1, 1, 1, 1)
@export var feedback_drop_distance: float = 22.0

var sweet_center: float = 0.5
var sweet_width: float = 0.2
var indicator_value: float = 0.5
var hits_current: int = 0
var hits_required: int = 1
var feedback_text: String = ""
var feedback_color: Color = Color(1, 1, 1, 1)
var feedback_timer: float = 0.0
var show_fail_region: bool = false

func _ready() -> void:
	z_index = 1000
	set_process(true)
	queue_redraw()

func set_indicator(value: float) -> void:
	indicator_value = clamp(value, 0.0, 1.0)
	queue_redraw()

func set_sweet_spot(center: float, width: float) -> void:
	sweet_width = clamp(width, 0.05, 0.9)
	sweet_center = clamp(center, sweet_width * 0.5, 1.0 - sweet_width * 0.5)
	queue_redraw()

func set_hits(current: int, required: int) -> void:
	hits_current = max(current, 0)
	hits_required = max(required, 1)
	queue_redraw()

func set_feedback(text: String, color: Color = Color.WHITE, duration: float = 0.6) -> void:
	feedback_text = text
	feedback_color = color
	feedback_timer = max(duration, 0.0)
	queue_redraw()

func clear_feedback() -> void:
	feedback_text = ""
	feedback_timer = 0.0
	queue_redraw()

func flash_fail_region() -> void:
	show_fail_region = true
	feedback_timer = max(feedback_timer, 0.15)
	queue_redraw()

func _process(delta: float) -> void:
	if feedback_timer > 0.0:
		feedback_timer -= delta
		if feedback_timer <= 0.0:
			feedback_timer = 0.0
			show_fail_region = false
			feedback_text = ""
			queue_redraw()

func _draw() -> void:
	var half_w: float = gauge_width * 0.5
	var half_h: float = gauge_height * 0.5
	var top_left := Vector2(-half_w, -half_h)
	var gauge_rect := Rect2(top_left, Vector2(gauge_width, gauge_height))
	draw_rect(gauge_rect, base_color)
	draw_rect(gauge_rect, border_color, false, 1.5)

	if show_fail_region:
		draw_rect(gauge_rect, fail_color, true)

	var sweet_left: float = lerpf(-half_w, half_w, sweet_center - sweet_width * 0.5)
	var sweet_right: float = lerpf(-half_w, half_w, sweet_center + sweet_width * 0.5)
	var sweet_rect := Rect2(
		Vector2(sweet_left, -half_h),
		Vector2(max(sweet_right - sweet_left, 1.0), gauge_height)
	)
	draw_rect(sweet_rect, sweet_color)

	var indicator_x: float = lerpf(-half_w, half_w, indicator_value)
	var top_point := Vector2(indicator_x, -half_h - 6.0)
	var bottom_point := Vector2(indicator_x, half_h + 6.0)
	draw_line(top_point, bottom_point, indicator_color, 2.5, true)

	var font := ThemeDB.fallback_font
	var font_size: float = ThemeDB.fallback_font_size
	if font:
		var hits_text := "%d / %d" % [hits_current, hits_required]
		var hits_size: Vector2 = font.get_string_size(hits_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var hits_pos := Vector2(-hits_size.x * 0.5, -half_h - 12.0)
		draw_string(font, hits_pos, hits_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)

		if feedback_text != "":
			var fb_size: Vector2 = font.get_string_size(feedback_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var fb_pos := Vector2(-fb_size.x * 0.5, half_h + feedback_drop_distance)
			draw_string(font, fb_pos, feedback_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, feedback_color)
