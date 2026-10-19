extends Node2D

## Kedinin başındaki günlük balık slotları: FISH_PER_DAY_CAP adet siyah balık silüeti; bugün yenen balık kadarı dolu balık olur.
## Sıradaki boş slot, kedi hâlâ balık istiyorsa nabız gibi atar. Çizim: CatFishingMinigame._draw_fish.

const _Minigame = preload("res://ui/minigames/CatFishingMinigame.gd")
const ICON_OFFSET: Vector2 = Vector2(0.0, -54.0)
const SLOT_SPACING: float = 26.0
const SCALE: float = 1.1

var slots: int = 3
var filled: int = 0
var asking: bool = false   # true: sıradaki slot nabız atar

var _time: float = 0.0

func _ready() -> void:
	z_index = 30

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var bob: float = sin(_time * 3.0) * 2.0
	var total_w: float = SLOT_SPACING * float(slots - 1)
	for i in slots:
		var c: Vector2 = ICON_OFFSET + Vector2(-total_w * 0.5 + SLOT_SPACING * float(i), bob)
		if i < filled:
			_Minigame._draw_fish(self, c, SCALE * 0.75)
		else:
			# Siyah silüet: dolu balığın üstüne koyu bir katman (aynı şekil, sabit koyu renk).
			var pulse: float = 1.0
			if asking and i == filled:
				pulse = 1.0 + 0.15 * sin(_time * 6.0)
			_draw_silhouette(c, SCALE * 0.75 * pulse)

func _draw_silhouette(c: Vector2, s: float) -> void:
	# Balık gövdesi (elips) + kuyruk üçgeni, siyah.
	var col := Color(0.04, 0.04, 0.05, 0.96)
	var body: PackedVector2Array = []
	for k in 20:
		var a: float = TAU * float(k) / 20.0
		body.append(c + Vector2(cos(a) * 10.0 * s, sin(a) * 5.5 * s))
	draw_colored_polygon(body, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(8.0, 0.0) * s, c + Vector2(15.0, -5.5) * s, c + Vector2(15.0, 5.5) * s]), col)
