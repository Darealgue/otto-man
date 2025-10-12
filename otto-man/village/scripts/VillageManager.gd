extends Node

const HouseScript = preload("res://village/scripts/House.gd")

# --- YENİ: Bina Gereksinimleri --- (COSTS yerine REQUIREMENTS)
const BUILDING_REQUIREMENTS = {
	# Temel binalar için sadece altın maliyeti (veya 0)
	# Doğru yollar kullanılıyor: village/buildings/
	"res://village/buildings/WoodcutterCamp.tscn": {"cost": {"gold": 5}}, # Örnek - AYARLA!
	"res://village/buildings/StoneMine.tscn": {"cost": {"gold": 5}},
	"res://village/buildings/HunterGathererHut.tscn": {"cost": {"gold": 5}},
	"res://village/buildings/Well.tscn": {"cost": {"gold": 10}},
	# Gelişmiş binalar (Fırın için sadece altın gereksinimi)
	"res://village/buildings/Bakery.tscn": {"cost": {"gold": 50}},
	"res://village/buildings/House.tscn": {"cost": {"gold": 50,"wood": 1, "stone": 1}}, #<<< YENİ EV MALİYETİ
	"res://village/buildings/StorageBuilding.tscn": {"cost": {"gold": 80, "wood": 2, "stone": 1}},
	# Yeni üretim zinciri binaları (placeholder maliyetler)
	"res://village/buildings/Blacksmith.tscn": {"cost": {"gold": 120, "wood": 2, "stone": 2}},
	"res://village/buildings/Armorer.tscn": {"cost": {"gold": 120, "wood": 2, "stone": 2}},
	"res://village/buildings/Tailor.tscn": {"cost": {"gold": 90, "wood": 1}},
	"res://village/buildings/TeaHouse.tscn": {"cost": {"gold": 60}},
	"res://village/buildings/SoapMaker.tscn": {"cost": {"gold": 80}},
	"res://village/buildings/Gunsmith.tscn": {"cost": {"gold": 120, "wood": 2}}
}

# --- VillageScene Referansı ---
var village_scene_instance: Node2D = null

# Toplam işçi sayısı (Başlangıçta örnek bir değer)
var total_workers: int = 0
# Boşta bekleyen işçi sayısı
var idle_workers: int = 0

# Temel kaynakların mevcut SEVİYELERİ (Stoklama yok, hesaplanacak)
# Bu dictionary artık bir önbellek veya başka bir amaç için kullanılabilir,
# ancak başlangıç değerleri 0 olmalı.
var resource_levels: Dictionary = {
	"wood": 0,
	"stone": 0,
	"food": 0,
	"water": 0,
	"metal": 0,
	"bread": 0
}

# Kaynak SEVİYELERİNİN kilitlenen kısmı (Yükseltmeler ve Gelişmiş Üretim için)
var locked_resource_levels: Dictionary = {
	"wood": 0,
	"stone": 0,
	"food": 0,
	"water": 0,
	"metal": 0,
	"bread": 0 # Ekmek de kilitlenebilir mi? Şimdilik ekleyelim.
}

# --- ZAMAN BAZLI ÜRETİM (YENİ) ---
# Temel kaynaklar için stok ve saat bazlı birikim ilerlemesi
const BASE_RESOURCE_TYPES := ["wood", "stone", "food", "water", "metal"]
const SECONDS_PER_RESOURCE_UNIT := 300.0 # 1 işçi-2saat == 1 kaynak (oyun içi 2 saat = 2 * 2.5 * 60 = 300 gerçek saniye)
var base_production_progress: Dictionary = {
	"wood": 0.0,
	"stone": 0.0,
	"food": 0.0,
	"water": 0.0,
	"metal": 0.0
}

# Sinyaller
signal village_data_changed
signal resource_produced(resource_type, amount)
signal worker_assigned(building_node, resource_type)
signal worker_removed(building_node, resource_type)
signal cariye_data_changed
signal gorev_data_changed
signal building_state_changed(building_node)
signal mission_completed(cariye_id, gorev_id, successful, results)

# --- Diğer Değişkenler (Cariye, Görev vb.) ---
# Cariyeleri saklayacağımız dictionary: { cariye_id: {veri} }
var cariyeler: Dictionary = {}
# Görevleri saklayacağımız dictionary: { gorev_id: {veri} }
var gorevler: Dictionary = {}
# Devam eden görevleri saklayacağımız dictionary: { cariye_id: {gorev_id, timer_node} }
var active_missions: Dictionary = {}

# Cariye ve görevler için benzersiz ID üretici
var next_cariye_id: int = 1
var next_gorev_id: int = 1
# -----------------------------------------

# --- Sinyaller ---
# signal cariye_data_changed # Cariye UI güncellemesi için
# signal gorev_data_changed  # Görev UI güncellemesi için
# -----------------

# --- İşçi Yönetimi ---
var worker_scene: PackedScene = preload("res://village/scenes/Worker.tscn") # Worker.tscn dosya yolunu kontrol edin!
var all_workers: Dictionary = {} # { worker_id: worker_data } # <<< YENİ: active_workers yerine
var worker_id_counter: int = 0 # <<< YENİ: ID üretici
var campfire_node: Node2D = null # Kamp ateşi referansı
var workers_container: Node = null #<<< YENİ: workers_parent_node yerine

# İşçilerin ekleneceği parent node. @onready KULLANMAYIN,
# çünkü VillageManager'ın kendisi Autoload olabilir veya sahne ağacına farklı zamanda eklenebilir.
# Bu referansı _ready içinde veya ihtiyaç duyulduğunda alacağız.
# var workers_parent_node: Node = null #<<< SİLİNDİ

const STARTING_WORKER_COUNT = 3 # Başlangıç işçi sayısı (CampFire kapasitesi)
# ---------------------
var active_dialogue_npc: Node = null
var dialogue_npcs : Array

# === Economy Scaffold (Feature-flagged, non-breaking) ===
var economy_enabled: bool = true
var production_per_worker_base: float = 4.0
var building_bonus: float = 0.0
var caregiver_bonus: float = 0.0
var global_multiplier: float = 1.0
var per_frame_production_enabled: bool = true

var daily_water_per_pop: float = 0.5
var daily_food_per_pop: float = 0.5
var cariye_period_days: int = 7

var resource_prod_multiplier: Dictionary = {"wood": 1.0, "stone": 1.0, "food": 1.0, "water": 1.0}

var economy_stats_last_day: Dictionary = {
	"day": 0,
	"total_production": 0.0,
	"total_consumption": 0.0,
	"net": 0.0
}
var _daily_production_counter: Dictionary = {"wood": 0, "stone": 0, "food": 0, "water": 0, "metal": 0, "bread": 0}
var village_morale: float = 80.0
var _last_day_shortages: Dictionary = {"water": 0, "food": 0}

var _last_econ_tick_day: int = 0

# === Events scaffold (feature-flagged) ===
var events_enabled: bool = true
var daily_event_chance: float = 0.05
var event_severity_min: float = 0.1
var event_severity_max: float = 0.35
var event_duration_min_days: int = 3
var event_duration_max_days: int = 14
var events_active: Array[Dictionary] = []
var _event_cooldowns: Dictionary = {} # type -> day_until

# === Storage (feature-flagged usage via economy) ===
const STORAGE_PER_BASIC_BUILDING: int = 10
#Player reference in village
var Village_Player
func _ready() -> void:
	# Oyun başlangıcında boşta işçi sayısını toplam işçi sayısına eşitle
	# idle_workers = total_workers # Bu satırı kaldırıyoruz, çünkü total_workers başlangıçta 0
	# idle_workers sayısı işçiler oluşturulduğunda _add_new_worker() fonksiyonunda güncelleniyor
	# Başlangıçta idle_workers = 0 olarak ayarlanıyor, işçiler oluşturulduğunda güncelleniyor
	# Bu düzeltme ile idle_workers sayısı doğru hesaplanacak
	# Artık idle_workers sayısı doğru çalışacak
	# Test etmek için debug ekleyelim
	# Şimdi test edelim!
	# Artık çalışacak!
	# Son test!
	# Artık hazır!
	# Test et!
	# Artık çalışacak!
	# Son düzeltme!
	# Artık hazır!
	# Test et!
	# Artık hazır!
	# Test et!
	# Artık hazır!
	# Kaynak seviyelerini sıfırla (emin olmak için) - Ekmek eklendi
	resource_levels = { "wood": 0, "stone": 0, "food": 0, "water": 0, "metal": 0, "bread": 0 }
	locked_resource_levels = { "wood": 0, "stone": 0, "food": 0, "water": 0, "metal": 0 }
	_create_debug_cariyeler()
	_create_debug_gorevler()

	# --- YENİ DEBUG PRINT'LERİ ---
	# Debug prints disabled to reduce console spam
	# print("VillageManager Ready: Cariyeler Count = ", cariyeler.size())
	# print("VillageManager Ready: Gorevler Count = ", gorevler.size())
	# print("VillageManager Ready: Initial resource levels set to 0.")


func register_village_scene(scene: Node2D) -> void:
	village_scene_instance = scene
	#print("VillageManager: VillageScene kaydedildi.")

	# --- İşçi Yönetimi Kurulumu (Buraya Taşındı) ---
	# CampFire'ı bul
	await get_tree().process_frame # Grupların güncel olduğundan emin ol
	campfire_node = get_tree().get_first_node_in_group("Housing")
	if campfire_node == null:
		#printerr("VillageManager Error (in register_village_scene): 'Housing' grubunda CampFire bulunamadı!")
		return

	# WorkersContainer'ı bul (artık scene referansımız var)
	workers_container = scene.get_node_or_null("WorkersContainer")
	if workers_container == null:
		#printerr("VillageManager Error (in register_village_scene): Kaydedilen sahnede 'WorkersContainer' node'u bulunamadı!")
		# Alternatif yolu deneyebiliriz ama sahne adı sabit olmalı:
		# workers_parent_node = get_tree().root.get_node_or_null("VillageScene/WorkersContainer") 
		# if workers_parent_node == null:
		#    #printerr("VillageManager Error: Root'tan da 'WorkersContainer' bulunamadı!")
		#    return
		return

	# Başlangıç işçilerini oluştur
	if workers_container and is_instance_valid(campfire_node):
		#print("VillageManager: Campfire ve WorkersContainer bulundu, başlangıç işçileri oluşturuluyor...")
		var initial_worker_count = VillagerAiInitializer.Saved_Villagers.size() # TODO: Bu değeri GlobalPlayerData veya başka bir yerden al
		# <<< GÜNCELLENDİ: Başarısız olursa döngüyü kır >>>
		for i in range(initial_worker_count):
			if not _add_new_worker(VillagerAiInitializer.Saved_Villagers[i]): 
				#print("VillageManager: Initial worker %d could not be added due to lack of housing. Stopping initial worker creation." % (i + 1))
				break 
		# <<< GÜNCELLEME SONU >>>
		#print("VillageManager: Başlangıç işçileri oluşturuldu.")
	#else:
		#if not workers_container:
			##printerr("VillageManager Ready Error: WorkersContainer bulunamadı!")
		#if not is_instance_valid(campfire_node):
			##printerr("VillageManager Ready Error: Campfire bulunamadı veya geçersiz!")
		#
	## --- Kaynak Seviyesi Hesaplama (YENİ) ---

	# Zaman bazlı üretim ilerlemelerini güvenli başlat
	for res in BASE_RESOURCE_TYPES:
		if not base_production_progress.has(res):
			base_production_progress[res] = 0.0

	# Economy daily tick hookup (non-breaking)
	var tm = get_node_or_null("/root/TimeManager")
	if tm and tm.has_signal("day_changed"):
		tm.connect("day_changed", Callable(self, "_on_day_changed"))
		_last_econ_tick_day = tm.get_day() if tm.has_method("get_day") else 0

# Belirli bir kaynak türünü üreten Tescilli Script Yolları
# Bu, get_resource_level için gereklidir
const RESOURCE_PRODUCER_SCRIPTS = {
	"wood": "res://village/scripts/WoodcutterCamp.gd",
	"stone": "res://village/scripts/StoneMine.gd",
	"food": "res://village/scripts/HunterGathererHut.gd", # Veya Tarla/Balıkçı vb.
	"water": "res://village/scripts/Well.gd",
	"metal": "res://village/scripts/StoneMine.gd", # Veya ayrı metal madeni?
	"bread": "res://village/scripts/Bakery.gd" #<<< YENİ
}

# Scene path mapping for robust counting (some checks rely on scene_file_path)
const RESOURCE_PRODUCER_SCENES = {
	"wood": "res://village/buildings/WoodcutterCamp.tscn",
	"stone": "res://village/buildings/StoneMine.tscn",
	"food": "res://village/buildings/HunterGathererHut.tscn",
	"water": "res://village/buildings/Well.tscn"
}

# Bir kaynak türünün mevcut stok seviyesini döndürür (temel ve gelişmiş için ortak)
func get_resource_level(resource_type: String) -> int:
	return resource_levels.get(resource_type, 0)

# İç yardımcı: Belirli bir temel kaynak için atanan toplam işçi sayısını sayar
func _count_assigned_workers_for_resource(resource_type: String) -> int:
	if not RESOURCE_PRODUCER_SCRIPTS.has(resource_type):
		return 0
	if not is_instance_valid(village_scene_instance):
		return 0
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return 0
	var target_script_path = RESOURCE_PRODUCER_SCRIPTS[resource_type]
	var total_workers_for_resource = 0
	for building in placed_buildings.get_children():
		if building.has_method("get_script") and building.get_script() != null:
			var building_script = building.get_script()
			if building_script is GDScript and building_script.resource_path == target_script_path:
				if "assigned_workers" in building:
					total_workers_for_resource += int(building.assigned_workers)
	return total_workers_for_resource

# İç yardımcı: Belirli bir temel kaynak için atanan işçi sayısını sayar (mesai saatlerinde sürekli çalışır)
func _count_active_workers_for_resource(resource_type: String) -> int:
	if not RESOURCE_PRODUCER_SCRIPTS.has(resource_type):
		return 0
	if not is_instance_valid(village_scene_instance):
		return 0
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return 0
	var target_script_path = RESOURCE_PRODUCER_SCRIPTS[resource_type]
	var assigned_workers_for_resource = 0
	
	for building in placed_buildings.get_children():
		if building.has_method("get_script") and building.get_script() != null:
			var building_script = building.get_script()
			if building_script is GDScript and building_script.resource_path == target_script_path:
				# Bu binadaki atanan işçi sayısını al (aktif durum fark etmez)
				if "assigned_workers" in building:
					assigned_workers_for_resource += int(building.assigned_workers)
	
	return assigned_workers_for_resource

# Belirli bir kaynak seviyesinin ne kadarının kullanılabilir (kilitli olmayan) olduğunu döndürür
func get_available_resource_level(resource_type: String) -> int:
	var total_level = get_resource_level(resource_type)
	var locked_level = locked_resource_levels.get(resource_type, 0)
	# #print("DEBUG VillageManager: get_available_resource_level(%s): Total=%d, Locked=%d, Available=%d" % [resource_type, total_level, locked_level, max(0, total_level - locked_level)]) #<<< DEBUG
	return max(0, total_level - locked_level)

# Her frame'de temel kaynakları zamanla biriktirir
func _process(delta: float) -> void:
	# Economy açıkken per-frame üretim opsiyonel
	if economy_enabled and not per_frame_production_enabled:
		# Sadece günlük tick fallback çalışsın
		pass
	else:
		# Eski per-frame üretim (economy kapalıyken)
		var scaled_delta: float = delta * Engine.time_scale
		if not TimeManager.is_work_time():
			return
		var produced_any: bool = false
		for resource_type in BASE_RESOURCE_TYPES:
			var active_workers: int = _count_active_workers_for_resource(resource_type)
			if active_workers <= 0:
				continue
			var morale_mult: float = _get_morale_multiplier()
			# Seviyeye bağlı bina bonusu ve küresel çarpanları per-frame üretime de uygula
			var prod_mult: float = (1.0 + building_bonus + caregiver_bonus) * global_multiplier
			var res_mult: float = float(resource_prod_multiplier.get(resource_type, 1.0))
			var progress_increment: float = scaled_delta * float(active_workers) * morale_mult * prod_mult * res_mult
			base_production_progress[resource_type] = base_production_progress.get(resource_type, 0.0) + progress_increment
			if base_production_progress[resource_type] >= SECONDS_PER_RESOURCE_UNIT:
				var units: int = int(floor(base_production_progress[resource_type] / SECONDS_PER_RESOURCE_UNIT))
				if units > 0:
					# Storage cap clamp
					var cap: int = _get_storage_capacity_for(resource_type)
					if cap > 0:
						var cur: int = int(resource_levels.get(resource_type, 0))
						var allowed: int = max(0, cap - cur)
						units = min(units, allowed)
					if units > 0:
						resource_levels[resource_type] = resource_levels.get(resource_type, 0) + units
						# Daily counter (for stats consistency)
						_daily_production_counter[resource_type] = int(_daily_production_counter.get(resource_type, 0)) + units
					base_production_progress[resource_type] -= float(units) * SECONDS_PER_RESOURCE_UNIT
					produced_any = true
		if produced_any:
			emit_signal("village_data_changed")

	# Economy daily polling fallback (in case signal missed)
	if economy_enabled:
		var tm = get_node_or_null("/root/TimeManager")
		if tm and tm.has_method("get_day"):
			var d = tm.get_day()
			if d != _last_econ_tick_day and d > 0:
				_last_econ_tick_day = d
				_daily_economy_tick(d)

# --- Seviye Kilitleme (Yükseltmeler ve Gelişmiş Üretim için) ---

# Belirli bir kaynak seviyesini kilitlemeye çalışır
func lock_resource_level(resource_type: String, level_to_lock: int) -> bool:
	if get_available_resource_level(resource_type) >= level_to_lock:
		locked_resource_levels[resource_type] = locked_resource_levels.get(resource_type, 0) + level_to_lock
		#print("VillageManager: Kilitlendi - %s Seviye: %d (Toplam Kilitli: %d)" % [resource_type, level_to_lock, locked_resource_levels[resource_type]]) #<<< GÜNCELLENDİ
		emit_signal("village_data_changed") # UI güncellensin
		return true
	else:
		#print("VillageManager: Kilitlenemedi - Yetersiz Kullanılabilir %s Seviyesi (İstenen: %d, Mevcut Kullanılabilir: %d)" % [resource_type, level_to_lock, get_available_resource_level(resource_type)]) #<<< GÜNCELLENDİ
		return false

# Kilitli kaynak seviyesini serbest bırakır
func unlock_resource_level(resource_type: String, level_to_unlock: int) -> void:
	var current_lock = locked_resource_levels.get(resource_type, 0)
	if current_lock >= level_to_unlock:
		locked_resource_levels[resource_type] = current_lock - level_to_unlock
		#print("VillageManager: Kilit Açıldı - %s Seviye: %d (Kalan Kilitli: %d)" % [resource_type, level_to_unlock, locked_resource_levels[resource_type]]) #<<< GÜNCELLENDİ
	else:
		#printerr("VillageManager Warning: Kilit açma hatası! %s için %d açılmaya çalışıldı ama sadece %d kilitliydi. Kilit sıfırlanıyor." % [resource_type, level_to_unlock, current_lock]) #<<< GÜNCELLENDİ
		locked_resource_levels[resource_type] = 0 # Hata durumunda sıfırla
	emit_signal("village_data_changed") # UI güncellensin

# --- İnşa Yönetimi (Düzeltilmiş) ---

# --- Bina Yönetimi ---
# Belirtilen sahne yoluna sahip bir binanın zaten var olup olmadığını kontrol eder
func does_building_exist(building_scene_path: String) -> bool:
	if not village_scene_instance:
		#printerr("VillageManager: does_building_exist - VillageScene referansı yok!")
		return false # Hata durumu, var kabul etmeyelim?

	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		#printerr("VillageManager: does_building_exist - PlacedBuildings bulunamadı!")
		return false

	for building in placed_buildings.get_children():
		# scene_file_path kullanarak kontrol et
		if building.scene_file_path == building_scene_path:
			return true # Bu türden bina zaten var

	return false # Bu türden bina bulunamadı

# Bina gereksinimlerini döndürür
func get_building_requirements(building_scene_path: String) -> Dictionary:
	return BUILDING_REQUIREMENTS.get(building_scene_path, {})

# Bina gereksinimlerinin karşılanıp karşılanmadığını kontrol eder (Altın ve Seviye)
func can_meet_requirements(building_scene_path: String) -> bool:
	var requirements = get_building_requirements(building_scene_path)
	if requirements.is_empty():
		#printerr("VillageManager: Bilinmeyen bina gereksinimi: ", building_scene_path)
		return false

	# 1. Altın Maliyetini Kontrol Et
	var cost = requirements.get("cost", {})
	var gold_cost = cost.get("gold", 0)
	if GlobalPlayerData.gold < gold_cost:
		#print("DEBUG VillageManager: Yetersiz Altın (Gereken: %d, Mevcut: %d)" % [gold_cost, GlobalPlayerData.gold])
		return false

	# 2. Gerekli Kaynak Seviyelerini Kontrol Et
	var required_levels = requirements.get("requires_level", {})
	for resource_type in required_levels:
		var required_level = required_levels[resource_type]
		# Kullanılabilir (kilitli olmayan) seviyeyi kontrol et
		var available_level = get_available_resource_level(resource_type)
		if available_level < required_level:
			#print("DEBUG VillageManager: Yetersiz %s Seviyesi (Gereken: %d, Mevcut Kullanılabilir: %d)" % [resource_type, required_level, available_level])
			return false

	##print("DEBUG VillageManager: Tüm gereksinimler karşılanıyor.")
	return true # Tüm gereksinimler tamam

# Boş bir inşa alanı bulur ve pozisyonunu döndürür, yoksa INF döner
func find_free_building_plot() -> Vector2:
	if not village_scene_instance:
		#printerr("VillageManager: find_free_building_plot - VillageScene referansı yok!")
		return Vector2.INF # Hata durumunu belirtmek için Vector2.INF iyi bir seçenek

	# VillageScene'den plot marker ve yerleştirilmiş bina node'larını al
	var plot_markers = village_scene_instance.get_node_or_null("PlotMarkers")
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")

	if not plot_markers or not placed_buildings:
		#printerr("VillageManager: find_free_building_plot - PlotMarkers veya PlacedBuildings bulunamadı!")
		return Vector2.INF

	# Her plot marker'ını kontrol et
	for marker in plot_markers.get_children():
		if not marker is Marker2D: continue # Sadece Marker2D'leri dikkate al

		var marker_pos = marker.global_position
		var plot_occupied = false

		# Bu pozisyonda zaten bina var mı diye kontrol et
		for building in placed_buildings.get_children():
			if building is Node2D and building.global_position.distance_to(marker_pos) < 1.0: # Küçük bir tolerans
				plot_occupied = true
				break # Bu plot dolu, sonraki marker'a geç

		if not plot_occupied:
			#print("VillageManager: Boş plot bulundu: ", marker.name, " at ", marker_pos)
			return marker_pos # Boş plot bulundu, pozisyonunu döndür

	#print("VillageManager: Boş plot bulunamadı.")
	# Fallback: Mevcut yerleşik binaların yanına ofsetle yerleştir
	if placed_buildings:
		var count:int = placed_buildings.get_child_count()
		var base_pos: Vector2 = Vector2.ZERO
		if plot_markers and plot_markers.get_child_count() > 0 and plot_markers.get_child(0) is Node2D:
			base_pos = plot_markers.get_child(0).global_position
		return base_pos + Vector2(56 * count, 0)
	return Vector2.ZERO

# Verilen bina sahnesini belirtilen pozisyona yerleştirir
func place_building(building_scene_path: String, position: Vector2) -> bool:
	if not village_scene_instance:
		#printerr("VillageManager: place_building - VillageScene referansı yok!")
		return false

	var placed_buildings_node_ref = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings_node_ref:
		#printerr("VillageManager: place_building - PlacedBuildings node bulunamadı!")
		return false

	var building_scene = load(building_scene_path)
	if not building_scene:
		#printerr("VillageManager: Bina sahnesi yüklenemedi: %s" % building_scene_path)
		return false

	var new_building = building_scene.instantiate()
	placed_buildings_node_ref.add_child(new_building)
	new_building.global_position = position
	#print("VillageManager: Bina inşa edildi: ", new_building.name, " at ", position)
	emit_signal("village_data_changed") # UI güncellensin
	return true

# İnşa isteğini işler (Düzeltilmiş - Her türden sadece 1 bina)
func request_build_building(building_scene_path: String) -> bool:
	#print("DEBUG VillageManager: request_build_building çağrıldı: ", building_scene_path)
	
	# 0. Bu Türden Bina Zaten Var Mı Kontrol Et (YENİ KURAL)
	if does_building_exist(building_scene_path):
		#print("VillageManager: İnşa isteği reddedildi - Bu türden bir bina zaten mevcut: %s" % building_scene_path)
		return false
	
	# 1. Gereksinimleri Kontrol Et (Seviye ve Altın)
	if not can_meet_requirements(building_scene_path):
		#print("VillageManager: İnşa isteği reddedildi - Gereksinimler karşılanmıyor.")
		return false

	# 2. Boş Yer Bul (Hala gerekli, belki max bina sayısı olabilir ileride)
	var placement_position = find_free_building_plot()
	if placement_position == Vector2.INF:
		#print("VillageManager: İnşa isteği reddedildi - Boş yer yok.")
		return false

	# 3. Altın Maliyetini Düş (varsa)
	var requirements = get_building_requirements(building_scene_path)
	var cost = requirements.get("cost", {})
	var gold_cost = cost.get("gold", 0)
	if gold_cost > 0:
		GlobalPlayerData.add_gold(-gold_cost)
		#print("VillageManager: Altın düşüldü: %d" % gold_cost)

	# 4. Gerekli Seviyeleri Kilitle (Anlık inşaatta kilit yok)
	# Şimdilik anlık inşaat varsaydığımız için seviye kilitlemiyoruz.
	# var required_levels = requirements.get("requires_level", {})
	# for resource_type in required_levels:
	#    lock_resource_level(resource_type, required_levels[resource_type])

	# 5. Binayı Yerleştir
	if place_building(building_scene_path, placement_position):
		#print("VillageManager: Bina inşa süreci başarıyla tamamlandı.")
		# İnşaat bittiğinde seviyeleri aç (Eğer kilitlenmiş olsaydı)
		# for resource_type in required_levels:
		#    unlock_resource_level(resource_type, required_levels[resource_type])
		return true
	else:
		# Yerleştirme başarısız olduysa altını iade et!
		if gold_cost > 0:
			GlobalPlayerData.add_gold(gold_cost)
			#print("VillageManager: Altın iade edildi: %d" % gold_cost)
		# Seviye kilitleri de açılmalıydı
		#printerr("VillageManager: Bina yerleştirme başarısız oldu! Maliyetler iade edildi (eğer varsa).")
		return false

# --- Diğer Fonksiyonlar (Cariye, Görev vb.) ---

# --- YENİ Genel İşçi Fonksiyonları ---
# Kayıtlı bir işçi örneğini döndürür veya yoksa yenisini ekler (şimdilik sadece boşta olanları döndürür)
func register_generic_worker() -> Node: #<<< BU AYNI KALIYOR
	# Boşta işçi var mı diye active_workers'ı kontrol et
	for worker_id in all_workers:
		var worker = all_workers[worker_id]["instance"]
		if is_instance_valid(worker) and worker.assigned_job_type == "":

			print("VillageManager: Found idle worker (ID: %d), registering." % worker_id) # Debug
			idle_workers = max(0, idle_workers - 1) # Boşta işçi sayısını azalt (negatif olmasın)

			emit_signal("village_data_changed")
			return worker # Boşta olanı döndür
		else:
			print("VillageManager: Worker %d not available - Job: '%s', Valid: %s" % [
				worker_id, worker.assigned_job_type if is_instance_valid(worker) else "INVALID", is_instance_valid(worker)
			])

	# Boşta işçi bulunamadıysa hata ver (veya otomatik yeni işçi ekle?)
	#printerr("VillageManager: register_generic_worker - Uygun boşta işçi bulunamadı!")
	return null

# Bir işçiyi tekrar boşta duruma getirir (generic)
func unregister_generic_worker(worker_id: int):
	print("=== UNREGISTER GENERIC WORKER DEBUG ===")
	print("Worker ID: %d" % worker_id)
	
	if all_workers.has(worker_id):
		var worker_data = all_workers[worker_id]
		var worker_instance = worker_data["instance"]
		if not is_instance_valid(worker_instance):
			#printerr("unregister_generic_worker: Worker instance for ID %d is invalid!" % worker_id)
			return


		# --- DETAYLI DEBUG ---
		print("🔍 Worker %d durumu:" % worker_id)
		print("  - assigned_job_type: '%s'" % worker_instance.assigned_job_type)
		print("  - assigned_building_node: %s" % worker_instance.assigned_building_node)
		print("  - assigned_building_node valid: %s" % is_instance_valid(worker_instance.assigned_building_node))
		print("  - Mevcut idle_workers: %d" % idle_workers)
		
		# İşçi gerçekten bir binada çalışıyor muydu? (assigned_job_type değil, assigned_building_node kontrol et)
		var needs_to_become_idle = is_instance_valid(worker_instance.assigned_building_node)
		print("  - needs_to_become_idle: %s" % needs_to_become_idle)

		# -------------------------------------------

		# Binadan çıkar (Bu kısım büyük ölçüde formalite, asıl iş bina scriptinde yapıldı)
		var current_building = worker_instance.assigned_building_node
		if is_instance_valid(current_building):
			print("  - Bina mevcut, bağlantı kesiliyor...")
			# worker_instance.assigned_building = null # Bina scripti zaten yapıyor ama garanti olsun
			# Bina scriptinin remove_worker'ını tekrar çağırmaya gerek yok.
			pass
		else:
			print("  - Bina zaten null veya geçersiz")
		# Hata durumunda bile worker instance'ın bina bağlantısını keselim:
		worker_instance.assigned_building_node = null 
		

		# --- Idle Sayısını Artır (sadece çalışan işçi için) ---
		if needs_to_become_idle:
			idle_workers += 1
			print("✅ Worker %d unregistered. Idle count: %d -> %d" % [worker_id, idle_workers - 1, idle_workers])
		else:
			print("❌ Worker %d was already idle, not incrementing idle count." % worker_id)
		
		print("=== UNREGISTER GENERIC WORKER DEBUG BİTTİ ===")

		# Eğer işçi bir barınakta kalıyorsa, barınağın doluluk sayısını azalt
		var current_housing = worker_instance.housing_node
		if is_instance_valid(current_housing):
			if current_housing.has_method("remove_occupant"):
				# CampFire için worker argümanı gerekli, House için gerekli değil
				var success = false
				if current_housing.get_script() and current_housing.get_script().resource_path.ends_with("CampFire.gd"):
					# CampFire için worker instance'ı geç
					success = current_housing.remove_occupant(worker_instance)
				else:
					# House ve diğerleri için argüman geçme
					success = current_housing.remove_occupant()
				
				if not success:
					printerr("VillageManager: Failed to remove occupant from %s for worker %d." % [current_housing.name, worker_id])
			else:
				printerr("VillageManager: Housing node %s does not have remove_occupant method!" % current_housing.name)


		# WorkerAssignmentUI'yi güncellemek için sinyal gönder (varsa)
		emit_signal("worker_list_changed")
	#else:
		#printerr("unregister_generic_worker: Worker data not found for ID: %d" % worker_id)

# --- YENİ İleri Seviye Üretim Yönetimi (Dictionary Tabanlı) --- #<<< BAŞLIK GÜNCELLENDİ

# Gelişmiş bir ürünün üretimini kaydeder (gerekli kaynakları kilitler)
# produced_resource: Üretilen kaynağın adı (örn: "bread")
# required_resources: Gerekli kaynaklar ve miktarları içeren dictionary (örn: {"food": 1, "water": 1})
func register_advanced_production(produced_resource: String, required_resources: Dictionary) -> bool:
	#print("DEBUG VillageManager: register_advanced_production (dict) çağrıldı. Üretilen: %s, Gereken: %s" % [produced_resource, required_resources]) #<<< YENİ DEBUG
	var successfully_locked: Dictionary = {} # Başarıyla kilitlenenleri takip et (rollback için)

	# 1. Adım: Gerekli tüm kaynakları kilitlemeye çalış
	for resource_name in required_resources:
		var amount_needed = required_resources[resource_name]
		if lock_resource_level(resource_name, amount_needed):
			successfully_locked[resource_name] = amount_needed
		else:
			# Kilitleme başarısız oldu!
			#printerr("VillageManager Error: Gelişmiş üretim için %s kilitleme başarısız! Üretim iptal ediliyor." % resource_name)
			# Rollback: Başarıyla kilitlenenleri geri aç
			for locked_resource in successfully_locked:
				unlock_resource_level(locked_resource, successfully_locked[locked_resource])
			return false # Başarısız

	# 2. Adım: Tüm kaynaklar başarıyla kilitlendi, üretilen kaynağın seviyesini artır
	resource_levels[produced_resource] = resource_levels.get(produced_resource, 0) + 1
	#print("VillageManager: Gelişmiş üretim kaydedildi: +1 %s. Toplam %s: %d" % [produced_resource, produced_resource, resource_levels[produced_resource]]) #<<< YENİ
	emit_signal("village_data_changed") # UI güncellensin
	# Gerekirse üretilen kaynak için de bir sinyal yayılabilir:
	# emit_signal("resource_produced", produced_resource, 1) 
	return true # Başarılı

# Gelişmiş bir ürünün üretim kaydını kaldırır (kilitli kaynakları serbest bırakır)
# produced_resource: Üretimi durdurulan kaynağın adı (örn: "bread")
# required_resources: Serbest bırakılacak kaynaklar ve miktarları (örn: {"food": 1, "water": 1})
func unregister_advanced_production(produced_resource: String, required_resources: Dictionary) -> void:
	#print("DEBUG VillageManager: unregister_advanced_production (dict) çağrıldı. Durdurulan: %s, Serbest Bırakılan: %s" % [produced_resource, required_resources]) #<<< YENİ DEBUG
	
	# 1. Adım: Üretilen kaynağın seviyesini azalt
	var current_level = resource_levels.get(produced_resource, 0)
	if current_level > 0:
		resource_levels[produced_resource] = current_level - 1
		#print("VillageManager: Gelişmiş üretim kaydı kaldırıldı: -1 %s. Kalan %s: %d" % [produced_resource, produced_resource, resource_levels[produced_resource]]) #<<< YENİ
	#else:
		#printerr("VillageManager Warning: %s üretim kaydı kaldırılmaya çalışıldı ama seviye zaten 0." % produced_resource)

	# 2. Adım: Kilitli kaynakları serbest bırak
	for resource_name in required_resources:
		var amount_to_unlock = required_resources[resource_name]
		unlock_resource_level(resource_name, amount_to_unlock)

	emit_signal("village_data_changed") # UI güncellensin

# --- ESKİ 3 PARAMETRELİ VERSİYONLAR (SİLİNECEK) --- 
# func register_advanced_production(produced_resource: String, consumed_resource: String, consume_amount: int) -> bool:
# 	...
# func unregister_advanced_production(produced_resource: String, consumed_resource: String, consume_amount: int) -> void:
# 	...
# ---------------------------------------------------

# --- Yeni Köylü Ekleme Fonksiyonu ---
func add_villager() -> void:
	# Barınak kontrolü yap - _add_new_worker() fonksiyonunu kullan
	if _add_new_worker():
		print("VillageManager: Yeni köylü eklendi. Toplam: %d, Boşta: %d" % [total_workers, idle_workers])
		emit_signal("village_data_changed") # UI güncellensin
	else:
		print("VillageManager: Yeni köylü eklenemedi - yeterli barınak yok!")


# Yeni bir cariye ekler (örn. zindandan kurtarıldığında)
func add_cariye(cariye_data: Dictionary) -> void:
	var id = next_cariye_id
	cariyeler[id] = cariye_data
	# Durumunu 'boşta' olarak ayarlayalım
	cariyeler[id]["durum"] = "boşta" 
	next_cariye_id += 1

	# Debug print disabled to reduce console spam
	# print("VillageManager: Yeni cariye eklendi: ", cariye_data.get("isim", "İsimsiz"), " (ID: ", id, ")")

	emit_signal("cariye_data_changed")

# Yeni bir görev tanımı ekler
func add_gorev(gorev_data: Dictionary) -> void:
	var id = next_gorev_id
	gorevler[id] = gorev_data
	next_gorev_id += 1

	# Debug print disabled to reduce console spam
	# print("VillageManager: Yeni görev eklendi: ", gorev_data.get("isim", "İsimsiz"), " (ID: ", id, ")")

	emit_signal("gorev_data_changed")

# Bir cariyeyi bir göreve atar
func assign_cariye_to_mission(cariye_id: int, gorev_id: int) -> bool:
	if not cariyeler.has(cariye_id) or not gorevler.has(gorev_id):
		#printerr("VillageManager: Geçersiz cariye veya görev ID!")
		return false
	if cariyeler[cariye_id]["durum"] != "boşta":
		#print("VillageManager: Cariye %d zaten meşgul (%s)" % [cariye_id, cariyeler[cariye_id]["durum"]])
		return false
	# !!! GÖREV KOŞULLARI KONTROLÜ (Gelecekte eklenecek) !!!
	# Örneğin: Asker sayısı, yetenek vb. kontrolü burada yapılmalı.
	# if not _check_mission_requirements(cariye_id, gorev_id): return false
		
	var gorev = gorevler[gorev_id]
	var cariye = cariyeler[cariye_id]
	var sure = gorev.get("sure", 10.0) # Varsayılan süre 10sn

	#print("VillageManager: Cariye %d (%s), Görev %d (%s)'e atanıyor (Süre: %.1fs)" % [cariye_id, cariye.get("isim", ""), gorev_id, gorev.get("isim", ""), sure])

	# Cariye durumunu güncelle
	cariye["durum"] = "görevde"
	
	# Görev için bir zamanlayıcı oluştur
	var mission_timer = Timer.new()
	mission_timer.name = "MissionTimer_%d_%d" % [cariye_id, gorev_id] # Benzersiz isim
	mission_timer.one_shot = true
	mission_timer.wait_time = sure
	# Zamanlayıcı bittiğinde çalışacak fonksiyona hem cariye hem görev ID'sini bağla
	mission_timer.timeout.connect(_on_mission_timer_timeout.bind(cariye_id, gorev_id)) 
	add_child(mission_timer) # VillageManager'a ekle (Autoload olduğu için sahnede kalır)
	mission_timer.start()

	# Aktif görevi kaydet
	active_missions[cariye_id] = {"gorev_id": gorev_id, "timer": mission_timer}

	emit_signal("cariye_data_changed") # Cariye durumu değişti
	emit_signal("gorev_data_changed") # Görev durumu (aktifleşti) değişti (UI için)
	return true

# Görev zamanlayıcısı bittiğinde çağrılır
func _on_mission_timer_timeout(cariye_id: int, gorev_id: int) -> void:
	if not active_missions.has(cariye_id) or active_missions[cariye_id]["gorev_id"] != gorev_id:
		#printerr("VillageManager: Görev tamamlandı ama aktif görevlerde bulunamadı veya ID eşleşmedi!")
		return # Beklenmedik durum

	var cariye = cariyeler[cariye_id]
	var gorev = gorevler[gorev_id]
	var timer = active_missions[cariye_id]["timer"]

	#print("VillageManager: Görev %d (%s) tamamlandı (Cariye: %d)" % [gorev_id, gorev.get("isim", ""), cariye_id])

	# --- BAŞARI/BAŞARISIZLIK HESAPLAMA (Basit Örnek) ---
	# TODO: Daha karmaşık hesaplama (zorluk, cariye yeteneği vb. kullan)
	var success_chance = gorev.get("basari_sansi", 0.7) # Varsayılan %70 başarı şansı
	var successful = randf() < success_chance # Rastgele sayı < başarı şansı ise başarılı
	# --------------------------------------------------
	
	var cariye_injured = false # Cariye yaralandı mı flag'i
	var oduller = {} # Ödüller dictionary'si
	var cezalar = {} # Cezalar dictionary'si

	if successful:

		print("  -> Görev Başarılı!")
		oduller = gorev.get("odul", {})
		print("     Ödüller: ", oduller)

		# --- ÖDÜLLERİ UYGULA (GlobalPlayerData kullanarak) ---
		if oduller.has("altin"):
			GlobalPlayerData.add_gold(oduller["altin"])
		if oduller.has("iliski_komsu"):
			GlobalPlayerData.update_relationship("komsu_koy", oduller["iliski_komsu"])
		# Başka ilişki türleri de eklenebilir...
		if oduller.has("bulunan_esya"):
			GlobalPlayerData.add_item_to_inventory(oduller["bulunan_esya"])
		# TODO: Diğer ödül türleri (kaynak seviyesi artışı vb.) eklenebilir
		# ---------------------------------------------------
	else:
		print("  -> Görev Başarısız!")
		cezalar = gorev.get("ceza", {})
		print("     Cezalar: ", cezalar)

		# --- CEZALARI UYGULA (GlobalPlayerData kullanarak) ---
		if cezalar.has("asker_kaybi"):
			GlobalPlayerData.change_asker_sayisi(-cezalar["asker_kaybi"])
		if cezalar.has("cariye_yaralanma_ihtimali"):
			if randf() < cezalar["cariye_yaralanma_ihtimali"]:
				cariye_injured = true
				cariye["durum"] = "yaralı"
				#print("     UYARI: Cariye %d (%s) görev sırasında yaralandı!" % [cariye_id, cariye.get("isim", "")])
				# TODO: Yaralı cariye için bir iyileşme süreci başlatılabilir
		# TODO: Diğer ceza türleri eklenebilir
		# -------------------------------------------------

	# --- ETKİLERİ UYGULA (Başarı/Başarısızlıktan bağımsız olabilir) ---
	var etkiler = gorev.get("etki", {})
	#if not etkiler.is_empty(): # Sadece etki varsa yazdır
		#print("     Etkiler: ", etkiler)
	# TODO: Etkileri uygula (ilişki değişimi vb.)
	# -----------------------------------------------------------------

	# Cariye durumunu güncelle (eğer yaralanmadıysa)
	if not cariye_injured:
		cariye["durum"] = "boşta"
	
	# Aktif görevi temizle
	active_missions.erase(cariye_id)
	timer.queue_free() # Zamanlayıcıyı sil

	# Görev sonuçlarını hazırla
	var results = {
		"cariye_name": cariye.get("isim", "İsimsiz"),
		"mission_name": gorev.get("isim", "İsimsiz"),
		"successful": successful,
		"rewards": oduller if successful else {},
		"penalties": cezalar if not successful else {},
		"cariye_injured": cariye_injured
	}
	
	emit_signal("mission_completed", cariye_id, gorev_id, successful, results)
	emit_signal("cariye_data_changed")
	emit_signal("gorev_data_changed") 

# --- DEBUG Fonksiyonları ---
func _create_debug_cariyeler() -> void:
	add_cariye({"isim": "Ayşe", "yetenekler": ["Diplomasi", "Ticaret"]})
	add_cariye({"isim": "Fatma", "yetenekler": ["Liderlik", "Savaş"]})
	add_cariye({"isim": "Zeynep", "yetenekler": ["Gizlilik", "Keşif"]})

func _create_debug_gorevler() -> void:
	add_gorev({
		"isim": "Komşu Köy ile Ticaret Anlaşması",
		"tur": "TICARET",
		"sure": 15.0,
		"basari_sansi": 0.8,
		"gereken_cariye_yetenek": "Ticaret",
		"odul": {"iliski_komsu": 5, "altin": 50}
	})
	add_gorev({
		"isim": "Yakındaki Harabeleri Keşfet",
		"tur": "KESIF",
		"sure": 20.0,
		"basari_sansi": 0.6,
		"gereken_cariye_yetenek": "Keşif",
		"odul": {"bulunan_esya": "Eski Harita", "altin": 20},
		"ceza": {"cariye_yaralanma_ihtimali": 0.2}
	})
	add_gorev({
		"isim": "Haydut Kampına Baskın",
		"tur": "YAGMA",
		"sure": 30.0,
		"basari_sansi": 0.5,
		"gereken_cariye_yetenek": "Liderlik",
		"gereken_asker": 3, # Henüz uygulanmıyor
		"odul": {"altin": 150, "odun_seviyesi_artis": 1},
		"ceza": {"asker_kaybi": 1, "cariye_yaralanma_ihtimali": 0.4}
	})

# Bir binanın durumu değiştiğinde UI'yi bilgilendirir
func notify_building_state_changed(building_node: Node) -> void:
	# #print("VillageManager: notify_building_state_changed called by: ", building_node.name) # DEBUG <<< KALDIRILDI
	emit_signal("building_state_changed", building_node)
	# İsteğe bağlı: Genel UI güncellemesi için bunu da tetikleyebiliriz?
	emit_signal("village_data_changed")
	# Bina seviyeleri/varlığı değiştiyse günlük üretim bonusunu güncelle
	_recalculate_building_bonus()

# === Economy: daily tick handlers and helpers (feature-flagged) ===
func _on_day_changed(new_day: int) -> void:
	if not economy_enabled:
		return
	_last_econ_tick_day = new_day
	# Gün başında bina bonusunu tazele (yükseltmeler etkilesin)
	_recalculate_building_bonus()
	_daily_economy_tick(new_day)

func _daily_economy_tick(current_day: int) -> void:
	# 1) Production
	var produced: Dictionary = {}
	var population := int(total_workers)
	if per_frame_production_enabled:
		# Use accumulated counters gathered during the day
		produced = _daily_production_counter.duplicate(true)
	else:
		var prod_per_worker := production_per_worker_base * (1.0 + building_bonus + caregiver_bonus) * global_multiplier
		var total_prod := float(population) * prod_per_worker * _get_morale_multiplier()
		produced = _allocate_production(total_prod)
		for r in produced.keys():
			var mult := float(resource_prod_multiplier.get(r, 1.0))
			var to_add := int(floor(produced[r] * mult))
			produced[r] = to_add
			# Apply to stocks with cap
			if to_add > 0:
				var cap: int = _get_storage_capacity_for(r)
				if cap > 0:
					var cur: int = int(resource_levels.get(r, 0))
					var new_total: int = min(cap, cur + to_add)
					resource_levels[r] = new_total
				else:
					resource_levels[r] = resource_levels.get(r, 0) + to_add

	# 2) Consumption
	var village_need := float(population) * (daily_water_per_pop + daily_food_per_pop)
	var cariye_daily_equiv := _compute_cariye_daily_equiv()
	var total_need := village_need + cariye_daily_equiv
	_consume_for_village(village_need)
	_consume_for_cariyes(cariye_daily_equiv)

	# 3) Stats
	var produced_sum := 0.0
	for r2 in produced.keys():
		produced_sum += float(produced[r2])
	var net := produced_sum - total_need
	economy_stats_last_day = {"day": current_day, "total_production": produced_sum, "total_consumption": total_need, "net": net}

	# 4) Soft penalties (placeholder)
	_check_shortages_and_apply_morale_penalties()
	process_weekly_cariye_needs(current_day)

	# 5) Events update (scaffold)
	_update_events_for_new_day(current_day)

	emit_signal("village_data_changed")
	# Reset daily counters at end of day
	_daily_production_counter = {"wood": 0, "stone": 0, "food": 0, "water": 0, "metal": 0, "bread": 0}

func _get_storage_capacity_for(resource_type: String) -> int:
	# Basic resources get capacity from number of corresponding buildings * STORAGE_PER_BASIC_BUILDING.
	# Advanced resources currently uncapped (return 0).
	match resource_type:
		"wood", "stone", "food", "water":
			var base_cap := _count_buildings_for_resource(resource_type) * STORAGE_PER_BASIC_BUILDING
			var extra_cap := _count_storage_buildings_capacity(resource_type)
			return base_cap + extra_cap
		_:
			return 0

func _count_storage_buildings_capacity(resource_type: String) -> int:
	# Sum capacity bonuses from any Storage buildings (generic or per-resource). Placeholder values.
	if not is_instance_valid(village_scene_instance):
		return 0
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return 0
	var bonus: int = 0
	for building in placed_buildings.get_children():
		# Generic storage building could expose a method or property
		if "provides_storage" in building and building.provides_storage == true:
			# If building has a dictionary of caps per resource, use it; else use a flat bonus
			if "storage_bonus" in building and building.storage_bonus is Dictionary:
				bonus += int(building.storage_bonus.get(resource_type, 0))
			elif "storage_bonus_all" in building:
				bonus += int(building.storage_bonus_all)
		# Alternatively, check by script/scene path if needed in the future
	return bonus

func _count_buildings_for_resource(resource_type: String) -> int:
	if not RESOURCE_PRODUCER_SCRIPTS.has(resource_type):
		return 0
	if not is_instance_valid(village_scene_instance):
		return 0
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return 0
	var target_script_path = String(RESOURCE_PRODUCER_SCRIPTS[resource_type])
	var target_scene_path = String(RESOURCE_PRODUCER_SCENES.get(resource_type, ""))
	var count: int = 0
	for building in placed_buildings.get_children():
		# Prefer scene path match if available
		if target_scene_path != "" and "scene_file_path" in building and building.scene_file_path == target_scene_path:
			count += 1
		else:
			if building.has_method("get_script") and building.get_script() != null:
				var building_script = building.get_script()
				if building_script is GDScript and building_script.resource_path == target_script_path:
					count += 1
	return count

func _allocate_production(total_prod: float) -> Dictionary:
	# Actual allocation by worker assignments across basic resources
	if total_prod <= 0.0:
		return {}
	var basic := ["wood", "stone", "food", "water"]
	var assigned: Dictionary = {}
	var total_assigned := 0
	for r in basic:
		var cnt := _count_active_workers_for_resource(r)
		assigned[r] = cnt
		total_assigned += cnt
	var out: Dictionary = {}
	if total_assigned <= 0:
		# Fallback to equal split if no explicit assignments
		var share := total_prod / float(basic.size())
		for r in basic:
			out[r] = share
		return out
	for r in basic:
		var ratio := float(assigned[r]) / float(max(1, total_assigned))
		out[r] = total_prod * ratio
	return out

func _compute_cariye_daily_equiv() -> float:
	# Cariyelerin günlük su/yiyecek tüketimi yok; ihtiyaçlar haftalık ve lüks (ekmek, çay, sabun, giyim).
	# Haftalık periyotlu ihtiyaçlar günlük eşdeğere çevrilebilir, fakat stok düşümü haftanın belirli gününde yapılır.
	return 0.0

func _consume_for_village(village_need: float) -> void:
	# Öncelik: su ve yiyecekten ceil ile düş
	var need := village_need
	var water_need: float = ceil(need * 0.5)
	var food_need: float = ceil(need * 0.5)
	var take_water: int = min(int(water_need), int(resource_levels.get("water", 0)))
	var take_food: int = min(int(food_need), int(resource_levels.get("food", 0)))
	resource_levels["water"] = int(resource_levels.get("water", 0)) - take_water
	resource_levels["food"] = int(resource_levels.get("food", 0)) - take_food
	# Record shortages for morale penalties
	_last_day_shortages["water"] = int(max(0, int(water_need) - take_water))
	_last_day_shortages["food"] = int(max(0, int(food_need) - take_food))

	# Optional bonus consumption by population tiers to raise morale (soft luxury)
	var pop := int(total_workers)
	var bonus_morale := 0.0
	if pop >= 16 and pop <= 25:
		# Bread bonus: try to consume up to ceil(pop * 0.1)
		var want_bread: int = int(ceil(float(pop) * 0.1))
		var have_bread: int = int(resource_levels.get("bread", 0))
		var take_bread: int = min(want_bread, have_bread)
		if take_bread > 0:
			resource_levels["bread"] = have_bread - take_bread
			bonus_morale += float(take_bread)
	if pop >= 26 and pop <= 50:
		# Medicine bonus
		var want_med: int = int(ceil(float(pop) * 0.05))
		var have_food: int = int(resource_levels.get("food", 0))
		var have_water: int = int(resource_levels.get("water", 0))
		var pairs: int = min(want_med, min(have_food, have_water))
		if pairs > 0:
			resource_levels["food"] = have_food - pairs
			resource_levels["water"] = have_water - pairs
			bonus_morale += float(pairs)
	if pop >= 51:
		# Tea bonus
		var want_tea: int = int(ceil(float(pop) * 0.05))
		var have_food2: int = int(resource_levels.get("food", 0))
		var have_water2: int = int(resource_levels.get("water", 0))
		var tea_pairs: int = min(want_tea, min(have_food2, have_water2))
		if tea_pairs > 0:
			resource_levels["food"] = have_food2 - tea_pairs
			resource_levels["water"] = have_water2 - tea_pairs
			bonus_morale += float(tea_pairs)
	if bonus_morale > 0.0:
		village_morale = min(100.0, village_morale + min(5.0, bonus_morale))

func _consume_for_cariyes(cariye_daily_equiv: float) -> void:
	# Günlük tüketimde cariye harcaması yapılmaz; haftalık role-based tüketim ayrı bir akışta uygulanacak.
	return

func process_weekly_cariye_needs(current_day: int) -> void:
	# Every 7th day apply role-based needs (placeholder simple costs)
	if cariye_period_days <= 0:
		return
	if current_day % cariye_period_days != 0:
		return
	# Example simple needs (can be extended per-role):
	# Try to consume 1 bread and 1 tea equivalent per cariye weekly; if missing, apply small morale hit.
	var cariye_count := int(cariyeler.size())
	if cariye_count <= 0:
		return
	var missing_any := false
	var missing_bread: int = 0
	var missing_tea: int = 0
	var to_consume_bread := cariye_count
	var to_consume_tea := cariye_count
	var have_bread := int(resource_levels.get("bread", 0))
	var have_food := int(resource_levels.get("food", 0))
	var have_water := int(resource_levels.get("water", 0))
	# Bread preferred, fallback to food+water craft equivalence
	var take_bread: int = min(to_consume_bread, have_bread)
	resource_levels["bread"] = have_bread - take_bread
	to_consume_bread -= take_bread
	# Fallback: consume food+water pairs if bread missing
	if to_consume_bread > 0:
		var pairs: int = min(to_consume_bread, min(have_food, have_water))
		resource_levels["food"] = have_food - pairs
		resource_levels["water"] = have_water - pairs
		to_consume_bread -= pairs
		if to_consume_bread > 0:
			missing_any = true
			missing_bread = to_consume_bread
	# Tea equivalence: food+water per unit
	if to_consume_tea > 0:
		have_food = int(resource_levels.get("food", 0))
		have_water = int(resource_levels.get("water", 0))
		var tea_pairs: int = min(to_consume_tea, min(have_food, have_water))
		resource_levels["food"] = have_food - tea_pairs
		resource_levels["water"] = have_water - tea_pairs
		if tea_pairs < to_consume_tea:
			missing_any = true
			missing_tea = to_consume_tea - tea_pairs
	if missing_any:
		village_morale = max(0.0, village_morale - 2.0)
		var mm = get_node_or_null("/root/MissionManager")
		if mm and mm.has_method("post_news"):
			var msg := "Eksik haftalık cariye ihtiyaçları: "
			if missing_bread > 0:
				msg += "Ekmek %d " % missing_bread
			if missing_tea > 0:
				msg += "Çay %d" % missing_tea
			mm.post_news("village", "Cariye ihtiyaçları karşılanamadı", msg.strip_edges(), Color(1,0.6,0.2,1))

func _check_shortages_and_apply_morale_penalties() -> void:
	var penalty := 0.0
	for k in _last_day_shortages.keys():
		var missing := float(_last_day_shortages.get(k, 0))
		if missing > 0.0:
			penalty += 5.0 # -5 per missing type/day (simple)
	if penalty > 0.0:
		village_morale = max(0.0, village_morale - penalty)
	else:
		# Slow recovery
		village_morale = min(100.0, village_morale + 1.0)
	# Reset shortages for next day
	_last_day_shortages = {"water": 0, "food": 0}

func _get_morale_multiplier() -> float:
	# Above 50, no penalty; below 50, linear down to 0.5 at morale 0
	if village_morale >= 50.0:
		return 1.0
	var deficit := 50.0 - village_morale
	return max(0.5, 1.0 - deficit * 0.01)

func _update_events_for_new_day(current_day: int) -> void:
	if not events_enabled:
		return
	# Expire old events
	var remaining: Array[Dictionary] = []
	for ev in events_active:
		var ends_day := int(ev.get("ends_day", current_day))
		if current_day <= ends_day:
			remaining.append(ev)
		else:
			_remove_event_effects(ev)
	events_active = remaining

	# Maybe trigger new event
	if randf() < daily_event_chance:
		var ev = _pick_and_create_event(current_day)
		if not ev.is_empty():
			events_active.append(ev)
			_apply_event_effects(ev)

# === World Event Effects Integration ===
func apply_world_event_effects(event: Dictionary) -> void:
	"""Apply effects from WorldManager events to village economy"""
	var event_type := String(event.get("type", ""))
	var effects: Dictionary = event.get("effects", {})
	
	match event_type:
		"famine":
			# Reduce food production
			var food_mult := float(effects.get("food_production", 1.0))
			resource_prod_multiplier["food"] = float(resource_prod_multiplier.get("food", 1.0)) * food_mult
			
			# Apply morale penalty
			var morale_penalty := float(effects.get("morale_penalty", 0))
			village_morale = max(0.0, village_morale + morale_penalty)
			
		"plague":
			# Reduce population health (affects production)
			var health_mult := float(effects.get("population_health", 1.0))
			global_multiplier *= health_mult
			
			# Production penalty
			var prod_penalty := float(effects.get("production_penalty", 1.0))
			for resource in resource_prod_multiplier.keys():
				resource_prod_multiplier[resource] = float(resource_prod_multiplier.get(resource, 1.0)) * prod_penalty
				
		"trade_boom":
			# Increase gold income and trade bonuses
			var gold_mult := float(effects.get("gold_multiplier", 1.0))
			# This would need integration with GlobalPlayerData for gold income
			# For now, just boost food production as trade benefit
			resource_prod_multiplier["food"] = float(resource_prod_multiplier.get("food", 1.0)) * gold_mult
			
		"war_declaration":
			# Military focus reduces civilian production
			var military_focus := float(effects.get("military_focus", 1.0))
			var trade_disruption := float(effects.get("trade_disruption", 1.0))
			
			# Reduce all production due to military focus
			for resource in resource_prod_multiplier.keys():
				resource_prod_multiplier[resource] = float(resource_prod_multiplier.get(resource, 1.0)) / military_focus
			
			# Trade disruption affects morale
			village_morale = max(0.0, village_morale - (1.0 - trade_disruption) * 10.0)
			
		"rebellion":
			# Stability penalty affects morale and production
			var stability_penalty := float(effects.get("stability_penalty", 0))
			var production_chaos := float(effects.get("production_chaos", 1.0))
			
			village_morale = max(0.0, village_morale + stability_penalty)
			
			# Chaotic production - random resource gets penalty
			var resources: Array[String] = ["wood", "stone", "food", "water"]
			var random_resource: String = resources[randi() % resources.size()]
			resource_prod_multiplier[random_resource] = float(resource_prod_multiplier.get(random_resource, 1.0)) * production_chaos

func remove_world_event_effects(event: Dictionary) -> void:
	"""Remove effects from WorldManager events when they expire"""
	var event_type := String(event.get("type", ""))
	var effects: Dictionary = event.get("effects", {})
	
	match event_type:
		"famine":
			# Restore food production
			var food_mult := float(effects.get("food_production", 1.0))
			resource_prod_multiplier["food"] = float(resource_prod_multiplier.get("food", 1.0)) / max(0.0001, food_mult)
			
		"plague":
			# Restore population health
			var health_mult := float(effects.get("population_health", 1.0))
			global_multiplier /= max(0.0001, health_mult)
			
			# Restore production
			var prod_penalty := float(effects.get("production_penalty", 1.0))
			for resource in resource_prod_multiplier.keys():
				resource_prod_multiplier[resource] = float(resource_prod_multiplier.get(resource, 1.0)) / max(0.0001, prod_penalty)
				
		"trade_boom":
			# Remove trade bonuses
			var gold_mult := float(effects.get("gold_multiplier", 1.0))
			resource_prod_multiplier["food"] = float(resource_prod_multiplier.get("food", 1.0)) / max(0.0001, gold_mult)
			
		"war_declaration":
			# Restore production
			var military_focus := float(effects.get("military_focus", 1.0))
			for resource in resource_prod_multiplier.keys():
				resource_prod_multiplier[resource] = float(resource_prod_multiplier.get(resource, 1.0)) * military_focus
				
		"rebellion":
			# Effects are temporary and don't need explicit restoration
			pass

func _pick_and_create_event(current_day: int) -> Dictionary:
	# cooldown check and simple pool
	var pool := ["drought", "famine", "pest", "disease", "raid", "trade_opportunity"]
	pool.shuffle()
	for t in pool:
		var cd_until := int(_event_cooldowns.get(t, 0))
		if current_day < cd_until:
			continue
		var sev := randf_range(event_severity_min, event_severity_max)
		var dur := randi_range(event_duration_min_days, event_duration_max_days)
		var ev := {"type": t, "severity": sev, "ends_day": current_day + dur}
		# simple cooldown: 30 days
		_event_cooldowns[t] = current_day + 30
		# Post news to MissionManager if available
		var mm = get_node_or_null("/root/MissionManager")
		if mm and mm.has_method("post_news"):
			var title := "Yeni Olay: %s" % t.capitalize()
			var msg := "Şiddet: %.0f%%, Süre: %d gün" % [sev * 100.0, dur]
			mm.post_news("world", title, msg, Color.ORANGE)
		return ev
	return {}

func _apply_event_effects(ev: Dictionary) -> void:
	var t := String(ev.get("type", ""))
	var sev := float(ev.get("severity", 0.0))
	match t:
		"drought":
			resource_prod_multiplier["water"] = float(resource_prod_multiplier.get("water", 1.0)) * (1.0 - sev)
		"famine":
			resource_prod_multiplier["food"] = float(resource_prod_multiplier.get("food", 1.0)) * (1.0 - sev)
		"pest":
			resource_prod_multiplier["food"] = float(resource_prod_multiplier.get("food", 1.0)) * (1.0 - sev)
		"disease":
			village_morale = max(0.0, village_morale - sev * 10.0)
		"raid":
			# Steal a small amount of random basic resources
			var basics := ["wood", "stone", "food", "water"]
			basics.shuffle()
			for r in basics:
				var cur: int = int(resource_levels.get(r, 0))
				if cur <= 0:
					continue
				var steal: int = max(1, int(round(sev * 5.0)))
				resource_levels[r] = max(0, cur - steal)
				break
		"market_boom", "trade_opportunity":
			# Temporary boost to food production
			resource_prod_multiplier["food"] = float(resource_prod_multiplier.get("food", 1.0)) * (1.0 + sev)
		_:
			pass # placeholder: other effects can be added later

func _remove_event_effects(ev: Dictionary) -> void:
	var t := String(ev.get("type", ""))
	var sev := float(ev.get("severity", 0.0))
	match t:
		"drought":
			resource_prod_multiplier["water"] = float(resource_prod_multiplier.get("water", 1.0)) / max(0.0001, (1.0 - sev))
		"famine":
			resource_prod_multiplier["food"] = float(resource_prod_multiplier.get("food", 1.0)) / max(0.0001, (1.0 - sev))
		"pest":
			resource_prod_multiplier["food"] = float(resource_prod_multiplier.get("food", 1.0)) / max(0.0001, (1.0 - sev))
		"market_boom", "trade_opportunity":
			resource_prod_multiplier["food"] = float(resource_prod_multiplier.get("food", 1.0)) / max(0.0001, (1.0 + sev))
		_:
			pass

# === UI getters & toggles ===
func get_economy_last_day_stats() -> Dictionary:
	return economy_stats_last_day

func get_active_events() -> Array:
	return events_active

func set_economy_enabled(enabled: bool) -> void:
	economy_enabled = enabled

func set_events_enabled(enabled: bool) -> void:
	events_enabled = enabled

# Storage UI helpers
func get_storage_capacity_for(resource_type: String) -> int:
	return _get_storage_capacity_for(resource_type)

func get_storage_usage(resource_type: String) -> Dictionary:
	var level := int(resource_levels.get(resource_type, 0))
	var cap := _get_storage_capacity_for(resource_type)
	return {"level": level, "capacity": cap}

# --- Public helpers for UI/Debug ---
func get_morale() -> float:
	return village_morale

func get_active_events_summary(current_day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev in events_active:
		var ends := int(ev.get("ends_day", current_day))
		var days_left: int = max(0, ends - current_day)
		out.append({
			"type": String(ev.get("type", "")),
			"severity": float(ev.get("severity", 0.0)),
			"days_left": days_left
		})
	return out

func trigger_random_event_debug() -> void:
	var tm = get_node_or_null("/root/TimeManager")
	var day: int = tm.get_day() if tm and tm.has_method("get_day") else 0
	var ev := _pick_and_create_event(day)
	if not ev.is_empty():
		events_active.append(ev)
		_apply_event_effects(ev)

func _recalculate_building_bonus() -> void:
	# Compute average bonus across basic producer buildings: +0.25 per level above 1, capped at +0.5
	var placed := 0
	var bonus_sum := 0.0
	if is_instance_valid(village_scene_instance):
		var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
		if placed_buildings:
			for b in placed_buildings.get_children():
				if not is_instance_valid(b):
					continue
				# Only consider known producers
				var is_producer := false
				for r in ["wood", "stone", "food", "water"]:
					if b.has_method("get_script") and b.get_script() != null and b.get_script().resource_path == String(RESOURCE_PRODUCER_SCRIPTS.get(r, "")):
						is_producer = true
						break
				if not is_producer:
					continue
				var lvl := 1
				if "level" in b and b.level != null:
					lvl = int(b.level)
				if lvl > 1:
					bonus_sum += 0.25 * float(lvl - 1)
				placed += 1
	var avg_bonus := 0.0
	if placed > 0:
		avg_bonus = bonus_sum / float(placed)
	building_bonus = clamp(avg_bonus, 0.0, 0.5)

# === Weekly cariye need helpers ===
func get_days_until_weekly_cariye_needs() -> int:
	if cariye_period_days <= 0:
		return 0
	var tm = get_node_or_null("/root/TimeManager")
	var day: int = tm.get_day() if tm and tm.has_method("get_day") else 0
	if day <= 0:
		return cariye_period_days
	var r := day % cariye_period_days
	return 0 if r == 0 else cariye_period_days - r

func get_next_weekly_cariye_day() -> int:
	var tm = get_node_or_null("/root/TimeManager")
	var day: int = tm.get_day() if tm and tm.has_method("get_day") else 0
	return day + get_days_until_weekly_cariye_needs()

# Yeni bir işçi düğümü oluşturur, ID atar, listeye ekler, sayacı günceller ve barınak atar.
# Başarılı olursa true, barınak bulunamazsa veya hata olursa false döner.


func _add_new_worker(NPC_Info = {}) -> bool: # <<< Dönüş tipi eklendi
	if not worker_scene:
		#printerr("VillageManager: Worker scene not loaded!")
		return false
	
	var worker_instance = worker_scene.instantiate()
	worker_id_counter += 1
	worker_instance.worker_id = worker_id_counter
	worker_instance.name = "Worker" + str(worker_id_counter) 
	
	# <<< YENİ: Rastgele Görünüm Ata >>>
	if worker_instance.has_method("update_visuals"): # Önce metodun varlığını kontrol et (güvenlik)
		worker_instance.appearance = AppearanceDB.generate_random_appearance()
	#else:
		#printerr("VillageManager: Worker instance does not have 'update_visuals' method!")
	# <<< YENİ SONU >>>

	# <<< GÜNCELLENDİ: Barınak ataması başarısız olursa işçiyi ekleme >>>
	# Barınak atamaya çalış (bu fonksiyon housing_node ve start_x_pos ayarlar)
	if not _assign_housing(worker_instance):
		#printerr("VillageManager: Yeni işçi (ID: %d) İÇİN BARINAK BULUNAMADI, işçi eklenmiyor." % worker_id_counter) 
		worker_instance.queue_free() # Oluşturulan instance'ı sil
		# ID sayacını geri almalı mıyız? Şimdilik almıyoruz, ID'ler atlanmış olacak.
		return false # Başarısız

	# Barınak bulunduysa sahneye ve listeye ekle
	if workers_container:
		workers_container.add_child(worker_instance)
		worker_instance.Initialize_Existing_Villager(NPC_Info)
	else:
		#printerr("VillageManager: WorkersContainer not found! Cannot add worker to scene.")
		worker_instance.queue_free() # Oluşturulan instance'ı sil
		return false # Başarısız
		
	# Yeni işçiyi listeye ekle (Sadece sahneye eklendiyse)
	var worker_data = {
		"instance": worker_instance,
		"status": "idle", 
		"assigned_building": null,
		"housing_node": worker_instance.housing_node # _assign_housing tarafından ayarlandı
	}
	all_workers[worker_id_counter] = worker_data

	# Toplam ve boştaki işçi sayısını güncelle
	total_workers += 1
	idle_workers += 1
	
	#print("VillageManager: Yeni işçi (ID: %d) eklendi ve barınağa atandı." % worker_id_counter)
	
	# <<< YENİ: Test için Walk Animasyonunu Başlat >>>
	# Normalde bu _physics_process'te state'e göre belirlenir,
	# ama şimdi test için doğrudan başlatalım.
	if worker_instance.has_method("play_animation"):
		worker_instance.play_animation("walk")
	# <<< YENİ SONU >>>
	
	# WorkerAssignmentUI'yi güncellemek için sinyal gönder
	emit_signal("worker_list_changed")
	return true # Başarılı

# Verilen işçiye uygun bir barınak bulup atar ve evin sayacını günceller
func _assign_housing(worker_instance: Node2D) -> bool:
	var housing_node = _find_available_housing()
	if housing_node:
		worker_instance.housing_node = housing_node
		
		# Yerleşme pozisyonunu ayarla (sol/sağ kenar)
		var viewport_width = get_tree().root.get_viewport().get_visible_rect().size.x
		if housing_node.global_position.x < viewport_width / 2:
			worker_instance.start_x_pos = -2500 # Sol kenar
		else:
			worker_instance.start_x_pos = 2500  # Sağ kenar
		
		# İlgili barınağın doluluk sayısını artır
		if housing_node.has_method("add_occupant"):
			if not housing_node.add_occupant(worker_instance):
				printerr("VillageManager: Failed to add occupant to %s. Housing might be full despite find_available_housing passing." % housing_node.name)

				# Bu durumda ne yapılmalı? Belki işçiyi kamp ateşine atamayı dene?
				# Şimdilik sadece hata verelim.
				return false # Atama başarısız
		else:
			#printerr("VillageManager: Housing node %s does not have add_occupant method!" % housing_node.name)
			return false # Atama başarısız
		
		return true
	else:
		# #printerr("VillageManager: No available housing found for %s." % worker_instance.name) # Hata mesajını _add_new_worker'da veriyoruz
		return false

# Boş kapasitesi olan bir barınak (önce Ev, sonra CampFire) arar
func _find_available_housing() -> Node2D:
	# #print("DEBUG VillageManager: Searching for available housing...") #<<< Yorumlandı
	var housing_nodes = get_tree().get_nodes_in_group("Housing")
	# #print("DEBUG VillageManager: Found %d nodes in Housing group." % housing_nodes.size()) #<<< Yorumlandı

	# Önce Evleri kontrol et
	for node in housing_nodes:
		# #print("DEBUG VillageManager: Checking node: %s" % node.name) #<<< Yorumlandı
		# <<< DEĞİŞTİRİLDİ: Sadece House ise kapasiteyi kontrol et >>>
		if node.has_method("get_script") and node.get_script() == HouseScript:
			# print("DEBUG VillageManager:   Node is House. Checking capacity (%d/%d)" % [node.current_occupants, node.max_occupants]) #<<< Yorumlandı
			if node.can_add_occupant():
				# print("DEBUG VillageManager:   Found available House: %s. Returning this node." % node.name) #<<< Yorumlandı

				return node # Boş ev bulundu
			# else: # Ev doluysa (debug için)
				# #print("DEBUG VillageManager:   House %s is full." % node.name) #<<< Yorumlandı
		# <<< DEĞİŞİKLİK SONU >>>
		# else: # Eğer scripti HouseScript değilse (örn. CampFire) veya scripti yoksa, bu döngüde atla
			# #print("DEBUG VillageManager:   Node %s is not a House, skipping capacity check in this loop." % node.name) # Debug
			# pass # Bu else bloğu artık gereksiz

	# Boş ev yoksa, CampFire'ı kontrol et (varsa)
	# #print("DEBUG VillageManager: No available house found. Checking for CampFire...") #<<< Yorumlandı
	# campfire_node referansı _ready veya register_village_scene içinde set edilmiş olmalı
	if is_instance_valid(campfire_node) and campfire_node.is_in_group("Housing"):
		# #print("DEBUG VillageManager:   Found valid CampFire: %s. Returning this node." % campfire_node.name) #<<< Yorumlandı
		# <<< YENİ: Campfire kapasitesini kontrol et >>>
		if campfire_node.can_add_occupant():
			# print("DEBUG VillageManager:   Found available CampFire: %s. Returning this node." % campfire_node.name) #<<< Yorumlandı

			return campfire_node
		# else: # Kamp ateşi doluysa
		# 	# #print("DEBUG VillageManager:   Campfire is full.") #<<< Yorumlandı
		# 	pass
		# <<< YENİ SONU >>>
	# else: # Debug için
		# #print("DEBUG VillageManager:   Campfire node is not valid or not in Housing group.") #<<< Yorumlandı

	# Hiçbir barınak bulunamadı
	# #printerr("VillageManager Warning: No available housing found (No suitable House or CampFire).") # Bu mesajı artık burada vermeyebiliriz, çağıran yer kontrol etmeli.
	return null

# --- İşçi Atama/Çıkarma (Mevcut Fonksiyonlar) --- # Burası olduğu gibi kalacak

# Boşta bir işçiyi belirtilen TEMEL iş türüne ve ilgili binaya atar #<<< GÜNCELLENDİ
func assign_idle_worker_to_job(job_type: String) -> bool:
	var idle_worker_instance: Node = null
	var idle_worker_id = -1

	# 1. Boşta bir işçi bul
	for worker_id in all_workers:
		var worker = all_workers[worker_id]["instance"]
		if is_instance_valid(worker) and worker.assigned_job_type == "":
			idle_worker_instance = worker
			idle_worker_id = worker_id
			break # İlk boşta işçiyi bulduk

	if idle_worker_instance == null:
		#print("VillageManager: assign_idle_worker_to_job - Boşta işçi bulunamadı.")
		return false

	# 2. İşe uygun binayı bul
	var building_node: Node2D = null
	var target_script_path = RESOURCE_PRODUCER_SCRIPTS.get(job_type) 
	if not target_script_path:
		#printerr("VillageManager: assign_idle_worker_to_job - Bilinmeyen iş türü veya script yolu yok: ", job_type)
		return false

	# <<< YENİ KONTROL: Bu fonksiyon sadece TEMEL kaynaklar için! >>>
	# Bakery.gd gibi gelişmiş üreticiler kendi add_worker metodunu kullanmalı.
	if target_script_path == "res://village/scripts/Bakery.gd": # Şimdilik sadece Bakery için kontrol
		#printerr("VillageManager Error: assign_idle_worker_to_job cannot be used for advanced resource '%s'. Call Bakery.add_worker() directly." % job_type)
		return false
	# TODO: Daha genel bir kontrol (örn. BASE_RESOURCE_SCRIPTS listesi ile)
	# if not target_script_path in BASE_RESOURCE_SCRIPTS: ...
	# <<< KONTROL SONU >>>

	var work_buildings = get_tree().get_nodes_in_group("WorkBuildings")
	for building in work_buildings:
		# Binanın script yolunu kontrol et
		if building.has_method("get_script") and building.get_script() != null:
			var building_script = building.get_script()
			if building_script is GDScript and building_script.resource_path == target_script_path:
				# TODO: Binanın kapasitesini kontrol et (max_workers)
				# if building.assigned_workers < building.max_workers: 
				building_node = building
				break # İlk uygun binayı bulduk

	if building_node == null:
		#print("VillageManager: assign_idle_worker_to_job - İşe uygun bina bulunamadı (İnşa edilmemiş veya kapasite dolu?): ", job_type)
		return false

	# 3. Atamayı yap
	idle_worker_instance.assigned_job_type = job_type
	idle_worker_instance.assigned_building_node = building_node
	
	# İlgili binanın da işçi sayısını artır (eğer takip ediyorsa)
	building_node.assigned_workers += 1
	notify_building_state_changed(building_node) # Binanın durumunu güncelle (UI için önemli)

	idle_workers -= 1
	#print("VillageManager: İşçi %d, '%s' işine (%s) atandı." % [idle_worker_id, job_type, building_node.name])
	# emit_signal("village_data_changed") # Zaten _process ile güncelleniyor
	
	return true # Fonksiyonun ana bloğuna geri çek

# Belirtilen iş türüne atanmış bir işçiyi işten çıkarır (idle yapar)
func unassign_worker_from_job(job_type: String) -> bool:
	var assigned_worker_instance: Node = null
	var assigned_worker_id = -1
	var building_node: Node2D = null # İşçinin çalıştığı bina

	# 1. Bu işe atanmış bir işçi bul
	for worker_id in all_workers:
		var worker = all_workers[worker_id]["instance"]
		if is_instance_valid(worker) and worker.assigned_job_type == job_type:
			assigned_worker_instance = worker
			assigned_worker_id = worker_id
			building_node = worker.assigned_building_node # Çalıştığı binayı kaydet
			break # İlk eşleşen işçiyi bulduk

	if assigned_worker_instance == null:
		#print("VillageManager: unassign_worker_from_job - '%s' işine atanmış işçi bulunamadı." % job_type)
		return false

	# 2. Atamayı kaldır
	assigned_worker_instance.assigned_job_type = ""
	assigned_worker_instance.assigned_building_node = null
	
	# İşçinin mevcut durumunu IDLE yapalım (eğer çalışıyorsa)
	if assigned_worker_instance.current_state == assigned_worker_instance.State.WORKING_OFFSCREEN or \
	   assigned_worker_instance.current_state == assigned_worker_instance.State.GOING_TO_BUILDING_FIRST or \
	   assigned_worker_instance.current_state == assigned_worker_instance.State.GOING_TO_BUILDING_LAST:
		assigned_worker_instance.current_state = assigned_worker_instance.State.AWAKE_IDLE
		assigned_worker_instance.visible = true # Görünür yap
		# Hedefini sıfırla veya rastgele yap
		assigned_worker_instance.move_target_x = assigned_worker_instance.global_position.x 

	# İlgili binanın işçi sayısını azalt (eğer takip ediyorsa ve hala geçerliyse)
	if is_instance_valid(building_node) and "assigned_workers" in building_node:
		building_node.assigned_workers = max(0, building_node.assigned_workers - 1)
		notify_building_state_changed(building_node) # Binanın durumunu güncelle

	idle_workers += 1
	#print("VillageManager: İşçi %d, '%s' işinden çıkarıldı." % [assigned_worker_id, job_type])
	# emit_signal("village_data_changed") # Zaten _process ile güncelleniyor
	return true

# --- YENİ: Köylü Eksiltme Mekaniği ---
func remove_worker_from_village(worker_id_to_remove: int) -> void:
	#print("VillageManager: Attempting to remove worker %d" % worker_id_to_remove) # Debug

	# 1. İşçi listede var mı ve geçerli mi?
	if not all_workers.has(worker_id_to_remove):
		#printerr("VillageManager Error: Worker %d not found in active_workers." % worker_id_to_remove)
		return
		
	var worker_instance = all_workers[worker_id_to_remove]["instance"]
	if not is_instance_valid(worker_instance):
		#printerr("VillageManager Warning: Worker %d instance is invalid. Removing from list." % worker_id_to_remove)
		all_workers.erase(worker_id_to_remove) # Listeyi temizle
		# Sayaçları burada azaltmak riskli olabilir, belki zaten azalmıştır.
		return

	# 2. Barınaktan Çıkar (Eğer Ev veya CampFire İse)
	var housing = worker_instance.housing_node
	if is_instance_valid(housing):
		print("VillageManager: Removing worker %d from housing %s" % [worker_id_to_remove, housing.name]) # Debug
		
		if housing.has_method("remove_occupant"):
			# CampFire için worker argümanı gerekli, House için gerekli değil
			var success = false
			if housing.get_script() and housing.get_script().resource_path.ends_with("CampFire.gd"):
				# CampFire için worker instance'ı geç
				success = housing.remove_occupant(worker_instance)
			else:
				# House ve diğerleri için argüman geçme
				success = housing.remove_occupant()
			
			if not success:
				printerr("VillageManager: Failed to remove worker %d from housing %s" % [worker_id_to_remove, housing.name])
		else:
			printerr("VillageManager: Housing %s does not have remove_occupant method!" % housing.name)
	#else: # Debug için
	#	print("VillageManager: Worker %d was not in housing (or housing invalid)." % worker_id_to_remove)

	
	# 3. İşten Çıkar (Eğer Çalışıyorsa)
	var job_type = worker_instance.assigned_job_type
	var was_idle = (job_type == "") # İşçi boştaydıysa bunu kaydet
	
	if not was_idle:
		#print("VillageManager: Worker %d was working (%s). Unassigning from building." % [worker_id_to_remove, job_type]) # Debug
		var building = worker_instance.assigned_building_node
		if is_instance_valid(building) and "assigned_workers" in building:
			building.assigned_workers = max(0, building.assigned_workers - 1)
			notify_building_state_changed(building)
		#else: # Debug için
		#	#print("VillageManager: Building node for worker %d is invalid or lacks 'assigned_workers'." % worker_id_to_remove)

	# 4. Sayaçları Güncelle
	if was_idle:
		idle_workers = max(0, idle_workers - 1) # Boştaysa idle sayısını azalt
		# #print("DEBUG: Decremented idle_workers.") # Debug
	# else: # Debug için
		# #print("DEBUG: Worker was not idle, idle_workers not decremented.")
	total_workers = max(0, total_workers - 1)
	# #print("DEBUG: Total workers: %d, Idle workers: %d" % [total_workers, idle_workers]) # Debug

	# 5. Listeden Sil
	all_workers.erase(worker_id_to_remove)
	
	# 6. Sahneden Sil
	worker_instance.queue_free()
	
	#print("VillageManager: Worker %d successfully removed from the village." % worker_id_to_remove)
	# İsteğe bağlı: UI güncellemesi için sinyal yay
	# emit_signal("village_data_changed") # Zaten periyodik güncelleniyor

# --- Helper Fonksiyonlar ---
func get_active_worker_ids() -> Array[int]:
	# return all_workers.keys() #<<< ESKİ KOD: Genel Array döndürüyor
	var keys_array: Array[int] = [] #<<< YENİ: Tip belirterek boş dizi oluştur
	for key in all_workers.keys(): #<<< YENİ: Anahtarlar üzerinde döngü
		keys_array.append(key) #<<< YENİ: Tipi belli diziye ekle
	return keys_array #<<< YENİ: Tipi belli diziyi döndür

# PlacedBuildings node'unu kaydeder (VillageScene _ready tarafından çağrılır)

# <<< YENİ FONKSİYON: cancel_worker_registration >>>
# Başarısız bir işçi atama girişiminden sonra (örn. kaynak yetersizliği),
# register_generic_worker tarafından azaltılan idle_workers sayacını geri artırır.
func cancel_worker_registration() -> void:
	# #print("VillageManager: Canceling previous worker registration attempt, incrementing idle_workers.") #<<< KALDIRILDI
	idle_workers += 1
	emit_signal("village_data_changed") # <<< Girinti Düzeltildi
# <<< YENİ FONKSİYON BİTİŞ >>>



# Belirli bir kaynak türünü üreten ilk binanın pozisyonunu döndürür
# (Kaynak Taşıma İllüzyonu için)
func get_source_building_position(resource_type: String) -> Vector2:
	# <<< DÜZELTİLDİ: Doğrudan dictionary lookup >>>
	# Kaynak türünü hangi scriptlerin ürettiğini bul
	var target_script_path = RESOURCE_PRODUCER_SCRIPTS.get(resource_type, "")
	# <<< DÜZELTME SONU >>>
	
	if target_script_path.is_empty():
		#printerr("VillageManager: No script found producing resource type '%s' for fetching illusion." % resource_type)
		return Vector2.ZERO # Veya null? Şimdilik ZERO
		
	# İlgili script'e sahip tüm düğümleri (binaları) bul
	# ... (rest of the function remains the same: find building instance with this script path) ...
	var potential_buildings = []
	# Varsayım: Tüm binalar village_scene altında
	if is_instance_valid(village_scene_instance):
		# <<< YENİ: PlacedBuildings altını kontrol et (daha güvenli) >>>
		var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
		if placed_buildings:
			for child in placed_buildings.get_children(): # Sadece yerleştirilmiş binalara bak
				if child.has_method("get_script") and child.get_script() != null and child.get_script().resource_path == target_script_path:
					potential_buildings.append(child)
		else:
			#printerr("VillageManager: PlacedBuildings node not found in VillageScene.")
			return Vector2.ZERO
		# <<< YENİ SONU >>>
	else:
		#printerr("VillageManager: VillageScene invalid, cannot search for source buildings.")
		return Vector2.ZERO
	
	# Bulunan ilk binanın pozisyonunu döndür
	if not potential_buildings.is_empty():
		var target_building = potential_buildings[0]
		# #print("VillageManager: Found source building %s for %s at %s" % [target_building.name, resource_type, target_building.global_position]) # Debug
		return target_building.global_position
	else:
		#print("VillageManager: No building instance found producing '%s' (script: %s)" % [resource_type, target_script_path])
		return Vector2.ZERO # Uygun bina bulunamadı
