extends Sprite2D
## Etkileşim noktalarının üstünde beliren "yukarı bas" ok ikonu (dünya uzayı).
## NpcOverheadUi'daki UI ok ikonunun Node2D karşılığı: hafifçe aşağı yukarı
## salınır, fade ile görünüp kaybolur. Kullanım:
##   const ArrowHint = preload("res://ui/InteractArrowHint.gd")
##   var a = ArrowHint.create(); a.position = ...; add_child(a)
##   a.show_hint() / a.hide_hint()

const TEX: Texture2D = preload("res://assets/Icons/up_arrow_icon.png")
const BOB_AMPLITUDE := 4.0
const BOB_PERIOD := 1.2
const FADE_DURATION := 0.15

var _base_y := 0.0
var _t := 0.0
var _shown := false
var _fade_tween: Tween = null


static func create() -> Sprite2D:
	var arrow: Sprite2D = load("res://ui/InteractArrowHint.gd").new()
	arrow.name = "InteractArrowHint"
	arrow.texture = TEX
	arrow.z_index = 80
	arrow.modulate.a = 0.0
	arrow.visible = false
	return arrow


func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	position.y = _base_y + sin(_t * TAU / BOB_PERIOD) * BOB_AMPLITUDE


func show_hint() -> void:
	if _shown:
		return
	_shown = true
	_kill_fade()
	visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)


func hide_hint() -> void:
	if not _shown:
		return
	_shown = false
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_fade_tween.tween_callback(func() -> void: visible = false)


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
