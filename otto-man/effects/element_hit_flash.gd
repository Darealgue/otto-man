# element_hit_flash.gd
# Placeholder görsel: bir düşmana element uygulandığında kısa bir renkli halka
# yanıp söner. Geçici/basit — kullanıcı kendi çizimlerini ekleyene kadar
# element uygulamasının EKRANDA görünür olması için. enemy sprite'ının
# modulate'ına dokunmaz (hurt-flash tween'iyle çakışmasın diye kasıtlı olarak
# ayrı bir node, ayrı bir çizim).

extends Node2D

const DURATION := 0.3
const RADIUS := 26.0

const ELEMENT_COLORS := {
	"poison": Color(0.45, 0.95, 0.35),
	"fire": Color(1.0, 0.55, 0.15),
	"ice": Color(0.4, 0.78, 1.0),
	"lightning": Color(1.0, 0.95, 0.4),
}

var _timer: float = 0.0
var _color: Color = Color.WHITE

func setup(pos: Vector2, element: String) -> void:
	global_position = pos
	_color = ELEMENT_COLORS.get(element, Color.WHITE)
	z_index = 60
	z_as_relative = false

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = _timer / DURATION
	var alpha: float = 1.0 - t
	var r: float = RADIUS * (0.5 + t * 0.9)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(_color.r, _color.g, _color.b, alpha * 0.9), 3.0)
	draw_circle(Vector2.ZERO, r * 0.35, Color(_color.r, _color.g, _color.b, alpha * 0.3))
