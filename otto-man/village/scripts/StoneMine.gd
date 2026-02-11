class_name StoneMine
extends Node2D

const CollisionLayers = preload("res://resources/CollisionLayers.gd")

# Tüm seviyeler için sadece CollisionLevel1 aktif
const COLLISION_NAMES_BY_LEVEL: Dictionary = {
	1: ["CollisionLevel1"],
	2: ["CollisionLevel1"],
	3: ["CollisionLevel1"],
	4: ["CollisionLevel1"]
}

@export var worker_stays_inside: bool = false

# --- Mevcut Değişkenler ---
@export var level: int = 1
@export var max_workers: int = 1
@export var assigned_workers: int = 0
var assigned_worker_ids: Array[int] = []
var is_upgrading: bool = false
var upgrade_timer: Timer = null
var upgrade_time_seconds: float = 10.0
@export var max_level: int = 4
var _collision_original_positions: Dictionary = {}

# Yükseltme maliyetleri (4 seviye)
const UPGRADE_COSTS = {
	2: {"gold": 30},
	3: {"gold": 60},
	4: {"gold": 100}
}
# Const for max workers per level (Optional)
# const MAX_WORKERS_PER_LEVEL = { 1: 1, 2: 2, 3: 3 }

# --- Hesaplanan Değişken ---
var max_workers_per_level: int:
	get: return level

# --- Zamanlayıcı (Timer) ---
# var upgrade_timer: Timer = null #<<< YUKARIDA ZATEN TANIMLI, BU SİLİNECEK

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
	print("StoneMine hazır.")
	_store_collision_original_positions()
	_setup_platform_collision()
	_update_texture()
	call_deferred("_update_collision")
	_update_ui()

# --- Worker Management (YENİ) ---
func add_worker() -> bool:
	if is_upgrading:
		print("StoneMine: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers >= max_workers:
		print("StoneMine: Zaten maksimum işçi sayısına ulaşıldı.")
		return false

	var worker_instance: Node = VillageManager.register_generic_worker()
	if not is_instance_valid(worker_instance):
		return false

	assigned_workers += 1
	assigned_worker_ids.append(worker_instance.worker_id)

	worker_instance.assigned_job_type = "stone"
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

	print("StoneMine: İşçi (ID: %d) atandı (%d/%d)." % [
		worker_instance.worker_id, assigned_workers, max_workers
	])
	_update_ui()
	VillageManager.notify_building_state_changed(self)
	return true

func remove_worker() -> bool:
	if is_upgrading:
		print("StoneMine: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers <= 0 or assigned_worker_ids.is_empty():
		print("StoneMine: Çıkarılacak işçi yok.")
		return false

	var worker_id_to_remove = assigned_worker_ids.pop_back()
	var worker_instance = null
	if VillageManager.all_workers.has(worker_id_to_remove):
		worker_instance = VillageManager.all_workers[worker_id_to_remove]["instance"]

	if not is_instance_valid(worker_instance):
		printerr("StoneMine: Çıkarılacak işçi (ID: %d) geçersiz!" % worker_id_to_remove)
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

	# VillageManager.unregister_generic_worker(worker_id_to_remove) # MissionCenter.gd'de çağrılıyor

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
	if upgrade_timer:
		upgrade_timer.wait_time = upgrade_time_seconds
		upgrade_timer.start()
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
	max_workers = level #<<< YENİ: Maksimum işçi sayısını seviyeye eşitle
	
	# Kaynakları serbest bırakmaya gerek yok
	# var cost = UPGRADE_COSTS.get(level, {})
	# VillageManager.unlock_resources(cost, self)
	
	emit_signal("upgrade_finished")
	emit_signal("state_changed") # Genel durum değişikliği sinyali
	VillageManager.notify_building_state_changed(self)
	
	if get_node_or_null("Sprite2D") is Sprite2D: get_node("Sprite2D").modulate = Color.WHITE
	_update_texture()
	_update_collision()
	print("Taş Madeni: Yeni seviye: %d, Maks İşçi: %d" % [level, max_workers])

# --- Texture (stone1..stone4) ---
func _update_texture() -> void:
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		return
	var texture_path = ""
	match level:
		1: texture_path = "res://village/buildings/sprite/stone1.png"
		2: texture_path = "res://village/buildings/sprite/stone2.png"
		3: texture_path = "res://village/buildings/sprite/stone3.png"
		4: texture_path = "res://village/buildings/sprite/stone4.png"
		_: texture_path = "res://village/buildings/sprite/stone1.png"
	if ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		if texture:
			sprite.texture = texture
			sprite.scale = Vector2(1.0, 1.0)
			sprite.offset = Vector2(0, -texture.get_height() / 2)

# --- Collision (Well/WoodcutterCamp ile aynı mantık) ---
func _store_collision_original_positions() -> void:
	if not _collision_original_positions.is_empty():
		return
	var body = get_node_or_null("StaticBody2D")
	if not body:
		return
	for child in body.get_children():
		if child is CollisionShape2D and child.name.begins_with("CollisionLevel"):
			_collision_original_positions[child.name] = child.position

func _apply_collision_sprite_offset() -> void:
	var sprite = get_node_or_null("Sprite2D")
	var body = get_node_or_null("StaticBody2D")
	if not sprite or not body or _collision_original_positions.is_empty():
		return
	var offset_y: float = sprite.offset.y if sprite.texture else 0.0
	for child in body.get_children():
		if child is CollisionShape2D and child.name.begins_with("CollisionLevel"):
			var orig: Vector2 = _collision_original_positions.get(child.name, child.position)
			child.position = orig + Vector2(0, offset_y)

func _setup_platform_collision() -> void:
	var body = get_node_or_null("StaticBody2D")
	if not body is StaticBody2D:
		return
	body.collision_layer = CollisionLayers.PLATFORM
	body.collision_mask = CollisionLayers.NONE
	body.add_to_group("one_way_platforms")
	for child in body.get_children():
		if child is CollisionShape2D:
			child.one_way_collision = true
			child.one_way_collision_margin = 12.0

func _update_collision() -> void:
	var body = get_node_or_null("StaticBody2D")
	if not body:
		return
	_apply_collision_sprite_offset()
	var names_to_enable: Array = COLLISION_NAMES_BY_LEVEL.get(level, ["CollisionLevel1"])
	for child in body.get_children():
		if child is CollisionShape2D and child.name.begins_with("CollisionLevel"):
			child.disabled = true
	for node_name in names_to_enable:
		var col = body.get_node_or_null(node_name)
		if col is CollisionShape2D:
			col.disabled = false

# --- UI Update ---
func _update_ui() -> void:
	# Bu fonksiyon, UI'yi güncellemek için kullanılabilir.
	# Örneğin, bir UI elementini güncellemek için kullanılabilir.
	pass

# Basit üretim bilgisini döndürür (UI için)
func get_production_info() -> String:
	var workers: int = assigned_workers if "assigned_workers" in self else 0
	var level_info := "Lv." + str(level)
	return level_info + " • İşçi:" + str(workers) + " • Taş üretimi: " + str(workers) + "/tick"
