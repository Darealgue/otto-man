extends Node

# Sinyaller
signal resource_updated(resource_type: String, new_value: int)
signal building_registered(building_id: int, building_type: String)
signal building_upgraded(building_id: int, new_level: int)
signal building_destroyed(building_id: int)
signal worker_assigned(worker_id: int, resource_type: String)
signal worker_unassigned(worker_id: int, resource_type: String)
signal house_registered(house_id: int)
signal resource_selected(resource_node: Node, resource_type: String)
signal resource_added(resource_type: String, amount: int)

# Köy verileri
var village_data = {
	"resources": {
		"wood": 0,
		"stone": 0,
		"food": 0,
		"water": 0,
		"metal": 0
	},
	"buildings": {},
	"workers": {},
	"houses": []
}

# ID sayaçları
var next_building_id: int = 0
var next_worker_id: int = 0

# Resource nodes referansları
var resource_nodes = {}

# Toplam barınma kapasitesi için değişken
var base_housing_capacity: int = 3  # Başlangıç barınma kapasitesi
var total_housing_capacity: int = base_housing_capacity  # Toplam barınma kapasitesi

# UI referansları
var village_ui = null

# İşçi durumları için özellikler
var available_workers = [] # Atanmamış işçiler için liste

func _ready():
	# Köylüleri oluşturmayı biraz geciktir (sahnenin yüklenmesini bekle)
	await get_tree().create_timer(0.5).timeout
	
	# Test için örnek işçiler ekleyelim ve köylü olarak oluşturalım
	for i in range(3):
		var worker_id = add_worker()
		# VillagerManager'a köylü oluşturması için sinyal gönder
		emit_signal("worker_assigned", worker_id, "wandering")
		print("Başlangıç köylüsü oluşturuldu - ID: ", worker_id)
	
	# Müsait işçileri güncelle
	_update_available_workers()
	
	print("VillageManager başlatıldı. İşçi sayısı: ", get_worker_count())

# Müsait işçileri güncelle
func _update_available_workers() -> void:
	available_workers.clear()
	
	for worker_id in village_data.workers:
		if village_data.workers[worker_id].assigned_to == "":
			available_workers.append(worker_id)
	
	print("Müsait işçi listesi güncellendi: ", available_workers)

# VillageUI referansını ayarla
func set_village_ui(ui_node: Node) -> void:
	village_ui = ui_node
	print("VillageUI referansı ayarlandı")

# Kaynak seçildiğinde
func _on_resource_selected(resource_node: Node, resource_type: String) -> void:
	print("VillageManager: Kaynak seçildi: ", resource_node.name, " tip: ", resource_type)
	
	# UI'a bildir
	if village_ui and village_ui.has_method("show_resource_assignment_screen"):
		village_ui.show_resource_assignment_screen(resource_node, resource_type)

# Kaynak yönetimi (artık işçi sayısıyla ilgili)
func get_resource_amount(resource_type: String) -> int:
	# Artık kaynak miktarı, o kaynağa atanmış işçi sayısıdır
	return get_resource_worker_count(resource_type)

func register_resource_node(node: Node, resource_type: String) -> void:
	# Resource node'u kaydet
	if !resource_nodes.has(resource_type):
		resource_nodes[resource_type] = []
	
	resource_nodes[resource_type].append(node)
	print(resource_type, " kaynağı için yeni bir ResourceNode kaydedildi")

func unregister_resource_node(node: Node, resource_type: String) -> void:
	if resource_nodes.has(resource_type):
		resource_nodes[resource_type].erase(node)

# İşçi yönetimi
func add_worker() -> int:
	var worker_id = next_worker_id
	village_data.workers[worker_id] = {
		"name": "İşçi " + str(worker_id),
		"assigned_to": "",
		"efficiency": 1.0
	}
	
	next_worker_id += 1
	return worker_id

func assign_worker(worker_id: int, resource_type: String, resource_building = null) -> bool:
	if !village_data.workers.has(worker_id):
		print("HATA: ", worker_id, " ID'li işçi bulunamadı")
		return false
	
	# Önceki görevden çıkar
	if village_data.workers[worker_id].assigned_to != "":
		var prev_assignment = village_data.workers[worker_id].assigned_to
		
		# Eğer bir binadan ayrılıyorsa
		if prev_assignment.begins_with("building:"):
			var building_id = int(prev_assignment.split(":")[1])
			remove_worker_from_building(worker_id, building_id)
	
	# Yeni göreve ata
	village_data.workers[worker_id].assigned_to = resource_type
	village_data.workers[worker_id].building_instance = resource_building
	
	worker_assigned.emit(worker_id, resource_type)
	print("İşçi ", worker_id, " -> ", resource_type, " kaynağına atandı")
	
	# Atanmamış işçi listesini güncelle
	_update_available_workers()
	
	return true

func unassign_worker(worker_id: int) -> bool:
	if !village_data.workers.has(worker_id):
		print("HATA: ", worker_id, " ID'li işçi bulunamadı")
		return false
	
	var prev_assignment = village_data.workers[worker_id].assigned_to
	
	# Eğer bir binadan ayrılıyorsa
	if prev_assignment.begins_with("building:"):
		var building_id = int(prev_assignment.split(":")[1])
		remove_worker_from_building(worker_id, building_id)
	
	village_data.workers[worker_id].assigned_to = ""
	worker_unassigned.emit(worker_id, prev_assignment)
	print("İşçi ", worker_id, " görevden alındı")
	
	# Atanmamış işçi listesini güncelle
	_update_available_workers()
	
	return true

func get_worker_count() -> int:
	return village_data.workers.size()

func get_unassigned_worker_count() -> int:
	var count = 0
	for worker_id in village_data.workers:
		if village_data.workers[worker_id].assigned_to == "":
			count += 1
	return count

func get_workers_data() -> Dictionary:
	return village_data.workers

# Bina yönetimi
func register_building(building_node: Node, building_type: String) -> int:
	var building_id = next_building_id
	
	village_data.buildings[building_id] = {
		"type": building_type,
		"level": 1,
		"node": building_node,
		"worker_id": -1  # Henüz bir işçi atanmamış
	}
	
	next_building_id += 1
	building_registered.emit(building_id, building_type)
	
	print("Yeni bina kaydedildi: ", building_type, " (ID: ", building_id, ")")
	return building_id

func register_house(house_node: Node) -> int:
	var house_id = register_building(house_node, "house")
	village_data.houses.append(house_id)
	house_registered.emit(house_id)
	
	# Her ev köye +3 barınma kapasitesi sağlar
	increase_housing_capacity(3)
	
	print("Yeni ev kaydedildi (ID: ", house_id, ")")
	return house_id

func assign_worker_to_building(worker_id: int, building_id: int) -> bool:
	if !village_data.workers.has(worker_id) or !village_data.buildings.has(building_id):
		print("HATA: Geçersiz işçi veya bina ID'si")
		return false
	
	# Binanın halihazırda bir işçisi var mı?
	if village_data.buildings[building_id].worker_id != -1:
		print("HATA: Bina zaten dolu")
		return false
	
	# İşçiyi önceki görevinden çıkar
	unassign_worker(worker_id)
	
	# İşçiyi binaya ata
	village_data.buildings[building_id].worker_id = worker_id
	village_data.workers[worker_id].assigned_to = "building:" + str(building_id)
	
	worker_assigned.emit(worker_id, "building:" + str(building_id))
	print("İşçi ", worker_id, " -> Bina ", building_id, " atandı")
	
	return true

func assign_worker_to_house(worker_id: int, house_id: int) -> bool:
	return assign_worker_to_building(worker_id, house_id)

func remove_worker_from_building(worker_id: int, building_id: int) -> bool:
	if !village_data.buildings.has(building_id):
		print("HATA: Geçersiz bina ID'si")
		return false
	
	# Bina bu işçiye mi atanmış?
	if village_data.buildings[building_id].worker_id != worker_id:
		print("HATA: Bu işçi bu binada çalışmıyor")
		return false
	
	# İşçiyi binadan çıkar
	village_data.buildings[building_id].worker_id = -1
	
	print("İşçi ", worker_id, " binadan (", building_id, ") çıkarıldı")
	return true

func remove_worker_from_house(worker_id: int, house_id: int) -> bool:
	return remove_worker_from_building(worker_id, house_id)

func get_available_house() -> int:
	# Mevcut evleri kontrol et ve boş olanı bul
	for house_id in village_data.houses:
		if village_data.buildings.has(house_id) and village_data.buildings[house_id].worker_id == -1:
			return house_id
	
	return -1  # Boş ev yok

func get_buildings_data() -> Dictionary:
	return village_data.buildings

func get_building_worker(building_id: int) -> int:
	if village_data.buildings.has(building_id):
		return village_data.buildings[building_id].worker_id
	return -1

func get_village_level() -> int:
	# Toplam bina sayısına göre köy seviyesini hesapla
	var building_count = village_data.buildings.size()
	
	if building_count >= 15:
		return 3
	elif building_count >= 5:
		return 2
	else:
		return 1

# Bina inşa etme - İşçi tabanlı sistem
func can_build(building_type: String) -> bool:
	# Bina türüne göre kaynak gereksinimlerini kontrol et
	var requirements = get_building_requirements(building_type)
	
	# Her kaynak tipi için yeterli işçi var mı kontrol et
	for resource_type in requirements:
		var required_workers = requirements[resource_type]
		var assigned_workers = get_resource_worker_count(resource_type)
		
		if assigned_workers < required_workers:
			print("Yetersiz işçi: ", resource_type, " - Gereken: ", required_workers, ", Mevcut: ", assigned_workers)
			return false
	
	return true

func build(building_type: String, slot_node: Node) -> bool:
	if !can_build(building_type):
		print("HATA: Yeterli kaynak/işçi yok")
		return false
	
	# Bina ID'sini oluştur
	var building_id = register_building(slot_node, building_type)
	
	# Kaynaklara atanmış işçileri binaya yönlendir (gerekli sayıda)
	var requirements = get_building_requirements(building_type)
	
	# Her kaynak türü için işçi bul ve ata
	for resource_type in requirements:
		var required_workers = requirements[resource_type]
		
		# Bu kaynak tipine atanmış işçileri bul
		var workers_to_reassign = []
		for worker_id in village_data.workers:
			if village_data.workers[worker_id].assigned_to == resource_type and workers_to_reassign.size() < required_workers:
				workers_to_reassign.append(worker_id)
		
		# Gerekli sayıda işçiyi binaya yönlendir
		for worker_id in workers_to_reassign:
			# Şu anda kaynak toplama görevinde olan işçiyi bina inşaasına yönlendir
			assign_worker_to_building(worker_id, building_id)
	
	print("Bina inşa edildi: ", building_type, " (ID: ", building_id, ")")
	return true

func get_building_requirements(building_type: String) -> Dictionary:
	match building_type:
		"house":
			return {"wood": 1, "stone": 1}
		"farm":
			return {"wood": 1, "stone": 1}
		"lumberjack":
			# Oduncu binası için gereksinim yok (bedava)
			return {}
		"well":
			# Su kuyusu binası için gereksinim yok (bedava)
			return {}
		"mine":
			return {"wood": 1, "stone": 1}
		"tower":
			return {"wood": 2, "stone": 1, "metal": 1}
		"blacksmith":
			return {"wood": 1, "stone": 1, "metal": 1}
		"quarry":
			return {"wood": 1, "stone": 1}
		_:
			return {"wood": 1, "stone": 1}

# Belirli kaynak tipinde çalışan işçi sayısını döndür
func get_resource_worker_count(resource_type: String) -> int:
	var count = 0
	
	for worker_id in village_data.workers:
		var worker = village_data.workers[worker_id]
		if worker.assigned_to == resource_type:
			count += 1
	
	return count

# Köyün mevcut barınma kapasitesi
func get_total_housing_capacity() -> int:
	return total_housing_capacity

# Köyün kullanılan barınma miktarı
func get_used_housing() -> int:
	return get_worker_count()

# Köyün boş barınma kapasitesi
func get_free_housing_capacity() -> int:
	return total_housing_capacity - get_worker_count()

# Barınma kapasitesini arttır (ev inşa edildiğinde)
func increase_housing_capacity(amount: int) -> void:
	total_housing_capacity += amount
	print("Barınma kapasitesi arttı: ", total_housing_capacity)

# Barınma kapasitesini azalt (ev yıkıldığında)
func decrease_housing_capacity(amount: int) -> void:
	# Kapasiteyi minimum base_housing_capacity olarak tut
	total_housing_capacity = max(base_housing_capacity, total_housing_capacity - amount)
	print("Barınma kapasitesi azaldı: ", total_housing_capacity)

# Ev yükseltme
func upgrade_house(house_id: int) -> bool:
	if !village_data.buildings.has(house_id):
		return false
	
	var house_data = village_data.buildings[house_id]
	if house_data.type != "house":
		return false
	
	# Ev seviyesini artır
	house_data.level += 1
	
	# Her seviye için +3 barınma kapasitesi
	increase_housing_capacity(3)
	
	print("Ev yükseltildi (ID: ", house_id, ", Yeni seviye: ", house_data.level, ")")
	return true

# Resource node'a işçi atama
func assign_worker_to_resource(worker_id: int, resource_type: String) -> bool:
	if !village_data.workers.has(worker_id):
		print("HATA: ", worker_id, " ID'li işçi bulunamadı")
		return false
	
	# İşçiyi kaynağa ata
	if assign_worker(worker_id, resource_type):
		print("İşçi ", worker_id, " -> ", resource_type, " kaynağına atandı")
		
		# Resource node'u bul ve çalışan atandı bilgisini güncelle
		if resource_nodes.has(resource_type) and !resource_nodes[resource_type].is_empty():
			for node in resource_nodes[resource_type]:
				if node is ResourceBuilding and node.worker_id == -1:
					# Boş bir kaynak binası bulundu, işçiyi buna ata
					node.assign_worker(worker_id)
					return true
		
		return true
	
	return false

# Kaynak ekle
func add_resource(resource_type: String, amount: int) -> void:
	if !village_data.resources.has(resource_type):
		print("Unknown resource type: ", resource_type)
		return
	
	village_data.resources[resource_type] += amount
	
	# Sinyal gönder
	resource_added.emit(resource_type, amount)
	
	print("Added ", amount, " of ", resource_type, ". New total: ", village_data.resources[resource_type]) 
