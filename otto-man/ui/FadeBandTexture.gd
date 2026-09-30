extends RefCounted
## İki ucu saydama giden siyah şerit dokusu — MainMenu'deki başlık şeridinin ("Rogue Harem"
## yazısının arkasındaki bant) dokusunun kodla üretilen hâli.
##
## Oyunun "çerçevesiz bilgi" dili bu: parşömen kutusu yerine, oyunun üstünde asılı durmayan,
## uçları eriyen bir bant. Şu an iki yerde kullanılıyor (AiVillagersChip ve dünya haritası
## bilgi balonu); üçüncü bir yere lazım olursa BURADAN al, kopyalama.
##
## class_name YOK, bilerek: bare isimle kullanmak editör taramasına bağlı ve bu projede daha
## önce parse hatalarına yol açtı (bkz. ui/npc_window.gd). Kullanım:
##   const _FadeBand := preload("res://ui/FadeBandTexture.gd")
##   band.texture = _FadeBand.make()

## Şeridin orta bandının siyah alfası — MainMenu.tscn'deki başlık şeridiyle aynı değer.
const DEFAULT_ALPHA := 0.62
## Alt/üst uçların yumuşatıldığı bölge, yüksekliğe oran olarak. Menüdeki şerit yazının
## etrafında ince bir bant olduğu için orada sert alt/üst kenar sorun değildi; kalın bir
## levha olarak kullanıldığında sert kenar tam da kaçındığımız "çerçeve" hissini geri
## getiriyor. 0.0 = menüdeki şeridin birebir aynısı.
const DEFAULT_FEATHER := 0.20

## Yatay profilin durakları — MainMenu'deki gradyanla birebir aynı, geçişler doğrusal.
const _FADE_START := 0.32
const _FADE_END := 0.68

const _TEX_W := 256
const _TEX_H := 64

## Aynı alfa/yumuşatma çiftiyle her çağrıda yeni bir görüntü üretmeyelim; pratikte bir avuç
## kombinasyon var.
static var _cache: Dictionary = {}


static func make(alpha: float = DEFAULT_ALPHA, feather: float = DEFAULT_FEATHER) -> ImageTexture:
	var key: String = "%.3f_%.3f" % [alpha, feather]
	if _cache.has(key):
		return _cache[key]
	var image := Image.create(_TEX_W, _TEX_H, false, Image.FORMAT_RGBA8)
	for y in _TEX_H:
		var vertical: float = _edge_fade(float(y) / float(_TEX_H - 1), feather)
		for x in _TEX_W:
			var horizontal: float = _band_profile(float(x) / float(_TEX_W - 1))
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha * horizontal * vertical))
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func _band_profile(t: float) -> float:
	if t < _FADE_START:
		return t / _FADE_START
	if t > _FADE_END:
		return (1.0 - t) / (1.0 - _FADE_END)
	return 1.0


static func _edge_fade(t: float, feather: float) -> float:
	if feather <= 0.0:
		return 1.0
	return smoothstep(0.0, feather, minf(t, 1.0 - t))
