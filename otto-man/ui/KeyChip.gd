extends PanelContainer
## Tek bir tuş rozeti: oyuncu klavye kullanıyorsa klavye tuşunu, gamepad kullanıyorsa gamepad
## karşılığını gösterir ve cihaz değişince kendini günceller.
##
## Eskiden bu rozet her yerde İKİ satırlıydı (üstte "Q", altta "L2") ve iki metni birden aynı
## kutuya sığdırmak için puntolar 13/9'a kadar düşürülmüştü — hiçbiri okunmuyordu (playtest,
## 2026-09-02). Oyuncu zaten tek bir cihaz kullanıyor, ikisini birden göstermenin faydası yok;
## tek satır olunca punto rahatça iki katına çıkabiliyor.
##
## class_name YOK, bilerek: bare isimle kullanmak editör taramasına bağlı ve bu projede daha
## önce "not declared in the current scope" parse hatalarına yol açtı (bkz. ui/npc_window.gd).
## Kullanım: `const _KeyChip := preload("res://ui/KeyChip.gd")`, sonra
## `var chip := _KeyChip.new(); chip.setup("Q", "L2")`.

const DEFAULT_FONT_SIZE := 18

var _keyboard_text: String = ""
var _joypad_text: String = ""
var _label: Label = null


func setup(keyboard_text: String, joypad_text: String, font_size: int = DEFAULT_FONT_SIZE) -> void:
	_keyboard_text = keyboard_text
	_joypad_text = joypad_text
	_build(font_size)
	_refresh()


func _build(font_size: int) -> void:
	if _label != null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.16, 0.08, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.78, 0.64, 0.32, 1.0)
	style.set_corner_radius_all(5)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", font_size)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _ready() -> void:
	var im := get_node_or_null("/root/InputManager")
	if im != null and im.has_signal("input_device_changed"):
		if not im.input_device_changed.is_connected(_on_input_device_changed):
			im.input_device_changed.connect(_on_input_device_changed)
	_refresh()


func _on_input_device_changed(_is_joypad: bool) -> void:
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	_label.text = _joypad_text if _is_joypad() and not _joypad_text.is_empty() else _keyboard_text


## Ağaca girmeden önce de çağrılabiliyor (setup() add_child'dan önce çalışıyor), o yüzden
## is_inside_tree kontrolü şart: ağacın dışında mutlak yolla get_node hata basar.
func _is_joypad() -> bool:
	if not is_inside_tree():
		return false
	var im := get_node_or_null("/root/InputManager")
	return im != null and bool(im.get("last_input_from_joypad"))
