extends CanvasLayer
## Dünya haritası açılış/kapanış geçişi: bulutlar ekranı kaplar, iki yana açılırken kamera haritadaki
## oyuncuya yaklaşır (Simpsonlar girişi gibi). Kapanışta tersi: kamera uzaklaşır, bulutlar kapanır,
## çıkış yapılır, bulutlar yeni sahneyi açar.
##
## class_name YOK (bilerek): WorldMapScene preload ile kullanır. Düğüm tree.root'ta yaşar, böylece harita
## sahnesi çıkışta silinse bile geçiş yarıda kalmaz. Çıkış çağrısını bu düğüm yapar (play_exit).

signal finished

const TEXTURES: Array[String] = [
	"res://assets/UI/map/map_clouds_1.png",
	"res://assets/UI/map/map_clouds_2.png",
	"res://assets/UI/map/map_clouds_3.png",
	"res://assets/UI/map/map_clouds_4.png",
	"res://assets/UI/map/map_clouds_5.png",
]
## Çizim sırası arkadan öne. Her bulut: [doku indeksi, merkez (ekran oranı), ölçek (1080 yüksekliğe göre),
## ton, hız çarpanı]. Arkadakiler daha koyu/mavi ve yavaş (derinlik hissi), öndekiler beyaz ve hızlı.
## Çizimlerin hepsi düz beyaz olduğu için örtüşen konturlar ancak ton farkıyla okunur.
const FAR_TINT := Color(0.70, 0.82, 0.95)
const BACK_TINT := Color(0.80, 0.88, 0.97)
const MID_TINT := Color(0.91, 0.95, 1.0)
const FRONT_TINT := Color(1.0, 1.0, 1.0)
## Bulutlar ÇİZİLDİĞİ ölçekte kullanılır (ölçekleme yok; yalnızca ekran çözünürlüğüne göre orantılanır).
## Konumlar 1920x1080 tasarım alanında bulutun SOL ÜST köşesidir; ekran dışına taşabilir. Dördüncü alan: yatay çevir.
## En uzaktaki üç bulut aynı çizimlerin çevrilmiş, koyu tonlu kopyalarıdır; öndekilerin arkasında kalıp
## aralardaki boşlukları kapatır (üst üste denk gelmesinler diye ön bulutların bıraktığı boşluklara konur).
const LAYOUT: Array = [
	# en arka
	[4, Vector2(760, -300), FAR_TINT, 0.70, true],
	[0, Vector2(300, 790), FAR_TINT, 0.70, true],
	[2, Vector2(-640, 230), FAR_TINT, 0.70, true],
	# arka
	[3, Vector2(-250, -60), BACK_TINT, 0.80, false],
	[1, Vector2(1180, -90), BACK_TINT, 0.80, false],
	# orta
	[0, Vector2(640, 380), MID_TINT, 0.95, false],
	# ön
	[2, Vector2(-420, 520), FRONT_TINT, 1.10, false],
	[4, Vector2(930, 560), FRONT_TINT, 1.15, false],
]
## Zemin: bulutlardan koyu gök mavisi; arka bulutlar ondan ayrışır, boşluklar uzak gökyüzü gibi görünür.
const SKY := Color(0.62, 0.76, 0.92)

const FADE_IN := 0.3             # açılışta bulutların belirmesi
const OPEN_HOLD := 0.2
const PART_TIME := 1.8           # bulutların açılma süresi (hız çarpanına bölünür)
const OPEN_BACKDROP_TIME := 0.8
const OPEN_ZOOM_TIME := 2.6
const CLOSE_CLOUD_TIME := 1.3
const CLOSE_ZOOM_TIME := 1.5
const PART_SCALE := 1.0          # bulutlar açılırken de ölçeklenmez
const EXIT_TIMEOUT := 8.0

var _backdrop: ColorRect
var _clouds: Array[TextureRect] = []
var _speeds: Array[float] = []
var _cover_pos: Array[Vector2] = []
var _off_pos: Array[Vector2] = []
var _cam: Camera2D


func _init() -> void:
	layer = 500   # yükleme ekranının (400) da üstünde: ekran kararırken bulutlar görünür kalır
	process_mode = Node.PROCESS_MODE_ALWAYS


func _build(vp: Vector2) -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = SKY
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP   # geçiş sürerken tıklamalar arkaya geçmesin
	add_child(_backdrop)
	var s_h: float = vp.y / 1080.0
	for entry in LAYOUT:
		var tex := load(TEXTURES[int(entry[0])]) as Texture2D
		if tex == null:
			continue
		var c := TextureRect.new()
		c.texture = tex
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_SCALE
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.self_modulate = entry[2] as Color   # ton self_modulate'te, solma modulate'te: ikisi çarpışmasın
		c.flip_h = bool(entry[4])
		var sz: Vector2 = tex.get_size() * s_h
		c.size = sz
		c.pivot_offset = sz * 0.5
		# 1920x1080 tasarım alanını ekranın ortasına oturt (daha geniş ekranda yanlara eşit pay)
		var origin_x: float = (vp.x - 1920.0 * s_h) * 0.5
		var cover: Vector2 = Vector2(origin_x + (entry[1] as Vector2).x * s_h, (entry[1] as Vector2).y * s_h)
		var centre_x: float = cover.x + sz.x * 0.5
		var off := cover
		# Bulut ekranın hangi yarısındaysa o yana, tamamen ekran dışına çıkar
		if centre_x > vp.x * 0.5 + 8.0:
			off.x = vp.x + 60.0
		else:
			off.x = -sz.x - 60.0
		add_child(c)
		_clouds.append(c)
		_speeds.append(float(entry[3]))
		_cover_pos.append(cover)
		_off_pos.append(off)


func _viewport_size() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(1920, 1080)


func _set_zoom(z: float) -> void:
	if is_instance_valid(_cam):
		_cam.zoom = Vector2(z, z)


func _place(positions: Array[Vector2], scale_f: float, alpha: float) -> void:
	for i in range(_clouds.size()):
		_clouds[i].position = positions[i]
		_clouds[i].scale = Vector2(scale_f, scale_f)
		_clouds[i].modulate.a = alpha


## Açılış: bulutlar belirip ekranı kaplar, sonra açılırken kamera zoom_from'dan zoom_to'ya yaklaşır.
func play_open(camera: Camera2D, zoom_from: float, zoom_to: float) -> void:
	_cam = camera
	_build(_viewport_size())
	_place(_cover_pos, 1.0, 0.0)
	_backdrop.color.a = 0.0
	_set_zoom(zoom_from)
	var tin := create_tween().set_parallel(true)
	tin.tween_property(_backdrop, "color:a", 1.0, FADE_IN)
	for c in _clouds:
		tin.tween_property(c, "modulate:a", 1.0, FADE_IN)
	await tin.finished
	await get_tree().create_timer(OPEN_HOLD).timeout
	await _part_clouds(zoom_from, zoom_to, OPEN_ZOOM_TIME)
	finished.emit()
	queue_free()


## Bulutlar iki yana açılır: hareket ederken son kısımda solarak yok olurlar (zoom_to = zoom_from ise kamera oynamaz).
func _part_clouds(zoom_from: float, zoom_to: float, zoom_time: float) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_backdrop, "color:a", 0.0, OPEN_BACKDROP_TIME).set_ease(Tween.EASE_IN)
	for i in range(_clouds.size()):
		var dur: float = PART_TIME / _speeds[i]
		t.tween_property(_clouds[i], "position", _off_pos[i], dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(_clouds[i], "scale", Vector2(PART_SCALE, PART_SCALE), dur)
		t.tween_property(_clouds[i], "modulate:a", 0.0, dur * 0.45).set_delay(dur * 0.55)
	if not is_equal_approx(zoom_from, zoom_to):
		t.tween_method(_set_zoom, zoom_from, zoom_to, zoom_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## Kapanış + çıkış + yeni sahneyi açma. `exit_call` harita sahnesinin çıkış çağrısıdır (sahne değiştirir
## ya da overlay'i kapatır); bu düğüm onu kendisi çağırır çünkü harita düğümü çıkışla birlikte silinir.
func play_exit(camera: Camera2D, zoom_far: float, exit_call: Callable, map_node: Node) -> void:
	_cam = camera
	var start_zoom: float = camera.zoom.x if is_instance_valid(camera) else zoom_far
	_build(_viewport_size())
	_place(_off_pos, PART_SCALE, 0.0)
	_backdrop.color.a = 0.0
	var t := create_tween().set_parallel(true)
	for i in range(_clouds.size()):
		var dur: float = CLOSE_CLOUD_TIME / _speeds[i]
		t.tween_property(_clouds[i], "position", _cover_pos[i], dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(_clouds[i], "scale", Vector2.ONE, dur)
		t.tween_property(_clouds[i], "modulate:a", 1.0, dur * 0.4)
	t.tween_property(_backdrop, "color:a", 1.0, 0.5).set_delay(CLOSE_CLOUD_TIME * 0.5)
	t.tween_method(_set_zoom, start_zoom, zoom_far, CLOSE_ZOOM_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished

	var tree := get_tree()
	var old_scene: Node = tree.current_scene
	if exit_call.is_valid():
		exit_call.call()

	# Sahne değişimini (ya da overlay'in kapanmasını) bekle; en geç EXIT_TIMEOUT sonra yine de aç
	var waited := 0.0
	var exited := false
	while waited < EXIT_TIMEOUT:
		await tree.create_timer(0.05).timeout
		waited += 0.05
		var map_gone: bool = not is_instance_valid(map_node) or map_node.is_queued_for_deletion()
		if map_gone or tree.current_scene != old_scene:
			exited = true
			break
	if exited:
		await tree.create_timer(0.5).timeout   # yükleme ekranı soluyor, yeni sahne oturuyor
	else:
		# Çıkış olmadı (hata/engel): haritayı geri getir
		_set_zoom(start_zoom)
		if is_instance_valid(map_node) and map_node.has_method("_on_exit_transition_aborted"):
			map_node.call("_on_exit_transition_aborted")
	_cam = null
	await _part_clouds(start_zoom, start_zoom, 0.0)
	finished.emit()
	queue_free()
