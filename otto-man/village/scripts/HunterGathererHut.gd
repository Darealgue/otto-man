class_name HunterGathererHut
extends Node2D
#asdasd
# Bu binaya özgü değişkenler
var assigned_workers: int = 0
var max_workers: int = 1 # Şimdilik her kamp 1 işçi alabilsin

# Bu bina için bir işçi atamaya çalışır
func add_worker() -> bool:
	if is_upgrading:
		print("Avcı Kulübesi: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers >= max_workers:
		print("Avcı Kulübesi: Kapasite dolu!")
		return false
	# VillageManager'dan genel bir işçi iste
	if not VillageManager.register_generic_worker():
		return false

	# İşçi başarıyla alındı
	assigned_workers += 1
	print("Avcı Kulübesi: İşçi atandı (%d/%d)" % [assigned_workers, max_workers])
	# VillageManager.register_worker_assignment("food") # KALDIRILDI
	VillageManager.notify_building_state_changed(self)
	return true

# Bu binadan bir işçi çıkarır
func remove_worker() -> bool:
	if is_upgrading:
		print("Avcı Kulübesi: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers <= 0:
		print("Avcı Kulübesi: Çıkarılacak işçi yok!")
		return false

	# İşçiyi genel havuza geri bırak
	VillageManager.unregister_generic_worker()

	assigned_workers -= 1
	print("Avcı Kulübesi: İşçi çıkarıldı (%d/%d)" % [assigned_workers, max_workers])
	# VillageManager.unregister_worker_assignment("food") # KALDIRILDI
	VillageManager.notify_building_state_changed(self)
	return true

# --- Yükseltme Değişkenleri ---
var level: int = 1
var max_level: int = 3 
var is_upgrading: bool = false
var upgrade_duration: float = 4.0 # Örnek süre

# Const defining the upgrade costs for each level
const UPGRADE_COSTS = {
	2: {"gold": 25}, # Cost to upgrade TO level 2
	3: {"gold": 50}  # Cost to upgrade TO level 3
	# Add more levels as needed
}
# Const for max workers per level (Optional)
# const MAX_WORKERS_PER_LEVEL = { 1: 1, 2: 2, 3: 3 }

# --- Zamanlayıcı (Timer) ---
var upgrade_timer: Timer # Tekrar aktif

# --- Sinyaller ---
signal upgrade_started 
signal upgrade_finished 
signal state_changed # Genel durum için

func _init(): # _ready yerine _init'te oluşturmak daha güvenli olabilir
	upgrade_timer = Timer.new()
	upgrade_timer.one_shot = true
	# wait_time _ready'de ayarlanabilir veya sabit kalabilir
	upgrade_timer.timeout.connect(finish_upgrade)
	add_child(upgrade_timer) # Timer'ı node ağacına ekle

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Timer'ın bekleme süresini ayarla
	upgrade_timer.wait_time = upgrade_duration
	# Sprite varsa başlangıç rengini ayarla vb.
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# --- Yeni Yükseltme Fonksiyonları (Timer ile) ---
func get_next_upgrade_cost() -> Dictionary:
	var next_level = level + 1
	return UPGRADE_COSTS.get(next_level, {})

# Yükseltmeyi ANINDA gerçekleştirir (Artık timer yok)
func start_upgrade() -> bool:
	if is_upgrading: # Yükseltme bayrağını tekrar kontrol et
		print("Avcı Kulübesi: Zaten yükseltiliyor.")
		return false
	if level >= max_level:
		print("Avcı Kulübesi: Zaten maksimum seviyede.")
		return false

	var cost_dict = get_next_upgrade_cost()
	if cost_dict.is_empty():
		print("Avcı Kulübesi: Bir sonraki seviye için maliyet tanımlanmamış.")
		return false

	var gold_cost = cost_dict.get("gold", 0)
	# TODO: Diğer kaynak maliyetleri varsa burada kontrol et

	# 1. Maliyet Kontrolü (Altın ve Diğer Kaynaklar)
	if GlobalPlayerData.gold < gold_cost:
		print("Avcı Kulübesi: Yükseltme için yeterli altın yok. Gereken: %d, Mevcut: %d" % [gold_cost, GlobalPlayerData.gold])
		return false
	
	# TODO: Diğer kaynakların kontrolü

	# 2. Maliyeti Düş (Kaynak kilitleme YOK)
	GlobalPlayerData.add_gold(-gold_cost)
	print("Avcı Kulübesi: Yükseltme maliyeti düşüldü: %d Altın" % gold_cost)
	# TODO: Diğer kaynak maliyetlerini düş

	# 3. Yükseltmeyi Başlat
	print("Avcı Kulübesi: Yükseltme başlatıldı (Seviye %d -> %d). Süre: %s sn" % [level, level + 1, upgrade_timer.wait_time])
	is_upgrading = true
	upgrade_timer.start() # Zamanlayıcıyı başlat
	emit_signal("upgrade_started")
	emit_signal("state_changed") # Genel durum değişikliği sinyali
	# Görsel geribildirim (opsiyonel)
	if get_node_or_null("Sprite2D") is Sprite2D: get_node("Sprite2D").modulate = Color.YELLOW

	return true

# finish_upgrade fonksiyonuna artık gerek yok
# func finish_upgrade() -> void: ...
# Zamanlayıcı bittiğinde çağrılır
func finish_upgrade() -> void:
	if not is_upgrading: return # Zaten bitmişse veya hiç başlamadıysa çık

	print("Avcı Kulübesi: Yükseltme tamamlandı (Seviye %d -> %d)" % [level, level + 1])
	is_upgrading = false
	level += 1
	# İsteğe bağlı: Yeni seviyeye göre max_workers güncelle
	# max_workers = MAX_WORKERS_PER_LEVEL.get(level, max_workers)

	emit_signal("upgrade_finished")
	emit_signal("state_changed") # Genel durum değişikliği sinyali
	VillageManager.notify_building_state_changed(self)
	
	# Görsel geribildirimi geri al (opsiyonel)
	if get_node_or_null("Sprite2D") is Sprite2D: get_node("Sprite2D").modulate = Color.WHITE
	print("Avcı Kulübesi: Yeni seviye: %d" % level)
