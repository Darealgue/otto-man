extends Node

# Signal tanımlamaları
signal schedule_changed(activity)
signal period_started(period, time)

# Aktivite türleri
enum ActivityType {
	SLEEPING,     # Uyuma
	WAKING_UP,    # Uyanma
	GETTING_TOOLS, # İş aletlerini alma
	WORKING,      # Çalışma
	RESTING,      # Dinlenme/yemek yeme
	SOCIALIZING,  # Sosyalleşme
	WANDERING     # Gezinme
}

# Activite isimleri (debug için)
var activity_names = {
	ActivityType.SLEEPING: "Uyku",
	ActivityType.WAKING_UP: "Uyanma",
	ActivityType.GETTING_TOOLS: "Hazırlık",
	ActivityType.WORKING: "Çalışma",
	ActivityType.RESTING: "Dinlenme",
	ActivityType.SOCIALIZING: "Sosyalleşme", 
	ActivityType.WANDERING: "Gezinme"
}

# Günlük zaman çizelgesi: saat:dakika -> aktivite
var daily_schedule = {
	"06:00": ActivityType.WAKING_UP,    # Uyanma saati
	"06:30": ActivityType.GETTING_TOOLS, # İş aletlerini alma
	"07:00": ActivityType.WORKING,      # Sabah çalışma başlangıcı
	"11:30": ActivityType.RESTING,      # Öğle yemeği molası
	"12:30": ActivityType.GETTING_TOOLS, # İş aletlerini alma
	"13:00": ActivityType.WORKING,      # Öğleden sonra çalışma başlangıcı
	"16:30": ActivityType.SOCIALIZING,  # Sosyalleşme/serbest zaman başlangıcı
	"20:00": ActivityType.SLEEPING      # Uyku saati
}

# Kişiselleştirilmiş programlar
var personalized_schedules = {}

# Mevcut aktivite
var current_activity: ActivityType = ActivityType.SLEEPING
var last_hour: int = 0
var last_minute: int = 0

func _ready() -> void:
	# TimeManager'a bağlan
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.time_changed.connect(_on_time_changed)
		time_manager.period_changed.connect(_on_period_changed)
		print("ScheduleManager TimeManager'a bağlandı")
		
		# Başlangıç aktivitesini mevcut saate göre ayarla
		var current_time = time_manager.get_time_text()
		_update_activity_for_time(current_time)
	else:
		print("UYARI: TimeManager bulunamadı! ScheduleManager düzgün çalışmayacak.")

func _on_time_changed(hour: int, minute: int, _second: int, time_text: String) -> void:
	# Sadece saat veya dakika değiştiğinde kontrol et
	if hour != last_hour or minute != last_minute:
		last_hour = hour
		last_minute = minute
		
		# Zaman değişti, günlük programı kontrol et
		_update_activity_for_time(time_text)

func _on_period_changed(period: String, time_text: String) -> void:
	# Gündüz/Gece durumu değişti, gerekirse özel işlemler yap
	period_started.emit(period, time_text)
	
	if period == "Night":
		# Gece olduğunda tüm köylüleri uyutmak için SLEEPING'e geçir
		_set_current_activity(ActivityType.SLEEPING)

func _update_activity_for_time(time_text: String) -> void:
	# İlk 5 karakteri al (saat:dakika)
	var time_key = time_text.substr(0, 5)
	
	# Program içinde bu saat var mı?
	if daily_schedule.has(time_key):
		var new_activity = daily_schedule[time_key]
		_set_current_activity(new_activity)
		print("Zaman değişimi: ", time_text, " -> ", activity_names[new_activity])
	
	# Alternatif olarak, tam saatlerde durum kontrolü yap
	elif time_text.substr(3, 2) == "00":
		# Tam saat, mevcut programa göre aktiviteyi kontrol et
		var closest_activity = _find_closest_activity(time_text)
		if closest_activity != current_activity:
			_set_current_activity(closest_activity)

func _set_current_activity(activity: ActivityType) -> void:
	if current_activity != activity:
		current_activity = activity
		emit_signal("schedule_changed", activity)

func _find_closest_activity(time_text: String) -> ActivityType:
	# İlk 5 karakteri al (saat:dakika)
	var time_key = time_text.substr(0, 5)
	
	# Verilen zamandan önce gelen en son aktiviteyi bul
	var closest_time = "00:00"
	var closest_activity = ActivityType.SLEEPING  # Varsayılan olarak uyku
	
	for schedule_time in daily_schedule.keys():
		if schedule_time <= time_key and schedule_time > closest_time:
			closest_time = schedule_time
			closest_activity = daily_schedule[schedule_time]
	
	return closest_activity

func get_current_activity() -> ActivityType:
	return current_activity

func get_activity_name(activity: ActivityType) -> String:
	return activity_names[activity]

func is_work_time() -> bool:
	return current_activity == ActivityType.WORKING

func is_sleep_time() -> bool:
	return current_activity == ActivityType.SLEEPING

func is_social_time() -> bool:
	return current_activity == ActivityType.SOCIALIZING

func set_custom_schedule(schedule: Dictionary) -> void:
	daily_schedule = schedule
	
	# Mevcut zamanı kontrol et ve aktiviteyi güncelle
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		var current_time = time_manager.get_time_text()
		_update_activity_for_time(current_time)

# Yeni fonksiyonlar: Kişiselleştirilmiş programlar için

func get_personalized_schedule(villager_id: int) -> Dictionary:
	# Köylü için özel program oluştur veya mevcut olanı kullan
	if not personalized_schedules.has(villager_id):
		# Ana programın kopyasını oluştur
		var personal_schedule = daily_schedule.duplicate(true)
		
		# Her köylü için saatleri biraz değiştir
		var variance_minutes = randi_range(-15, 15)
		
		# Saatleri güncelle ve yeni kişisel program oluştur
		var new_schedule = {}
		for time_key in personal_schedule.keys():
			var hour = int(time_key.substr(0, 2))
			var minute = int(time_key.substr(3, 2))
			
			# Dakikaları değiştir (±15 dakika)
			minute += variance_minutes
			
			# Taşmaları düzelt
			if minute >= 60:
				hour += 1
				minute -= 60
			elif minute < 0:
				hour -= 1
				minute += 60
			
			# Saat aralığını kontrol et
			hour = wrapi(hour, 0, 24)
			
			# Saati tekrar formatlı dizeye çevir
			var new_time = "%02d:%02d" % [hour, minute]
			new_schedule[new_time] = personal_schedule[time_key]
		
		# Kişiselleştirilmiş programı kaydet
		personalized_schedules[villager_id] = new_schedule
		print("Köylü ", villager_id, " için kişiselleştirilmiş program oluşturuldu")
	
	return personalized_schedules[villager_id]

func get_activity_for_villager(villager_id: int, time_text: String) -> ActivityType:
	# Köylünün kişiselleştirilmiş programına göre aktivite döndür
	var schedule = get_personalized_schedule(villager_id)
	
	# İlk 5 karakteri al (saat:dakika)
	var time_key = time_text.substr(0, 5)
	
	# Program içinde bu saat var mı?
	if schedule.has(time_key):
		return schedule[time_key]
	
	# Yoksa en yakın aktiviteyi bul
	var closest_time = "00:00"
	var closest_activity = ActivityType.SLEEPING
	
	for schedule_time in schedule.keys():
		if schedule_time <= time_key and schedule_time > closest_time:
			closest_time = schedule_time
			closest_activity = schedule[schedule_time]
	
	return closest_activity

func get_next_activity_time(villager_id: int, current_activity: ActivityType) -> String:
	# Köylünün programında, mevcut aktiviteden sonraki aktivitenin zamanını bul
	var schedule = get_personalized_schedule(villager_id)
	var activity_times = {}
	
	# Aktivitelere göre zamanları grupla
	for time_key in schedule.keys():
		var activity = schedule[time_key]
		if not activity_times.has(activity):
			activity_times[activity] = []
		activity_times[activity].append(time_key)
	
	# Mevcut aktivitenin sonraki aktivitesini bul
	var next_activity = null
	var activities_list = ActivityType.values()
	var current_idx = activities_list.find(current_activity)
	
	if current_idx >= 0 and current_idx < activities_list.size() - 1:
		next_activity = activities_list[current_idx + 1]
	else:
		next_activity = activities_list[0]  # Döngüsel olarak ilk aktiviteye dön
	
	# Bir sonraki aktivitenin zamanını bul
	if activity_times.has(next_activity) and not activity_times[next_activity].is_empty():
		return activity_times[next_activity][0]
	
	return ""  # Bulunamadıysa boş döndür

func get_time_until_next_activity(villager_id: int, current_time: String) -> float:
	# Şu anki zamandan bir sonraki aktiviteye kadar olan süreyi dakika olarak döndür
	var schedule = get_personalized_schedule(villager_id)
	
	# İlk 5 karakteri al (saat:dakika)
	var time_key = current_time.substr(0, 5)
	
	# Mevcut zamanı dakika cinsinden hesapla
	var hour = int(time_key.substr(0, 2))
	var minute = int(time_key.substr(3, 2))
	var current_minutes = hour * 60 + minute
	
	# Bir sonraki aktivite zamanını bul
	var next_time = ""
	var min_diff = 24 * 60  # Maksimum 24 saat (dakika cinsinden)
	
	for schedule_time in schedule.keys():
		var t_hour = int(schedule_time.substr(0, 2))
		var t_minute = int(schedule_time.substr(3, 2))
		var t_minutes = t_hour * 60 + t_minute
		
		var diff = t_minutes - current_minutes
		if diff <= 0:
			diff += 24 * 60  # Ertesi güne taşan süreler için
		
		if diff < min_diff:
			min_diff = diff
			next_time = schedule_time
	
	return min_diff  # Dakika cinsinden bir sonraki aktiviteye kalan süre 
