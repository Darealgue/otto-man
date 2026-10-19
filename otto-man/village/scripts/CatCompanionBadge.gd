extends Node2D

## Eşlikçi olarak seçilmiş kedinin köydeki küçük işareti: kedinin üstünde altın rengi bir pati (kodla çizilir).

const BADGE_POS: Vector2 = Vector2(0.0, -40.0)
const PAD_COLOR: Color = Color(1.0, 0.82, 0.3, 1.0)
const OUTLINE_COLOR: Color = Color(0.25, 0.15, 0.0, 0.85)

func _ready() -> void:
	z_index = 29

func _draw() -> void:
	# Pati: büyük ana yastık ve üstte üç küçük parmak.
	draw_circle(BADGE_POS + Vector2(0, 1.6), 4.6, OUTLINE_COLOR)
	draw_circle(BADGE_POS + Vector2(0, 1.6), 3.6, PAD_COLOR)
	for off in [Vector2(-4.2, -3.2), Vector2(0, -5.2), Vector2(4.2, -3.2)]:
		draw_circle(BADGE_POS + off, 2.5, OUTLINE_COLOR)
		draw_circle(BADGE_POS + off, 1.7, PAD_COLOR)
