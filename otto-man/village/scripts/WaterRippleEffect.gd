extends Node2D
## Su yüzeyinde yağmur damlası ripple efektleri oluşturur.
## Sadece köy sahnesinde çalışır. Yağmur şiddetine göre ripple spawn rate'i ayarlanır.

@export var water_sprite_path: NodePath = NodePath("../Water")
@export var water_area: Rect2 = Rect2(-2000, 100, 4000, 200)  # Su yüzeyinin kapladığı alan (X, Y, width, height)
@export var min_spawn_interval: float = 0.08  # Hafif yağmurda minimum spawn aralığı (saniye)
@export var max_spawn_interval: float = 0.5  # Hafif yağmurda maksimum spawn aralığı (saniye)
@export var heavy_rain_multiplier: float = 0.02  # Sağanakta interval bu kadar katına iner (çok sık)
@export var ripple_lifetime: float = 1.5  # Ripple'ın yaşam süresi (saniye)
@export var ripple_max_scale: float = 24.0  # Ripple'ın maksimum ölçeği (elips yarıçapı) - 5'te 1 boyut
@export var ripple_ellipse_ratio: float = 0.35  # Elips oranı (Y ekseni / X ekseni) - yukarıdan bakış açısı için
@export var ripple_line_thickness: float = 2.0  # Ripple çizgisinin kalınlığı (piksel)
@export var max_ripples: int = 600  # Maksimum eşzamanlı ripple (sağanakta çok sayı için)
@export var ripple_texture: Texture2D = null  # Opsiyonel: Kendi sprite'ını atarsan bu kullanılır (daha hızlı)
## 7 karelik yağmur damlası suya düşme efekti (rain_drop.png). Atanırsa bu kullanılır; yoksa çizgisel elips.
@export var splash_frames_texture: Texture2D = null
@export var splash_frame_duration: float = 0.2 / 7.0  # Her karenin süresi (7 kare = 0.2 saniye toplam)

var _water_sprite: Sprite2D = null
var _spawn_timer: float = 0.0
var _shared_ripple_texture: Texture2D = null  # Tüm ripple'lar aynı texture'ı kullanır
var _splash_frames: Array[Dictionary] = []  # { "node": Sprite2D, "time": float, "frame": int }

func _ready() -> void:
	# Sadece köy sahnesinde çalış
	if not _is_village_scene():
		queue_free()
		return
	
	# Su sprite'ını bul
	if water_sprite_path:
		_water_sprite = get_node_or_null(water_sprite_path)
	
	if _water_sprite:
		# Su sprite'ının gerçek boyutunu hesapla
		var texture_size = _water_sprite.texture.get_size() if _water_sprite.texture else Vector2(1, 1)
		var scaled_size = texture_size * _water_sprite.scale
		# Su alanını sprite'a göre ayarla
		water_area = Rect2(
			_water_sprite.global_position.x - scaled_size.x * 0.5,
			_water_sprite.global_position.y - scaled_size.y * 0.5,
			scaled_size.x,
			scaled_size.y
		)
		print("[WaterRippleEffect] Water area: ", water_area)
	
	# 4 karelik splash texture atanmamışsa varsayılan yolu dene (rain_drop.png)
	if splash_frames_texture == null:
		var loaded := load("res://assets/effects/rain/rain_drop.png") as Texture2D
		if loaded:
			splash_frames_texture = loaded
	
	# Ripple texture: sadece splash KULLANILMIYORSA (elips modu için)
	if splash_frames_texture == null:
		if ripple_texture:
			_shared_ripple_texture = ripple_texture
		else:
			_shared_ripple_texture = _create_ripple_texture()
	
	# Load sırasında yağmur yoksa mevcut splash'ları temizle (deferred - WeatherManager hazır olmayabilir)
	call_deferred("_check_and_clear_on_load")
	
func _create_ripple_texture() -> Texture2D:
	var texture_size := 128
	var img := Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(texture_size * 0.5, texture_size * 0.5)
	var max_radius := float(texture_size * 0.4)
	for x in texture_size:
		for y in texture_size:
			var ellipse_dist: float = sqrt((x - center.x) * (x - center.x) + ((y - center.y) / ripple_ellipse_ratio) * ((y - center.y) / ripple_ellipse_ratio))
			var alpha: float = 0.0
			var dist_from_edge: float = abs(ellipse_dist - max_radius)
			if dist_from_edge <= ripple_line_thickness * 0.5:
				alpha = 0.9
				if dist_from_edge > ripple_line_thickness * 0.3:
					alpha = lerp(0.9, 0.3, (dist_from_edge - ripple_line_thickness * 0.3) / (ripple_line_thickness * 0.2))
			if alpha > 0.0:
				img.set_pixel(x, y, Color(0.85, 0.9, 1.0, alpha))
	return ImageTexture.create_from_image(img)
	
func _is_village_scene() -> bool:
	var scene_manager = get_node_or_null("/root/SceneManager")
	if scene_manager:
		var scene_path: String = scene_manager.current_scene_path
		if scene_path:
			# VILLAGE_SCENE const'una doğrudan erişim
			var village_scene_path: String = scene_manager.VILLAGE_SCENE
			return scene_path == village_scene_path or "village" in scene_path.to_lower()
	return false

func _process(delta: float) -> void:
	if not WeatherManager:
		return
	
	var intensity: float = WeatherManager.rain_intensity
	if intensity < 0.02:  # Yağmur yoksa ripple spawn etme ve mevcut splash'ları temizle
		_spawn_timer = 0.0
		# Yağmur kesildiğinde takılı kalan splash'ları temizle
		_clear_all_splashes()
		return
	
	# Spawn interval'i yağmur şiddetine göre ayarla
	# Yoğun yağmurda daha sık spawn (interval daha kısa)
	# Intensity 0.0 -> 1.0 arasında, 1.0'da heavy_rain_multiplier kullanılır
	var min_interval: float = lerp(min_spawn_interval, min_spawn_interval * heavy_rain_multiplier, intensity)
	var max_interval: float = lerp(max_spawn_interval, max_spawn_interval * heavy_rain_multiplier, intensity)
	var current_interval: float = randf_range(min_interval, max_interval)
	
	# 7 karelik splash animasyonlarını güncelle
	_update_splash_frames(delta)
	
	_spawn_timer += delta
	# Spawn sayısı: başlangıç/hafif/orta 2 katı, sağanak çok yüksek
	var spawn_count: int = 10  # Yağmur başlangıcı (önceki 5'in 2 katı)
	if intensity > 0.6:  # Sağanak
		spawn_count = 1200 + int((intensity - 0.6) * 2000)
	elif intensity > 0.35:  # Orta yağmur (önceki 25'in 2 katı)
		spawn_count = 50
	elif intensity > 0.15:  # Hafif (önceki 10'un 2 katı)
		spawn_count = 20
	
	while _spawn_timer >= current_interval:
		_spawn_timer -= current_interval
		for i in spawn_count:
			_spawn_ripple()
		# Sonraki spawn için yeni interval
		min_interval = lerp(min_spawn_interval, min_spawn_interval * heavy_rain_multiplier, intensity)
		max_interval = lerp(max_spawn_interval, max_spawn_interval * heavy_rain_multiplier, intensity)
		current_interval = randf_range(min_interval, max_interval)

func _check_and_clear_on_load() -> void:
	# Load sonrası kontrol: eğer yağmur yoksa splash'ları temizle
	if WeatherManager and WeatherManager.rain_intensity < 0.02:
		_clear_all_splashes()

func _clear_all_splashes() -> void:
	# Tüm splash'ları temizle (yağmur kesildiğinde veya load sırasında)
	for d in _splash_frames:
		var spr: Sprite2D = d.get("node")
		if is_instance_valid(spr):
			spr.queue_free()
	_splash_frames.clear()
	
	# Child node'lardaki splash'ları da temizle (güvenlik için)
	for child in get_children():
		if child is Sprite2D and child.texture == splash_frames_texture:
			child.queue_free()

func _update_splash_frames(delta: float) -> void:
	var i := _splash_frames.size() - 1
	while i >= 0:
		var d: Dictionary = _splash_frames[i]
		d["time"] = d["time"] + delta
		if d["time"] >= splash_frame_duration:
			d["time"] = 0.0
			d["frame"] = d["frame"] + 1
			var spr: Sprite2D = d["node"]
			if is_instance_valid(spr):
				spr.frame = d["frame"]
			if d["frame"] >= 7:
				if is_instance_valid(spr):
					spr.queue_free()
				_splash_frames.remove_at(i)
		i -= 1

func _spawn_ripple() -> void:
	var total_children: int = get_child_count() + _splash_frames.size()
	if total_children >= max_ripples:
		return
	
	# Su alanı içinde rastgele bir pozisyon seç
	var spawn_x: float = randf_range(water_area.position.x, water_area.position.x + water_area.size.x)
	var spawn_y: float = randf_range(water_area.position.y, water_area.position.y + water_area.size.y)
	var spawn_pos := Vector2(spawn_x, spawn_y)
	
	# 7 karelik splash efekti kullan
	if splash_frames_texture != null:
		var splash := Sprite2D.new()
		splash.position = spawn_pos
		splash.z_index = 21
		splash.texture = splash_frames_texture
		splash.centered = true
		splash.hframes = 7
		splash.vframes = 1
		splash.frame = 0
		add_child(splash)
		_splash_frames.append({ "node": splash, "time": 0.0, "frame": 0 })
		return
	
	if not _shared_ripple_texture:
		return
	
	# Eski davranış: paylaşılan elips texture ile scale animasyonu
	var ripple := Sprite2D.new()
	ripple.position = spawn_pos
	ripple.z_index = 21
	ripple.scale = Vector2.ZERO
	ripple.texture = _shared_ripple_texture
	ripple.centered = true
	
	add_child(ripple)
	
	var tween := create_tween()
	tween.set_parallel(true)
	var max_scale_x: float = ripple_max_scale / 64.0
	var max_scale_y: float = ripple_max_scale / 64.0 * ripple_ellipse_ratio
	tween.tween_property(ripple, "scale", Vector2(max_scale_x, max_scale_y), ripple_lifetime)
	tween.tween_property(ripple, "modulate:a", 0.0, ripple_lifetime)
	tween.tween_callback(ripple.queue_free).set_delay(ripple_lifetime)
