extends Node2D

# Binanın arkasına konan düz renkli "kalınlık" katmanı. Bina gövde sprite'larının siluetini koyu tek renkle çizer ve
# kameranın bina merkezine göre sağında/solunda olmasına göre birkaç piksel yana kaydırır; böylece bina kağıt gibi
# değil kalın bir karton gibi görünür (yan yüz hissi). BuildingDepthManager tarafından binanın child'ı olarak eklenir.

const SLAB_COLOR: Color = Color(0.27, 0.15, 0.11, 1.0)
const MAX_OFFSET: float = 8.0              # en fazla kaç piksel kayar (= görünen "kalınlık")
const FULL_OFFSET_DISTANCE: float = 500.0  # kamera bina merkezinden bu kadar uzaktayken tam kayma
const FOLLOW_SPEED: float = 8.0
const MIN_BODY_WIDTH: float = 150.0        # bundan dar sprite'lar (kapı, pencere, süs) siluete katılmaz
const REFRESH_INTERVAL: float = 0.5        # kat eklenmesi gibi değişiklikleri yakalamak için kontrol aralığı
const SLAB_Z_INDEX: int = -2

static var _silhouette_cache: Dictionary = {}

# Sahneye göre değişebilir: ziyaret köyünde zemin resmi z -1'de olduğu için orada katman da -1'e alınır
# (aynı z'de ağaç sırası belirler, bina sonradan eklendiği için zeminin üstünde çizilir).
var z_override: int = SLAB_Z_INDEX

var _host: Node2D = null
var _clones: Array[Sprite2D] = []
var _signature: String = ""
var _refresh_timer: float = 0.0
var _current_offset: float = 0.0

func _ready() -> void:
	name = "DepthSlab"
	_host = get_parent() as Node2D
	if _host == null:
		set_process(false)
		return
	z_index = z_override
	_rebuild()
	_current_offset = _target_offset()
	position.x = roundf(_current_offset)

func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		var sig: String = _compute_signature(_collect_body_sprites())
		if sig != _signature:
			_rebuild()
	_current_offset = lerpf(_current_offset, _target_offset(), 1.0 - exp(-FOLLOW_SPEED * delta))
	position.x = roundf(_current_offset)  # tam piksele oturt, titreme olmasın

# Kamera bina merkezinin sağındaysa katman sağa, solundaysa sola kayar (arka yüz görüş noktasına doğru yaklaşır).
func _target_offset() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam == null or _host == null:
		return 0.0
	var rel: float = cam.get_screen_center_position().x - _host.global_position.x
	return clampf(rel / FULL_OFFSET_DISTANCE, -1.0, 1.0) * MAX_OFFSET

func _collect_body_sprites() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	_collect_recursive(_host, out)
	return out

func _collect_recursive(node: Node, out: Array[Sprite2D]) -> void:
	for child in node.get_children():
		if child == self:
			continue
		if child is Sprite2D:
			var s: Sprite2D = child
			if s.texture != null and s.hframes == 1 and s.vframes == 1 and s.is_visible_in_tree() \
					and not String(s.name).begins_with("Window") \
					and s.texture.get_width() * absf(s.global_scale.x) >= MIN_BODY_WIDTH:
				out.append(s)
		_collect_recursive(child, out)

func _compute_signature(sprites: Array[Sprite2D]) -> String:
	var parts: PackedStringArray = []
	for s in sprites:
		parts.append("%d|%s|%s" % [s.get_instance_id(), str(s.global_position.round()), str(s.texture.get_rid().get_id())])
	return ";".join(parts)

func _rebuild() -> void:
	for c in _clones:
		if is_instance_valid(c):
			c.queue_free()
	_clones.clear()
	var sprites: Array[Sprite2D] = _collect_body_sprites()
	_signature = _compute_signature(sprites)
	var host_inverse: Transform2D = _host.global_transform.affine_inverse()
	for s in sprites:
		var sil: Texture2D = _get_silhouette(s.texture)
		if sil == null:
			continue
		var clone := Sprite2D.new()
		clone.texture = sil
		clone.centered = s.centered
		clone.offset = s.offset
		clone.flip_h = s.flip_h
		clone.flip_v = s.flip_v
		clone.region_enabled = s.region_enabled
		clone.region_rect = s.region_rect
		clone.modulate = SLAB_COLOR
		add_child(clone)
		clone.transform = host_inverse * s.global_transform
		_clones.append(clone)

# Sprite'ın opak piksellerini beyaza çevirip saydam yerleri koruyan siluet dokusu (doku başına önbellekli).
# Renk, clone.modulate ile SLAB_COLOR olarak verilir.
static func _get_silhouette(tex: Texture2D) -> Texture2D:
	if _silhouette_cache.has(tex):
		return _silhouette_cache[tex]
	var result: Texture2D = null
	var img: Image = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var data: PackedByteArray = img.get_data()
		for i in range(0, data.size(), 4):
			var solid: bool = data[i + 3] >= 128
			data[i] = 255
			data[i + 1] = 255
			data[i + 2] = 255
			data[i + 3] = 255 if solid else 0
		result = ImageTexture.create_from_image(Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data))
	_silhouette_cache[tex] = result
	return result
