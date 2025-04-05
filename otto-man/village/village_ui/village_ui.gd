extends CanvasLayer
class_name VillageUI

# Preloaded scenes
var worker_button_scene = preload("res://village/village_ui/worker_assignment_button.tscn")
var resource_assignment_scene = preload("res://village/village_ui/resource_assignment_screen.tscn")
var building_assignment_screen = preload("res://village/village_ui/building_assignment_screen.tscn")
var building_selection_ui_scene = preload("res://village/village_ui/building_selection_ui.tscn")

# Signals
signal ui_closed

# Child nodes
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var main_menu: Control = $MainMenu
@onready var resource_screen: Control 
@onready var building_screen: Control 
@onready var worker_list: VBoxContainer = $MainMenu/PanelContainer/MarginContainer/VBoxContainer/WorkerList
@onready var building_selection_ui: Control
@onready var resource_assignment_screen: Control

# Screens enum
enum Screen { MAIN, RESOURCE, BUILDING }
var current_screen: int = Screen.MAIN

# Menu navigation
var main_menu_buttons = []
var current_main_menu_index = 0
var is_ui_active = false

# İşçi verileri
var available_workers = []
var selected_resource_type: String = ""

func _ready() -> void:
	# Set default visibility
	visible = false
	is_ui_active = false
	
	# Liste menü butonlarını
	main_menu_buttons = [
		$MainMenu/PanelContainer/MarginContainer/VBoxContainer/ResourceButton,
		$MainMenu/PanelContainer/MarginContainer/VBoxContainer/BuildingButton,
		$MainMenu/PanelContainer/MarginContainer/VBoxContainer/BackButton
	]
	
	# Butonlara focus modunu aktif et
	for button in main_menu_buttons:
		button.focus_mode = Control.FOCUS_ALL
	
	# Buton bağlantılarını kur
	$MainMenu/PanelContainer/MarginContainer/VBoxContainer/ResourceButton.pressed.connect(_on_resource_button_pressed)
	$MainMenu/PanelContainer/MarginContainer/VBoxContainer/BuildingButton.pressed.connect(_on_building_button_pressed)
	$MainMenu/PanelContainer/MarginContainer/VBoxContainer/BackButton.pressed.connect(_on_back_button_pressed)
	
	# Building Selection UI'ı oluştur
	building_selection_ui = building_selection_ui_scene.instantiate()
	add_child(building_selection_ui)
	building_selection_ui.visible = false
	building_selection_ui.building_selected.connect(_on_building_selection_ui_building_selected)
	building_selection_ui.ui_closed.connect(_on_building_selection_ui_closed)
	
	# Resource Assignment Screen'i oluştur
	resource_assignment_screen = resource_assignment_scene.instantiate()
	add_child(resource_assignment_screen)
	resource_assignment_screen.visible = false
	resource_assignment_screen.connect("back_button_pressed", _on_resource_assignment_back_pressed)
	resource_assignment_screen.connect("worker_assigned", _on_worker_assigned)
	
	# Ekran hazırlığı
	_initialize_worker_list()
	
	# BuildingSlot node'larını bul ve sinyallerini bağla
	_connect_building_slots()
	
	# ResourceBuilding sinyallerini bağla
	_connect_resource_buildings()
	
	# VillageManager'a UI referansını ver
	VillageManager.village_ui = self

# ResourceBuilding'leri bul ve sinyallerini bağla
func _connect_resource_buildings() -> void:
	# Sahnedeki tüm resource building'leri bul
	var resource_buildings = get_tree().get_nodes_in_group("resource_buildings")
	
	# Her resource building için sinyalleri bağla
	for resource in resource_buildings:
		if resource is ResourceBuilding:
			resource.resource_selected.connect(_on_resource_selected)

func _connect_building_slots() -> void:
	# Sahnedeki tüm building slot'ları bul
	var building_slots = get_tree().get_nodes_in_group("building_slots")
	
	# Her slot için sinyalleri bağla
	for slot in building_slots:
		if "slot_selected" in slot and slot.has_signal("slot_selected"):
			slot.slot_selected.connect(_on_building_slot_selected.bind(slot))

func _on_building_slot_selected(slot) -> void:
	# Doğru verip vermediğini kontrol et
	if slot == null:
		return
	
	# Building selection UI'ın durumunu kontrol et
	if building_selection_ui == null:
		return
	
	# Bina seçim UI'ını göster
	if "slot_position_index" in slot and "allowed_building_types" in slot:
		building_selection_ui.show_for_slot(slot.slot_position_index, slot.allowed_building_types)
	else:
		print("UYARI: Slot indeksi veya izin verilen bina tipleri bulunamadı")

func _on_building_selection_ui_building_selected(building_type: String) -> void:
	# BuildingSlot'u bul
	var slot_index = building_selection_ui.current_slot_index
	var building_slots = get_tree().get_nodes_in_group("building_slots")
	
	for slot in building_slots:
		if "slot_position_index" in slot and slot.slot_position_index == slot_index:
			# Binayı inşa et
			if slot.has_method("build_building"):
				slot.build_building(building_type)
			break

func _on_building_selection_ui_closed() -> void:
	# Ana menüyü tekrar göster
	main_menu.visible = true

# Kaynak seçildiğinde çağrılacak fonksiyon
func _on_resource_selected(resource_node: Node, resource_type: String) -> void:
	show_resource_assignment_screen(resource_type)

# Kaynak atama ekranını göster
func show_resource_assignment_screen(resource_type: String = "") -> void:
	# Ana menüyü gizle
	main_menu.visible = false
	
	# İşçi atama ekranını göster
	if resource_assignment_screen:
		# Ekran bir instantiated node ise
		if resource_assignment_screen is Node and resource_assignment_screen.is_inside_tree():
			resource_assignment_screen.visible = true
			
			# Seçilen kaynak tipini ayarla (eğer belirtilmişse)
			if resource_type != "" and resource_assignment_screen.has_method("set_resource_type"):
				resource_assignment_screen.set_resource_type(resource_type)
			
			# İlk uygun işçiyi seç (eğer henüz işçi seçili değilse)
			_select_first_available_worker()
		# Ekran henüz instantiate edilmemiş olabilir
		else:
			# Instance kontrolü, değişken bir Control olmuş olabilir 
			# ama henüz ağaca eklenmemiş olabilir
			if resource_assignment_screen is Control and not resource_assignment_screen.is_inside_tree():
				add_child(resource_assignment_screen)
				resource_assignment_screen.visible = true
				
				# Seçilen kaynak tipini ayarla (eğer belirtilmişse)
				if resource_type != "" and resource_assignment_screen.has_method("set_resource_type"):
					resource_assignment_screen.set_resource_type(resource_type)
				
				# İlk uygun işçiyi seç
				_select_first_available_worker()
			# Yeni bir instance oluştur
			else:
				# Bu satırı tekrar preload yaparak çözelim, orijinal PackedScene'i koruyalım
				var resource_assignment_scene_preload = preload("res://village/village_ui/resource_assignment_screen.tscn")
				var screen_instance = resource_assignment_scene_preload.instantiate()
				add_child(screen_instance)
				resource_assignment_screen = screen_instance
				resource_assignment_screen.visible = true
				
				# Seçilen kaynak tipini ayarla (eğer belirtilmişse)
				if resource_type != "" and resource_assignment_screen.has_method("set_resource_type"):
					resource_assignment_screen.set_resource_type(resource_type)
				
				# İlk uygun işçiyi seç
				_select_first_available_worker()
	else:
		print("HATA: ResourceAssignmentScreen bulunamadı!")

func _input(event: InputEvent) -> void:
	if not is_ui_active:
		return
	
	if current_screen == Screen.MAIN:
		# Ana menüde navigasyon
		if event.is_action_pressed("ui_up"):
			_navigate_main_menu(-1)
			get_viewport().set_input_as_handled()
			
		elif event.is_action_pressed("ui_down"):
			_navigate_main_menu(1)
			get_viewport().set_input_as_handled()
			
		elif event.is_action_pressed("attack"): # Ataca doğru
			_select_main_menu_item()
			get_viewport().set_input_as_handled()
			
		elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("jump"):
			close_ui()
			get_viewport().set_input_as_handled()
	
	elif current_screen == Screen.RESOURCE or current_screen == Screen.BUILDING:
		# Alt ekranlarda geri dönüş
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("jump"):
			_return_to_main_menu()
			get_viewport().set_input_as_handled()

func _navigate_main_menu(direction: int) -> void:
	if main_menu_buttons.is_empty():
		return
	
	# Önceki butonu normal hale getir
	main_menu_buttons[current_main_menu_index].release_focus()
	
	# Yeni indeksi hesapla
	current_main_menu_index = (current_main_menu_index + direction + main_menu_buttons.size()) % main_menu_buttons.size()
	
	# Yeni butona odak ver
	main_menu_buttons[current_main_menu_index].grab_focus()

func _select_main_menu_item() -> void:
	if main_menu_buttons.is_empty():
		return
	
	# Seçilen butonu çalıştır
	main_menu_buttons[current_main_menu_index].emit_signal("pressed")

func show_ui() -> void:
	# UI'ı göster ve aktif et
	visible = true
	is_ui_active = true
	
	# Animasyonu oynat
	animation_player.play("show")
	
	# Ana menüyü göster, diğer ekranları gizle
	_switch_to_screen(Screen.MAIN)
	
	# İlk butona odak ver
	if not main_menu_buttons.is_empty():
		current_main_menu_index = 0
		main_menu_buttons[current_main_menu_index].grab_focus()

func close_ui() -> void:
	# UI'ı kapat
	animation_player.play("hide")
	is_ui_active = false
	
	# Sinyal gönder
	ui_closed.emit()
	
	# Butonu bırak
	if current_screen == Screen.MAIN and not main_menu_buttons.is_empty():
		main_menu_buttons[current_main_menu_index].release_focus()

func _on_animation_player_animation_finished(anim_name: String) -> void:
	# "hide" animasyonu bittiğinde UI'ı tamamen gizle
	if anim_name == "hide":
		visible = false

func _initialize_worker_list() -> void:
	# Mevcut işçi butonlarını temizle
	for child in worker_list.get_children():
		child.queue_free()
	
	# Kullanılabilir işçi listesini temizle
	available_workers.clear()
	
	# Village Manager'dan işçi verilerini al
	var workers_data = VillageManager.get_workers_data()
	
	# Her işçi için buton oluştur
	for worker_id in workers_data:
		var worker_data = workers_data[worker_id]
		var button = worker_button_scene.instantiate()
		worker_list.add_child(button)
		
		button.set_worker_id(worker_id)
		button.set_worker_name("İşçi #" + str(worker_id))
		
		# Atanmış kaynak veya bina varsa göster
		if worker_data.assigned_to != "":
			button.set_assigned_resource(worker_data.assigned_to)
		else:
			# Atanmamış işçileri takip et
			available_workers.append(worker_id)
		
		# Butona tıklama olayını bağla
		button.pressed.connect(_on_worker_button_selected.bind(button))

func _switch_to_screen(screen: int) -> void:
	# Önceki ekranları temizle ve yeni ekrana geç
	current_screen = screen
	
	# Ekranları gizle
	main_menu.visible = false
	if resource_screen:
		resource_screen.visible = false
	if building_screen:
		building_screen.visible = false
	
	# İstenen ekranı göster
	match screen:
		Screen.MAIN:
			main_menu.visible = true
		Screen.RESOURCE:
			if not resource_screen:
				resource_screen = resource_assignment_screen.instantiate()
				add_child(resource_screen)
				# Sinyalleri bağla
				resource_screen.back_button_pressed.connect(_return_to_main_menu)
				resource_screen.worker_assigned.connect(_on_resource_assignment_screen_worker_assigned)
			resource_screen.visible = true
			
			# Kaynak ekranına geçtiğimizde otomatik olarak ilk işçiyi seç
			_select_first_available_worker()
		Screen.BUILDING:
			if not building_screen:
				building_screen = building_assignment_screen.instantiate()
				add_child(building_screen)
				# Sinyalleri bağla
				building_screen.back_button_pressed.connect(_return_to_main_menu)
				building_screen.worker_assigned.connect(_on_building_assignment_screen_worker_assigned)
			building_screen.visible = true
			
			# Bina ekranına geçtiğimizde otomatik olarak ilk işçiyi seç
			_select_first_available_worker()

# İlk müsait işçiyi otomatik olarak seç
func _select_first_available_worker() -> void:
	# Müsait işçileri kontrol et
	var unassigned_workers = VillageManager.available_workers
	
	if unassigned_workers.size() > 0:
		var worker_id = unassigned_workers[0]
		
		# Resource assignment ekranına işçi ID'sini ilet
		if resource_assignment_screen and resource_assignment_screen.has_method("set_selected_worker"):
			resource_assignment_screen.set_selected_worker(worker_id)
	else:
		# TODO: Bildirim göster
		pass

func _on_resource_button_pressed() -> void:
	# Doğrudan kaynak atama ekranını aç
	show_resource_assignment_screen()

func _on_building_button_pressed() -> void:
	# Tüm boş building slotlarını göster ve inşa UI'ını aç
	var building_slots = get_tree().get_nodes_in_group("building_slots")
	
	# Kullanılabilir slotları filtrele
	var available_slots = []
	for slot in building_slots:
		if "has_building" in slot and not slot.has_building:
			available_slots.append(slot)
	
	if available_slots.size() > 0:
		# Ana menüyü gizle
		main_menu.visible = false
		
		# İlk boş slotu kullan
		var first_slot = available_slots[0]
		if "slot_position_index" in first_slot and "allowed_building_types" in first_slot:
			building_selection_ui.show_for_slot(first_slot.slot_position_index, first_slot.allowed_building_types)
		else:
			print("UYARI: Slot özellikleri eksik")
	else:
		print("UYARI: İnşa edilecek boş slot yok")

func _on_back_button_pressed() -> void:
	close_ui()

func _return_to_main_menu() -> void:
	_switch_to_screen(Screen.MAIN)
	
	# Ana menüde önceki seçilmiş butona odak ver
	if not main_menu_buttons.is_empty():
		main_menu_buttons[current_main_menu_index].grab_focus()

func _on_worker_button_selected(button) -> void:
	# Seçilen işçi için atama ekranını göster
	var worker_id = button.worker_id
	
	if current_screen == Screen.RESOURCE and resource_screen:
		resource_screen.set_selected_worker(worker_id)
	elif current_screen == Screen.BUILDING and building_screen:
		building_screen.set_selected_worker(worker_id)

func _on_building_assignment_screen_worker_assigned(worker_id: int, building_id: int) -> void:
	print("İşçi ", worker_id, " binaya atandı: ", building_id)
	_initialize_worker_list()  # İşçi listesini güncelle

func _on_resource_assignment_screen_worker_assigned(worker_id: int, resource_type: String) -> void:
	print("İşçi ", worker_id, " kaynağa atandı: ", resource_type)
	_initialize_worker_list()  # İşçi listesini güncelle

# Resource Assignment ekranı sinyal işleyicileri
func _on_resource_assignment_back_pressed() -> void:
	if resource_assignment_screen:
		resource_assignment_screen.visible = false
	main_menu.visible = true

func _on_worker_assigned(worker_id: int, resource_type: String) -> void:
	if resource_assignment_screen:
		resource_assignment_screen.visible = false
	main_menu.visible = true 
