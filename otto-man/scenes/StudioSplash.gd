extends Control
## One Percent Games açılış logosu. Oyun bu sahneyle başlar; animasyon bitince ana menüye
## geçer. Godot'un kendi kocaman açılış logosu project.godot'ta kapatıldı
## (application/boot_splash/show_image=false), yerini bu sahne aldı.
##
## Animasyonun hikâyesi: pil bozuk bir ampul gibi iki kez kıvılcımlanıp yanar, içindeki
## %1 göstergesi düşük pil uyarısı gibi kırmızı kırmızı yanıp söner, sonra stüdyo adı
## belirir, tam logo bir süre ekranda kalıp bir kez "nefes alır" ve siyaha kararır.
## Kararmanın ardından ikinci perde açılır: oyunun adı siyah zeminde yavaşça belirip
## birkaç saniye durur ve söner. TitleLayer sahne ağacında Fade'in ALTINDA (yani üstünde
## çizilen) duruyor; yazının siyah perdenin önünde görünmesini sağlayan tek şey bu sıra.
##
## Yazı Grenze Gotisch (assets/fonts/title_font.ttf, OFL). Işıma için hazır blur PNG'si yok,
## o yüzden hale çalışma anında üretiliyor: yazının küçültülmüş bir kopyası iki geçişli
## GERÇEK Gaussian blur'dan geçirilip toplamalı (additive) karışımla net yazının arkasına
## çiziliyor (bkz. _build_title_glow ve shaders/text_glow_blur.gdshader). Önceki hâl gitgide
## kalınlaşan outline_size kopyalarını üst üste bindiriyordu; her kopya keskin kenarlı bir
## halka bıraktığı için ortaya ışıma değil izohips haritası çıkıyordu — logonun blur'ları
## için de aynı sebeple outline_size denenip atılmıştı (bkz. CLAUDE.md, "Açılış").
##
## Katmanlar assets/logo/ altında ayrı PNG'ler: white / red / wordmark ve her birinin blur'u.
## Hepsi 480x480 ve üst üste hizalı, o yüzden hizalama için hiçbir şey hesaplanmıyor —
## animasyon sadece modulate.a sürüyor. Blur katmanları toplamalı (additive) karışımla
## çiziliyor; siyah zeminde gerçek bir ışık saçma hissi veren şey bu.
##
## `white.png` / `white blur.png` de üretildi (2026-09-02, önceki elle çizilmiş hâlin yerine).
## Pil gövdesi 480x480 tuvalde: dış dikdörtgen (50,138)-(421,325) yarıçap 34, iç pencere
## (76,164)-(395,299) yarıçap 8, tırnak (427,184)-(460,274) yarıçap 6, hepsi yumuşatmasız
## (piksel art) doldurulmuş. **İç yarıçap = dış yarıçap − 26 olmak ZORUNDA**: çerçeve 26 px
## ve ancak bu eşitlikte iki köşenin merkezi çakışıp çerçeve köşede de 26 px kalıyor. Eski
## çizimde dış 11 / iç 4 idi, üstelik yaylar düzensizdi — köşelerde gözle görülür tümsekler
## vardı. Yarıçapı değiştirirsen bu bağıntıyı koru.
##
## `white blur.png` aynı şekle sigma≈4 Gauss (yarıçap 4, 3 kutu geçişi) uygulanarak üretildi;
## kenardaki alfa profili eski blur ile birebir örtüşüyor (keskin kenarda 138, ±8 px'te 0).
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

@export_group("Oyun adı")
## Yazının punto'su. Hale kalınlıkları buna oranla hesaplandığı için tek başına
## değiştirilebilir — hale kendiliğinden birlikte ölçeklenir.
@export var title_font_size: int = 170
## Logo karardıktan sonra yazının belirmeye başlamasına kadar geçen sessizlik.
@export var title_delay: float = 0.35
## Yazının siyahtan tam görünürlüğe çıkma süresi. Uzun tutuluyor — "yavaşça belirsin".
@export var title_fade_in: float = 1.5
## Yazının tam görünür halde ekranda beklediği süre.
@export var title_hold: float = 2.2
## Yazının sönme süresi. Bittiğinde ana menüye geçilir.
@export var title_fade_out: float = 0.9
## Yazı belirirken bu ölçekten 1.0'a büyür. 1.0 = büyüme yok.
@export_range(0.85, 1.0, 0.005) var title_scale_from: float = 0.965

@onready var _logo: Control = $Center/Logo
@onready var _white: TextureRect = $Center/Logo/White
@onready var _white_glow: TextureRect = $Center/Logo/WhiteGlow
@onready var _red: TextureRect = $Center/Logo/Red
@onready var _red_glow: TextureRect = $Center/Logo/RedGlow
@onready var _text: TextureRect = $Center/Logo/Text
@onready var _text_glow: TextureRect = $Center/Logo/TextGlow
@onready var _fade: ColorRect = $Fade
@onready var _title_layer: Control = $TitleLayer
@onready var _title: Label = $TitleLayer/Title

## Halenin küçültme oranı: kaynak yazı ekranın 1/4'ü boyutunda bir SubViewport'a çizilir.
## Blur bu küçük dokuda yapılıp geri büyütülüyor — hem ucuz, hem de büyütmenin lineer
## süzgeci fazladan bir yumuşatma katıyor.
const _GLOW_DOWNSCALE: int = 4
## Blur'un standart sapması, küçültülmüş piksel cinsinden. Halenin ekrandaki yayılımı kabaca
## 3 * _GLOW_SIGMA * _GLOW_DOWNSCALE ≈ 96 px — eski kontur yığınının en dış halkasıyla aynı
## genişlik. Işımayı genişletip daraltmak için buraya dokunulur; shader'daki RADIUS (24)
## 3 sigma'yı karşılayacak kadar geniş, sigma'yı büyütürsen orayı da büyüt.
const _GLOW_SIGMA: float = 8.0
const _GLOW_BLUR_SHADER: Shader = preload("res://shaders/text_glow_blur.gdshader")
## Halenin rengi: sıcak kehribar. Siyah zeminde altın hissi veriyor, kırmızı logodan
## sonra gelen perdeyi aynı sıcaklıkta tutuyor.
const _GLOW_COLOR: Color = Color(1.0, 0.72, 0.32)

## Menüye geçiş bir kez istendi mi — hem "atla" hem normal akış buradan geçer.
var _leaving: bool = false
var _tween: Tween = null


func _ready() -> void:
	_fade.color = Color(0, 0, 0, 1)
	_logo.custom_minimum_size = Vector2(logo_size, logo_size)
	_set_layer(_white, _white_glow, 0.0)
	_set_layer(_red, _red_glow, 0.0)
	_set_layer(_text, _text_glow, 0.0)

	# Yazı katmanı: hale parlaklığı logoyla aynı glow_strength'e bağlı ki ikisi tek bir
	# ışık dilinde konuşsun. Ölçek merkezden büyüsün diye pivot ekranın ortasına alınıyor;
	# _title_layer.size bu noktada henüz hesaplanmamış olabildiği için viewport'tan okuyoruz.
	_title_layer.modulate.a = 0.0
	_title_layer.pivot_offset = get_viewport_rect().size * 0.5
	_title_layer.scale = Vector2.ONE * clampf(title_scale_from, 0.5, 1.0)
	_build_title_glow()

	_tween = _build_animation()
	_tween.finished.connect(_go_to_main_menu)


## Işımayı kurar: yazının küçültülmüş bir kopyası iki geçişli gerçek Gaussian blur'dan
## geçirilip net yazının ARKASINA toplamalı olarak çizilir.
##
## Zincir üç adım: (1) küçük bir SubViewport'a yazı, hale renginde, siyah zeminde;
## (2) ikinci bir SubViewport'a onun yatay blur'u; (3) ekrana, tam boyutta, dikey blur'u.
## Kaynağın küçültülmesi hem blur'u ucuzlatıyor hem de son adımdaki lineer büyütme
## fazladan bir yumuşatma katıyor.
##
## Kopya duplicate() ile üretiliyor ki metin, font ve hizalama tek yerde (sahnedeki Title)
## kalsın; burada sadece renk ve ölçek eziliyor.
func _build_title_glow() -> void:
	_title.add_theme_font_size_override("font_size", title_font_size)

	var screen: Vector2 = get_viewport_rect().size
	var small := Vector2i(
		maxi(1, int(screen.x) / _GLOW_DOWNSCALE),
		maxi(1, int(screen.y) / _GLOW_DOWNSCALE)
	)

	# 1) Kaynak: net yazının hale renginde, küçültülmüş kopyası.
	var source_viewport := _make_glow_viewport(small)
	_title_layer.add_child(source_viewport)
	var source_text: Label = _title.duplicate() as Label
	source_text.add_theme_font_size_override("font_size", title_font_size)
	source_text.add_theme_color_override("font_color", _GLOW_COLOR)
	source_text.add_theme_constant_override("outline_size", 0)
	source_text.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	source_text.size = screen
	source_text.scale = Vector2.ONE / float(_GLOW_DOWNSCALE)
	source_viewport.add_child(source_text)

	# 2) Yatay geçiş, yine küçük bir viewport'a.
	var blur_viewport := _make_glow_viewport(small)
	_title_layer.add_child(blur_viewport)
	blur_viewport.add_child(_make_glow_rect(source_viewport.get_texture(), Vector2(1.0, 0.0)))

	# 3) Dikey geçiş, doğrudan ekrana. move_child(0) net yazının her zaman en üstte
	#    kalmasını sağlıyor; hale onun arkasından ışıyor.
	var glow := _make_glow_rect(blur_viewport.get_texture(), Vector2(0.0, 1.0))
	glow.modulate = Color(1.0, 1.0, 1.0, glow_strength)
	_title_layer.add_child(glow)
	_title_layer.move_child(glow, 0)


## Hale zincirindeki ara hedef. Zemin KASITLI olarak elle konmuş opak siyah bir ColorRect:
## viewport'un kendi temizleme rengi proje ayarına bağlı ve toplamalı karışımda sabit bir
## renk halenin üstüne binerdi.
func _make_glow_viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Proje geneli Nearest; burada küçültülmüş doku geri büyütülerek okunduğu için Linear şart.
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 1)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(backdrop)
	return viewport


## Tek eksenli blur geçişini çizen dikdörtgen; kaynak dokuyu kaplayacağı alana esnetir.
func _make_glow_rect(source: Texture2D, blur_direction: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = source
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = _GLOW_BLUR_SHADER
	mat.set_shader_parameter("direction", blur_direction)
	mat.set_shader_parameter("sigma", _GLOW_SIGMA)
	rect.material = mat
	return rect


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

	# 5) Siyaha kararır.
	t.tween_property(_fade, "color:a", 1.0, maxf(0.05, fade_out_duration))

	# 6) İkinci perde: oyunun adı siyah zeminde yavaşça belirir, durur, söner. Tween
	#    bittiğinde _go_to_main_menu zaten .finished'e bağlı olduğu için menüye geçiş
	#    kendiliğinden buranın sonunda oluyor.
	t.tween_interval(maxf(0.0, title_delay))
	t.tween_property(_title_layer, "modulate:a", 1.0, maxf(0.05, title_fade_in))
	t.parallel().tween_property(_title_layer, "scale", Vector2.ONE, maxf(0.05, title_fade_in))
	t.tween_interval(maxf(0.0, title_hold))
	t.tween_property(_title_layer, "modulate:a", 0.0, maxf(0.05, title_fade_out))
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
