extends Node

##
# Menü yazılarının boyutunu topluca büyüten global çarpan.
#
# İlk playtest (2026-08-31): "UI menülerdeki yazılar küçük, bunlara bi boyut seçeneği olsa iyi
# olur." Projede ~470 yerde sabit `font_size` var, dolayısıyla temanın `default_font_size`
# değerini değiştirmek tek başına hiçbir işe yaramıyor; bu yüzden çarpan her denetime tek tek
# uygulanıyor.
#
# KAPSAM: sadece MENÜLER. Oyun içi HUD, köy kaynak barı ve dünya haritası bilerek dışarıda
# bırakıldı (sabit genişlikli, taşmaya çok müsait alanlar). Bir menü kapsama girmek için
# `_ready()` içinde `register(self)` çağırır.
#
# Çarpan uygulanırken her denetimin ÖZGÜN punto değeri bir kez `meta` içine yazılır ve sonraki
# tüm hesaplar hep o taban değerden yapılır. Bu sayede fonksiyon istediği kadar çağrılabilir,
# değerler asla birbirinin üzerine katlanmaz.
##

signal scale_changed(new_scale: float)

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "video"
const SETTINGS_KEY := "ui_font_scale"

## Ayarlar menüsündeki üç kademe. Değiştirilirse SettingsMenu'deki etiketler de güncellenmeli.
const SCALES: Array[float] = [1.0, 1.2, 1.4]
const DEFAULT_SCALE := 1.0

const _META_PREFIX := "_ui_font_scale_base_"

const _META_PANEL_PREFIX := "_ui_font_scale_panel_"

var _scale: float = DEFAULT_SCALE
## register() ile kapsama alınmış menü kökleri: [{"root": Control, "panel": Control|null}].
## Ölçek değişince hepsi yeniden hesaplanır.
var _registered: Array[Dictionary] = []


func _ready() -> void:
	_load_from_disk()


func get_scale() -> float:
	return _scale


## Ayarlar menüsü buradan çağırır. Diske YAZMAZ — kaydetme SettingsMenu'nün kendi
## settings.cfg yazımıyla birlikte olur, iki yerden aynı dosyaya yazmayalım diye.
func set_scale(value: float) -> void:
	var clamped := clampf(value, 0.5, 3.0)
	if is_equal_approx(clamped, _scale):
		return
	_scale = clamped
	_reapply_all()
	scale_changed.emit(_scale)


## Bir menü kökünü kalıcı olarak kapsama alır: hemen uygular ve ölçek her değiştiğinde
## yeniden uygular. Menü çalışma anında yeni denetim üretiyorsa (ör. SettingsMenu'nün yapay
## zeka bölümü) o denetimler için ayrıca apply() çağırmak gerekir.
## Aynı kökle tekrar tekrar çağrılabilir: kayıt bir kez yapılır ama uygulama her seferinde
## tekrarlanır, böylece menü açılırken üretilen yeni denetimler de ölçeklenir.
##
## `panel` verilirse o panelin sabit boyutu da ölçeklenir (bkz. scale_panel).
func register(root: Control, panel: Control = null) -> void:
	if root == null:
		return
	if _index_of(root) < 0:
		_registered.append({"root": root, "panel": panel})
		root.tree_exiting.connect(_on_root_exiting.bind(root))
	elif panel != null:
		_registered[_index_of(root)]["panel"] = panel
	apply(root)
	scale_panel(panel)


func _index_of(root: Control) -> int:
	for i in range(_registered.size()):
		if _registered[i]["root"] == root:
			return i
	return -1


func _on_root_exiting(root: Control) -> void:
	var index := _index_of(root)
	if index >= 0:
		_registered.remove_at(index)


## Ortalanmış, sabit boyutlu bir paneli ölçekle birlikte büyütür.
##
## Yazılar %140'a çıkınca 640x520'lik bir kutuya sığmıyorlar ve alt satırlar parşömen
## çerçevesinin dışına taşıyordu. Sadece anchors_preset = center (dört anchor da 0.5,
## simetrik offset) panellerde doğrudur; başka yerleşimlere dokunmaz.
func scale_panel(panel: Control) -> void:
	if panel == null:
		return
	if not (is_equal_approx(panel.anchor_left, 0.5) and is_equal_approx(panel.anchor_right, 0.5) \
			and is_equal_approx(panel.anchor_top, 0.5) and is_equal_approx(panel.anchor_bottom, 0.5)):
		return
	var sides: Array[String] = ["left", "right", "top", "bottom"]
	for side in sides:
		var meta_key: String = _META_PANEL_PREFIX + side
		var property: String = "offset_" + side
		var base: float
		if panel.has_meta(meta_key):
			base = float(panel.get_meta(meta_key))
		else:
			base = float(panel.get(property))
			panel.set_meta(meta_key, base)
		panel.set(property, base * _scale)


## Verilen düğümü ve tüm alt ağacını ölçekler. İstendiği kadar çağrılabilir.
func apply(root: Node) -> void:
	if root == null:
		return
	if root is Control:
		_apply_to_control(root as Control)
	for child in root.get_children():
		apply(child)


func _reapply_all() -> void:
	var live: Array[Dictionary] = []
	for entry in _registered:
		var root: Control = entry["root"]
		if not is_instance_valid(root):
			continue
		live.append(entry)
		apply(root)
		var panel = entry["panel"]
		if panel != null and is_instance_valid(panel):
			scale_panel(panel)
	_registered = live


func _apply_to_control(control: Control) -> void:
	for item in _font_size_items(control):
		var meta_key := _META_PREFIX + item
		var base: int
		if control.has_meta(meta_key):
			base = int(control.get_meta(meta_key))
		else:
			# İlk dokunuş: o anki etkin punto taban kabul edilir (sahnedeki override ya da
			# temadan gelen değer). Bundan sonra hep bu saklanan değerden hesaplanır.
			base = control.get_theme_font_size(item)
			if base <= 0:
				continue
			control.set_meta(meta_key, base)
		var scaled := int(round(float(base) * _scale))
		control.add_theme_font_size_override(item, maxi(scaled, 1))


## Hangi tema punto kalemlerinin ölçekleneceği. Button türevleri (CheckBox, CheckButton,
## OptionButton, MenuButton) "font_size" kullanır, RichTextLabel'ın ise beş ayrı kalemi var.
func _font_size_items(control: Control) -> Array[String]:
	if control is RichTextLabel:
		return ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]
	if control is Label or control is Button or control is LinkButton \
			or control is LineEdit or control is TextEdit or control is ItemList \
			or control is TabBar or control is TabContainer or control is ProgressBar:
		return ["font_size"]
	return []


func _load_from_disk() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		_scale = DEFAULT_SCALE
		return
	_scale = clampf(float(config.get_value(SETTINGS_SECTION, SETTINGS_KEY, DEFAULT_SCALE)), 0.5, 3.0)
