class_name VillageDigestTicker
extends CanvasLayer
## Köy sahnesinde VillageDigest satırlarını ekranın üst ortasından aşağı doğru dizer.
## "Son dakika" gibi: yeni haber geldiği an satır olarak düşer. Köye dönüşte kaçırılan her şey
## bir anda alt alta dizilir (posta kutusu gibi), önemli (kırmızı/sarı) satırlar en üstte.
## Satırlar birkaç saniye kalıp solar; kalabalık bir toplu gösterimde okuma süresi uzar.

const LINE_HOLD_SEC: float = 8.0
## Toplu gösterimde her fazladan satır için eklenen okuma süresi (üst sınır HOLD_MAX_SEC)
const HOLD_PER_EXTRA_LINE_SEC: float = 0.6
const HOLD_MAX_SEC: float = 18.0
const FADE_IN_SEC: float = 0.2
const FADE_OUT_SEC: float = 0.5
## Toplu gösterimde satırlar arası küçük kademe: hepsi "bir anda" ama göz akışı yukarıdan aşağı
const CASCADE_SEC: float = 0.05
## Ekrana aynı anda sığacak en çok satır; fazlası yer açılınca gelir
const MAX_VISIBLE: int = 14
const FONT_SIZE: int = 20
const PANEL_WIDTH: float = 920.0
## Olay şeridi (VillageEventStrip) y=10'dan başlar ve ~36 px yüksektir; satırlar hemen altından başlar
const TOP_OFFSET: float = 58.0
## Köy sahnesi yüklenirken oyuncunun ekrana alışması için ilk satırdan önce küçük bekleme
const START_DELAY_SEC: float = 0.9

var _column: VBoxContainer = null
var _queue: Array[Dictionary] = []
var _visible_count: int = 0
var _start_delay_left: float = START_DELAY_SEC
var _digest: Node = null


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Üst orta: sol üstte oyuncu paneli, sağ üstte hedef kutusu var.
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 4)
	_column.anchor_left = 0.5
	_column.anchor_right = 0.5
	_column.anchor_top = 0.0
	_column.anchor_bottom = 0.0
	_column.offset_left = -PANEL_WIDTH * 0.5
	_column.offset_right = PANEL_WIDTH * 0.5
	_column.offset_top = TOP_OFFSET
	_column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_column)
	_digest = get_node_or_null("/root/VillageDigest")
	if _digest != null:
		if not _digest.entry_added.is_connected(_drain_digest):
			_digest.entry_added.connect(_drain_digest)
		_drain_digest()


func _exit_tree() -> void:
	if is_instance_valid(_digest) and _digest.entry_added.is_connected(_drain_digest):
		_digest.entry_added.disconnect(_drain_digest)


func _drain_digest() -> void:
	if _digest == null:
		return
	_queue.append_array(_digest.take_pending())


func _process(delta: float) -> void:
	if _start_delay_left > 0.0:
		_start_delay_left -= delta
		return
	if _queue.is_empty() or _visible_count >= MAX_VISIBLE:
		return
	# Kuyrukta ne varsa (sığdığı kadar) hepsi aynı anda dizilir
	var room: int = MAX_VISIBLE - _visible_count
	var batch: int = mini(_queue.size(), room)
	var hold: float = minf(HOLD_MAX_SEC, LINE_HOLD_SEC + HOLD_PER_EXTRA_LINE_SEC * float(maxi(0, batch - 1)))
	for i in range(batch):
		_spawn_line(_queue.pop_front(), CASCADE_SEC * float(i), hold)


func _spawn_line(entry: Dictionary, delay: float, hold: float) -> void:
	var tone: int = int(entry.get("tone", 0))
	var accent: Color = VillageDigest.TONE_ACCENTS.get(tone, Color(0.62, 0.72, 0.85))

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.03, 0.8)
	sb.border_width_left = 4
	sb.border_color = accent
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var icon: String = String(entry.get("icon", ""))
	if not icon.is_empty():
		var icon_lbl := Label.new()
		icon_lbl.text = icon
		icon_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_lbl)

	# Uzun haberler ikinci satıra sarar; kısa olanlar içeriğine göre daralır
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rtl.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	rtl.add_theme_font_override("normal_font", TextOutline.get_game_font())
	rtl.add_theme_color_override("default_color", TextOutline.FONT_COLOR)
	rtl.text = String(entry.get("text", ""))
	# fit_content yalnız genişlik verilince doğru yüksekliği hesaplar: metnin doğal genişliğini ölç, sınıra kırp
	var font: Font = TextOutline.get_game_font()
	var plain: String = rtl.get_parsed_text() if rtl.is_inside_tree() else _strip_bbcode(rtl.text)
	var natural: float = font.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 8.0
	rtl.custom_minimum_size.x = minf(natural, PANEL_WIDTH - 60.0)
	row.add_child(rtl)

	var holder := HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	holder.modulate.a = 0.0
	_column.add_child(holder)
	_visible_count += 1

	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(holder, "modulate:a", 1.0, FADE_IN_SEC)
	tw.tween_interval(hold)
	tw.tween_property(holder, "modulate:a", 0.0, FADE_OUT_SEC)
	tw.tween_callback(func() -> void:
		_visible_count = maxi(0, _visible_count - 1)
		if is_instance_valid(holder):
			holder.queue_free())


static func _strip_bbcode(s: String) -> String:
	var out: String = ""
	var depth: int = 0
	for ch in s:
		if ch == "[":
			depth += 1
		elif ch == "]" and depth > 0:
			depth -= 1
		elif depth == 0:
			out += ch
	return out
