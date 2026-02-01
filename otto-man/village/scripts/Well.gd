class_name Well
extends Node2D

# Bu binaya özgü değişkenler
var assigned_workers: int = 0
var max_workers: int = 1
var assigned_worker_ids: Array[int] = []
var is_upgrading: bool = false
var upgrade_timer: Timer = null
var upgrade_time_seconds: float = 10.0
@export var max_level: int = 5

@export var worker_stays_inside: bool = false

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
	
	# Mesai saatleri kontrolü: Mesai saatleri dışındaysa beklemeli
	var current_hour = TimeManager.get_hour()
	var is_work_time = current_hour >= TimeManager.WORK_START_HOUR and current_hour < TimeManager.WORK_END_HOUR
	if is_work_time:
		worker_instance.current_state = worker_instance.State.GOING_TO_BUILDING_FIRST
	else:
		# Mesai saatleri dışında, beklemeli (AWAKE_IDLE'da kalır, mesai başlayınca gider)
		worker_instance.current_state = worker_instance.State.AWAKE_IDLE

	print("Kuyu: İşçi (ID: %d) atandı (%d/%d)." % [
		worker_instance.worker_id, assigned_workers, max_workers
	])
	VillageManager.notify_building_state_changed(self)
	return true

# Bu binadan bir işçi çıkarır
func remove_worker() -> bool:
	print("=== WELL REMOVE WORKER DEBUG ===")
	print("Well: remove_worker() çağrıldı")
	
	if is_upgrading:
		print("Kuyu: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers <= 0 or assigned_worker_ids.is_empty():
		print("Kuyu: Çıkarılacak işçi yok!")
		return false

	var worker_id_to_remove = assigned_worker_ids.pop_back()
	print("Well: Çıkarılacak işçi ID: %d" % worker_id_to_remove)
	
	var worker_instance = null
	if VillageManager.all_workers.has(worker_id_to_remove):
		worker_instance = VillageManager.all_workers[worker_id_to_remove]["instance"]
		print("Well: İşçi instance bulundu: %s" % worker_instance)
	else:
		print("Well: İşçi VillageManager'da bulunamadı!")

	if not is_instance_valid(worker_instance):
		printerr("Kuyu: Çıkarılacak işçi (ID: %d) geçersiz!" % worker_id_to_remove)
		assigned_workers = assigned_worker_ids.size()
		VillageManager.notify_building_state_changed(self)
		return false
	
	print("Well: İşçi %d durumu - Job: '%s', Visible: %s, State: %s, Pos: %s" % [
		worker_id_to_remove,
		worker_instance.assigned_job_type,
		worker_instance.visible,
		worker_instance.State.keys()[worker_instance.current_state] if worker_instance.current_state >= 0 else "INVALID",
		worker_instance.global_position
	])
	
	assigned_workers -= 1

	worker_instance.assigned_job_type = ""
	worker_instance.assigned_building_node = null
	worker_instance.move_target_x = worker_instance.global_position.x
	
	print("Well: İşçi %d job ve building referansı temizlendi" % worker_id_to_remove)
	
	if worker_instance.current_state == worker_instance.State.WORKING_OFFSCREEN or \
	   worker_instance.current_state == worker_instance.State.WAITING_OFFSCREEN or \
	   worker_instance.current_state == worker_instance.State.GOING_TO_BUILDING_FIRST:
		print("Well: İşçi %d state değiştiriliyor: %s -> AWAKE_IDLE" % [
			worker_id_to_remove,
			worker_instance.State.keys()[worker_instance.current_state] if worker_instance.current_state >= 0 else "INVALID"
		])
		worker_instance.current_state = worker_instance.State.AWAKE_IDLE
		worker_instance.visible = true
		print("Well: İşçi %d visible=true yapıldı" % worker_id_to_remove)
	else:
		print("Well: İşçi %d state değiştirilmedi: %s" % [
			worker_id_to_remove,
			worker_instance.State.keys()[worker_instance.current_state] if worker_instance.current_state >= 0 else "INVALID"
		])

	# VillageManager.unregister_generic_worker(worker_id_to_remove) # MissionCenter.gd'de çağrılıyor

	print("Well: İşçi %d son durumu - Job: '%s', Visible: %s, State: %s, Pos: %s, Parent: %s" % [
		worker_id_to_remove,
		worker_instance.assigned_job_type,
		worker_instance.visible,
		worker_instance.State.keys()[worker_instance.current_state] if worker_instance.current_state >= 0 else "INVALID",
		worker_instance.global_position,
		worker_instance.get_parent()
	])
	
	print("%s: İşçi (ID: %d) çıkarıldı (%d/%d)." % [self.name, worker_id_to_remove, assigned_workers, max_workers])
	emit_signal("worker_removed", worker_id_to_remove)
	VillageManager.notify_building_state_changed(self)

	print("=== WELL REMOVE WORKER DEBUG BİTTİ ===")
	return true

# --- Yükseltme Değişkenleri ---
var level: int = 1
var upgrade_duration: float = 4.0

# Const defining the upgrade costs for each level
const UPGRADE_COSTS = {
	2: {"gold": 25},
	3: {"gold": 50},
	4: {"gold": 75},
	5: {"gold": 100}
}

# --- Zamanlayıcı (Timer) ---
func _init():
	upgrade_timer = Timer.new()
	upgrade_timer.one_shot = true
	upgrade_timer.timeout.connect(finish_upgrade)
	add_child(upgrade_timer)

func _ready() -> void:
	print("Well hazır.")
	_update_texture()
	_update_ui()

func _process(delta: float) -> void:
	pass

# Basit üretim bilgisini döndürür (UI için)
func get_production_info() -> String:
	var per_worker: float = 1.0
	# Seviyeye bağlı kapasite bilgisi: işçi sayısı üretimi etkiler
	var workers: int = assigned_workers if "assigned_workers" in self else 0
	var level_info := "Lv." + str(level) if "level" in self else "Lv.?"
	return level_info + " • İşçi:" + str(workers) + " • Su üretimi: " + str(workers) + "/tick"

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

	if GlobalPlayerData.gold < gold_cost:
		print("Kuyu: Yükseltme için yeterli altın yok. Gereken: %d, Mevcut: %d" % [gold_cost, GlobalPlayerData.gold])
		return false

	GlobalPlayerData.add_gold(-gold_cost)
	print("Kuyu: Yükseltme maliyeti düşüldü: %d Altın" % gold_cost)

	print("Kuyu: Yükseltme başlatıldı (Seviye %d -> %d). Süre: %s sn" % [level, level + 1, upgrade_time_seconds])
	is_upgrading = true
	if upgrade_timer:
		upgrade_timer.wait_time = upgrade_time_seconds
		upgrade_timer.start()
	emit_signal("upgrade_started")
	emit_signal("state_changed")
	if get_node_or_null("Sprite2D") is Sprite2D: get_node("Sprite2D").modulate = Color.YELLOW

	return true

func finish_upgrade() -> void:
	if not is_upgrading: return

	print("Kuyu: Yükseltme tamamlandı (Seviye %d -> %d)" % [level, level + 1])
	is_upgrading = false
	level += 1
	max_workers = level

	emit_signal("upgrade_finished")
	emit_signal("state_changed")
	VillageManager.notify_building_state_changed(self)
	
	if get_node_or_null("Sprite2D") is Sprite2D: get_node("Sprite2D").modulate = Color.WHITE
	
	# Texture'ı güncelle
	_update_texture()
	
	print("Kuyu: Yeni seviye: %d" % level)

# --- Texture Update ---
func _update_texture() -> void:
	print("Well: _update_texture() çağrıldı - Seviye: ", level)
	
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		print("Well: Sprite2D bulunamadı!")
		return
	
	print("Well: Sprite2D bulundu, texture güncelleniyor...")
	
	# Seviyeye göre texture yolu belirle
	var texture_path = ""
	match level:
		1: texture_path = "res://village/buildings/sprite/well1.png"
		2: texture_path = "res://village/buildings/sprite/well2.png"
		3: texture_path = "res://village/buildings/sprite/well3.png"
		4: texture_path = "res://village/buildings/sprite/well4.png"
		5: texture_path = "res://village/buildings/sprite/well5.png"
		_: 
			print("Well: Geçersiz seviye: ", level, " - Varsayılan olarak seviye 1 kullanılıyor")
			texture_path = "res://village/buildings/sprite/well1.png"
	
	print("Well: Texture yolu: ", texture_path)
	
	# Texture'ı yükle ve uygula
	if ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		if texture:
			sprite.texture = texture
			# Texture boyutunu ayarla (gerekirse)
			sprite.scale = Vector2(1.0, 1.0)
			# Texture'ı doğru pozisyona ayarla (alt kenara hizala)
			sprite.offset = Vector2(0, -texture.get_height() / 2)
			print("Well: ✅ Texture başarıyla güncellendi - Seviye ", level, " (", texture_path, ")")
		else:
			print("Well: ❌ Texture yüklenemedi: ", texture_path)
	else:
		print("Well: ❌ Texture dosyası bulunamadı: ", texture_path)

func _update_ui() -> void:
	pass
