class_name WoodcutterCamp
extends Node2D

@export var worker_stays_inside: bool = false #<<< YENİ

# Bu binaya özgü değişkenler
@export var level: int = 1
@export var max_workers: int = 1 # Başlangıçta 1 işçi alabilir
@export var assigned_workers: int = 0
var assigned_worker_ids: Array[int] = [] #<<< YENİ: Atanan işçi ID'leri

@export var base_production_rate: float = 1.0 # Seviye başına üretim (opsiyonel)
@export var max_level: int = 3 # Inspector'dan ayarlanabilir, varsayılan 3

# Upgrade değişkenleri
var is_upgrading: bool = false
var upgrade_timer: Timer = null
var upgrade_time_seconds: float = 10.0 # Yükseltme süresi (örnek)

# --- UI Bağlantıları (Eğer varsa) ---
# @onready var worker_label: Label = %WorkerLabel # Gerekirse eklenecek

func _ready() -> void:
	print("WoodcutterCamp hazır.")
	_update_ui()

# --- Worker Management (YENİ) ---
func add_worker() -> bool:
	if assigned_workers >= max_workers:
		print("WoodcutterCamp: Zaten maksimum işçi sayısına ulaşıldı.")
		return false

	# 1. Boşta İşçi Bul ve Kaydet
	var worker_instance: Node = VillageManager.register_generic_worker()
	if not is_instance_valid(worker_instance):
		return false # Hata mesajı VillageManager'dan

	# 2. Başarılı: İşçi Bilgilerini Ayarla ve Kaydet
	assigned_workers += 1
	assigned_worker_ids.append(worker_instance.worker_id) # ID'yi listeye ekle

	# İşçinin hedefini ve durumunu ayarla
	worker_instance.assigned_job_type = "wood"
	worker_instance.assigned_building_node = self
	worker_instance.move_target_x = self.global_position.x
	worker_instance.current_state = worker_instance.State.GOING_TO_BUILDING_FIRST

	print("WoodcutterCamp: İşçi (ID: %d) atandı (%d/%d)." % [
		worker_instance.worker_id, assigned_workers, max_workers
	])
	_update_ui()
	VillageManager.notify_building_state_changed(self) # Sinyal ekle
	return true

func remove_worker() -> bool:
	if assigned_workers <= 0 or assigned_worker_ids.is_empty():
		print("WoodcutterCamp: Çıkarılacak işçi yok.")
		return false

	var worker_id_to_remove = assigned_worker_ids.pop_back()
	var worker_instance = null
	if VillageManager.all_workers.has(worker_id_to_remove):
		worker_instance = VillageManager.all_workers[worker_id_to_remove]["instance"]

	if not is_instance_valid(worker_instance):
		printerr("WoodcutterCamp: Çıkarılacak işçi (ID: %d) VillageManager'da bulunamadı veya geçersiz!" % worker_id_to_remove)
		assigned_workers = assigned_worker_ids.size() # Sayacı listeyle senkronize et
		_update_ui()
		VillageManager.notify_building_state_changed(self)
		return false # Hata durumu
	
	assigned_workers -= 1

	# İşçinin Durumunu Sıfırla
	worker_instance.assigned_job_type = ""
	worker_instance.assigned_building_node = null
	worker_instance.move_target_x = worker_instance.global_position.x
	# Eğer çalışıyorsa veya işe gidiyorsa idle yap
	if worker_instance.current_state == worker_instance.State.WORKING_OFFSCREEN or \
	   worker_instance.current_state == worker_instance.State.WAITING_OFFSCREEN or \
	   worker_instance.current_state == worker_instance.State.GOING_TO_BUILDING_FIRST:
		worker_instance.current_state = worker_instance.State.AWAKE_IDLE
		worker_instance.visible = true

	# İşçiyi VillageManager'dan kaldır
	VillageManager.unregister_generic_worker(worker_id_to_remove)

	print("%s: İşçi (ID: %d) çıkarıldı (%d/%d)." % [self.name, worker_id_to_remove, assigned_workers, max_workers]) # Debug
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

# Yükseltme maliyetleri: Seviye -> {kaynak: maliyet}
const UPGRADE_COSTS = {
	2: {"gold": 20}, # Seviye 2 için altın maliyeti
	3: {"gold": 40}  # Seviye 3 için altın maliyeti
}
# Const for max workers per level (Optional)
# const MAX_WORKERS_PER_LEVEL = { 1: 1, 2: 2, 3: 3 }

# --- Zamanlayıcı (Timer) ---

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
# func _ready() -> void: # <<< BU FONKSİYON BLOKU SİLİNECEK (Duplicate)
# 	# Yükseltme zamanlayıcısını oluştur ve ayarla
# 	# _init'e taşındı
# 	# Timer'ın bekleme süresini ayarla
# 	upgrade_timer.wait_time = upgrade_time_seconds
# 	pass

# --- Yeni Yükseltme Fonksiyonları (Timer ile) ---

# Bir sonraki seviyenin maliyetini döndürür
func get_next_upgrade_cost() -> Dictionary:
	var next_level = level + 1
	return UPGRADE_COSTS.get(next_level, {})

# Yükseltmeyi başlatır (UI tarafından çağrılacak)
func start_upgrade() -> bool:
	if is_upgrading:
		print("Oduncu Kampı: Zaten yükseltiliyor.")
		return false
	if level >= max_level:
		print("Oduncu Kampı: Zaten maksimum seviyede.")
		return false

	var cost_dict = get_next_upgrade_cost()
	if cost_dict.is_empty():
		print("Oduncu Kampı: Bir sonraki seviye için maliyet bulunamadı.")
		return false

	var gold_cost = cost_dict.get("gold", 0)
	# TODO: Diğer kaynak maliyetleri varsa burada kontrol et

	# 1. Maliyet Kontrolü (Altın ve Diğer Kaynaklar)
	if GlobalPlayerData.gold < gold_cost:
		print("Oduncu Kampı: Yükseltme için yeterli altın yok. Gereken: %d, Mevcut: %d" % [gold_cost, GlobalPlayerData.gold])
		return false
	
	# TODO: Diğer kaynakların kontrolü

	# 2. Maliyeti Düş (Kaynak kilitleme YOK)
	GlobalPlayerData.add_gold(-gold_cost)
	print("Oduncu Kampı: Yükseltme maliyeti düşüldü: %d Altın" % gold_cost)
	# TODO: Diğer kaynak maliyetlerini düş

	# 3. Yükseltmeyi Başlat
	print("Oduncu Kampı: Yükseltme başlatıldı (Seviye %d -> %d). Süre: %s sn" % [level, level + 1, upgrade_timer.wait_time])
	is_upgrading = true
	upgrade_timer.start() # Zamanlayıcıyı başlat
	emit_signal("upgrade_started")
	emit_signal("state_changed") # Genel durum değişikliği sinyali
	
	# Görsel olarak yükseltildiğini belirtebiliriz (örn. rengini değiştir)
	if get_node_or_null("Sprite2D") is Sprite2D: # Eğer Sprite2D varsa
		get_node("Sprite2D").modulate = Color.YELLOW

	return true

# Yükseltme tamamlandığında çağrılır (Timer tarafından)
func finish_upgrade() -> void:
	if not is_upgrading: return # Zaten bitmişse veya hiç başlamamışsa bir şey yapma

	print("Oduncu Kampı: Yükseltme tamamlandı (Seviye %d -> %d)" % [level, level + 1])
	is_upgrading = false
	level += 1
	max_workers = level #<<< YENİ: Maksimum işçi sayısını seviyeye eşitle

	# <<< YENİ: İlk işçinin durumunu güncelle >>>
	# <<< BU BLOK KALDIRILIYOR - "SON İŞÇİ İÇERİDE" KURALI İLE GEREKSİZ >>>
	# if level >= 2 and not worker_stays_inside and not assigned_worker_ids.is_empty():
	# 	var first_worker_id = assigned_worker_ids[0]
	# 	var first_worker_instance = VillageManager.active_workers.get(first_worker_id)
	# 	if is_instance_valid(first_worker_instance):
	# 		# Sadece dışarıda çalışan/bekleyen işçinin durumunu değiştir
	# 		if first_worker_instance.current_state == first_worker_instance.State.WORKING_OFFSCREEN or \
	# 		   first_worker_instance.current_state == first_worker_instance.State.WAITING_OFFSCREEN:
	# 			first_worker_instance.switch_to_working_inside()
	# 		else:
	# 			print("WoodcutterCamp Upgrade: First worker (ID %d) not offscreen, state: %s" % [first_worker_id, first_worker_instance.State.keys()[first_worker_instance.current_state]])
	# 	else:
	# 		printerr("WoodcutterCamp Upgrade: Could not find instance for first worker (ID %d)" % first_worker_id)
	# <<< YENİ KOD BİTİŞİ >>>

	# Kaynakları serbest bırakmaya gerek yok, çünkü kilitlemedik
	# var cost = UPGRADE_COSTS.get(level, {})
	
	emit_signal("upgrade_finished") # Sinyali gönder
	emit_signal("state_changed") # Genel durum değişikliği sinyali
	VillageManager.notify_building_state_changed(self) # YENİ

	# Görseli normale döndür
	if get_node_or_null("Sprite2D") is Sprite2D:
		get_node("Sprite2D").modulate = Color.WHITE

	print("Oduncu Kampı: Yeni seviye: %d, Maks İşçi: %d" % [level, max_workers])

# --- UI Update ---
func _update_ui() -> void:
	# UI güncelleme işlemleri burada yapılabilir
	pass
