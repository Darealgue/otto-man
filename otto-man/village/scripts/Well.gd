class_name Well
extends Node2D

const CollisionLayers = preload("res://resources/CollisionLayers.gd")

# Seviyeye göre collision: 1→sadece 1, 2→sadece 2, 3→2+3, 4→2+3+4 (alt katlar açık kalır)
const COLLISION_NAMES_BY_LEVEL: Dictionary = {
	1: ["CollisionLevel1"],
	2: ["CollisionLevel2"],
	3: ["CollisionLevel2", "CollisionLevel3"],
	4: ["CollisionLevel2", "CollisionLevel3", "CollisionLevel4"]
}

# Bu binaya özgü değişkenler
var assigned_workers: int = 0
var max_workers: int = 1
var assigned_worker_ids: Array[int] = []
var is_upgrading: bool = false
var upgrade_timer: Timer = null
var upgrade_time_seconds: float = 10.0
@export var max_level: int = 4

# Test için: true yaparsan one-way kapatılır (çift yönlü collision). Çalışıyorsa segment a/b yönünü ters çevirmen gerekir.
@export var collision_debug_twoway: bool = false

# Inspector'da true yap: collision kurulumu ve periyodik durum Output'a yazılır
@export var debug_collision: bool = false
var _debug_collision_timer: float = 0.0

# Editörde ayarladığın collision konumları (sprite offset uygulanmadan önce); script bunları saklayıp sadece sprite ile aynı dikey kaymayı ekler
var _collision_original_positions: Dictionary = {}

@export var worker_stays_inside: bool = false

# Bu bina için bir işçi atamaya çalışır
func add_worker() -> bool:
	if is_upgrading:
		return false
	if assigned_workers >= max_workers:
		return false

	var worker_instance: Node = VillageManager.register_generic_worker()
	if not is_instance_valid(worker_instance):
		return false

	assigned_workers += 1
	assigned_worker_ids.append(worker_instance.worker_id)

	worker_instance.assigned_job_type = "water"
	worker_instance.assigned_building_node = self
	worker_instance.move_target_x = self.global_position.x + worker_instance._building_arrival_x_offset(self)
	if VillageManager.has_method("ensure_basic_gather_expedition_for_worker"):
		VillageManager.ensure_basic_gather_expedition_for_worker(worker_instance.worker_id)
	
	# Mesai saatleri kontrolü: Mesai saatleri dışındaysa beklemeli
	if worker_instance.should_start_shift_on_assignment():
		worker_instance.current_state = worker_instance.State.GOING_TO_BUILDING_FIRST
	else:
		# Mesai saatleri dışında ya da bugün vardiyaya zaten başladıysa, beklemeli
		worker_instance.current_state = worker_instance.State.AWAKE_IDLE

	VillageManager.notify_building_state_changed(self)
	return true

# Bu binadan bir işçi çıkarır
func remove_worker() -> bool:
	
	if is_upgrading:
		return false
	if assigned_workers <= 0 or assigned_worker_ids.is_empty():
		print("Kuyu: Çıkarılacak işçi yok!")
		return false

	var worker_id_to_remove = assigned_worker_ids.pop_back()
	if VillageManager.has_method("clear_basic_gather_expedition_for_worker"):
		VillageManager.clear_basic_gather_expedition_for_worker(worker_id_to_remove)
	
	var worker_instance = null
	if VillageManager.all_workers.has(worker_id_to_remove):
		worker_instance = VillageManager.all_workers[worker_id_to_remove]["instance"]
	else:
		print("Well: İşçi VillageManager'da bulunamadı!")

	if not is_instance_valid(worker_instance):
		printerr("Kuyu: Çıkarılacak işçi (ID: %d) geçersiz!" % worker_id_to_remove)
		assigned_workers = assigned_worker_ids.size()
		VillageManager.notify_building_state_changed(self)
		return false
	
	
	assigned_workers -= 1

	# Bina bağlantısı hâlâ geçerliyken unregister et (idle_workers++) — alanları SONRA temizle,
	# yoksa VillageManager işçinin zaten boşta olduğunu sanıp sayacı artırmaz.
	VillageManager.unregister_generic_worker(worker_id_to_remove)

	worker_instance.assigned_job_type = ""
	worker_instance.assigned_building_node = null
	worker_instance.move_target_x = worker_instance.global_position.x

	
	if worker_instance.current_state == worker_instance.State.WORKING_OFFSCREEN or \
	   worker_instance.current_state == worker_instance.State.WAITING_OFFSCREEN or \
	   worker_instance.current_state == worker_instance.State.GOING_TO_BUILDING_FIRST:
		worker_instance.current_state = worker_instance.State.AWAKE_IDLE
		worker_instance.visible = true
	else:
		pass

	# VillageManager.unregister_generic_worker(worker_id_to_remove) # MissionCenter.gd'de çağrılıyor

	
	emit_signal("worker_removed", worker_id_to_remove)
	VillageManager.notify_building_state_changed(self)

	return true

# --- Yükseltme Değişkenleri ---
var level: int = 1
var upgrade_duration: float = 4.0

# --- Zamanlayıcı (Timer) ---
func _init():
	upgrade_timer = Timer.new()
	upgrade_timer.one_shot = true
	upgrade_timer.timeout.connect(finish_upgrade)
	add_child(upgrade_timer)

const WATER_INTERACTABLE_SCRIPT = preload("res://village/scripts/VillageWellInteractable.gd")

func _ready() -> void:
	_store_collision_original_positions()
	_setup_platform_collision()
	_update_texture()
	_setup_water_interactable()
	# Collision'ı bir frame ertede uygula; physics tam hazır olsun (özellikle runtime'da eklenen binalar için)
	call_deferred("_update_collision")
	_update_ui()

# Günlük su çekme oyunu (+1 moral): kuyunun zemin hizasına bir etkileşim alanı ekler (bkz. VillageWellInteractable.gd).
func _setup_water_interactable() -> void:
	if get_node_or_null("WaterInteractable") != null:
		return
	var area := Area2D.new()
	area.name = "WaterInteractable"
	area.set_script(WATER_INTERACTABLE_SCRIPT)
	area.collision_layer = 4096
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(160, 150)
	shape.shape = rect
	shape.position = Vector2(0, -75)
	area.add_child(shape)
	add_child(area)

func _process(delta: float) -> void:
	if debug_collision:
		_debug_collision_timer += delta
		if _debug_collision_timer >= 2.0:
			_debug_collision_timer = 0.0
			_print_collision_debug()

# Basit üretim bilgisini döndürür (UI için)
func get_production_info() -> String:
	var per_worker: float = 1.0
	# Seviyeye bağlı kapasite bilgisi: işçi sayısı üretimi etkiler
	var workers: int = assigned_workers if "assigned_workers" in self else 0
	var level_info := "Lv." + str(level) if "level" in self else "Lv.?"
	return level_info + tr("building.well.production_info") % [workers, workers]

func get_next_upgrade_cost() -> Dictionary:
	return BuildingUpgradeMixin.get_next_cost(self)

func start_upgrade() -> bool:
	if not BuildingUpgradeMixin.start(self):
		return false
	if get_node_or_null("Sprite2D") is Sprite2D:
		get_node("Sprite2D").modulate = Color.YELLOW
	return true

func finish_upgrade() -> void:
	if not is_upgrading: return

	is_upgrading = false
	level += 1
	max_workers = level

	emit_signal("upgrade_finished")
	emit_signal("state_changed")
	VillageManager.notify_building_state_changed(self)
	
	if get_node_or_null("Sprite2D") is Sprite2D: get_node("Sprite2D").modulate = Color.WHITE
	
	# Texture ve seviyeye göre collision'ı güncelle
	_update_texture()
	_update_collision()

# --- Texture Update ---
func _update_texture() -> void:
	
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		print("Well: Sprite2D bulunamadı!")
		return
	
	
	# Seviyeye göre texture yolu belirle (3 seviye)
	var texture_path = ""
	match level:
		1: texture_path = "res://village/buildings/sprite/well1.png"
		2: texture_path = "res://village/buildings/sprite/well2.png"
		3: texture_path = "res://village/buildings/sprite/well3.png"
		4: texture_path = "res://village/buildings/sprite/well4.png"
		_:
			texture_path = "res://village/buildings/sprite/well1.png"
	
	
	# Texture'ı yükle ve uygula
	if ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		if texture:
			sprite.texture = texture
			# Texture boyutunu ayarla (gerekirse)
			sprite.scale = Vector2(1.0, 1.0)
			# Texture'ı doğru pozisyona ayarla (alt kenara hizala)
			sprite.offset = Vector2(0, -texture.get_height() / 2)
		else:
			pass
	else:
		print("Well: ❌ Texture dosyası bulunamadı: ", texture_path)

# Sadece PLATFORM (layer 10) kullan: böylece oyuncu "aşağı + zıplama" ile platformdan inebilir
# (drop_through_platform() layer 10 maskesini kapatır; WORLD olsaydı inemezdi)
func _setup_platform_collision() -> void:
	var body = get_node_or_null("StaticBody2D")
	if not body is StaticBody2D:
		if debug_collision:
			print("[Well DEBUG] StaticBody2D bulunamadı!")
		return
	body.collision_layer = CollisionLayers.PLATFORM
	body.collision_mask = CollisionLayers.NONE
	body.add_to_group("one_way_platforms")
	var count := 0
	for child in body.get_children():
		if child is CollisionShape2D:
			child.one_way_collision = !collision_debug_twoway
			child.one_way_collision_margin = 12.0
			count += 1
	# Her zaman kısa özet (kuyu runtime'da eklendiğinde Inspector'da debug açılamaz)
	if debug_collision:
		for child in body.get_children():
			if child is CollisionShape2D:
				var sh = child.shape
				var shape_info := "no_shape"
				if sh is SegmentShape2D:
					shape_info = "Segment a=%s b=%s" % [sh.a, sh.b]
				elif sh:
					shape_info = sh.get_class()

# Editördeki collision konumlarını sakla (sadece ilk yüklemede; sprite offset buna göre sonradan eklenir)
func _store_collision_original_positions() -> void:
	if not _collision_original_positions.is_empty():
		return
	var body = get_node_or_null("StaticBody2D")
	if not body:
		return
	for child in body.get_children():
		if child is CollisionShape2D and child.name.begins_with("CollisionLevel"):
			_collision_original_positions[child.name] = child.position

# Sprite'a uygulanan dikey offset'i collision'lara da uygula; böylece editörde gördüğün hizada kalırlar
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

# Seviyeye göre hangi collision shape'lerin aktif olacağını ayarla (seviye 3'te 2 segment).
# Önce editör konumları + sprite offset uygulanır, sonra sadece ilgili seviyenin shape'leri açılır.
func _update_collision() -> void:
	var body = get_node_or_null("StaticBody2D")
	if not body:
		if debug_collision:
			pass
		return
	_apply_collision_sprite_offset()
	var names_to_enable: Array = COLLISION_NAMES_BY_LEVEL.get(level, ["CollisionLevel1"])
	if debug_collision:
		pass
	# Önce CollisionLevel* ile başlayan tüm shape'leri kapat
	for child in body.get_children():
		if child is CollisionShape2D and child.name.begins_with("CollisionLevel"):
			child.disabled = true
	# Sonra bu seviyeye ait olanları aç
	for node_name in names_to_enable:
		var col = body.get_node_or_null(node_name)
		if col is CollisionShape2D:
			col.disabled = false
			if debug_collision:
				pass
		elif debug_collision:
			print("  -> %s BULUNAMADI" % node_name)
	# Her zaman kısa özet (segment global koordinatları = oyuncu pozisyonuyla karşılaştır)
	var active_list: Array[String] = []
	for child in body.get_children():
		if child is CollisionShape2D and child.name.begins_with("CollisionLevel") and not child.disabled:
			active_list.append(child.name)
	for child in body.get_children():
		if child is CollisionShape2D and child.name.begins_with("CollisionLevel"):
			if child.shape is SegmentShape2D:
				var s_seg: SegmentShape2D = child.shape as SegmentShape2D
				var ga_vec: Vector2 = child.global_position + s_seg.a
				var gb_vec: Vector2 = child.global_position + s_seg.b
			else:
				pass
	if debug_collision:
		for child in body.get_children():
			if child is CollisionShape2D and child.name.begins_with("CollisionLevel"):
				pass

func _print_collision_debug() -> void:
	var body = get_node_or_null("StaticBody2D")
	if not body:
		return
	for child in body.get_children():
		if child is CollisionShape2D and child.name.begins_with("CollisionLevel"):
			var seg := ""
			if child.shape is SegmentShape2D:
				var s: SegmentShape2D = child.shape as SegmentShape2D
				var ga: Vector2 = child.global_position + s.a
				var gb: Vector2 = child.global_position + s.b
				seg = " segment_global: %s .. %s" % [ga, gb]

func _update_ui() -> void:
	pass
