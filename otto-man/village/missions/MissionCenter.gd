extends CanvasLayer

# Sayfa türleri
enum PageType { MISSIONS, ASSIGNMENT, CONSTRUCTION, NEWS, CONCUBINE_DETAILS }

# İnşaat menüsü için enum'lar
enum ConstructionAction { BUILD, UPGRADE, DEMOLISH, INFO }
enum BuildingCategory { PRODUCTION, LIFE, MILITARY, DECORATION }

# Menü durumları (PlayStation mantığı)
enum MenuState { İŞLEM_SEÇİMİ, KATEGORİ_SEÇİMİ, BİNA_SEÇİMİ }

# Atama sayfası için menü durumları
enum AssignmentMenuState { BİNA_LISTESİ, BİNA_DETAYI }

# Görevler sayfası için menü durumları
enum MissionMenuState { GÖREV_LISTESİ, CARİYE_SEÇİMİ, GÖREV_DETAYI, GÖREV_GEÇMİŞİ, GEÇMİŞ_DETAYI, GÖREV_ZİNCİRLERİ }

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
var current_active_mission_index: int = 0 # Aktif görev seçimi için index

# Görev geçmişi seçimleri
var current_history_index: int = 0 # Görev geçmişinde seçim için index
var current_history_menu_state: MissionMenuState = MissionMenuState.GÖREV_LISTESİ # Görev geçmişi menü durumu

# Cariye detay sayfası seçimleri
var current_concubine_detail_index: int = 0 # Cariye detay sayfasında seçim için index

# Görev sonucu gösterimi
var showing_mission_result: bool = false
var mission_result_timer: float = 0.0
var mission_result_duration: float = 5.0

# Menü durumu (PlayStation mantığı)
var current_menu_state: MenuState = MenuState.İŞLEM_SEÇİMİ

# UI referansları
@onready var missions_page: Control = $MissionsPage
@onready var assignment_page: Control = $AssignmentPage
@onready var construction_page: Control = $ConstructionPage
@onready var news_page: Control = $NewsCenterPage
@onready var concubine_details_page: Control = $ConcubineDetailsPage
@onready var page_label: Label = $PageLabel

# Sayfa göstergesi referansları
@onready var page_dot1: Panel = $PageIndicator/PageDot1
@onready var page_dot2: Panel = $PageIndicator/PageDot2
@onready var page_dot3: Panel = $PageIndicator/PageDot3
@onready var page_dot4: Panel = $PageIndicator/PageDot4
@onready var page_dot5: Panel = $PageIndicator/PageDot5

# Görevler sayfası UI referansları
@onready var idle_cariyeler_label: Label = $MissionsPage/MissionsHeader/IdleCariyelerLabel
@onready var active_missions_list: VBoxContainer = $MissionsPage/MainContent/ActiveMissionsPanel/ActiveMissionsScroll/ActiveMissionsList
@onready var available_missions_scroll: ScrollContainer = $MissionsPage/MainContent/AvailableMissionsPanel/AvailableMissionsScroll
@onready var available_missions_list: VBoxContainer = $MissionsPage/MainContent/AvailableMissionsPanel/AvailableMissionsScroll/AvailableMissionsList
@onready var cariye_selection_panel: VBoxContainer = $MissionsPage/CariyeSelectionPanel
@onready var cariye_selection_list: VBoxContainer = $MissionsPage/CariyeSelectionPanel/CariyeSelectionScroll/CariyeSelectionList
@onready var mission_result_panel: VBoxContainer = $MissionsPage/MissionResultPanel
@onready var mission_result_content: Label = $MissionsPage/MissionResultPanel/MissionResultContent

# Görev geçmişi UI referansları
@onready var mission_history_panel: VBoxContainer = $MissionsPage/MissionHistoryPanel
@onready var mission_history_list: VBoxContainer = $MissionsPage/MissionHistoryPanel/MissionHistoryScroll/MissionHistoryList
@onready var mission_history_stats: VBoxContainer = $MissionsPage/MissionHistoryPanel/MissionHistoryStats
@onready var stats_content: Label = $MissionsPage/MissionHistoryPanel/MissionHistoryStats/StatsContent

# Sayfa isimleri
var page_names: Array[String] = ["GÖREVLER", "ATAMALAR", "İNŞAAT", "HABERLER", "CARİYELER"]

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

# MissionManager referansı
var mission_manager: Node

# B tuşu timer sistemi
var b_button_timer: float = 0.0
var b_button_pressed: bool = false
var b_button_hold_time: float = 0.5  # 0.5 saniye basılı tutarsa menü kapanır

# Görevler sayfası güncelleme timer'ı
var missions_update_timer: float = 0.0
var missions_update_interval: float = 1.0  # Her 1 saniyede bir güncelle

# Görev sonuçları gösterimi
var current_mission_result: Dictionary = {}

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
	
	# MissionManager'ı bul
	mission_manager = get_node("/root/MissionManager")
	if mission_manager:
		print("✅ MissionManager bulundu: ", mission_manager.name)
		# Görev tamamlandığında sinyal dinle
		mission_manager.connect("mission_completed", _on_mission_completed)
		mission_manager.connect("concubine_leveled_up", _on_concubine_leveled_up)
	else:
		print("❌ MissionManager bulunamadı! Autoload: /root/MissionManager")

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
	if Input.is_action_pressed("ui_cancel"):
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
		
		# Y tuşu: Aktif görev iptal et
		if Input.is_action_just_pressed("ui_select"):
			cancel_selected_active_mission()
		
		# Sol/Sağ D-pad: Aktif görev seçimi veya görev geçmişi navigasyonu
		if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
			if current_mission_menu_state == MissionMenuState.GÖREV_GEÇMİŞİ:
				handle_history_navigation()
			else:
				handle_active_mission_selection()
		
		# B tuşu: Geri dön
		if Input.is_action_just_pressed("ui_cancel"):
			match current_mission_menu_state:
				MissionMenuState.CARİYE_SEÇİMİ:
					current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
					update_missions_ui()
				MissionMenuState.GÖREV_GEÇMİŞİ:
					current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
					update_missions_ui()
				MissionMenuState.GEÇMİŞ_DETAYI:
					current_mission_menu_state = MissionMenuState.GÖREV_GEÇMİŞİ
					update_missions_ui()
		
		# A tuşu: Seçim/Onay
		if Input.is_action_just_pressed("ui_accept"):
			match current_mission_menu_state:
				MissionMenuState.GÖREV_LISTESİ:
					var available_missions = get_available_missions_list()
					if not available_missions.is_empty():
						current_mission_menu_state = MissionMenuState.CARİYE_SEÇİMİ
						current_cariye_index = 0
						update_missions_ui()
				MissionMenuState.CARİYE_SEÇİMİ:
					assign_mission_to_cariye()
				MissionMenuState.GÖREV_GEÇMİŞİ:
					current_mission_menu_state = MissionMenuState.GEÇMİŞ_DETAYI
					update_missions_ui()
		
		# X tuşu: Görev geçmişine geç (sadece görev listesinde)
		if current_mission_menu_state == MissionMenuState.GÖREV_LISTESİ:
			if Input.is_action_just_pressed("mission_history"):
				current_mission_menu_state = MissionMenuState.GÖREV_GEÇMİŞİ
				current_history_index = 0
				update_missions_ui()
		
		# Görevler sayfası güncelleme timer'ı
		missions_update_timer += delta
		if missions_update_timer >= missions_update_interval:
			missions_update_timer = 0.0
			update_missions_ui()
		
		# Görev sonucu timer'ı
		if showing_mission_result:
			mission_result_timer += delta
			var close_time = 5.0  # Varsayılan 5 saniye
			
			# Seviye atlama bildirimi ise 3 saniye
			if mission_result_content.get_child_count() > 0:
				var first_child = mission_result_content.get_child(0)
				if first_child is Label and "SEVİYE ATLAMA" in first_child.text:
					close_time = 3.0
			
			if mission_result_timer >= close_time:
				mission_result_panel.visible = false
				showing_mission_result = false
				mission_result_timer = 0.0  # Aktif görevlerin sürelerini güncelle
	
	# Cariye detay sayfasında D-pad navigasyonu
	elif current_page == PageType.CONCUBINE_DETAILS:
		handle_concubine_details_navigation()
	
	# Test kontrolleri (sadece geliştirme için)
	if Input.is_action_just_pressed("ui_accept") and Input.is_key_pressed(KEY_CTRL):
		# Ctrl + A: Dinamik görev oluştur
		create_test_dynamic_mission()
	
	if Input.is_action_just_pressed("ui_cancel") and Input.is_key_pressed(KEY_CTRL):
		# Ctrl + B: Dünya olayı tetikle
		trigger_test_world_event()
	
	if Input.is_action_just_pressed("ui_up") and Input.is_key_pressed(KEY_CTRL):
		# Ctrl + Yukarı: İtibar artır
		update_test_reputation(10)
	
	if Input.is_action_just_pressed("ui_down") and Input.is_key_pressed(KEY_CTRL):
		# Ctrl + Aşağı: İtibar azalt
		update_test_reputation(-10)
	
	if Input.is_action_just_pressed("ui_left") and Input.is_key_pressed(KEY_CTRL):
		# Ctrl + Sol: İstikrar artır
		update_test_stability(10)
	
	if Input.is_action_just_pressed("ui_right") and Input.is_key_pressed(KEY_CTRL):
		# Ctrl + Sağ: İstikrar azalt
		update_test_stability(-10)
	
	if Input.is_action_just_pressed("ui_select") and Input.is_key_pressed(KEY_CTRL):
		# Ctrl + Y: Dinamik görev bilgilerini göster
		show_dynamic_mission_info()

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
	news_page.visible = false
	concubine_details_page.visible = false

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
		PageType.NEWS:
			news_page.visible = true
			print("NewsPage gösterildi")
			# Haber sayfası açıldığında güncelle
			update_news_ui()
		PageType.CONCUBINE_DETAILS:
			concubine_details_page.visible = true
			print("ConcubineDetailsPage gösterildi")
			# Cariye detay sayfası açıldığında güncelle
			current_concubine_detail_index = 0
			update_concubine_details_ui()

	page_label.text = page_names[page_index]

	# Sayfa göstergesini güncelle
	update_page_indicator()

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

# Mevcut görevleri yenile
func refresh_available_missions():
	print("=== GÖREV YENİLEME DEBUG ===")
	
	if not mission_manager:
		print("❌ MissionManager bulunamadı!")
		return
	
	print("🔄 Görevler yenileniyor...")
	
	# MissionManager'dan görevleri yenile
	mission_manager.refresh_missions()
	
	# Index'i sıfırla
	current_mission_index = 0
	print("📋 Görev index sıfırlandı: %d" % current_mission_index)
	
	# UI'ı güncelle
	update_missions_ui()
	
	print("✅ Görevler yenilendi!")
	print("========================")

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
	
	# Aktif görevler (MissionManager'dan)
	var active_missions = mission_manager.get_active_missions()
	if not active_missions.is_empty():
		text += "📋 AKTİF GÖREVLER:\n"
		for cariye_id in active_missions:
			var mission_id = active_missions[cariye_id]
			var mission = mission_manager.missions[mission_id]
			var cariye = mission_manager.concubines[cariye_id]
			
			var remaining_time = mission.get_remaining_time()
			text += "• %s → %s (%.1fs kaldı)\n" % [cariye.name, mission.name, remaining_time]
		text += "\n"
	else:
		text += "📋 AKTİF GÖREV YOK\n\n"
	
	# Mevcut görevler (MissionManager'dan)
	var available_missions = mission_manager.get_available_missions()
	if not available_missions.is_empty():
		text += "📝 YAPILABİLİR GÖREVLER:\n"
		for i in range(available_missions.size()):
			var mission = available_missions[i]
			var selection_marker = " ← SEÇİLİ" if i == current_mission_index else ""
			text += "• %s%s\n" % [mission.name, selection_marker]
		text += "\n"
	else:
		text += "📝 YAPILABİLİR GÖREV YOK\n\n"
	
	# Boşta cariyeler (MissionManager'dan)
	var idle_cariyeler = mission_manager.get_idle_concubines()
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
	text += "Görev: %s\n\n" % selected_mission.name
	
	# Boşta cariyeler (MissionManager'dan)
	var idle_cariyeler = mission_manager.get_idle_concubines()
	if idle_cariyeler.is_empty():
		text += "❌ Boşta cariye yok!\n\n[B: Geri]"
	else:
		text += "MEVCUT CARİYELER:\n"
		for i in range(idle_cariyeler.size()):
			var cariye = idle_cariyeler[i]
			var selection_marker = " ← SEÇİLİ" if i == current_cariye_index else ""
			text += "• %s%s\n" % [cariye.name, selection_marker]
		
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
	var available_missions = mission_manager.get_available_missions()
	
	if current_mission_index < available_missions.size():
		return available_missions[current_mission_index]
	return null

# Görev atama işlemi
func assign_mission_to_cariye():
	print("=== GÖREV ATAMA DEBUG ===")
	
	var selected_mission = get_selected_mission()
	if not selected_mission:
		print("❌ Seçili görev bulunamadı!")
		return false
	
	print("✅ Seçili görev: %s (ID: %s)" % [selected_mission.name, selected_mission.id])
	
	# Boşta cariyeler (MissionManager'dan)
	var idle_cariyeler = mission_manager.get_idle_concubines()
	print("📋 Boşta cariye sayısı: %d" % idle_cariyeler.size())
	print("📋 Seçili cariye index: %d" % current_cariye_index)
	
	if current_cariye_index >= idle_cariyeler.size():
		print("❌ Seçili cariye index geçersiz!")
		return false
	
	var selected_cariye = idle_cariyeler[current_cariye_index]
	print("✅ Seçili cariye: %s (ID: %d)" % [selected_cariye.name, selected_cariye.id])
	
	# Güvenli ID erişimi
	var cariye_id = -1
	if selected_cariye is Concubine:
		cariye_id = selected_cariye.id
	else:
		print("❌ Seçili cariye Concubine değil!")
		return false
	
	# Görev ID'sini güvenli şekilde al
	var mission_id = ""
	if selected_mission is Mission:
		mission_id = selected_mission.id
	else:
		print("❌ Seçili görev Mission değil!")
		return false
	
	print("🔄 Görev atanıyor: Cariye %d -> Görev %s" % [cariye_id, mission_id])
	
	# Görev atama (MissionManager ile)
	var success = mission_manager.assign_mission_to_concubine(cariye_id, mission_id)
	if success:
		print("✅ Görev başarıyla atandı!")
		# Görev listesine geri dön
		current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
		current_mission_index = 0
		update_missions_ui()
		print("🔄 Görev listesi güncellendi")
		return true
	else:
		print("❌ Görev atama başarısız!")
		return false
	
	print("========================")

# Görevler sayfasında D-pad navigasyonu
func handle_missions_navigation():
	match current_mission_menu_state:
		MissionMenuState.GÖREV_LISTESİ:
			handle_mission_list_selection()
		MissionMenuState.CARİYE_SEÇİMİ:
			handle_cariye_selection()
		MissionMenuState.GÖREV_DETAYI:
			handle_mission_detail()
		MissionMenuState.GÖREV_GEÇMİŞİ:
			handle_history_selection()
		MissionMenuState.GEÇMİŞ_DETAYI:
			handle_history_detail()

# Görev listesi seçimi
func handle_mission_list_selection():
	# Yukarı/Aşağı D-pad: Görev seçimi
	if Input.is_action_just_pressed("ui_up"):
		var available_missions = get_available_missions_list()
		if not available_missions.is_empty():
			current_mission_index = (current_mission_index - 1) % available_missions.size()
			if current_mission_index < 0:
				current_mission_index = available_missions.size() - 1
			update_missions_ui()
			scroll_to_selected_mission()

	elif Input.is_action_just_pressed("ui_down"):
		var available_missions = get_available_missions_list()
		if not available_missions.is_empty():
			current_mission_index = (current_mission_index + 1) % available_missions.size()
			update_missions_ui()
			scroll_to_selected_mission()

	# A tuşu kontrolü ana _process() fonksiyonunda

# Cariye seçimi
func handle_cariye_selection():
	# Yukarı/Aşağı D-pad: Cariye seçimi
	if Input.is_action_just_pressed("ui_up"):
		var idle_cariyeler = get_idle_cariyeler_list()
		if not idle_cariyeler.is_empty():
			current_cariye_index = (current_cariye_index - 1) % idle_cariyeler.size()
			if current_cariye_index < 0:
				current_cariye_index = idle_cariyeler.size() - 1
			update_missions_ui()

	elif Input.is_action_just_pressed("ui_down"):
		var idle_cariyeler = get_idle_cariyeler_list()
		if not idle_cariyeler.is_empty():
			current_cariye_index = (current_cariye_index + 1) % idle_cariyeler.size()
			update_missions_ui()

	# A tuşu kontrolü ana _process() fonksiyonunda

# Görev detayı (şimdilik sadece geri dönme)
func handle_mission_detail():
	# B tuşu: Geri dön
	if Input.is_action_just_pressed("ui_cancel"):
		current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
		update_missions_ui()

# Görev geçmişi navigasyonu
func handle_history_navigation():
	# Yukarı/Aşağı D-pad: Görev geçmişi seçimi
	if Input.is_action_just_pressed("ui_up"):
		var completed_missions = get_completed_missions_list()
		if not completed_missions.is_empty():
			current_history_index = (current_history_index - 1) % completed_missions.size()
			if current_history_index < 0:
				current_history_index = completed_missions.size() - 1
			update_missions_ui()
	elif Input.is_action_just_pressed("ui_down"):
		var completed_missions = get_completed_missions_list()
		if not completed_missions.is_empty():
			current_history_index = (current_history_index + 1) % completed_missions.size()
			update_missions_ui()

# Görev geçmişi seçimi
func handle_history_selection():
	# Yukarı/Aşağı D-pad: Görev geçmişi seçimi
	if Input.is_action_just_pressed("ui_up"):
		var completed_missions = get_completed_missions_list()
		if not completed_missions.is_empty():
			current_history_index = (current_history_index - 1) % completed_missions.size()
			if current_history_index < 0:
				current_history_index = completed_missions.size() - 1
			update_missions_ui()
	elif Input.is_action_just_pressed("ui_down"):
		var completed_missions = get_completed_missions_list()
		if not completed_missions.is_empty():
			current_history_index = (current_history_index + 1) % completed_missions.size()
			update_missions_ui()

# Görev geçmişi detayı
func handle_history_detail():
	# B tuşu kontrolü ana _process() fonksiyonunda
	pass

# Aktif görev seçimi
func handle_active_mission_selection():
	var active_missions = mission_manager.get_active_missions()
	if active_missions.is_empty():
		return
	
	var active_mission_keys = active_missions.keys()
	if active_mission_keys.is_empty():
		return
	
	# Sol/Sağ D-pad ile aktif görev seçimi
	if Input.is_action_just_pressed("ui_left"):
		current_active_mission_index = (current_active_mission_index - 1) % active_mission_keys.size()
		if current_active_mission_index < 0:
			current_active_mission_index = active_mission_keys.size() - 1
	elif Input.is_action_just_pressed("ui_right"):
		current_active_mission_index = (current_active_mission_index + 1) % active_mission_keys.size()
	
	# UI'ı güncelle
	update_missions_ui()

# Aktif görev iptal etme
func cancel_selected_active_mission():
	var active_missions = mission_manager.get_active_missions()
	if active_missions.is_empty():
		return
	
	var active_mission_keys = active_missions.keys()
	if current_active_mission_index >= active_mission_keys.size():
		current_active_mission_index = 0
	
	# Seçili aktif görevi iptal et
	var cariye_id = active_mission_keys[current_active_mission_index]
	var mission_id = active_missions[cariye_id]
	
	# MissionManager ile iptal et
	mission_manager.cancel_mission(cariye_id, mission_id)
	
	# Index'i sıfırla
	current_active_mission_index = 0
	
	# UI'ı güncelle
	update_missions_ui()

# Yardımcı fonksiyonlar
func get_available_missions_list():
	return mission_manager.get_available_missions()

func get_idle_cariyeler_list():
	return mission_manager.get_idle_concubines()

func get_completed_missions_list():
	# Tamamlanan görev objelerini döndür (UI için)
	var completed = []
	for mission_id in mission_manager.get_completed_missions():
		if mission_id in mission_manager.missions:
			completed.append(mission_manager.missions[mission_id])
	return completed

# Seçilen görevi scroll container'da görünür yap
func scroll_to_selected_mission():
	if not available_missions_scroll:
		return
	
	var available_missions = get_available_missions_list()
	if available_missions.is_empty() or current_mission_index >= available_missions.size():
		return
	
	# Seçilen görev kartını bul
	var mission_cards = available_missions_list.get_children()
	if current_mission_index < mission_cards.size():
		var selected_card = mission_cards[current_mission_index]
		
		# Scroll container'ı seçilen karta kaydır
		var scroll_value = selected_card.position.y / (available_missions_list.size.y - available_missions_scroll.size.y)
		scroll_value = clamp(scroll_value, 0.0, 1.0)
		available_missions_scroll.scroll_vertical = int(scroll_value * available_missions_scroll.get_v_scroll_bar().max_value)
		
		print("📜 Scroll değeri: " + str(scroll_value) + " -> " + str(available_missions_scroll.scroll_vertical))

# Görev tamamlandığında çağrılır
func _on_mission_completed(cariye_id: int, gorev_id: String, successful: bool, results: Dictionary):
	# Görev sonuçlarını göster
	show_mission_result(cariye_id, gorev_id, successful, results)
	
	# Eğer görevler sayfasındaysak UI'ı güncelle
	if current_page == PageType.MISSIONS:
		update_missions_ui()

# Cariye seviye atladığında çağrılır
func _on_concubine_leveled_up(cariye_id: int, new_level: int):
	var cariye = mission_manager.concubines.get(cariye_id)
	if not cariye:
		return
	
	# Seviye atlama bildirimi göster
	show_level_up_notification(cariye, new_level)
	
	# UI'ı güncelle
	if current_page == PageType.MISSIONS:
		update_missions_ui()

# Görev sonucu göster
func show_mission_result(cariye_id: int, mission_id: String, successful: bool, results: Dictionary):
	var cariye = mission_manager.concubines.get(cariye_id)
	var mission = mission_manager.missions.get(mission_id)
	
	if not cariye or not mission:
		return
	
	# Sonuç panelini göster
	mission_result_panel.visible = true
	
	# Sonuç içeriğini güncelle
	update_mission_result_content(cariye, mission, successful, results)
	
	# 5 saniye sonra otomatik kapat
	mission_result_timer = 0.0
	showing_mission_result = true

# Seviye atlama bildirimi göster
func show_level_up_notification(cariye: Concubine, new_level: int):
	# Sonuç panelini göster
	mission_result_panel.visible = true
	
	# Seviye atlama içeriğini güncelle
	update_level_up_content(cariye, new_level)
	
	# 3 saniye sonra otomatik kapat
	mission_result_timer = 0.0
	showing_mission_result = true

# Görev sonucu içeriğini güncelle
func update_mission_result_content(cariye: Concubine, mission: Mission, successful: bool, results: Dictionary):
	if not mission_result_content:
		return
	
	# Mevcut içeriği temizle
	if mission_result_content.get_child_count() > 0:
		for child in mission_result_content.get_children():
			child.queue_free()
	
	# Ana container oluştur
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mission_result_content.add_child(main_container)
	
	# Başlık
	var title_label = Label.new()
	title_label.text = "🎯 GÖREV SONUCU"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)
	
	# Boşluk
	var spacer1 = Control.new()
	spacer1.custom_minimum_size.y = 10
	main_container.add_child(spacer1)
	
	# Cariye ve görev bilgisi
	var info_label = Label.new()
	info_label.text = "👤 %s → 🎯 %s" % [cariye.name, mission.name]
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(info_label)
	
	# Boşluk
	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 15
	main_container.add_child(spacer2)
	
	# Sonuç
	var result_label = Label.new()
	if successful:
		result_label.text = "✅ BAŞARILI!"
		result_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		result_label.text = "❌ BAŞARISIZ!"
		result_label.add_theme_color_override("font_color", Color.RED)
	result_label.add_theme_font_size_override("font_size", 20)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(result_label)
	
	# Boşluk
	var spacer3 = Control.new()
	spacer3.custom_minimum_size.y = 15
	main_container.add_child(spacer3)
	
	# Ödüller/Cezalar
	if successful and mission.rewards.size() > 0:
		var rewards_label = Label.new()
		rewards_label.text = "💰 ÖDÜLLER:"
		rewards_label.add_theme_font_size_override("font_size", 16)
		rewards_label.add_theme_color_override("font_color", Color.YELLOW)
		rewards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_container.add_child(rewards_label)
		
		for reward_type in mission.rewards:
			var amount = mission.rewards[reward_type]
			var reward_text = "  • %s: +%d" % [reward_type, amount]
			var reward_label = Label.new()
			reward_label.text = reward_text
			reward_label.add_theme_font_size_override("font_size", 14)
			reward_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
			reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			main_container.add_child(reward_label)
	
	if not successful and mission.penalties.size() > 0:
		var penalties_label = Label.new()
		penalties_label.text = "⚠️ CEZALAR:"
		penalties_label.add_theme_font_size_override("font_size", 16)
		penalties_label.add_theme_color_override("font_color", Color.ORANGE)
		penalties_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_container.add_child(penalties_label)
		
		for penalty_type in mission.penalties:
			var amount = mission.penalties[penalty_type]
			var penalty_text = "  • %s: %d" % [penalty_type, amount]
			var penalty_label = Label.new()
			penalty_label.text = penalty_text
			penalty_label.add_theme_font_size_override("font_size", 14)
			penalty_label.add_theme_color_override("font_color", Color.RED)
			penalty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			main_container.add_child(penalty_label)
	
	# Boşluk
	var spacer4 = Control.new()
	spacer4.custom_minimum_size.y = 15
	main_container.add_child(spacer4)
	
	# Cariye durumu
	var cariye_status_label = Label.new()
	cariye_status_label.text = "👤 Cariye Durumu: Seviye %d | Sağlık: %d | Moral: %d" % [cariye.level, cariye.health, cariye.moral]
	cariye_status_label.add_theme_font_size_override("font_size", 14)
	cariye_status_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	cariye_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(cariye_status_label)
	
	# Boşluk
	var spacer5 = Control.new()
	spacer5.custom_minimum_size.y = 20
	main_container.add_child(spacer5)
	
	# Kapatma talimatı
	var close_label = Label.new()
	close_label.text = "⏰ 5 saniye sonra otomatik kapanır..."
	close_label.add_theme_font_size_override("font_size", 12)
	close_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(close_label)

# Seviye atlama içeriğini güncelle
func update_level_up_content(cariye: Concubine, new_level: int):
	if not mission_result_content:
		return
	
	# Mevcut içeriği temizle
	if mission_result_content.get_child_count() > 0:
		for child in mission_result_content.get_children():
			child.queue_free()
	
	# Başlık
	var title_label = Label.new()
	title_label.text = "🎉 SEVİYE ATLAMA! 🎉"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color.GOLD)
	mission_result_content.add_child(title_label)
	
	# Cariye bilgisi
	var cariye_label = Label.new()
	cariye_label.text = "%s seviye %d'ye yükseldi!" % [cariye.name, new_level]
	cariye_label.add_theme_font_size_override("font_size", 16)
	cariye_label.add_theme_color_override("font_color", Color.WHITE)
	mission_result_content.add_child(cariye_label)
	
	# Yeni özellikler
	var stats_label = Label.new()
	stats_label.text = "YENİ ÖZELLİKLER:"
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color.YELLOW)
	mission_result_content.add_child(stats_label)
	
	# Sağlık ve moral
	var health_label = Label.new()
	health_label.text = "• Maksimum Sağlık: %d" % cariye.max_health
	health_label.add_theme_font_size_override("font_size", 12)
	health_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	mission_result_content.add_child(health_label)
	
	var moral_label = Label.new()
	moral_label.text = "• Maksimum Moral: %d" % cariye.max_moral
	moral_label.add_theme_font_size_override("font_size", 12)
	moral_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	mission_result_content.add_child(moral_label)
	
	# Yetenekler
	var skills_label = Label.new()
	skills_label.text = "YETENEK ARTIŞLARI:"
	skills_label.add_theme_font_size_override("font_size", 14)
	skills_label.add_theme_color_override("font_color", Color.YELLOW)
	mission_result_content.add_child(skills_label)
	
	for skill in cariye.skills:
		var skill_label = Label.new()
		skill_label.text = "• %s: %d" % [cariye.get_skill_name(skill), cariye.skills[skill]]
		skill_label.add_theme_font_size_override("font_size", 12)
		skill_label.add_theme_color_override("font_color", Color.LIGHT_CYAN)
		mission_result_content.add_child(skill_label)
	
	# Kapatma talimatı
	var close_label = Label.new()
	close_label.text = "3 saniye sonra otomatik kapanır..."
	close_label.add_theme_font_size_override("font_size", 10)
	close_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	mission_result_content.add_child(close_label)

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
func create_mission_card(mission: Mission, is_selected: bool = false, is_active: bool = false) -> Control:
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
	title_label.text = mission.name
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_label)
	
	# Tür ve süre
	var info_label = Label.new()
	info_label.text = "Tür: %s | Süre: %.1fs" % [mission.get_mission_type_name(), mission.duration]
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(info_label)
	
	# Başarı şansı
	var success_label = Label.new()
	success_label.text = "Başarı Şansı: %d%%" % (mission.success_chance * 100)
	success_label.add_theme_font_size_override("font_size", 12)
	success_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	vbox.add_child(success_label)
	
	# Ödüller (kısa)
	if not mission.rewards.is_empty():
		var reward_text = "Ödüller: "
		var reward_keys = mission.rewards.keys()
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
func create_cariye_card(cariye: Concubine, is_selected: bool = false) -> Control:
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
	
	# İsim ve seviye
	var name_label = Label.new()
	name_label.text = "%s (Lv.%d)" % [cariye.name, cariye.level]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# En yüksek yetenek
	var best_skill = cariye.get_best_skill()
	var skill_label = Label.new()
	skill_label.text = "En İyi: %s (%d)" % [cariye.get_skill_name(best_skill), cariye.get_skill_level(best_skill)]
	skill_label.add_theme_font_size_override("font_size", 12)
	skill_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	vbox.add_child(skill_label)
	
	# Durum
	var durum_label = Label.new()
	durum_label.text = "Durum: %s" % cariye.get_status_name()
	durum_label.add_theme_font_size_override("font_size", 12)
	match cariye.status:
		Concubine.Status.BOŞTA:
			durum_label.add_theme_color_override("font_color", Color.GREEN)
		Concubine.Status.GÖREVDE:
			durum_label.add_theme_color_override("font_color", Color.ORANGE)
		Concubine.Status.YARALI:
			durum_label.add_theme_color_override("font_color", Color.RED)
		Concubine.Status.DİNLENİYOR:
			durum_label.add_theme_color_override("font_color", Color.YELLOW)
		_:
			durum_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(durum_label)
	
	return card

# Aktif görev kartı oluştur (süre ile)
func create_active_mission_card(cariye: Concubine, mission: Mission, remaining_time: float, is_selected: bool = false) -> Control:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(450, 120)
	
	# Kart rengi - seçili ise daha parlak
	if is_selected:
		card.modulate = Color(1.0, 1.0, 0.8)  # Sarımsı - seçili
	else:
		card.modulate = Color(0.8, 1.0, 0.8)  # Yeşilimsi - aktif
	
	# Kart içeriği
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	
	# Cariye ve görev
	var title_label = Label.new()
	var selection_marker = " ← SEÇİLİ" if is_selected else ""
	title_label.text = "%s → %s%s" % [cariye.name, mission.name, selection_marker]
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_label)
	
	# Görev türü ve zorluk
	var info_label = Label.new()
	info_label.text = "Tür: %s | Zorluk: %s" % [mission.get_mission_type_name(), mission.get_difficulty_name()]
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(info_label)
	
	# Kalan süre
	var time_label = Label.new()
	time_label.text = "⏱️ %.1f saniye kaldı" % remaining_time
	time_label.add_theme_font_size_override("font_size", 14)
	time_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(time_label)
	
	# Progress bar (gerçek progress bar)
	var progress_container = HBoxContainer.new()
	vbox.add_child(progress_container)
	
	var progress_label = Label.new()
	progress_label.text = "İlerleme:"
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	progress_container.add_child(progress_label)
	
	var progress_bar = ProgressBar.new()
	var progress_percent = (mission.duration - remaining_time) / mission.duration * 100
	progress_bar.value = progress_percent
	progress_bar.max_value = 100
	progress_bar.custom_minimum_size = Vector2(200, 20)
	progress_bar.add_theme_color_override("fill", Color(0.2, 0.8, 0.2))
	progress_container.add_child(progress_bar)
	
	var percent_label = Label.new()
	percent_label.text = "%d%%" % progress_percent
	percent_label.add_theme_font_size_override("font_size", 12)
	percent_label.add_theme_color_override("font_color", Color.WHITE)
	progress_container.add_child(percent_label)
	
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
		mission_history_panel.visible = false
	elif current_mission_menu_state == MissionMenuState.GÖREV_GEÇMİŞİ:
		cariye_selection_panel.visible = false
		mission_history_panel.visible = true
	else:
		cariye_selection_panel.visible = false
		mission_history_panel.visible = false
	
	# Aktif görevleri güncelle
	update_active_missions_cards()
	
	# Yapılabilir görevleri güncelle
	update_available_missions_cards()
	
	# Cariye seçimi güncelle
	if current_mission_menu_state == MissionMenuState.CARİYE_SEÇİMİ:
		update_cariye_selection_cards()
	
	# Görev geçmişi güncelle
	if current_mission_menu_state == MissionMenuState.GÖREV_GEÇMİŞİ:
		update_mission_history_cards()
		update_mission_history_stats()
		
		# Görev zincirlerini güncelle
		update_mission_chains_ui()

# Aktif görevleri kart olarak güncelle
func update_active_missions_cards():
	clear_list(active_missions_list)
	
	var active_missions = mission_manager.get_active_missions()
	if active_missions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Aktif görev yok"
		empty_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		active_missions_list.add_child(empty_label)
		return
	
	var active_mission_keys = active_missions.keys()
	for i in range(active_mission_keys.size()):
		var cariye_id = active_mission_keys[i]
		var mission_id = active_missions[cariye_id]
		var mission = mission_manager.missions[mission_id]
		var cariye = mission_manager.concubines[cariye_id]
		
		var remaining_time = mission.get_remaining_time()
		var is_selected = (i == current_active_mission_index)
		var card = create_active_mission_card(cariye, mission, remaining_time, is_selected)
		active_missions_list.add_child(card)

# Yapılabilir görevleri kart olarak güncelle
func update_available_missions_cards():
	clear_list(available_missions_list)
	
	var available_missions = get_available_missions_list()
	
	# 🔍 DEBUG: Görev listesi durumu
	print("=== GÖREV LİSTESİ DEBUG ===")
	print("📋 Mevcut görev sayısı: %d" % available_missions.size())
	print("📋 Seçili görev index: %d" % current_mission_index)
	print("📋 Menü durumu: %s" % MissionMenuState.keys()[current_mission_menu_state])
	
	# Tüm görevleri listele (kilitli olanlar dahil)
	var all_missions = mission_manager.missions
	print("📋 Toplam görev sayısı: %d" % all_missions.size())
	for mission_id in all_missions:
		var mission = all_missions[mission_id]
		var status_text = "🔒 KİLİTLİ" if not mission.are_prerequisites_met(mission_manager.completed_missions) else "✅ AÇIK"
		print("   - %s (%s)" % [mission.name, status_text])
	
	if available_missions.is_empty():
		print("❌ Görev listesi boş!")
		var empty_label = Label.new()
		empty_label.text = "Yapılabilir görev yok"
		empty_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		available_missions_list.add_child(empty_label)
		return
	
	# 🔍 DEBUG: Her görevin detayları
	for i in range(available_missions.size()):
		var mission = available_missions[i]
		print("📋 Görev %d: %s (ID: %s, Tip: %s)" % [i, mission.name, mission.id, mission.mission_type])
		print("   - Süre: %d saniye" % mission.duration)
		print("   - Ödül: %s" % str(mission.rewards))
		print("   - Seçili: %s" % (i == current_mission_index))
	
	print("==========================")
	
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

# Görev geçmişini kart olarak güncelle
func update_mission_history_cards():
	clear_list(mission_history_list)
	
	var completed_missions = get_completed_missions_list()
	if completed_missions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Tamamlanan görev yok"
		empty_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		mission_history_list.add_child(empty_label)
		return
	
	# 🔍 DEBUG: Görev geçmişi durumu
	print("=== GÖREV GEÇMİŞİ DEBUG ===")
	print("📋 Tamamlanan görev sayısı: %d" % completed_missions.size())
	print("📋 Seçili görev index: %d" % current_history_index)
	print("📋 Menü durumu: %s" % MissionMenuState.keys()[current_mission_menu_state])
	
	# 🔍 DEBUG: Her görevin detayları
	for i in range(completed_missions.size()):
		var mission = completed_missions[i]
		print("📋 Görev %d: %s (ID: %s, Durum: %s)" % [i, mission.name, mission.id, Mission.Status.keys()[mission.status]])
		print("   - Seçili: %s" % (i == current_history_index))
	
	print("==========================")
	
	for i in range(completed_missions.size()):
		var mission = completed_missions[i]
		var is_selected = (i == current_history_index)
		var card = create_history_mission_card(mission, is_selected)
		mission_history_list.add_child(card)

# Görev geçmişi istatistiklerini güncelle
func update_mission_history_stats():
	var completed_missions = get_completed_missions_list()
	var total_missions = completed_missions.size()
	var successful_missions = 0
	var failed_missions = 0
	
	for mission in completed_missions:
		if mission.status == Mission.Status.TAMAMLANDI:
			successful_missions += 1
		elif mission.status == Mission.Status.BAŞARISIZ:
			failed_missions += 1
	
	var success_rate = 0.0
	if total_missions > 0:
		success_rate = (successful_missions * 100.0) / total_missions
	
	stats_content.text = "Toplam Görev: %d | Başarılı: %d | Başarısız: %d | Başarı Oranı: %.1f%%" % [total_missions, successful_missions, failed_missions, success_rate]

# Görev geçmişi kartı oluştur
func create_history_mission_card(mission: Mission, is_selected: bool) -> Control:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(400, 80)
	
	# Seçili kart için farklı renk
	if is_selected:
		card.add_theme_stylebox_override("panel", create_selected_stylebox())
	else:
		card.add_theme_stylebox_override("panel", create_normal_stylebox())
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_top", 5)
	vbox.add_theme_constant_override("margin_bottom", 5)
	vbox.add_theme_constant_override("separation", 8)
	
	# Görev adı ve durum
	var title_label = Label.new()
	var selection_marker = " ← SEÇİLİ" if is_selected else ""
	var status_icon = "✅" if mission.status == Mission.Status.TAMAMLANDI else "❌"
	title_label.text = "%s %s%s" % [status_icon, mission.name, selection_marker]
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_label)
	
	# Görev türü ve zorluk
	var info_label = Label.new()
	info_label.text = "Tür: %s | Zorluk: %s" % [mission.get_mission_type_name(), mission.get_difficulty_name()]
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(info_label)
	
	# Tamamlanma tarihi ve süre
	var time_label = Label.new()
	var completion_time = "Tamamlandı: %.1f saniye" % mission.duration
	time_label.text = "⏱️ %s" % completion_time
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	vbox.add_child(time_label)
	
	return card

# Sayfa göstergesini güncelle
func update_page_indicator():
	# Tüm noktaları gri yap
	page_dot1.modulate = Color(0.5, 0.5, 0.5, 1)
	page_dot2.modulate = Color(0.5, 0.5, 0.5, 1)
	page_dot3.modulate = Color(0.5, 0.5, 0.5, 1)
	page_dot4.modulate = Color(0.5, 0.5, 0.5, 1)
	page_dot5.modulate = Color(0.5, 0.5, 0.5, 1)
	
	# Aktif sayfayı beyaz yap
	match current_page:
		PageType.MISSIONS:
			page_dot1.modulate = Color(1, 1, 1, 1)
		PageType.ASSIGNMENT:
			page_dot2.modulate = Color(1, 1, 1, 1)
		PageType.CONSTRUCTION:
			page_dot3.modulate = Color(1, 1, 1, 1)
		PageType.NEWS:
			page_dot4.modulate = Color(1, 1, 1, 1)
		PageType.CONCUBINE_DETAILS:
			page_dot5.modulate = Color(1, 1, 1, 1)

# StyleBox oluşturma fonksiyonları
func create_selected_stylebox() -> StyleBoxFlat:
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.2, 0.4, 0.8, 0.8)  # Mavi arka plan
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.4, 0.6, 1.0, 1.0)  # Parlak mavi kenarlık
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	return stylebox

func create_normal_stylebox() -> StyleBoxFlat:
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.8)  # Koyu gri arka plan
	stylebox.border_width_left = 1
	stylebox.border_width_right = 1
	stylebox.border_width_top = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(0.3, 0.3, 0.3, 1.0)  # Gri kenarlık
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	return stylebox

# --- HABER MERKEZİ FONKSİYONLARI ---

# Haber Merkezi UI'ını güncelle
func update_news_ui():
	if current_page != PageType.NEWS:
		return
	
	# Şimdilik statik haberler göster
	# Gelecekte dinamik haber sistemi eklenecek
	print("📰 Haber Merkezi güncelleniyor...")

# Haber Merkezi navigasyonu
func handle_news_navigation():
	# Şimdilik basit navigasyon
	# Gelecekte haber seçimi ve detay görüntüleme eklenecek
	pass

# --- CARİYE DETAY SAYFASI FONKSİYONLARI ---

# Cariye detay sayfası UI'ını güncelle
func update_concubine_details_ui():
	if current_page != PageType.CONCUBINE_DETAILS:
		return
	
	print("👤 Cariye Detay Sayfası güncelleniyor...")
	
	# Cariye listesini güncelle
	update_concubine_list()
	
	# Seçili cariyenin detaylarını güncelle
	update_selected_concubine_details()

# Cariye listesini güncelle
func update_concubine_list():
	# Şimdilik statik liste
	# Gelecekte MissionManager'dan dinamik liste alınacak
	print("📋 Cariye listesi güncelleniyor...")

# Seçili cariyenin detaylarını güncelle
func update_selected_concubine_details():
	# Şimdilik statik detaylar
	# Gelecekte seçili cariyenin gerçek verileri gösterilecek
	print("📊 Seçili cariye detayları güncelleniyor...")

# Cariye detay sayfası navigasyonu
func handle_concubine_details_navigation():
	# Yukarı/Aşağı D-pad: Cariye seçimi
	if Input.is_action_just_pressed("ui_up"):
		var all_concubines = get_all_concubines_list()
		if not all_concubines.is_empty():
			current_concubine_detail_index = (current_concubine_detail_index - 1) % all_concubines.size()
			if current_concubine_detail_index < 0:
				current_concubine_detail_index = all_concubines.size() - 1
			update_concubine_details_ui()

	elif Input.is_action_just_pressed("ui_down"):
		var all_concubines = get_all_concubines_list()
		if not all_concubines.is_empty():
			current_concubine_detail_index = (current_concubine_detail_index + 1) % all_concubines.size()
			update_concubine_details_ui()

# Tüm cariyeleri al
func get_all_concubines_list():
	if not mission_manager:
		return []
	
	# MissionManager'dan tüm cariyeleri al
	var all_concubines = []
	for cariye_id in mission_manager.concubines:
		all_concubines.append(mission_manager.concubines[cariye_id])
	
	return all_concubines

# --- GÖREV ZİNCİRLERİ FONKSİYONLARI ---

# Görev zincirleri UI'ını güncelle
func update_mission_chains_ui():
	if not mission_manager:
		return
	
	print("🔗 Görev zincirleri güncelleniyor...")
	
	# Görev zincirleri listesini temizle
	var chains_list = $MissionsPage/MissionChainsPanel/MissionChainsScroll/MissionChainsList
	for child in chains_list.get_children():
		child.queue_free()
	
	# Tüm zincirleri al ve göster
	var chain_count = 0
	for chain_id in mission_manager.mission_chains:
		var chain_info = mission_manager.get_chain_info(chain_id)
		var chain_progress = mission_manager.get_chain_progress(chain_id)
		
		# Zincir kartı oluştur
		var chain_card = create_chain_card(chain_info, chain_progress)
		chains_list.add_child(chain_card)
		chain_count += 1
	
	print("📊 " + str(chain_count) + " görev zinciri gösterildi")

# Zincir kartı oluştur
func create_chain_card(chain_info: Dictionary, chain_progress: Dictionary) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(750, 100)
	
	# Arka plan stili
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	stylebox.border_width_left = 1
	stylebox.border_width_right = 1
	stylebox.border_width_top = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(0.3, 0.3, 0.3, 1.0)
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", stylebox)
	
	# Ana container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)
	
	# Zincir adı
	var name_label = Label.new()
	name_label.text = "🔗 " + chain_info.get("name", "Bilinmeyen Zincir")
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	# İlerleme
	var progress_label = Label.new()
	var progress_text = "İlerleme: %d/%d (%.0f%%)" % [
		chain_progress.get("completed", 0),
		chain_progress.get("total", 0),
		chain_progress.get("percentage", 0.0)
	]
	progress_label.text = progress_text
	progress_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	progress_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(progress_label)
	
	# Zincir türü
	var type_label = Label.new()
	var chain_type_name = get_chain_type_name(chain_info.get("type", Mission.ChainType.NONE))
	type_label.text = "Tür: " + type_label
	type_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	type_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(type_label)
	
	# Ödüller
	var rewards_label = Label.new()
	var rewards_text = "Ödül: "
	var rewards = chain_info.get("rewards", {})
	var reward_parts = []
	for reward_type in rewards:
		reward_parts.append(str(rewards[reward_type]) + " " + reward_type)
	rewards_label.text = rewards_text + ", ".join(reward_parts)
	rewards_label.add_theme_color_override("font_color", Color.YELLOW)
	rewards_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(rewards_label)
	
	return card

# Zincir türü adını al
func get_chain_type_name(chain_type: Mission.ChainType) -> String:
	match chain_type:
		Mission.ChainType.NONE: return "Bağımsız"
		Mission.ChainType.SEQUENTIAL: return "Sıralı"
		Mission.ChainType.PARALLEL: return "Paralel"
		Mission.ChainType.CHOICE: return "Seçimli"
		_: return "Bilinmeyen"

# --- DİNAMİK GÖREV SİSTEMİ UI ---

# Dinamik görevleri UI'da göster
func show_dynamic_mission_info():
	if not mission_manager:
		return
	
	print("🎲 Dinamik görev bilgileri:")
	print("  - Oyuncu İtibarı: " + str(mission_manager.player_reputation))
	print("  - Dünya İstikrarı: " + str(mission_manager.world_stability))
	
	# Aktif dünya olayları
	var active_events = mission_manager.get_active_world_events()
	if not active_events.is_empty():
		print("  - Aktif Dünya Olayları:")
		for event in active_events:
			var remaining_time = event["duration"] - (Time.get_unix_time_from_system() - event["start_time"])
			print("    * " + event["name"] + " (Kalan: " + str(int(remaining_time)) + "s)")
	else:
		print("  - Aktif dünya olayı yok")

# Dinamik görev oluşturma butonu (test için)
func create_test_dynamic_mission():
	if not mission_manager:
		return
	
	var new_mission = mission_manager.generate_random_dynamic_mission()
	if new_mission:
		mission_manager.missions[new_mission.id] = new_mission
		print("✨ Test dinamik görev oluşturuldu: " + new_mission.name)
		update_missions_ui()

# Dünya olayı başlatma (test için)
func trigger_test_world_event():
	if not mission_manager:
		return
	
	mission_manager.start_random_world_event()
	print("🌍 Test dünya olayı tetiklendi")

# Oyuncu itibarını güncelle (test için)
func update_test_reputation(change: int):
	if not mission_manager:
		return
	
	mission_manager.update_player_reputation(change)
	print("📊 Test itibar güncellemesi: " + str(change))

# Dünya istikrarını güncelle (test için)
func update_test_stability(change: int):
	if not mission_manager:
		return
	
	mission_manager.update_world_stability(change)
	print("🌍 Test istikrar güncellemesi: " + str(change))
