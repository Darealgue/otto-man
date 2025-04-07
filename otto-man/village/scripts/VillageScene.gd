extends Node2D # Veya sahnenizin kök node türü neyse (Node2D, Control vb.)

# Bina sahnelerini önceden yükle
const WoodcutterCampScene = preload("res://village/buildings/WoodcutterCamp.tscn")
const StoneMineScene = preload("res://village/buildings/StoneMine.tscn")
const HunterGathererHutScene = preload("res://village/buildings/HunterGathererHut.tscn")
const WellScene = preload("res://village/buildings/Well.tscn")

# Sahnedeki UI ve Buton referansları
@onready var worker_assignment_ui = $WorkerAssignmentUI
@onready var open_worker_ui_button = $OpenWorkerUIButton # Bu butonu gizleyeceğiz/göstereceğiz
@onready var build_woodcutter_button = $BuildWoodcutterButton
@onready var build_stone_mine_button = $BuildStoneMineButton
@onready var build_hunter_hut_button = $BuildHunterHutButton
@onready var build_well_button = $BuildWellButton
@onready var add_villager_button = $AddVillagerButton
@onready var placed_buildings_node = $PlacedBuildings
@onready var plot_markers_node = $PlotMarkers

func _ready() -> void:
	# Sinyalleri bağla
	open_worker_ui_button.pressed.connect(_on_open_worker_ui_button_pressed)
	build_woodcutter_button.pressed.connect(_on_build_button_pressed.bind(WoodcutterCampScene, "BuildPlot1", build_woodcutter_button))
	build_stone_mine_button.pressed.connect(_on_build_button_pressed.bind(StoneMineScene, "BuildPlot2", build_stone_mine_button))
	build_hunter_hut_button.pressed.connect(_on_build_button_pressed.bind(HunterGathererHutScene, "BuildPlot3", build_hunter_hut_button))
	build_well_button.pressed.connect(_on_build_button_pressed.bind(WellScene, "BuildPlot4", build_well_button))
	add_villager_button.pressed.connect(_on_add_villager_button_pressed)
	
	# --- YENİ: UI görünürlük sinyalini bağla ---
	worker_assignment_ui.visibility_changed.connect(_on_worker_ui_visibility_changed)
	# -----------------------------------------

	# Başlangıçta UI'ın gizli olduğundan emin ol
	worker_assignment_ui.hide()
	# Başlangıçta açma butonunun görünür olduğundan emin ol
	open_worker_ui_button.show()

func _on_open_worker_ui_button_pressed() -> void:
	worker_assignment_ui.show()
	# Butonu UI açıldığında gizle (opsiyonel: animasyonla da yapılabilir)
	# open_worker_ui_button.hide() # _on_worker_ui_visibility_changed halledecek

# --- YENİ Fonksiyon: UI Paneli Görünürlüğü Değiştiğinde ---
func _on_worker_ui_visibility_changed() -> void:
	if worker_assignment_ui.visible:
		# UI görünürse, açma butonunu gizle
		open_worker_ui_button.hide()
	else:
		# UI gizlenirse, açma butonunu göster
		open_worker_ui_button.show()
# -------------------------------------------------------

# --- Genel İnşa Fonksiyonu ---
func _on_build_button_pressed(building_scene: PackedScene, target_plot_name: String, button_pressed: Button) -> void:
	# Plot marker'ını marker konteynerinden al
	var target_plot_marker = plot_markers_node.get_node_or_null(target_plot_name) 
	
	if not target_plot_marker:
		print("Hata: Plot marker '", target_plot_name, "' bulunamadı!")
		return
		
	var target_position = target_plot_marker.global_position

	# --- Doluluk Kontrolü (GÜNCELLENDİ: PlacedBuildings içinde ara) ---
	var plot_occupied = false
	for child in placed_buildings_node.get_children(): # Yerleştirilmiş binaları kontrol et
		if child is Node2D and child.global_position.distance_to(target_position) < 1.0:
			plot_occupied = true
			break
	
	if plot_occupied:
		print("Hata: ", target_plot_name, " (", target_position, ") zaten dolu!")
		return 
	# --- KONTROL BİTTİ ---
		
	# Kontrol: Yeterli kaynak var mı? (Daha sonra eklenecek)
	
	# Binayı yerleştir
	place_building(building_scene, target_position)
	
	# Başarılı inşa sonrası butonu devre dışı bırak
	if button_pressed:
		button_pressed.disabled = true 
	
	# UI'ı güncelle
	if worker_assignment_ui: 
		worker_assignment_ui.update_ui() 
			

# Verilen bina sahnesini belirtilen pozisyona yerleştirir (GÜNCELLENDİ)
func place_building(building_scene: PackedScene, position: Vector2) -> void:
	var new_building = building_scene.instantiate()
	# Binayı 'PlacedBuildings' altına ekle
	placed_buildings_node.add_child(new_building) 
	new_building.global_position = position
	print("Bina inşa edildi: ", new_building.name, " at ", position)

# --- Yeni Köylü Ekleme Buton Fonksiyonu ---
func _on_add_villager_button_pressed() -> void:
	VillageManager.add_villager()
	# Köylü eklenince UI'ı da güncelleyelim
	if worker_assignment_ui:
		worker_assignment_ui.update_ui()

# Belki UI'ın içindeki Kapat butonu yerine burada Esc ile kapatmak istersin? (Opsiyonel)
# func _input(event):
# 	if event.is_action_pressed("ui_cancel") and worker_assignment_ui.visible:
# 		worker_assignment_ui.hide()
