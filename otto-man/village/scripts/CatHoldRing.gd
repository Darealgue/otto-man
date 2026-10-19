extends Node2D

## Kedi etkileşiminde basılı tutma halkası (kodla çizilir): oyuncu tuşu basılı tuttukça kedinin başında dolan halka.
## Oyuncunun mevcut basılı tutma sistemi (Player._update_npc_interact_hold_visual) CatPrototype.set_interact_hold_progress'e oran gönderir.

const RING_CENTER: Vector2 = Vector2(0.0, -52.0)
const RING_RADIUS: float = 11.0
const BG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const TRACK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
const FILL_COLOR: Color = Color(1.0, 0.85, 0.45, 1.0)

var ratio: float = 0.0:
	set(value):
		ratio = clampf(value, 0.0, 1.0)
		visible = ratio > 0.0
		queue_redraw()

func _ready() -> void:
	z_index = 40
	visible = false

func _draw() -> void:
	if ratio <= 0.0:
		return
	draw_circle(RING_CENTER, RING_RADIUS + 3.0, BG_COLOR)
	draw_arc(RING_CENTER, RING_RADIUS, 0.0, TAU, 28, TRACK_COLOR, 3.0)
	draw_arc(RING_CENTER, RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * ratio, 28, FILL_COLOR, 3.0)
