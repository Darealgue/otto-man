extends PanelContainer
## Kaydet ve Yükle ekranlarındaki tek satır.
##
## Bilerek `class_name` KULLANMIYOR: global sınıf kaydı yalnızca editör taramasıyla
## oluşuyor, bu yüzden class_name'e bağlı dosyalar headless doğrulamada
## "Could not find type" hatası veriyor. Kullanan taraf preload sabitiyle alıyor.
##
## İki menü de aynı yerleşimi kullansın ve sütunlar satırdan satıra kaymasın diye ortak.
## Yerleşim sabit genişlikli üç sütun:
##   [ başlık + alt bilgi (esner) ][ tarih (sabit) ][ butonlar (sabit) ]
## Buton kutusunda HER ZAMAN iki yuva vardır; ikinci buton gerekmiyorsa (otomatik kayıt
## satırında Sil yok) yerine aynı boyutta görünmez bir dolgu konur. Eski sürümde bu yoktu
## ve butonlar satır satır kayıyordu.

const DATE_COLUMN_WIDTH: float = 210.0
const BUTTON_SIZE := Vector2(96.0, 38.0)
const BUTTON_SEPARATION: int = 8
const ROW_PADDING: int = 10

const COLOR_TITLE := Color(0.95, 0.93, 0.88, 1.0)
const COLOR_SUB := Color(0.70, 0.66, 0.58, 1.0)
const COLOR_DATE := Color(0.86, 0.74, 0.44, 1.0)
const COLOR_WARN := Color(0.90, 0.62, 0.35, 1.0)
const COLOR_ROW_BG := Color(1.0, 0.95, 0.85, 0.055)
const COLOR_ROW_BG_EMPTY := Color(1.0, 0.95, 0.85, 0.02)

var title_label: Label
var sub_label: Label
var date_label: Label
var primary_button: Button
var secondary_button: Button

var _bg: StyleBoxFlat
var _button_box: HBoxContainer


func _init() -> void:
	_bg = StyleBoxFlat.new()
	_bg.bg_color = COLOR_ROW_BG
	_bg.corner_radius_top_left = 4
	_bg.corner_radius_top_right = 4
	_bg.corner_radius_bottom_left = 4
	_bg.corner_radius_bottom_right = 4
	_bg.content_margin_left = ROW_PADDING
	_bg.content_margin_right = ROW_PADDING
	_bg.content_margin_top = ROW_PADDING
	_bg.content_margin_bottom = ROW_PADDING
	add_theme_stylebox_override("panel", _bg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", COLOR_TITLE)
	text_box.add_child(title_label)

	sub_label = Label.new()
	sub_label.add_theme_font_size_override("font_size", 15)
	sub_label.add_theme_color_override("font_color", COLOR_SUB)
	text_box.add_child(sub_label)

	date_label = Label.new()
	date_label.custom_minimum_size = Vector2(DATE_COLUMN_WIDTH, 0)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	date_label.add_theme_font_size_override("font_size", 17)
	date_label.add_theme_color_override("font_color", COLOR_DATE)
	row.add_child(date_label)

	_button_box = HBoxContainer.new()
	_button_box.alignment = BoxContainer.ALIGNMENT_END
	_button_box.add_theme_constant_override("separation", BUTTON_SEPARATION)
	_button_box.custom_minimum_size = Vector2(BUTTON_SIZE.x * 2.0 + float(BUTTON_SEPARATION), 0)
	row.add_child(_button_box)

	primary_button = Button.new()
	primary_button.custom_minimum_size = BUTTON_SIZE
	_button_box.add_child(primary_button)

	secondary_button = Button.new()
	secondary_button.custom_minimum_size = BUTTON_SIZE
	_button_box.add_child(secondary_button)


## İkinci butonu kullanım dışı bırakır.
##
## keep_space = true: buton yerinde kalır ama tamamen saydam ve tıklanamaz olur. Godot
## `visible = false` yapılan çocukları yerleşimden TAMAMEN çıkardığı için burada görünürlük
## kapatılamaz; kapatılırsa ilk buton sağa kayar ve diğer satırlarla hizası bozulur.
## Yükle ekranındaki otomatik kayıt satırı bunu kullanıyor.
##
## keep_space = false: sütun tamamen kaldırılır, buton kutusu tek buton genişliğine iner.
## Hiçbir satırında ikinci buton olmayan Kaydet ekranı bunu kullanıyor.
func hide_secondary_button(keep_space: bool = true) -> void:
	secondary_button.disabled = true
	secondary_button.focus_mode = Control.FOCUS_NONE
	secondary_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if keep_space:
		secondary_button.modulate = Color(1, 1, 1, 0)
	else:
		secondary_button.visible = false
		_button_box.custom_minimum_size = Vector2(BUTTON_SIZE.x, 0)


## Dolu satır: başlık, alt bilgi ve okunabilir tarih.
func set_filled(title: String, subtitle: String, date_text: String) -> void:
	title_label.text = title
	sub_label.text = subtitle
	sub_label.add_theme_color_override("font_color", COLOR_SUB)
	date_label.text = date_text
	_bg.bg_color = COLOR_ROW_BG
	modulate = Color(1, 1, 1, 1)


## Boş veya bozuk satır: tarih sütunu boş kalır, satır soluklaşır.
func set_placeholder(title: String, state_text: String, is_warning: bool = false) -> void:
	title_label.text = title
	sub_label.text = state_text
	sub_label.add_theme_color_override("font_color", COLOR_WARN if is_warning else COLOR_SUB)
	date_label.text = ""
	_bg.bg_color = COLOR_ROW_BG_EMPTY
	modulate = Color(1, 1, 1, 0.72) if not is_warning else Color(1, 1, 1, 1)


## Kayıt yerini yalnızca köy DIŞINDA göster. Kayıtların çoğu köyde alınıyor ve her satıra
## "Köy" yazmak bilgi değil gürültü; zindan veya dünya haritası kaydı ise ayırt edici.
static func location_suffix(scene_path: String) -> String:
	if scene_path.strip_edges().is_empty():
		return ""
	if scene_path.contains("Village"):
		return ""
	var name := LocaleManager.get_scene_display_name(scene_path)
	if name.is_empty():
		return ""
	return " · " + name
