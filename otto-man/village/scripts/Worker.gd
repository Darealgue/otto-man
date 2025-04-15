extends Node2D

var worker_id: int = -1 # VillageManager tarafından atanacak

# <<< YENİ: Kenardan Başlama Pozisyonu >>>
var start_x_pos: float = 0.0 # VillageManager._assign_housing tarafından ayarlanacak
# <<< YENİ SONU >>>

# İşçinin olası durumları
enum State { 
	SLEEPING,         # Uyuyor (görünmez)
	AWAKE_IDLE,       # Uyanık, işsiz/boşta geziyor
	GOING_TO_BUILDING_FIRST, # İşe gitmek için ÖNCE binaya uğruyor
	WORKING_OFFSCREEN, # Ekran dışında çalışıyor
	WAITING_OFFSCREEN, # Ekran dışında iş bitimini beklerken
	WORKING_INSIDE,   # Binanın içinde çalışıyor (görünmez)
	RETURNING_FROM_WORK, # İşten dönüyor (ekran dışından geliyor)
	GOING_TO_BUILDING_LAST, # İşten dönünce SONRA binaya uğruyor
	SOCIALIZING,      # Köyde sosyalleşiyor/dolaşıyor
	GOING_TO_SLEEP,   # Uyumak için barınağa gidiyor
	FETCHING_RESOURCE, # Kaynak almaya gidiyor (görsel)
	WAITING_AT_SOURCE, # Kaynak binasında bekliyor (görünmez)
	RETURNING_FROM_FETCH # Kaynaktan binaya dönüyor (görsel)
} 
var current_state = State.AWAKE_IDLE # Başlangıç durumu (Tip otomatik çıkarılacak)

# Atama Bilgileri
var assigned_job_type: String = "" # "wood", "stone", etc. or "" for idle
var assigned_building_node: Node2D = null # Atandığı binanın node'u
var housing_node: Node2D = null # Kaldığı yer (CampFire veya House)

# Rutin Zamanlaması için Rastgele Farklar
var wake_up_minute_offset: int = randi_range(0, 15) 
var work_start_minute_offset: int = randi_range(0, 30)
var work_end_minute_offset: int = randi_range(0, 30) # 0-30 dk arası rastgelelik
var sleep_minute_offset: int = randi_range(0, 60) #<<< YENİ IDLE UYKU OFFSETİ
# TODO: Diğer rutinler (iş bitişi, uyku) için de offsetler eklenebilir

# Hareket Değişkenleri
var move_target_x: float = 0.0 # Sadece X ekseninde hareket edilecek hedef
var move_speed: float = randf_range(50.0, 70.0) # Pixel per second (ayarlanabilir)
var _offscreen_exit_x: float = 0.0 #<<< YENİ

# <<< YENİ: Kaynak Taşıma Zamanlayıcıları >>>
var fetching_timer: Timer # Dışarı çıkma aralığı için
var wait_at_source_timer: Timer # Kaynakta bekleme süresi için
var fetch_interval_min: float = 15.0 
var fetch_interval_max: float = 30.0 
var wait_at_source_duration: float = 1.5 # Kaynakta bekleme süresi (saniye)
var fetch_target_x_temp: float = 0.0 # Artık kullanılmıyor olabilir? Gözden geçir.
# <<< YENİ SONU >>>

@onready var sprite: Sprite2D = $Sprite2D # Sprite node'una referans (eğer adı farklıysa değiştir)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# <<< YENİ: Timer Oluşturma >>>
	fetching_timer = Timer.new()
	fetching_timer.one_shot = true
	fetching_timer.timeout.connect(_on_fetching_timer_timeout)
	add_child(fetching_timer)
	
	wait_at_source_timer = Timer.new()
	wait_at_source_timer.one_shot = true
	wait_at_source_timer.wait_time = wait_at_source_duration
	wait_at_source_timer.timeout.connect(_on_wait_at_source_timer_timeout)
	add_child(wait_at_source_timer)
	# <<< YENİ SONU >>>

	# Başlangıçta görünür yapalım
	visible = true
	# <<< YENİ: Başlangıç Hedefini Ayarla >>>
	# Eğer bir barınağımız varsa, başlangıç hedefimizi orası yapalım
	if is_instance_valid(housing_node):
		move_target_x = housing_node.global_position.x
		# print("Worker %d Ready: Initial target set to housing at %s" % [worker_id, move_target_x]) # DEBUG <<< KALDIRILDI
	else:
		# Barınak yoksa (bir hata durumunda), hedefi kendi konumu yap
		move_target_x = global_position.x 
		# printerr("Worker %d Ready: No housing node, initial target set to self at %s" % [worker_id, move_target_x]) # DEBUG <<< KALDIRILDI (printerr kalabilir)
	# <<< ESKİ KOD >>>
	# move_target_x = global_position.x # Başlangıçta hedefi kendi konumu yap
	# <<< ESKİ KOD BİTİŞ >>>

func _physics_process(delta: float) -> void:
	match current_state:
		State.SLEEPING:
			# Uyanma zamanı geldi mi kontrol et
			var current_hour = TimeManager.get_hour()
			var current_minute = TimeManager.get_minute()
			# WAKE_UP_HOUR sabitine ve işçiye özel offset'e göre kontrol
			if current_hour == TimeManager.WAKE_UP_HOUR and current_minute >= wake_up_minute_offset:
				# Uyandır!
				current_state = State.AWAKE_IDLE # Şimdilik direkt idle yapalım
				visible = true #<<< YORUM KALDIRILDI: Uyandığında görünür olmalı
				# Uyandığı noktada belirsin (barınağın konumu)
				if is_instance_valid(housing_node): # Güvenlik kontrolü
					global_position = housing_node.global_position
					# Rastgele ilk hedefi belirle (barınak etrafında?)
					var wander_range = 150.0 # Ne kadar gezinsin?
					move_target_x = global_position.x + randf_range(-wander_range, wander_range)
				else:
					printerr("Worker %d: Housing node geçerli değil, başlangıç konumu ayarlanamadı!" % worker_id)
					move_target_x = global_position.x # Hedefi kendi konumu yap
					
				print("Worker %d uyandı!" % worker_id) # Debug

		State.AWAKE_IDLE:
			var current_hour = TimeManager.get_hour()
			var current_minute = TimeManager.get_minute()
			
			# 1. Uyku Zamanı Kontrolü
			if current_hour >= TimeManager.SLEEP_HOUR and current_minute >= sleep_minute_offset:
				if is_instance_valid(housing_node):
					print("Worker %d (Idle) uyumaya gidiyor." % worker_id) # Debug için Idle eklendi
					current_state = State.GOING_TO_SLEEP
					move_target_x = housing_node.global_position.x
					return # State değişti, bu frame'i bitir
				else:
					# Uyuyacak yeri yoksa veya saat gelmediyse gezinmeye devam
					pass # Şimdilik bir şey yapma, aşağıdaki kod çalışacak
			
			# 2. İşe Gitme Zamanı Kontrolü (eğer atanmışsa ve uyku vakti değilse)
			elif assigned_job_type != "" and is_instance_valid(assigned_building_node):
				# Saat kontrolü zaten yukarıda yapıldı, burada tekrar yapmaya gerek yok
				# Sadece WORK_START_HOUR kontrolü yeterli (ve offset)
				if current_hour == TimeManager.WORK_START_HOUR and current_minute >= work_start_minute_offset:
					print("Worker %d işe gidiyor (%s)!" % [worker_id, assigned_job_type]) # Debug
					current_state = State.GOING_TO_BUILDING_FIRST
					move_target_x = assigned_building_node.global_position.x
					return # State değiştiği için bu frame'i bitir

			# 3. Idle Gezinme Mantığı (ne uyku vakti ne iş vakti ise)
			# --- Idle Gezinme Mantığı (işe gitmiyorsa) ---
			if abs(global_position.x - move_target_x) > 5.0: 
				global_position.x = move_toward(global_position.x, move_target_x, move_speed * delta)
				sprite.flip_h = move_target_x < global_position.x 
			else:
				var wander_range = 150.0 
				var base_x = global_position.x 
				move_target_x = base_x + randf_range(-wander_range, wander_range)
				# TODO: Sahne sınırları kontrolü eklenebilir
				
		State.GOING_TO_BUILDING_FIRST:
			# Binaya doğru hareket et
			if is_instance_valid(assigned_building_node) and abs(global_position.x - move_target_x) > 5.0:
				global_position.x = move_toward(global_position.x, move_target_x, move_speed * delta)
				sprite.flip_h = move_target_x < global_position.x 
			else:
				# Binaya vardı, bina türüne ve seviyesine göre karar ver
				if is_instance_valid(assigned_building_node) and assigned_building_node.has_method("get_script"):
					var building_node = assigned_building_node # Kısa isim
					var go_inside = false # Varsayılan: dışarı çık

					# 1. worker_stays_inside özelliğini kontrol et
					if "worker_stays_inside" in building_node and building_node.worker_stays_inside:
						go_inside = true
					else:
						# 2. Seviye ve İLK işçi kontrolü (sadece worker_stays_inside false ise)
						if "level" in building_node and building_node.level >= 2 and \
						   "assigned_worker_ids" in building_node and \
						   not building_node.assigned_worker_ids.is_empty() and \
						   worker_id == building_node.assigned_worker_ids[0]: #<<< DÜZELTİLDİ: [-1] yerine [0]
							go_inside = true

					# Karara göre state değiştir
					if go_inside:
						# --- İÇERİDE ÇALIŞMA MANTIĞI ---
						print("Worker %d entering building %s (Level %d, FirstWorker=%s) to work inside." % [
							worker_id, building_node.name, building_node.level if "level" in building_node else 1, 
							(true if ("assigned_worker_ids" in building_node and not building_node.assigned_worker_ids.is_empty() and worker_id == building_node.assigned_worker_ids[0]) else false)
						]) # DEBUG <<< DEĞİŞTİ: LastWorker yerine FirstWorker
						current_state = State.WORKING_INSIDE 
						visible = false # İşçiyi gizle
						global_position = building_node.global_position
					else:
						# --- DIŞARIDA ÇALIŞMA MANTIĞI (MEVCUT KOD) ---
						print("Worker %d reached building %s (Level %d), going offscreen." % [
							worker_id, building_node.name, building_node.level if "level" in building_node else 1
						]) # DEBUG
						current_state = State.WORKING_OFFSCREEN
						if global_position.x < 960: # Ekranın ortası
							move_target_x = -2500.0
						else:
							move_target_x = 2500.0
				else:
					# Bina geçerli değil veya scripti yoksa varsayılan davranış
					printerr("Worker %d reached target, but assigned_building_node is invalid or has no script!" % worker_id)
					current_state = State.AWAKE_IDLE # Güvenli bir duruma geç

		State.WORKING_OFFSCREEN:
			# Ekran dışına doğru hareket et
			if abs(global_position.x - move_target_x) > 5.0:
				global_position.x = move_toward(global_position.x, move_target_x, move_speed * delta)
				sprite.flip_h = move_target_x < global_position.x 
			else:
				# Ekran dışına ulaştı
				print("Worker %d ekran dışına çıktı, çalışıyor (beklemede)." % worker_id) # Debug
				_offscreen_exit_x = global_position.x #<<< YENİ: Çıkış X'ini kaydet
				visible = false
				current_state = State.WAITING_OFFSCREEN # Durumu değiştir! Spam biter.

		State.WORKING_INSIDE:
			# İşçi görünmez ve bina içinde çalışıyor varsayılır.
			
			# <<< YENİ: Fetching timer'ı başlat (eğer uygunsa ve çalışmıyorsa) >>>
			_start_fetching_timer()
			# <<< YENİ SONU >>>

			# İş bitiş zamanını kontrol et.
			var current_hour = TimeManager.get_hour()
			var current_minute = TimeManager.get_minute()
			if current_hour == TimeManager.WORK_END_HOUR and current_minute >= work_end_minute_offset:
				print("Worker %d finished working inside building." % worker_id)
				visible = true 
				# <<< YENİ: İş bitince fetch timer'ı durdur >>>
				if not fetching_timer.is_stopped():
					fetching_timer.stop()
				# <<< YENİ SONU >>>
				# Konumu bina konumu olarak ayarla (önceki state'de yapıldı ama yine de yapalım)
				if is_instance_valid(assigned_building_node):
					global_position = assigned_building_node.global_position
				else:
					# Bina yoksa, son bilinen X'te ortaya çıksın?
					pass # Veya bulunduğu yerde kalsın

				# İş bitince uyku vakti mi kontrol et
				if current_hour >= TimeManager.SLEEP_HOUR:
					if is_instance_valid(housing_node):
						print("Worker %d going to sleep from inside building." % worker_id)
						current_state = State.GOING_TO_SLEEP
						move_target_x = housing_node.global_position.x
					else:
						# Uyuyacak yer yoksa sosyalleşsin
						print("Worker %d finished work, no housing, socializing." % worker_id)
						current_state = State.SOCIALIZING
						var wander_range = 150.0
						move_target_x = global_position.x + randf_range(-wander_range, wander_range)
				else:
					# Uyku vakti değilse sosyalleşsin
					print("Worker %d finished work, socializing." % worker_id)
					current_state = State.SOCIALIZING
					var wander_range = 150.0
					move_target_x = global_position.x + randf_range(-wander_range, wander_range)

		State.WAITING_OFFSCREEN:
			# İş bitiş zamanı mı kontrol et
			var current_hour = TimeManager.get_hour()
			var current_minute = TimeManager.get_minute()
			if current_hour == TimeManager.WORK_END_HOUR and current_minute >= work_end_minute_offset:
				print("Worker %d işten dönüyor." % worker_id)
				current_state = State.RETURNING_FROM_WORK
				visible = true # Tekrar görünür yap
				# Ekranın kenarından içeri girmesini sağla (Kaydedilen X'i kullanarak)
				var entry_margin = 10.0 # Kenardan ne kadar içeride belirecek
				if _offscreen_exit_x < 0: # Sol kenardan çıktıysa
					global_position.x = _offscreen_exit_x - entry_margin # Çıktığı noktanın biraz solunda başlat
					move_target_x = _offscreen_exit_x + entry_margin * 2 # Çıktığı noktanın biraz sağına hedefle
				else: # Sağ kenardan çıktıysa
					global_position.x = _offscreen_exit_x + entry_margin # Çıktığı noktanın biraz sağında başlat
					move_target_x = _offscreen_exit_x - entry_margin * 2 # Çıktığı noktanın biraz soluna hedefle

		State.RETURNING_FROM_WORK:
			# Ekranın içine doğru hareket et (Binaya doğru değil, sadece ekran içine)
			# Hedef artık kaydedilen çıkış noktasının yakını
			if abs(global_position.x - move_target_x) > 5.0:
				global_position.x = move_toward(global_position.x, move_target_x, move_speed * delta)
				sprite.flip_h = move_target_x < global_position.x
			else:
				# Ekran içine girdi, şimdi binaya uğrayacak
				print("Worker %d ekran içine döndü, binaya uğrayacak." % worker_id)
				if is_instance_valid(assigned_building_node):
					current_state = State.GOING_TO_BUILDING_LAST
					move_target_x = assigned_building_node.global_position.x
				else:
					# Bina yoksa (yıkıldıysa vs.) direkt sosyalleşsin
					print("Worker %d: Atanmış bina artık geçerli değil, sosyalleşiyor." % worker_id)
					current_state = State.SOCIALIZING
					# Rastgele hedef belirle
					var wander_range = 150.0
					move_target_x = global_position.x + randf_range(-wander_range, wander_range)

		State.GOING_TO_BUILDING_LAST:
			# Binaya doğru hareket et
			if is_instance_valid(assigned_building_node) and abs(global_position.x - move_target_x) > 5.0:
				global_position.x = move_toward(global_position.x, move_target_x, move_speed * delta)
				sprite.flip_h = move_target_x < global_position.x
			else:
				# Binaya vardı (veya bina yok oldu)
				print("Worker %d binaya uğradı, şimdi sosyalleşecek." % worker_id)
				current_state = State.SOCIALIZING
				# Rastgele hedef belirle
				var wander_range = 150.0
				move_target_x = global_position.x + randf_range(-wander_range, wander_range)

		State.SOCIALIZING:
			# --- Uyku Zamanı Kontrolü ---
			var current_hour = TimeManager.get_hour()
			# SLEEP_HOUR TimeManager'da tanımlı olmalı (örneğin 22)
			if current_hour >= TimeManager.SLEEP_HOUR: 
				if is_instance_valid(housing_node):
					print("Worker %d uyumaya gidiyor." % worker_id)
					current_state = State.GOING_TO_SLEEP
					move_target_x = housing_node.global_position.x
					return # State değişti, bu frame'i bitir
				else:
					printerr("Worker %d: Uyuyacak yer (housing_node) yok!" % worker_id)
					# Uyuyacak yer yoksa ne yapsın? Şimdilik gezinmeye devam etsin.

			# --- Sosyalleşme/Boşta Gezme Mantığı ---
			if abs(global_position.x - move_target_x) > 5.0: 
				global_position.x = move_toward(global_position.x, move_target_x, move_speed * delta)
				sprite.flip_h = move_target_x < global_position.x 
			else:
				# Hedefe vardı, yeni bir rastgele hedef belirle
				var wander_range = 150.0 
				# housing_node etrafında gezinmesini sağlayabiliriz
				var base_x = global_position.x 
				if is_instance_valid(housing_node):
					base_x = housing_node.global_position.x
					
				move_target_x = base_x + randf_range(-wander_range, wander_range)
				# TODO: Sahne sınırları kontrolü eklenebilir
			
			# --- UYKU ZAMANI KONTROLÜ (Sonra eklenecek) ---

		State.GOING_TO_SLEEP:
			# Barınağa doğru hareket et
			if is_instance_valid(housing_node) and abs(global_position.x - move_target_x) > 5.0:
				global_position.x = move_toward(global_position.x, move_target_x, move_speed * delta)
				sprite.flip_h = move_target_x < global_position.x
			else:
				# Barınağa vardı (veya barınak yok oldu)
				print("Worker %d barınağa ulaştı ve uykuya daldı." % worker_id)
				current_state = State.SLEEPING
				visible = false
				# İsteğe bağlı: Konumu tam barınak konumu yap
				if is_instance_valid(housing_node):
					global_position = housing_node.global_position 

		State.FETCHING_RESOURCE:
			# Hedef kaynak binasına git
			if abs(global_position.x - move_target_x) > 5.0: 
				global_position.x = move_toward(global_position.x, move_target_x, move_speed * delta)
				sprite.flip_h = move_target_x < global_position.x 
			else:
				# Hedefe vardı, bekleme durumuna geç
				print("Worker %d reached fetch destination, waiting..." % worker_id) # Mesaj güncellendi
				current_state = State.WAITING_AT_SOURCE
				visible = false # Görünmez yap
				wait_at_source_timer.start() # Bekleme zamanlayıcısını başlat

		State.WAITING_AT_SOURCE:
			# Bu durumda işçi görünmez ve zamanlayıcının dolmasını bekler.
			# Hareket etmez.
			pass 

		State.RETURNING_FROM_FETCH:
			# Binaya geri dön
			if is_instance_valid(assigned_building_node) and abs(global_position.x - move_target_x) > 5.0:
				global_position.x = move_toward(global_position.x, move_target_x, move_speed * delta)
				sprite.flip_h = move_target_x < global_position.x 
			else:
				# Binaya vardı
				print("Worker %d returned to building after fetching." % worker_id)
				current_state = State.WORKING_INSIDE
				visible = false
				if is_instance_valid(assigned_building_node): # Güvenlik kontrolü
					global_position = assigned_building_node.global_position
					if assigned_building_node.has_method("finished_fetching"):
						assigned_building_node.finished_fetching()
					else:
						printerr("Worker %d: Building %s has no finished_fetching method!" % [worker_id, assigned_building_node.name])
					# Zamanlayıcı WORKING_INSIDE'da tekrar başlayacak

		_:
			pass # Bilinmeyen veya henüz işlenmeyen durumlar

# Worker'ın scriptine set fonksiyonları eklemek daha güvenli olabilir:
# --- Worker.gd içine eklenecek opsiyonel set fonksiyonları ---
# func set_worker_id(id: int):
#     worker_id = id
# func set_housing_node(node: Node2D):
#     housing_node = node
# ---------------------------------------------------------

func _on_animation_finished(anim_name):
	if anim_name == "walk":
		$AnimatedSprite2D.play("idle")

# <<< YENİ FONKSİYON BAŞLANGIÇ >>>
# Bina yükseltmesi tamamlandığında çağrılır (eğer bu işçi ilk işçiyse ve dışarıdaysa)
func switch_to_working_inside():
	if current_state == State.WORKING_OFFSCREEN or current_state == State.WAITING_OFFSCREEN:
		# print("Worker %d switching from OFFSCREEN to WORKING_INSIDE due to building upgrade." % worker_id) #<<< KALDIRILDI
		current_state = State.WORKING_INSIDE
		visible = false
		# İsteğe bağlı: İşçiyi bina girişine yakın bir yere ışınlayabilir veya
		# sadece görünür yapıp animasyonu güncelleyebiliriz. Şimdilik görünür yapalım.
		#$AnimatedSprite2D.play("idle") # Veya uygun bir 'working_inside' animasyonu varsa o
	#else:
		# Zaten içerideyse veya başka bir durumdaysa işlem yapma
		# print("Worker %d not switching state, current state: %s" % [worker_id, State.keys()[current_state]]) #<<< KALDIRILDI
# <<< YENİ FONKSİYON BİTİŞ >>>

# <<< YENİ FONKSİYON BAŞLANGIÇ: switch_to_working_offscreen >>>
# İşçi içeride çalışırken (WORKING_INSIDE) dışarıda çalışmaya geçirmek için
func switch_to_working_offscreen():
	if current_state == State.WORKING_INSIDE:
		# print("Worker %d switching from INSIDE to WORKING_OFFSCREEN." % worker_id) #<<< KALDIRILDI
		current_state = State.WORKING_OFFSCREEN
		visible = true # Görünür yap
		# Binanın konumuna göre ekran dışı hedefini belirle
		if is_instance_valid(assigned_building_node):
			if assigned_building_node.global_position.x < 960: # Kabaca ekran merkezi
				move_target_x = -2500.0
			else:
				move_target_x = 2500.0
			# Pozisyonu bina konumu yap ki oradan yürümeye başlasın
			global_position = assigned_building_node.global_position
		else:
			# Bina geçerli değilse, bulunduğu yerden rastgele bir yöne gitsin? Güvenli varsayım:
			printerr("Worker %d switching to OFFSCREEN but building node is invalid. Using current pos." % worker_id)
			if global_position.x < 960: 
				move_target_x = -2500.0
			else:
				move_target_x = 2500.0
		
		$AnimatedSprite2D.play("walk") # Yürüme animasyonunu başlat
	#else:
		# Zaten dışarıdaysa veya başka bir durumdaysa işlem yapma
		# print("Worker %d not switching to OFFSCREEN, current state: %s" % [worker_id, State.keys()[current_state]]) #<<< KALDIRILDI
# <<< YENİ FONKSİYON BİTİŞ >>>

# <<< YENİ: Zamanlayıcı Sinyali İşleyici >>>
func _on_fetching_timer_timeout():
	# Sadece içeride çalışırken ve bina geçerliyse tetiklenmeli
	if current_state != State.WORKING_INSIDE or not is_instance_valid(assigned_building_node):
		return

	# <<< YENİ: İş Bitiş Saati Kontrolü >>>
	var current_hour = TimeManager.get_hour()
	if current_hour >= TimeManager.WORK_END_HOUR:
		print("Worker %d stopping fetch timer, it's end of work time." % worker_id)
		# Fetch timer zaten doldu, tekrar başlatmaya gerek yok.
		# Doğrudan iş bitiş mantığını çalıştır (WORKING_INSIDE'dan kopyalandı/uyarlandı)
		visible = true # Görünür yap (eğer zaten değilse)
		
		# Konumu bina konumu yap
		if is_instance_valid(assigned_building_node):
			global_position = assigned_building_node.global_position
		
		# Uyku vakti mi?
		if current_hour >= TimeManager.SLEEP_HOUR:
			if is_instance_valid(housing_node):
				print("Worker %d going to sleep directly after fetch timer (work end time)." % worker_id)
				current_state = State.GOING_TO_SLEEP
				move_target_x = housing_node.global_position.x
			else:
				print("Worker %d finished work (fetch timer), no housing, socializing." % worker_id)
				current_state = State.SOCIALIZING
				var wander_range = 150.0
				move_target_x = global_position.x + randf_range(-wander_range, wander_range)
		else:
			# Uyku vakti değilse sosyalleş
			print("Worker %d finished work (fetch timer), socializing." % worker_id)
			current_state = State.SOCIALIZING
			var wander_range = 150.0
			move_target_x = global_position.x + randf_range(-wander_range, wander_range)
		return # Fetch işlemine devam etme
	# <<< YENİ KONTROL SONU >>>
		
	# Binanın izin fonksiyonu var mı ve izin veriyor mu?
	if assigned_building_node.has_method("can_i_fetch") and assigned_building_node.can_i_fetch():
		# 1. Binanın hangi kaynaklara ihtiyacı olduğunu öğren
		var required = {}
		if assigned_building_node.has_method("get") and assigned_building_node.get("required_resources") is Dictionary:
			required = assigned_building_node.get("required_resources")
		
		if required.is_empty():
			printerr("Worker %d: Cannot determine required resources for %s! Aborting fetch." % [worker_id, assigned_building_node.name])
			assigned_building_node.finished_fetching() # İzni geri ver
			_start_fetching_timer() # Zamanlayıcıyı yeniden başlat
			return
			
		# 2. İhtiyaç duyulan kaynaklardan birini rastgele seç
		var resource_to_fetch = required.keys()[randi() % required.size()]
		
		# 3. VillageManager'dan o kaynağı üreten binanın konumunu al
		var target_pos = VillageManager.get_source_building_position(resource_to_fetch)
		
		if target_pos == Vector2.ZERO:
			print("Worker %d: Could not find a source building for '%s'. Skipping fetch." % [worker_id, resource_to_fetch])
			assigned_building_node.finished_fetching() # İzni geri ver
			_start_fetching_timer() # Zamanlayıcıyı yeniden başlat
			return
			
		# 4. Hareketi başlat
		print("Worker %d starting resource fetch for '%s' towards %s..." % [worker_id, resource_to_fetch, target_pos])
		current_state = State.FETCHING_RESOURCE
		visible = true
		move_target_x = target_pos.x # Hedef X'i ayarla
	else:
		# İzin yok veya fonksiyon yok, tekrar bekle (ama saat kontrolü zaten yapıldı)
		_start_fetching_timer()
# <<< YENİ SONU >>>

# <<< YENİ: Zamanlayıcı Başlatma Fonksiyonu >>>
func _start_fetching_timer():
	# Sadece içeride çalışan ve işleme binasında olanlar için
	if current_state == State.WORKING_INSIDE and \
	   is_instance_valid(assigned_building_node) and \
	   assigned_building_node.has_method("get") and \
	   assigned_building_node.get("worker_stays_inside") == true: # Güvenli erişim
		
		if fetching_timer.is_stopped(): # Zaten çalışmıyorsa
			var wait_time = randf_range(fetch_interval_min, fetch_interval_max)
			fetching_timer.start(wait_time)
			# print("Worker %d fetching timer started (%s sec)." % [worker_id, wait_time]) # Debug
# <<< YENİ SONU >>>

# YENİ Timer için timeout fonksiyonu
func _on_wait_at_source_timer_timeout():
	# Sadece WAITING_AT_SOURCE durumundaysa çalışmalı
	if current_state != State.WAITING_AT_SOURCE:
		return
		
	print("Worker %d finished waiting at source, returning to building." % worker_id)
	current_state = State.RETURNING_FROM_FETCH
	visible = true # Tekrar görünür yap
	if is_instance_valid(assigned_building_node):
		move_target_x = assigned_building_node.global_position.x
	else:
		# Bina yoksa? Güvenli bir yere git?
		printerr("Worker %d: Building node invalid while returning from fetch!" % worker_id)
		move_target_x = global_position.x
# <<< YENİ SONU >>>
