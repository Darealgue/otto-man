class_name Well
extends Node2D
#asdasd
# Bu binaya özgü değişkenler
var assigned_workers: int = 0
var max_workers: int = 1 # Şimdilik her kamp 1 işçi alabilsin
var assigned_worker_ids: Array[int] = [] #<<< YENİ
var is_upgrading: bool = false
var upgrade_timer: Timer = null #<<< YENİDEN EKLENDİ
var upgrade_time_seconds: float = 10.0 # Örnek
@export var max_level: int = 3 # Inspector'dan ayarlanabilir, varsayılan 3

@export var worker_stays_inside: bool = false #<<< YENİ

# Bu bina için bir işçi atamaya çalışır
func add_worker() -> bool:
	if is_upgrading:
		print("Kuyu: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers >= max_workers:
		print("Kuyu: Kapasite dolu!")
		return false

	var worker_instance: Node = VillageManager.register_generic_worker()
	if not is_instance_valid(worker_instance):
		return false

	assigned_workers += 1
	assigned_worker_ids.append(worker_instance.worker_id)

	worker_instance.assigned_job_type = "water"
	worker_instance.assigned_building_node = self
	worker_instance.move_target_x = self.global_position.x
	worker_instance.current_state = worker_instance.State.GOING_TO_BUILDING_FIRST

	print("Kuyu: İşçi (ID: %d) atandı (%d/%d)." % [
		worker_instance.worker_id, assigned_workers, max_workers
	])
	_update_ui()
	VillageManager.notify_building_state_changed(self)
	return true

# Bu binadan bir işçi çıkarır
func remove_worker() -> bool:
	if is_upgrading:
		print("Kuyu: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers <= 0 or assigned_worker_ids.is_empty():
		print("Kuyu: Çıkarılacak işçi yok!")
		return false

	var worker_id_to_remove = assigned_worker_ids.pop_back()
	var worker_instance = null
	if VillageManager.all_workers.has(worker_id_to_remove):
		worker_instance = VillageManager.all_workers[worker_id_to_remove]["instance"]

	if not is_instance_valid(worker_instance):
		printerr("Kuyu: Çıkarılacak işçi (ID: %d) geçersiz!" % worker_id_to_remove)
		assigned_workers = assigned_worker_ids.size()
		_update_ui()
		VillageManager.notify_building_state_changed(self)
		return false
	
	assigned_workers -= 1

	worker_instance.assigned_job_type = ""
	worker_instance.assigned_building_node = null
	worker_instance.move_target_x = worker_instance.global_position.x
	if worker_instance.current_state == worker_instance.State.WORKING_OFFSCREEN or \
	   worker_instance.current_state == worker_instance.State.WAITING_OFFSCREEN or \
	   worker_instance.current_state == worker_instance.State.GOING_TO_BUILDING_FIRST:
		worker_instance.current_state = worker_instance.State.AWAKE_IDLE
		worker_instance.visible = true

	VillageManager.unregister_generic_worker(worker_id_to_remove)

	print("%s: İşçi (ID: %d) çıkarıldı (%d/%d)." % [self.name, worker_id_to_remove, assigned_workers, max_workers])
	emit_signal("worker_removed", worker_id_to_remove)
	VillageManager.notify_building_state_changed(self)

	# <<< YENİ: İşçi çıkarıldıktan sonra SON işçiyi içeri al VEYA TEK işçiyi dışarı çıkar >>>
	if not worker_stays_inside and level >= 2:
		if assigned_worker_ids.is_empty():
			pass
		elif assigned_worker_ids.size() == 1:
			var last_remaining_worker_id = assigned_worker_ids[0]
			var remaining_worker_instance = null
			if VillageManager.all_workers.has(last_remaining_worker_id):
				remaining_worker_instance = VillageManager.all_workers[last_remaining_worker_id]["instance"]
			if is_instance_valid(remaining_worker_instance):
				if remaining_worker_instance.current_state == remaining_worker_instance.State.WORKING_INSIDE:
					remaining_worker_instance.switch_to_working_offscreen()
		else: # 2 veya daha fazla işçi kaldı
			var new_last_worker_id = assigned_worker_ids[-1]
			var last_worker_instance = null
			if VillageManager.all_workers.has(new_last_worker_id):
				last_worker_instance = VillageManager.all_workers[new_last_worker_id]["instance"]
			if is_instance_valid(last_worker_instance):
				if last_worker_instance.current_state == last_worker_instance.State.WORKING_OFFSCREEN or \
				   last_worker_instance.current_state == last_worker_instance.State.WAITING_OFFSCREEN:
					last_worker_instance.switch_to_working_inside()
	# <<< YENİ KOD BİTİŞİ >>>

	return true # Başarıyla çıkarıldı

# --- Yükseltme Değişkenleri ---
var level: int = 1
var upgrade_duration: float = 3.0 # Örnek süre

# Yükseltme maliyetleri: Seviye -> {kaynak: maliyet}
const UPGRADE_COSTS = {
	2: {"gold": 25}, # Seviye 2 için altın maliyeti
	3: {"gold": 50}  # Seviye 3 için altın maliyeti
}
# Const for max workers per level (Optional)
# const MAX_WORKERS_PER_LEVEL = { 1: 1, 2: 2, 3: 3 }

# --- Zamanlayıcı (Timer) ---
func _init(): # _ready yerine _init'te oluşturmak daha güvenli olabilir
	upgrade_timer = Timer.new()
	upgrade_timer.one_shot = true
	# wait_time _ready'de ayarlanabilir veya sabit kalabilir
	upgrade_timer.timeout.connect(finish_upgrade)
	add_child(upgrade_timer) # Timer'ı node ağacına ekle

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Well hazır.")
	_update_ui()

# --- Yeni Yükseltme Fonksiyonları (Timer ile) ---
func get_next_upgrade_cost() -> Dictionary:
	var next_level = level + 1
	return UPGRADE_COSTS.get(next_level, {})

func start_upgrade() -> bool:
	if is_upgrading:
		print("Kuyu: Zaten yükseltiliyor.")
		return false
	if level >= max_level:
		print("Kuyu: Zaten maksimum seviyede.")
		return false

	var cost_dict = get_next_upgrade_cost()
	if cost_dict.is_empty():
		print("Kuyu: Bir sonraki seviye için maliyet tanımlanmamış.")
		return false

	var gold_cost = cost_dict.get("gold", 0)
	# TODO: Diğer kaynak maliyetleri varsa burada kontrol et

	# 1. Maliyet Kontrolü (Altın ve Diğer Kaynaklar)
	if GlobalPlayerData.gold < gold_cost:
		print("Kuyu: Yükseltme için yeterli altın yok. Gereken: %d, Mevcut: %d" % [gold_cost, GlobalPlayerData.gold])
		return false
	
	# TODO: Diğer kaynakların kontrolü

	# 2. Maliyeti Düş (Kaynak kilitleme YOK)
	GlobalPlayerData.add_gold(-gold_cost)
	print("Kuyu: Yükseltme maliyeti düşüldü: %d Altın" % gold_cost)
	# TODO: Diğer kaynak maliyetlerini düş

	# 3. Yükseltmeyi Başlat
	print("Kuyu: Yükseltme başlatıldı (Seviye %d -> %d). Süre: %s sn" % [level, level + 1, upgrade_timer.wait_time])
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
	print("Kuyu: Yükseltme tamamlandı (Seviye %d -> %d)" % [level, level + 1])
	is_upgrading = false
	level += 1
	max_workers = level #<<< YENİ: Maksimum işçi sayısını seviyeye eşitle
	# İsteğe bağlı: Yeni seviyeye göre max_workers güncelle
	# max_workers = MAX_WORKERS_PER_LEVEL.get(level, max_workers)
	
	# Kaynakları serbest bırakmaya gerek yok
	# var cost = UPGRADE_COSTS.get(level, {}) 
	# VillageManager.unlock_resources(cost, self)
	
	emit_signal("upgrade_finished")
	emit_signal("state_changed") # Genel durum değişikliği sinyali
	VillageManager.notify_building_state_changed(self) # YENİ
	
	# Görseli normale döndür
	if get_node_or_null("Sprite2D") is Sprite2D: get_node("Sprite2D").modulate = Color.WHITE
	print("Kuyu: Yeni seviye: %d, Maks İşçi: %d" % [level, max_workers]) # max_workers henüz tanımlı değil!

# --- UI Update ---
func _update_ui() -> void:
	# Implement the logic to update the UI based on the current state of the well
	pass

# --- Sinyaller ---
signal upgrade_started 
signal upgrade_finished 
signal state_changed # Genel durum için
