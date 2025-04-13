extends Node2D

# --- Building Properties ---
var building_name: String = "Fırın"
@export var level: int = 1
@export var max_workers: int = 1 # Başlangıçta 1 işçi alabilir
@export var assigned_workers: int = 0
@export var worker_stays_inside: bool = true #<<< YENİ (Fırın için true)
var assigned_worker_instance: Node = null #<<< YENİ: Atanan işçinin referansı

# <<< YENİ: Fetching Durumu >>>
var is_fetcher_out: bool = false # Aynı anda sadece 1 işçi dışarı çıkabilir
# <<< YENİ SONU >>>

# Gerekli temel kaynaklar (üretim için)
# Artık dictionary olarak tanımlıyoruz: {"kaynak_adı": miktar}
var required_resources: Dictionary = {"food": 1, "water": 1}

# Üretilen gelişmiş kaynak
var produced_resource: String = "bread"
# var produced_resource_amount: int = 1 # Artık VillageManager'da varsayılıyor

# Üretim Döngüsü Zamanlayıcısı - KALDIRILDI
# @onready var production_timer: Timer = Timer.new()

# --- UI Bağlantıları (Eğer varsa, yolları ayarla) ---
# @onready var worker_label: Label = %WorkerLabel

func _ready() -> void:
	# Production Timer ayarları kaldırıldı
	_update_ui()
	print("%s hazır." % building_name)

# --- Worker Management --- 
func add_worker() -> bool:
	if assigned_workers >= max_workers:
		print("%s: Zaten maksimum işçi sayısına ulaşıldı." % building_name)
		return false
		
	# 1. Boşta İşçi Bul
	var worker_instance: Node = VillageManager.register_generic_worker()
	if not is_instance_valid(worker_instance):
		# Hata mesajı VillageManager'dan geldi
		return false # Boşta işçi yok

	# 2. Gerekli Kaynakları Kontrol Et ve Kilitle
	# Gerekli TÜM kaynaklar var mı diye ANLIK kontrol et (Kilitleme zaten kontrol edecek ama yine de yapalım)
	for resource_name in required_resources:
		var amount_needed = required_resources[resource_name]
		if VillageManager.get_available_resource_level(resource_name) < amount_needed:
			print("%s: İşçi atanamıyor, yeterli %s yok. (Gereken: %d, Mevcut: %d)" % [
				building_name, resource_name, amount_needed, VillageManager.get_available_resource_level(resource_name)
			])
			# İşçiyi geri bırak!
			VillageManager.cancel_worker_registration() #<<< DEĞİŞTİ: Yeni fonksiyon çağrılıyor
			print("%s: Kaynak yetersiz olduğu için alınan işçi (ID: %d) kaydı iptal edildi." % [building_name, worker_instance.worker_id]) # Mesaj güncellendi
			return false
	
	# Kaynakları kilitle (Bu zaten içeride tekrar kontrol ediyor)
	if VillageManager.register_advanced_production(produced_resource, required_resources):
		# 3. Başarılı: İşçi Bilgilerini Ayarla ve Kaydet
		assigned_workers += 1
		assigned_worker_instance = worker_instance # İşçi referansını kaydet
		
		# İşçinin hedefini ve durumunu ayarla
		worker_instance.assigned_job_type = "bread"
		worker_instance.assigned_building_node = self
		worker_instance.move_target_x = self.global_position.x
		worker_instance.current_state = worker_instance.State.GOING_TO_BUILDING_FIRST
		
		print("%s: İşçi (ID: %d) atandı ve üretim başladı (%d/%d). Gerekli kaynaklar: %s" % [
			building_name, worker_instance.worker_id, assigned_workers, max_workers, required_resources
		])
		_update_ui()
		return true
	else:
		# 4. Başarısız: İşçiyi Geri Bırak
		VillageManager.cancel_worker_registration() #<<< DEĞİŞTİ: Yeni fonksiyon çağrılıyor
		print("%s: Üretim başlatılamadığı (kaynak yetersiz?) için alınan işçi (ID: %d) kaydı iptal edildi." % [building_name, worker_instance.worker_id]) # Mesaj güncellendi
		return false

func remove_worker() -> bool:
	if assigned_workers > 0 and is_instance_valid(assigned_worker_instance):
		var worker_to_remove = assigned_worker_instance # Referansı al
		assigned_workers -= 1
		assigned_worker_instance = null # Referansı temizle

		# 1. İleri Seviye Üretimi Kaldır (Kaynakları serbest bırak)
		VillageManager.unregister_advanced_production(produced_resource, required_resources)
		
		# 2. İşçinin Durumunu Sıfırla
		worker_to_remove.assigned_job_type = ""
		worker_to_remove.assigned_building_node = null
		worker_to_remove.move_target_x = worker_to_remove.global_position.x # Hedefi sıfırla
		# Eğer içerideyse veya işe gidiyorsa idle yap
		if worker_to_remove.current_state == worker_to_remove.State.WORKING_INSIDE or \
		   worker_to_remove.current_state == worker_to_remove.State.GOING_TO_BUILDING_FIRST:
			worker_to_remove.current_state = worker_to_remove.State.AWAKE_IDLE
			worker_to_remove.visible = true # Görünür yap

		# İşçiyi VillageManager'dan kaldır
		VillageManager.unregister_generic_worker(worker_to_remove.worker_id)
		
		print("%s: İşçi (ID: %d) çıkarıldı ve üretim durdu (%d/%d). Serbest bırakılan kaynaklar: %s" % [
			building_name, worker_to_remove.worker_id, assigned_workers, max_workers, required_resources
		])
		_update_ui()
		return true
	elif assigned_workers <= 0:
		print("%s: Çıkarılacak işçi yok (Sayaç 0)." % building_name)
		return false
	else: # assigned_workers > 0 ama assigned_worker_instance geçersiz
		printerr("%s: HATA! İşçi sayısı > 0 ama işçi referansı geçersiz! Sayaç sıfırlanıyor." % building_name)
		assigned_workers = 0 # Tutarsızlığı düzelt
		assigned_worker_instance = null
		# Kaynakları serbest bırakmayı deneyelim yine de?
		VillageManager.unregister_advanced_production(produced_resource, required_resources)
		# VillageManager.unregister_generic_worker() # Çağırmasak daha iyi olabilir
		_update_ui()
		return false

# --- Üretim Mantığı - KALDIRILDI ---
# func _on_production_timer_timeout() -> void:
#    ... (eski kod)

# --- UI Update (Varsa) ---
func _update_ui() -> void:
	# if worker_label:
	#    worker_label.text = "%d / %d" % [assigned_workers, max_workers]
	pass # Label yoksa veya adı farklıysa hata vermesin

# --- TODO: Yükseltme Mantığı ---
# func upgrade():
#    ...

# <<< YENİ: Fetching İzin Fonksiyonları >>>
func can_i_fetch() -> bool:
	if not is_fetcher_out:
		is_fetcher_out = true
		# print("%s: Fetching permission granted." % building_name) # Debug
		return true
	else:
		# print("%s: Fetching permission denied (another worker is out)." % building_name) # Debug
		return false

func finished_fetching() -> void:
	if is_fetcher_out:
		is_fetcher_out = false
		# print("%s: Fetcher returned." % building_name) # Debug
	else:
		# Bu durumun olmaması lazım ama güvenlik için loglayalım
		printerr("%s: finished_fetching called but no fetcher was out?" % building_name)
# <<< YENİ SONU >>>
