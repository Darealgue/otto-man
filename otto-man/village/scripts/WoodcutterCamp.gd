class_name WoodcutterCamp
extends Node2D

# Bu binaya özgü değişkenler
var assigned_workers: int = 0
var max_workers: int: # Maksimum işçi sayısı seviyeye göre hesaplanır
	get: return level

# Bu bina için bir işçi atamaya çalışır
func add_worker() -> bool:
	if is_upgrading: # Yükseltme sırasında işçi eklenemez/çıkarılamaz
		print("Oduncu Kampı: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers >= max_workers:
		print("Oduncu Kampı: Kapasite dolu!")
		return false
	if VillageManager.idle_workers <= 0:
		print("Oduncu Kampı: Boşta işçi yok!")
		return false
	assigned_workers += 1
	print("Oduncu Kampı: İşçi atandı (%d/%d)" % [assigned_workers, max_workers])
	VillageManager.register_worker_assignment("wood") # Hangi tür kaynağa atandığını bildir
	
	# Görsel bir değişiklik yapabiliriz (örn. sprite değişimi, animasyon) - daha sonra
	
	return true # Başarılı

# Bu binadan bir işçi çıkarır
func remove_worker() -> bool:
	if is_upgrading: # Yükseltme sırasında işçi eklenemez/çıkarılamaz
		print("Oduncu Kampı: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers <= 0:
		print("Oduncu Kampı: Çıkarılacak işçi yok!")
		return false
	assigned_workers -= 1
	print("Oduncu Kampı: İşçi çıkarıldı (%d/%d)" % [assigned_workers, max_workers])
	VillageManager.unregister_worker_assignment("wood") # Hangi tür kaynaktan çıkarıldığını bildir
		
	# Görsel bir değişiklik yapabiliriz - daha sonra

	return true # Başarılı

# --- Yükseltme Değişkenleri ---
var level: int = 1
var max_level: int = 3 # Örnek bir maksimum seviye
var is_upgrading: bool = false
var upgrade_duration: float = 5.0 # Saniye cinsinden yükseltme süresi (test için)

# Yükseltme maliyetleri: Seviye -> {kaynak: seviye_gereksinimi}
# Seviye 2 için maliyet (Seviye 1'den 2'ye geçerken)
const UPGRADE_COSTS = {
	2: {"stone": 1}, # Seviye 2 için 1 Taş seviyesi gerekir
	3: {"stone": 1, "metal": 1} # Seviye 3 için 1 Taş ve 1 Metal seviyesi gerekir (Metal eklenince)
}

# --- Zamanlayıcı (Timer) ---
var upgrade_timer: Timer

# --- Sinyaller ---
signal upgrade_started # Yükseltme başladığında UI'ı bilgilendirmek için
signal upgrade_finished # Yükseltme bittiğinde UI'ı bilgilendirmek için

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Yükseltme zamanlayıcısını oluştur ve ayarla
	upgrade_timer = Timer.new()
	upgrade_timer.one_shot = true # Sadece bir kez çalışacak
	upgrade_timer.wait_time = upgrade_duration
	upgrade_timer.timeout.connect(finish_upgrade) # Süre dolunca finish_upgrade'i çağır
	add_child(upgrade_timer) # Zamanlayıcıyı sahne ağacına ekle

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# --- Yeni Yükseltme Fonksiyonları ---

# Bir sonraki seviyenin maliyetini döndürür
func get_next_upgrade_cost() -> Dictionary:
	var next_level = level + 1
	if UPGRADE_COSTS.has(next_level):
		return UPGRADE_COSTS[next_level]
	else:
		return {} # Maliyet yok veya maksimum seviyeye ulaşıldı

# Yükseltmeyi başlatır (UI tarafından çağrılacak)
func start_upgrade() -> bool:
	if is_upgrading:
		print("Oduncu Kampı: Zaten yükseltiliyor.")
		return false
	if level >= max_level:
		print("Oduncu Kampı: Zaten maksimum seviyede.")
		return false

	var cost = get_next_upgrade_cost()
	if cost.is_empty():
		print("Oduncu Kampı: Bir sonraki seviye için maliyet bulunamadı.")
		return false

	if not VillageManager.lock_resources(cost, self): return false

	print("Oduncu Kampı: Yükseltme başlatıldı (Seviye %d -> %d)" % [level, level + 1])
	is_upgrading = true
	
	# İşçi varsa geri çek (opsiyonel - yükseltme sırasında bina boşaltılabilir)
	# while assigned_workers > 0:
	#	 remove_worker() 
		
	upgrade_timer.start() # Zamanlayıcıyı başlat
	emit_signal("upgrade_started") # Sinyali gönder
	
	# Görsel olarak yükseltildiğini belirtebiliriz (örn. rengini değiştir)
	if get_node_or_null("Sprite2D") is Sprite2D: # Eğer Sprite2D varsa
		get_node("Sprite2D").modulate = Color.YELLOW

	return true

# Yükseltme tamamlandığında çağrılır (Timer tarafından)
func finish_upgrade() -> void:
	if not is_upgrading: return # Zaten bitmişse veya hiç başlamamışsa bir şey yapma

	print("Oduncu Kampı: Yükseltme tamamlandı (Seviye %d)" % (level + 1))
	is_upgrading = false
	level += 1
	# max_workers otomatik olarak güncellenecek (get metodu sayesinde)

	var cost = UPGRADE_COSTS.get(level, {}) # Bir önceki seviyenin maliyetini al (artık yeni level)

	VillageManager.unlock_resources(cost, self)
	
	emit_signal("upgrade_finished") # Sinyali gönder

	# Görseli normale döndür
	if get_node_or_null("Sprite2D") is Sprite2D:
		get_node("Sprite2D").modulate = Color.WHITE

	print("Oduncu Kampı: Yeni seviye: %d, Maks İşçi: %d" % [level, max_workers])
