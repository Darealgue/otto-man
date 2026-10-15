extends Control
## Tam ekran menülerin açılış/kapanış örtüsü: bir el siyah örtüyü ekranın sağından sola doğru sererek
## menünün arka planını oluşturur (falcı, tüccar). Kapanışta animasyon ters oynar: örtü sağa çekilip
## alttaki oyunu açar.
##
## class_name YOK (bilerek, bkz. ui/KeyChip.gd): kullanan taraf preload eder.
## Çizim 1920x1080 tasarım alanının İKİ katı genişliğinde (3840x1080) bekleniyor; son karede sağdaki
## siyah kısım ekranı tamamen kaplar, el ekranın solundan çıkmış olur. Doku yoksa animasyonsuz geçilir.
##
## Kullanım:
##   var c := _CurtainScript.new(); c.setup("res://.../el.png"); add_child(c)
##   c.play_in()  -> `covered` sinyali (örtü ekranı kapladı; menü içeriği şimdi gösterilebilir)
##   c.play_out() -> `uncovered` sinyali (örtü çekildi; menü gizlenebilir)

signal covered
signal uncovered

const IN_DURATION := 1.3
const OUT_DURATION := 0.5      # kapanış hızlı: açılışın tersi ama çok daha kısa
const END_PX := 1500.0         # son karede çizimin sola kaydığı miktar (3840 genişlikte; el çıkar, örtü kalır)

var _cloth: TextureRect
var _tween: Tween
var _start_x: float = 0.0
var _end_x: float = 0.0


func setup(texture_path: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cloth = TextureRect.new()
	_cloth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cloth.stretch_mode = TextureRect.STRETCH_SCALE
	_cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cloth.visible = false
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		_cloth.texture = load(texture_path) as Texture2D
	add_child(_cloth)


func has_cloth() -> bool:
	return _cloth != null and _cloth.texture != null


func _layout() -> void:
	var vp: Vector2 = size if size.y > 0.0 else Vector2(1920, 1080)
	var scale_f: float = vp.y / float(_cloth.texture.get_height())
	var w: float = float(_cloth.texture.get_width()) * scale_f
	_cloth.size = Vector2(w, vp.y)
	_start_x = vp.x
	_end_x = maxf(-END_PX * scale_f, vp.x - w)


func _kill() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func play_in() -> void:
	_kill()
	if not has_cloth():
		covered.emit()
		return
	_layout()
	_cloth.visible = true
	_cloth.position = Vector2(_start_x, 0.0)
	_tween = create_tween()
	_tween.tween_property(_cloth, "position:x", _end_x, IN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func(): covered.emit())


## Ters animasyon: örtü bulunduğu yerden sağa çekilir.
func play_out() -> void:
	_kill()
	if not has_cloth() or not _cloth.visible:
		uncovered.emit()
		return
	_layout()
	_tween = create_tween()
	_tween.tween_property(_cloth, "position:x", _start_x, OUT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		_cloth.visible = false
		uncovered.emit())


## Animasyonu anında bırakıp örtüyü gizler (menü aniden kapanırsa).
func reset() -> void:
	_kill()
	if _cloth:
		_cloth.visible = false
