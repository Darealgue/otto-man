extends Node
## Hava durumu merkezi: yağmur, rüzgar, storm event bağlantısı.
## Oyun içi zamana göre güncellenir; köy ve orman aynı değerleri kullanır.

# --- Yağmur ---
## Mevcut yağmur şiddeti (0 = yok, 1 = sağanak). Görsel sistemler bunu okur.
var rain_intensity: float = 0.0
## Hedef yağmur şiddeti; her frame rain_intensity buna doğru lerp edilir.
var _target_rain_intensity: float = 0.0
## Storm aktifken true; rastgele yağmur devre dışı, yoğun yağış zorlanır.
var storm_active: bool = false
## Storm seviyesi (EventLevel.LOW/MEDIUM/HIGH) storm aktifken kullanılır.
var storm_level: int = 1

# --- Rüzgar ---
## Rüzgar gücü (0 = durgun, 1 = çok güçlü). Ağaç sallanması ve damla açısı için.
var wind_strength: float = 0.0
## Rüzgar yönü (derece): 0 = sağa, 90 = aşağı, 180 = sola, 270 = yukarı.
var wind_direction_angle: float = 0.0
var _target_wind_strength: float = 0.0
var _target_wind_direction: float = 0.0

# --- Rastgele yağmur (oyun içi süre) ---
const RAIN_DURATION_MIN_MINUTES: int = 20
const RAIN_DURATION_MAX_MINUTES: int = 50
const CLEAR_DURATION_MIN_MINUTES: int = 60
const CLEAR_DURATION_MAX_MINUTES: int = 180
const CHANCE_RAIN_STARTS_PER_CHECK: float = 0.25
const RAIN_LERP_SPEED: float = 0.015
const WIND_LERP_SPEED: float = 0.02
## Storm başladığında yağmur/rüzgar hedefe bu hızla çıkar (sağanak hemen hissedilsin).
const STORM_LERP_SPEED: float = 0.12

var _last_total_game_minutes: int = -1
var _rain_minutes_remaining: int = 0
var _clear_minutes_remaining: int = 0
var _is_raining_randomly: bool = false
var _random_rain_target: float = 0.0  # Final hedef intensity
var _rain_starting: bool = false  # Yağmur başlangıç aşamasında (kesintisiz seyrek yağmur)
var _rain_ending: bool = false  # Yağmur bitiş aşamasında (kademeli azalış)
var _rain_start_minutes_remaining: int = 0  # Başlangıç aşaması süresi
var _rain_transition_minutes_remaining: int = 0  # Geçiş aşaması süresi (hafif→orta→yoğun)
var _current_rain_stage: int = 0  # 0=başlangıç, 1=hafif, 2=orta, 3=yoğun
var _target_rain_stage: int = 0  # Hedef seviye
var _rain_stage_progress: float = 0.0  # Mevcut seviye içindeki ilerleme (0-1)

# --- Storm ramp-up (kademeli artış) ---
var _storm_ramp_minutes_remaining: int = 0
var _storm_start_intensity: float = 0.25  # Storm hafif başlar
var _storm_start_wind_strength: float = 0.12  # Rüzgar da yağmurla paralel başlar (düşük)
var _storm_ramp_pattern: float = 0.0  # 0-1: 0 = aniden bastırır, 1 = yavaş artar
var _storm_ramp_total_duration: int = 0  # Başlangıçta belirlenen toplam ramp süresi
var _storm_stage_intensities: Array[float] = []  # Storm seviye intensity'leri (başlangıçta belirlenir, sabit kalır)
var _storm_ending_wind_peak: float = 0.9  # Storm biterken rüzgarı yağmurla paralel azaltmak için son tepe değer

# --- Sinyaller ---
signal weather_changed()
signal rain_intensity_changed(value: float)
signal wind_changed(strength: float, angle_deg: float)
signal storm_changed(active: bool)

## Yağmur bir yağıp bir duruyorsa true yap: intensity/target değişimlerini konsola yazar (RainController debug_rain_verbose ile birlikte kullan).
const DEBUG_RAIN_VERBOSE: bool = false
var _debug_last_intensity_above: bool = false
var _debug_weather_log_timer: float = 0.0
var _debug_last_threshold_log: float = -10.0


func _ready() -> void:
	if TimeManager:
		_last_total_game_minutes = TimeManager.get_total_game_minutes()
		# İlk açılışta kısa süre sonra ilk kontrol için clear remaining başlat
		_clear_minutes_remaining = randi_range(CLEAR_DURATION_MIN_MINUTES / 2, CLEAR_DURATION_MAX_MINUTES / 2)
	
	# Scene reload sonrası kontrol için SceneManager sinyalini dinle
	if SceneManager:
		if not SceneManager.scene_change_completed.is_connected(_on_scene_change_completed):
			SceneManager.scene_change_completed.connect(_on_scene_change_completed)

func _on_scene_change_completed(new_path: String) -> void:
	# Scene reload sonrası kontrol flag'ini resetle (bir sonraki _process'te kontrol yapılsın)
	_load_check_done = false
	print("[WeatherManager] Scene change completed, resetting load check flag")
	
	# ÖNEMLİ: Sahne değişikliği sırasında zaman ilerlemiş olabilir (örneğin yolculuk süresi)
	# Storm aktifse, bu zaman ilerlemesini hemen storm progression'a yansıtmalıyız
	if storm_active and TimeManager:
		var current_minutes: int = TimeManager.get_total_game_minutes()
		var old_minutes: int = _last_total_game_minutes
		
		if current_minutes != old_minutes:
			var minutes_advanced: int = current_minutes - old_minutes
			print("[WeatherManager] ⚡ Scene change detected time advance: %d minutes (storm active, updating progression)" % minutes_advanced)
			
			# Zamanı güncelle ve storm progression'ı hemen hesapla
			_last_total_game_minutes = current_minutes
			
			# Storm ramp-up süresini güncelle
			if _storm_ramp_minutes_remaining > 0:
				_storm_ramp_minutes_remaining -= minutes_advanced
				if _storm_ramp_minutes_remaining < 0:
					_storm_ramp_minutes_remaining = 0
				
				# Storm progression'ı hemen güncelle (zaman ilerlemesini yansıt)
				var total_ramp_duration: float = float(_storm_ramp_total_duration)
				var remaining: float = float(_storm_ramp_minutes_remaining)
				var progress: float = 1.0 - (remaining / total_ramp_duration)
				progress = clamp(progress, 0.0, 1.0)
				
				# Kademeli seviyeler arasında lerp yap
				var stage_progress: float
				var stage_intensity: float
				
				if _storm_stage_intensities.size() >= 5:
					if progress < 0.25:
						stage_progress = progress / 0.25
						stage_intensity = lerp(_storm_stage_intensities[0], _storm_stage_intensities[1], stage_progress)
					elif progress < 0.5:
						stage_progress = (progress - 0.25) / 0.25
						stage_intensity = lerp(_storm_stage_intensities[1], _storm_stage_intensities[2], stage_progress)
					elif progress < 0.75:
						stage_progress = (progress - 0.5) / 0.25
						stage_intensity = lerp(_storm_stage_intensities[2], _storm_stage_intensities[3], stage_progress)
					else:
						stage_progress = (progress - 0.75) / 0.25
						stage_intensity = lerp(_storm_stage_intensities[3], _storm_stage_intensities[4], stage_progress)
					
					_target_rain_intensity = stage_intensity
					
					# Rüzgar yağmurla paralel seviyeli artar
					var final_wind: float = _storm_wind_strength()
					_target_wind_strength = lerp(_storm_start_wind_strength, final_wind, progress)
					
					print("[WeatherManager] ✅ Storm progression updated: progress=%.2f%%, intensity=%.3f, wind=%.3f" % [progress * 100.0, _target_rain_intensity, _target_wind_strength])
				else:
					# Fallback: eğer stage intensities belirlenmemişse
					_target_rain_intensity = _storm_rain_intensity()
					_target_wind_strength = _storm_wind_strength()
			else:
				# Ramp tamamlandı, final intensity'e ulaş
				_target_rain_intensity = _storm_rain_intensity()
				_target_wind_strength = _storm_wind_strength()
	


var _load_check_done: bool = false  # Load sonrası kontrol yapıldı mı?

func _process(delta: float) -> void:
	# Load sonrası ilk frame'de kontrol: eğer yağmur bitiyorsa veya hedef 0 ama intensity > 0 ise hemen bitir
	if not _load_check_done:
		_load_check_done = true
		var old_intensity = rain_intensity
		# Load sonrası takılı kalmış yağmur durumunu kontrol et:
		# 1. Yağmur bitiyorsa (_rain_ending) ve hedef 0 ise
		# 2. VEYA intensity > 0 ama hedef 0 ise (load sonrası takılı kalmış durum)
		if (_rain_ending and _target_rain_intensity <= 0.0) or (rain_intensity > 0.01 and _target_rain_intensity <= 0.0 and not storm_active):
			# Load sonrası takılı kalmış yağmur durumu - hemen bitir
			_rain_ending = false
			_is_raining_randomly = false
			rain_intensity = 0.0
			_target_rain_intensity = 0.0
			print("[WeatherManager] Load sonrası takılı kalmış yağmur durumu temizlendi (intensity: %.3f -> 0.0, _rain_ending: %s, _is_raining_randomly: %s)" % [old_intensity, _rain_ending, _is_raining_randomly])
			if DEBUG_RAIN_VERBOSE:
				print("[WeatherDEBUG] LOAD CHECK yağmuru sıfırladı (target=0)")
	
	# Storm varsa kademeli artış; rüzgar hedefi sadece _update_storm_progression içinde yağmurla paralel set edilir
	if storm_active:
		_update_storm_progression()
		_target_wind_direction = _storm_wind_direction()
	else:
		# Oyun içi dakika ilerlemesine göre rastgele yağmur güncelle
		_tick_random_weather()

	# Lerp mevcut değerleri hedefe; storm'da hızlı geçiş (sağanak hemen gelsin)
	var rain_lerp: float = STORM_LERP_SPEED if storm_active else RAIN_LERP_SPEED
	var wind_lerp: float = STORM_LERP_SPEED if storm_active else WIND_LERP_SPEED
	rain_intensity = move_toward(rain_intensity, _target_rain_intensity, rain_lerp)
	wind_strength = move_toward(wind_strength, _target_wind_strength, wind_lerp)
	var angle_lerp: float = wind_lerp * 0.5 if storm_active else WIND_LERP_SPEED * 0.5
	var angle_rad: float = lerp_angle(deg_to_rad(wind_direction_angle), deg_to_rad(_target_wind_direction), angle_lerp)
	wind_direction_angle = rad_to_deg(angle_rad)
	
	if DEBUG_RAIN_VERBOSE:
		var t: float = Time.get_ticks_msec() / 1000.0
		_debug_weather_log_timer += delta
		var above: bool = rain_intensity > 0.02
		if above != _debug_last_intensity_above:
			_debug_last_intensity_above = above
			if t - _debug_last_threshold_log >= 1.0:
				_debug_last_threshold_log = t
				print("[WeatherDEBUG] rain_intensity 0.02 EŞİĞİ GEÇTİ: %.3f -> should_emit=%s (target=%.3f storm=%s)" % [rain_intensity, above, _target_rain_intensity, storm_active])
		if _debug_weather_log_timer >= 5.0:
			_debug_weather_log_timer = 0.0
			print("[WeatherDEBUG] intensity=%.3f target=%.3f storm=%s _rain_ending=%s _rain_starting=%s" % [rain_intensity, _target_rain_intensity, storm_active, _rain_ending, _rain_starting])

	# Sinyalleri tek seferde yaymak yerine sadece değişimde yayalım (isteğe)
	# Şimdilik her frame emit etmeyelim; sahneler _process'te doğrudan rain_intensity okuyabilir.
	# Gerekirse weather_changed'i periyodik veya büyük değişimde emit edebiliriz.


func _tick_random_weather() -> void:
	if not TimeManager:
		return
	var total: int = TimeManager.get_total_game_minutes()
	if total == _last_total_game_minutes:
		return

	var minutes_advanced: int = total - _last_total_game_minutes
	_last_total_game_minutes = total

	# Yağmur başlangıç aşaması kontrolü (önce kontrol et, tüm dakikalar için)
	if _rain_starting:
		_rain_start_minutes_remaining -= minutes_advanced
		if _rain_start_minutes_remaining <= 0:
			_rain_starting = false
			# Başlangıç aşaması bitti, gerçek hedefe geç
			_target_rain_intensity = _random_rain_target

	for _i in range(minutes_advanced):
		# Storm bitiş kademeli azalış kontrolü (storm bitti ama _rain_ending aktifse)
		if _rain_ending and not storm_active:
			_tick_storm_ending()
			continue
		
		if _is_raining_randomly:
			# Yağmur bitiş aşaması kontrolü
			if _rain_ending:
				_rain_transition_minutes_remaining -= 1
				if _rain_transition_minutes_remaining <= 0:
					# Bir sonraki düşük seviyeye geç
					if _current_rain_stage > 0:
						_current_rain_stage -= 1
						_update_target_intensity_for_stage()
						_rain_transition_minutes_remaining = randi_range(3, 8)  # Geçiş süresi
					else:
						# Başlangıç seviyesinden bitiş
						_rain_ending = false
						_is_raining_randomly = false
						_target_rain_intensity = 0.0
						_target_wind_strength = randf_range(0.0, 0.15)
						_target_wind_direction = randf_range(0.0, 360.0)
						_clear_minutes_remaining = randi_range(CLEAR_DURATION_MIN_MINUTES, CLEAR_DURATION_MAX_MINUTES)
				continue
			
			# Yağmur başlangıç aşaması kontrolü
			if _rain_starting:
				_rain_start_minutes_remaining -= 1
				if _rain_start_minutes_remaining <= 0:
					_rain_starting = false
					_current_rain_stage = 1  # Hafif seviyeye geç
					_update_target_intensity_for_stage()
					_rain_transition_minutes_remaining = randi_range(3, 8)  # Geçiş süresi
				continue
			
			# Normal yağmur: kademeli artış
			if _current_rain_stage < _target_rain_stage:
				_rain_transition_minutes_remaining -= 1
				if _rain_transition_minutes_remaining <= 0:
					_current_rain_stage += 1
					_update_target_intensity_for_stage()
					_rain_transition_minutes_remaining = randi_range(3, 8)  # Geçiş süresi
			
			# Yağmur süresi kontrolü
			_rain_minutes_remaining -= 1
			if _rain_minutes_remaining <= 0:
				# Yağmur bitiş: kademeli azalış başlat
				_rain_ending = true
				_rain_transition_minutes_remaining = randi_range(3, 8)
		else:
			_clear_minutes_remaining -= 1
			if _clear_minutes_remaining <= 0:
				if randf() < CHANCE_RAIN_STARTS_PER_CHECK:
					# Yağmur başlangıç: önce bulutlar spawn olsun, sonra kesintisiz seyrek yağmur başlasın
					_start_rain_with_clouds()
				else:
					_clear_minutes_remaining = randi_range(15, 45)


func _storm_rain_intensity() -> float:
	# Storm = sağanak; "atıştırır" hissi yok, hep net yoğun yağış.
	match storm_level:
		0: return 0.98   # LOW storm bile belirgin sağanak
		1: return 0.99   # MEDIUM storm
		2: return 1.0    # HIGH storm (tam sağanak)
		_: return 0.99


func _storm_wind_strength() -> float:
	# Storm'da rüzgar hep güçlü (sağanak + rüzgar hissi).
	match storm_level:
		0: return 0.75
		1: return 0.9
		2: return 1.0
		_: return 0.9


func _storm_wind_direction() -> float:
	# Storm sırasında rüzgar yönü (genelde soldan sağa veya sağdan sola).
	return _target_wind_direction


## VillageManager severe_storm event başladığında çağrılır.
func set_storm_active(active: bool, event_level: int = 1) -> void:
	storm_active = active
	storm_level = clampi(event_level, 0, 2)
	if active:
		# Storm başladığında rastgele yağmur sistemini devre dışı bırak
		_is_raining_randomly = false
		_rain_starting = false
		_rain_ending = false
		
		# Storm: önce bulutlar spawn olsun, sonra yağmur başlangıç seviyesiyle başlasın
		# Bulutların gökyüzünü kaplaması için sinyal gönder (CloudManager dinliyor)
		weather_changed.emit()
		
		# Storm başlangıç seviyesi: kesintisiz seyrek yağmur (0.1-0.15)
		var final_intensity = _storm_rain_intensity()
		_storm_start_intensity = randf_range(0.1, 0.15)  # Başlangıç seviyesi (kesintisiz seyrek)
		rain_intensity = _storm_start_intensity
		_target_rain_intensity = _storm_start_intensity
		
		# Storm kademeli artış seviyelerini bir kez belirle (sabit kalacak)
		_storm_stage_intensities.clear()
		_storm_stage_intensities.append(_storm_start_intensity)  # Başlangıç
		_storm_stage_intensities.append(randf_range(0.18, 0.32))  # Hafif
		_storm_stage_intensities.append(randf_range(0.38, 0.55))  # Orta
		_storm_stage_intensities.append(randf_range(0.58, 0.75))  # Yoğun (sağanak öncesi)
		_storm_stage_intensities.append(final_intensity)  # Final sağanak
		
		# Storm kademeli artış: Başlangıç → Hafif → Orta → Sağanak
		# Ramp-up süresi: rastgele 30-120 oyun dakikası (1-2 saatlik süreç, ama değişken)
		_storm_ramp_total_duration = randi_range(30, 120)
		_storm_ramp_minutes_remaining = _storm_ramp_total_duration
		
		# Ramp pattern: 0 = aniden bastırır (hızlı), 1 = yavaş artar
		_storm_ramp_pattern = randf()
		
		_storm_start_wind_strength = randf_range(0.08, 0.18)  # Yağmurla paralel: rüzgar da düşük başlar
		_target_wind_strength = _storm_start_wind_strength
		wind_strength = _storm_start_wind_strength
		_target_wind_direction = randf_range(200.0, 340.0)
		wind_direction_angle = _target_wind_direction
		if DEBUG_RAIN_VERBOSE:
			print("[WeatherDEBUG] set_storm_active(TRUE) intensity=%.3f target=%.3f" % [rain_intensity, _target_rain_intensity])
	else:
		# Storm bitti; kademeli azalış başlat (Sağanak → Orta → Hafif → Başlangıç → 0)
		_is_raining_randomly = false
		_storm_ramp_minutes_remaining = 0
		_rain_ending = true
		_storm_ending_wind_peak = _storm_wind_strength()  # Rüzgarı yağmurla paralel azaltmak için tepe değeri sakla
		# Mevcut storm seviyesinden başla (yoğun seviye = 3)
		_current_rain_stage = 3
		_target_rain_stage = 0  # Hedef: başlangıç seviyesine kadar azal
		_rain_transition_minutes_remaining = randi_range(3, 8)
	storm_changed.emit(storm_active)
	weather_changed.emit()

## Storm'u tamamen sıfırla (load işlemi için - bitiş sürecini başlatmadan)
func reset_storm_completely() -> void:
	storm_active = false
	storm_level = 1
	rain_intensity = 0.0
	_target_rain_intensity = 0.0
	wind_strength = 0.0
	_target_wind_strength = 0.0
	wind_direction_angle = 0.0
	_target_wind_direction = randf_range(0.0, 360.0)  # Rastgele başlangıç yönü
	
	# Tüm storm-related internal state'i sıfırla
	_is_raining_randomly = false
	_rain_starting = false
	_rain_ending = false
	_rain_minutes_remaining = 0
	_clear_minutes_remaining = randi_range(CLEAR_DURATION_MIN_MINUTES / 2, CLEAR_DURATION_MAX_MINUTES / 2)
	_rain_start_minutes_remaining = 0
	_rain_transition_minutes_remaining = 0
	_current_rain_stage = 0
	_target_rain_stage = 0
	_rain_stage_progress = 0.0
	_random_rain_target = 0.0
	
	# Storm ramp-up state'i sıfırla
	_storm_ramp_minutes_remaining = 0
	_storm_start_intensity = 0.25
	_storm_start_wind_strength = 0.12
	_storm_ramp_pattern = 0.0
	_storm_ramp_total_duration = 0
	_storm_stage_intensities.clear()
	_storm_ending_wind_peak = 0.9
	
	print("[WeatherManager] 🌤️ Storm completely reset - all storm state cleared")
	storm_changed.emit(false)
	weather_changed.emit()


## Storm sırasında yağmurun kademeli artışını güncelle (oyun içi dakika bazlı).
## Storm: Başlangıç → Hafif → Orta → Sağanak (kademeli artış).
func _update_storm_progression() -> void:
	if not TimeManager:
		return
	
	var total: int = TimeManager.get_total_game_minutes()
	if total == _last_total_game_minutes:
		return
	
	var minutes_advanced: int = total - _last_total_game_minutes
	_last_total_game_minutes = total
	
	if _storm_ramp_minutes_remaining > 0:
		_storm_ramp_minutes_remaining -= minutes_advanced
		if _storm_ramp_minutes_remaining < 0:
			_storm_ramp_minutes_remaining = 0
		
		# Storm kademeli artış: Başlangıç → Hafif → Orta → Sağanak
		var total_ramp_duration: float = float(_storm_ramp_total_duration)
		var remaining: float = float(_storm_ramp_minutes_remaining)
		var progress: float = 1.0 - (remaining / total_ramp_duration)
		progress = clamp(progress, 0.0, 1.0)
		
		# Kademeli seviyeler: 0.0-0.25 = Başlangıç→Hafif, 0.25-0.5 = Hafif→Orta, 0.5-0.75 = Orta→Yoğun, 0.75-1.0 = Yoğun→Sağanak
		# Sabit belirlenmiş intensity'ler arasında lerp yap
		var stage_progress: float
		var stage_intensity: float
		
		if _storm_stage_intensities.size() < 5:
			# Fallback: eğer stage intensities belirlenmemişse (eski kayıtlar için)
			_target_rain_intensity = _storm_rain_intensity()
		elif progress < 0.25:
			# Başlangıç → Hafif
			stage_progress = progress / 0.25
			stage_intensity = lerp(_storm_stage_intensities[0], _storm_stage_intensities[1], stage_progress)
		elif progress < 0.5:
			# Hafif → Orta
			stage_progress = (progress - 0.25) / 0.25
			stage_intensity = lerp(_storm_stage_intensities[1], _storm_stage_intensities[2], stage_progress)
		elif progress < 0.75:
			# Orta → Yoğun
			stage_progress = (progress - 0.5) / 0.25
			stage_intensity = lerp(_storm_stage_intensities[2], _storm_stage_intensities[3], stage_progress)
		else:
			# Yoğun → Sağanak
			stage_progress = (progress - 0.75) / 0.25
			stage_intensity = lerp(_storm_stage_intensities[3], _storm_stage_intensities[4], stage_progress)
		
		# Hedef intensity'i güncelle (sadece önemli değişikliklerde)
		# Eğer mevcut hedef ile yeni hedef arasındaki fark çok küçükse, hedefi değiştirme
		# Bu sayede lerp daha stabil çalışır
		# Storm sırasında: Daha düşük threshold kullan (0.0001) - storm geçişlerinde kesilme olmasın
		var threshold: float = 0.0001 if storm_active else 0.001
		if abs(_target_rain_intensity - stage_intensity) > threshold:
			_target_rain_intensity = stage_intensity
		
		# Rüzgar yağmurla paralel seviyeli artar (aynı progress)
		var final_wind: float = _storm_wind_strength()
		_target_wind_strength = lerp(_storm_start_wind_strength, final_wind, progress)
	else:
		# Ramp tamamlandı, final intensity'e ulaş
		_target_rain_intensity = _storm_rain_intensity()
		_target_wind_strength = _storm_wind_strength()


## Okuma: şu an yağmur var mı (görsel kullanımı için).
func is_raining() -> bool:
	return rain_intensity > 0.02


## Rüzgar yönü vektörü (normalize, sağ = 1,0). Yağmur partikül yönü için.
func get_wind_direction_vector() -> Vector2:
	var rad: float = deg_to_rad(wind_direction_angle)
	return Vector2(cos(rad), sin(rad))


## Yağmur başlangıç: önce bulutları spawn et, sonra kesintisiz seyrek yağmur başlat.
func _start_rain_with_clouds() -> void:
	_is_raining_randomly = true
	_rain_starting = true
	_rain_ending = false
	
	# Başlangıç seviyesi: kesintisiz seyrek yağmur (0.1-0.15)
	var start_intensity = randf_range(0.1, 0.15)
	_target_rain_intensity = start_intensity
	rain_intensity = start_intensity  # Hemen set et ki CloudManager tespit edebilsin
	_current_rain_stage = 0  # Başlangıç seviyesi
	
	_target_wind_strength = randf_range(0.05, 0.15)
	_target_wind_direction = randf_range(0.0, 360.0)
	
	# Başlangıç aşaması: 5-10 oyun dakikası (bulutların toplanması için)
	_rain_start_minutes_remaining = randi_range(5, 10)
	
	# Hedef seviyeyi belirle (kademeli artış için)
	var r := randf()
	if r < 0.4:
		_target_rain_stage = 1  # Hafif (0.18-0.32)
		_random_rain_target = randf_range(0.18, 0.32)
	elif r < 0.8:
		_target_rain_stage = 2  # Orta (0.38-0.55)
		_random_rain_target = randf_range(0.38, 0.55)
	else:
		_target_rain_stage = 3  # Yoğun (0.58-0.75)
		_random_rain_target = randf_range(0.58, 0.75)
	
	_rain_minutes_remaining = randi_range(RAIN_DURATION_MIN_MINUTES, RAIN_DURATION_MAX_MINUTES)
	
	# Bulutların spawn olması için sinyal gönder (rain_intensity zaten >0.02)
	weather_changed.emit()


## Mevcut yağmur seviyesine göre hedef intensity'i güncelle.
func _update_target_intensity_for_stage() -> void:
	match _current_rain_stage:
		0:  # Başlangıç
			_target_rain_intensity = randf_range(0.1, 0.15)
		1:  # Hafif
			_target_rain_intensity = randf_range(0.18, 0.32)
		2:  # Orta
			_target_rain_intensity = randf_range(0.38, 0.55)
		3:  # Yoğun
			_target_rain_intensity = randf_range(0.58, 0.75)
		_:  # Fallback
			_target_rain_intensity = _random_rain_target


## Storm bitiş kademeli azalış (oyun içi dakika bazlı).
## Not: Bu fonksiyon _tick_random_weather() içinde çağrılır, dakika güncellemesi orada yapılır.
func _tick_storm_ending() -> void:
	if not _rain_ending:
		return
	
	if _current_rain_stage > 0:
		_rain_transition_minutes_remaining -= 1
		if _rain_transition_minutes_remaining <= 0:
			_current_rain_stage -= 1
			_update_target_intensity_for_stage()
			# Rüzgar yağmurla paralel azalsın (seviyeye göre)
			_target_wind_strength = (_current_rain_stage / 3.0) * _storm_ending_wind_peak
			_rain_transition_minutes_remaining = randi_range(3, 8)
	elif _current_rain_stage == 0:
		# Başlangıç seviyesinden bitiş
		_rain_ending = false
		_target_rain_intensity = 0.0
		_target_wind_strength = randf_range(0.0, 0.2)
		_clear_minutes_remaining = randi_range(CLEAR_DURATION_MIN_MINUTES / 2, CLEAR_DURATION_MAX_MINUTES / 2)
