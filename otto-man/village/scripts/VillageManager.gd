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
	# Gelişmiş binalar seviye ve altın isteyebilir (örnek)
	"res://village/buildings/Bakery.tscn": {"requires_level": {"food": 1}, "cost": {"gold": 50}},
	"res://village/buildings/House.tscn": {"cost": {"gold": 50,"wood": 1, "stone": 1}} #<<< YENİ EV MALİYETİ
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

# Sinyaller
signal village_data_changed
signal resource_produced(resource_type, amount)
signal worker_assigned(building_node, resource_type)
signal worker_removed(building_node, resource_type)
signal cariye_data_changed
signal gorev_data_changed
signal building_state_changed(building_node)

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

const STARTING_WORKER_COUNT = 5 # Başlangıç işçi sayısı
# ---------------------

func _ready() -> void:
	# Oyun başlangıcında boşta işçi sayısını toplam işçi sayısına eşitle
	idle_workers = total_workers
	# Kaynak seviyelerini sıfırla (emin olmak için) - Ekmek eklendi
	resource_levels = { "wood": 0, "stone": 0, "food": 0, "water": 0, "metal": 0, "bread": 0 }
	locked_resource_levels = { "wood": 0, "stone": 0, "food": 0, "water": 0, "metal": 0 }
	_create_debug_cariyeler()
	_create_debug_gorevler()
	# --- YENİ DEBUG #print'LERİ ---
	#print("VillageManager Ready: Cariyeler Count = ", cariyeler.size())
	#print("VillageManager Ready: Gorevler Count = ", gorevler.size())
	# ---------------------------
	#print("VillageManager Ready: Initial resource levels set to 0.")

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

# Bir kaynak türü için toplam çalışan işçi sayısını (seviyeyi) veya üretici sayısını hesaplar
func get_resource_level(resource_type: String) -> int:
	# Kaynak birincil mi (işçi sayısıyla mı belirleniyor)?
	if RESOURCE_PRODUCER_SCRIPTS.has(resource_type):
		# Evet, birincil kaynak. İşçileri say.
		if not village_scene_instance:
			#printerr("VillageManager: get_resource_level (base) - VillageScene referansı yok!")
			return 0

		var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
		if not placed_buildings:
			#printerr("VillageManager: get_resource_level (base) - PlacedBuildings bulunamadı!")
			return 0

		var target_script_path = RESOURCE_PRODUCER_SCRIPTS[resource_type]
		var total_workers_for_resource = 0
		for building in placed_buildings.get_children():
			if building.has_method("get_script") and building.get_script() != null:
				var building_script = building.get_script()
				if building_script is GDScript and building_script.resource_path == target_script_path:
					if "assigned_workers" in building:
						total_workers_for_resource += building.assigned_workers

		return total_workers_for_resource
	else:
		# Hayır, ikincil/gelişmiş kaynak (ekmek vb.). resource_levels'dan oku.
		# Bu değer, register/unregister_advanced_production tarafından güncellenir.
		# #print("DEBUG VillageManager: get_resource_level (advanced) for %s returning %s" % [resource_type, resource_levels.get(resource_type, 0)]) #<<< DEBUG
		return resource_levels.get(resource_type, 0)

# Belirli bir kaynak seviyesinin ne kadarının kullanılabilir (kilitli olmayan) olduğunu döndürür
func get_available_resource_level(resource_type: String) -> int:
	var total_level = get_resource_level(resource_type)
	var locked_level = locked_resource_levels.get(resource_type, 0)
	# #print("DEBUG VillageManager: get_available_resource_level(%s): Total=%d, Locked=%d, Available=%d" % [resource_type, total_level, locked_level, max(0, total_level - locked_level)]) #<<< DEBUG
	return max(0, total_level - locked_level)

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
	return Vector2.INF # Hiç boş plot bulunamadı

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
			#print("VillageManager: Found idle worker (ID: %d), registering." % worker_id) # Debug
			idle_workers -= 1 # Boşta işçi sayısını azalt
			emit_signal("village_data_changed")
			return worker # Boşta olanı döndür

	# Boşta işçi bulunamadıysa hata ver (veya otomatik yeni işçi ekle?)
	#printerr("VillageManager: register_generic_worker - Uygun boşta işçi bulunamadı!")
	return null

# Bir işçiyi tekrar boşta duruma getirir (generic)
func unregister_generic_worker(worker_id: int):
	if all_workers.has(worker_id):
		var worker_data = all_workers[worker_id]
		var worker_instance = worker_data["instance"]
		if not is_instance_valid(worker_instance):
			#printerr("unregister_generic_worker: Worker instance for ID %d is invalid!" % worker_id)
			return

		# --- IDLE CHECK and Conditional Increment --- 
		var needs_to_become_idle = (worker_instance.assigned_job_type != "") 
		# if not needs_to_become_idle: # Artık bu mesajı yazdırmayalım, kafa karıştırıyor
		# 	 #print("VillageManager: Worker (ID: %d) was already idle." % worker_id)
		# -------------------------------------------

		# Binadan çıkar (Bu kısım büyük ölçüde formalite, asıl iş bina scriptinde yapıldı)
		var current_building = worker_instance.assigned_building_node
		if is_instance_valid(current_building):
			# worker_instance.assigned_building = null # Bina scripti zaten yapıyor ama garanti olsun
			# Bina scriptinin remove_worker'ını tekrar çağırmaya gerek yok.
			pass
		# Hata durumunda bile worker instance'ın bina bağlantısını keselim:
		worker_instance.assigned_building_node = null 
		
		# --- Idle Sayısını Artır --- #<<< YENİ YORUM
		idle_workers += 1 #<<< HER ZAMAN ARTIRILACAK
		# #print("VillageManager: Worker %d unregistered. Idle count: %d" % [worker_id, idle_workers]) # DEBUG

		# Eğer işçi bir barınakta kalıyorsa, barınağın doluluk sayısını azalt
		var current_housing = worker_instance.housing_node
		#if is_instance_valid(current_housing):
			#if current_housing.has_method("remove_occupant"):
				#if not current_housing.remove_occupant():
					#printerr("VillageManager: Failed to remove occupant from %s for worker %d." % [current_housing.name, worker_id])
			#else:
				#printerr("VillageManager: Housing node %s does not have remove_occupant method!" % current_housing.name)

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
	total_workers += 1
	idle_workers += 1
	#print("VillageManager: Yeni köylü eklendi. Toplam: %d, Boşta: %d" % [total_workers, idle_workers])
	emit_signal("village_data_changed") # UI güncellensin

# Yeni bir cariye ekler (örn. zindandan kurtarıldığında)
func add_cariye(cariye_data: Dictionary) -> void:
	var id = next_cariye_id
	cariyeler[id] = cariye_data
	# Durumunu 'boşta' olarak ayarlayalım
	cariyeler[id]["durum"] = "boşta" 
	next_cariye_id += 1
	#print("VillageManager: Yeni cariye eklendi: ", cariye_data.get("isim", "İsimsiz"), " (ID: ", id, ")")
	emit_signal("cariye_data_changed")

# Yeni bir görev tanımı ekler
func add_gorev(gorev_data: Dictionary) -> void:
	var id = next_gorev_id
	gorevler[id] = gorev_data
	next_gorev_id += 1
	#print("VillageManager: Yeni görev eklendi: ", gorev_data.get("isim", "İsimsiz"), " (ID: ", id, ")")
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

	if successful:
		#print("  -> Görev Başarılı!")
		var oduller = gorev.get("odul", {})
		#print("     Ödüller: ", oduller)
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
		#print("  -> Görev Başarısız!")
		var cezalar = gorev.get("ceza", {})
		#print("     Cezalar: ", cezalar)
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

# Yeni bir işçi düğümü oluşturur, ID atar, listeye ekler, sayacı günceller ve barınak atar.
# Başarılı olursa true, barınak bulunamazsa veya hata olursa false döner.


func _add_new_worker(NPC_Info:Dictionary = {}) -> bool: # <<< Dönüş tipi eklendi
	if not worker_scene:
		#printerr("VillageManager: Worker scene not loaded!")
		return false
	
	var worker_instance = worker_scene.instantiate()
	worker_id_counter += 1
	worker_instance.worker_id = worker_id_counter
	worker_instance.name = "Worker" + str(worker_id_counter) 
	worker_instance.NPC_Info = NPC_Info
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
			if not housing_node.add_occupant():
				#printerr("VillageManager: Failed to add occupant to %s. Housing might be full despite find_available_housing passing." % housing_node.name)
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
			# #print("DEBUG VillageManager:   Node is House. Checking capacity (%d/%d)" % [node.current_occupants, node.max_occupants]) #<<< Yorumlandı
			if node.can_house_worker():
				# #print("DEBUG VillageManager:   Found available House: %s. Returning this node." % node.name) #<<< Yorumlandı
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
		if campfire_node.can_house_worker():
			# #print("DEBUG VillageManager:   Found available CampFire: %s. Returning this node." % campfire_node.name) #<<< Yorumlandı
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

	# 2. Barınaktan Çıkar (Eğer Ev İse)
	var housing = worker_instance.housing_node
	if is_instance_valid(housing) and housing.get_script() == HouseScript:
		#print("VillageManager: Removing worker %d from House %s" % [worker_id_to_remove, housing.name]) # Debug
		housing.remove_occupant()
	#else: # Debug için
	#	#print("VillageManager: Worker %d was not in a House (or housing invalid)." % worker_id_to_remove)
	
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("add_worker_debug"): 
		#print("DEBUG: 'N' key pressed, attempting to add new worker.")
		
		# <<< GÜNCELLENDİ: Ön kontrol kaldırıldı, _add_new_worker kontrolü yeterli >>>
		if not _add_new_worker():
			# _add_new_worker zaten hata mesajı yazdırıyor.
			# #print("VillageManager: Failed to add new worker via N key (likely no housing).")
			pass 
		# <<< GÜNCELLEME SONU >>>

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
