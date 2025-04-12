extends Node2D # Veya sahnenizin kök node türü neyse (Node2D, Control vb.)

# Bina sahnelerini önceden yükle (Bunlar kalabilir, belki başka yerde kullanılır)
const WoodcutterCampScene = preload("res://village/buildings/WoodcutterCamp.tscn")
const StoneMineScene = preload("res://village/buildings/StoneMine.tscn")
const HunterGathererHutScene = preload("res://village/buildings/HunterGathererHut.tscn")
const WellScene = preload("res://village/buildings/Well.tscn")
const BakeryScene = preload("res://village/buildings/Bakery.tscn")

# Sahnedeki UI ve Diğer Referanslar (Eski inşa butonları kaldırıldı)
@onready var worker_assignment_ui = $WorkerAssignmentUI
@onready var cariye_management_ui = $CariyeManagementUI # YENİ PANEL
@onready var open_worker_ui_button = $OpenWorkerUIButton
@onready var open_cariye_ui_button = $OpenCariyeUIButton # YENİ BUTON
@onready var add_villager_button = $AddVillagerButton
@onready var placed_buildings_node = $PlacedBuildings
@onready var plot_markers_node = $PlotMarkers

# TimeManager node'una referans lazım (eğer farklı bir yolla erişiyorsanız ona göre ayarlayın)
@onready var time_manager: TimeManager = get_node("/root/TimeManager") # Veya doğru yolu kullanın

func _ready() -> void:
	# VillageManager'a bu sahneyi tanıt
	VillageManager.register_village_scene(self)

	# Sinyalleri bağla (Eski inşa buton bağlantıları kaldırıldı)
	open_worker_ui_button.pressed.connect(_on_open_worker_ui_button_pressed)
	open_cariye_ui_button.pressed.connect(_on_open_cariye_ui_button_pressed)
	add_villager_button.pressed.connect(VillageManager.add_villager)

	# UI görünürlük sinyallerini bağla
	worker_assignment_ui.visibility_changed.connect(_on_worker_ui_visibility_changed)
	cariye_management_ui.visibility_changed.connect(_on_cariye_ui_visibility_changed) # Yeni panel bağlandı

	# Başlangıçta UI'ları gizle
	worker_assignment_ui.hide()
	cariye_management_ui.hide()
	# Açma butonlarını göster
	open_worker_ui_button.show()
	open_cariye_ui_button.show()

# --- UI Açma / Kapatma Fonksiyonları ---
func _on_open_worker_ui_button_pressed() -> void:
	# Diğer paneli kapat (aynı anda sadece biri açık olsun)
	cariye_management_ui.hide()
	worker_assignment_ui.show()

func _on_open_cariye_ui_button_pressed() -> void:
	# Diğer paneli kapat
	worker_assignment_ui.hide()
	cariye_management_ui.show()

func _on_worker_ui_visibility_changed() -> void:
	# İşçi paneli kapandığında butonu göster, açıksa gizle
	open_worker_ui_button.visible = not worker_assignment_ui.visible
	# Eğer işçi paneli açıldıysa, cariye butonunu da göster (kapatılmış olabilir)
	if worker_assignment_ui.visible:
		open_cariye_ui_button.show()

func _on_cariye_ui_visibility_changed() -> void:
	# Cariye paneli kapandığında butonu göster, açıksa gizle
	open_cariye_ui_button.visible = not cariye_management_ui.visible
	# Eğer cariye paneli açıldıysa, işçi butonunu da göster
	if cariye_management_ui.visible:
		open_worker_ui_button.show()

# Verilen bina sahnesini belirtilen pozisyona yerleştirir (Artık VillageManager'da)
# func place_building(building_scene: PackedScene, position: Vector2) -> void:
# 	var new_building = building_scene.instantiate()
# 	# Binayı 'PlacedBuildings' altına ekle
# 	placed_buildings_node.add_child(new_building)
# 	new_building.global_position = position
# 	print("Bina inşa edildi: ", new_building.name, " at ", position)
# 	# UI'ların güncellenmesi için sinyal yay
# 	VillageManager.emit_signal("village_data_changed")

# --- Köylü Ekleme Fonksiyonu ---
func _on_add_villager_button_pressed() -> void:
	VillageManager.add_villager()
	# UI'ları sadece açıksa güncelle
	if worker_assignment_ui and worker_assignment_ui.visible: worker_assignment_ui.update_ui()
	if cariye_management_ui and cariye_management_ui.visible:
		cariye_management_ui.populate_cariye_list() # Veya daha genel bir update fonksiyonu varsa o çağrılır

# Belki UI'ın içindeki Kapat butonu yerine burada Esc ile kapatmak istersin? (Opsiyonel)
# func _input(event):
# 	if event.is_action_pressed("ui_cancel") and worker_assignment_ui.visible:
# 		worker_assignment_ui.hide()

func _input(event: InputEvent) -> void:
	# Sadece klavye tuş basımlarını dinle
	if event is InputEventKey and event.pressed and not event.is_echo():
		# 1 tuşu: Normal hız (x1)
		if event.keycode == KEY_1:
			if time_manager: # Null kontrolü
				time_manager.set_time_scale_index(0)
		# 2 tuşu: Hızlı hız (x4)
		elif event.keycode == KEY_2:
			if time_manager:
				time_manager.set_time_scale_index(1)
		# 3 tuşu: Çok hızlı hız (x16)
		elif event.keycode == KEY_3:
			if time_manager:
				time_manager.set_time_scale_index(2)
		# Veya 'T' tuşu ile hızlar arasında geçiş yap (isteğe bağlı)
		elif event.keycode == KEY_T:
			if time_manager:
				time_manager.cycle_time_scale()
		# 'N' tuşuna basıldığında yeni işçi ekle (DEBUG)
		elif event.keycode == KEY_N:
			# VillageManager autoload ise direkt çağır:
			VillageManager._add_new_worker()
			# Eğer autoload değilse ve yukarıdaki gibi @onready ile aldıysak:
			# if village_manager: village_manager._add_new_worker()
			print("DEBUG: 'N' key pressed, attempting to add new worker.")
		
		# 'M' tuşuna basıldığında rastgele işçi sil (DEBUG)
		elif event.keycode == KEY_M:
			var worker_ids = VillageManager.get_active_worker_ids() # VillageManager'da bu fonksiyonu eklememiz gerekecek
			if not worker_ids.is_empty():
				var random_worker_id = worker_ids.pick_random()
				print("DEBUG: 'M' key pressed, attempting to remove random worker: %d" % random_worker_id)
				VillageManager.remove_worker_from_village(random_worker_id)
			else:
				print("DEBUG: 'M' key pressed, but no active workers to remove.")

	# Varsa diğer _input kodları...
