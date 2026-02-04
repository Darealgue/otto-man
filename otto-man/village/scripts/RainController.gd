extends Node2D
## Yağmur partikül sistemini WeatherManager ile senkron tutar.
## Dünya uzayında çalışır: yağmur kamerayla hareket etmez. Emission kutusu
## çok geniş (world_emission_half_width) olduğu için köy ve procedural orman
## chunk'larında nereye gidilirse gidilsin yağmur hep düşer.
## Orman sahnesinde: Oyuncuya göre konumlandırılır ve uzak chunk'larda render edilmez.

@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var particles_overlap: GPUParticles2D = $GPUParticles2DOverlap

## Çakışma süresi: yeni segment bu süre boyunca eskiyle birlikte yağar, sonra ana katman güncellenir (boş an kalmaz).
@export var overlap_duration: float = 1.0

## Rastgele yağmurda kullanılan üst sınır; storm'da storm_amount_multiplier ile artar.
@export var max_amount: int = 35000
## Storm sırasında partikül sayısı bu kadar katına çıkar (geniş emission kutusunda ekranda yeterli damla görünsün).
@export var storm_amount_multiplier: float = 2.2
@export var base_velocity: float = 400.0
@export var velocity_spread: float = 80.0
@export var lifetime: float = 2.0
## Dünya biriminde emission kutusunun yarı genişliği (X). Köy + orman chunk'ları
## için çok geniş tutulur; yağmur bu aralıkta spawn olur, kamera hareket etmez.
@export var world_emission_half_width: float = 50000.0
@export var world_emission_half_height: float = 20.0
## Orman sahnesinde: Oyuncuya göre konumlandırma aktif mi? (true = oyuncuya göre, false = sabit dünya pozisyonu)
@export var follow_player_in_forest: bool = true
## Oyuncuya maksimum mesafe (piksel). Bu mesafeden uzaktaki chunk'larda yağmur render edilmez (optimizasyon).
@export var max_player_distance: float = 3000.0
## Emission alanını yeşil çerçeve ile çiz (debug; merkezde küçük işaret).
@export var debug_rain_emission: bool = false
## Yağmur bir yağıp bir duruyorsa aç: emitting/amount/intensity değişimlerini konsola yazar. Sorun çözülünce false yap.
@export var debug_rain_verbose: bool = true

var _process_material: ParticleProcessMaterial
var _process_material_overlap: ParticleProcessMaterial
var _player: Node2D = null
var _is_forest_scene: bool = false
var _last_rain_y_position: float = 0.0  # Son yağmur Y pozisyonu (büyük değişiklikleri tespit etmek için)
var _overlap_active: bool = false
var _overlap_start_time: float = 0.0
var _overlap_target_amount: int = 0


func _ready() -> void:
	if not particles:
		return
	var base_mat = particles.process_material
	if base_mat:
		_process_material = base_mat.duplicate() as ParticleProcessMaterial
		particles.process_material = _process_material
	if not _process_material:
		return
	particles.emitting = false
	particles.amount = 0
	_create_rain_texture_if_needed()
	_process_material.spread = 8.0

	if particles_overlap:
		var overlap_mat = particles_overlap.process_material
		if overlap_mat:
			_process_material_overlap = overlap_mat.duplicate() as ParticleProcessMaterial
			particles_overlap.process_material = _process_material_overlap
		particles_overlap.emitting = false
		particles_overlap.amount = 0
		if particles.texture:
			particles_overlap.texture = particles.texture
		if _process_material_overlap:
			_process_material_overlap.spread = 8.0

	# Orman sahnesi kontrolü: SceneManager veya parent node'dan kontrol et
	_check_if_forest_scene()
	
	# Emission ve visibility ayarlarını sahneye göre yap
	_setup_emission_and_visibility()
	
	# Eğer orman sahnesindeyse oyuncuyu bul
	if _is_forest_scene:
		_find_player()
		# İlk Y pozisyonunu kaydet
		if _player:
			_last_rain_y_position = _player.global_position.y - 800.0

func _check_if_forest_scene() -> void:
	_is_forest_scene = false  # Varsayılan: köy sahnesi
	
	# 1. Öncelik: SceneManager'dan current_scene_path kontrolü (en güvenilir)
	var scene_manager = get_node_or_null("/root/SceneManager")
	if scene_manager:
		# current_scene_path property'sine doğrudan erişim (SceneManager'da var)
		var scene_path: String = scene_manager.current_scene_path
		if scene_path:
			# SceneManager'da tanımlı const'larla karşılaştır
			# Const'lara doğrudan erişmeyi dene (SceneManager'da tanımlı)
			var forest_scene_path: String = ""
			var village_scene_path: String = ""
			
			# Const'lara erişmeyi dene (doğrudan erişim)
			forest_scene_path = scene_manager.FOREST_SCENE
			village_scene_path = scene_manager.VILLAGE_SCENE
			
			# Karşılaştır
			if forest_scene_path and (scene_path == forest_scene_path or "forest" in scene_path.to_lower()):
				_is_forest_scene = true
			elif village_scene_path and (scene_path == village_scene_path or "village" in scene_path.to_lower()):
				_is_forest_scene = false  # Açıkça köy sahnesi
			else:
				# Fallback: string kontrolü
				if "forest" in scene_path.to_lower():
					_is_forest_scene = true
				elif "village" in scene_path.to_lower():
					_is_forest_scene = false
	
	# 2. Alternatif: current_scene'dan scene_file_path kontrolü
	if not _is_forest_scene:
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.scene_file_path:
			var scene_path: String = current_scene.scene_file_path
			if "forest" in scene_path.to_lower():
				_is_forest_scene = true
			elif "village" in scene_path.to_lower():
				_is_forest_scene = false  # Açıkça köy sahnesi
	
	# 3. Son kontrol: Parent node ve ForestLevelGenerator kontrolü
	if not _is_forest_scene:
		var parent = get_parent()
		if parent:
			# Köy sahnesinde parent genellikle "VillageScene" olur
			if "village" in parent.name.to_lower():
				_is_forest_scene = false  # Açıkça köy sahnesi
			elif parent.scene_file_path and "forest" in parent.scene_file_path.to_lower():
				_is_forest_scene = true
		
		# ForestLevelGenerator grubunda mı kontrol et
		var forest_gen = get_tree().get_first_node_in_group("level_generator")
		if forest_gen and forest_gen.get_script() and forest_gen.get_script().resource_path:
			if "forest" in forest_gen.get_script().resource_path.to_lower():
				_is_forest_scene = true

func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		# Alternatif: ForestLevelGenerator'dan player'ı al
		var forest_gen = get_tree().get_first_node_in_group("level_generator")
		if forest_gen:
			# ForestLevelGenerator'da player property'sine doğrudan erişim
			# has() metodu Node2D'de yok, bu yüzden doğrudan property'ye erişmeyi deniyoruz
			# Eğer property yoksa null döner, bu yüzden null kontrolü yapıyoruz
			var player_prop = forest_gen.get("player")
			if player_prop:
				_player = player_prop as Node2D

func _setup_emission_and_visibility() -> void:
	# Dünya uzayında sabit, çok geniş emission: kamera hareket etmez, yağmur hep düşer
	_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	
	if _is_forest_scene:
		# Orman sahnesinde: _update_forest_position() her frame bunları güncelleyecek
		_process_material.emission_box_extents = Vector3(world_emission_half_width, world_emission_half_height, 1.0)
		var visible_half_width: float = max_player_distance
		particles.visibility_rect = Rect2(-visible_half_width - 500, -500, visible_half_width * 2.0 + 1000, 5000)
		if particles_overlap and _process_material_overlap:
			_process_material_overlap.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			_process_material_overlap.emission_box_extents = Vector3(world_emission_half_width, world_emission_half_height, 1.0)
			particles_overlap.visibility_rect = particles.visibility_rect
		print("[RainController] FOREST MODE: emission_box=", _process_material.emission_box_extents, " visibility_rect=", particles.visibility_rect)
	else:
		# Köy sahnesinde: Sabit pozisyon ve geniş visibility rect
		_process_material.emission_box_extents = Vector3(world_emission_half_width, world_emission_half_height, 1.0)
		var total_width: float = world_emission_half_width * 2.0
		particles.visibility_rect = Rect2(-world_emission_half_width - 500, -500, total_width + 1000, 5000)
		if particles_overlap and _process_material_overlap:
			_process_material_overlap.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			_process_material_overlap.emission_box_extents = Vector3(world_emission_half_width, world_emission_half_height, 1.0)
			particles_overlap.visibility_rect = particles.visibility_rect
		print("[RainController] VILLAGE MODE: emission_box=", _process_material.emission_box_extents, " visibility_rect=", particles.visibility_rect, " position=", global_position)
	
	if debug_rain_emission:
		print("[RainController] Initialized: emission half_width=", world_emission_half_width, " position=", global_position, " is_forest=", _is_forest_scene)


var _current_particles_amount: int = 0  # Mevcut partikül sistemi amount değeri
var _debug_last_intensity: float = -1.0  # Threshold kontrolü için önceki intensity değeri (debug log yok)
var _debug_last_should_emit: bool = false
var _debug_log_timer: float = 0.0  # Periyodik özet için
var _debug_last_flip_log: float = -10.0
var _debug_last_emit_log: float = -10.0
var _debug_last_update_log: float = -10.0
const _debug_interval: float = 1.0  # Aynı tür log en fazla bu sürede bir

func _process(_delta: float) -> void:
	if not particles or not _process_material:
		return
	if not WeatherManager:
		particles.emitting = false
		_overlap_active = false
		if particles_overlap:
			particles_overlap.emitting = false
		if debug_rain_emission:
			queue_redraw()
		return

	# Orman sahnesinde: Oyuncuya göre konumlandır ve uzak chunk'larda render etme
	# Köy sahnesinde: Sabit pozisyon ve geniş visibility rect (hiçbir şey değişmez)
	if _is_forest_scene and follow_player_in_forest:
		_update_forest_position()
	else:
		# Köy sahnesinde: Emission box ve visibility rect'i her frame kontrol et ve düzelt
		# (Eğer bir şekilde değiştiyse geri al)
		if not _is_forest_scene:
			# Köy sahnesinde sabit ayarları koru
			var total_width: float = world_emission_half_width * 2.0
			var expected_rect = Rect2(-world_emission_half_width - 500, -500, total_width + 1000, 5000)
			var expected_extents = Vector3(world_emission_half_width, world_emission_half_height, 1.0)
			
			# Eğer değiştiyse geri al
			if particles.visibility_rect != expected_rect:
				particles.visibility_rect = expected_rect
			if _process_material.emission_box_extents != expected_extents:
				_process_material.emission_box_extents = expected_extents
	
	var intensity: float = WeatherManager.rain_intensity
	var wind_vec: Vector2 = WeatherManager.get_wind_direction_vector()
	var wind_strength: float = WeatherManager.wind_strength
	var storm_active: bool = WeatherManager.storm_active

	var effective_max: int = max_amount
	if WeatherManager.storm_active:
		effective_max = int(float(max_amount) * storm_amount_multiplier)
	
	# Intensity'e göre amount hesapla
	var calculated_amount: int = int(float(effective_max) * intensity)
	
	# Storm: 4 katı yağmur; hafif yağmur (intensity düşük): çeyreği.
	if WeatherManager.storm_active:
		calculated_amount = int(calculated_amount * 4.0)
	elif intensity < 0.35:
		calculated_amount = int(calculated_amount * 0.25)
	
	# SORUN: Düşük intensity'de amount çok düşük oluyor ve geniş emission box'ta görünmüyor
	# ÇÖZÜM: Minimum amount garantisi - düşük intensity'de bile ekranda görünsün
	# Emission box çok geniş (100,000 birim) olduğu için minimum amount yüksek olmalı
	var min_amount_for_visibility: int = 15000  # Geniş emission box için minimum görünürlük
	if intensity > 0.02:  # Yağmur varsa
		calculated_amount = max(calculated_amount, min_amount_for_visibility)
	
	# GPU partikül sistemi limiti: maksimum 100,000 partikül (performans için)
	calculated_amount = clampi(calculated_amount, 0, 100000)
	
	var should_emit = intensity > 0.02

	if debug_rain_verbose:
		var t: float = Time.get_ticks_msec() / 1000.0
		_debug_log_timer += _delta
		if should_emit != _debug_last_should_emit:
			_debug_last_should_emit = should_emit
			if t - _debug_last_flip_log >= _debug_interval:
				_debug_last_flip_log = t
				print("[RainDEBUG] should_emit FLIP intensity=%.3f -> should_emit=%s (eşik 0.02)" % [intensity, should_emit])
		if _debug_log_timer >= 5.0:
			_debug_log_timer = 0.0
			print("[RainDEBUG] durum intensity=%.3f should_emit=%s main.emitting=%s overlap.emitting=%s overlap_active=%s amount=%d" % [
				intensity, should_emit, particles.emitting, particles_overlap.emitting if particles_overlap else false, _overlap_active, _current_particles_amount])
	
	# KRİTİK: amount değerini sadece gerçekten değiştiğinde güncelle
	# Godot'da amount değiştiğinde partikül sistemi resetlenir ve partiküller kaybolur
	# Bu yüzden amount'u sadece önemli değişikliklerde güncellemeliyiz
	
	# amount değişince Godot partikül sistemini resetler → yağmur kesilip tekrar başlar.
	# Storm'da da sadece eşik bantlarında güncelle; her frame 0.01 değişimle güncelleme (lerp ~0.12/frame).
	var should_update_amount: bool = false
	var storm_intensity_bands: Array[float] = [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0]
	
	var debug_update_reason: String = ""
	# Overlap aktifken yeni amount güncellemesi tetikleme: primary amount overlap bitene kadar 0 kalır, her frame "first_amount" tetiklenip overlap sürekli sıfırlanmasın.
	if _overlap_active:
		pass  # should_update_amount false kalır, overlap bitene kadar bekleriz
	elif WeatherManager.storm_active:
		# Storm: Sadece ilk açılışta (ve yağmur gerçekten başlıyorsa) veya intensity yeni bir banda geçtiğinde amount güncelle
		if _current_particles_amount == 0 and should_emit:
			should_update_amount = true
			debug_update_reason = "storm_first_amount"
		else:
			var prev_intensity: float = _debug_last_intensity if _debug_last_intensity >= 0.0 else 0.0
			var band_now: float = 0.0
			var band_prev: float = 0.0
			for b in storm_intensity_bands:
				if intensity >= b:
					band_now = b
				if prev_intensity >= b:
					band_prev = b
			if band_now != band_prev:
				should_update_amount = true
				debug_update_reason = "storm_band %.1f->%.1f" % [band_prev, band_now]
	else:
		# Normal yağmur: Threshold sistemi kullan (performans için)
		# İlk başlangıçta veya intensity eşiklerini geçtiğinde amount'u güncelle
		var intensity_thresholds: Array[float] = [0.0, 0.1, 0.2, 0.35, 0.5, 0.7, 0.9]
		
		if _current_particles_amount == 0 and should_emit:
			# İlk başlangıçta (yağmur gerçekten başlıyorsa) güncelle; yağmur yokken her frame 0 ile güncelleme
			should_update_amount = true
			debug_update_reason = "normal_first_amount"
		else:
			# Mevcut intensity hangi eşikte?
			var current_threshold: float = 0.0
			var new_threshold: float = 0.0
			for threshold in intensity_thresholds:
				if intensity >= threshold:
					new_threshold = threshold
			# Önceki intensity hangi eşikteydi?
			var prev_intensity: float = _debug_last_intensity if _debug_last_intensity >= 0.0 else 0.0
			for threshold in intensity_thresholds:
				if prev_intensity >= threshold:
					current_threshold = threshold
			# Eşik değiştiyse amount'u güncelle
			if new_threshold != current_threshold:
				should_update_amount = true
				debug_update_reason = "normal_threshold %.1f->%.1f" % [current_threshold, new_threshold]
	
	if debug_rain_verbose and should_update_amount:
		var t: float = Time.get_ticks_msec() / 1000.0
		if t - _debug_last_update_log >= _debug_interval:
			_debug_last_update_log = t
			print("[RainDEBUG] should_update_amount=TRUE reason=%s intensity=%.3f calculated_amount=%d" % [debug_update_reason, intensity, calculated_amount])
	
	if should_update_amount:
		# Çakışan segment: önce overlap katmanını yeni amount ile başlat, 1 sn sonra ana katmanı güncelle (boş an kalmaz)
		if particles_overlap and _process_material_overlap:
			_overlap_target_amount = calculated_amount
			_overlap_start_time = Time.get_ticks_msec() / 1000.0
			particles_overlap.amount = calculated_amount
			particles_overlap.emitting = should_emit
			_overlap_active = true
			if debug_rain_verbose and (Time.get_ticks_msec() / 1000.0) - _debug_last_update_log >= _debug_interval:
				_debug_last_update_log = Time.get_ticks_msec() / 1000.0
				print("[RainDEBUG] OVERLAP START amount=%d should_emit=%s (%.1fs sonra primary güncellenecek)" % [calculated_amount, should_emit, overlap_duration])
		else:
			_current_particles_amount = calculated_amount
			particles.amount = _current_particles_amount
			particles.emitting = should_emit
			if debug_rain_verbose and (Time.get_ticks_msec() / 1000.0) - _debug_last_update_log >= _debug_interval:
				_debug_last_update_log = Time.get_ticks_msec() / 1000.0
				print("[RainDEBUG] PRIMARY direct update amount=%d emitting=%s" % [calculated_amount, should_emit])
	
	# Çakışma süresi dolduysa ana katmanı güncelle ve overlap'i kapat; yağmur bittiyse overlap'i hemen iptal et
	if _overlap_active and particles_overlap:
		if not should_emit:
			particles_overlap.emitting = false
			_current_particles_amount = 0
			particles.amount = 0
			particles.emitting = false
			_overlap_active = false
			if debug_rain_verbose:
				var t: float = Time.get_ticks_msec() / 1000.0
				if t - _debug_last_update_log >= _debug_interval:
					_debug_last_update_log = t
					print("[RainDEBUG] OVERLAP CANCEL (yağmur durdu, intensity<=0.02)")
		else:
			var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _overlap_start_time
			if elapsed >= overlap_duration:
				_current_particles_amount = _overlap_target_amount
				particles.amount = _current_particles_amount
				particles.emitting = should_emit
				particles_overlap.emitting = false
				_overlap_active = false
				if debug_rain_verbose:
					var t: float = Time.get_ticks_msec() / 1000.0
					if t - _debug_last_update_log >= _debug_interval:
						_debug_last_update_log = t
						print("[RainDEBUG] OVERLAP END -> primary amount=%d emitting=%s" % [_current_particles_amount, should_emit])
	
	# Emitting değerini sadece değiştiğinde güncelle (overlap yoksa)
	if not _overlap_active and particles.emitting != should_emit:
		particles.emitting = should_emit
		if debug_rain_verbose:
			var t: float = Time.get_ticks_msec() / 1000.0
			if t - _debug_last_emit_log >= _debug_interval:
				_debug_last_emit_log = t
				print("[RainDEBUG] primary.emitting -> %s (intensity=%.3f)" % [should_emit, intensity])
	
	# Threshold kontrolü için intensity değerini kaydet (debug log yok)
	_debug_last_intensity = intensity

	if calculated_amount > 0:
		var dir_y: float = 1.0
		# Rüzgar şiddetine göre daha yatay yağmur - güçlü rüzgarda 45 derece veya daha fazla
		# Storm'da ve güçlü rüzgarda daha agresif açı
		var wind_multiplier: float = 0.5
		if storm_active and wind_strength > 0.5:
			wind_multiplier = 1.2  # Storm'da çok yatay
		elif wind_strength > 0.7:
			wind_multiplier = 1.0  # Güçlü rüzgarda yatay
		elif wind_strength > 0.4:
			wind_multiplier = 0.8  # Orta rüzgarda biraz yatay
		
		var dir_x: float = wind_vec.x * wind_strength * wind_multiplier
		var dir_len: float = sqrt(dir_x * dir_x + dir_y * dir_y)
		if dir_len > 0.01:
			dir_x /= dir_len
			dir_y /= dir_len
		_process_material.direction = Vector3(dir_x, dir_y, 0)
		var vel_scale: float = 1.0 + wind_strength * 0.3
		_process_material.initial_velocity_min = (base_velocity - velocity_spread) * vel_scale
		_process_material.initial_velocity_max = (base_velocity + velocity_spread) * vel_scale
		# Overlap aktifken aynı rüzgar/yönü overlap katmanına da uygula
		if _overlap_active and _process_material_overlap:
			_process_material_overlap.direction = _process_material.direction
			_process_material_overlap.initial_velocity_min = _process_material.initial_velocity_min
			_process_material_overlap.initial_velocity_max = _process_material.initial_velocity_max
		if _overlap_active and _is_forest_scene and particles_overlap:
			particles_overlap.visibility_rect = particles.visibility_rect

	if debug_rain_emission:
		queue_redraw()


func _create_rain_texture_if_needed() -> void:
	if not particles:
		return
	if particles.texture != null:
		return
	# Boy ve en yarıya indirildi (2x24 → 1x12)
	var w: int = 1
	var h: int = 12
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		for y in h:
			var alpha: float = 1.0
			if y < 2:
				alpha = float(y) / 2.0
			elif y > h - 2:
				alpha = float(h - 1 - y) / 2.0
			elif w > 1 and (x == 0 or x == w - 1):
				alpha = 0.6
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	var tex := ImageTexture.create_from_image(img)
	particles.texture = tex


## Orman sahnesinde: Oyuncuya göre konumlandır ve uzak chunk'larda render etme
func _update_forest_position() -> void:
	if not _player or not is_instance_valid(_player):
		# Oyuncu bulunamadıysa tekrar dene
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			var forest_gen = get_tree().get_first_node_in_group("level_generator")
			if forest_gen:
				# ForestLevelGenerator'da player property'sine doğrudan erişim
				var player_prop = forest_gen.get("player")
				if player_prop:
					_player = player_prop as Node2D
		if not _player:
			return
	
	var player_pos: Vector2 = _player.global_position
	
	# Yağmuru oyuncuya göre konumlandır (X ve Y ekseninde)
	# Emission box geniş olduğu için oyuncunun etrafında spawn olur
	var target_x: float = player_pos.x
	var target_y: float = player_pos.y - 800.0  # Köy sahnesindekiyle aynı offset
	
	# X ekseni için smooth takip (yatay hareket için yumuşak geçiş)
	var lerp_speed_x: float = 0.25
	global_position.x = lerp(global_position.x, target_x, lerp_speed_x)
	
	# Y ekseni için direkt takip (dikey hareket için anında takip - oyuncu düştüğünde yağmur hemen gelir)
	# Küçük Y değişikliklerinde bile reset yap (50 pikselden fazla) - oyuncu düştüğünde hemen yeni partiküller spawn olsun
	var y_change: float = abs(target_y - _last_rain_y_position)
	if y_change > 50.0:  # Çok düşük threshold (önceki: 200) - küçük değişikliklerde bile reset
		# Dikey hareket: partikül sistemini resetle ki yeni pozisyonda spawn olsun
		# Reset öncesi emitting'i true yap ki reset sonrası hemen spawn olsun
		var was_emitting: bool = particles.emitting
		particles.restart()
		if was_emitting:
			particles.emitting = true  # Reset sonrası hemen spawn olsun
	
	global_position.y = target_y
	_last_rain_y_position = target_y
	
	# Visibility rect'i oyuncuya göre güncelle (optimizasyon: uzak chunk'larda render etme)
	# Local pozisyon kullanıyoruz (RainEffect node'unun pozisyonuna göre)
	var visible_half_width: float = max_player_distance
	# Y ekseni için maksimum genişlik visibility rect (oyuncu yüksekten düştüğünde yağmur görünsün)
	# Reset sırasında partiküller kaybolmasın diye çok geniş tutuyoruz
	var visible_half_height: float = max_player_distance * 2.0  # Y ekseni için çok geniş (önceki: 1.2)
	
	# Local pozisyon (RainEffect node'unun merkezine göre)
	# Y ekseni için maksimum genişlik rect (yukarı ve aşağı çok fazla alan)
	# Bu sayede reset sırasında bile partiküller görünür kalır
	var local_rect = Rect2(
		-visible_half_width - 500,
		-visible_half_height - 1000,  # Yukarı çok fazla alan (önceki: 500)
		visible_half_width * 2.0 + 1000,
		visible_half_height * 2.0 + 8000  # Aşağı çok fazla alan (önceki: 5000)
	)
	particles.visibility_rect = local_rect
	
	# Emission box'ı geniş tut (oyuncunun etrafında geniş bir alanda spawn olur)
	# Y ekseni için maksimum yükseklik (oyuncu yüksekten düştüğünde yağmur spawn olsun)
	# Emission box'un merkezi yağmur pozisyonunda, ama Y ekseni için çok geniş tutuyoruz
	# Böylece oyuncu yukarıda veya aşağıda olsun, partiküller spawn olur
	var forest_emission_height: float = world_emission_half_height * 20.0  # Y ekseni için 20 katı yükseklik (400 birim)
	_process_material.emission_box_extents = Vector3(world_emission_half_width, forest_emission_height, 1.0)
	
	# Emission box'un Y offset'ini ayarla (partiküller oyuncunun üstünden ve altından spawn olsun)
	# Bu sayede oyuncu yüksekten düştüğünde bile partiküller görünür
	# Not: ParticleProcessMaterial'da emission box offset yok, bu yüzden visibility rect'i geniş tutuyoruz


func _draw() -> void:
	if not debug_rain_emission:
		return
	# Dünya uzayında emission merkezi (node pozisyonu); ekranda küçük işaret çiz
	draw_circle(Vector2.ZERO, 12.0, Color.GREEN)
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 16, Color.GREEN, 2.0)
	
	# Orman sahnesinde: Oyuncuya olan mesafeyi göster
	if _is_forest_scene and _player and is_instance_valid(_player):
		var player_local_pos = to_local(_player.global_position)
		draw_line(Vector2.ZERO, player_local_pos, Color.YELLOW, 2.0)
		draw_circle(player_local_pos, 8.0, Color.YELLOW)
