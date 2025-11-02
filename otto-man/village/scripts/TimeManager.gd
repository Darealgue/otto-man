extends Node

# Zaman Ölçeği: 1 Oyun Günü = 1 Gerçek Saat (3600 saniye)
# 1 Oyun Günü = 24 * 60 = 1440 Oyun Dakikası
# 1 Oyun Dakikası = 3600 / 1440 = 2.5 Gerçek Saniye
const SECONDS_PER_GAME_MINUTE: float = 2.5
const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24

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
signal hour_changed(new_hour: int)
signal minute_changed(new_minute: int)
signal day_changed(new_day: int)
signal time_advanced(total_minutes: int, start_day: int, start_hour: int, start_minute: int)

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
	if minutes_to_advance <= 0:
		return
	var remaining := minutes_to_advance
	while remaining > 0:
		var step: int = min(remaining, MINUTES_PER_HOUR - minutes)
		if step <= 0:
			step = remaining
		minutes += step
		remaining -= step
		if minutes >= MINUTES_PER_HOUR:
			minutes -= MINUTES_PER_HOUR
			emit_signal("minute_changed", minutes)
			_increment_hour(1)
		else:
			emit_signal("minute_changed", minutes)

func _increment_hour(count: int) -> void:
	var new_hour := hours + count
	var extra_days := new_hour / HOURS_PER_DAY
	hours = new_hour % HOURS_PER_DAY
	emit_signal("hour_changed", hours)
	if extra_days > 0:
		days += extra_days
		emit_signal("day_changed", days)

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

func advance_minutes(total_minutes: int) -> void:
	# Validation: Check for invalid values
	if total_minutes <= 0:
		return
	# Check for extremely large values (prevent performance issues)
	# Max: 1000 days = 1000 * 24 * 60 = 1,440,000 minutes
	var max_minutes: int = 1000 * HOURS_PER_DAY * MINUTES_PER_HOUR
	if total_minutes > max_minutes:
		push_warning("[TimeManager] ⚠️ Very large time skip detected: %d minutes (%.1f days). Capping to %d minutes." % [total_minutes, float(total_minutes) / float(MINUTES_PER_HOUR * HOURS_PER_DAY), max_minutes])
		total_minutes = max_minutes
	
	var start_day := days
	var start_hour := hours
	var start_minute := minutes
	_advance_time(total_minutes)
	time_advanced.emit(total_minutes, start_day, start_hour, start_minute)

func advance_hours(total_hours: float) -> void:
	# Validation: Check for invalid values
	if total_hours <= 0.0:
		return
	# Check for NaN or Infinity
	if is_nan(total_hours) or is_inf(total_hours):
		push_error("[TimeManager] ❌ Invalid time value: %f (NaN or Infinity). Skipping time advance." % total_hours)
		return
	# Check for extremely large values
	var max_hours: float = 1000.0 * float(HOURS_PER_DAY)
	if total_hours > max_hours:
		push_warning("[TimeManager] ⚠️ Very large time skip detected: %.1f hours (%.1f days). Capping to %.1f hours." % [total_hours, total_hours / float(HOURS_PER_DAY), max_hours])
		total_hours = max_hours
	
	var minutes_to_advance := int(round(total_hours * float(MINUTES_PER_HOUR)))
	advance_minutes(minutes_to_advance)

func advance_days(total_days: float) -> void:
	# Validation: Check for invalid values
	if total_days <= 0.0:
		return
	# Check for NaN or Infinity
	if is_nan(total_days) or is_inf(total_days):
		push_error("[TimeManager] ❌ Invalid time value: %f (NaN or Infinity). Skipping time advance." % total_days)
		return
	# Check for extremely large values (max 1000 days)
	var max_days: float = 1000.0
	if total_days > max_days:
		push_warning("[TimeManager] ⚠️ Very large time skip detected: %.1f days. Capping to %.1f days." % [total_days, max_days])
		total_days = max_days
	
	advance_hours(total_days * float(HOURS_PER_DAY))
