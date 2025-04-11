class_name StoneMine
extends Node2D

# --- Mevcut Değişkenler ---
var assigned_workers: int = 0

# --- Yükseltme Değişkenleri ---
var level: int = 1
var max_level: int = 3
var is_upgrading: bool = false
var upgrade_duration: float = 6.0 # Örnek süre

# Yükseltme maliyetleri: Seviye -> {kaynak: maliyet}
const UPGRADE_COSTS = {
	2: {"gold": 30}, # Seviye 2 için altın maliyeti
	3: {"gold": 60}  # Seviye 3 için altın maliyeti
}
# Const for max workers per level (Optional)
# const MAX_WORKERS_PER_LEVEL = { 1: 1, 2: 2, 3: 3 }

# --- Hesaplanan Değişken ---
var max_workers: int:
	get: return level

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

func _ready() -> void:
	# Timer'ın bekleme süresini ayarla
	upgrade_timer.wait_time = upgrade_duration
	pass

# --- Mevcut Fonksiyonlar ---
func add_worker() -> bool:
	if is_upgrading:
		print("Taş Madeni: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers >= max_workers:
		print("Taş Madeni: Kapasite dolu!")
		return false
	if not VillageManager.register_generic_worker():
		return false

	assigned_workers += 1
	print("Taş Madeni: İşçi atandı (%d/%d)" % [assigned_workers, max_workers])
	VillageManager.notify_building_state_changed(self)
	return true

func remove_worker() -> bool:
	if is_upgrading:
		print("Taş Madeni: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers <= 0:
		print("Taş Madeni: Çıkarılacak işçi yok!")
		return false

	VillageManager.unregister_generic_worker()

	assigned_workers -= 1
	print("Taş Madeni: İşçi çıkarıldı (%d/%d)" % [assigned_workers, max_workers])
	VillageManager.notify_building_state_changed(self)
	return true

# --- Yeni Yükseltme Fonksiyonları (Timer ile) ---
func get_next_upgrade_cost() -> Dictionary:
	var next_level = level + 1
	return UPGRADE_COSTS.get(next_level, {})

func start_upgrade() -> bool:
	if is_upgrading:
		print("Taş Madeni: Zaten yükseltiliyor.")
		return false
	if level >= max_level:
		print("Taş Madeni: Zaten maksimum seviyede.")
		return false

	var cost_dict = get_next_upgrade_cost()
	if cost_dict.is_empty():
		print("Taş Madeni: Bir sonraki seviye için maliyet tanımlanmamış.")
		return false

	var gold_cost = cost_dict.get("gold", 0)
	# TODO: Diğer kaynak maliyetleri varsa burada kontrol et

	# 1. Maliyet Kontrolü (Altın ve Diğer Kaynaklar)
	if GlobalPlayerData.gold < gold_cost:
		print("Taş Madeni: Yükseltme için yeterli altın yok. Gereken: %d, Mevcut: %d" % [gold_cost, GlobalPlayerData.gold])
		return false
	
	# TODO: Diğer kaynakların kontrolü

	# 2. Maliyeti Düş (Kaynak kilitleme YOK)
	GlobalPlayerData.add_gold(-gold_cost)
	print("Taş Madeni: Yükseltme maliyeti düşüldü: %d Altın" % gold_cost)
	# TODO: Diğer kaynak maliyetlerini düş

	# 3. Yükseltmeyi Başlat
	print("Taş Madeni: Yükseltme başlatıldı (Seviye %d -> %d). Süre: %s sn" % [level, level + 1, upgrade_timer.wait_time])
	is_upgrading = true
	upgrade_timer.start() # Zamanlayıcıyı başlat
	emit_signal("upgrade_started")
	emit_signal("state_changed") # Genel durum değişikliği sinyali
	
	# Görsel geribildirim (opsiyonel)
	if get_node_or_null("Sprite2D") is Sprite2D: get_node("Sprite2D").modulate = Color.YELLOW
	
	return true

# Zamanlayıcı bittiğinde çağrılır
func finish_upgrade() -> void:
	if not is_upgrading: return
	print("Taş Madeni: Yükseltme tamamlandı (Seviye %d -> %d)" % [level, level + 1])
	is_upgrading = false
	level += 1
	# max_workers otomatik olarak güncellenir
	
	# Kaynakları serbest bırakmaya gerek yok
	# var cost = UPGRADE_COSTS.get(level, {})
	# VillageManager.unlock_resources(cost, self)
	
	emit_signal("upgrade_finished")
	emit_signal("state_changed") # Genel durum değişikliği sinyali
	VillageManager.notify_building_state_changed(self)
	
	# Görseli normale döndür
	if get_node_or_null("Sprite2D") is Sprite2D: get_node("Sprite2D").modulate = Color.WHITE
	print("Taş Madeni: Yeni seviye: %d, Maks İşçi: %d" % [level, max_workers])
