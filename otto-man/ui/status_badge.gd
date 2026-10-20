extends Control
## Düşman can barının üstündeki yuvarlak debuff göstergesi: renkli daire + içinde stack sayısı.
## `set_pulse(true)` 5 stack etkisi (donma, çürüme, kalkan erimesi, şimşek sıçraması) sürerken
## göstergeyi büyütüp parlatır.
## Sayı Label ile değil doğrudan _draw içinde, fontun gerçek yükseklik/genişlik ölçüleriyle ortalanır
## (Label dikey hizası fontun satır boşluğuna göre kayıyordu, sayı dairenin ortasında durmuyordu).

const DIAMETER := 16.0
const FONT_SIZE := 11
const OUTLINE_SIZE := 3
const PULSE_SCALE := 1.22
const PULSE_SPEED := 9.0

var _color := Color.WHITE
var _pulse := false
var _t := 0.0
var _text := ""

func setup(color: Color) -> void:
	_color = color
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	size = Vector2(DIAMETER, DIAMETER)
	pivot_offset = Vector2(DIAMETER, DIAMETER) * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func set_count(count: int) -> void:
	var new_text := str(count) if count > 0 else ""
	if new_text != _text:
		_text = new_text
		queue_redraw()

func set_pulse(on: bool) -> void:
	if _pulse == on:
		return
	_pulse = on
	_t = 0.0
	set_process(on)
	if not on:
		scale = Vector2.ONE
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var wobble := 0.5 + 0.5 * sin(_t * PULSE_SPEED)
	scale = Vector2.ONE * lerpf(1.08, PULSE_SCALE, wobble)
	queue_redraw()

func _draw() -> void:
	var c := Vector2(DIAMETER, DIAMETER) * 0.5
	if _pulse:
		var glow := 0.5 + 0.5 * sin(_t * PULSE_SPEED)
		draw_circle(c, DIAMETER * 0.5 + 4.0, Color(_color.r, _color.g, _color.b, 0.22 + 0.25 * glow))
		draw_circle(c, DIAMETER * 0.5 + 2.0, Color(_color.r, _color.g, _color.b, 0.35 + 0.3 * glow))
	draw_circle(c, DIAMETER * 0.5, Color(0, 0, 0, 0.9))
	var fill := _color.lightened(0.25) if _pulse else _color
	draw_circle(c, DIAMETER * 0.5 - 1.2, fill)
	if _text.is_empty():
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var text_size := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	# Taban çizgisi: rakamların görünür yüksekliği ascent'in büyük kısmı; daireyi ortalamak için
	# (ascent - descent) / 2 kadar aşağıdan başlat
	var baseline := c.y + (font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) * 0.5
	var pos := Vector2(c.x - text_size.x * 0.5, baseline)
	draw_string_outline(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE_SIZE, Color(0, 0, 0))
	draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1, 1, 1))
