extends Node2D

@export var gauge_width: float = 180.0
@export var gauge_height: float = 20.0
@export var base_color: Color = Color(0.2, 0.2, 0.25, 0.9)  # Koyu bar arka planı
@export var border_color: Color = Color(0.8, 0.8, 0.8, 0.9)  # Açık kenar
@export var fill_color: Color = Color(1.0, 0.7, 0.3, 0.9)  # Turuncu/sarı dolum rengi (meyve teması)
@export var success_zone_color: Color = Color(0.2, 1.0, 0.3, 1.0)  # Yeşil başarılı bölge
@export var text_color: Color = Color(1, 1, 1, 1)
@export var feedback_drop_distance: float = 22.0

# Bar dolum değeri (0.0 = sol, 1.0 = sağ)
var fill_value: float = 0.0
var success_zone_threshold: float = 0.85  # Bar'ın en sağ %15'lik kısmı

var fruits_collected: int = 0
var fruits_total: int = 5
var feedback_text: String = ""
var feedback_color: Color = Color(1, 1, 1, 1)
var feedback_timer: float = 0.0

func _ready() -> void:
	z_index = 1000
	set_process(true)
	queue_redraw()

func set_fill_value(value: float) -> void:
	fill_value = clamp(value, 0.0, 1.0)
	queue_redraw()

func set_success_zone_threshold(threshold: float) -> void:
	success_zone_threshold = clamp(threshold, 0.0, 1.0)
	queue_redraw()

func set_fruits_collected(collected: int, total: int) -> void:
	fruits_collected = max(collected, 0)
	fruits_total = max(total, 1)
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

func _process(delta: float) -> void:
	if feedback_timer > 0.0:
		feedback_timer -= delta
		if feedback_timer <= 0.0:
			feedback_timer = 0.0
			feedback_text = ""
	queue_redraw()

func _draw() -> void:
	var half_w: float = gauge_width * 0.5
	var half_h: float = gauge_height * 0.5
	var top_left := Vector2(-half_w, -half_h)
	var gauge_rect := Rect2(top_left, Vector2(gauge_width, gauge_height))
	
	# Bar arka planı
	draw_rect(gauge_rect, base_color)
	# Kenar
	draw_rect(gauge_rect, border_color, false, 2.0)
	
	# Başarılı bölge (en sağ %15'lik kısım - yeşil)
	var success_zone_width: float = gauge_width * (1.0 - success_zone_threshold)
	var success_zone_left: float = half_w - success_zone_width  # Bar'ın sağ tarafından başla
	var success_zone_right: float = half_w  # Bar'ın en sağı
	
	# Dolu kısım (soldan sağa) - ama yeşil bölgenin soluna kadar
	var fill_width: float = gauge_width * fill_value
	var fill_left: float = -half_w  # Bar'ın sol tarafı
	var fill_right: float = -half_w + fill_width  # Bar'ın sağ tarafı
	
	# Turuncu dolum sadece yeşil bölgenin soluna kadar çizilir
	if fill_right >= success_zone_left:
		# Turuncu dolum yeşil bölgeye ulaştı, sadece yeşil bölgenin soluna kadar çiz
		var clamped_fill_width: float = success_zone_left - fill_left
		if clamped_fill_width > 0:
			var fill_rect := Rect2(
				Vector2(fill_left, -half_h),
				Vector2(clamped_fill_width, gauge_height)
			)
			draw_rect(fill_rect, fill_color)
	else:
		# Turuncu dolum henüz yeşil bölgeye ulaşmadı, normal çiz
		var fill_rect := Rect2(
			Vector2(fill_left, -half_h),
			Vector2(fill_width, gauge_height)
		)
		draw_rect(fill_rect, fill_color)
	
	# Başarılı bölge (en sağ %15'lik kısım - yeşil) - en son çiz ki her zaman görünür olsun
	var success_zone_rect := Rect2(
		Vector2(success_zone_left, -half_h),
		Vector2(success_zone_width, gauge_height)
	)
	draw_rect(success_zone_rect, success_zone_color)
	# Başarılı bölge kenarı (daha parlak)
	draw_rect(success_zone_rect, Color(0.4, 1.0, 0.5, 1.0), false, 2.0)
	
	# Text
	var font := ThemeDB.fallback_font
	var font_size: float = ThemeDB.fallback_font_size
	if font:
		var fruits_text := "Meyve: %d / %d" % [fruits_collected, fruits_total]
		var fruits_size: Vector2 = font.get_string_size(fruits_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var fruits_pos := Vector2(-fruits_size.x * 0.5, -half_h - 20.0)
		# Text shadow
		draw_string(font, fruits_pos + Vector2(1, 1), fruits_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.7))
		draw_string(font, fruits_pos, fruits_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)
		
		if feedback_text != "":
			var fb_size: Vector2 = font.get_string_size(feedback_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var fb_pos := Vector2(-fb_size.x * 0.5, half_h + feedback_drop_distance)
			# Feedback text shadow
			draw_string(font, fb_pos + Vector2(1, 1), feedback_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.7))
			draw_string(font, fb_pos, feedback_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, feedback_color)

