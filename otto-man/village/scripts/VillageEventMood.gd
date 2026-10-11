extends Node
## Köyde aktif felaket/nimet eventlerine göre ekrana hafif bir hava tonu verir (hissedilir olsun diye).
## Etki saf görseldir: üretim/moral etkileri VillageManager'da hesaplanır. Sadece köy sahnesi açıkken görünür.

const _LAYER_INDEX := 3            # oyun dünyasının üstü, arayüzün altı
const _CHECK_INTERVAL_SEC := 1.0
const _FADE_SEC := 2.5

## Olay tipi -> ton (alpha en yüksek olan baskın gelir)
const EVENT_TINTS: Dictionary = {
	"drought": Color(1.0, 0.76, 0.32, 0.15),
	"famine": Color(0.52, 0.52, 0.48, 0.17),
	"pest": Color(0.42, 0.55, 0.28, 0.13),
	"wolf_attack": Color(0.28, 0.33, 0.55, 0.12),
	"severe_storm": Color(0.2, 0.26, 0.38, 0.14),
	"weather_blessing": Color(1.0, 0.9, 0.5, 0.11),
	"worker_strike": Color(0.75, 0.3, 0.22, 0.09),
	"plague": Color(0.45, 0.8, 0.38, 0.13),
	"disease": Color(0.45, 0.8, 0.38, 0.13),
	"rebellion": Color(0.7, 0.2, 0.2, 0.12),
}

var _layer: CanvasLayer = null
var _rect: ColorRect = null
var _timer: float = 0.0
var _current: Color = Color(0, 0, 0, 0)
var _tween: Tween = null


func _ready() -> void:
	_timer = 0.5


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _CHECK_INTERVAL_SEC
	_refresh()


func _village_visible() -> bool:
	var vm: Node = get_parent()
	return is_instance_valid(vm) and "village_scene_instance" in vm and is_instance_valid(vm.get("village_scene_instance"))


func _collect_event_types() -> Array[String]:
	var out: Array[String] = []
	var vm: Node = get_parent()
	if is_instance_valid(vm) and vm.has_method("get_active_events"):
		for ev in vm.call("get_active_events"):
			if ev is Dictionary:
				out.append(String(ev.get("type", "")))
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm != null and wm.get("active_events") != null:
		for ev in wm.get("active_events"):
			if ev is Dictionary:
				out.append(String(ev.get("type", "")))
	return out


func _target_tint() -> Color:
	if not _village_visible():
		return Color(0, 0, 0, 0)
	var best := Color(0, 0, 0, 0)
	for t in _collect_event_types():
		var c: Color = EVENT_TINTS.get(t, Color(0, 0, 0, 0))
		if c.a > best.a:
			best = c
	return best


func _ensure_layer() -> void:
	if is_instance_valid(_rect):
		return
	_layer = CanvasLayer.new()
	_layer.name = "VillageEventMoodLayer"
	_layer.layer = _LAYER_INDEX
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(0, 0, 0, 0)
	_layer.add_child(_rect)


func _refresh() -> void:
	var target: Color = _target_tint()
	if target.is_equal_approx(_current):
		return
	_ensure_layer()
	_current = target
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_rect, "color", target, _FADE_SEC)
