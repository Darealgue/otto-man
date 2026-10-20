class_name VillageActionRing
extends Control

## Yay üzerinde açılan yuvarlak eylem tuşları (harita: komşu köy Ziyaret/Sız/İptal, zindan/etkinlik Gir/Vazgeç;
## köy: bina Yükselt/Yık/Etkileşim). Tuşlar merkez noktadan büyüyerek aşağı doğru yaya yayılır; seçili ya da üzerine gelinen
## tuşun adı (ve varsa alt satırı, ör. maliyet) tuşun altında yazılır. İstenirse merkezin üstünde bir bilgi kutusu (başlık + satırlar) çizilir.
## Girdi: sol/sağ ile seç, onay (ui_accept) ile uygula, ui_cancel ya da sağ tık ile vazgeç, fare ile tıkla.
## Seçenek: {"id", "kind", "label", "sub" (ops.), "disabled" (ops.)}. İkonlar kodla çizilir (sanat gelince _draw_icon yerine doku konabilir).

signal chosen(id: String)

const BUTTON_RADIUS: float = 28.0
const ARC_RADIUS: float = 112.0
const ARC_HALF_SPREAD_DEG: float = 38.0   # 2-3 tuşta sabit, hafif eğik yay; 4+ tuşta yarıçap ve açı otomatik büyür
const OPEN_TIME: float = 0.28
const INPUT_GRACE: float = 0.18            # ringi açan onay tuşu aynı anda seçim yapmasın

## true: halka açıkken tüm klavye/gamepad girdisi halkaya aittir (harita). Köyde de modal davranır.
var swallow_keys: bool = true

var _options: Array[Dictionary] = []
var _center_provider: Callable = Callable()
var _center: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _selected: int = 0
var _hover: int = -1
var _age: float = 0.0
var _open: bool = false
var _header_title: String = ""
var _header_lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return _open


## center_provider: merkezin ekran konumunu verir (kamera hareket etse de halka yerinde kalır).
func open_ring(options: Array[Dictionary], center_provider: Callable, header_title: String = "", header_lines: PackedStringArray = PackedStringArray()) -> void:
	_options = options
	_center_provider = center_provider
	_center = center_provider.call() if center_provider.is_valid() else get_viewport_rect().size * 0.5
	_header_title = header_title
	_header_lines = header_lines
	_t = 0.0
	_age = 0.0
	_selected = 0
	for i in _options.size():
		if not bool(_options[i].get("disabled", false)):
			_selected = i
			break
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


# ─── Yerleşim ────────────────────────────────────────────────────────────────

func _arc_radius() -> float:
	var n: int = _options.size()
	return ARC_RADIUS + 30.0 * float(maxi(0, n - 3))


func _button_angle(i: int) -> float:
	var n: int = _options.size()
	if n <= 1:
		return PI * 0.5
	var half: float = deg_to_rad(ARC_HALF_SPREAD_DEG)
	if n > 3:
		var step: float = 2.0 * asin(minf(1.0, (BUTTON_RADIUS * 2.0 + 14.0) / (2.0 * _arc_radius())))
		half = step * float(n - 1) * 0.5
	var f: float = float(i) / float(n - 1)
	# Aşağı doğru açılır; ilk tuş solda kalır.
	return PI * 0.5 + half - f * half * 2.0


func _button_pos(i: int) -> Vector2:
	var e: float = _ease_out_back(_t)
	return _center + Vector2.from_angle(_button_angle(i)) * _arc_radius() * e


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


# ─── Girdi ───────────────────────────────────────────────────────────────────

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
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
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
	# Açıkken diğer girdiler (hareket, zoom, işçi atama) halkanın arkasına işlemesin.
	if swallow_keys and (event is InputEventKey or event is InputEventJoypadButton):
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
	if bool(_options[i].get("disabled", false)):
		return   # devre dışı tuş (ör. en üst seviye): halka açık kalır
	var id: String = String(_options[i].get("id", ""))
	close_ring()
	chosen.emit(id)


# ─── Çizim ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not _open:
		return
	_draw_header()
	# Merkezden yaya uzanan ince çizgiler (tuşlar merkezden "büyüyerek" çıkıyor hissi).
	for i in _options.size():
		var p: Vector2 = _button_pos(i)
		draw_line(_center, p, Color(0.9, 0.8, 0.5, 0.35 * _t), 2.0)
	var scale_t: float = clampf(_t * 1.2, 0.0, 1.0)
	for i in _options.size():
		_draw_button(i, scale_t)
	_draw_label()


## Merkezin üstündeki bilgi kutusu (başlık + satırlar): bina adı, seviye, işçi sayısı gibi.
func _draw_header() -> void:
	if _header_title.is_empty() and _header_lines.is_empty():
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var title_fs: int = 22
	var line_fs: int = 17
	var w: float = font.get_string_size(_header_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_fs).x
	for l in _header_lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, line_fs).x)
	var pad: Vector2 = Vector2(16.0, 10.0)
	var h: float = pad.y * 2.0 + float(title_fs) + 4.0 + float(_header_lines.size()) * (float(line_fs) + 4.0)
	var box := Rect2(_center + Vector2(-(w + pad.x * 2.0) * 0.5, -h - 18.0), Vector2(w + pad.x * 2.0, h))
	var a: float = clampf(_t * 1.5, 0.0, 1.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.04, 0.03, 0.94 * a)
	sb.border_color = Color(0.66, 0.52, 0.3, a)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, box)
	var y: float = box.position.y + pad.y + float(title_fs) * 0.85
	var tw: float = font.get_string_size(_header_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_fs).x
	draw_string(font, Vector2(_center.x - tw * 0.5, y), _header_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_fs, Color(0.95, 0.82, 0.45, a))
	y += 8.0
	for l in _header_lines:
		y += float(line_fs) + 4.0
		var lw: float = font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, line_fs).x
		draw_string(font, Vector2(_center.x - lw * 0.5, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, line_fs, Color(0.92, 0.88, 0.78, a))


func _kind_color(kind: String) -> Color:
	match kind:
		"visit", "house":
			return Color(0.75, 0.95, 0.7)
		"infiltrate", "inventor":
			return Color(0.75, 0.7, 1.0)
		"cancel", "demolish":
			return Color(1.0, 0.65, 0.6)
		"enter", "upgrade", "weapon":
			return Color(1.0, 0.85, 0.5)
		"confirm":
			return Color(0.7, 1.0, 0.7)
	return Color.WHITE


func _draw_button(i: int, scale_t: float) -> void:
	var p: Vector2 = _button_pos(i)
	var sel: bool = i == _selected
	var disabled: bool = bool(_options[i].get("disabled", false))
	var r: float = BUTTON_RADIUS * scale_t * (1.12 if sel else 1.0)
	var kind: String = String(_options[i].get("kind", ""))
	var col: Color = _kind_color(kind)
	var alpha: float = 0.4 if disabled else 1.0
	col.a = alpha
	draw_circle(p + Vector2(2, 3), r, Color(0, 0, 0, 0.35 * alpha))
	draw_circle(p, r, Color(0.13, 0.09, 0.06, 0.94))
	var border: Color = Color(1.0, 0.86, 0.45) if sel else Color(0.62, 0.52, 0.36)
	border.a = alpha if not sel else 1.0
	draw_arc(p, r, 0.0, TAU, 40, border, 3.0 if sel else 2.0, true)
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
		"house":
			# Ev + artı (kat ekle / ev kur)
			draw_polyline(PackedVector2Array([c + Vector2(-s, -s * 0.1), c + Vector2(-s * 0.2, -s * 0.9), c + Vector2(s * 0.6, -s * 0.1)]), col, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.7, -s * 0.1), c + Vector2(-s * 0.7, s * 0.8), c + Vector2(s * 0.5, s * 0.8)]), col, w, true)
			draw_line(c + Vector2(s * 0.62, s * 0.05), c + Vector2(s * 0.62, s * 0.75), col, w, true)
			draw_line(c + Vector2(s * 0.27, s * 0.4), c + Vector2(s * 0.97, s * 0.4), col, w, true)
		"infiltrate":
			# Üstü çizili göz: sessizce görünmeden gir
			var eye := PackedVector2Array()
			for k in range(0, 17):
				var a: float = lerpf(PI, TAU, float(k) / 16.0)
				eye.append(c + Vector2(cos(a) * s, sin(a) * s * 0.62))
			for k in range(0, 17):
				var a2: float = lerpf(0.0, PI, float(k) / 16.0)
				eye.append(c + Vector2(cos(a2) * s, sin(a2) * s * 0.62))
			draw_polyline(eye, col, w, true)
			draw_circle(c, s * 0.28, col)
			draw_line(c + Vector2(-s * 0.9, s * 0.8), c + Vector2(s * 0.9, -s * 0.8), Color(0.13, 0.09, 0.06), w * 2.6, true)
			draw_line(c + Vector2(-s * 0.9, s * 0.8), c + Vector2(s * 0.9, -s * 0.8), col, w, true)
		"enter":
			# Kemerli kapı: zindan / etkinlik girişi
			var arch := PackedVector2Array()
			arch.append(c + Vector2(-s * 0.7, s * 0.9))
			arch.append(c + Vector2(-s * 0.7, -s * 0.1))
			for k in range(0, 13):
				var a3: float = lerpf(PI, TAU, float(k) / 12.0)
				arch.append(c + Vector2(cos(a3) * s * 0.7, -s * 0.1 + sin(a3) * s * 0.8))
			arch.append(c + Vector2(s * 0.7, s * 0.9))
			draw_polyline(arch, col, w, true)
			draw_line(c + Vector2(-s * 1.0, s * 0.9), c + Vector2(s * 1.0, s * 0.9), col, w, true)
			draw_line(c + Vector2(0, -s * 0.7), c + Vector2(0, s * 0.9), col, w * 0.7, true)
		"upgrade":
			# Yukarı ok + alt çizgi (seviye yükselt)
			draw_line(c + Vector2(0, s * 0.8), c + Vector2(0, -s * 0.7), col, w * 1.2, true)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.6, -s * 0.1), c + Vector2(0, -s * 0.8), c + Vector2(s * 0.6, -s * 0.1)]), col, w * 1.2, true)
			draw_line(c + Vector2(-s * 0.6, s * 0.95), c + Vector2(s * 0.6, s * 0.95), col, w, true)
		"demolish":
			# Çöp / yık: kapak + gövde
			draw_line(c + Vector2(-s * 0.85, -s * 0.55), c + Vector2(s * 0.85, -s * 0.55), col, w, true)
			draw_line(c + Vector2(-s * 0.3, -s * 0.55), c + Vector2(-s * 0.3, -s * 0.85), col, w, true)
			draw_line(c + Vector2(s * 0.3, -s * 0.55), c + Vector2(s * 0.3, -s * 0.85), col, w, true)
			draw_line(c + Vector2(-s * 0.3, -s * 0.85), c + Vector2(s * 0.3, -s * 0.85), col, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.65, -s * 0.55), c + Vector2(-s * 0.55, s * 0.9), c + Vector2(s * 0.55, s * 0.9), c + Vector2(s * 0.65, -s * 0.55)]), col, w, true)
			draw_line(c + Vector2(0, -s * 0.3), c + Vector2(0, s * 0.65), col, w * 0.8, true)
		"weapon":
			# Kılıç
			draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(s * 0.8, -s * 0.8), col, w * 1.3, true)
			draw_line(c + Vector2(-s * 0.55, s * 0.05), c + Vector2(-s * 0.05, s * 0.55), col, w * 1.1, true)
			draw_line(c + Vector2(-s * 0.85, s * 0.85), c + Vector2(-s * 0.55, s * 0.55), col, w * 1.1, true)
		"inventor":
			# Dişli
			draw_arc(c, s * 0.55, 0.0, TAU, 24, col, w, true)
			draw_circle(c, s * 0.18, col)
			for k in range(8):
				var ang: float = TAU * float(k) / 8.0
				draw_line(c + Vector2.from_angle(ang) * s * 0.55, c + Vector2.from_angle(ang) * s * 0.95, col, w * 1.4, true)
		"confirm":
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.8, 0.0), c + Vector2(-s * 0.2, s * 0.6), c + Vector2(s * 0.85, -s * 0.65)]), col, w * 1.4, true)
		"cancel":
			draw_line(c + Vector2(-s * 0.7, -s * 0.7), c + Vector2(s * 0.7, s * 0.7), col, w * 1.3, true)
			draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(s * 0.7, -s * 0.7), col, w * 1.3, true)


## Seçili (ya da üzerine gelinen) tuşun adı tuşun altında yazılır; varsa alt satırı (ör. maliyet) onun altında, küçük puntoyla.
func _draw_label() -> void:
	if _t < 0.8:
		return
	var i: int = _hover if _hover >= 0 else _selected
	if i < 0 or i >= _options.size():
		return
	var text: String = String(_options[i].get("label", ""))
	var sub: String = String(_options[i].get("sub", ""))
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var fs: int = 22
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var p: Vector2 = _button_pos(i) + Vector2(-size.x * 0.5, BUTTON_RADIUS + 26.0)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.95))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.95, 0.8))
	if not sub.is_empty():
		var sfs: int = 17
		var ssize: Vector2 = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs)
		var sp: Vector2 = _button_pos(i) + Vector2(-ssize.x * 0.5, BUTTON_RADIUS + 26.0 + float(sfs) + 6.0)
		draw_string_outline(font, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, 4, Color(0, 0, 0, 0.95))
		draw_string(font, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(0.85, 0.8, 0.65))
