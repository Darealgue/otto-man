extends Node2D
class_name BlastVisualV2

## Patlama görseli (kodla çizilir): genişleyen ateş topu + şok halkası + dumanlar. Hasar vermez,
## sadece patlamanın alanını oyuncuya okutur. Kendini bitince siler.

var radius: float = 48.0
var duration: float = 0.4
var _t: float = 0.0
var _smoke: Array[Vector2] = []


func setup(r: float, d: float = 0.4) -> void:
	radius = r
	duration = d
	for i in range(6):
		_smoke.append(Vector2.from_angle(randf() * TAU) * randf_range(0.2, 0.7))


func _ready() -> void:
	z_index = 30
	z_as_relative = false


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = clampf(_t / duration, 0.0, 1.0)
	var fade: float = 1.0 - k
	# Ateş topu: hızla radius'a ulaşır, sonra söner
	var fire_r: float = radius * (0.35 + 0.65 * minf(k * 2.2, 1.0))
	draw_circle(Vector2.ZERO, fire_r, Color(1.0, 0.55, 0.15, 0.55 * fade))
	draw_circle(Vector2.ZERO, fire_r * 0.6, Color(1.0, 0.9, 0.5, 0.7 * fade))
	# Şok halkası: hasar alanının gerçek sınırı
	draw_arc(Vector2.ZERO, radius * (0.6 + 0.4 * minf(k * 3.0, 1.0)), 0.0, TAU, 48, Color(1.0, 0.85, 0.5, 0.9 * fade), 3.0)
	# Duman
	for s in _smoke:
		draw_circle(s * radius * (0.5 + k), 7.0 + 10.0 * k, Color(0.25, 0.22, 0.2, 0.5 * fade))
