class_name CardVisualUtil
extends RefCounted
## Zindan seçim kartları (powerup/item) için ortak görsel yardımcılar.
## Tek bir şablon çizim (card_template.png) sınıfa/rarity'e göre renklendirilip
## StyleBoxTexture olarak butonun arka planına basılır.

const CARD_TEMPLATE_PATH := "res://assets/Icons/card_template.png"

## Kart 320x460 çiziliyor: üst ~285px (%62) resim alanı, alt ~175px (%38) isim+açıklama metni.
## Metin bu alt bölgeye sığsın diye StyleBoxTexture'a content margin uyguluyoruz.
const CARD_ART_ZONE_HEIGHT := 285.0
const CARD_TEXT_MARGIN_SIDE := 16.0
const CARD_TEXT_MARGIN_BOTTOM := 14.0

## Aynı renk için tekrar tekrar piksel bazlı tint hesaplamayı önlemek üzere küçük bir önbellek.
static var _tint_cache: Dictionary = {}


## template'i verilen renkle çarpıp (RGB çarpım, alfa korunur) bir StyleBoxTexture döndürür.
## Şablon dosyası yoksa null döner — çağıran taraf bu durumda eski düz renkli görünüme düşmeli.
static func build_tinted_card_stylebox(tint: Color) -> StyleBoxTexture:
	var tex: Texture2D = _get_tinted_texture(tint)
	if tex == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.content_margin_top = CARD_ART_ZONE_HEIGHT
	sb.content_margin_left = CARD_TEXT_MARGIN_SIDE
	sb.content_margin_right = CARD_TEXT_MARGIN_SIDE
	sb.content_margin_bottom = CARD_TEXT_MARGIN_BOTTOM
	return sb


static func _get_tinted_texture(tint: Color) -> Texture2D:
	var key: String = tint.to_html(false)
	if _tint_cache.has(key):
		return _tint_cache[key]
	if not ResourceLoader.exists(CARD_TEMPLATE_PATH):
		return null
	var base_tex: Texture2D = load(CARD_TEMPLATE_PATH) as Texture2D
	if base_tex == null:
		return null
	var img: Image = base_tex.get_image()
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var px: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(px.r * tint.r, px.g * tint.g, px.b * tint.b, px.a))
	var tinted := ImageTexture.create_from_image(img)
	_tint_cache[key] = tinted
	return tinted


## 3 (veya N) kartı sırayla farklı yönlerden kaydırıp hafif "pop" ile büyüterek içeri sokar.
## buttons: Container'a eklenmiş, layout'u zaten bir kez oturmuş Control'ler olmalı —
## fonksiyon her birinin O ANKİ (container'ın atadığı) position'ını hedef alıp oradan geriye kaydırır.
static func play_card_entrance(buttons: Array, base_delay: float = 0.08, duration: float = 0.45) -> void:
	var count: int = buttons.size()
	for i in range(count):
		var btn: Control = buttons[i]
		if not is_instance_valid(btn):
			continue
		var final_pos: Vector2 = btn.position
		var from_offset: Vector2
		if count <= 1:
			from_offset = Vector2(0, 260)
		elif i == 0:
			from_offset = Vector2(-420, 0)
		elif i == count - 1:
			from_offset = Vector2(420, 0)
		else:
			from_offset = Vector2(0, 260)
		btn.pivot_offset = btn.size * 0.5
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.75, 0.75)
		btn.position = final_pos + from_offset
		var tw: Tween = btn.create_tween()
		tw.set_parallel(true)
		tw.tween_property(btn, "position", final_pos, duration) \
			.set_delay(i * base_delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, duration) \
			.set_delay(i * base_delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "modulate:a", 1.0, duration * 0.6) \
			.set_delay(i * base_delay).set_trans(Tween.TRANS_LINEAR)


## Kart seçildiğinde çağrılır: seçilmeyen kartlar giriş yönlerinin (sol/sağ/aşağı) tersine
## hızlıca kayıp saydamlaşarak kaybolur, seçilen kart hafifçe büyüyüp öne çıkar.
static func play_card_exit(buttons: Array, selected_index: int, duration: float = 0.25) -> void:
	var count: int = buttons.size()
	for i in range(count):
		var btn: Control = buttons[i]
		if not is_instance_valid(btn):
			continue
		var tw: Tween = btn.create_tween()
		tw.set_parallel(true)
		if i == selected_index:
			tw.tween_property(btn, "scale", Vector2(1.08, 1.08), duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			var exit_offset: Vector2
			if i == 0:
				exit_offset = Vector2(-500, 0)
			elif i == count - 1:
				exit_offset = Vector2(500, 0)
			else:
				exit_offset = Vector2(0, 320)
			tw.tween_property(btn, "position", btn.position + exit_offset, duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(btn, "modulate:a", 0.0, duration * 0.8) \
				.set_trans(Tween.TRANS_LINEAR)
