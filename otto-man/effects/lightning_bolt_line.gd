# lightning_bolt_line.gd
# Placeholder görsel: iki nokta arasında çentikli bir yıldırım çizgisi.
# İki kullanım: (1) gökten düşen şimşek — from = hedefin ÜSTÜ, to = hedef;
# (2) Yıldırım Zinciri'nin sekmesi — from = ölen düşman, to = sıçradığı yeni
# hedef. global_position kasıtlı olarak (0,0)'da bırakılıyor ve noktalar
# doğrudan global koordinatlarla çiziliyor (node hiç taşınmıyor/döndürülmüyor,
# bu yüzden local çizim uzayı == global uzay).

extends Node2D

const DURATION := 0.22
const JAG_SEGMENTS := 6
const JAG_SPREAD := 12.0

var _timer: float = 0.0
var _points: PackedVector2Array = []

func setup(from_global: Vector2, to_global: Vector2) -> void:
	z_index = 55
	z_as_relative = false
	_points = _build_jagged_line(from_global, to_global)

func _build_jagged_line(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir: Vector2 = b - a
	var perp: Vector2 = dir.orthogonal().normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
	pts.append(a)
	for i in range(1, JAG_SEGMENTS):
		var t: float = float(i) / float(JAG_SEGMENTS)
		var base: Vector2 = a.lerp(b, t)
		pts.append(base + perp * randf_range(-JAG_SPREAD, JAG_SPREAD))
	pts.append(b)
	return pts

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if _points.size() < 2:
		return
	var alpha: float = 1.0 - (_timer / DURATION)
	var core := Color(1.0, 0.97, 0.75, alpha)
	var glow := Color(1.0, 0.92, 0.4, alpha * 0.5)
	for i in range(_points.size() - 1):
		draw_line(_points[i], _points[i + 1], glow, 6.0)
		draw_line(_points[i], _points[i + 1], core, 2.0)
