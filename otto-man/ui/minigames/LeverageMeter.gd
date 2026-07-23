extends Control

var leverage: int = 0
var min_value: int = -5
var max_value: int = 5
var flip: bool = false # true: pozitif leverage SOLA dolar (oyuncu solda dururken)
var _display_t: float = 0.5 # 0..1 normalized visual progress
var _anim_speed: float = 6.0

func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(delta):
	# pull leverage from meta if provided
	if has_meta("leverage"):
		leverage = int(get_meta("leverage"))
	if has_meta("flip"):
		flip = bool(get_meta("flip"))
	# Smooth animation toward target t
	var vis_lev: int = -leverage if flip else leverage
	var span: int = max_value - min_value
	var target_t: float = clamp(float(vis_lev - min_value) / float(span), 0.0, 1.0)
	_display_t = lerp(_display_t, target_t, clamp(delta * _anim_speed, 0.0, 1.0))
	queue_redraw()

func _draw():
	var rect := Rect2(Vector2.ZERO, size)
	var bg := Color(0.08, 0.08, 0.08, 0.85)
	draw_rect(rect, bg)
	# center line
	var cx: float = rect.size.x * 0.5
	draw_line(Vector2(cx, 0), Vector2(cx, rect.size.y), Color(0.3, 0.3, 0.3, 1.0), 2.0)
	# fill toward left/right; yön flip'e göre, renk gerçek skora göre
	var vis_lev: int = -leverage if flip else leverage
	var span: int = max_value - min_value # 10
	var fill_x: float = rect.position.x + rect.size.x * _display_t
	var col: Color = Color(0.2, 0.8, 0.4, 1.0) if leverage >= 0 else Color(0.9, 0.3, 0.25, 1.0)
	if vis_lev >= 0:
		draw_rect(Rect2(Vector2(cx, 0), Vector2(fill_x - cx, rect.size.y)), col)
	else:
		draw_rect(Rect2(Vector2(fill_x, 0), Vector2(cx - fill_x, rect.size.y)), col)
	# tick marks
	for i in range(min_value, max_value + 1):
		var ix: float = rect.position.x + rect.size.x * float(i - min_value) / float(span)
		var h: float = rect.size.y
		if i != 0:
			h = rect.size.y * 0.4
		draw_line(Vector2(ix, rect.size.y - h), Vector2(ix, rect.size.y), Color(1,1,1,0.25), 1)
	# labels for ends (flip'te +5 solda)
	var fnt := get_theme_default_font()
	if fnt:
		var left_txt := "+5" if flip else "-5"
		var right_txt := "-5" if flip else "+5"
		draw_string(fnt, Vector2(4, rect.size.y - 6), left_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1,1,1,0.6))
		draw_string(fnt, Vector2(rect.size.x - 22, rect.size.y - 6), right_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1,1,1,0.6))
