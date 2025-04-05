extends Node2D

# Köy sahnesini yöneten ana sınıf

var resource_buildings = []
var building_slots = []

var time_ui_scene = preload("res://village/village_ui/TimeUI.tscn")
var time_ui = null

# Resource buildings - bunları preload yerine load kullanacağız
# var lumberjack_scene = preload("res://village/buildings/lumberjack.tscn")
# var quarry_scene = preload("res://village/buildings/quarry.tscn")
# var well_scene = preload("res://village/buildings/well.tscn")

@onready var villager_manager = $VillagerManager if has_node("VillagerManager") else null

func _ready() -> void:
	print("Village Scene initialized")
	
	# Köy sahnesini village_scene grubuna ekleyelim
	if not is_in_group("village_scene"):
		add_to_group("village_scene")
		print("Köy sahnesi 'village_scene' grubuna eklendi")
	
	# Setup TimeUI
	time_ui = time_ui_scene.instantiate()
	var canvas_layer = get_node_or_null("CanvasLayer")
	if canvas_layer:
		canvas_layer.add_child(time_ui)
		print("TimeUI added to CanvasLayer")
	else:
		print("ERROR: CanvasLayer not found in village_scene, creating one")
		canvas_layer = CanvasLayer.new()
		add_child(canvas_layer)
		canvas_layer.add_child(time_ui)
	
	# Check for TimeManager singleton
	if not get_node_or_null("/root/TimeManager"):
		print("ERROR: TimeManager singleton not found")
	
	# Check for VillagerManager
	var villager_manager = get_node_or_null("/root/VillagerManager")
	if villager_manager:
		print("VillagerManager found")
	else:
		print("ERROR: VillagerManager not found")
	
	# Check workers data from VillageManager
	var village_manager = get_node_or_null("/root/VillageManager")
	if village_manager:
		print("VillageManager found")
		var workers = village_manager.get_workers()
		print("Workers count: ", workers.size())
	else:
		print("ERROR: VillageManager not found")
	
	# Kaynak binalarını oluştur
	create_resource_buildings()

func _process(delta: float) -> void:
	# TimeUI update
	if time_ui:
		if get_node_or_null("/root/TimeManager"):
			time_ui.update_time()
	
	# Additional processing can be added here

func _find_resource_buildings() -> void:
	resource_buildings = get_tree().get_nodes_in_group("resource_buildings")
	print("Bulunan kaynak binaları: ", resource_buildings.size())
	for rb in resource_buildings:
		print("Kaynak binası: ", rb.name, " - Tip: ", rb.resource_type if "resource_type" in rb else "bilinmiyor")

func _connect_resource_buildings() -> void:
	for building in resource_buildings:
		if building.has_signal("resource_selected"):
			# Sinyali VillageManager'a bağla
			if not building.resource_selected.is_connected(VillageManager._on_resource_selected):
				building.resource_selected.connect(VillageManager._on_resource_selected)

func _find_building_slots() -> void:
	building_slots = get_tree().get_nodes_in_group("building_slots")
	print("Bulunan bina slotları: ", building_slots.size())

func _connect_building_slots() -> void:
	for slot in building_slots:
		if slot.has_signal("slot_selected"):
			# Building slot seçildiğinde UI göster
			if not slot.slot_selected.is_connected(_on_building_slot_selected):
				slot.slot_selected.connect(_on_building_slot_selected.bind(slot))

func _on_building_slot_selected(slot) -> void:
	if "slot_position_index" in slot and "allowed_building_types" in slot:
		# Bina seçim ekranını göster
		if get_parent() and get_parent().has_method("show_building_selection_ui"):
			get_parent().show_building_selection_ui(slot.slot_position_index, slot.allowed_building_types)

# TimeUI ile ilgili fonksiyonlar
func _setup_time_ui() -> void:
	if time_ui:
		# TimeManager'dan sinyal bağlantıları
		if not TimeManager.time_updated.is_connected(_on_time_updated):
			TimeManager.time_updated.connect(_on_time_updated)
		if not TimeManager.day_changed.is_connected(_on_day_changed):
			TimeManager.day_changed.connect(_on_day_changed)
		
		# İlk değerleri ayarla
		_update_time_ui()
		print("TimeUI sinyal bağlantıları kuruldu.")
	else:
		print("UYARI: TimeUI bulunamadı! Canvas Layer içinde TimeUI node'u ekleyin.")
		
		# TimeUI'ı bulmak için alternatif yollar dene
		var ui_nodes = get_tree().get_nodes_in_group("ui")
		print("UI grubundaki node sayısı: ", ui_nodes.size())
		
		# Tüm UI node'larını kontrol et
		var found = false
		for ui_node in get_tree().get_nodes_in_group("Control"):
			if ui_node is Control and ui_node.get_script() and ui_node.get_script().get_path().find("TimeUI") >= 0:
				print("TimeUI script'li bir node bulundu: ", ui_node.name)
				time_ui = ui_node
				found = true
				break
				
		if not found:
			print("Hiçbir TimeUI node'u bulunamadı. Canvas Layer -> TimeUI ekleyin.")

func _update_time_ui() -> void:
	if time_ui:
		# TimeManager'dan güncel zamanı al
		var time_string = TimeManager.get_time_string()
		var day_string = TimeManager.get_day_string()
		var period_string = TimeManager.get_period_string()
		
		# UI'ı güncelle
		if time_ui.has_method("update_time"):
			time_ui.update_time(time_string, day_string, period_string)

func _on_time_updated(hour: int, minute: int, time_str: String, day: int, day_str: String, period: String) -> void:
	# Zaman değiştiğinde çalışacak kod
	if time_ui and time_ui.has_method("update_time"):
		time_ui.update_time(time_str, day_str, period)

func _on_day_changed(day: int, day_str: String) -> void:
	# Gün değiştiğinde çalışacak kod
	print("Yeni gün başladı: ", day_str)
	
	# Gece/gündüz geçişlerinde görsel değişiklikler yapılabilir
	var period = TimeManager.get_period_string()
	_update_village_lighting(period)

func _update_village_lighting(period: String) -> void:
	# Gün periyoduna göre ışıklandırmayı ayarla
	# WorldEnvironment veya CanvasModulate kullanmak daha iyi olur
	# Şimdilik placeholder basit bir çözüm
	var world_modulate = $WorldModulate if has_node("WorldModulate") else null
	
	if world_modulate:
		match period:
			"Sabah":
				# Sabah ışığı - parlak sarımsı
				world_modulate.color = Color(1.0, 0.95, 0.8, 1.0)
			"Öğle":
				# Gün ışığı - beyaz
				world_modulate.color = Color(1.0, 1.0, 1.0, 1.0)
			"Akşam":
				# Akşam ışığı - turuncu/kırmızımsı
				world_modulate.color = Color(1.0, 0.7, 0.5, 1.0)
			"Gece":
				# Gece ışığı - koyu mavi
				world_modulate.color = Color(0.2, 0.2, 0.4, 1.0)

# Kaynak binalarını oluşturacak yeni fonksiyon
func create_resource_buildings():
	print("Kaynak binaları oluşturuluyor...")
	
	# Önce 'resource_buildings' grubunu temizle
	var existing_buildings = get_tree().get_nodes_in_group("resource_buildings")
	for building in existing_buildings:
		if building.is_in_group("resource_buildings"):
			building.remove_from_group("resource_buildings")
			print("Bina 'resource_buildings' grubundan çıkarıldı: ", building.name)
	
	# Bina pozisyonlarını ayarla (sahneye göre)
	var building_positions = {
		"lumberjack": Vector2(300, 850),
		"quarry": Vector2(600, 850),
		"well": Vector2(900, 850)
	}
	
	# Kaynak binalarını oluştur
	var lumberjack_path = "res://village/buildings/lumberjack.tscn"
	var quarry_path = "res://village/buildings/quarry.tscn"
	var well_path = "res://village/buildings/well.tscn"
	
	# Oduncu (lumberjack) binasını oluştur
	if ResourceLoader.exists(lumberjack_path):
		var lumberjack_scene = load(lumberjack_path)
		var lumberjack = lumberjack_scene.instantiate()
		lumberjack.position = building_positions["lumberjack"]
		add_child(lumberjack)
		lumberjack.add_to_group("resource_buildings")
		print("Oduncu binası oluşturuldu: ", lumberjack.position)
	else:
		print("UYARI: Oduncu binası bulunamadı: ", lumberjack_path)
	
	# Taş ocağı (quarry) binasını oluştur
	if ResourceLoader.exists(quarry_path):
		var quarry_scene = load(quarry_path)
		var quarry = quarry_scene.instantiate()
		quarry.position = building_positions["quarry"]
		add_child(quarry)
		quarry.add_to_group("resource_buildings")
		print("Taş ocağı binası oluşturuldu: ", quarry.position)
	else:
		print("UYARI: Taş ocağı binası bulunamadı: ", quarry_path)
	
	# Kuyu (well) binasını oluştur
	if ResourceLoader.exists(well_path):
		var well_scene = load(well_path)
		var well = well_scene.instantiate()
		well.position = building_positions["well"]
		add_child(well)
		well.add_to_group("resource_buildings")
		print("Kuyu binası oluşturuldu: ", well.position)
	else:
		print("UYARI: Kuyu binası bulunamadı: ", well_path)
		
	# Binaları oluştur ve ya mevcut dosyaları kontrol et
	check_or_create_resource_building_files()
	
	print("Kaynak binaları oluşturma tamamlandı.")

func check_or_create_resource_building_files():
	var dir = DirAccess.open("res://village/buildings")
	if dir == null:
		print("UYARI: res://village/buildings dizini bulunamadı, oluşturuluyor...")
		dir = DirAccess.make_dir_recursive_absolute("res://village/buildings")
	
	# Gerekli kaynak binası dosyalarını kontrol et ve gerekirse oluştur
	var required_buildings = {
		"lumberjack": "wood",
		"quarry": "stone",
		"well": "water"
	}
	
	for building_name in required_buildings:
		var file_path = "res://village/buildings/" + building_name + ".tscn"
		if not FileAccess.file_exists(file_path):
			create_resource_building_file(building_name, required_buildings[building_name])

func create_resource_building_file(building_name: String, resource_type: String):
	print("Yeni dosya oluşturuluyor: ", building_name, ".tscn")
	
	# Bu örnek basit bir şekilde dosya oluşturabilmek için
	# Gerçek bir tscn dosyası oluşturmak daha karmaşık olabilir
	# Bu örnekte VillagerManager dosyaları zaten var olmalı
	
	print(building_name, " için kaynak binası dosyası oluşturulması gerekiyor.")
	print("Tip: ", resource_type)
	
	# Uyarı mesajı göster
	print("UYARI: Lütfen aşağıdaki dosyaları manuel olarak Godot Editor'da oluşturun:")
	print("- res://village/buildings/", building_name, ".tscn (resource_type: ", resource_type, ")")

func _on_resource_selected(resource_node, resource_type_from_signal, resource_type_bound):
	print("Kaynak seçildi: ", resource_node.name, " - Tip: ", resource_type_bound)
	
	# VillageManager'a bildir
	VillageManager.emit_signal("resource_selected", resource_node, resource_type_bound)
	
func _on_building_slot_selected(slot_node):
	print("Bina slotu seçildi: ", slot_node.name)
	
	# VillageManager üzerinden VillageUI'a erişim deneyelim
	if VillageManager.village_ui != null:
		print("VillageUI bulundu (VillageManager üzerinden), slot_selected fonksiyonu çağrılıyor...")
		VillageManager.village_ui._on_building_slot_selected(slot_node)
	else:
		print("UYARI: VillageManager.village_ui null. VillageUI referansı bulunamadı.")
		
		# Alternatif olarak doğrudan canvas layer'da arayalım
		var ui_nodes = get_tree().get_nodes_in_group("ui")
		print("UI grubundaki node sayısı: ", ui_nodes.size())
		
		for ui_node in ui_nodes:
			if ui_node is CanvasLayer and ui_node.has_method("_on_building_slot_selected"):
				print("Uygun UI node'u bulundu: ", ui_node.name)
				ui_node._on_building_slot_selected(slot_node)
				return
		
		# Doğrudan slot'u kullanarak building_selection_ui göstermeyi deneyelim
		if slot_node.has_method("_show_building_selection_ui"):
			print("Slot üzerinden doğrudan _show_building_selection_ui çağrılıyor...")
			slot_node._show_building_selection_ui() 