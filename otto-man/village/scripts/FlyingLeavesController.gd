extends Node2D
## Dünya koordinatında yapraklar: yağmur gibi sahnede, kameradan bağımsız. Rüzgar yönünde hareket.

@export var leaf_scene: PackedScene
@export var base_spawn_interval: float = 2.5  # Temel spawn aralığı (rüzgar şiddetine göre değişecek)
@export var min_spawn_interval: float = 0.8  # Minimum spawn aralığı (en hafif rüzgarda bile, daha seyrek)
@export var base_wind_speed: float = 120.0  # Daha yavaş ve doğal hareket için
@export var scale_min: float = 1.0  # Daha büyük yapraklar için
@export var scale_max: float = 1.5
@export var base_max_leaves: int = 10  # Temel max yaprak sayısı (rüzgar şiddetine göre artacak)

var _spawn_timer: float = 0.0
var _current_interval: float = 1.5
var _sprite_frames: SpriteFrames = null

const LEAF_ANIMATION_FOLDER: String = "res://assets/effects/leaf"
const LEAF_ANIM_NAMES: Array[String] = ["leaf1", "leaf2", "leaf3"]
const FRAMES_PER_LEAF: int = 4

func _ready() -> void:
	print("[FlyingLeavesController] _ready() başladı")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_current_interval = base_spawn_interval
	_sprite_frames = _build_leaf_sprite_frames()
	if not leaf_scene:
		set_process(false)
		printerr("[FlyingLeavesController] leaf_scene atanmamış.")
		return
	if _sprite_frames == null or _sprite_frames.get_animation_names().is_empty():
		set_process(false)
		printerr("[FlyingLeavesController] Yaprak texture'ları yüklenemedi (res://assets/effects/leaf/).")
		return
	var anim_count: int = _sprite_frames.get_animation_names().size()
	print("[FlyingLeavesController] ✅ Hazır: %d animasyon, leaf_scene=%s" % [anim_count, leaf_scene])


func _build_leaf_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	for i in range(LEAF_ANIM_NAMES.size()):
		var path: String = LEAF_ANIMATION_FOLDER.path_join(LEAF_ANIM_NAMES[i] + ".png")
		var tex := load(path) as Texture2D
		if not tex:
			print("[FlyingLeavesController] ⚠️ Texture yüklenemedi: %s" % path)
			continue
		var anim_name: String = LEAF_ANIM_NAMES[i]
		sf.add_animation(anim_name)
		var w: float = float(tex.get_width()) / float(FRAMES_PER_LEAF)
		var h: float = float(tex.get_height())
		print("[FlyingLeavesController] 📄 Texture yüklendi: %s, boyut: %dx%d, frame boyutu: %dx%d" % [path, tex.get_width(), tex.get_height(), w, h])
		for frame_idx in range(FRAMES_PER_LEAF):
			var atlas_tex := AtlasTexture.new()
			atlas_tex.atlas = tex
			atlas_tex.region = Rect2(frame_idx * w, 0, w, h)
			sf.add_frame(anim_name, atlas_tex, 0.35)  # Animasyonu yavaşlattık (0.12 -> 0.35)
	var anim_count = sf.get_animation_names().size()
	print("[FlyingLeavesController] 📊 Toplam %d animasyon oluşturuldu: %s" % [anim_count, sf.get_animation_names()])
	
	# "default" animasyonunu kaldır (eğer varsa ve boşsa)
	if "default" in sf.get_animation_names():
		if sf.get_frame_count("default") == 0:
			sf.remove_animation("default")
			print("[FlyingLeavesController] 🗑️ Boş 'default' animasyonu kaldırıldı")
	
	return sf if not sf.get_animation_names().is_empty() else null


func _process(delta: float) -> void:
	# Pause'da durdur
	if is_instance_valid(GameState) and GameState.is_paused:
		return
	
	if not WeatherManager or _sprite_frames == null or not leaf_scene:
		return
	
	var wind: float = WeatherManager.wind_strength
	var storm: bool = WeatherManager.storm_active
	
	# Rüzgar eşiği YOK - en hafif rüzgarda bile yapraklar spawn edilecek
	# Rüzgar şiddeti 0'dan 1'e kadar olabilir, minimum 0.01 olarak kabul et (daha iyi scaling)
	wind = max(wind, 0.01)  # Minimum 0.01 olarak ayarla (daha iyi görünürlük için)
	
	# Rüzgar şiddetine göre spawn interval'ını hesapla
	# Rüzgar arttıkça interval azalır (daha sık spawn)
	# En hafif rüzgarda bile yapraklar görünsün - minimum interval garantisi
	# Daha seyrek spawn için interval'ları artır
	# wind=0.01 -> interval ≈ min_spawn_interval (0.8 saniye)
	# wind=0.2 -> interval ≈ 0.6 saniye
	# wind=0.5 -> interval ≈ 0.4 saniye
	# wind=1.0 -> interval ≈ 0.3 saniye
	var wind_multiplier: float = 8.0  # Rüzgar etkisi çarpanı (biraz azaltıldı)
	# Normalize wind: minimum 0.01 olarak kabul et (daha iyi scaling için)
	var normalized_wind: float = max(wind, 0.01)
	var dynamic_interval: float = base_spawn_interval / (1.0 + pow(normalized_wind, 1.2) * wind_multiplier)
	# Minimum interval garantisi - en hafif rüzgarda bile yapraklar görünsün ama daha seyrek
	dynamic_interval = max(dynamic_interval, min_spawn_interval)
	
	# Storm aktifse daha da hızlandır
	if storm:
		dynamic_interval *= 0.5
	
	# Rüzgar şiddetine göre max yaprak sayısını hesapla
	# Rüzgar arttıkça max leaves katlanarak artar (exponential)
	# wind=0.01 -> max_leaves ≈ base_max_leaves (10)
	# wind=0.2 -> max_leaves ≈ base_max_leaves * 2.5 (25)
	# wind=0.5 -> max_leaves ≈ base_max_leaves * 6 (60)
	# wind=1.0 -> max_leaves ≈ base_max_leaves * 10 (100)
	# Exponential artış: 2^(wind * 3.3) - daha yumuşak başlangıç
	var max_leaves_multiplier: float = pow(2.0, wind * 3.3)
	var dynamic_max_leaves: int = int(base_max_leaves * max_leaves_multiplier)
	dynamic_max_leaves = max(dynamic_max_leaves, base_max_leaves)  # Minimum base_max_leaves
	dynamic_max_leaves = min(dynamic_max_leaves, 100)  # Maksimum 100 yaprak
	
	# Rüzgar şiddetine göre bir seferde spawn edilecek yaprak sayısını hesapla
	# Daha seyrek spawn için sayıyı azalt
	# wind=0.01 -> 1 yaprak (her zaman en az 1)
	# wind=0.2 -> 1-2 yaprak
	# wind=0.5 -> 2-3 yaprak
	# wind=0.8 -> 3-4 yaprak
	# wind=1.0 -> 4-5 yaprak
	var spawn_count: int = max(1, int(pow(wind, 1.5) * 5.0 + 1.0))
	spawn_count = min(spawn_count, 5)  # Maksimum 5 yaprak bir seferde (daha seyrek)
	
	# Debug: İlk birkaç frame'de rüzgar gücünü logla
	if not has_meta("wind_logged"):
		set_meta("wind_logged", true)
		print("[FlyingLeavesController] 💨 Rüzgar durumu: strength=%.4f, storm=%s, interval=%.2f, max_leaves=%d, spawn_count=%d" % [wind, storm, dynamic_interval, dynamic_max_leaves, spawn_count])

	_spawn_timer += delta
	if _spawn_timer < _current_interval:
		return
	
	_spawn_timer = 0.0
	_current_interval = dynamic_interval * randf_range(0.8, 1.2)  # Biraz rastgelelik ekle

	var leaf_count: int = 0
	for c in get_children():
		if c is Node2D and c.has_method("init_leaf"):
			leaf_count += 1
	
	if leaf_count >= dynamic_max_leaves:
		return

	# Rüzgar şiddetine göre birden fazla yaprak spawn et
	for i in range(spawn_count):
		if leaf_count + i >= dynamic_max_leaves:
			break
		_spawn_one_leaf()


func _spawn_one_leaf() -> void:
	var leaf: Node2D = leaf_scene.instantiate() as Node2D
	if not leaf or not leaf.has_method("init_leaf"):
		if leaf:
			leaf.queue_free()
		return

	var anim_names: PackedStringArray = _sprite_frames.get_animation_names()
	if anim_names.is_empty():
		leaf.queue_free()
		return
	
	# Sadece leaf1, leaf2, leaf3 animasyonlarını kullan (default'u filtrele)
	var valid_anims: Array[String] = []
	for anim in anim_names:
		if anim.begins_with("leaf") and _sprite_frames.get_frame_count(anim) > 0:
			valid_anims.append(anim)
	
	if valid_anims.is_empty():
		print("[FlyingLeavesController] ⚠️ Geçerli animasyon bulunamadı!")
		leaf.queue_free()
		return
	
	var anim_name: String = valid_anims[randi() % valid_anims.size()]
	var scale_factor: float = randf_range(scale_min, scale_max)

	var wind_dir: Vector2 = WeatherManager.get_wind_direction_vector()
	var wind_strength: float = WeatherManager.wind_strength
	var storm_active: bool = WeatherManager.storm_active
	
	# ÖNEMLİ: Rüzgar yönünü TERS ÇEVİRME - yağmur damlalarıyla aynı yöne gitmeli
	# WeatherManager.get_wind_direction_vector() rüzgarın geldiği yönü verir
	# Yağmur damlaları bu yöne doğru hareket eder, yapraklar da aynı şekilde
	
	# Yağmur damlalarıyla TAM AYNI mantık kullan
	# RainController'daki mantık: dir_y = 1.0, dir_x = wind_vec.x * wind_strength * multiplier
	var base_dir_y: float = 1.0  # Temel aşağı yönü (yağmur gibi)
	
	# Yapraklar ÇOK DAHA YATAY hareket etmeli (rüzgardan çok daha fazla etkileniyorlar)
	# Çok agresif wind_multiplier değerleri kullan
	var wind_multiplier: float = 0.8  # Normal rüzgarda bile yatay
	if storm_active and wind_strength > 0.5:
		wind_multiplier = 3.0  # Storm'da ÇOK yatay (neredeyse yatay)
	elif wind_strength > 0.7:
		wind_multiplier = 2.5  # Güçlü rüzgarda çok yatay
	elif wind_strength > 0.4:
		wind_multiplier = 1.8  # Orta rüzgarda yatay
	
	# Yapraklar için base_dir_y'yi çok azalt ki çok yatay olsun
	var leaf_dir_x: float = wind_dir.x * wind_strength * wind_multiplier
	var leaf_dir_y: float = base_dir_y * 0.5  # %50 daha yatay - çok daha az dikey bileşen
	
	# Normalize et (yağmur damlaları gibi)
	var dir_len: float = sqrt(leaf_dir_x * leaf_dir_x + leaf_dir_y * leaf_dir_y)
	if dir_len > 0.01:
		leaf_dir_x /= dir_len
		leaf_dir_y /= dir_len
	
	# Yön vektörü oluştur
	var movement_dir: Vector2 = Vector2(leaf_dir_x, leaf_dir_y)
	
	var speed: float = base_wind_speed * max(wind_strength, 0.01) * randf_range(0.7, 1.1)
	var velocity: Vector2 = movement_dir * speed

	# Dünya koordinatı: kameranın görüş alanının rüzgarın geldiği kenarında spawn (yağmur gibi ekrana girer)
	var vp := get_viewport().get_visible_rect().size
	var cam_pos: Vector2 = Vector2.ZERO
	var cam := get_viewport().get_camera_2d()
	if not cam:
		leaf.queue_free()
		return
	cam_pos = cam.global_position
	
	# Spawn pozisyonunu daha homojen dağıtmak için sistematik bir yaklaşım
	var margin: float = 100.0  # Daha uzak spawn
	var spawn_range: float = 400.0  # Daha geniş spawn alanı
	var spawn_x: float
	var spawn_y: float
	
	# Kameranın görüş alanını hesapla
	var cam_left: float = cam_pos.x - vp.x * 0.5
	var cam_right: float = cam_pos.x + vp.x * 0.5
	var cam_top: float = cam_pos.y - vp.y * 0.5
	var cam_bottom: float = cam_pos.y + vp.y * 0.5
	
	# Homojen dağılım için: ekranı eşit bölümlere ayır ve her spawn'da farklı bir bölümden spawn et
	# Spawn sayacını kullanarak daha sistematik bir dağılım sağla
	var spawn_index: int = get_meta("spawn_index", 0) as int
	set_meta("spawn_index", spawn_index + 1)
	
	# Y ekseni için ekranı 8 eşit bölüme ayır (daha homojen dağılım)
	var y_sections: int = 8
	var section_height: float = vp.y * 1.4 / y_sections  # Ekranın üstü ve altından da spawn için 1.4x
	var y_offset_start: float = cam_top - vp.y * 0.2  # Üstten biraz yukarıdan başla
	var current_section: int = spawn_index % y_sections
	var section_y: float = y_offset_start + current_section * section_height
	# Her bölüm içinde de biraz rastgelelik ekle
	var y_random_offset: float = randf_range(-section_height * 0.3, section_height * 0.3)
	
	# Yağmur damlaları gibi spawn pozisyonu: rüzgar hangi yönden geliyorsa o yönden spawn et
	# wind_dir rüzgarın geldiği yönü gösteriyor (yağmur damlalarıyla aynı)
	# X ekseni için de benzer bir homojen dağılım uygula
	if wind_dir.x > 0.2:
		# Rüzgar sağdan geliyor, yapraklar sağa gidiyor - soldan spawn et
		# X ekseni için de bölümlere ayır
		var x_sections: int = 6
		var x_section: int = (spawn_index / y_sections) % x_sections
		var x_spawn_range: float = spawn_range / x_sections
		spawn_x = cam_left - margin - x_section * x_spawn_range - randf_range(0, x_spawn_range * 0.5)
		spawn_y = section_y + y_random_offset
	elif wind_dir.x < -0.2:
		# Rüzgar soldan geliyor, yapraklar sola gidiyor - sağdan spawn et
		var x_sections: int = 6
		var x_section: int = (spawn_index / y_sections) % x_sections
		var x_spawn_range: float = spawn_range / x_sections
		spawn_x = cam_right + margin + x_section * x_spawn_range + randf_range(0, x_spawn_range * 0.5)
		spawn_y = section_y + y_random_offset
	else:
		# Dikey rüzgar - ekranın geniş bir alanından spawn et
		# X ekseni için homojen dağılım
		var x_sections: int = 10
		var x_section: int = spawn_index % x_sections
		var x_section_width: float = vp.x * 1.4 / x_sections
		var x_offset_start: float = cam_left - vp.x * 0.2
		spawn_x = x_offset_start + x_section * x_section_width + randf_range(-x_section_width * 0.3, x_section_width * 0.3)
		if wind_dir.y > 0.2:
			# Rüzgar aşağıdan geliyor, yapraklar aşağı gidiyor - yukarıdan spawn et
			var y_sections_vertical: int = 6
			var y_section_vertical: int = spawn_index % y_sections_vertical
			var y_spawn_range: float = spawn_range / y_sections_vertical
			spawn_y = cam_top - margin - y_section_vertical * y_spawn_range - randf_range(0, y_spawn_range * 0.5)
		else:
			# Rüzgar yukarıdan geliyor, yapraklar yukarı gidiyor - aşağıdan spawn et
			var y_sections_vertical: int = 6
			var y_section_vertical: int = spawn_index % y_sections_vertical
			var y_spawn_range: float = spawn_range / y_sections_vertical
			spawn_y = cam_bottom + margin + y_section_vertical * y_spawn_range + randf_range(0, y_spawn_range * 0.5)
	
	# Debug: İlk birkaç spawn'da pozisyonu logla
	var spawn_count_debug: int = get_meta("spawn_count_debug", 0) as int
	if spawn_count_debug < 5:
		set_meta("spawn_count_debug", spawn_count_debug + 1)
		print("[FlyingLeavesController] 🍃 Spawn #%d: pos=(%.1f, %.1f), cam=(%.1f, %.1f), wind_dir=(%.2f, %.2f), vp=(%.1f, %.1f)" % [spawn_count_debug + 1, spawn_x, spawn_y, cam_pos.x, cam_pos.y, wind_dir.x, wind_dir.y, vp.x, vp.y])

	add_child(leaf)
	leaf.global_position = Vector2(spawn_x, spawn_y)
	leaf.z_index = 50  # Yüksek z_index - NPC ve oyuncunun üstünde görünsün
	
	# Debug: İlk birkaç yaprak için detaylı bilgi (aynı değişkeni kullan)
	if spawn_count_debug < 5:
		print("[FlyingLeavesController] ✅ Yaprak eklendi: pos=(%.1f, %.1f), z_index=%d, anim=%s, scale=%.2f, velocity=(%.1f, %.1f)" % [spawn_x, spawn_y, z_index, anim_name, scale_factor, velocity.x, velocity.y])
	
	if leaf.has_method("set_animation_data"):
		leaf.set_animation_data(_sprite_frames, anim_name)
	if leaf.has_method("set_scale_size"):
		leaf.set_scale_size(scale_factor)
	
	# Rüzgar açısına göre rotasyon hızı ve başlangıç açısı
	var rotation_speed: float = randf_range(1.5, 3.5)
	# Güçlü rüzgarda daha hızlı rotasyon (rüzgarda sallanır gibi)
	if wind_strength > 0.5:
		rotation_speed *= 1.5
	
	# Yaprağın başlangıç rotasyonunu rüzgar açısına göre ayarla (init_leaf'ten önce)
	if leaf.has_method("set_wind_angle"):
		var wind_angle: float = rad_to_deg(atan2(leaf_dir_y, leaf_dir_x))
		leaf.set_wind_angle(wind_angle)
	
	leaf.init_leaf(velocity, rotation_speed)
