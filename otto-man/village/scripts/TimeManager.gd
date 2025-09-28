extends Node

# Zaman Ölçeği: 1 Oyun Günü = 1 Gerçek Saat (3600 saniye)
# 1 Oyun Günü = 24 * 60 = 1440 Oyun Dakikası
# 1 Oyun Dakikası = 3600 / 1440 = 2.5 Gerçek Saniye
const SECONDS_PER_GAME_MINUTE: float = 2.5

# Mevcut Zaman
var days: int = 1
var hours: int = 6 # Başlangıç saati
var minutes: int = 0

# Zamanı takip eden sayaç
var _time_accumulator: float = 0.0

# Temel Rutin Saatleri (Sabit)
const WAKE_UP_HOUR: int = 6
const WORK_START_HOUR: int = 7
const WORK_END_HOUR: int = 18
const SLEEP_HOUR: int = 22

# --- Zaman Hızlandırma --- #
var current_time_scale_index: int = 0 # 0: Normal, 1: x4, 2: x16
var time_scales: Array[float] = [1.0, 4.0, 16.0]

# Zaman ilerlemesini sağlayan sinyal (opsiyonel, gerekirse diğer scriptler bağlanabilir)
# signal hour_changed(new_hour)
# signal day_changed(new_day)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("--- TimeManager.gd: _ready() ÇAĞRILDI! TimeManager YÜKLENDİ! ---")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Zaman ölçeğini uygula (Engine.time_scale'i kullanmak yerine delta'yı çarpmak daha esnek olabilir)
	var scaled_delta = delta * Engine.time_scale #<<< YENİ
	_time_accumulator += scaled_delta # delta yerine scaled_delta kullanıldı
	
	# Kaç oyun dakikası geçtiğini hesapla
	var minutes_passed = floori(_time_accumulator / SECONDS_PER_GAME_MINUTE)
	
	if minutes_passed > 0:
		# Zamanı ilerlet
		_advance_time(minutes_passed)
		# Akümülatörü güncelle (artık kısmı koru)
		_time_accumulator = fmod(_time_accumulator, SECONDS_PER_GAME_MINUTE)

func _advance_time(minutes_to_advance: int) -> void:
	minutes += minutes_to_advance
	var extra_hours = floori(minutes / 60.0)
	minutes = minutes % 60
	emit_signal("minute_changed", minutes) # YENİ: Dakika değiştiğinde sinyal gönder
	
	if extra_hours > 0:
		hours += extra_hours
		var extra_days = floori(hours / 24.0)
		hours = hours % 24
		# emit_signal("hour_changed", hours) # Sinyal opsiyonel
		
		if extra_days > 0:
			days += extra_days
			# emit_signal("day_changed", days) # Sinyal opsiyonel
			# print("Yeni gün başladı: Gün ", days) # Debug

# --- Public Getters ---
func get_hour() -> int:
	return hours

func get_minute() -> int:
	return minutes
	
func get_day() -> int:
	return days

func get_time_string() -> String:
	return "Gün %d, %02d:%02d" % [days, hours, minutes]

# --- Zaman Hızı Kontrol Fonksiyonları --- #
func set_time_scale_index(index: int) -> void:
	if index >= 0 and index < time_scales.size():
		current_time_scale_index = index
		Engine.time_scale = time_scales[current_time_scale_index]
		print("Time scale set to: x", Engine.time_scale) # Debug
	else:
		printerr("Invalid time scale index: ", index)

func cycle_time_scale() -> void:
	var next_index = (current_time_scale_index + 1) % time_scales.size()
	set_time_scale_index(next_index)

func get_current_time_scale() -> float:
	return Engine.time_scale

func get_current_hour_float() -> float:
	# Mevcut saat ve dakikayı ondalık bir değere çevirir (örn: 6:30 -> 6.5)
	return float(hours) + (float(minutes) / 60.0)

func get_continuous_hour_float() -> float:
	# Oyun dakikasının içindeki ilerlemeyi de hesaba katarak daha akıcı bir saat değeri döndürür.
	# Bu, animasyonların ve pozisyon güncellemelerinin saniye bazında daha yumuşak olmasını sağlar.
	var minute_progress = _time_accumulator / SECONDS_PER_GAME_MINUTE
	return float(hours) + (float(minutes) / 60.0) + (minute_progress / 60.0)

func get_current_day_count() -> int:
	return days

# Çalışma saatlerinde mi kontrol eder
func is_work_time() -> bool:
	return hours >= WORK_START_HOUR and hours < WORK_END_HOUR

# сигналы
signal hour_changed(new_hour: int)
signal minute_changed(new_minute: int) # YENİ SİNYAL (Opsiyonel, gerekirse diye)
