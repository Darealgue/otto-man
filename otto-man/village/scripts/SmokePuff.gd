extends Sprite2D
## Bacadan çıkan tek bir duman partikülü: kaynak texture 16 karelik büyüme animasyonu
## (bakery_smoke.png), yükselme/sallanma/solma burada script ile ekleniyor. Kendi kendini siler.

@export var rise_speed: float = 28.0       # px/sn yukarı süzülme
@export var sway_amplitude: float = 5.0    # px cinsinden sağa-sola sallanma genliği
@export var sway_speed: float = 2.2        # rad/sn sallanma hızı
@export var lifetime: float = 3.0          # toplam ömür (sn)
@export var fade_start_ratio: float = 0.5  # ömrün bu oranından sonra solmaya başlar

var _age: float = 0.0
var _sway_seed: float = 0.0
var _start_x: float = 0.0

func _ready() -> void:
	hframes = 16
	frame = 0
	centered = true
	_sway_seed = randf() * TAU
	_start_x = position.x

func _process(delta: float) -> void:
	if is_instance_valid(GameState) and GameState.is_paused:
		return

	_age += delta
	var t: float = clampf(_age / lifetime, 0.0, 1.0)

	frame = clampi(int(t * float(hframes - 1)), 0, hframes - 1)
	position.y -= rise_speed * delta
	position.x = _start_x + sin(_age * sway_speed + _sway_seed) * sway_amplitude

	if t > fade_start_ratio:
		modulate.a = clampf(1.0 - (t - fade_start_ratio) / (1.0 - fade_start_ratio), 0.0, 1.0)

	if t >= 1.0:
		queue_free()
