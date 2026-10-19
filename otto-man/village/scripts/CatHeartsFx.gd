extends Node2D

## Kedi sevilince yükselip solan küçük kalpler (kodla çizilir, sprite gerekmez). Kedinin çocuğu olarak eklenir, kedi gibi hareket eder.

const HEART_POINTS: PackedVector2Array = [
	Vector2(0, 3), Vector2(-3, 0), Vector2(-3, -2), Vector2(-1.5, -3.5),
	Vector2(0, -2), Vector2(1.5, -3.5), Vector2(3, -2), Vector2(3, 0),
]
const HEART_COLOR: Color = Color(0.95, 0.25, 0.38, 1.0)
const LIFETIME: float = 1.5
const RISE_PX: float = 34.0
const SCALE: float = 1.7

var count: int = 3                       # kaç kalp çıkacak
var _hearts: Array[Dictionary] = []      # {x_offset, delay, sway}
var _time: float = 0.0

func _ready() -> void:
	z_index = 30
	for i in range(count):
		_hearts.append({
			"x": randf_range(-10.0, 10.0),
			"delay": float(i) * 0.18 + randf_range(0.0, 0.08),
			"sway": randf_range(0.0, TAU),
		})

func _process(delta: float) -> void:
	_time += delta
	if _time > LIFETIME + float(count) * 0.2 + 0.2:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for h in _hearts:
		var t: float = (_time - float(h["delay"])) / LIFETIME
		if t < 0.0 or t > 1.0:
			continue
		var pos := Vector2(float(h["x"]) + sin(t * 5.0 + float(h["sway"])) * 3.0, -26.0 - t * RISE_PX)
		var c: Color = HEART_COLOR
		c.a = 1.0 - smoothstep(0.55, 1.0, t)
		var pts: PackedVector2Array = PackedVector2Array()
		for p in HEART_POINTS:
			pts.append(pos + p * SCALE)
		draw_colored_polygon(pts, c)
