extends Node

signal time_advanced(hour: int, minute: int, day: int, period: String)
signal day_advanced(day: int)
signal period_changed(period: String)

const MINUTES_PER_HOUR = 60
const HOURS_PER_DAY = 24

# Zaman ölçeklendirme (1 oyun günü = 1 gerçek saat)
# 1 gerçek saat = 60 dakika = 3600 saniye
# 1 oyun günü = 24 saat
# Bu durumda 1 oyun saati = (3600 / 24) = 150 saniye gerçek zaman
# 1 oyun dakikası = (150 / 60) = 2.5 saniye gerçek zaman
const MINUTES_PER_REAL_SECOND_BASE = 1.0 / 2.5  # Her gerçek saniyede 0.4 oyun dakikası geçer (1/2.5)
var time_scale = 1.0  # Zamanı hızlandırmak için çarpan

# Starting values
var hour: int = 6
var minute: int = 0
var day: int = 1
var accumulated_minutes: float = 0.0  # Fractional minute accumulator

# Time periods
enum Period { MORNING, NOON, EVENING, NIGHT }
var current_period: Period = Period.MORNING

# Period definitions (hour ranges)
const period_ranges = {
	Period.MORNING: [6, 11],  # 6:00-11:59
	Period.NOON: [12, 17],    # 12:00-17:59
	Period.EVENING: [18, 21], # 18:00-21:59
	Period.NIGHT: [22, 5]     # 22:00-5:59
}

# Time advancement control
var time_paused: bool = false

# Debug vars
var debug_timer: float = 0.0
var debug_enabled: bool = true
var debug_timing_interval: float = 5.0  # Log timing every 5 seconds

func _ready():
	print("TimeManager initialized")
	print("Starting time: ", get_time_string())
	print("Current period: ", get_period_string())
	
	# Start time advancement
	_update_period()

func _process(delta):
	if time_paused:
		return
	
	# Debug timing
	if debug_enabled:
		debug_timer += delta
		if debug_timer >= debug_timing_interval:
			debug_timer = 0.0
			print("Current time: ", get_time_string(), " (Day ", day, ") - Period: ", get_period_string())
	
	# Advance time
	var start_time = Time.get_ticks_msec()
	_advance_time(delta)
	var end_time = Time.get_ticks_msec()
	
	# Performance check
	var process_time = end_time - start_time
	if process_time > 5:  # If processing takes more than 5ms, log it
		print("WARNING: Time advancement took ", process_time, "ms")

func _advance_time(delta):
	# Her gerçek saniyede geçen oyun dakikası
	# minutes_per_real_second = 1 / 2.5 = 0.4 
	# Yani her gerçek saniyede 0.4 oyun dakikası geçer
	var minutes_to_advance = delta * (MINUTES_PER_REAL_SECOND_BASE * time_scale)
	
	# Add to accumulated minutes
	accumulated_minutes += minutes_to_advance
	
	# If we've accumulated at least one minute, advance the clock
	if accumulated_minutes >= 1.0:
		var full_minutes = floor(accumulated_minutes)
		accumulated_minutes -= full_minutes
		
		# Add minutes
		minute += int(full_minutes)
		
		# Handle minute overflow
		if minute >= MINUTES_PER_HOUR:
			hour += minute / MINUTES_PER_HOUR
			minute = minute % MINUTES_PER_HOUR
			
			# Handle hour overflow
			if hour >= HOURS_PER_DAY:
				hour = hour % HOURS_PER_DAY
				day += 1
				day_advanced.emit(day)
				print("Day advanced to: ", day)
		
		# Check if period changed
		_update_period()
		
		# Emit time advanced signal
		time_advanced.emit(hour, minute, day, get_period_string())

func _update_period():
	var old_period = current_period
	
	# Determine current period based on hour
	if hour >= period_ranges[Period.MORNING][0] && hour <= period_ranges[Period.MORNING][1]:
		current_period = Period.MORNING
	elif hour >= period_ranges[Period.NOON][0] && hour <= period_ranges[Period.NOON][1]:
		current_period = Period.NOON
	elif hour >= period_ranges[Period.EVENING][0] && hour <= period_ranges[Period.EVENING][1]:
		current_period = Period.EVENING
	else:
		current_period = Period.NIGHT
	
	# If period changed, emit signal
	if old_period != current_period:
		period_changed.emit(get_period_string())
		print("Period changed to: ", get_period_string())

func get_time_string() -> String:
	return "%02d:%02d" % [hour, minute]

func get_day_string() -> String:
	return "Day %d" % day

func get_period_string() -> String:
	match current_period:
		Period.MORNING:
			return "Morning"
		Period.NOON:
			return "Noon"
		Period.EVENING:
			return "Evening"
		Period.NIGHT:
			return "Night"
		_:
			return "Unknown"

func get_period_color() -> Color:
	match current_period:
		Period.MORNING:
			return Color(1.0, 0.8, 0.6)  # Orange-yellow
		Period.NOON:
			return Color(1.0, 1.0, 1.0)  # White
		Period.EVENING:
			return Color(1.0, 0.6, 0.4)  # Orange-red
		Period.NIGHT:
			return Color(0.3, 0.3, 0.6)  # Dark blue
		_:
			return Color(1.0, 1.0, 1.0)  # Default white

func set_time(new_hour: int, new_minute: int, new_day: int = -1):
	hour = clampi(new_hour, 0, 23)
	minute = clampi(new_minute, 0, 59)
	
	if new_day > 0:
		day = new_day
	
	_update_period()
	time_advanced.emit(hour, minute, day, get_period_string())
	print("Time manually set to: ", get_time_string(), " (Day ", day, ")")

func pause_time():
	time_paused = true
	print("Time paused at: ", get_time_string())

func resume_time():
	time_paused = false
	print("Time resumed from: ", get_time_string())

func set_time_scale(scale: float):
	time_scale = max(0.1, scale)
	print("Time scale set to: ", time_scale, "x")

func skip_to_next_period():
	match current_period:
		Period.MORNING:
			set_time(12, 0)  # Skip to Noon
		Period.NOON:
			set_time(18, 0)  # Skip to Evening
		Period.EVENING:
			set_time(22, 0)  # Skip to Night
		Period.NIGHT:
			set_time(6, 0, day + 1)  # Skip to Morning of next day
	
	print("Skipped to next period: ", get_period_string()) 
