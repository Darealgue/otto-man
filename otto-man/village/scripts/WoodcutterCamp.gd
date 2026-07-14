class_name WoodcutterCamp
extends Node2D

const CollisionLayers = preload("res://resources/CollisionLayers.gd")

# Görsel tier: 1→col1, 2→col2, 3→col2+col3, 4+→col2+col3
const COLLISION_BY_VISUAL_TIER: Dictionary = {
	1: ["CollisionLevel1"],
	2: ["CollisionLevel2"],
	3: ["CollisionLevel2", "CollisionLevel3"],
	4: ["CollisionLevel2", "CollisionLevel3"],
}

@export var worker_stays_inside: bool = false #<<< YENİ

# Bu binaya özgü değişkenler
@export var level: int = 1
@export var max_workers: int = 1 # Başlangıçta 1 işçi alabilir
@export var assigned_workers: int = 0
var assigned_worker_ids: Array[int] = [] #<<< YENİ: Atanan işçi ID'leri

@export var base_production_rate: float = 1.0 # Seviye başına üretim (opsiyonel)
@export var max_level: int = 8
var _collision_original_positions: Dictionary = {}

# Upgrade değişkenleri
var is_upgrading: bool = false
var upgrade_timer: Timer = null
var upgrade_time_seconds: float = 10.0 # Yükseltme süresi (örnek)

# --- UI Bağlantıları (Eğer varsa) ---
# @onready var worker_label: Label = %WorkerLabel # Gerekirse eklenecek

func _ready() -> void:
	print("WoodcutterCamp hazır - Seviye: ", level)
	if level <= 0:
		level = 1
		print("WoodcutterCamp: Level 1'e ayarlandı")
	if not scene_file_path.is_empty():
		max_level = BuildingUpgradeConfig.get_max_level(scene_file_path)
	_store_collision_original_positions()
	_setup_platform_collision()
	_update_texture()
	call_deferred("_update_collision")
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
	if VillageManager.has_method("ensure_basic_gather_expedition_for_worker"):
		VillageManager.ensure_basic_gather_expedition_for_worker(worker_instance.worker_id)
	
	# Mesai saatleri kontrolü: Mesai saatleri dışındaysa beklemeli
	if worker_instance.should_start_shift_on_assignment():
		worker_instance.current_state = worker_instance.State.GOING_TO_BUILDING_FIRST
	else:
		# Mesai saatleri dışında ya da bugün vardiyaya zaten başladıysa, beklemeli
		worker_instance.current_state = worker_instance.State.AWAKE_IDLE

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
	if VillageManager.has_method("clear_basic_gather_expedition_for_worker"):
		VillageManager.clear_basic_gather_expedition_for_worker(worker_id_to_remove)
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

	# Bina bağlantısı hâlâ geçerliyken unregister et (idle_workers++) — alanları SONRA temizle,
	# yoksa VillageManager işçinin zaten boşta olduğunu sanıp sayacı artırmaz.
	VillageManager.unregister_generic_worker(worker_id_to_remove)

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

	#print("%s: İşçi (ID: %d) çıkarıldı (%d/%d)." % [self.name, worker_id_to_remove, assigned_workers, max_workers]) # Debug
	emit_signal("worker_removed", worker_id_to_remove)
	VillageManager.notify_building_state_changed(self)

	return true # Başarıyla çıkarıldı

# --- Yükseltme Değişkenleri ---

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
	return BuildingUpgradeMixin.get_next_cost(self)

func start_upgrade() -> bool:
	if not BuildingUpgradeMixin.start(self):
		return false
	if get_node_or_null("Sprite2D") is Sprite2D:
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

	# Görseli normale döndür ve texture'ı güncelle
	if get_node_or_null("Sprite2D") is Sprite2D:
		get_node("Sprite2D").modulate = Color.WHITE
	
	_update_texture()
	_update_collision()
	print("Oduncu Kampı: Yeni seviye: %d, Maks İşçi: %d" % [level, max_workers])

# --- Texture Update ---
func _update_texture() -> void:
	print("WoodcutterCamp: _update_texture() çağrıldı - Seviye: ", level)
	
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		print("WoodcutterCamp: Sprite2D bulunamadı!")
		return
	
	print("WoodcutterCamp: Sprite2D bulundu, texture güncelleniyor...")
	
	var texture_path := BuildingUpgradeConfig.gather_sprite_path("wood", level)
	
	print("WoodcutterCamp: Texture yolu: ", texture_path)
	
	# Texture'ı yükle ve uygula
	if ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		if texture:
			sprite.texture = texture
			# Texture boyutunu ayarla (gerekirse)
			sprite.scale = Vector2(1.0, 1.0)
			# Texture'ı doğru pozisyona ayarla (alt kenara hizala)
			sprite.offset = Vector2(0, -texture.get_height() / 2)
			print("WoodcutterCamp: ✅ Texture başarıyla güncellendi - Seviye ", level, " (", texture_path, ")")
		else:
			print("WoodcutterCamp: ❌ Texture yüklenemedi: ", texture_path)
	else:
		print("WoodcutterCamp: ❌ Texture dosyası bulunamadı: ", texture_path)

# --- Collision (Well ile aynı mantık: PLATFORM layer, one-way, sprite offset uyumu) ---
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
	var visual_tier := mini(BuildingUpgradeConfig.gather_visual_tier(level), 4)
	var names_to_enable: Array = COLLISION_BY_VISUAL_TIER.get(visual_tier, ["CollisionLevel1"])
	for child in body.get_children():
		if child is CollisionShape2D and child.name.begins_with("CollisionLevel"):
			child.disabled = true
	for node_name in names_to_enable:
		var col = body.get_node_or_null(node_name)
		if col is CollisionShape2D:
			col.disabled = false

# --- UI Update ---
func _update_ui() -> void:
	# UI güncelleme işlemleri burada yapılabilir
	pass

# Basit üretim bilgisini döndürür (UI için)
func get_production_info() -> String:
	var workers: int = assigned_workers if "assigned_workers" in self else 0
	var level_info := "Lv." + str(level)
	return level_info + " • İşçi:" + str(workers) + " • Odun üretimi: " + str(workers) + "/tick"
