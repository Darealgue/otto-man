extends Node

signal villager_created(villager)
signal building_registered(building_id, building)

@export var villager_scene: PackedScene = null
@export var debug_enabled: bool = true

var next_villager_id = 1
var villagers = {}  # Dictionary to track all villagers
var resource_buildings = []  # Array to store resource buildings
var resource_gathering_points = {}  # Dictionary to store off-screen gathering points

func _ready():
	print("VillagerManager initialized")
	
	# Köylü sahnesini yükle 
	if ResourceLoader.exists("res://village/characters/villager.tscn"):
		villager_scene = load("res://village/characters/villager.tscn")
		print("Köylü sahnesi yüklendi: res://village/characters/villager.tscn")
	else:
		print("UYARI: Köylü sahnesi bulunamadı: res://village/characters/villager.tscn")
		# Alternatif yol deneyin
		if ResourceLoader.exists("res://village/Villager.tscn"):
			villager_scene = load("res://village/Villager.tscn")
			print("Köylü sahnesi alternatif yoldan yüklendi: res://village/Villager.tscn")
		else:
			print("HATA: Hiçbir köylü sahnesi bulunamadı!")
			
	# Setup resource gathering points for off-screen collection
	_setup_resource_gathering_points()
	
	# Find resource buildings in the scene
	call_deferred("find_resource_buildings")
	
	# Connect to VillageManager signals
	var village_manager = get_node_or_null("/root/VillageManager")
	if village_manager:
		if village_manager.has_signal("worker_assigned") and not village_manager.is_connected("worker_assigned", _on_worker_assigned):
			village_manager.worker_assigned.connect(_on_worker_assigned)
			print("VillageManager worker_assigned sinyaline bağlandı")
		else:
			print("UYARI: VillageManager worker_assigned sinyali bulunamadı veya bağlanamadı")
	else:
		print("HATA: VillageManager bulunamadı!")

func _setup_resource_gathering_points():
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Define off-screen gathering points for each resource type
	resource_gathering_points = {
		"wood": Vector2(viewport_size.x + 200, 100),
		"stone": Vector2(viewport_size.x + 200, 200),
		"water": Vector2(viewport_size.x + 200, 300),
		"food": Vector2(viewport_size.x + 200, 400),
		"metal": Vector2(viewport_size.x + 200, 500)
	}
	
	print("Resource gathering points setup: ", resource_gathering_points)

func find_resource_buildings():
	resource_buildings.clear()
	
	print("Kaynak binaları aranıyor...")
	
	# First, check if there are any nodes in the "resource_buildings" group
	var buildings_in_group = get_tree().get_nodes_in_group("resource_buildings")
	
	if buildings_in_group.size() > 0:
		print("'resource_buildings' grubunda ", buildings_in_group.size(), " bina bulundu")
		
		for building in buildings_in_group:
			# Her binanın tipini kontrol et
			var resource_type = "bilinmiyor"
			
			if building.has_method("get_resource_type"):
				resource_type = building.get_resource_type()
			elif "resource_type" in building:
				resource_type = building.resource_type
			
			if resource_type == "bilinmiyor":
				print("UYARI: Bina resource_type değeri bulunamadı: ", building.name)
				continue
			
			resource_buildings.append(building)
			print("Kaynak binası bulundu: ", building.name, " - Tip: ", resource_type)
	else:
		print("'resource_buildings' grubunda bina bulunamadı")
		
		# Tüm sahnedeki Node2D'leri kontrol et
		print("Tüm sahnedeki Node2D'ler kontrol ediliyor...")
		var all_nodes = get_tree().get_nodes_in_group("Node2D")
		for node in all_nodes:
			if "resource_type" in node:
				print("Potansiyel kaynak binası bulundu: ", node.name, " - Tip: ", node.resource_type)
				
				if not node.is_in_group("resource_buildings"):
					node.add_to_group("resource_buildings")
					print("Node 'resource_buildings' grubuna eklendi: ", node.name)
				
				resource_buildings.append(node)
			
			# Scripti kontrol edelim
			if node.get_script() and node.get_script().get_path().find("resource_building") >= 0:
				print("Resource building script'i bulunan node: ", node.name)
				
				if not node.is_in_group("resource_buildings"):
					node.add_to_group("resource_buildings")
					print("Script'inden dolayı 'resource_buildings' grubuna eklendi: ", node.name)
				
				if not resource_buildings.has(node):
					resource_buildings.append(node)
	
	print("Toplam bulunan kaynak binası: ", resource_buildings.size())
	
	# Kaynak tiplerine göre bina sayısını raporla
	var building_types = {}
	for building in resource_buildings:
		var type = "bilinmiyor"
		
		if building.has_method("get_resource_type"):
			type = building.get_resource_type()
		elif "resource_type" in building:
			type = building.resource_type
		
		if type in building_types:
			building_types[type] += 1
		else:
			building_types[type] = 1
	
	for type in building_types:
		print("Kaynak tipi: ", type, " - Adet: ", building_types[type])
	
	# Belirli kaynak tipi mevcut mu kontrol et
	var required_types = ["wood", "stone", "water"]
	for required in required_types:
		if not required in building_types:
			print("UYARI: '", required, "' tipi için bina bulunamadı")
		else:
			print("'", required, "' tipi için ", building_types[required], " bina bulundu")
	
	return resource_buildings

func create_villager_for_resource(worker_id, resource_type, position = Vector2.ZERO):
	if villager_scene == null:
		print("ERROR: Cannot create villager - villager_scene is null")
		return null
	
	print("Creating villager for worker ", worker_id, " to gather ", resource_type)
	
	var villager = villager_scene.instantiate()
	
	# Çarpışmaları yapılandır
	if villager is CharacterBody2D:
		villager.collision_layer = 16  # Köylü katmanı (5. bit)
		villager.collision_mask = 1    # Sadece zemin ile etkileşim (1. bit)
		print("Villager collision configured: Layer=16, Mask=1")
	
	# Köylüye başlangıç pozisyonu ver
	var start_pos = Vector2.ZERO
	if position == Vector2.ZERO:
		# Köy merkezinde rastgele bir pozisyon (960 ± 300)
		start_pos = Vector2(960 + randf_range(-300, 300), 0)
	else:
		start_pos = position
	
	villager.position = Vector2(start_pos.x, 0)  # Y koordinatı köylü tarafından ayarlanacak
	print("Köylü başlangıç pozisyonu: ", villager.position, " (Y köylü tarafından ayarlanacak)")
	
	# İşçi kimliği atama
	if "worker_id" in villager:
		villager.worker_id = int(worker_id)
		print("İşçi kimliği atandı: ", worker_id)
	else:
		print("UYARI: Köylüde worker_id özelliği yok!")
		
	# Kaynak türü atama
	if "resource_type" in villager:
		villager.resource_type = resource_type
		print("Kaynak türü atandı: ", resource_type)
	else:
		print("UYARI: Köylüde resource_type özelliği yok!")
	
	# Debug: Köylünün görünümünü özelleştir
	if "scale" in villager:
		villager.scale = Vector2(1.5, 1.5)
		print("Köylü ölçeği ayarlandı: ", villager.scale)
		
	# Sprite rengini düzenle
	var sprite = villager.get_node_or_null("Sprite2D")
	if sprite:
		match resource_type:
			"wandering":
				sprite.modulate = Color(1.0, 1.0, 1.0)  # Normal renk
			"wood": 
				sprite.modulate = Color(0.6, 0.4, 0.2)  # Kahverengi
			"stone": 
				sprite.modulate = Color(0.8, 0.8, 0.8)  # Gri
			"water": 
				sprite.modulate = Color(0.3, 0.6, 1.0)  # Mavi
			"food": 
				sprite.modulate = Color(0.4, 0.9, 0.4)  # Yeşil
			"metal": 
				sprite.modulate = Color(0.7, 0.7, 0.9)  # Metal rengi
		print("Köylü sprite rengi ayarlandı: ", sprite.modulate)
		
	# Etiketleri güncelle
	var label = villager.get_node_or_null("Label")
	if label:
		label.text = "İşçi #" + str(worker_id) + "\n" + resource_type
		print("Köylü etiketi ayarlandı: ", label.text)
	
	# Eğer wandering değilse, hedef bina ve toplama noktası ata
	if resource_type != "wandering":
		# Find a target building for this resource type
		var target_building = _find_building_for_resource(resource_type)
		if target_building:
			if "set_target_building" in villager:
				villager.set_target_building(target_building)
				print("Assigned villager to target building: ", target_building.name)
			else:
				print("UYARI: Köylüde set_target_building metodu yok!")
		else:
			print("WARNING: No building found for resource type: ", resource_type)
		
		# Set gathering point for this resource type
		if resource_type in resource_gathering_points:
			var gathering_point = resource_gathering_points[resource_type]
			if "set_gathering_point" in villager:
				villager.set_gathering_point(gathering_point)
				print("Assigned gathering point for ", resource_type, ": ", gathering_point)
			elif "gathering_point" in villager:
				villager.gathering_point = gathering_point
				print("Gathering point atandı: ", gathering_point)
			else:
				print("UYARI: Köylüde set_gathering_point metodu veya gathering_point özelliği yok!")
	
	# Add villager to the scene
	# Önce ana sahneyi bul
	var main_scene = get_tree().get_root().get_child(get_tree().get_root().get_child_count() - 1)
	print("Ana sahne bulundu: ", main_scene.name)
	
	# Village sahnesini bul
	var village_scene = null
	for child in main_scene.get_children():
		if child.name == "Village":
			village_scene = child
			break
	
	if village_scene:
		print("Village sahnesi bulundu: ", village_scene.name)
		village_scene.add_child(villager)
		print("Köylü Village sahnesine eklendi")
		
		# Village sahnesini village_scene grubuna ekle
		if not village_scene.is_in_group("village_scene"):
			village_scene.add_to_group("village_scene")
			print("Village sahnesi 'village_scene' grubuna eklendi")
	else:
		print("UYARI: Village sahnesi bulunamadı, ana sahneye ekleniyor...")
		main_scene.add_child(villager)
		print("Köylü ana sahneye eklendi")
	
	# Track villager
	villagers[worker_id] = villager
	
	# Köylüyü ayarla
	if "setup" in villager:
		villager.setup(worker_id, resource_type)
		print("Köylü ayarlandı - worker_id: ", worker_id, ", resource_type: ", resource_type)
	
	emit_signal("villager_created", villager)
	print("Köylü oluşturuldu - worker_id: ", worker_id, " konumu: ", villager.position)
	
	return villager

func _find_building_for_resource(resource_type):
	print("Finding building for resource type: ", resource_type)
	
	# Update resource buildings list first
	if resource_buildings.size() == 0:
		find_resource_buildings()
	
	# Find a building matching the resource type
	for building in resource_buildings:
		var building_resource_type
		
		if building.has_method("get_resource_type"):
			building_resource_type = building.get_resource_type()
		elif "resource_type" in building:
			building_resource_type = building.resource_type
		else:
			continue
		
		if building_resource_type == resource_type:
			print("Found building for ", resource_type, ": ", building.name)
			return building
	
	print("WARNING: No building found for resource type: ", resource_type)
	return null

func _on_building_registered(building_id, building):
	print("Building registered: ", building.name)
	
	# If this is a resource building, add it to our list
	if building.has_method("get_resource_type") or "resource_type" in building:
		if not building.is_in_group("resource_buildings"):
			building.add_to_group("resource_buildings")
			print("Added registered building to resource_buildings group")
		
		if not resource_buildings.has(building):
			resource_buildings.append(building)
			print("Added building to resource_buildings list: ", building.name)

func _on_worker_assigned(worker_id, resource_type):
	print("Worker assigned: ", worker_id, " to resource: ", resource_type)
	
	# Eğer bu bir wandering köylüsü ise, direkt oluştur
	if resource_type == "wandering":
		create_villager_for_resource(worker_id, resource_type)
		return
	
	# Eğer bu bir kaynak tipi (building değil) ise ve bina bulunamıyorsa, işçi atamasını yapmayı reddet
	if not resource_type.begins_with("building:"):
		var target_building = _find_building_for_resource(resource_type)
		if target_building == null:
			print("HATA: ", resource_type, " için kaynak binası bulunamadı. İşçi ataması iptal edildi.")
			# VillageManager'a işçinin serbest bırakıldığını bildir
			var village_manager = get_node_or_null("/root/VillageManager")
			if village_manager and village_manager.has_method("unassign_worker"):
				village_manager.unassign_worker(worker_id)
				print("İşçi ", worker_id, " kaynak binası olmadığı için görevden alındı")
			return
	
	# If a villager already exists for this worker, update it
	if worker_id in villagers:
		var villager = villagers[worker_id]
		
		# Villager'ın kaynak tipini güncelle
		if "resource_type" in villager:
			villager.resource_type = resource_type
		
		# Find a target building for this resource type
		var target_building = _find_building_for_resource(resource_type)
		if target_building:
			if "set_target_building" in villager:
				villager.set_target_building(target_building)
			else:
				print("UYARI: Mevcut köylüde set_target_building metodu bulunamadı")
		else:
			# Eğer kaynak tipinde bir bina yoksa ve bu bir bina ataması değilse, işçiyi göreve gönderme
			if not resource_type.begins_with("building:"):
				print("HATA: ", resource_type, " için kaynak binası bulunamadı. Köylü göreve gönderilemedi.")
				return
		
		# Set gathering point for this resource type
		if resource_type in resource_gathering_points:
			var gathering_point = resource_gathering_points[resource_type]
			if "set_gathering_point" in villager:
				villager.set_gathering_point(gathering_point)
			elif "gathering_point" in villager:
				villager.gathering_point = gathering_point
			else:
				print("UYARI: Köylüde gathering_point özelliği bulunamadı")
		
		print("Updated existing villager for worker ", worker_id)
		return
	
	# Eğer kaynak tipi bir bina değilse, önce ilgili kaynak binasını ara
	if not resource_type.begins_with("building:"):
		var target_building = _find_building_for_resource(resource_type)
		if target_building == null:
			print("HATA: ", resource_type, " için kaynak binası bulunamadı. Yeni köylü oluşturulamadı.")
			# İşçiyi görevden al
			var village_manager = get_node_or_null("/root/VillageManager")
			if village_manager and village_manager.has_method("unassign_worker"):
				village_manager.unassign_worker(worker_id)
				print("İşçi ", worker_id, " kaynak binası olmadığı için görevden alındı")
			return
	
	# Create a new villager
	create_villager_for_resource(worker_id, resource_type)

func _process(delta):
	# Her 10 saniyede bir kaynak binalarını kontrol et
	if Engine.get_process_frames() % 600 == 0:  # 60 FPS'de her 10 saniyede bir
		find_resource_buildings()
	
	# Her 5 saniyede bir (300 kare) köylülerin durumunu kontrol et
	if Engine.get_process_frames() % 300 == 0:
		_debug_report_villagers()

func _debug_report_villagers():
	print("=============== KÖYLÜLERİN DURUMU ===============")
	print("Toplam kayıtlı köylü sayısı: ", villagers.size())
	
	if villagers.size() == 0:
		print("Hiç köylü yok!")
		return
	
	print("Köylülerin listesi:")
	for worker_id in villagers:
		var villager = villagers[worker_id]
		if is_instance_valid(villager):
			var position_str = str(villager.position) if "position" in villager else "bilinmiyor"
			var resource_type_str = villager.resource_type if "resource_type" in villager else "bilinmiyor"
			var state_str = "bilinmiyor"
			
			# Durum bilgisini al
			if "state" in villager:
				var state_index = villager.state
				if state_index >= 0 and state_index < villager.VillagerState.size():
					state_str = villager.VillagerState.keys()[state_index]
			
			print("- İşçi ID: ", worker_id, 
				  " - Kaynak: ", resource_type_str,
				  " - Durum: ", state_str,
				  " - Pozisyon: ", position_str,
				  " - Sahne yolu: ", villager.get_path() if villager.is_inside_tree() else "ağaçta değil")
			
			# İş süresi bilgisini ekle (çalışıyorsa)
			if "state" in villager and villager.state == villager.VillagerState.RETURNING_HOME and "job_duration" in villager:
				if villager.job_duration > 0 and villager.job_duration < villager.max_job_duration:
					print("  > Çalışma süresi: ", int(villager.job_duration), "/", int(villager.max_job_duration), " saniye")
		else:
			print("- İşçi ID: ", worker_id, " - GEÇERSİZ KÖYLÜ!")
	
	print("=================================================") 
