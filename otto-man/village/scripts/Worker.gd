extends Node2D

var worker_id: int = -1 # VillageManager tarafından atanacak

# İşçinin olası durumları
enum State { 
	SLEEPING,         # Uyuyor (görünmez)
	AWAKE_IDLE,       # Uyanık, işsiz/boşta geziyor
	GOING_TO_BUILDING_FIRST, # İşe gitmek için ÖNCE binaya uğruyor
	WORKING_OFFSCREEN, # Bu state sadece hedefe gidene kadar sürecek
	WAITING_OFFSCREEN, # Ekran dışında iş bitimini beklerken
	RETURNING_FROM_WORK, # İşten dönüyor (ekran dışından geliyor)
	GOING_TO_BUILDING_LAST, # İşten dönünce SONRA binaya uğruyor
	SOCIALIZING,      # Köyde sosyalleşiyor/dolaşıyor
	GOING_TO_SLEEP    # Uyumak için barınağa gidiyor
} 
var current_state = State.SLEEPING # Başlangıç durumu (Tip otomatik çıkarılacak)

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

@onready var sprite: Sprite2D = $Sprite2D # Sprite node'una referans (eğer adı farklıysa değiştir)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Başlangıçta görünmez yapalım, uyandığında görünür olacak
	visible = false 
	move_target_x = global_position.x # Başlangıçta hedefi kendi konumu yap

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
				visible = true
				# Uyandığı noktada belirsin (barınağın konumu)
				if is_instance_valid(housing_node): # Güvenlik kontrolü
					global_position = housing_node.global_position
					# Rastgele ilk hedefi belirle (kamp ateşi etrafında?)
					var wander_range = 150.0 # Kamp ateşi etrafında ne kadar gezinsin?
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
			if abs(global_position.x - move_target_x) > 5.0: 
				global_position.x = move_toward(global_position.x, move_target_x, move_speed * delta)
				sprite.flip_h = move_target_x < global_position.x 
			else:
				# Binaya vardı, şimdi ekran dışına çıkacak
				print("Worker %d binaya ulaştı, çalışmak için ekran dışına gidiyor." % worker_id) # Debug
				current_state = State.WORKING_OFFSCREEN
				# Binanın konumuna göre sağa veya sola gitmesini sağlayalım
				# Viewport genişliğini almak yerine direkt sabit hedefleri kullanalım
				if global_position.x < 960: # Ekranın ortası (1920/2 varsayımı - gerekirse ayarla)
					# Bina sol taraftaysa sola doğru çık
					move_target_x = -2500 # Yeni Sol Hedef X
				else:
					# Bina sağ taraftaysa sağa doğru çık
					move_target_x = 2500  # Yeni Sağ Hedef X

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
		_:
			pass # Bilinmeyen veya henüz işlenmeyen durumlar

# Worker'ın scriptine set fonksiyonları eklemek daha güvenli olabilir:
# --- Worker.gd içine eklenecek opsiyonel set fonksiyonları ---
# func set_worker_id(id: int):
#     worker_id = id
# func set_housing_node(node: Node2D):
#     housing_node = node
# ---------------------------------------------------------
