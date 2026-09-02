extends TextureRect

## Etkileşim göstergelerinin arkasına konan yumuşak koyu leke.
## Gösterge arkasındaki zemin açık olduğunda (gökyüzü, çimen, ateş ışığı) ok ikonu ve
## köylü ismi okunmuyordu; bu leke kontrastı garantiye alıyor.
##
## Bu script'in kendisi lekenin NODE'u: `attach()` bir InteractBand üretip host'un
## çocuğu yapıyor ve `show_behind_parent = true` ile arkaya alıyor. Çocuk olması
## kritik — host taşındığında, döndüğünde, modulate ile fade olduğunda leke hiçbir ek
## kod olmadan onunla birlikte hareket ediyor ve birlikte sönüyor.
##
## ── 2026-09-02'de baştan yazıldı, ilk hali üç yerden birden kötü görünüyordu ──
##   1. Genişlik host'un KUTUSUNDAN alınıyordu. Worker.tscn'deki NamePlateContainer
##      sabit 120 px; "Kemal" yazsa da kutu 120 px olduğu için leke 300 px oluyordu.
##      Artık Label'larda gerçek YAZI genişliği ölçülüyor.
##   2. Ok ile ismin lekeleri üst üste biniyordu ve çakışma bölgesinde alfalar toplanıp
##      (0.45 üstüne 0.45 → 0.70) koyu bir çizgi yapıyordu. Dikey sönümlenmeyi azaltmak
##      da alfayı düşürmek de çizgiyi yok etmedi, sadece sönükleştirdi. Çözüm iki
##      lekeyi TAM TEĞET dizmek oldu: dikeyde sönümlenme kaldırıldı (FADE_Y = 0),
##      yükseklik göstergenin yerleşim dikdörtgeni yapıldı ve Worker.gd'de ok
##      -107.5'ten -112.5'e alındı. Artık ikisi tek bir sürekli sütun gibi görünüyor.
##   3. Alfa 0.62'ydi ve çakışmada ~0.86'ya fırlıyordu. Çakışma bittiği için artık
##      sabit 0.45.

## Lekenin alfası. Çakışma olmadığı için her yerde bu değer geçerli.
const ALPHA := 0.45

## Yatay sönümlenmenin yazının bittiği yerden itibaren kaç PİKSEL sürdüğü. Oran değil
## piksel olması önemli: oranla ölçeklendiğinde "Kemal"in sönümlenmesi dar, "Abdülkerim"inki
## geniş oluyordu ve yan yana duran köylüler birbirini tutmuyordu.
const FADE_X := 16.0

## DİKEYDE SÖNÜMLENME YOK — bilerek. Alt alta duran iki göstergenin (ok + isim) yumuşak
## dikey kenarları çakıştığında alfalar toplanıp koyu bir çizgi yapıyor; keskin kenar +
## tam teğet yerleşim bunu kökten çözüyor. Ölçüldü (2026-09-02): ok lekesi ekranda
## 90..114, isim lekesi 115..144 satırlarını kaplıyor — ne boşluk ne çakışma var, sütun
## kesintisiz. Üst/alt kenarın keskin olması ayrıca ana menüdeki başlık şeridiyle aynı dil.
##
## Teğetlik üç şeye birden bağlı, birini değiştirirsen üçünü de gözden geçir:
##   - burada FADE_Y = 0 ve yükseklik göstergenin yerleşim dikdörtgeni (bkz. _refit)
##   - Worker.gd: ok butonu merkezi -112.5, isim plakası merkezi -85 (yükseklik 30)
##   - ConcubineNPC.gd: ipucu ikonu merkezi -110.0
const FADE_Y := 0.0

## Doku çözünürlüğü. Leke her boyuta esnetildiği için düşük tutuluyor; yumuşak geçiş
## için bu fazlasıyla yeterli.
const _TEX_W := 96
const _TEX_H := 32

## Sönümlenme piksel cinsinden sabit tutulduğu ve doku lekenin boyutuna esnetildiği için
## plato oranı her boyutta farklı çıkıyor; dolayısıyla tek bir doku yetmiyor. Oranları
## yuvarlayıp önbelleğe alıyoruz: pratikte birkaç farklı isim uzunluğu ve iki ikon boyutu
## var, yani sahnede onlarca köylü olsa da elde tutulan doku sayısı bir avuç kalıyor.
static var _texture_cache: Dictionary = {}
## Script'in kendine referansı. `class_name` kullanılmıyor (global sınıf önbelleğine
## kaydı headless çalıştırmalarda güvenilir değil, tüketiciler preload ile alıyor),
## bu yüzden kendi türünden node üretmek için script'i elle yüklüyoruz.
static var _self_script: GDScript = null

var _host: Control = null
## Genişliği bu Control'ün içeriğinden al (yüksekliği yine host'un). Köylülerde ok, ismin
## hemen üstünde duruyor ve aralarında boşluk yok; ok lekesi kendi dar genişliğini
## kullansaydı ismin geniş lekesiyle birleşip "T" şeklinde bir basamak yapardı. Aynı
## genişliği paylaştıklarında ikisinin birleşimi tek bir yumuşak dikdörtgen oluyor.
var _width_source: Control = null
var _last_content: Vector2 = Vector2.ZERO
var _last_text: String = "￿"
var _last_host_size: Vector2 = Vector2(-1, -1)
var _last_frame_size: Vector2 = Vector2(-1, -1)


## Yatayda ve dikeyde ayrı ayrı sönümlenen bir leke üretir. Tek boyutlu bir gradyan
## yerine gerçek bir 2B görüntü çiziliyor, çünkü yazının arkasında iyi duran şey
## yatayda uzun bir plato + dört yanda yumuşak kenar; bunu Gradient ile kurmak mümkün değil.
static func texture_for(content: Vector2) -> ImageTexture:
	var px: float = _plateau(content.x, FADE_X)
	var py: float = _plateau(content.y, FADE_Y)
	var key: String = "%d_%d" % [int(round(px * 40.0)), int(round(py * 40.0))]
	if _texture_cache.has(key):
		return _texture_cache[key]
	# Yuvarlanmış anahtarla üretiliyor ki aynı kovaya düşen farklı isimler tek doku paylaşsın.
	px = float(int(round(px * 40.0))) / 40.0
	py = float(int(round(py * 40.0))) / 40.0
	var img := Image.create(_TEX_W, _TEX_H, false, Image.FORMAT_RGBA8)
	for y in _TEX_H:
		var vy: float = _falloff(float(y) / float(_TEX_H - 1), py)
		for x in _TEX_W:
			var vx: float = _falloff(float(x) / float(_TEX_W - 1), px)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, ALPHA * vx * vy))
	var tex := ImageTexture.create_from_image(img)
	_texture_cache[key] = tex
	return tex


## İçerik + iki yanda FADE kadar sönümlenme olduğunda, opak platonun toplam boya oranı.
static func _plateau(content: float, fade: float) -> float:
	if fade <= 0.0:
		return 1.0        # o eksende hiç sönümlenme yok, kenar keskin
	var total: float = maxf(1.0, content + fade * 2.0)
	return clampf(content / total, 0.05, 0.95)


## 0..1 aralığında: ortadaki `plateau` genişliğinde 1.0, kenarlara doğru smoothstep ile 0.
static func _falloff(t: float, plateau: float) -> float:
	var d: float = absf(t - 0.5) * 2.0        # merkezde 0, kenarda 1
	if d <= plateau:
		return 1.0
	var k: float = (d - plateau) / maxf(0.0001, 1.0 - plateau)
	return 1.0 - smoothstep(0.0, 1.0, k)


## Control host (ok ikonu, ev ikonu, etkileşim butonu, isim etiketi) için leke ekler.
static func attach(host: Control, width_source: Control = null) -> Node:
	if host == null or not is_instance_valid(host):
		return null
	if host.has_node("InteractBand"):
		return host.get_node("InteractBand")
	if _self_script == null:
		_self_script = load("res://ui/InteractBand.gd") as GDScript
	var band := TextureRect.new()
	band.set_script(_self_script)
	band.name = "InteractBand"
	band.show_behind_parent = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.set("_host", host)
	band.set("_width_source", width_source)
	host.add_child(band)
	return band


func _process(_delta: float) -> void:
	if not is_instance_valid(_host):
		return
	# İsim metni değiştiğinde (Update_Villager_Name) Label sabit genişlikli kutunun içinde
	# kaldığı için `resized` ATEŞLENMİYOR; o yüzden sinyale güvenmek yerine yoklama yapıyoruz.
	# Yoklama ucuz tutuluyor: yazı ve kutu boyutu aynıysa font ölçümüne hiç girilmiyor.
	# Genişlik kaynağı varsa yoklanacak metin ONUN metni — ok butonunun kendi metni boş.
	var probe: Control = _width_source if is_instance_valid(_width_source) else _host
	var text: String = (probe as Label).text if probe is Label else ""
	# Yükseklik kapsayıcıdan geldiği için onun boyutu da yoklanıyor; sadece host'a
	# bakılsaydı kapsayıcı büyüyüp Label aynı kaldığında leke güncellenmezdi.
	var parent: Node = _host.get_parent()
	var frame: Vector2 = (parent as Control).size if parent is Container else _host.size
	if text == _last_text and _host.size.is_equal_approx(_last_host_size) \
			and frame.is_equal_approx(_last_frame_size):
		return
	_last_text = text
	_last_host_size = _host.size
	_last_frame_size = frame
	var content: Vector2 = _measure(_host)
	if is_instance_valid(_width_source):
		content.x = _measure(_width_source).x
	if content.is_equal_approx(_last_content):
		return
	_last_content = content
	_refit(content)


func _refit(content: Vector2) -> void:
	var w: float = content.x + FADE_X * 2.0
	# Yükseklik (yukarıdaki FADE_Y açıklamasına bakın): bitişik göstergelerin lekeleri
	# boşluksuz ve çakışmasız dizilsin diye lekenin dikey sınırları GÖSTERGENİN YERLEŞİM
	# DİKDÖRTGENİ oluyor. İsim plakasında esas alınacak olan Label değil KAPSAYICI: Label
	# kapsayıcıdan kısa kalabiliyor (yazı yüksekliğine göre), oysa oyunun yerleşiminde
	# teğetlik kapsayıcının kenarına göre kurulu (Worker.tscn'de -100..-70, ok butonu
	# -125..-100). Label'ı esas alsaydık aradaki farkta ince bir boşluk çizgisi kalırdı.
	var h: float = _host.size.y
	var y: float = 0.0
	var parent: Node = _host.get_parent()
	if parent is Container:
		h = (parent as Container).size.y
		y = -_host.position.y
	texture = texture_for(Vector2(content.x, h))
	# Yatayda host'un ortasına: hem isim etiketi hem ok butonu içeriğini ortalı çiziyor
	# (horizontal_alignment = 1, icon_alignment = CENTER).
	position = Vector2((_host.size.x - w) * 0.5, y)
	size = Vector2(w, h)


## İçeriğin gerçek kapladığı alan — host'un kutusu değil. Label'da bu YAZININ ölçüsü;
## sabit genişlikli plakalarda ikisi çok farklı oluyor (bkz. dosya başındaki 1. madde).
static func _measure(host: Control) -> Vector2:
	if host is Label:
		var lb := host as Label
		var font: Font = lb.get_theme_font("font")
		if font != null:
			var fs: int = lb.get_theme_font_size("font_size")
			var ts: Vector2 = font.get_string_size(
				lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs
			)
			# Kontur da yazının parçası, lekenin içinde kalsın.
			var outline: float = float(lb.get_theme_constant("outline_size"))
			return ts + Vector2(outline, outline)
	return host.size


## Sprite2D host (InteractArrowHint — çalı, ağaç, kapı; dünya uzayı) için leke.
## Bunun boyutu hiç değişmediği için ayrı bir script'e ve _process'e gerek yok.
static func attach_to_sprite(host: Sprite2D) -> Sprite2D:
	if host == null or not is_instance_valid(host) or host.texture == null:
		return null
	if host.has_node("InteractBand"):
		return host.get_node("InteractBand") as Sprite2D
	var content: Vector2 = host.texture.get_size()
	var tex := texture_for(content)
	var band := Sprite2D.new()
	band.name = "InteractBand"
	band.texture = tex
	band.show_behind_parent = true
	band.scale = Vector2(
		(content.x + FADE_X * 2.0) / float(tex.get_width()),
		(content.y + FADE_Y * 2.0) / float(tex.get_height())
	)
	host.add_child(band)
	return band
