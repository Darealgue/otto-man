class_name VillageActionRing
extends Control

## Komşu köyün üstünde yay üzerinde açılan yuvarlak eylem tuşları: Ziyaret et / Sız / İptal.
## Tuşlar köyün üstünden büyüyerek yaya yayılır; seçili ya da üzerine gelinen tuşun adı yazı olarak görünür.
## Girdi: ok tuşları / D-pad ile seç, onay (ui_accept) ile uygula, ui_cancel ya da sağ tık ile vazgeç, fare ile tıkla.
## İkonlar kodla çizilir (ev, üstü çizili göz, çarpı); sanat gelince _draw_icon yerine doku konabilir.

signal chosen(id: String)

const BUTTON_RADIUS: float = 28.0
const ARC_RADIUS: float = 112.0
const ARC_HALF_SPREAD_DEG: float = 38.0   # düz dizilmesin: köyün üstünde hafif eğik bir yay
const OPEN_TIME: float = 0.28
const INPUT_GRACE: float = 0.18            # ringi açan onay tuşu aynı anda seçim yapmasın

var _options: Array[Dictionary] = []       # {id, label, kind}
var _center_provider: Callable = Callable()
var _center: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _selected: int = 0
var _hover: int = -1
var _age: float = 0.0
var _open: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return _open


## options: [{"id": "visit", "label": "...", "kind": "visit"|"infiltrate"|"cancel"}]; center_provider: köyün ekran konumunu verir.
func open_ring(options: Array[Dictionary], center_provider: Callable) -> void:
	_options = options
	_center_provider = center_provider
	_center = center_provider.call() if center_provider.is_valid() else get_viewport_rect().size * 0.5
	_t = 0.0
	_age = 0.0
	_selected = 0
	_hover = -1
	_open = true
	visible = true
	set_process(true)
	queue_redraw()


func close_ring() -> void:
	_open = false
	visible = false


func _process(delta: float) -> void:
	if not _open:
		return
	_age += delta
	_t = minf(1.0, _t + delta / OPEN_TIME)
	if _center_provider.is_valid():
		_center = _center_provider.call()
	queue_redraw()


func _button_angle(i: int) -> float:
	var n: int = _options.size()
	if n <= 1:
		return -PI * 0.5
	var f: float = float(i) / float(n - 1)
	return deg_to_rad(-90.0 - ARC_HALF_SPREAD_DEG + f * ARC_HALF_SPREAD_DEG * 2.0)


func _button_pos(i: int) -> Vector2:
	var e: float = _ease_out_back(_t)
	return _center + Vector2.from_angle(_button_angle(i)) * ARC_RADIUS * e


static func _ease_out_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _hit_test(p: Vector2) -> int:
	if _t < 0.6:
		return -1
	for i in _options.size():
		if p.distance_to(_button_pos(i)) <= BUTTON_RADIUS + 4.0:
			return i
	return -1


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseMotion:
		_hover = _hit_test((event as InputEventMouseMotion).position)
		if _hover >= 0:
			_selected = _hover
		queue_redraw()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var hit: int = _hit_test(mb.position)
			if hit >= 0:
				_choose(hit)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_selected = (_selected - 1 + _options.size()) % _options.size()
		_hover = -1
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		_selected = (_selected + 1) % _options.size()
		_hover = -1
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		if _age >= INPUT_GRACE:
			_choose(_selected)
		get_viewport().set_input_as_handled()
		return
	# Açıkken diğer harita girdileri (hareket, zoom) ringin arkasına işlemesin.
	if event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func _cancel() -> void:
	for i in _options.size():
		if String(_options[i].get("kind", "")) == "cancel":
			_choose(i)
			return
	close_ring()


func _choose(i: int) -> void:
	if i < 0 or i >= _options.size():
		return
	var id: String = String(_options[i].get("id", ""))
	close_ring()
	chosen.emit(id)


# ─── Çizim ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not _open:
		return
	# Köyden yaya uzanan ince çizgiler (tuşlar köyün üstünden "büyüyerek" çıkıyor hissi).
	for i in _options.size():
		var p: Vector2 = _button_pos(i)
		draw_line(_center, p, Color(0.9, 0.8, 0.5, 0.35 * _t), 2.0)
	var scale_t: float = clampf(_t * 1.2, 0.0, 1.0)
	for i in _options.size():
		_draw_button(i, scale_t)
	_draw_label()


func _kind_color(kind: String) -> Color:
	match kind:
		"visit":
			return Color(0.75, 0.95, 0.7)
		"infiltrate":
			return Color(0.75, 0.7, 1.0)
		"cancel":
			return Color(1.0, 0.65, 0.6)
	return Color.WHITE


func _draw_button(i: int, scale_t: float) -> void:
	var p: Vector2 = _button_pos(i)
	var sel: bool = i == _selected
	var r: float = BUTTON_RADIUS * scale_t * (1.12 if sel else 1.0)
	var kind: String = String(_options[i].get("kind", ""))
	var col: Color = _kind_color(kind)
	draw_circle(p + Vector2(2, 3), r, Color(0, 0, 0, 0.35))
	draw_circle(p, r, Color(0.13, 0.09, 0.06, 0.94))
	draw_arc(p, r, 0.0, TAU, 40, Color(1.0, 0.86, 0.45) if sel else Color(0.62, 0.52, 0.36), 3.0 if sel else 2.0, true)
	_draw_icon(kind, p, r * 0.52, col)


func _draw_icon(kind: String, c: Vector2, s: float, col: Color) -> void:
	var w: float = maxf(2.0, s * 0.16)
	match kind:
		"visit":
			# Ev: gövde + çatı + kapı
			var roof := PackedVector2Array([c + Vector2(-s, -s * 0.05), c + Vector2(0, -s), c + Vector2(s, -s * 0.05)])
			draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2]]), col, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.75, -s * 0.05), c + Vector2(-s * 0.75, s * 0.85), c + Vector2(s * 0.75, s * 0.85), c + Vector2(s * 0.75, -s * 0.05)]), col, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.22, s * 0.85), c + Vector2(-s * 0.22, s * 0.3), c + Vector2(s * 0.22, s * 0.3), c + Vector2(s * 0.22, s * 0.85)]), col, w, true)
		"infiltrate":
			# Üstü çizili göz: sessizce görünmeden gir
			var eye := PackedVector2Array()
			for k in range(0, 17):
				var a: float = lerpf(PI, TAU, float(k) / 16.0)
				eye.append(c + Vector2(cos(a) * s, sin(a) * s * 0.62 - s * 0.0))
			for k in range(0, 17):
				var a2: float = lerpf(0.0, PI, float(k) / 16.0)
				eye.append(c + Vector2(cos(a2) * s, sin(a2) * s * 0.62))
			draw_polyline(eye, col, w, true)
			draw_circle(c, s * 0.28, col)
			draw_line(c + Vector2(-s * 0.9, s * 0.8), c + Vector2(s * 0.9, -s * 0.8), Color(0.13, 0.09, 0.06), w * 2.6, true)
			draw_line(c + Vector2(-s * 0.9, s * 0.8), c + Vector2(s * 0.9, -s * 0.8), col, w, true)
		"cancel":
			draw_line(c + Vector2(-s * 0.7, -s * 0.7), c + Vector2(s * 0.7, s * 0.7), col, w * 1.3, true)
			draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(s * 0.7, -s * 0.7), col, w * 1.3, true)


## Seçili (ya da üzerine gelinen) tuşun adı, tuşun üstünde yazı olarak görünür.
func _draw_label() -> void:
	if _t < 0.8:
		return
	var i: int = _hover if _hover >= 0 else _selected
	if i < 0 or i >= _options.size():
		return
	var text: String = String(_options[i].get("label", ""))
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var fs: int = 22
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var p: Vector2 = _button_pos(i) + Vector2(-size.x * 0.5, -BUTTON_RADIUS - 14.0)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.95))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.95, 0.8))
