# lightning_flash.gd - Kısa süreli şimşek görseli (Yıldırım Düşüşü vb.)
extends Node2D

const DURATION := 0.25
const FLASH_RADIUS := 80.0

var _timer: float = 0.0

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var alpha = 1.0 - (_timer / DURATION)
	var col = Color(1.0, 0.95, 0.8, alpha * 0.6)
	draw_circle(Vector2.ZERO, FLASH_RADIUS * (1.0 + _timer * 0.3), col)
