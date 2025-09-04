extends CanvasLayer

# Sayfa türleri
enum PageType { MISSIONS, ASSIGNMENT, CONSTRUCTION }

# İnşaat menüsü için enum'lar
enum ConstructionAction { BUILD, UPGRADE, DEMOLISH, INFO }
enum BuildingCategory { PRODUCTION, LIFE, MILITARY, DECORATION }

# Menü durumları (PlayStation mantığı)
enum MenuState { İŞLEM_SEÇİMİ, KATEGORİ_SEÇİMİ, BİNA_SEÇİMİ }

# Atama sayfası için menü durumları
enum AssignmentMenuState { BİNA_LISTESİ, BİNA_DETAYI }

# Görevler sayfası için menü durumları
enum MissionMenuState { GÖREV_LISTESİ, CARİYE_SEÇİMİ, GÖREV_DETAYI }

# Mevcut sayfa
var current_page: PageType = PageType.MISSIONS

# İnşaat seçimleri
var current_construction_action: int = ConstructionAction.BUILD
var current_building_category: int = BuildingCategory.PRODUCTION
var current_building_index: int = 0  # Bina seçimi için index

# Atama seçimleri
var current_assignment_building_index: int = 0 # Atama sayfasında bina seçimi için index
var current_assignment_menu_state: AssignmentMenuState = AssignmentMenuState.BİNA_LISTESİ # Atama sayfasındaki menü durumu

# Görevler seçimleri
var current_mission_index: int = 0 # Görevler sayfasında görev seçimi için index
var current_mission_menu_state: MissionMenuState = MissionMenuState.GÖREV_LISTESİ # Görevler sayfasındaki menü durumu
var current_cariye_index: int = 0 # Cariye seçimi için index

# Menü durumu (PlayStation mantığı)
var current_menu_state: MenuState = MenuState.İŞLEM_SEÇİMİ

# UI referansları
@onready var missions_page: Control = $MissionsPage
@onready var assignment_page: Control = $AssignmentPage
@onready var construction_page: Control = $ConstructionPage
@onready var page_label: Label = $PageLabel

# Görevler sayfası UI referansları
@onready var idle_cariyeler_label: Label = $MissionsPage/MissionsHeader/IdleCariyelerLabel
@onready var active_missions_list: VBoxContainer = $MissionsPage/MainContent/ActiveMissionsPanel/ActiveMissionsScroll/ActiveMissionsList
@onready var available_missions_list: VBoxContainer = $MissionsPage/MainContent/AvailableMissionsPanel/AvailableMissionsScroll/AvailableMissionsList
@onready var cariye_selection_panel: VBoxContainer = $MissionsPage/CariyeSelectionPanel
@onready var cariye_selection_list: VBoxContainer = $MissionsPage/CariyeSelectionPanel/CariyeSelectionScroll/CariyeSelectionList
@onready var mission_result_panel: VBoxContainer = $MissionsPage/MissionResultPanel
@onready var mission_result_content: Label = $MissionsPage/MissionResultPanel/MissionResultContent

# Sayfa isimleri
var page_names: Array[String] = ["GÖREVLER", "ATAMALAR", "İNŞAAT"]

# Action ve Category isimleri
var action_names: Array[String] = ["YAP", "YÜKSELT", "YIK", "BİLGİ"]
var category_names: Array[String] = ["ÜRETİM", "YAŞAM", "ORDU", "DEKORASYON"]

# Bina türleri kategorilere göre (gerçek bina türleri)
var building_categories: Dictionary = {
	BuildingCategory.PRODUCTION: ["Kuyu", "Avcı", "Oduncu", "Taş Madeni", "Fırın"],
	BuildingCategory.LIFE: ["Ev"],
	BuildingCategory.MILITARY: ["Kale", "Kule"], # Gelecekte eklenecek
	BuildingCategory.DECORATION: ["Çeşme", "Bahçe"] # Gelecekte eklenecek
}

# Bina sahne yolları (gerçek dosya yolları)
var building_scene_paths: Dictionary = {
	"Kuyu": "res://village/buildings/Well.tscn",
	"Avcı": "res://village/buildings/HunterGathererHut.tscn",
	"Oduncu": "res://village/buildings/WoodcutterCamp.tscn",
	"Taş Madeni": "res://village/buildings/StoneMine.tscn",
	"Fırın": "res://village/buildings/Bakery.tscn",
	"Ev": "res://village/buildings/House.tscn"
}

# Player referansı
var player: Node2D

# VillageManager referansı
var village_manager: Node

# B tuşu timer sistemi
var b_button_timer: float = 0.0
var b_button_pressed: bool = false
var b_button_hold_time: float = 0.5  # 0.5 saniye basılı tutarsa menü kapanır

# Görevler sayfası güncelleme timer'ı
var missions_update_timer: float = 0.0
var missions_update_interval: float = 1.0  # Her 1 saniyede bir güncelle

# Görev sonuçları gösterimi
var mission_result_timer: float = 0.0
var mission_result_duration: float = 5.0  # 5 saniye göster
var current_mission_result: Dictionary = {}
var showing_mission_result: bool = false

func _ready():
	print("=== MISSION CENTER DEBUG ===")
	print("MissionCenter _ready() çağrıldı!")
	print("===============================")

	# VillageManager'ı bul (önce autoload olarak, sonra group olarak)
	village_manager = get_tree().get_first_node_in_group("VillageManager")
	if not village_manager:
		print("VillageManager group'ta bulunamadı, autoload olarak aranıyor...")
		village_manager = get_node("/root/VillageManager")
	
	if village_manager:
		print("✅ VillageManager bulundu: ", village_manager.name)
		# Görev tamamlandığında sinyal dinle
		village_manager.connect("mission_completed", _on_mission_completed)
	else:
		print("❌ VillageManager bulunamadı! Group: VillageManager, Autoload: /root/VillageManager")

	# Player'ı bul ve kilitle
	find_and_lock_player()
	
	# Başlangıç sayfasını göster
	show_page(current_page)

func find_and_lock_player():
	print("=== PLAYER LOCK DEBUG ===")
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("Player bulundu: ", player.name)
		player.set_process(false)
		player.set_physics_process(false)
		player.set_process_input(false)
		player.set_process_unhandled_input(false)

		if player.has_method("set_input_enabled"):
			player.set_input_enabled(false)
		if player.has_method("disable_movement"):
			player.disable_movement()

		print("=== PLAYER LOCK TAMAMLANDI ===")
	else:
		print("Player bulunamadı! Group: player")

func unlock_player():
	if player:
		print("=== PLAYER UNLOCK DEBUG ===")
		player.set_process(true)
		player.set_physics_process(true)
		player.set_process_input(true)
		player.set_process_unhandled_input(true)

		if player.has_method("set_input_enabled"):
			player.set_input_enabled(true)
		if player.has_method("enable_movement"):
			player.enable_movement()

		print("=== PLAYER UNLOCK TAMAMLANDI ===")

func _process(delta):
	# B tuşu timer sistemi
	if Input.is_action_pressed("ui_back"):
		if not b_button_pressed:
			b_button_pressed = true
			b_button_timer = 0.0
			print("=== B TUŞU BASILDI - TIMER BAŞLADI ===")
		
		b_button_timer += delta
		
		# Basılı tutma süresi aşıldıysa menüyü kapat
		if b_button_timer >= b_button_hold_time:
			print("=== B TUŞU BASILI TUTULDU - MENÜ KAPANIYOR ===")
			close_menu()
			return
	else:
		# B tuşu bırakıldı
		if b_button_pressed:
			print("=== B TUŞU BIRAKILDI - GERİ GİTME ===")
			handle_back_button()
			b_button_pressed = false
			b_button_timer = 0.0

	# Sayfa navigasyonu (L2/R2)
	if Input.is_action_just_pressed("l2_trigger"):
		print("=== L2 TRIGGER ===")
		previous_page()
	elif Input.is_action_just_pressed("r2_trigger"):
		print("=== R2 TRIGGER ===")
		next_page()

	# İnşaat sayfasında D-pad navigasyonu
	if current_page == PageType.CONSTRUCTION:
		handle_construction_navigation()

	# Atama sayfasında D-pad navigasyonu
	if current_page == PageType.ASSIGNMENT:
		handle_assignment_navigation()
	
	# Görevler sayfasında D-pad navigasyonu
	if current_page == PageType.MISSIONS:
		handle_missions_navigation()
		
		# Görevler sayfası güncelleme timer'ı
		missions_update_timer += delta
		if missions_update_timer >= missions_update_interval:
			missions_update_timer = 0.0
			update_missions_ui()  # Aktif görevlerin sürelerini güncelle
		
		# Görev sonuçları timer'ı
		if showing_mission_result:
			mission_result_timer += delta
			if mission_result_timer >= mission_result_duration:
				showing_mission_result = false
				mission_result_timer = 0.0
				update_missions_ui()  # Normal görev listesine dön

# Atama sayfasında D-pad navigasyonu
func handle_assignment_navigation():
	match current_assignment_menu_state:
		AssignmentMenuState.BİNA_LISTESİ:
			handle_assignment_building_list_selection()
		AssignmentMenuState.BİNA_DETAYI:
			handle_assignment_building_detail()

# İnşaat sayfasında D-pad navigasyonu (PlayStation mantığı)
func handle_construction_navigation():
	# İnşaat sayfasında değilse çık
	if current_page != PageType.CONSTRUCTION:
		return

	match current_menu_state:
		MenuState.İŞLEM_SEÇİMİ:
			handle_action_selection()
		MenuState.KATEGORİ_SEÇİMİ:
			handle_category_selection()
		MenuState.BİNA_SEÇİMİ:
			handle_building_selection()

# İşlem seçimi seviyesi (YAP/YÜKSELT/YIK/BİLGİ)
func handle_action_selection():
	# Sol/Sağ D-pad: İşlem seçimi
	if Input.is_action_just_pressed("ui_left"):
		print("=== SOL D-PAD: İşlem değiştiriliyor ===")
		current_construction_action = (current_construction_action - 1) % action_names.size()
		if current_construction_action < 0:
			current_construction_action = action_names.size() - 1
		print("Yeni işlem: ", action_names[current_construction_action])
		update_construction_ui()

	elif Input.is_action_just_pressed("ui_right"):
		print("=== SAĞ D-PAD: İşlem değiştiriliyor ===")
		current_construction_action = (current_construction_action + 1) % action_names.size()
		print("Yeni işlem: ", action_names[current_construction_action])
		update_construction_ui()

	# A tuşu (ui_forward): İşlemi seç, kategorilere geç
	elif Input.is_action_just_pressed("ui_forward"):
		print("=== A TUŞU: İşlem seçildi, kategorilere geçiliyor ===")
		current_menu_state = MenuState.KATEGORİ_SEÇİMİ
		update_construction_ui()

# Kategori seçimi seviyesi (ÜRETİM/YAŞAM/ORDU/DEKORASYON)
func handle_category_selection():
	# Sol/Sağ D-pad: Kategori seçimi
	if Input.is_action_just_pressed("ui_left"):
		print("=== SOL D-PAD: Kategori değiştiriliyor ===")
		current_building_category = (current_building_category - 1) % category_names.size()
		if current_building_category < 0:
			current_building_category = category_names.size() - 1
		print("Yeni kategori: ", category_names[current_building_category])
		update_construction_ui()

	elif Input.is_action_just_pressed("ui_right"):
		print("=== SAĞ D-PAD: Kategori değiştiriliyor ===")
		current_building_category = (current_building_category + 1) % category_names.size()
		print("Yeni kategori: ", category_names[current_building_category])
		update_construction_ui()

	# A tuşu (ui_forward): Kategoriyi seç, binalara geç
	elif Input.is_action_just_pressed("ui_forward"):
		print("=== A TUŞU: Kategori seçildi, binalara geçiliyor ===")
		current_menu_state = MenuState.BİNA_SEÇİMİ
		update_construction_ui()

	# B tuşu: Geri dön, işlem seçimine
	elif Input.is_action_just_pressed("ui_cancel"):
		print("=== B TUŞU: Geri dönülüyor, işlem seçimine ===")
		current_menu_state = MenuState.İŞLEM_SEÇİMİ
		update_construction_ui()

# Bina seçimi seviyesi
func handle_building_selection():
	var buildings = building_categories.get(current_building_category, [])
	if buildings.is_empty():
		print("Bu kategoride bina yok!")
		return
	
	# Yukarı/Aşağı D-pad: Bina seçimi
	if Input.is_action_just_pressed("ui_up"):
		print("=== YUKARI D-PAD: Bina seçimi ===")
		current_building_index = (current_building_index - 1) % buildings.size()
		if current_building_index < 0:
			current_building_index = buildings.size() - 1
		print("Seçilen bina: ", buildings[current_building_index])
		update_construction_ui()

	elif Input.is_action_just_pressed("ui_down"):
		print("=== AŞAĞI D-PAD: Bina seçimi ===")
		current_building_index = (current_building_index + 1) % buildings.size()
		print("Seçilen bina: ", buildings[current_building_index])
		update_construction_ui()

	# A tuşu (ui_forward): Bina inşa et
	elif Input.is_action_just_pressed("ui_forward"):
		print("=== A TUŞU: Bina inşa ediliyor ===")
		execute_build_action()
		# İşlem tamamlandı, başa dön
		current_menu_state = MenuState.İŞLEM_SEÇİMİ
		current_building_index = 0  # Bina seçimini sıfırla
		update_construction_ui()

	# B tuşu: Geri dön, kategori seçimine
	elif Input.is_action_just_pressed("ui_cancel"):
		print("=== B TUŞU: Geri dönülüyor, kategori seçimine ===")
		current_menu_state = MenuState.KATEGORİ_SEÇİMİ
		current_building_index = 0  # Bina seçimini sıfırla
		update_construction_ui()

# İnşaat UI'ını güncelle (PlayStation mantığı)
func update_construction_ui():
	if current_page == PageType.CONSTRUCTION:
		var action_label = construction_page.get_node_or_null("ActionRow/ActionLabel")
		var category_label = construction_page.get_node_or_null("CategoryRow/CategoryLabel")
		var buildings_label = construction_page.get_node_or_null("BuildingsLabel")
		
		# İşlem seçimi seviyesi
		if current_menu_state == MenuState.İŞLEM_SEÇİMİ:
			if action_label:
				action_label.text = "İŞLEM: " + action_names[current_construction_action] + " ← SEÇİLİ"
			if category_label:
				category_label.text = "KATEGORİ: [A tuşu ile seç]"
			if buildings_label:
				buildings_label.text = "BİNALAR: [Önce işlem seçin]"
		
		# Kategori seçimi seviyesi
		elif current_menu_state == MenuState.KATEGORİ_SEÇİMİ:
			if action_label:
				action_label.text = "İŞLEM: " + action_names[current_construction_action] + " ✓"
			if category_label:
				category_label.text = "KATEGORİ: " + category_names[current_building_category] + " ← SEÇİLİ"
			if buildings_label:
				buildings_label.text = "BİNALAR: [A tuşu ile seç]"
		
		# Bina seçimi seviyesi
		elif current_menu_state == MenuState.BİNA_SEÇİMİ:
			if action_label:
				action_label.text = "İŞLEM: " + action_names[current_construction_action] + " ✓"
			if category_label:
				category_label.text = "KATEGORİ: " + category_names[current_building_category] + " ✓"
			if buildings_label:
				var buildings = building_categories.get(current_building_category, [])
				var buildings_text = "BİNALAR:\n"
				
				for i in range(buildings.size()):
					var building_name = buildings[i]
					var building_info = get_building_status_info(building_name)
					
					if i == current_building_index:
						buildings_text += "• " + building_name + " ← SEÇİLİ\n"
						buildings_text += "  " + building_info + "\n"
					else:
						buildings_text += "• " + building_name + "\n"
						buildings_text += "  " + building_info + "\n"
				
				# İşlem türüne göre farklı açıklamalar
				match current_construction_action:
					ConstructionAction.BUILD:
						buildings_text += "\n[A tuşu ile inşa et] [B tuşu ile geri dön]"
					ConstructionAction.UPGRADE:
						buildings_text += "\n[A tuşu ile yükselt] [B tuşu ile geri dön]"
					ConstructionAction.DEMOLISH:
						buildings_text += "\n[A tuşu ile yık] [B tuşu ile geri dön]"
					ConstructionAction.INFO:
						buildings_text += "\n[A tuşu ile bilgi göster] [B tuşu ile geri dön]"
				
				buildings_label.text = buildings_text

# Atama bina listesi seçimi
func handle_assignment_building_list_selection():
	var all_buildings = get_all_available_buildings()
	if all_buildings.is_empty():
		print("Atanabilir bina yok!")
		return
	
	# Yukarı/Aşağı D-pad: Bina seçimi
	if Input.is_action_just_pressed("ui_up"):
		print("=== YUKARI D-PAD: Bina seçimi ===")
		current_assignment_building_index = (current_assignment_building_index - 1) % all_buildings.size()
		if current_assignment_building_index < 0:
			current_assignment_building_index = all_buildings.size() - 1
		print("Seçilen bina: ", all_buildings[current_assignment_building_index]["name"])
		update_assignment_ui()

	elif Input.is_action_just_pressed("ui_down"):
		print("=== AŞAĞI D-PAD: Bina seçimi ===")
		current_assignment_building_index = (current_assignment_building_index + 1) % all_buildings.size()
		print("Seçilen bina: ", all_buildings[current_assignment_building_index]["name"])
		update_assignment_ui()

	# Sol/Sağ D-pad: İşçi ekle/çıkar
	elif Input.is_action_just_pressed("ui_left"):
		print("=== SOL D-PAD: İşçi çıkarılıyor ===")
		remove_worker_from_building(all_buildings[current_assignment_building_index])
		update_assignment_ui()

	elif Input.is_action_just_pressed("ui_right"):
		print("=== SAĞ D-PAD: İşçi ekleniyor ===")
		add_worker_to_building(all_buildings[current_assignment_building_index])
		update_assignment_ui()

	# A tuşu (ui_forward): Bina detayına geç
	elif Input.is_action_just_pressed("ui_forward"):
		print("=== A TUŞU: Bina detayına geçiliyor ===")
		current_assignment_menu_state = AssignmentMenuState.BİNA_DETAYI
		update_assignment_ui()

# Atama bina detayı
func handle_assignment_building_detail():
	var all_buildings = get_all_available_buildings()
	if all_buildings.is_empty():
		print("Atanabilir bina yok!")
		return
	
	var selected_building_info = all_buildings[current_assignment_building_index]
	var building_node = selected_building_info["node"]
	var building_type = selected_building_info["type"]
	
	var info = get_building_detailed_info(building_node, building_type)
	print("📋 Bina Detayları:")
	print(info)
	
	# UI'da bilgi göster (şimdilik sadece console'da)
	show_building_info_in_ui(info)

# Tüm mevcut binaları al (işçi atanabilir olanlar)
func get_all_available_buildings() -> Array:
	var all_buildings = []
	
	# Sahnedeki mevcut binaları bul
	var placed_buildings = get_tree().current_scene.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		print("PlacedBuildings node'u bulunamadı!")
		return all_buildings
	
	for building in placed_buildings.get_children():
		if building.has_method("add_worker") or building.has_method("remove_worker"):
			# Gerçek zamanlı verileri al
			var assigned_workers = 0
			var max_workers = 1
			
			if "assigned_workers" in building:
				assigned_workers = building.assigned_workers
			if "max_workers" in building:
				max_workers = building.max_workers
			
			var building_info = {
				"node": building,
				"name": building.name,
				"type": get_building_type_name(building),
				"assigned_workers": assigned_workers,
				"max_workers": max_workers
			}
			all_buildings.append(building_info)
	
	return all_buildings

# Bina türü adını al
func get_building_type_name(building: Node) -> String:
	var script_path = building.get_script().resource_path if building.get_script() else ""
	
	match script_path:
		"res://village/scripts/Well.gd": return "Kuyu"
		"res://village/scripts/HunterGathererHut.gd": return "Avcı"
		"res://village/scripts/WoodcutterCamp.gd": return "Oduncu"
		"res://village/scripts/StoneMine.gd": return "Taş Madeni"
		"res://village/scripts/Bakery.gd": return "Fırın"
		"res://village/scripts/House.gd": return "Ev"
		_: return "Bilinmeyen"

# Binaya işçi ekle
func add_worker_to_building(building_info: Dictionary) -> void:
	print("=== ADD WORKER DEBUG ===")
	print("İşçi ekleniyor: ", building_info["name"])
	
	var building = building_info["node"]
	if not building:
		print("❌ Bina node'u bulunamadı!")
		return
	
	# 1. Maksimum işçi kontrolü (gerçek zamanlı veri)
	var current_assigned = building.assigned_workers if "assigned_workers" in building else 0
	var current_max = building.max_workers if "max_workers" in building else 1
	
	if current_assigned >= current_max:
		print("❌ Bina maksimum işçi sayısına ulaştı: ", building_info["name"], " (", current_assigned, "/", current_max, ")")
		return
	
	# 2. Barınak kapasitesi kontrolü
	if not has_available_housing():
		print("❌ Köyde yeterli barınak yok! Yeni işçi eklenemez.")
		return
	
	# 3. VillageManager'da boşta işçi var mı kontrol et
	if village_manager and village_manager.idle_workers <= 0:
		print("❌ Köyde boşta işçi yok! Idle sayısı: ", village_manager.idle_workers)
		return
	
	# 4. İşçi ekleme
	if building.has_method("add_worker"):
		var success = building.add_worker()
		if success:
			print("✅ İşçi eklendi: ", building_info["name"])
			
			# UI'ı güncelle
			update_assignment_ui()
		else:
			print("❌ İşçi eklenemedi: ", building_info["name"])
	else:
		print("❌ Bu binada işçi ekleme metodu yok!")
	
	print("=== ADD WORKER DEBUG BİTTİ ===")

# Köyde yeterli barınak var mı kontrol et
func has_available_housing() -> bool:
	print("=== HOUSING CHECK DEBUG ===")
	
	# Eğer VillageManager'da idle işçi varsa, bu işçiler zaten barınakta demektir
	if village_manager and village_manager.idle_workers > 0:
		print("✅ Idle işçiler zaten barınakta. Yeni barınak gerekmez.")
		print("Idle işçi sayısı: ", village_manager.idle_workers)
		return true
	
	# Eğer idle işçi yoksa, yeni barınak gerekir
	var housing_nodes = get_tree().get_nodes_in_group("Housing")
	print("Housing group'ta bulunan node sayısı: ", housing_nodes.size())
	
	for housing in housing_nodes:
		if housing.has_method("can_add_occupant") and housing.can_add_occupant():
			print("✅ Mevcut barınakta yer var: ", housing.name)
			return true
	
	print("❌ Hiçbir barınakta yer yok!")
	print("=== HOUSING CHECK DEBUG BİTTİ ===")
	return false

# Binadan işçi çıkar
func remove_worker_from_building(building_info: Dictionary) -> void:
	print("=== REMOVE WORKER DEBUG ===")
	print("İşçi çıkarılıyor: ", building_info["name"])
	
	var building = building_info["node"]
	if not building:
		print("❌ Bina node'u bulunamadı!")
		return
	
	# Gerçek zamanlı veri kontrolü
	var current_assigned = building.assigned_workers if "assigned_workers" in building else 0
	
	if current_assigned <= 0:
		print("❌ Binada işçi yok: ", building_info["name"], " (", current_assigned, ")")
		return
	
	# İşçiyi binadan çıkar (ama silme! Sadece idle yap!)
	if building.has_method("remove_worker"):
		# ÖNEMLİ: Önce VillageManager'da işçiyi unregister et (bina scripti çağrılmadan önce!)
		# Çünkü bina scripti çağrıldığında assigned_building_node zaten null oluyor
		var worker_id = building.assigned_worker_ids[0] if building.assigned_worker_ids.size() > 0 else -1
		if worker_id != -1:
			print("🔧 VillageManager'da işçi %d unregister ediliyor (bina scripti çağrılmadan önce)" % worker_id)
			village_manager.unregister_generic_worker(worker_id)
		
		var success = building.remove_worker()
		if success:
			print("✅ İşçi binadan çıkarıldı: ", building_info["name"])
			
			# EKSTRA KONTROL: İşçinin görünür olduğundan emin ol!
			_ensure_worker_visibility_after_removal(building)
			
			print("✅ İşçi idle moda geçti (sahneden silinmedi). Idle sayısı: ", village_manager.idle_workers)
			
			# UI'ı güncelle
			update_assignment_ui()
		else:
			print("❌ İşçi binadan çıkarılamadı: ", building_info["name"])
	else:
		print("❌ Bu binada işçi çıkarma metodu yok!")
	
	print("=== REMOVE WORKER DEBUG BİTTİ ===")

# İşçi çıkarıldıktan sonra görünürlüğünü garanti et
func _ensure_worker_visibility_after_removal(building: Node2D) -> void:
	print("=== VİSİBİLİTY CHECK DEBUG ===")
	
	# TÜM işçileri kontrol et (sadece idle değil!)
	for worker_id in village_manager.all_workers.keys():
		var worker_data = village_manager.all_workers[worker_id]
		var worker_instance = worker_data["instance"]
		
		if not is_instance_valid(worker_instance):
			print("❌ İşçi %d geçersiz!" % worker_id)
			continue
		
		print("🔍 İşçi %d kontrol ediliyor: Job='%s', Visible=%s, State=%s" % [
			worker_id, 
			worker_instance.assigned_job_type, 
			worker_instance.visible,
			worker_instance.State.keys()[worker_instance.current_state] if worker_instance.current_state >= 0 else "INVALID"
		])
		
		# Sadece gerçekten idle olması gereken işçileri düzelt (assigned_job_type boşsa VE görünmezse VEYA binanın içinde ise)
		if worker_instance.assigned_job_type == "" and \
		   ((not worker_instance.visible) or \
			(is_instance_valid(building) and abs(worker_instance.global_position.x - building.global_position.x) < 50.0)):
			
			print("🔧 İşçi %d düzeltiliyor! (Job: '%s', Visible: %s, State: %s, Pos: %s)" % [
				worker_id,
				worker_instance.assigned_job_type,
				worker_instance.visible,
				worker_instance.State.keys()[worker_instance.current_state] if worker_instance.current_state >= 0 else "INVALID",
				worker_instance.global_position
			])
			
			# İşçiyi idle yap ve görünür yap
			worker_instance.assigned_job_type = ""
			worker_instance.assigned_building_node = null
			worker_instance.visible = true
			worker_instance.current_state = worker_instance.State.AWAKE_IDLE
			
			# İşçiyi binadan uzaklaştır - DAHA UZAK MESAFE
			if is_instance_valid(building):
				var safe_distance = 200.0  # Daha uzak mesafe
				var direction = 1 if randf() > 0.5 else -1
				var new_x = building.global_position.x + (safe_distance * direction)
				worker_instance.global_position = Vector2(new_x, building.global_position.y)
				worker_instance.move_target_x = new_x
				print("  -> İşçi %d yeni konuma taşındı: %s" % [worker_id, worker_instance.global_position])
			
			print("✅ İşçi %d görünür yapıldı ve güvenli konuma taşındı!" % worker_id)
	
	# İşçi hala sahne ağacında mı kontrol et
	for worker_id in village_manager.all_workers.keys():
		var worker_data = village_manager.all_workers[worker_id]
		var worker_instance = worker_data["instance"]
		
		if not is_instance_valid(worker_instance):
			print("❌ İşçi %d sahne ağacında değil!" % worker_id)
		else:
			var parent = worker_instance.get_parent()
			if parent == null:
				print("⚠️ İşçi %d parent'ı null! - Pos: %s, Visible: %s, Z-Index: %d" % [
					worker_id, worker_instance.global_position, worker_instance.visible, worker_instance.z_index
				])
				# İşçiyi WorkersContainer'a geri ekle
				var workers_container = village_manager.workers_container
				if workers_container:
					workers_container.add_child(worker_instance)
					print("✅ İşçi %d WorkersContainer'a geri eklendi!" % worker_id)
				else:
					print("❌ WorkersContainer bulunamadı! VillageManager.workers_container: %s" % village_manager.workers_container)
			else:
				print("✅ İşçi %d sahne ağacında - Parent: %s, Pos: %s, Z-Index: %d" % [
					worker_id, parent, worker_instance.global_position, worker_instance.z_index
				])
	
	print("=== VİSİBİLİTY CHECK DEBUG BİTTİ ===")

# Bina durum bilgilerini al (UI için kısa format)
func get_building_status_info(building_type: String) -> String:
	var existing_buildings = find_existing_buildings(building_type)
	
	if existing_buildings.is_empty():
		return "❌ Yok"
	
	var building = existing_buildings[0]
	var info = ""
	
	# Bina seviyesi
	if "level" in building:
		info += "Lv." + str(building.level)
		if "max_level" in building:
			info += "/" + str(building.max_level)
	
	# Yükseltme durumu
	if "is_upgrading" in building and building.is_upgrading:
		info += " ⚡"
	elif "level" in building and "max_level" in building and building.level >= building.max_level:
		info += " ✅"
	
	# İşçi bilgileri
	if "assigned_workers" in building and "max_workers" in building:
		info += " 👥" + str(building.assigned_workers) + "/" + str(building.max_workers)
	
	# Yükseltme maliyeti (sadece yükseltme seçiliyse)
	if current_construction_action == ConstructionAction.UPGRADE:
		if building.has_method("get_next_upgrade_cost"):
			var upgrade_cost = building.get_next_upgrade_cost()
			if upgrade_cost.has("gold") and upgrade_cost["gold"] > 0:
				info += " 💰" + str(upgrade_cost["gold"])
	
	return info

# Bina inşa etme işlemi
func execute_build_action():
	var buildings = building_categories.get(current_building_category, [])
	if buildings.is_empty():
		print("Bu kategoride bina yok!")
		return
	
	# Seçili binayı al
	var selected_building = buildings[current_building_index]
	
	# İşlem türüne göre farklı işlemler yap
	match current_construction_action:
		ConstructionAction.BUILD:
			execute_build_action_internal(selected_building)
		ConstructionAction.UPGRADE:
			execute_upgrade_action(selected_building)
		ConstructionAction.DEMOLISH:
			execute_demolish_action(selected_building)
		ConstructionAction.INFO:
			execute_info_action(selected_building)

# Bina inşa etme işlemi (iç fonksiyon)
func execute_build_action_internal(selected_building: String):
	var building_scene_path = building_scene_paths.get(selected_building, "")
	
	if building_scene_path == "":
		print("Bina sahne yolu bulunamadı: ", selected_building)
		return
	
	# VillageManager ile inşa et
	if village_manager and village_manager.has_method("request_build_building"):
		print("İnşa ediliyor: ", selected_building, " (", building_scene_path, ")")
		var success = village_manager.request_build_building(building_scene_path)
		if success:
			print("✅ Bina başarıyla inşa edildi: ", selected_building)
		else:
			print("❌ Bina inşa edilemedi: ", selected_building)
	else:
		print("VillageManager bulunamadı veya request_build_building metodu yok!")

# Bina yıkma işlemi
func execute_demolish_action(building_type: String):
	print("=== YIKMA İŞLEMİ ===")
	print("Bina türü: ", building_type)
	
	# Bu türden mevcut binaları bul
	var existing_buildings = find_existing_buildings(building_type)
	
	if existing_buildings.is_empty():
		print("❌ Bu türden bina bulunamadı!")
		return
	
	# İlk binayı yık (şimdilik sadece ilkini)
	var building_to_demolish = existing_buildings[0]
	print("Yıkılacak bina: ", building_to_demolish.name)
	
	# İŞÇİ KONTROLÜ: Binada çalışan işçi var mı?
	var assigned_workers = 0
	if "assigned_workers" in building_to_demolish:
		assigned_workers = building_to_demolish.assigned_workers
	
	if assigned_workers > 0:
		print("⚠️ BİNADA %d İŞÇİ ÇALIŞIYOR!" % assigned_workers)
		print("❌ Önce tüm işçileri işten çıkarmalısınız!")
		print("💡 İpucu: ATAMALAR sayfasından işçileri çıkarın")
		return
	
	print("✅ Binada işçi yok, yıkma işlemi devam ediyor...")
	
	# Binanın yıkma metodunu çağır (eğer varsa)
	if building_to_demolish.has_method("demolish"):
		var success = building_to_demolish.demolish()
		if success:
			print("✅ Bina yıkıldı: ", building_to_demolish.name)
		else:
			print("❌ Bina yıkılamadı: ", building_to_demolish.name)
	else:
		# Yıkma metodu yoksa, node'u kaldır
		print("Demolish metodu yok, node kaldırılıyor...")
		building_to_demolish.queue_free()
		print("✅ Bina kaldırıldı: ", building_type)

# Bina bilgi işlemi
func execute_info_action(building_type: String):
	print("=== BİLGİ İŞLEMİ ===")
	print("Bina türü: ", building_type)
	
	# Bu türden mevcut binaları bul
	var existing_buildings = find_existing_buildings(building_type)
	
	if existing_buildings.is_empty():
		print("❌ Bu türden bina bulunamadı!")
		return
	
	# İlk binanın bilgilerini göster
	var building = existing_buildings[0]
	var info = get_building_detailed_info(building, building_type)
	print("📋 Bina Bilgileri:")
	print(info)
	
	# UI'da bilgi göster (şimdilik sadece console'da)
	show_building_info_in_ui(info)

# Bina detaylı bilgilerini al
func get_building_detailed_info(building: Node, building_type: String) -> String:
	var info = "🏗️ " + building_type + "\n"
	
	# Bina seviyesi
	if "level" in building:
		info += "📊 Seviye: " + str(building.level)
		if "max_level" in building:
			info += "/" + str(building.max_level)
		info += "\n"
	
	# Yükseltme durumu
	if "is_upgrading" in building and building.is_upgrading:
		info += "⚡ Yükseltiliyor...\n"
	
	# İşçi bilgileri
	if "assigned_workers" in building and "max_workers" in building:
		info += "👥 İşçiler: " + str(building.assigned_workers) + "/" + str(building.max_workers) + "\n"
	
	# Yükseltme maliyeti
	if building.has_method("get_next_upgrade_cost"):
		var upgrade_cost = building.get_next_upgrade_cost()
		if upgrade_cost.has("gold") and upgrade_cost["gold"] > 0:
			info += "💰 Yükseltme: " + str(upgrade_cost["gold"]) + " Altın\n"
	
	# Üretim bilgileri (eğer varsa)
	if building.has_method("get_production_info"):
		var production_info = building.get_production_info()
		info += "📈 Üretim: " + production_info + "\n"
	
	return info

# UI'da bina bilgilerini göster
func show_building_info_in_ui(info: String):
	# Şimdilik sadece console'da göster
	# Gelecekte UI'da güzel bir popup olarak gösterilebilir
	print("=== BİNA BİLGİLERİ ===")
	print(info)
	print("=======================")

# Bina yükseltme işlemi
func execute_upgrade_action(building_type: String):
	print("=== YÜKSELTME İŞLEMİ ===")
	print("Bina türü: ", building_type)
	
	# Bu türden mevcut binaları bul
	var existing_buildings = find_existing_buildings(building_type)
	
	if existing_buildings.is_empty():
		print("❌ Bu türden bina bulunamadı!")
		return
	
	# İlk binayı yükselt (şimdilik sadece ilkini)
	var building_to_upgrade = existing_buildings[0]
	print("Yükseltilecek bina: ", building_to_upgrade.name)
	
	# Binanın yükseltme metodunu çağır
	if building_to_upgrade.has_method("start_upgrade"):
		var success = building_to_upgrade.start_upgrade()
		if success:
			print("✅ Yükseltme başlatıldı: ", building_to_upgrade.name)
		else:
			print("❌ Yükseltme başlatılamadı: ", building_to_upgrade.name)
	else:
		print("❌ Bu binada yükseltme metodu yok!")

# Belirtilen türden mevcut binaları bul
func find_existing_buildings(building_type: String) -> Array:
	var buildings = []
	
	# Bina türüne göre script yolu bul
	var script_path = ""
	match building_type:
		"Kuyu": script_path = "res://village/scripts/Well.gd"
		"Avcı": script_path = "res://village/scripts/HunterGathererHut.gd"
		"Oduncu": script_path = "res://village/scripts/WoodcutterCamp.gd"
		"Taş Madeni": script_path = "res://village/scripts/StoneMine.gd"
		"Fırın": script_path = "res://village/scripts/Bakery.gd"
		_: 
			print("Bilinmeyen bina türü: ", building_type)
			return buildings
	
	# Sahnedeki bu türden binaları bul
	var placed_buildings = get_tree().current_scene.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		print("PlacedBuildings node'u bulunamadı!")
		return buildings
	
	for building in placed_buildings.get_children():
		if building.has_method("get_script") and building.get_script() != null:
			var building_script = building.get_script()
			if building_script is GDScript and building_script.resource_path == script_path:
				buildings.append(building)
	
	print("Bulunan binalar: ", buildings.size(), " adet")
	return buildings

# Atama UI'ını güncelle
func update_assignment_ui():
	if current_page == PageType.ASSIGNMENT:
		var category_label = assignment_page.get_node_or_null("CategoryRow/CategoryLabel")
		var buildings_label = assignment_page.get_node_or_null("BuildingsLabel")
		
		# Bina listesi seviyesi
		if current_assignment_menu_state == AssignmentMenuState.BİNA_LISTESİ:
			if category_label:
				category_label.text = "KATEGORİ: İŞÇİ ATAMALARI ← SEÇİLİ"
			if buildings_label:
				var all_buildings = get_all_available_buildings()
				var buildings_text = "BİNALAR:\n"
				
				if all_buildings.is_empty():
					buildings_text += "❌ Atanabilir bina yok!\n"
					buildings_text += "Önce bina inşa edin."
				else:
					for i in range(all_buildings.size()):
						var building = all_buildings[i]
						var selection_marker = " ← SEÇİLİ" if i == current_assignment_building_index else ""
						buildings_text += "• " + building["type"] + " (" + str(building["assigned_workers"]) + "/" + str(building["max_workers"]) + ")" + selection_marker + "\n"
				
				buildings_text += "\n[Yukarı/Aşağı: Bina seçimi] [Sol/Sağ: İşçi ekle/çıkar] [A: Detay] [B: Geri]"
				buildings_label.text = buildings_text
		
		# Bina detayı seviyesi
		elif current_assignment_menu_state == AssignmentMenuState.BİNA_DETAYI:
			if category_label:
				category_label.text = "KATEGORİ: İŞÇİ ATAMALARI ✓"
			if buildings_label:
				var all_buildings = get_all_available_buildings()
				if current_assignment_building_index < all_buildings.size():
					var selected_building = all_buildings[current_assignment_building_index]
					buildings_label.text = "BİNA: " + selected_building["type"] + " ✓\n\n" + get_building_detailed_info(selected_building["node"], selected_building["type"])
					buildings_label.text += "\n[B: Geri dön]"
				else:
					buildings_label.text = "❌ Bina bulunamadı!\n\n[B: Geri dön]"

func next_page():
	print("next_page() çağrıldı!")
	var next_index = (current_page + 1) % page_names.size()
	print("Mevcut sayfa index: ", current_page, " -> Yeni index: ", next_index)
	show_page(next_index)

func previous_page():
	print("previous_page() çağrıldı!")
	var prev_index = (current_page - 1) % page_names.size()
	if prev_index < 0:
		prev_index = page_names.size() - 1
	print("Mevcut sayfa index: ", current_page, " -> Yeni index: ", prev_index)
	show_page(prev_index)

func show_page(page_index: int):
	print("show_page() çağrıldı - Index: ", page_index)
	current_page = page_index

	missions_page.visible = false
	assignment_page.visible = false
	construction_page.visible = false

	print("Tüm sayfalar gizlendi")

	match current_page:
		PageType.MISSIONS:
			missions_page.visible = true
			print("MissionsPage gösterildi")
			# Görevler sayfası açıldığında başlangıç durumuna sıfırla
			current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
			current_mission_index = 0
			update_missions_ui()
		PageType.ASSIGNMENT:
			assignment_page.visible = true
			print("AssignmentPage gösterildi")
			# Atama sayfası açıldığında başlangıç durumuna sıfırla
			current_assignment_menu_state = AssignmentMenuState.BİNA_LISTESİ
			current_assignment_building_index = 0
			update_assignment_ui()
		PageType.CONSTRUCTION:
			construction_page.visible = true
			print("ConstructionPage gösterildi")
			# İnşaat sayfası açıldığında başlangıç durumuna sıfırla
			current_menu_state = MenuState.İŞLEM_SEÇİMİ
			current_building_index = 0
			update_construction_ui()

	page_label.text = page_names[page_index]

	print("Sayfa değişti: ", page_names[page_index])
	print("Mevcut sayfa enum değeri: ", current_page)

func close_menu():
	print("=== CLOSE MENU DEBUG ===")
	print("Mission Center kapatılıyor...")

	unlock_player()

	print("Node tree: ", get_tree())
	print("Parent node: ", get_parent())
	print("=========================")
	queue_free()

# B tuşu ile geri gitme
func handle_back_button():
	if current_page == PageType.CONSTRUCTION:
		match current_menu_state:
			MenuState.İŞLEM_SEÇİMİ:
				print("Zaten en üst seviyede, geri gidilemez")
			MenuState.KATEGORİ_SEÇİMİ:
				print("Kategori seçiminden işlem seçimine geri dönülüyor")
				current_menu_state = MenuState.İŞLEM_SEÇİMİ
				update_construction_ui()
			MenuState.BİNA_SEÇİMİ:
				print("Bina seçiminden kategori seçimine geri dönülüyor")
				current_menu_state = MenuState.KATEGORİ_SEÇİMİ
				current_building_index = 0
				update_construction_ui()
	elif current_page == PageType.ASSIGNMENT:
		match current_assignment_menu_state:
			AssignmentMenuState.BİNA_LISTESİ:
				print("Zaten en üst seviyede, geri gidilemez")
			AssignmentMenuState.BİNA_DETAYI:
				print("Bina detayından bina listesine geri dönülüyor")
				current_assignment_menu_state = AssignmentMenuState.BİNA_LISTESİ
				update_assignment_ui()
	elif current_page == PageType.MISSIONS:
		match current_mission_menu_state:
			MissionMenuState.GÖREV_LISTESİ:
				print("Zaten en üst seviyede, geri gidilemez")
			MissionMenuState.CARİYE_SEÇİMİ:
				print("Cariye seçiminden görev listesine geri dönülüyor")
				current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
				update_missions_ui()
			MissionMenuState.GÖREV_DETAYI:
				print("Görev detayından görev listesine geri dönülüyor")
				current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
				update_missions_ui()

# --- GÖREVLER SAYFASI FONKSİYONLARI ---

# Görevler sayfası UI'ını güncelle
func update_missions_ui():
	if current_page == PageType.MISSIONS:
		# Kart sistemi ile güncelle
		update_missions_ui_cards()

# Görev listesi UI'ını güncelle
func update_mission_list_ui(content_label: Label):
	if not content_label:
		return
		
	var text = "🎯 MEVCUT GÖREVLER:\n\n"
	
	# Aktif görevler
	var active_missions = village_manager.active_missions
	if not active_missions.is_empty():
		text += "📋 AKTİF GÖREVLER:\n"
		for cariye_id in active_missions:
			var mission_data = active_missions[cariye_id]
			var gorev_id = mission_data["gorev_id"]
			var timer = mission_data["timer"]
			var cariye = village_manager.cariyeler[cariye_id]
			var gorev = village_manager.gorevler[gorev_id]
			
			var remaining_time = timer.time_left
			text += "• %s → %s (%.1fs kaldı)\n" % [cariye.get("isim", "İsimsiz"), gorev.get("isim", "İsimsiz"), remaining_time]
		text += "\n"
	else:
		text += "📋 AKTİF GÖREV YOK\n\n"
	
	# Mevcut görevler (boşta olanlar)
	var available_missions = []
	for gorev_id in village_manager.gorevler:
		var gorev = village_manager.gorevler[gorev_id]
		# Bu görev aktif değilse listele
		var is_active = false
		for active_cariye_id in active_missions:
			if active_missions[active_cariye_id]["gorev_id"] == gorev_id:
				is_active = true
				break
		if not is_active:
			available_missions.append({"id": gorev_id, "data": gorev})
	
	if not available_missions.is_empty():
		text += "📝 YAPILABİLİR GÖREVLER:\n"
		for i in range(available_missions.size()):
			var mission = available_missions[i]
			var selection_marker = " ← SEÇİLİ" if i == current_mission_index else ""
			text += "• %s%s\n" % [mission["data"].get("isim", "İsimsiz"), selection_marker]
		text += "\n"
	else:
		text += "📝 YAPILABİLİR GÖREV YOK\n\n"
	
	# Boşta cariyeler
	var idle_cariyeler = []
	for cariye_id in village_manager.cariyeler:
		var cariye = village_manager.cariyeler[cariye_id]
		if cariye.get("durum", "") == "boşta":
			idle_cariyeler.append(cariye)
	
	text += "👥 BOŞTA CARİYELER: %d\n" % idle_cariyeler.size()
	
	# Kontroller
	text += "\n[Yukarı/Aşağı: Görev seçimi] [A: Cariye seç] [B: Geri]"
	
	content_label.text = text

# Cariye seçimi UI'ını güncelle
func update_cariye_selection_ui(content_label: Label):
	if not content_label:
		return
		
	var selected_mission = get_selected_mission()
	if not selected_mission:
		content_label.text = "❌ Görev bulunamadı!\n\n[B: Geri]"
		return
	
	var text = "👥 CARİYE SEÇİMİ:\n\n"
	text += "Görev: %s\n\n" % selected_mission.get("isim", "İsimsiz")
	
	# Boşta cariyeler
	var idle_cariyeler = []
	for cariye_id in village_manager.cariyeler:
		var cariye = village_manager.cariyeler[cariye_id]
		if cariye.get("durum", "") == "boşta":
			idle_cariyeler.append({"id": cariye_id, "data": cariye})
	
	if idle_cariyeler.is_empty():
		text += "❌ Boşta cariye yok!\n\n[B: Geri]"
	else:
		text += "MEVCUT CARİYELER:\n"
		for i in range(idle_cariyeler.size()):
			var cariye = idle_cariyeler[i]
			var selection_marker = " ← SEÇİLİ" if i == current_cariye_index else ""
			text += "• %s%s\n" % [cariye["data"].get("isim", "İsimsiz"), selection_marker]
		
		text += "\n[A: Görev ata] [B: Geri]"
	
	content_label.text = text

# Görev detayı UI'ını güncelle
func update_mission_detail_ui(content_label: Label):
	if not content_label:
		return
		
	var selected_mission = get_selected_mission()
	if not selected_mission:
		content_label.text = "❌ Görev bulunamadı!\n\n[B: Geri]"
		return
	
	var text = "📋 GÖREV DETAYI:\n\n"
	text += "İsim: %s\n" % selected_mission.get("isim", "İsimsiz")
	text += "Tür: %s\n" % selected_mission.get("tur", "Bilinmiyor")
	text += "Süre: %.1f saniye\n" % selected_mission.get("sure", 0.0)
	text += "Başarı Şansı: %d%%\n\n" % (selected_mission.get("basari_sansi", 0.7) * 100)
	
	# Ödüller
	var oduller = selected_mission.get("odul", {})
	if not oduller.is_empty():
		text += "🎁 ÖDÜLLER:\n"
		for key in oduller:
			text += "• %s: %s\n" % [key, oduller[key]]
		text += "\n"
	
	# Cezalar
	var cezalar = selected_mission.get("ceza", {})
	if not cezalar.is_empty():
		text += "⚠️ CEZALAR:\n"
		for key in cezalar:
			text += "• %s: %s\n" % [key, cezalar[key]]
		text += "\n"
	
	text += "[B: Geri]"
	content_label.text = text

# Seçili görevi döndür
func get_selected_mission():
	var available_missions = []
	for gorev_id in village_manager.gorevler:
		var gorev = village_manager.gorevler[gorev_id]
		# Bu görev aktif değilse listele
		var is_active = false
		for active_cariye_id in village_manager.active_missions:
			if village_manager.active_missions[active_cariye_id]["gorev_id"] == gorev_id:
				is_active = true
				break
		if not is_active:
			available_missions.append(gorev)
	
	if current_mission_index < available_missions.size():
		return available_missions[current_mission_index]
	return null

# Görev atama işlemi
func assign_mission_to_cariye():
	var selected_mission = get_selected_mission()
	if not selected_mission:
		print("MissionCenter: Seçili görev bulunamadı!")
		return false
	
	# Boşta cariyeler
	var idle_cariyeler = []
	for cariye_id in village_manager.cariyeler:
		var cariye = village_manager.cariyeler[cariye_id]
		if cariye.get("durum", "") == "boşta":
			idle_cariyeler.append(cariye_id)
	
	if current_cariye_index >= idle_cariyeler.size():
		print("MissionCenter: Seçili cariye bulunamadı!")
		return false
	
	var selected_cariye_id = idle_cariyeler[current_cariye_index]
	var gorev_id = null
	
	# Görev ID'sini bul
	for gorev_id_key in village_manager.gorevler:
		if village_manager.gorevler[gorev_id_key] == selected_mission:
			gorev_id = gorev_id_key
			break
	
	if not gorev_id:
		print("MissionCenter: Görev ID bulunamadı!")
		return false
	
	# Görev atama
	var success = village_manager.assign_cariye_to_mission(selected_cariye_id, gorev_id)
	if success:
		print("MissionCenter: Görev başarıyla atandı!")
		# Görev listesine geri dön
		current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
		current_mission_index = 0
		update_missions_ui()
		return true
	else:
		print("MissionCenter: Görev atama başarısız!")
		return false

# Görevler sayfasında D-pad navigasyonu
func handle_missions_navigation():
	match current_mission_menu_state:
		MissionMenuState.GÖREV_LISTESİ:
			handle_mission_list_selection()
		MissionMenuState.CARİYE_SEÇİMİ:
			handle_cariye_selection()
		MissionMenuState.GÖREV_DETAYI:
			handle_mission_detail()

# Görev listesi seçimi
func handle_mission_list_selection():
	# Yukarı/Aşağı D-pad: Görev seçimi
	if Input.is_action_just_pressed("ui_up"):
		print("=== YUKARI D-PAD: Görev seçimi ===")
		var available_missions = get_available_missions_list()
		if not available_missions.is_empty():
			current_mission_index = (current_mission_index - 1) % available_missions.size()
			if current_mission_index < 0:
				current_mission_index = available_missions.size() - 1
			print("Seçilen görev: ", available_missions[current_mission_index].get("isim", "İsimsiz"))
			update_missions_ui()

	elif Input.is_action_just_pressed("ui_down"):
		print("=== AŞAĞI D-PAD: Görev seçimi ===")
		var available_missions = get_available_missions_list()
		if not available_missions.is_empty():
			current_mission_index = (current_mission_index + 1) % available_missions.size()
			print("Seçilen görev: ", available_missions[current_mission_index].get("isim", "İsimsiz"))
			update_missions_ui()

	# A tuşu: Cariye seçimine geç
	elif Input.is_action_just_pressed("ui_forward"):
		print("=== A TUŞU: Cariye seçimine geçiliyor ===")
		var available_missions = get_available_missions_list()
		if not available_missions.is_empty():
			current_mission_menu_state = MissionMenuState.CARİYE_SEÇİMİ
			current_cariye_index = 0
			update_missions_ui()

# Cariye seçimi
func handle_cariye_selection():
	# Yukarı/Aşağı D-pad: Cariye seçimi
	if Input.is_action_just_pressed("ui_up"):
		print("=== YUKARI D-PAD: Cariye seçimi ===")
		var idle_cariyeler = get_idle_cariyeler_list()
		if not idle_cariyeler.is_empty():
			current_cariye_index = (current_cariye_index - 1) % idle_cariyeler.size()
			if current_cariye_index < 0:
				current_cariye_index = idle_cariyeler.size() - 1
			print("Seçilen cariye: ", idle_cariyeler[current_cariye_index].get("isim", "İsimsiz"))
			update_missions_ui()

	elif Input.is_action_just_pressed("ui_down"):
		print("=== AŞAĞI D-PAD: Cariye seçimi ===")
		var idle_cariyeler = get_idle_cariyeler_list()
		if not idle_cariyeler.is_empty():
			current_cariye_index = (current_cariye_index + 1) % idle_cariyeler.size()
			print("Seçilen cariye: ", idle_cariyeler[current_cariye_index].get("isim", "İsimsiz"))
			update_missions_ui()

	# A tuşu: Görev ata
	elif Input.is_action_just_pressed("ui_forward"):
		print("=== A TUŞU: Görev atanıyor ===")
		assign_mission_to_cariye()

# Görev detayı (şimdilik sadece geri dönme)
func handle_mission_detail():
	# B tuşu: Geri dön
	if Input.is_action_just_pressed("ui_cancel"):
		print("=== B TUŞU: Görev detayından geri dönülüyor ===")
		current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
		update_missions_ui()

# Yardımcı fonksiyonlar
func get_available_missions_list():
	var available_missions = []
	for gorev_id in village_manager.gorevler:
		var gorev = village_manager.gorevler[gorev_id]
		# Bu görev aktif değilse listele
		var is_active = false
		for active_cariye_id in village_manager.active_missions:
			if village_manager.active_missions[active_cariye_id]["gorev_id"] == gorev_id:
				is_active = true
				break
		if not is_active:
			available_missions.append(gorev)
	return available_missions

func get_idle_cariyeler_list():
	var idle_cariyeler = []
	for cariye_id in village_manager.cariyeler:
		var cariye = village_manager.cariyeler[cariye_id]
		if cariye.get("durum", "") == "boşta":
			idle_cariyeler.append(cariye)
	return idle_cariyeler

# Görev tamamlandığında çağrılır
func _on_mission_completed(cariye_id: int, gorev_id: int, successful: bool, results: Dictionary):
	print("=== GÖREV TAMAMLANDI ===")
	print("Cariye: %s" % results.get("cariye_name", "İsimsiz"))
	print("Görev: %s" % results.get("mission_name", "İsimsiz"))
	print("Başarılı: %s" % successful)
	print("========================")
	
	# Görev sonuçlarını göster
	current_mission_result = results
	showing_mission_result = true
	mission_result_timer = 0.0
	
	# Eğer görevler sayfasındaysak UI'ı güncelle
	if current_page == PageType.MISSIONS:
		update_missions_ui()

# Görev sonuçları UI'ını güncelle
func update_mission_result_ui(content_label: Label):
	if not content_label:
		return
		
	var text = "🎯 GÖREV SONUCU:\n\n"
	
	var cariye_name = current_mission_result.get("cariye_name", "İsimsiz")
	var mission_name = current_mission_result.get("mission_name", "İsimsiz")
	var successful = current_mission_result.get("successful", false)
	var cariye_injured = current_mission_result.get("cariye_injured", false)
	
	text += "Cariye: %s\n" % cariye_name
	text += "Görev: %s\n\n" % mission_name
	
	if successful:
		text += "✅ GÖREV BAŞARILI!\n\n"
		
		var rewards = current_mission_result.get("rewards", {})
		if not rewards.is_empty():
			text += "🎁 ÖDÜLLER:\n"
			for key in rewards:
				text += "• %s: %s\n" % [key, rewards[key]]
			text += "\n"
	else:
		text += "❌ GÖREV BAŞARISIZ!\n\n"
		
		var penalties = current_mission_result.get("penalties", {})
		if not penalties.is_empty():
			text += "⚠️ CEZALAR:\n"
			for key in penalties:
				text += "• %s: %s\n" % [key, penalties[key]]
			text += "\n"
	
	if cariye_injured:
		text += "🏥 Cariye yaralandı!\n\n"
	
	var remaining_time = mission_result_duration - mission_result_timer
	text += "⏱️ %.1f saniye sonra kapanacak..." % remaining_time
	
	content_label.text = text

# --- KART SİSTEMİ FONKSİYONLARI ---

# Görev kartı oluştur
func create_mission_card(mission_data: Dictionary, is_selected: bool = false, is_active: bool = false) -> Control:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(300, 120)
	
	# Kart rengi
	if is_active:
		card.modulate = Color(0.8, 1.0, 0.8)  # Yeşilimsi - aktif
	elif is_selected:
		card.modulate = Color(1.0, 1.0, 0.8)  # Sarımsı - seçili
	else:
		card.modulate = Color(1.0, 1.0, 1.0)  # Normal
	
	# Kart içeriği
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	
	# Başlık
	var title_label = Label.new()
	title_label.text = mission_data.get("isim", "İsimsiz Görev")
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_label)
	
	# Tür ve süre
	var info_label = Label.new()
	info_label.text = "Tür: %s | Süre: %.1fs" % [mission_data.get("tur", "Bilinmiyor"), mission_data.get("sure", 0.0)]
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(info_label)
	
	# Başarı şansı
	var success_label = Label.new()
	success_label.text = "Başarı Şansı: %d%%" % (mission_data.get("basari_sansi", 0.7) * 100)
	success_label.add_theme_font_size_override("font_size", 12)
	success_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	vbox.add_child(success_label)
	
	# Ödüller (kısa)
	var rewards = mission_data.get("odul", {})
	if not rewards.is_empty():
		var reward_text = "Ödüller: "
		var reward_keys = rewards.keys()
		for i in range(min(2, reward_keys.size())):  # İlk 2 ödülü göster
			reward_text += "%s " % reward_keys[i]
		if reward_keys.size() > 2:
			reward_text += "..."
		
		var reward_label = Label.new()
		reward_label.text = reward_text
		reward_label.add_theme_font_size_override("font_size", 10)
		reward_label.add_theme_color_override("font_color", Color.GREEN)
		vbox.add_child(reward_label)
	
	return card

# Cariye kartı oluştur
func create_cariye_card(cariye_data: Dictionary, is_selected: bool = false) -> Control:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(250, 100)
	
	# Kart rengi
	if is_selected:
		card.modulate = Color(1.0, 1.0, 0.8)  # Sarımsı - seçili
	else:
		card.modulate = Color(1.0, 1.0, 1.0)  # Normal
	
	# Kart içeriği
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	
	# İsim
	var name_label = Label.new()
	name_label.text = cariye_data.get("isim", "İsimsiz Cariye")
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# Yetenekler
	var yetenekler = cariye_data.get("yetenekler", [])
	if not yetenekler.is_empty():
		var yetenek_text = "Yetenekler: "
		for i in range(min(3, yetenekler.size())):  # İlk 3 yeteneği göster
			yetenek_text += "%s " % yetenekler[i]
		if yetenekler.size() > 3:
			yetenek_text += "..."
		
		var yetenek_label = Label.new()
		yetenek_label.text = yetenek_text
		yetenek_label.add_theme_font_size_override("font_size", 12)
		yetenek_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
		vbox.add_child(yetenek_label)
	
	# Durum
	var durum = cariye_data.get("durum", "boşta")
	var durum_label = Label.new()
	durum_label.text = "Durum: %s" % durum
	durum_label.add_theme_font_size_override("font_size", 12)
	if durum == "boşta":
		durum_label.add_theme_color_override("font_color", Color.GREEN)
	elif durum == "görevde":
		durum_label.add_theme_color_override("font_color", Color.ORANGE)
	elif durum == "yaralı":
		durum_label.add_theme_color_override("font_color", Color.RED)
	else:
		durum_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(durum_label)
	
	return card

# Aktif görev kartı oluştur (süre ile)
func create_active_mission_card(cariye_data: Dictionary, mission_data: Dictionary, remaining_time: float) -> Control:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(300, 100)
	card.modulate = Color(0.8, 1.0, 0.8)  # Yeşilimsi - aktif
	
	# Kart içeriği
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	
	# Cariye ve görev
	var title_label = Label.new()
	title_label.text = "%s → %s" % [cariye_data.get("isim", "İsimsiz"), mission_data.get("isim", "İsimsiz")]
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_label)
	
	# Kalan süre
	var time_label = Label.new()
	time_label.text = "⏱️ %.1f saniye kaldı" % remaining_time
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(time_label)
	
	# Progress bar (basit)
	var progress_label = Label.new()
	var progress_percent = (mission_data.get("sure", 10.0) - remaining_time) / mission_data.get("sure", 10.0) * 100
	progress_label.text = "İlerleme: %d%%" % progress_percent
	progress_label.add_theme_font_size_override("font_size", 10)
	progress_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	vbox.add_child(progress_label)
	
	return card

# Liste temizle
func clear_list(list_container: VBoxContainer):
	for child in list_container.get_children():
		child.queue_free()

# Görevler sayfası UI'ını kart sistemi ile güncelle
func update_missions_ui_cards():
	if current_page != PageType.MISSIONS:
		return
	
	# Boşta cariye sayısını güncelle
	var idle_count = get_idle_cariyeler_list().size()
	idle_cariyeler_label.text = "👥 BOŞTA: %d" % idle_count
	
	# Görev sonuçları gösteriliyorsa
	if showing_mission_result:
		mission_result_panel.visible = true
		cariye_selection_panel.visible = false
		update_mission_result_ui(mission_result_content)
		return
	else:
		mission_result_panel.visible = false
	
	# Menü durumuna göre panel görünürlüğü
	if current_mission_menu_state == MissionMenuState.CARİYE_SEÇİMİ:
		cariye_selection_panel.visible = true
	else:
		cariye_selection_panel.visible = false
	
	# Aktif görevleri güncelle
	update_active_missions_cards()
	
	# Yapılabilir görevleri güncelle
	update_available_missions_cards()
	
	# Cariye seçimi güncelle
	if current_mission_menu_state == MissionMenuState.CARİYE_SEÇİMİ:
		update_cariye_selection_cards()

# Aktif görevleri kart olarak güncelle
func update_active_missions_cards():
	clear_list(active_missions_list)
	
	var active_missions = village_manager.active_missions
	if active_missions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Aktif görev yok"
		empty_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		active_missions_list.add_child(empty_label)
		return
	
	for cariye_id in active_missions:
		var mission_data = active_missions[cariye_id]
		var gorev_id = mission_data["gorev_id"]
		var timer = mission_data["timer"]
		var cariye = village_manager.cariyeler[cariye_id]
		var gorev = village_manager.gorevler[gorev_id]
		
		var remaining_time = timer.time_left
		var card = create_active_mission_card(cariye, gorev, remaining_time)
		active_missions_list.add_child(card)

# Yapılabilir görevleri kart olarak güncelle
func update_available_missions_cards():
	clear_list(available_missions_list)
	
	var available_missions = get_available_missions_list()
	if available_missions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Yapılabilir görev yok"
		empty_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		available_missions_list.add_child(empty_label)
		return
	
	for i in range(available_missions.size()):
		var mission = available_missions[i]
		var is_selected = (i == current_mission_index)
		var card = create_mission_card(mission, is_selected)
		available_missions_list.add_child(card)

# Cariye seçimini kart olarak güncelle
func update_cariye_selection_cards():
	clear_list(cariye_selection_list)
	
	var idle_cariyeler = get_idle_cariyeler_list()
	if idle_cariyeler.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Boşta cariye yok"
		empty_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		cariye_selection_list.add_child(empty_label)
		return
	
	for i in range(idle_cariyeler.size()):
		var cariye = idle_cariyeler[i]
		var is_selected = (i == current_cariye_index)
		var card = create_cariye_card(cariye, is_selected)
		cariye_selection_list.add_child(card)
