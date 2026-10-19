extends Node2D

## Yüzen köylünün su çizgisindeki halkalar (kodla çizilir); köylüyle birlikte yukarı aşağı gezer (su çizgisi ShowSwimVisual'dan gelir).
## Alt yarı köylünün kopyasının ÖNÜNDE (z 23), üst yarı ARKASINDA (z 21) çizilir; böylece halkanın üst kısmı göğsün önünde görünmez.
## Su sprite'ı z 20, köylünün kırpılmış kopyası z 22.

const RING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
const FRONT_Z: int = 23
const BACK_Z: int = 21

var swimmer: Node2D = null
var visual: Node2D = null                # ShowSwimVisual (clip_y alanı su çizgisidir)
var _time: float = 0.0
var _back: Node2D = null


## Üst yarım halkaları köylünün arkasında çizen yardımcı düğüm.
class _BackHalf extends Node2D:
	var ripple: Node2D = null

	func _draw() -> void:
		if ripple != null and is_instance_valid(ripple):
			ripple._draw_half(self, true)


func _ready() -> void:
	z_as_relative = false
	z_index = FRONT_Z
	_back = _BackHalf.new()
	_back.ripple = self
	_back.z_as_relative = false
	_back.z_index = BACK_Z
	add_child(_back)

func _process(delta: float) -> void:
	if swimmer == null or not is_instance_valid(swimmer) or visual == null or not is_instance_valid(visual):
		queue_free()
		return
	_time += delta
	global_position = Vector2(swimmer.global_position.x, float(visual.clip_y) + 1.0)
	queue_redraw()
	_back.queue_redraw()

func _draw() -> void:
	_draw_half(self, false)

## İki halka sırayla genişleyip solar. upper=true: elipsin üst yarısı (su çizgisinin üstü), false: alt yarısı.
func _draw_half(canvas: CanvasItem, upper: bool) -> void:
	for k in range(2):
		var phase: float = fmod(_time * 0.9 + float(k) * 0.5, 1.0)
		var w: float = 14.0 + phase * 24.0
		var h: float = 2.0 + phase * 3.0
		var c: Color = RING_COLOR
		c.a *= (1.0 - phase)
		var pts: PackedVector2Array = PackedVector2Array()
		var a0: float = PI if upper else 0.0   # üst yarı: PI..TAU (y negatif), alt yarı: 0..PI (y pozitif)
		for i in range(13):
			var a: float = a0 + PI * float(i) / 12.0
			pts.append(Vector2(cos(a) * w, sin(a) * h))
		canvas.draw_polyline(pts, c, 1.0)
