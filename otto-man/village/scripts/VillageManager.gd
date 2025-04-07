extends Node

# Toplam işçi sayısı (Başlangıçta örnek bir değer)
var total_workers: int = 3 
# Boşta bekleyen işçi sayısı
var idle_workers: int = 3 

# Temel kaynakların mevcut seviyeleri (atanan işçi sayısı)
# Bu hala toplam seviyeyi gösterir, binalar tarafından güncellenir
var resource_levels: Dictionary = {
	"wood": 0,
	"stone": 0,
	"food": 0,
	"water": 0,
	"metal": 0
}

# --- Kaynak Kilitleme ---
# Hangi kaynağın ne kadarının kilitli olduğunu tutar
var locked_resource_levels: Dictionary = {
	"wood": 0, "stone": 0, "food": 0, "water": 0, "metal": 0
}
# Hangi işlemin (örn. hangi binanın yükseltmesi) kaynakları kilitlediğini tutar
# Bu, aynı işlemin yanlışlıkla kendi kilidini açmasını engellemek için kullanılabilir (şimdilik basit)
var resource_locks: Dictionary = {} # { "wood": [locking_object1, locking_object2], ... }

# Gerekirse buraya kaynak seviyelerini güncelleyen fonksiyonlar ekleyeceğiz
# Örneğin: assign_worker_to_resource(resource_type), free_worker_from_resource(resource_type)

# --- Yeni Fonksiyonlar (Binalar tarafından çağrılacak) ---

# Bir binaya işçi atandığında çağrılır
func register_worker_assignment(resource_type: String) -> void:
	if idle_workers > 0:
		idle_workers -= 1
		if resource_levels.has(resource_type):
			resource_levels[resource_type] += 1
			emit_signal("village_data_changed") # UI güncellensin
		else:
			printerr("VillageManager: Bilinmeyen kaynak türü: ", resource_type)
	else:
		printerr("VillageManager: register_worker_assignment çağrıldı ama boşta işçi yok!")

# Bir binadan işçi çıkarıldığında çağrılır
func unregister_worker_assignment(resource_type: String) -> void:
	if resource_levels.has(resource_type) and resource_levels[resource_type] > 0:
		idle_workers += 1
		resource_levels[resource_type] -= 1
		emit_signal("village_data_changed") # UI güncellensin
	else:
		printerr("VillageManager: unregister_worker_assignment çağrıldı ama %s kaynağında zaten işçi yok!" % resource_type)

# --- Kaynak Kilitleme Fonksiyonları ---

# Belirtilen kaynak maliyetinin mevcut ve kilitli olmayan seviyelerle karşılanıp karşılanmadığını kontrol eder
func can_afford_and_lock(cost: Dictionary) -> bool:
	for resource_type in cost:
		var required_level = cost[resource_type]
		if not resource_levels.has(resource_type):
			printerr("VillageManager: Bilinmeyen kaynak maliyeti: ", resource_type)
			return false # Bilinmeyen kaynak isteniyor
		
		var available_level = resource_levels[resource_type] - locked_resource_levels[resource_type]
		if available_level < required_level:
			print("VillageManager: Yetersiz %s seviyesi. Gerekli: %d, Kullanılabilir: %d (Toplam: %d, Kilitli: %d)" % [resource_type, required_level, available_level, resource_levels[resource_type], locked_resource_levels[resource_type]])
			return false # Yeterli kullanılabilir seviye yok
			
	return true # Tüm kaynaklar karşılanabiliyor

# Belirtilen maliyet için kaynak seviyelerini kilitler
# locker_object: Kaynakları kimin kilitlediğini belirtir (örn. yükseltilen bina)
func lock_resources(cost: Dictionary, locker_object) -> bool:
	if not can_afford_and_lock(cost):
		return false # Önce kontrol et

	print("VillageManager: Kaynaklar kilitleniyor: ", cost, " by ", locker_object)
	for resource_type in cost:
		var lock_amount = cost[resource_type]
		locked_resource_levels[resource_type] += lock_amount
		
		# Kilitleyen nesneyi kaydet (gerekirse)
		if not resource_locks.has(resource_type):
			resource_locks[resource_type] = []
		resource_locks[resource_type].append(locker_object)

	emit_signal("village_data_changed") # Kilit durumu değişti, UI güncellenebilir
	return true

# Belirtilen maliyet için kaynak kilitlerini açar
# locker_object: Kaynakları kimin kilitlediğini belirtir
func unlock_resources(cost: Dictionary, locker_object) -> void:
	print("VillageManager: Kaynak kilitleri açılıyor: ", cost, " by ", locker_object)
	for resource_type in cost:
		if locked_resource_levels.has(resource_type) and locked_resource_levels[resource_type] > 0:
			var unlock_amount = cost[resource_type]
			# Kilitli miktar sıfırın altına düşmemeli
			locked_resource_levels[resource_type] = max(0, locked_resource_levels[resource_type] - unlock_amount)

			# Kilitleyen nesneyi listeden çıkar (gerekirse)
			if resource_locks.has(resource_type) and locker_object in resource_locks[resource_type]:
				resource_locks[resource_type].erase(locker_object) # erase() listeden kaldırır
		else:
			printerr("VillageManager: %s kaynağı için kilit açılmaya çalışıldı ama zaten kilitli değil veya bilinmiyor." % resource_type)
			
	emit_signal("village_data_changed") # Kilit durumu değişti, UI güncellenebilir

func _ready() -> void:
	# Oyun başlangıcında boşta işçi sayısını toplam işçi sayısına eşitle
	idle_workers = total_workers
	# Kaynak seviyelerini sıfırla (emin olmak için)
	resource_levels = { "wood": 0, "stone": 0, "food": 0, "water": 0, "metal": 0 }
	locked_resource_levels = { "wood": 0, "stone": 0, "food": 0, "water": 0, "metal": 0 }
	resource_locks = {}

# --- Sinyal (Opsiyonel - UI güncelleme için daha iyi bir yol) ---
# signal village_data_changed 

# --- Yeni Köylü Ekleme Fonksiyonu ---
func add_villager() -> void:
	total_workers += 1
	idle_workers += 1
	print("VillageManager: Yeni köylü eklendi. Toplam: %d, Boşta: %d" % [total_workers, idle_workers])
	emit_signal("village_data_changed") # UI güncellensin

# --- Sinyal ---
signal village_data_changed # UI güncellemesi için
