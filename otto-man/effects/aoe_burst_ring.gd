# aoe_burst_ring.gd
# Placeholder görsel: parametrik bir "bu yarıçap isabet aldı" halkası. Item'ın
# GERÇEK radius sabitiyle çağrılması gerekiyor — uydurma bir boyut değil,
# kodun kendi hesapladığı alan. Kalıcı sanat gelene kadar AoE item'larının
# (Sarsıcı Darbe, Daire Darbesi, Leş Gazı vb.) "neden hasar aldım" sorusuna
# cevap veriyor.

extends Node2D

const DURATION := 0.35

var _timer: float = 0.0
var _radius: float = 60.0
var _color: Color = Color(1.0, 1.0, 1.0, 0.8)

func setup(pos: Vector2, radius: float, color: Color) -> void:
	global_position = pos
	_radius = radius
	_color = color
	z_index = 58
	z_as_relative = false

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = _timer / DURATION
	var alpha: float = (1.0 - t) * _color.a
	var r: float = _radius * (0.55 + t * 0.6)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(_color.r, _color.g, _color.b, alpha), 4.0)
	draw_circle(Vector2.ZERO, r, Color(_color.r, _color.g, _color.b, alpha * 0.18))
