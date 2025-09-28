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

# --- ZAMAN BAZLI EKMEK ÜRETİMİ ---
var bread_production_progress: float = 0.0
const BREAD_PRODUCTION_TIME: float = 300.0 # 2 oyun saati (300 gerçek saniye) = 1 ekmek
var is_producing: bool = false

# --- UI Bağlantıları (Eğer varsa, yolları ayarla) ---
# @onready var worker_label: Label = %WorkerLabel

func _ready() -> void:
	_update_ui()
	print("%s hazır." % building_name)

# Her frame'de ekmek üretimini kontrol et
func _process(delta: float) -> void:
	# Zaman ölçeğini uygula (TimeManager ile tutarlı olması için)
	var scaled_delta = delta * Engine.time_scale
	
	# Debug: Bakery _process çağrıldığında delta değerini kontrol et
	if Engine.time_scale >= 16.0 and delta > 0.1:
		print("🍞 Bakery _process - Delta: %.3f, Scaled Delta: %.3f, Time Scale: %.1f, Producing: %s, Workers: %d" % [delta, scaled_delta, Engine.time_scale, is_producing, assigned_workers])
	
	# Çalışma saatleri kontrolü - sadece 7:00-18:00 arası üretim yapılır
	if not TimeManager.is_work_time():
		return # Çalışma saatleri dışında üretim yok
	
	if is_producing and assigned_workers > 0:
		# Gerekli kaynaklar var mı kontrol et
		var can_produce = true
		for resource_name in required_resources:
			var amount_needed = required_resources[resource_name]
			if VillageManager.get_available_resource_level(resource_name) < amount_needed:
				can_produce = false
				break
		
		if can_produce:
			# Üretim ilerlemesini artır (işçi atandığında sürekli çalışır)
			bread_production_progress += scaled_delta
			
			# Debug: Ekmek üretim ilerlemesini göster
			if Engine.time_scale >= 16.0 and bread_production_progress > 0:
				print("🍞 Ekmek üretim ilerlemesi: %.2f/%.1f (%.1f%%)" % [bread_production_progress, BREAD_PRODUCTION_TIME, (bread_production_progress / BREAD_PRODUCTION_TIME) * 100])
			
			# 1 ekmek üretildi mi?
			if bread_production_progress >= BREAD_PRODUCTION_TIME:
				# Kaynakları harca
				for resource_name in required_resources:
					var amount_needed = required_resources[resource_name]
					VillageManager.lock_resource_level(resource_name, amount_needed)
				
				# Ekmek üret
				VillageManager.resource_levels["bread"] = VillageManager.resource_levels.get("bread", 0) + 1
				VillageManager.emit_signal("village_data_changed")
				
				# İlerlemeyi sıfırla
				bread_production_progress = 0.0
				
				print("%s: 1 ekmek üretildi! Toplam ekmek: %d" % [building_name, VillageManager.resource_levels.get("bread", 0)])
				# Toplam kaynakları göster
				print("📊 TOPLAM KAYNAKLAR: Odun:%d, Taş:%d, Yiyecek:%d, Su:%d, Metal:%d, Ekmek:%d" % [
					VillageManager.resource_levels.get("wood", 0),
					VillageManager.resource_levels.get("stone", 0), 
					VillageManager.resource_levels.get("food", 0),
					VillageManager.resource_levels.get("water", 0),
					VillageManager.resource_levels.get("metal", 0),
					VillageManager.resource_levels.get("bread", 0)
				])
		else:
			# Kaynak yoksa üretimi durdur
			bread_production_progress = 0.0

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

	# 2. Başarılı: İşçi Bilgilerini Ayarla ve Kaydet
	assigned_workers += 1
	assigned_worker_instance = worker_instance # İşçi referansını kaydet
	
	# İşçinin hedefini ve durumunu ayarla
	worker_instance.assigned_job_type = "bread"
	worker_instance.assigned_building_node = self
	worker_instance.move_target_x = self.global_position.x
	worker_instance.current_state = worker_instance.State.GOING_TO_BUILDING_FIRST
	
	# Üretimi başlat
	is_producing = true
	bread_production_progress = 0.0
	
	print("%s: İşçi (ID: %d) atandı ve üretim başladı (%d/%d). Gerekli kaynaklar: %s" % [
		building_name, worker_instance.worker_id, assigned_workers, max_workers, required_resources
	])
	_update_ui()
	return true

func remove_worker() -> bool:
	if assigned_workers > 0 and is_instance_valid(assigned_worker_instance):
		var worker_to_remove = assigned_worker_instance # Referansı al
		assigned_workers -= 1
		assigned_worker_instance = null # Referansı temizle

		# Üretimi durdur
		is_producing = false
		bread_production_progress = 0.0
		
		# İşçinin Durumunu Sıfırla
		worker_to_remove.assigned_job_type = ""
		worker_to_remove.assigned_building_node = null
		worker_to_remove.move_target_x = worker_to_remove.global_position.x # Hedefi sıfırla
		# Eğer içerideyse veya işe gidiyorsa idle yap
		if worker_to_remove.current_state == worker_to_remove.State.WORKING_INSIDE or \
		   worker_to_remove.current_state == worker_to_remove.State.GOING_TO_BUILDING_FIRST:
			worker_to_remove.current_state = worker_to_remove.State.AWAKE_IDLE
			worker_to_remove.visible = true # Görünür yap

		# İşçiyi VillageManager'dan kaldır
		# VillageManager.unregister_generic_worker(worker_to_remove.worker_id) # MissionCenter.gd'de çağrılıyor
		
		print("%s: İşçi (ID: %d) çıkarıldı ve üretim durdu (%d/%d)." % [
			building_name, worker_to_remove.worker_id, assigned_workers, max_workers
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
		is_producing = false
		bread_production_progress = 0.0
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
