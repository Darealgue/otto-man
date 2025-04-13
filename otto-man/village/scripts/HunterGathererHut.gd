class_name HunterGathererHut
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
		print("Avcı Kulübesi: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers >= max_workers:
		print("Avcı Kulübesi: Kapasite dolu!")
		return false

	var worker_instance: Node = VillageManager.register_generic_worker()
	if not is_instance_valid(worker_instance):
		return false

	assigned_workers += 1
	assigned_worker_ids.append(worker_instance.worker_id)

	worker_instance.assigned_job_type = "food"
	worker_instance.assigned_building_node = self
	worker_instance.move_target_x = self.global_position.x
	worker_instance.current_state = worker_instance.State.GOING_TO_BUILDING_FIRST

	print("Avcı Kulübesi: İşçi (ID: %d) atandı (%d/%d)." % [
		worker_instance.worker_id, assigned_workers, max_workers
	])
	VillageManager.notify_building_state_changed(self)
	return true

# Bu binadan bir işçi çıkarır
func remove_worker() -> bool:
	if is_upgrading:
		print("Avcı Kulübesi: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers <= 0 or assigned_worker_ids.is_empty():
		print("Avcı Kulübesi: Çıkarılacak işçi yok!")
		return false

	var worker_id_to_remove = assigned_worker_ids.pop_back()
	var worker_instance = VillageManager.active_workers.get(worker_id_to_remove)

	if not is_instance_valid(worker_instance):
		printerr("Avcı Kulübesi: Çıkarılacak işçi (ID: %d) geçersiz!" % worker_id_to_remove)
		assigned_workers = assigned_worker_ids.size()
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
			var remaining_worker_instance = VillageManager.active_workers.get(last_remaining_worker_id)
			if is_instance_valid(remaining_worker_instance):
				if remaining_worker_instance.current_state == remaining_worker_instance.State.WORKING_INSIDE:
					# print("%s RemoveWorker: Only 1 worker left (ID %d), switching from inside to offscreen." % [self.name, last_remaining_worker_id]) #<<< KALDIRILDI
					remaining_worker_instance.switch_to_working_offscreen()
				# else: #<<< KALDIRILDI
				# 	print("%s RemoveWorker: Only 1 worker left (ID %d), already not inside." % [self.name, last_remaining_worker_id]) #<<< KALDIRILDI
			# else: # Hata durumu printerr ile kalsın
			# 	printerr("%s RemoveWorker: Could not find instance for the last remaining worker (ID %d)" % [self.name, last_remaining_worker_id])
		else: # 2 veya daha fazla işçi kaldı
			var new_last_worker_id = assigned_worker_ids[-1]
			var last_worker_instance = VillageManager.active_workers.get(new_last_worker_id)
			if is_instance_valid(last_worker_instance):
				if last_worker_instance.current_state == last_worker_instance.State.WORKING_OFFSCREEN or \
				   last_worker_instance.current_state == last_worker_instance.State.WAITING_OFFSCREEN:
					# print("%s RemoveWorker: Switching new last worker (ID %d) to inside." % [self.name, new_last_worker_id]) #<<< KALDIRILDI
					last_worker_instance.switch_to_working_inside()
				# else: #<<< KALDIRILDI
				# 	print("%s RemoveWorker: New last worker (ID %d) already inside or in other state." % [self.name, new_last_worker_id]) #<<< KALDIRILDI
			# else: # Hata durumu printerr ile kalsın
			# 	printerr("%s RemoveWorker: Could not find instance for new last worker (ID %d)" % [self.name, new_last_worker_id])
	# <<< YENİ KOD BİTİŞİ >>>

	return true # Başarıyla çıkarıldı

# --- Yükseltme Değişkenleri ---
var level: int = 1
var upgrade_duration: float = 4.0 # Örnek süre

# Const defining the upgrade costs for each level
const UPGRADE_COSTS = {
	2: {"gold": 25}, # Cost to upgrade TO level 2
	3: {"gold": 50},  # Cost to upgrade TO level 3
	4: {"gold": 75},  # Cost to upgrade TO level 4
	5: {"gold": 100}  # Cost to upgrade TO level 5
	# Add more levels as needed
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
	print("HunterGathererHut hazır.")
	_update_ui()

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
	max_workers = level #<<< YENİ: Maksimum işçi sayısını seviyeye eşitle
	# İsteğe bağlı: Yeni seviyeye göre max_workers güncelle
	# max_workers = MAX_WORKERS_PER_LEVEL.get(level, max_workers)

	emit_signal("upgrade_finished")
	emit_signal("state_changed") # Genel durum değişikliği sinyali
	VillageManager.notify_building_state_changed(self)
	
	# Görsel geribildirimi geri al (opsiyonel)
	if get_node_or_null("Sprite2D") is Sprite2D: get_node("Sprite2D").modulate = Color.WHITE
	print("Avcı Kulübesi: Yeni seviye: %d" % level)

# --- UI Update ---
func _update_ui() -> void:
	# Implement the logic to update the UI based on the current state of the hut
	pass
