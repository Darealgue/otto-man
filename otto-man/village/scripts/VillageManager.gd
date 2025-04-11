extends Node

# --- YENİ: Bina Gereksinimleri --- (COSTS yerine REQUIREMENTS)
const BUILDING_REQUIREMENTS = {
	# Temel binalar için sadece altın maliyeti (veya 0)
	# Doğru yollar kullanılıyor: village/buildings/
	"res://village/buildings/WoodcutterCamp.tscn": {"cost": {"gold": 5}}, # Örnek - AYARLA!
	"res://village/buildings/StoneMine.tscn": {"cost": {"gold": 5}},
	"res://village/buildings/HunterGathererHut.tscn": {"cost": {"gold": 5}},
	"res://village/buildings/Well.tscn": {"cost": {"gold": 10}},
	# Gelişmiş binalar seviye ve altın isteyebilir (örnek)
	"res://village/buildings/Bakery.tscn": {"requires_level": {"food": 1}, "cost": {"gold": 50}} 
}

# --- VillageScene Referansı ---
var village_scene_instance: Node2D = null

# Toplam işçi sayısı (Başlangıçta örnek bir değer)
var total_workers: int = 3 
# Boşta bekleyen işçi sayısı
var idle_workers: int = 3 

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

# Kaynak SEVİYELERİNİN kilitlenen kısmı (Yükseltmeler için kullanılabilir)
# Şimdilik inşaat için kullanılmıyor.
var locked_resource_levels: Dictionary = {
	"wood": 0,
	"stone": 0,
	"food": 0,
	"water": 0,
	"metal": 0
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

func _ready() -> void:
	# Oyun başlangıcında boşta işçi sayısını toplam işçi sayısına eşitle
	idle_workers = total_workers
	# Kaynak seviyelerini sıfırla (emin olmak için) - Ekmek eklendi
	resource_levels = { "wood": 0, "stone": 0, "food": 0, "water": 0, "metal": 0, "bread": 0 }
	locked_resource_levels = { "wood": 0, "stone": 0, "food": 0, "water": 0, "metal": 0 }
	_create_debug_cariyeler()
	_create_debug_gorevler()
	# --- YENİ DEBUG PRINT'LERİ ---
	print("VillageManager Ready: Cariyeler Count = ", cariyeler.size())
	print("VillageManager Ready: Gorevler Count = ", gorevler.size())
	# ---------------------------
	print("VillageManager Ready: Initial resource levels set to 0.")

# --- Kaynak Seviyesi Hesaplama (YENİ) ---

# Belirli bir kaynak türünü üreten Tescilli Script Yolları
# Bu, get_resource_level için gereklidir
const RESOURCE_PRODUCER_SCRIPTS = {
	"wood": "res://village/scripts/WoodcutterCamp.gd",
	"stone": "res://village/scripts/StoneMine.gd",
	"food": "res://village/scripts/HunterGathererHut.gd", # Veya Tarla/Balıkçı vb.
	"water": "res://village/scripts/Well.gd",
	"metal": "res://village/scripts/StoneMine.gd" # Veya ayrı metal madeni?
}

# Bir kaynak türü için toplam çalışan işçi sayısını (seviyeyi) hesaplar
func get_resource_level(resource_type: String) -> int:
	if not village_scene_instance:
		printerr("VillageManager: get_resource_level - VillageScene referansı yok!")
		return 0

	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		printerr("VillageManager: get_resource_level - PlacedBuildings bulunamadı!")
		return 0

	var target_script_path = RESOURCE_PRODUCER_SCRIPTS.get(resource_type)
	if not target_script_path:
		# Gelişmiş kaynaklar (ekmek vb.) veya metal gibi özel durumlar?
		# Şimdilik 0 döndür veya farklı bir mantık uygula.
		# print("VillageManager: get_resource_level - Bilinmeyen kaynak türü veya üretici scripti yok: ", resource_type)
		return resource_levels.get(resource_type, 0) # Ekmek gibi stoklananlar için?

	var total_workers_for_resource = 0
	for building in placed_buildings.get_children():
		# Bina scriptinin yolunu al (varsa)
		if building.has_method("get_script") and building.get_script() != null:
			var building_script = building.get_script()
			if building_script is GDScript and building_script.resource_path == target_script_path:
				# Doğru türde bina bulundu, işçi sayısını al (varsayım: 'assigned_workers' özelliği var)
				if "assigned_workers" in building:
					total_workers_for_resource += building.assigned_workers

	return total_workers_for_resource

# Belirli bir kaynak seviyesinin ne kadarının kullanılabilir (kilitli olmayan) olduğunu döndürür
func get_available_resource_level(resource_type: String) -> int:
	var total_level = get_resource_level(resource_type)
	var locked_level = locked_resource_levels.get(resource_type, 0)
	return max(0, total_level - locked_level)

# --- Seviye Kilitleme (Yükseltmeler için - Şimdilik İnşaatta Kullanılmıyor) ---

# Belirli bir kaynak seviyesini kilitlemeye çalışır
func lock_resource_level(resource_type: String, level_to_lock: int) -> bool:
	if get_available_resource_level(resource_type) >= level_to_lock:
		locked_resource_levels[resource_type] = locked_resource_levels.get(resource_type, 0) + level_to_lock
		print("VillageManager: Kilitlendi - %s Seviye: %d" % [resource_type, level_to_lock])
		emit_signal("village_data_changed")
		return true
	else:
		print("VillageManager: Kilitlenemedi - Yetersiz %s Seviyesi (İstenen: %d, Mevcut: %d)" % [resource_type, level_to_lock, get_available_resource_level(resource_type)])
		return false

# Kilitli kaynak seviyesini serbest bırakır
func unlock_resource_level(resource_type: String, level_to_unlock: int) -> void:
	var current_lock = locked_resource_levels.get(resource_type, 0)
	locked_resource_levels[resource_type] = max(0, current_lock - level_to_unlock)
	print("VillageManager: Kilit Açıldı - %s Seviye: %d" % [resource_type, level_to_unlock])
	emit_signal("village_data_changed")

# --- İnşa Yönetimi (Düzeltilmiş) ---

# VillageScene tarafından çağrılır
func register_village_scene(scene: Node2D) -> void:
	village_scene_instance = scene
	print("VillageManager: VillageScene kaydedildi.")

# --- Bina Yönetimi ---
# Belirtilen sahne yoluna sahip bir binanın zaten var olup olmadığını kontrol eder
func does_building_exist(building_scene_path: String) -> bool:
	if not village_scene_instance:
		printerr("VillageManager: does_building_exist - VillageScene referansı yok!")
		return false # Hata durumu, var kabul etmeyelim?

	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		printerr("VillageManager: does_building_exist - PlacedBuildings bulunamadı!")
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
		printerr("VillageManager: Bilinmeyen bina gereksinimi: ", building_scene_path)
		return false

	# 1. Altın Maliyetini Kontrol Et
	var cost = requirements.get("cost", {})
	var gold_cost = cost.get("gold", 0)
	if GlobalPlayerData.gold < gold_cost:
		print("DEBUG VillageManager: Yetersiz Altın (Gereken: %d, Mevcut: %d)" % [gold_cost, GlobalPlayerData.gold])
		return false

	# 2. Gerekli Kaynak Seviyelerini Kontrol Et
	var required_levels = requirements.get("requires_level", {})
	for resource_type in required_levels:
		var required_level = required_levels[resource_type]
		# Kullanılabilir (kilitli olmayan) seviyeyi kontrol et
		var available_level = get_available_resource_level(resource_type)
		if available_level < required_level:
			print("DEBUG VillageManager: Yetersiz %s Seviyesi (Gereken: %d, Mevcut Kullanılabilir: %d)" % [resource_type, required_level, available_level])
			return false

	#print("DEBUG VillageManager: Tüm gereksinimler karşılanıyor.")
	return true # Tüm gereksinimler tamam

# Boş bir inşa alanı bulur ve pozisyonunu döndürür, yoksa INF döner
func find_free_building_plot() -> Vector2:
	if not village_scene_instance:
		printerr("VillageManager: find_free_building_plot - VillageScene referansı yok!")
		return Vector2.INF # Hata durumunu belirtmek için Vector2.INF iyi bir seçenek

	# VillageScene'den plot marker ve yerleştirilmiş bina node'larını al
	var plot_markers = village_scene_instance.get_node_or_null("PlotMarkers")
	var placed_buildings = village_scene_instance.get_node_or_null("PlacedBuildings")

	if not plot_markers or not placed_buildings:
		printerr("VillageManager: find_free_building_plot - PlotMarkers veya PlacedBuildings bulunamadı!")
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
			print("VillageManager: Boş plot bulundu: ", marker.name, " at ", marker_pos)
			return marker_pos # Boş plot bulundu, pozisyonunu döndür

	print("VillageManager: Boş plot bulunamadı.")
	return Vector2.INF # Hiç boş plot bulunamadı

# Verilen bina sahnesini belirtilen pozisyona yerleştirir
func place_building(building_scene_path: String, position: Vector2) -> bool:
	if not village_scene_instance:
		printerr("VillageManager: place_building - VillageScene referansı yok!")
		return false

	var placed_buildings_node_ref = village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings_node_ref:
		printerr("VillageManager: place_building - PlacedBuildings node bulunamadı!")
		return false

	var building_scene = load(building_scene_path)
	if not building_scene:
		printerr("VillageManager: Bina sahnesi yüklenemedi: %s" % building_scene_path)
		return false

	var new_building = building_scene.instantiate()
	placed_buildings_node_ref.add_child(new_building)
	new_building.global_position = position
	print("VillageManager: Bina inşa edildi: ", new_building.name, " at ", position)
	emit_signal("village_data_changed") # UI güncellensin
	return true

# İnşa isteğini işler (Düzeltilmiş - Her türden sadece 1 bina)
func request_build_building(building_scene_path: String) -> bool:
	print("DEBUG VillageManager: request_build_building çağrıldı: ", building_scene_path)
	
	# 0. Bu Türden Bina Zaten Var Mı Kontrol Et (YENİ KURAL)
	if does_building_exist(building_scene_path):
		print("VillageManager: İnşa isteği reddedildi - Bu türden bir bina zaten mevcut: %s" % building_scene_path)
		return false
	
	# 1. Gereksinimleri Kontrol Et (Seviye ve Altın)
	if not can_meet_requirements(building_scene_path):
		print("VillageManager: İnşa isteği reddedildi - Gereksinimler karşılanmıyor.")
		return false

	# 2. Boş Yer Bul (Hala gerekli, belki max bina sayısı olabilir ileride)
	var placement_position = find_free_building_plot()
	if placement_position == Vector2.INF:
		print("VillageManager: İnşa isteği reddedildi - Boş yer yok.")
		return false

	# 3. Altın Maliyetini Düş (varsa)
	var requirements = get_building_requirements(building_scene_path)
	var cost = requirements.get("cost", {})
	var gold_cost = cost.get("gold", 0)
	if gold_cost > 0:
		GlobalPlayerData.add_gold(-gold_cost)
		print("VillageManager: Altın düşüldü: %d" % gold_cost)

	# 4. Gerekli Seviyeleri Kilitle (Anlık inşaatta kilit yok)
	# Şimdilik anlık inşaat varsaydığımız için seviye kilitlemiyoruz.
	# var required_levels = requirements.get("requires_level", {})
	# for resource_type in required_levels:
	#    lock_resource_level(resource_type, required_levels[resource_type])

	# 5. Binayı Yerleştir
	if place_building(building_scene_path, placement_position):
		print("VillageManager: Bina inşa süreci başarıyla tamamlandı.")
		# İnşaat bittiğinde seviyeleri aç (Eğer kilitlenmiş olsaydı)
		# for resource_type in required_levels:
		#    unlock_resource_level(resource_type, required_levels[resource_type])
		return true
	else:
		# Yerleştirme başarısız olduysa altını iade et!
		if gold_cost > 0:
			GlobalPlayerData.add_gold(gold_cost)
			print("VillageManager: Altın iade edildi: %d" % gold_cost)
		# Seviye kilitleri de açılmalıydı
		printerr("VillageManager: Bina yerleştirme başarısız oldu! Maliyetler iade edildi (eğer varsa).")
		return false

# --- Diğer Fonksiyonlar (Cariye, Görev vb.) ---

# --- YENİ Genel İşçi Yönetimi Fonksiyonları ---
# Kaynak seviyesini etkilemeden genel bir işçi atamasını kaydeder
func register_generic_worker() -> bool:
	if idle_workers > 0:
		idle_workers -= 1
		emit_signal("village_data_changed") # UI güncellensin
		return true
	else:
		printerr("VillageManager: register_generic_worker çağrıldı ama boşta işçi yok!")
		return false

# Kaynak seviyesini etkilemeden genel bir işçi atamasının kaldırılmasını kaydeder
func unregister_generic_worker() -> void:
	# Bu fonksiyon çağrıldığında binada işçi olduğu varsayılır (kontrol binada yapılır)
	idle_workers += 1
	emit_signal("village_data_changed") # UI güncellensin
# -------------------------------------------

# --- YENİ İleri Seviye Üretim Yönetimi ---
# İleri seviye üretimi kaydeder (anlık)
# Girdi kaynağını azaltır, çıktı kaynağını artırır
func register_advanced_production(produced_resource: String, consumed_resource: String, consume_amount: int) -> bool:
	# Girdi kaynağının kilitli olmayan miktarını tekrar kontrol et (güvenlik için)
	if get_available_resource_level(consumed_resource) < consume_amount:
		printerr("VillageManager: register_advanced_production - Yetersiz %s!" % consumed_resource)
		return false
		
	if resource_levels.has(produced_resource) and resource_levels.has(consumed_resource):
		# Kaynakları kilit mekanizması ile yönetmek daha doğru olurdu,
		# ama şimdilik doğrudan azaltıp artıralım (stoklama olmadığı için)
		resource_levels[consumed_resource] -= consume_amount
		resource_levels[produced_resource] += 1 # Her zaman 1 birim üretildiğini varsayalım
		print("VillageManager: %s üretimi aktif (+1 %s, -%d %s)" % [produced_resource.capitalize(), produced_resource, consume_amount, consumed_resource])
		emit_signal("village_data_changed")
		return true
	else:
		printerr("VillageManager: register_advanced_production - Bilinmeyen kaynak: %s veya %s" % [produced_resource, consumed_resource])
		return false

# İleri seviye üretimi kaldırır (anlık)
# Çıktı kaynağını azaltır, girdi kaynağını geri verir
func unregister_advanced_production(produced_resource: String, consumed_resource: String, consume_amount: int) -> void:
	if resource_levels.has(produced_resource) and resource_levels.has(consumed_resource):
		if resource_levels[produced_resource] > 0:
			resource_levels[produced_resource] -= 1
			resource_levels[consumed_resource] += consume_amount # Tüketilen kaynağı geri ver
			print("VillageManager: %s üretimi durdu (-1 %s, +%d %s)" % [produced_resource.capitalize(), produced_resource, consume_amount, consumed_resource])
			emit_signal("village_data_changed")
		else:
			printerr("VillageManager: unregister_advanced_production - Zaten %s üretilmiyor!" % produced_resource)
	else:
		printerr("VillageManager: unregister_advanced_production - Bilinmeyen kaynak: %s veya %s" % [produced_resource, consumed_resource])
# -------------------------------------------

# --- Yeni Köylü Ekleme Fonksiyonu ---
func add_villager() -> void:
	total_workers += 1
	idle_workers += 1
	print("VillageManager: Yeni köylü eklendi. Toplam: %d, Boşta: %d" % [total_workers, idle_workers])
	emit_signal("village_data_changed") # UI güncellensin

# Yeni bir cariye ekler (örn. zindandan kurtarıldığında)
func add_cariye(cariye_data: Dictionary) -> void:
	var id = next_cariye_id
	cariyeler[id] = cariye_data
	# Durumunu 'boşta' olarak ayarlayalım
	cariyeler[id]["durum"] = "boşta" 
	next_cariye_id += 1
	print("VillageManager: Yeni cariye eklendi: ", cariye_data.get("isim", "İsimsiz"), " (ID: ", id, ")")
	emit_signal("cariye_data_changed")

# Yeni bir görev tanımı ekler
func add_gorev(gorev_data: Dictionary) -> void:
	var id = next_gorev_id
	gorevler[id] = gorev_data
	next_gorev_id += 1
	print("VillageManager: Yeni görev eklendi: ", gorev_data.get("isim", "İsimsiz"), " (ID: ", id, ")")
	emit_signal("gorev_data_changed")

# Bir cariyeyi bir göreve atar
func assign_cariye_to_mission(cariye_id: int, gorev_id: int) -> bool:
	if not cariyeler.has(cariye_id) or not gorevler.has(gorev_id):
		printerr("VillageManager: Geçersiz cariye veya görev ID!")
		return false
	if cariyeler[cariye_id]["durum"] != "boşta":
		print("VillageManager: Cariye %d zaten meşgul (%s)" % [cariye_id, cariyeler[cariye_id]["durum"]])
		return false
	# !!! GÖREV KOŞULLARI KONTROLÜ (Gelecekte eklenecek) !!!
	# Örneğin: Asker sayısı, yetenek vb. kontrolü burada yapılmalı.
	# if not _check_mission_requirements(cariye_id, gorev_id): return false
		
	var gorev = gorevler[gorev_id]
	var cariye = cariyeler[cariye_id]
	var sure = gorev.get("sure", 10.0) # Varsayılan süre 10sn

	print("VillageManager: Cariye %d (%s), Görev %d (%s)'e atanıyor (Süre: %.1fs)" % [cariye_id, cariye.get("isim", ""), gorev_id, gorev.get("isim", ""), sure])

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
		printerr("VillageManager: Görev tamamlandı ama aktif görevlerde bulunamadı veya ID eşleşmedi!")
		return # Beklenmedik durum

	var cariye = cariyeler[cariye_id]
	var gorev = gorevler[gorev_id]
	var timer = active_missions[cariye_id]["timer"]

	print("VillageManager: Görev %d (%s) tamamlandı (Cariye: %d)" % [gorev_id, gorev.get("isim", ""), cariye_id])

	# --- BAŞARI/BAŞARISIZLIK HESAPLAMA (Basit Örnek) ---
	# TODO: Daha karmaşık hesaplama (zorluk, cariye yeteneği vb. kullan)
	var success_chance = gorev.get("basari_sansi", 0.7) # Varsayılan %70 başarı şansı
	var successful = randf() < success_chance # Rastgele sayı < başarı şansı ise başarılı
	# --------------------------------------------------
	
	var cariye_injured = false # Cariye yaralandı mı flag'i

	if successful:
		print("  -> Görev Başarılı!")
		var oduller = gorev.get("odul", {})
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
		var cezalar = gorev.get("ceza", {})
		print("     Cezalar: ", cezalar)
		# --- CEZALARI UYGULA (GlobalPlayerData kullanarak) ---
		if cezalar.has("asker_kaybi"):
			GlobalPlayerData.change_asker_sayisi(-cezalar["asker_kaybi"])
		if cezalar.has("cariye_yaralanma_ihtimali"):
			if randf() < cezalar["cariye_yaralanma_ihtimali"]:
				cariye_injured = true
				cariye["durum"] = "yaralı"
				print("     UYARI: Cariye %d (%s) görev sırasında yaralandı!" % [cariye_id, cariye.get("isim", "")])
				# TODO: Yaralı cariye için bir iyileşme süreci başlatılabilir
		# TODO: Diğer ceza türleri eklenebilir
		# -------------------------------------------------

	# --- ETKİLERİ UYGULA (Başarı/Başarısızlıktan bağımsız olabilir) ---
	var etkiler = gorev.get("etki", {})
	if not etkiler.is_empty(): # Sadece etki varsa yazdır
		print("     Etkiler: ", etkiler)
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

# Binaların çağırması için yeni fonksiyon
func notify_building_state_changed(building_node):
	print("VillageManager: notify_building_state_changed called by: ", building_node.name) # DEBUG
	emit_signal("building_state_changed", building_node)
	# İsteğe bağlı: Genel UI güncellemesi için bunu da tetikleyebiliriz?
	# emit_signal("village_data_changed")
