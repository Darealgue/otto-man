extends Sprite2D
## Rüzgar etkisiyle sallanan sprite'lar için script.
## Alt kenar sabit kalırken üst kenar sağa sola oynar (skew efekti).

@export var base_amplitude: float = 0.5  # Temel sallanma genliği (derece) - çok hafif, zor belli olacak
@export var frequency: float = 1.0  # Sallanma frekansı (saniyede kaç kez) - biraz yavaşlatıldı
@export var wind_multiplier: float = 8.0  # Rüzgar güçlendirme çarpanı (wind_strength ile çarpılır) - rüzgar varken belirgin olsun
@export var random_offset: float = 0.0  # Her sprite için farklı başlangıç fazı (rastgele)

var _base_rotation: float = 0.0  # Orijinal rotation değeri
var _base_skew: float = 0.0  # Orijinal skew değeri
var _base_offset: Vector2 = Vector2.ZERO  # Orijinal offset değeri
var _base_position: Vector2 = Vector2.ZERO  # Orijinal position değeri
var _base_z_index: int = 0  # Orijinal z_index değeri
var _pivot_offset_y: float = 0.0  # Pivot offset'i
var _time: float = 0.0  # Zaman sayacı

func _ready() -> void:
	# Orijinal değerleri kaydet (position/index'leri değiştirmeyeceğiz)
	_base_rotation = rotation
	_base_skew = skew
	_base_offset = offset
	_base_position = position
	_base_z_index = z_index
	
	# Her sprite için pivot'u altına taşı (her sprite'ın yüksekliği farklı)
	# offset.y NEGATİF değer sprite'ı yukarı kaydırır, bu da pivot'u altına taşır
	if texture:
		var sprite_height: float = texture.get_height() if texture else 0.0
		if sprite_height > 0.0:
			# Pivot'u altına taşı: sprite'ı yukarı kaydır (negatif offset)
			_pivot_offset_y = sprite_height / 2.0
			offset.y = _base_offset.y - _pivot_offset_y
			# Görsel konumu korumak için position'ı aşağı kaydır
			position.y = _base_position.y + _pivot_offset_y
			# Render sırasını korumak için z_index'i de ayarla
			# y_sort_enabled varsa render sırası position.y'ye göre belirlenir
			# Orijinal render sırasını korumak için z_index'i position.y değişikliğine göre ayarla
			# Ama daha basit: z_index'i position.y'ye göre ayarla (y_sort_enabled için)
			# Ancak bu her sprite için farklı olabilir, bu yüzden orijinal z_index'i koruyoruz
			z_index = _base_z_index
	
	# Her sprite için farklı başlangıç fazı (rastgele, doğal görünüm için)
	if random_offset == 0.0:
		random_offset = randf() * TAU  # 0-2π arası rastgele
	
	# Process mode'u kontrol et (Sprite2D default olarak PROCESS_MODE_INHERIT kullanır)
	# Eğer parent paused ise bu da paused olur, bu yüzden PROCESS_MODE_ALWAYS yapalım
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)  # Açıkça process'i aktif et

func _process(delta: float) -> void:
	# Pause'da durdur
	if is_instance_valid(GameState) and GameState.is_paused:
		return
	
	# WeatherManager kontrolü
	if not WeatherManager:
		return
	
	_time += delta
	
	# Rüzgar gücünü al
	var wind_strength: float = WeatherManager.wind_strength if WeatherManager else 0.0
	
	# Temel rastgele sallanma (her zaman aktif ama çok hafif)
	var base_sway: float = sin(_time * frequency + random_offset) * base_amplitude
	
	# Rüzgar güçlendirmesi: rüzgar yokken çok az, rüzgar varken belirgin
	# wind_strength 0 ise sadece base_sway, wind_strength artarsa wind_multiplier ile çarpılır
	var wind_boost: float = base_sway * wind_strength * wind_multiplier
	
	# Final sallanma: temel sallanma + rüzgar güçlendirmesi
	# Rüzgar yokken sadece base_sway (çok hafif), rüzgar varken wind_boost eklenir
	var final_sway: float = base_sway + wind_boost
	
	# Skew kullanarak sallanma efekti
	# NOT: Pivot merkezde kalacak (offset kullanmıyoruz), bu yüzden alt kenar tam sabit kalmaz
	# ama görsel olarak yeterince iyi görünecek ve position/index'ler korunacak
	var skew_rad: float = deg_to_rad(final_sway)
	skew = _base_skew + skew_rad
	
	# Rotation'ı orijinal değerde tut (sadece skew değişsin)
	rotation = _base_rotation
