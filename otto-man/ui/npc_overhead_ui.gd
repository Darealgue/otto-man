class_name NpcOverheadUi
extends RefCounted

## Köylü kafasındaki isim plakası ve etkileşim tuşu — parşömen/çerçeve olmadan.

const NAMEPLATE_FONT_COLOR := Color(0.95, 0.93, 0.88, 1)
const NAMEPLATE_OUTLINE_COLOR := Color(0, 0, 0, 1)
const NAMEPLATE_OUTLINE_SIZE := 3
const NAMEPLATE_FONT_SIZE := 16

const UP_ARROW_ICON: Texture2D = preload("res://assets/Icons/up_arrow_icon.png")
const ARROW_ICON_SIZE := Vector2(20.0, 20.0)

const UP_ARROW_TALK_ICON: Texture2D = preload("res://assets/Icons/up_arrow_talk_icon.png")

const HOUSE_HINT_ICON: Texture2D = preload("res://assets/Icons/menu_house_icon.png")
const HOUSE_ICON_SIZE := Vector2(20.0, 20.0)


## "Yukarı bas" tipi etkileşimler için cihazdan bağımsız sabit bir ok ikonu — klavye/gamepad
## metnine göre değişmiyor, bu yüzden "D-Pad" gibi metinlerin sızması da kökten mümkün değil.
## Konuşulabilen NPC'ler (köylü/mentor/tüccar) için build_up_arrow_talk_hint_icon() kullanılır;
## bu düz ok, inşaat/kamp ateşi gibi konuşma içermeyen etkileşimler içindir.
static func build_up_arrow_hint_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "InteractHintIcon"
	icon.texture = UP_ARROW_ICON
	icon.custom_minimum_size = ARROW_ICON_SIZE
	icon.size = ARROW_ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## Konuşma balonu içeren ok ikonu — köylü/mentor/tüccar gibi diyalog açan NPC'lerin üzerinde
## gösterilir; inşaat/kamp ateşi gibi konuşma içermeyen etkileşimlerde düz build_up_arrow_hint_icon()
## kullanılmaya devam eder.
static func build_up_arrow_talk_hint_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "InteractHintIcon"
	icon.texture = UP_ARROW_TALK_ICON
	icon.custom_minimum_size = ARROW_ICON_SIZE
	icon.size = ARROW_ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## İnşaat parsellerinde (boş veya üzerinde bina olan) tek başına gösterilen ev ikonu — "yukarı
## basınca inşaat yap / binaya gir" bilgisini metinsiz, cihazdan bağımsız şekilde verir.
static func build_house_hint_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "BuildHintIcon"
	icon.texture = HOUSE_HINT_ICON
	icon.custom_minimum_size = HOUSE_ICON_SIZE
	icon.size = HOUSE_ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


const FADE_DURATION := 0.15

## Etkileşim ok/ikon ipuçlarının sert "anında görün/kaybol" yerine yumuşak fade in/out ile
## girip çıkması için — sahneye aniden zıplayıp gözden kaybolmuyorlar.
static func fade_show_icon(control: Control, duration: float = FADE_DURATION) -> void:
	if control == null:
		return
	if control.visible and control.modulate.a >= 1.0:
		return
	_kill_fade_tween(control)
	if not control.visible:
		# Tamamen gizliyken alpha'nın önceki (kalıntı) değeri önemsiz — her zaman 0'dan başlat.
		control.modulate.a = 0.0
	control.visible = true
	var tween := control.create_tween()
	control.set_meta("_fade_tween", tween)
	tween.tween_property(control, "modulate:a", 1.0, duration)


static func fade_hide_icon(control: Control, duration: float = FADE_DURATION) -> void:
	if control == null:
		return
	if not control.visible:
		return
	_kill_fade_tween(control)
	var tween := control.create_tween()
	control.set_meta("_fade_tween", tween)
	tween.tween_property(control, "modulate:a", 0.0, duration)
	tween.tween_callback(func() -> void:
		control.visible = false)


static func _kill_fade_tween(control: Control) -> void:
	var existing: Variant = control.get_meta("_fade_tween", null)
	if existing is Tween and (existing as Tween).is_valid():
		(existing as Tween).kill()


static func apply_frameless_nameplate(container: PanelContainer) -> void:
	if container == null:
		return
	container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


static func apply_frameless_interact_button(button: Button, name_reference: Label = null) -> void:
	if button == null:
		return
	var empty := StyleBoxEmpty.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_name, empty)
	apply_nameplate_text_style(button, name_reference)


static func apply_nameplate_text_style(control: Control, name_reference: Label = null) -> void:
	if control == null:
		return
	TextOutline.apply_font_to_control(control)
	var font_size := NAMEPLATE_FONT_SIZE
	if name_reference != null:
		font_size = name_reference.get_theme_font_size("font_size")
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", NAMEPLATE_FONT_COLOR)
	control.add_theme_color_override("font_outline_color", NAMEPLATE_OUTLINE_COLOR)
	control.add_theme_constant_override("outline_size", NAMEPLATE_OUTLINE_SIZE)
	if control is Button:
		var btn := control as Button
		btn.add_theme_color_override("font_hover_color", NAMEPLATE_FONT_COLOR)
		btn.add_theme_color_override("font_pressed_color", NAMEPLATE_FONT_COLOR)
		btn.add_theme_color_override("font_focus_color", NAMEPLATE_FONT_COLOR)
		btn.add_theme_color_override("font_disabled_color", NAMEPLATE_FONT_COLOR)


static func sync_horizontal_flip(host: Node2D, ui_nodes: Array) -> void:
	if not is_instance_valid(host):
		return
	var flip := -1.0 if host.scale.x < 0.0 else 1.0
	for node in ui_nodes:
		if node is CanvasItem and is_instance_valid(node):
			(node as CanvasItem).scale.x = flip


## "interact" aksiyonu klavye düzenine göre değişik fiziksel tuşlara bağlanabiliyor (bkz.
## InputManager._KEYBOARD_PRESETS — WASD_NUMPAD'de Num8, ARROWS_QWEASD'de W), gamepad'de ise
## D-Pad Up / sol çubuk yukarı. Hangi tuş olursa olsun anlamı hep "yukarı bas" olduğundan, metin
## yerine sabit ok ikonuyla gösteriyoruz — hem diğer "yukarı bas" ipuçlarıyla tutarlı olsun hem
## de basılı-tutma halkası (NpcInteractHoldRing) ince/ortalanmamış bir glif yerine sabit
## boyutlu bir ikonun etrafında dönsün. Bu buton sadece köylülerle (Worker) konuşmayı açtığı
## için konuşma balonlu ok kullanılıyor.
static func apply_interact_hint_text(button: Button) -> void:
	if button == null:
		return
	button.text = ""
	button.icon = UP_ARROW_TALK_ICON
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER


## Ring, target_control'ün ÇOCUĞU olarak eklenir (host'un değil) — böylece kontrol sahne
## ışığından kaçmak için ayrı bir CanvasLayer'a taşınırsa (bkz. OverheadUiTracker) ring de
## otomatik olarak onunla birlikte taşınır, ayrıca senkronize edilmesine gerek kalmaz.
## target_control bir Button (E tuşu) veya düz bir ikon (TextureRect, ör. yukarı ok) olabilir.
static func attach_hold_ring(host: Node, target_control: Control) -> NpcInteractHoldRing:
	if host == null or target_control == null:
		return null
	var ring := NpcInteractHoldRing.new()
	ring.name = "InteractHoldRing"
	ring.z_index = target_control.z_index
	target_control.add_child(ring)
	ring.sync_to_control(target_control)
	ring.visible = false
	return ring
