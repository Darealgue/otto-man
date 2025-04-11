extends Node2D

# --- Building Properties ---
var building_name: String = "Fırın"
@export var level: int = 1
@export var max_workers: int = 1 # Başlangıçta 1 işçi alabilir
@export var assigned_workers: int = 0

# Gerekli temel kaynak (üretim için)
var required_resource: String = "food" # Şimdilik buğday/un yerine food kullanalım
var required_resource_amount: int = 1 # Bir ekmek için 1 birim food

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
		
	# Önce gerekli kaynak var mı diye ANLIK kontrol et
	if VillageManager.get_available_resource_level(required_resource) < required_resource_amount:
		print("%s: İşçi atanamıyor, yeterli %s yok." % [building_name, required_resource])
		return false

	# VillageManager'dan boşta işçi kontrolü ve kaydı
	if VillageManager.register_generic_worker(): 
		# İşçi alındı, şimdi üretimi kaydet (kaynakları tüket/artır)
		if VillageManager.register_advanced_production(produced_resource, required_resource, required_resource_amount):
			assigned_workers += 1
			print("%s: İşçi atandı ve üretim başladı (%d/%d)" % [building_name, assigned_workers, max_workers])
			_update_ui()
			return true
		else:
			# Üretim kaydedilemedi (kaynak yetersiz kalmış olabilir - nadir durum)
			# İşçiyi geri bırak
			VillageManager.unregister_generic_worker()
			print("%s: Üretim başlatılamadığı için işçi geri çekildi." % building_name)
			return false
	else:
		# Boşta işçi yok (Hata mesajı VillageManager tarafından yazdırılacak)
		return false

func remove_worker() -> bool:
	if assigned_workers > 0:
		assigned_workers -= 1
		# İleri seviye üretimi kaldır (kaynakları geri ver)
		VillageManager.unregister_advanced_production(produced_resource, required_resource, required_resource_amount)
		# Genel işçiyi geri bırak
		VillageManager.unregister_generic_worker()
		print("%s: İşçi çıkarıldı ve üretim durdu (%d/%d)" % [building_name, assigned_workers, max_workers])
		_update_ui()
		return true
	else:
		print("%s: Çıkarılacak işçi yok." % building_name)
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
