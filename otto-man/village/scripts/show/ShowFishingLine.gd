extends Node2D

## Balık tutan köylünün olta çizgisi ve şamandırası (kodla çizilir). Su sprite'ının (z 20) üstünde görünsün diye z 21'dedir.
## Şamandıra ara sıra batıp çıkar (ileride balık tutma minigame'ine bağlanabilir).

const WATER_Y: float = 98.0
const LINE_COLOR: Color = Color(0.92, 0.9, 0.82, 0.95)
const BOBBER_RED: Color = Color(0.86, 0.2, 0.15, 1.0)
const BOBBER_WHITE: Color = Color(0.95, 0.95, 0.92, 1.0)
const RING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)

var fisher: Node2D = null
var dir: float = 1.0                                  # köylünün baktığı yön
var hand_offset: Vector2 = Vector2(17.0, -30.0)       # oturma pozunda elin köylüye göre konumu (yön + ise sağa)
var cast_distance: float = 70.0                       # şamandıranın köylüden yatay uzaklığı
var bobber_depth: float = 12.0                        # şamandıranın su yüzeyinin altındaki konumu

var _time: float = 0.0
var _dip: float = 0.0
var _next_dip: float = 4.0

func _ready() -> void:
	z_index = 21
	_next_dip = randf_range(3.0, 8.0)

func _process(delta: float) -> void:
	if fisher == null or not is_instance_valid(fisher):
		queue_free()
		return
	_time += delta
	_next_dip -= delta
	if _next_dip <= 0.0:
		_dip = 1.0
		_next_dip = randf_range(4.0, 10.0)
	_dip = maxf(0.0, _dip - delta * 1.6)
	queue_redraw()

func _draw() -> void:
	if fisher == null or not is_instance_valid(fisher):
		return
	var hand: Vector2 = fisher.global_position + Vector2(dir * hand_offset.x, hand_offset.y)
	var bob: Vector2 = Vector2(fisher.global_position.x + dir * cast_distance, WATER_Y + bobber_depth + sin(_time * 2.0) * 0.8 + _dip * 3.0)
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(13):
		var t: float = float(i) / 12.0
		var p: Vector2 = hand.lerp(bob, t)
		p.y -= sin(t * PI) * 12.0   # çizgi elden yukarı kavis yapıp suya iner
		pts.append(p)
	draw_polyline(pts, LINE_COLOR, 1.0)
	draw_circle(bob + Vector2(0, -2), 2.4, BOBBER_WHITE)
	draw_circle(bob + Vector2(0, -3.4), 1.6, BOBBER_RED)
	# Şamandıra çevresinde küçük halka (batınca büyür).
	var ring_r: float = 4.0 + _dip * 3.0 + fmod(_time * 3.0, 4.0) * 0.5
	draw_arc(bob + Vector2(0, 1), ring_r, PI, TAU, 14, RING_COLOR, 1.0)
