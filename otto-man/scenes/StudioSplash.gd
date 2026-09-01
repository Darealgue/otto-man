extends Control
## One Percent Games açılış logosu. Oyun bu sahneyle başlar; animasyon bitince ana menüye
## geçer. Godot'un kendi kocaman açılış logosu project.godot'ta kapatıldı
## (application/boot_splash/show_image=false), yerini bu sahne aldı.
##
## Animasyonun hikâyesi: pil bozuk bir ampul gibi iki kez kıvılcımlanıp yanar, içindeki
## %1 göstergesi düşük pil uyarısı gibi kırmızı kırmızı yanıp söner, sonra stüdyo adı
## belirir, tam logo bir süre ekranda kalıp bir kez "nefes alır" ve siyaha kararır.
##
## Katmanlar assets/logo/ altında ayrı PNG'ler: white / red / wordmark ve her birinin blur'u.
## Hepsi 480x480 ve üst üste hizalı, o yüzden hizalama için hiçbir şey hesaplanmıyor —
## animasyon sadece modulate.a sürüyor. Blur katmanları toplamalı (additive) karışımla
## çiziliyor; siyah zeminde gerçek bir ışık saçma hissi veren şey bu.
##
## `wordmark.png` / `wordmark blur.png` elle çizilmedi: projenin kendi fontundan (Grenze,
## wght 900, "ONE PERCENT", punto 55, harf aralığı 4, blur sigma 4) 480x480 tuvale üretildi.
## Yazıyı değiştirmen gerekirse ikisini birlikte yeniden üret — sadece birini değiştirirsen
## ışıma ile yazı ayrışır. Eski elle çizilmiş `text.png` / `text blur.png` artık kullanılmıyor.

const MAIN_MENU_SCENE: String = "res://scenes/MainMenu.tscn"

## Logonun ekrandaki boyutu (kaynak 480x480). 720 = 1.5x.
@export var logo_size: float = 720.0
## Blur katmanlarının parlaklığı. 0 = ışık saçma kapalı.
@export_range(0.0, 2.0, 0.05) var glow_strength: float = 0.85
## Tüm animasyonun hız çarpanı. 1.0 ≈ 4.6 saniye.
@export_range(0.25, 4.0, 0.05) var speed_scale: float = 1.0
## Yazı belirdikten sonra tam logonun ekranda kaldığı süre (nefes alma bu sürenin içinde).
@export var hold_duration: float = 1.6
## Animasyon bittikten sonra siyaha kararma süresi.
@export var fade_out_duration: float = 0.5

@onready var _logo: Control = $Center/Logo
@onready var _white: TextureRect = $Center/Logo/White
@onready var _white_glow: TextureRect = $Center/Logo/WhiteGlow
@onready var _red: TextureRect = $Center/Logo/Red
@onready var _red_glow: TextureRect = $Center/Logo/RedGlow
@onready var _text: TextureRect = $Center/Logo/Text
@onready var _text_glow: TextureRect = $Center/Logo/TextGlow
@onready var _fade: ColorRect = $Fade

## Menüye geçiş bir kez istendi mi — hem "atla" hem normal akış buradan geçer.
var _leaving: bool = false
var _tween: Tween = null


func _ready() -> void:
	_fade.color = Color(0, 0, 0, 1)
	_logo.custom_minimum_size = Vector2(logo_size, logo_size)
	_set_layer(_white, _white_glow, 0.0)
	_set_layer(_red, _red_glow, 0.0)
	_set_layer(_text, _text_glow, 0.0)

	_tween = _build_animation()
	_tween.finished.connect(_go_to_main_menu)


## Katman çiftini (net + ışıma) tek seferde açar/kapatır. Işıma her zaman glow_strength
## kadar sönük kalır ki net çizim ışığın içinde kaybolmasın.
func _set_layer(sharp: CanvasItem, glow: CanvasItem, alpha: float) -> void:
	sharp.modulate.a = alpha
	glow.modulate.a = alpha * glow_strength


func _build_animation() -> Tween:
	var t := create_tween()
	t.set_speed_scale(maxf(0.05, speed_scale))
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_SINE)

	# Siyahtan aç.
	t.tween_property(_fade, "color:a", 0.0, 0.35)
	t.tween_interval(0.15)

	# 1) Pil, kontak eden bir devre gibi iki kez kıvılcımlanır, sonra sabit yanar.
	_blink(t, _white, _white_glow, 0.07, 0.11)
	_blink(t, _white, _white_glow, 0.06, 0.16)
	t.tween_callback(_set_layer.bind(_white, _white_glow, 1.0))
	t.tween_interval(0.22)

	# 2) İçindeki %1 göstergesi düşük pil uyarısı gibi iki kez kırmızı yanıp söner,
	#    üçüncüde açık kalır.
	_blink(t, _red, _red_glow, 0.18, 0.16)
	_blink(t, _red, _red_glow, 0.18, 0.16)
	t.tween_callback(_set_layer.bind(_red, _red_glow, 1.0))
	t.tween_interval(0.22)

	# 3) Stüdyo adı yumuşakça belirir.
	t.tween_property(_text, "modulate:a", 1.0, 0.5)
	t.parallel().tween_property(_text_glow, "modulate:a", glow_strength, 0.5)

	# 4) Tam logo ekranda kalır; bu sırada ışık bir kez nefes alıp geri yükselir.
	var hold: float = maxf(0.0, hold_duration)
	_breathe(t, 0.55, hold * 0.35)
	_breathe(t, 1.0, hold * 0.35)
	t.tween_interval(hold * 0.3)

	# 5) Siyaha kararıp menüye devret.
	t.tween_property(_fade, "color:a", 1.0, maxf(0.05, fade_out_duration))
	return t


## Sert bir yanıp sönme: on_time kadar açık, off_time kadar kapalı. Bilinçli olarak
## tween_property değil callback — bir uyarı lambası yumuşak geçiş yapmaz.
func _blink(t: Tween, sharp: CanvasItem, glow: CanvasItem, on_time: float, off_time: float) -> void:
	t.tween_callback(_set_layer.bind(sharp, glow, 1.0))
	t.tween_interval(on_time)
	t.tween_callback(_set_layer.bind(sharp, glow, 0.0))
	t.tween_interval(off_time)


## Üç ışıma katmanının parlaklığını birlikte hedefe sürer.
func _breathe(t: Tween, level: float, duration: float) -> void:
	if duration <= 0.0:
		return
	var target: float = glow_strength * level
	t.tween_property(_white_glow, "modulate:a", target, duration)
	t.parallel().tween_property(_red_glow, "modulate:a", target, duration)
	t.parallel().tween_property(_text_glow, "modulate:a", target, duration)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	var pressed: bool = false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventJoypadButton or event is InputEventMouseButton:
		pressed = event.pressed
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_go_to_main_menu()


func _go_to_main_menu() -> void:
	if _leaving:
		return
	_leaving = true
	if is_instance_valid(_tween) and _tween.is_valid():
		_tween.kill()
	## SceneManager açılışta kendini bu sahneye ayarladı; menüye geçerken düzeltiyoruz.
	## previous_scene_path'e KASITLI olarak dokunmuyoruz: MainMenu soğuk açılış akışını
	## (dil kapısı, uyarı, siyah ekran fade'i) onun boş olmasına bakarak oynatır.
	var scene_manager := get_node_or_null("/root/SceneManager")
	if scene_manager:
		scene_manager.set("current_scene_path", MAIN_MENU_SCENE)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
