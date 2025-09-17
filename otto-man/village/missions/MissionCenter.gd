extends CanvasLayer

# Sayfa türleri
enum PageType { MISSIONS, ASSIGNMENT, CONSTRUCTION, NEWS, CONCUBINE_DETAILS, TRADE }

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

# Görev zinciri seçimleri
var current_chain_index: int = 0 # Görev zincirleri listesinde seçim için index
var _chain_ids_ordered: Array[String] = [] # UI'de gösterilen zincir ID sırası
var current_history_focus: String = "history" # "history" | "chains"

# Cariye detay sayfası seçimleri
var current_concubine_detail_index: int = 0 # Cariye detay sayfasında seçim için index

# Görev sonucu gösterimi
var showing_mission_result: bool = false
var mission_result_timer: float = 0.0
var mission_result_duration: float = 5.0

# Menü durumu (PlayStation mantığı)
var current_menu_state: MenuState = MenuState.İŞLEM_SEÇİMİ

# D-Pad debounce sistemi
var dpad_debounce_timer: float = 0.0
var dpad_debounce_delay: float = 0.2  # 200ms gecikme
var last_dpad_input: String = ""

# UI referansları
@onready var missions_page: Control = $MissionsPage
@onready var assignment_page: Control = $AssignmentPage
@onready var construction_page: Control = $ConstructionPage
@onready var news_page: Control = $NewsCenterPage
@onready var concubine_details_page: Control = $ConcubineDetailsPage
@onready var trade_page: Control = $TradePage
@onready var page_label: Label = $PageLabel

# Sayfa göstergesi referansları
@onready var page_dot1: Panel = $PageIndicator/PageDot1
@onready var page_dot2: Panel = $PageIndicator/PageDot2
@onready var page_dot3: Panel = $PageIndicator/PageDot3
@onready var page_dot4: Panel = $PageIndicator/PageDot4
@onready var page_dot5: Panel = $PageIndicator/PageDot5
@onready var page_dot6: Panel = $PageIndicator/PageDot6

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

# Görev geçmişi detay alanı (dinamik oluşturulacak)
var mission_history_detail_label: RichTextLabel = null

# Sayfa isimleri
var page_names: Array[String] = ["GÖREVLER", "ATAMALAR", "İNŞAAT", "HABERLER", "CARİYELER", "TİCARET"]

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
var _logged_missing_placed_buildings: bool = false

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

# --- HABER MERKEZİ: Ticaret Anlaşmaları Overlay ---
var trade_mode: bool = false
var trade_overlay: Panel = null
var trade_offers_vbox: VBoxContainer = null
var current_trade_index: int = 0
var current_offer_index: int = 0
var available_trade_offers: Array = []
var current_focus_panel: String = "active" # "active" or "offers"

# Haber merkezi navigasyonu durumu
var news_focus: String = "village" # "village" | "world" | "random"
var current_news_index_village: int = 0
var current_news_index_world: int = 0
var current_news_index_random: int = 0
var news_detail_overlay: Panel = null
var news_queue_village: Array = []
var news_queue_world: Array = []

func _ready():
	print("=== MISSION CENTER DEBUG ===")
	
	# MissionManager referansını al
	mission_manager = get_node("/root/MissionManager")
	if not mission_manager:
		print("❌ MissionManager bulunamadı!")
		return
	
	print("✅ MissionManager bulundu")
	
	# MissionManager sinyallerini bağla
	mission_manager.mission_completed.connect(_on_mission_completed)
	mission_manager.mission_started.connect(_on_mission_started)
	mission_manager.mission_cancelled.connect(_on_mission_cancelled)
	mission_manager.concubine_leveled_up.connect(_on_concubine_leveled_up)
	mission_manager.mission_chain_completed.connect(_on_mission_chain_completed)
	mission_manager.mission_unlocked.connect(_on_mission_unlocked)
	if mission_manager.has_signal("news_posted"):
		mission_manager.news_posted.connect(_on_news_posted)
	if mission_manager.has_signal("trade_offers_updated"):
		mission_manager.trade_offers_updated.connect(_on_trade_offers_updated)
	
	print("✅ MissionManager sinyalleri bağlandı")
	
	# MissionCenter'ı group'a ekle
	add_to_group("mission_center")
	print("✅ MissionCenter group'a eklendi")
	
	# Başlangıç UI güncellemesi (deferred olarak çağır)
	call_deferred("update_missions_ui")
	
	print("✅ Mission Center hazır!")
	print("========================")

# MissionManager sinyal işleyicileri
func _on_mission_completed(cariye_id: int, mission_id: String, successful: bool, results: Dictionary):
	print("=== GÖREV TAMAMLANDI ===")
	print("Cariye ID: %d" % cariye_id)
	print("Görev ID: %s" % mission_id)
	print("Başarılı: %s" % successful)
	print("Sonuçlar: %s" % results)
	
	# Görev sonucunu göster
	current_mission_result = results
	showing_mission_result = true
	mission_result_timer = 0.0
	
	# UI'ı güncelle
	update_missions_ui()
	
	# 5 saniye sonra sonucu gizle
	await get_tree().create_timer(5.0).timeout
	showing_mission_result = false
	update_missions_ui()
	
	print("========================")

func _on_mission_started(cariye_id: int, mission_id: String):
	print("=== GÖREV BAŞLADI ===")
	print("Cariye ID: %d" % cariye_id)
	print("Görev ID: %s" % mission_id)
	
	# UI'ı güncelle
	update_missions_ui()
	
	print("=====================")

func _on_mission_cancelled(cariye_id: int, mission_id: String):
	print("=== GÖREV İPTAL EDİLDİ ===")
	print("Cariye ID: %d" % cariye_id)
	print("Görev ID: %s" % mission_id)
	
	# UI'ı güncelle
	update_missions_ui()
	
	print("=========================")

func _on_concubine_leveled_up(cariye_id: int, new_level: int):
	print("=== CARİYE SEVİYE ATLADI ===")
	print("Cariye ID: %d" % cariye_id)
	print("Yeni Seviye: %d" % new_level)
	
	# UI'ı güncelle
	update_missions_ui()
		
	print("============================")

func _on_mission_chain_completed(chain_id: String, rewards: Dictionary):
	print("=== GÖREV ZİNCİRİ TAMAMLANDI ===")
	print("Zincir ID: %s" % chain_id)
	print("Ödüller: %s" % rewards)
	
	# UI'ı güncelle
	update_missions_ui()
		
	print("===============================")

func _on_mission_unlocked(mission_id: String):
	print("=== YENİ GÖREV AÇILDI ===")
	print("Görev ID: %s" % mission_id)
	
	# UI'ı güncelle
	update_missions_ui()

	print("=========================")

# Gerçek zamanlı güncelleme sistemi
func _process(delta):
	if not visible:
		return

	# Görevler sayfası güncelleme timer'ı
	missions_update_timer += delta
	if missions_update_timer >= missions_update_interval:
		missions_update_timer = 0.0
		update_missions_ui()

	# Görev sonucu timer'ı
	if showing_mission_result:
		mission_result_timer += delta
		if mission_result_timer >= mission_result_duration:
			showing_mission_result = false
			update_missions_ui()

	# B basılı tutma ile çıkış
	if b_button_pressed:
		b_button_timer += delta
		if b_button_timer >= b_button_hold_time:
			b_button_pressed = false
			close_menu()

	# D-Pad debounce timer'ı
	if dpad_debounce_timer > 0:
		dpad_debounce_timer -= delta

	# Not: Input işlemleri _input(event) içinde, tek kanaldan yönetiliyor

func find_and_lock_player():
	print("=== PLAYER LOCK DEBUG ===")
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("Player bulundu: ", player.name)
		# Tercih: player içinde UI lock flag'i aç
		if player.has_method("set_ui_locked"):
			player.set_ui_locked(true)
		else:
			# Yedek: süreçleri devre dışı bırak
			player.set_process(false)
			player.set_physics_process(false)
			player.set_process_input(false)
			player.set_process_unhandled_input(false)

		print("=== PLAYER LOCK TAMAMLANDI ===")
	else:
		print("Player bulunamadı! Group: player")

func unlock_player():
	if player:
		print("=== PLAYER UNLOCK DEBUG ===")
		if player.has_method("set_ui_locked"):
			player.set_ui_locked(false)
		else:
			player.set_process(true)
			player.set_physics_process(true)
			player.set_process_input(true)
			player.set_process_unhandled_input(true)

		print("=== PLAYER UNLOCK TAMAMLANDI ===")

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
				action_label.text = "> " + "İŞLEM: " + action_names[current_construction_action] + " ← SEÇİLİ"
			if category_label:
				category_label.text = "  " + "KATEGORİ: [A tuşu ile seç]"
			if buildings_label:
				buildings_label.text = "  " + "BİNALAR: [Önce işlem seçin]"
		
		# Kategori seçimi seviyesi
		elif current_menu_state == MenuState.KATEGORİ_SEÇİMİ:
			if action_label:
				action_label.text = "  " + "İŞLEM: " + action_names[current_construction_action] + " ✓"
			if category_label:
				category_label.text = "> " + "KATEGORİ: " + category_names[current_building_category] + " ← SEÇİLİ"
			if buildings_label:
				buildings_label.text = "  " + "BİNALAR: [A tuşu ile seç]"
		
		# Bina seçimi seviyesi
		elif current_menu_state == MenuState.BİNA_SEÇİMİ:
			if action_label:
				action_label.text = "  " + "İŞLEM: " + action_names[current_construction_action] + " ✓"
			if category_label:
				category_label.text = "  " + "KATEGORİ: " + category_names[current_building_category] + " ✓"
			if buildings_label:
				var buildings = building_categories.get(current_building_category, [])
				var buildings_text = "BİNALAR:\n"
				
				for i in range(buildings.size()):
					var building_name = buildings[i]
					var building_info = get_building_status_info(building_name)
					
					if i == current_building_index:
						buildings_text += "> " + building_name + " ← SEÇİLİ\n"
						buildings_text += "  " + building_info + "\n"
					else:
						buildings_text += "  " + building_name + "\n"
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
		if not _logged_missing_placed_buildings:
			_logged_missing_placed_buildings = true
			print("PlacedBuildings node'u bulunamadı! (Test sahnesi - normal)")
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
	var _assigned_val = building.get("assigned_workers")
	var _max_val = building.get("max_workers")
	var current_assigned:int = int(_assigned_val) if _assigned_val != null else 0
	var current_max:int = int(_max_val) if _max_val != null else 1
	
	if current_assigned >= current_max:
		print("❌ Bina maksimum işçi sayısına ulaştı: ", building_info["name"], " (", current_assigned, "/", current_max, ")")
		return
	
	# 2. Idle işçi kontrolünü gerçek zamanlı yap (all_workers üzerinden)
	_ensure_workers_registered()
	var idle_count := 0
	if village_manager:
		var workers_dict = village_manager.get("all_workers")
		if typeof(workers_dict) == TYPE_DICTIONARY:
			for wid in workers_dict.keys():
				var w = workers_dict[wid]["instance"]
				if is_instance_valid(w) and (not w.assigned_job_type or w.assigned_job_type == ""):
					idle_count += 1
	print("[Assignment] realtime idle count:", idle_count)
	
	# 3. Boşta işçi yoksa atama başarısız
	if idle_count <= 0:
		print("❌ Köyde boşta işçi yok! Atama yapılamaz.")
		return
	
	# 4. İşçi atama (binanın add_worker'ı atama yapmalı)
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

# Çalışanlar WorkersContainer altında olup VillageManager.all_workers'a kayıtlı değilse kaydeder
func _ensure_workers_registered() -> void:
	if not village_manager:
		village_manager = get_node_or_null("/root/VillageManager")
	if not village_manager:
		return
	var container: Node = null
	if "workers_container" in village_manager and village_manager.workers_container:
		container = village_manager.workers_container
	if container == null and get_tree().current_scene:
		container = get_tree().current_scene.get_node_or_null("WorkersContainer")
	if container == null:
		print("[Assignment] WorkersContainer not found - skip ensure")
		return
	if not ("all_workers" in village_manager):
		return
	var added := 0
	for child in container.get_children():
		if not is_instance_valid(child):
			continue
		var wid = -1
		wid = int(child.get("worker_id")) if child.get("worker_id") != null else -1
		if wid <= 0:
			continue
		if village_manager.all_workers.has(wid):
			continue
		village_manager.all_workers[wid] = {
			"instance": child,
			"status": "idle",
			"assigned_building": null,
			"housing_node": child.get("housing_node") if child.get("housing_node") != null else null
		}
		if "total_workers" in village_manager:
			village_manager.total_workers = int(village_manager.total_workers) + 1
		if "idle_workers" in village_manager:
			village_manager.idle_workers = int(village_manager.idle_workers) + 1
		added += 1
	if added > 0:
		print("[Assignment] ensure_registered added:", added, " | totals: workers=", int(village_manager.total_workers), " idle=", int(village_manager.idle_workers))

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
		"Ev": script_path = "res://village/scripts/House.gd"
		"Kale": script_path = "res://village/scripts/Castle.gd"
		"Kule": script_path = "res://village/scripts/Tower.gd"
		"Çeşme": script_path = "res://village/scripts/Fountain.gd"
		"Bahçe": script_path = "res://village/scripts/Garden.gd"
		_: 
			print("Bilinmeyen bina türü: ", building_type)
			return buildings
	
	# Sahnedeki bu türden binaları bul
	var placed_buildings = get_tree().current_scene.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		if not _logged_missing_placed_buildings:
			_logged_missing_placed_buildings = true
			print("PlacedBuildings node'u bulunamadı! (Test sahnesi - normal)")
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
	if trade_page:
		trade_page.visible = false

	print("Tüm sayfalar gizlendi")

	match current_page:
		PageType.MISSIONS:
			missions_page.visible = true
			print("MissionsPage gösterildi")
			# Görevler sayfası açıldığında başlangıç durumuna sıfırla
			current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
			# current_mission_index = 0  # Index'i sıfırlama - kullanıcının seçimini koru
			update_missions_ui()
			update_active_missions_cards()
			update_available_missions_cards()
		PageType.ASSIGNMENT:
			assignment_page.visible = true
			print("AssignmentPage gösterildi")
			# Atama sayfası açıldığında başlangıç durumuna sıfırla
			current_assignment_menu_state = AssignmentMenuState.BİNA_LISTESİ
			# current_assignment_building_index = 0  # Index'i sıfırlama - kullanıcının seçimini koru
			update_assignment_ui()
		PageType.CONSTRUCTION:
			construction_page.visible = true
			print("ConstructionPage gösterildi")
			# İnşaat sayfası açıldığında başlangıç durumuna sıfırla
			current_menu_state = MenuState.İŞLEM_SEÇİMİ
			# current_building_index = 0  # Index'i sıfırlama - kullanıcının seçimini koru
			update_construction_ui()
		PageType.NEWS:
			news_page.visible = true
			print("NewsPage gösterildi")
			# Haber sayfası açıldığında güncelle
			update_news_ui()
		PageType.TRADE:
			if trade_page:
				trade_page.visible = true
				print("TradePage gösterildi")
				update_trade_ui()
		PageType.CONCUBINE_DETAILS:
			concubine_details_page.visible = true
			print("ConcubineDetailsPage gösterildi")
			# Cariye detay sayfası açıldığında güncelle
			current_concubine_detail_index = 0
			update_concubine_details_ui()

	page_label.text = page_names[page_index]
	await get_tree().process_frame

	# Sayfa göstergesini güncelle
	update_page_indicator()

	print("Sayfa değişti: ", page_names[page_index])
	print("Mevcut sayfa enum değeri: ", current_page)

# Duplicate close_menu function removed - using the one at the end of file

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
	
	# Index'i sıfırlama - kullanıcının seçimini koru
	# current_mission_index = 0
	print("📋 Görev index korunuyor: %d" % current_mission_index)
	
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
		# current_mission_index = 0  # Index'i sıfırlama - kullanıcının seçimini koru
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

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

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
	card.custom_minimum_size = Vector2(450, 140)  # Minimum yüksekliği sabitle
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Kart rengi - seçili ise daha parlak
	if is_selected:
		card.modulate = Color(1.0, 1.0, 0.8)  # Sarımsı - seçili
	else:
		card.modulate = Color(0.8, 1.0, 0.8)  # Yeşilimsi - aktif
	
	# Kart içeriği
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.anchor_left = 0
	vbox.anchor_top = 0
	vbox.anchor_right = 1
	vbox.anchor_bottom = 1
	vbox.offset_left = 10
	vbox.offset_right = -10
	vbox.offset_top = 8
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 8)
	
	# Cariye ve görev
	var title_label = Label.new()
	var selection_marker = " ← SEÇİLİ" if is_selected else ""
	title_label.text = "%s → %s%s" % [cariye.name, mission.name, selection_marker]
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_label)
	
	# Rozetler: Durum, Zorluk, Risk
	var badges = HBoxContainer.new()
	badges.add_theme_constant_override("separation", 10)
	vbox.add_child(badges)

	var status_badge = Label.new()
	var pct := 0.0
	if mission.duration > 0:
		pct = clamp((mission.duration - remaining_time) / mission.duration, 0.0, 1.0)
	var status_text = "Devam ediyor"
	if remaining_time <= 0.0:
		status_text = "Tamamlanıyor"
	status_badge.text = "🟢 %s" % status_text
	status_badge.add_theme_font_size_override("font_size", 11)
	status_badge.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	badges.add_child(status_badge)

	var diff_badge = Label.new()
	diff_badge.text = "🎯 %s" % mission.get_difficulty_name()
	diff_badge.add_theme_font_size_override("font_size", 11)
	diff_badge.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	badges.add_child(diff_badge)

	var risk_badge = Label.new()
	risk_badge.text = "⚠️ Risk: %s" % mission.risk_level
	risk_badge.add_theme_font_size_override("font_size", 11)
	risk_badge.add_theme_color_override("font_color", Color(1, 0.7, 0.2, 1))
	badges.add_child(risk_badge)
	
	# Görev türü ve zorluk
	var info_label = Label.new()
	info_label.text = "Tür: %s | Zorluk: %s" % [mission.get_mission_type_name(), mission.get_difficulty_name()]
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

	# Ödül önizleme ve ordu/beklenen
	var rewards_preview = Label.new()
	var rewards_text = "Ödüller: "
	var first = true
	for reward_type in mission.rewards.keys():
		var amount = mission.rewards[reward_type]
		if not first:
			rewards_text += ", "
		rewards_text += "%s: %s" % [str(reward_type), str(amount)]
		first = false
	if first:
		rewards_text += "-"
	rewards_preview.text = rewards_text
	rewards_preview.add_theme_font_size_override("font_size", 11)
	rewards_preview.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	rewards_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(rewards_preview)

	var reqs_label = Label.new()
	reqs_label.text = "Gerekli Seviye: %d | Gerekli Ordu: %d" % [mission.required_cariye_level, mission.required_army_size]
	reqs_label.add_theme_font_size_override("font_size", 10)
	reqs_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(reqs_label)
	
	return card

# Liste temizle
func clear_list(list_container: VBoxContainer):
	if not list_container:
		print("⚠️ clear_list: list_container is null!")
		return
	for child in list_container.get_children():
		child.queue_free()

# Görevler sayfası UI'ını kart sistemi ile güncelle
func update_missions_ui_cards():
	if current_page != PageType.MISSIONS:
		return
	
	# Zincir panelini gizle (zincir görevler ana listeye taşındı)
	var chains_panel_root = get_node_or_null("MissionsPage/MissionChainsPanel")
	if chains_panel_root:
		chains_panel_root.visible = false
	
	# Boşta cariye sayısını güncelle
	var idle_count = get_idle_cariyeler_list().size()
	if idle_cariyeler_label:
		idle_cariyeler_label.text = "👥 BOŞTA: %d" % idle_count
	
	# Görev sonuçları gösteriliyorsa
	if showing_mission_result:
		if mission_result_panel:
			mission_result_panel.visible = true
		if cariye_selection_panel:
			cariye_selection_panel.visible = false
		if mission_result_content:
			update_mission_result_ui(mission_result_content)
		return
	else:
		if mission_result_panel:
			mission_result_panel.visible = false
	
	# Menü durumuna göre panel görünürlüğü
	if current_mission_menu_state == MissionMenuState.CARİYE_SEÇİMİ:
		if cariye_selection_panel:
			cariye_selection_panel.visible = true
		if mission_history_panel:
			mission_history_panel.visible = false
	elif current_mission_menu_state == MissionMenuState.GÖREV_GEÇMİŞİ:
		if cariye_selection_panel:
			cariye_selection_panel.visible = false
		if mission_history_panel:
			mission_history_panel.visible = true
	else:
		if cariye_selection_panel:
			cariye_selection_panel.visible = false
		if mission_history_panel:
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
		# Zincir panelini gizle (artık tek listede göstereceğiz)
		var chains_panel = get_node_or_null("MissionsPage/MissionChainsPanel")
		if chains_panel:
			chains_panel.visible = false

# Yapılabilir görevleri kart olarak güncelle

func update_available_missions_cards():
	if not available_missions_list:
		print("⚠️ update_available_missions_cards: available_missions_list is null!")
		return
	clear_list(available_missions_list)
	# Kartlar arası boşluk
	available_missions_list.add_theme_constant_override("separation", 10)
	
	var available_missions = mission_manager.get_available_missions()
	# Zincirlerden yapılabilir görevleri de ekle
	var chain_missions_to_show: Array = []
	if mission_manager and "mission_chains" in mission_manager:
		for chain_id in mission_manager.mission_chains.keys():
			var chain_missions = mission_manager.get_chain_missions(chain_id)
			for m in chain_missions:
				# Sadece henüz tamamlanmamış ve MEVCUT olanlar listelensin
				if m.status == Mission.Status.MEVCUT and m.are_prerequisites_met(mission_manager.get_completed_missions()):
					chain_missions_to_show.append(m)
	# Ana listeyle birleştir (aynı ID'yi iki kez ekleme)
	var unique_ids := {}
	var merged: Array = []
	for mission in available_missions:
		if mission.id not in unique_ids:
			unique_ids[mission.id] = true
			merged.append(mission)
	for mission in chain_missions_to_show:
		if mission.id not in unique_ids:
			unique_ids[mission.id] = true
			merged.append(mission)
	# Merged listeyi kullan
	available_missions = merged
	if available_missions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Yapılabilir görev yok"
		empty_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		available_missions_list.add_child(empty_label)
		return
	
	for i in range(available_missions.size()):
		var mission = available_missions[i]
		var is_selected = (i == current_mission_index)
		var card = create_available_mission_card(mission, is_selected)
		available_missions_list.add_child(card)

	# Seçim görünürlük takibi: seçilen öğeyi otomatik kaydır
	_scroll_available_to_index(current_mission_index)

func _scroll_available_to_index(index: int):
	if not available_missions_scroll or not available_missions_list:
		return
	if index < 0 or index >= available_missions_list.get_child_count():
		return
	var card = available_missions_list.get_child(index)
	if card and card is Control:
		available_missions_scroll.ensure_control_visible(card)


# Yapılabilir görev kartı oluştur
func create_available_mission_card(mission: Mission, is_selected: bool) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(300, 130)  # Minimum yükseklik
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Seçili kart rengi
	if is_selected:
		card.modulate = Color(1, 1, 0.8, 1)
	else:
		card.modulate = Color(0.9, 0.9, 0.9, 1)
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.anchor_left = 0
	vbox.anchor_top = 0
	vbox.anchor_right = 1
	vbox.anchor_bottom = 1
	vbox.offset_left = 10
	vbox.offset_right = -10
	vbox.offset_top = 8
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_top", 10)
	vbox.add_theme_constant_override("margin_bottom", 10)
	
	# Görev başlığı
	var title_label = Label.new()
	var type_emoji = "⚔️" if mission.mission_type == Mission.MissionType.SAVAŞ else "🧭" if mission.mission_type == Mission.MissionType.KEŞİF else "🤝" if mission.mission_type == Mission.MissionType.DİPLOMASİ else "💰" if mission.mission_type == Mission.MissionType.TİCARET else "📜" if mission.mission_type == Mission.MissionType.BÜROKRASİ else "🕵️"
	title_label.text = "%s %s" % [type_emoji, mission.name]
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_label)
	
	# Rozetler: Zorluk, Risk, Süre
	var badges = HBoxContainer.new()
	badges.add_theme_constant_override("separation", 8)
	vbox.add_child(badges)

	# Zincir rozetini ekle (varsa)
	if mission.is_part_of_chain():
		var chain_badge = Label.new()
		chain_badge.text = "🔗 Zincir"
		chain_badge.add_theme_font_size_override("font_size", 11)
		chain_badge.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5, 1))
		badges.add_child(chain_badge)

	var diff_badge = Label.new()
	diff_badge.text = "🎯 %s" % mission.get_difficulty_name()
	diff_badge.add_theme_font_size_override("font_size", 11)
	diff_badge.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	badges.add_child(diff_badge)

	var risk_badge = Label.new()
	risk_badge.text = "⚠️ %s" % mission.risk_level
	risk_badge.add_theme_font_size_override("font_size", 11)
	risk_badge.add_theme_color_override("font_color", Color(1, 0.7, 0.2, 1))
	badges.add_child(risk_badge)

	var duration_badge = Label.new()
	duration_badge.text = "⏱️ %.1fs" % mission.duration
	duration_badge.add_theme_font_size_override("font_size", 11)
	duration_badge.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	badges.add_child(duration_badge)

	# Görev bilgileri
	var info_label = Label.new()
	info_label.text = "Tür: %s | Süre: %.1fs" % [mission.get_mission_type_name(), mission.duration]
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)
	
	# Başarı şansı
	var success_label = Label.new()
	success_label.text = "Başarı Şansı: %d%%" % (mission.success_chance * 100)
	success_label.add_theme_font_size_override("font_size", 12)
	success_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	vbox.add_child(success_label)
	
	# Ödüller
	var rewards_text = "Ödüller: "
	var first = true
	for reward_type in mission.rewards.keys():
		var amount = mission.rewards[reward_type]
		if not first:
			rewards_text += ", "
		rewards_text += "%s: %s" % [str(reward_type), str(amount)]
		first = false
	if first:
		rewards_text += "-"
	
	var rewards_label = Label.new()
	rewards_label.text = rewards_text
	rewards_label.add_theme_font_size_override("font_size", 10)
	rewards_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	rewards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(rewards_label)

	# Gereksinimler
	var reqs_label = Label.new()
	reqs_label.text = "Min. Seviye: %d | Min. Ordu: %d" % [mission.required_cariye_level, mission.required_army_size]
	reqs_label.add_theme_font_size_override("font_size", 10)
	reqs_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(reqs_label)
	
	return card

# Cariye seçimi kartlarını güncelle
func update_cariye_selection_cards():
	if not cariye_selection_list:
		print("⚠️ update_cariye_selection_cards: cariye_selection_list is null!")
		return
	clear_list(cariye_selection_list)
	
	var idle_cariyeler = mission_manager.get_idle_concubines()
	if idle_cariyeler.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Boşta cariye yok"
		empty_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		cariye_selection_list.add_child(empty_label)
		return
	
	for i in range(idle_cariyeler.size()):
		var cariye = idle_cariyeler[i]
		var is_selected = (i == current_cariye_index)
		var card = create_cariye_selection_card(cariye, is_selected)
		cariye_selection_list.add_child(card)

# Cariye seçim kartı oluştur
func create_cariye_selection_card(cariye: Concubine, is_selected: bool) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(250, 100)
	
	# Seçili kart rengi
	if is_selected:
		card.modulate = Color(1, 1, 0.8, 1)
	else:
		card.modulate = Color(0.9, 0.9, 0.9, 1)
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_top", 10)
	vbox.add_theme_constant_override("margin_bottom", 10)
	
	# Cariye adı
	var name_label = Label.new()
	name_label.text = cariye.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# Yetenekler
	var best_skill = cariye.get_best_skill()
	var skills_text = "En İyi: %s (%d)" % [cariye.get_skill_name(best_skill), cariye.get_skill_level(best_skill)]
	var skills_label = Label.new()
	skills_label.text = skills_text
	skills_label.add_theme_font_size_override("font_size", 12)
	skills_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	vbox.add_child(skills_label)
	
	# Durum
	var status_label = Label.new()
	status_label.text = "Durum: %s" % cariye.get_status_name()
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	vbox.add_child(status_label)
	
	return card

# Görev geçmişi kartlarını güncelle
func update_mission_history_cards():
	if not mission_history_list:
		print("⚠️ update_mission_history_cards: mission_history_list is null!")
		return
	clear_list(mission_history_list)
	# Detay alanını mission_history_panel'in altına bir kere ekle
	if mission_history_panel and mission_history_detail_label == null:
		mission_history_detail_label = RichTextLabel.new()
		mission_history_detail_label.fit_content = true
		mission_history_detail_label.scroll_active = true
		mission_history_detail_label.custom_minimum_size = Vector2(0, 140)
		mission_history_detail_label.bbcode_enabled = true
		mission_history_detail_label.add_theme_font_size_override("normal_font_size", 12)
		mission_history_panel.add_child(mission_history_detail_label)
	
	var completed_missions = mission_manager.get_completed_missions()
	if completed_missions.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Tamamlanan görev yok"
		empty_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		mission_history_list.add_child(empty_label)
		return
	
	for i in range(completed_missions.size()):
		var mission_id = completed_missions[i]
		if mission_id in mission_manager.missions:
			var mission = mission_manager.missions[mission_id]
			var is_selected = (i == current_history_index)
			var card = create_mission_history_card(mission, is_selected)
			mission_history_list.add_child(card)

	# Seçili görev detayını güncelle
	update_mission_history_detail()

func update_mission_history_detail():
	if not mission_history_detail_label:
		return
	var completed_missions = mission_manager.get_completed_missions()
	if completed_missions.is_empty():
		mission_history_detail_label.text = ""
		return
	var sel_id = completed_missions[min(current_history_index, completed_missions.size()-1)]
	if sel_id not in mission_manager.missions:
		mission_history_detail_label.text = ""
		return
	var mission: Mission = mission_manager.missions[sel_id]
	var cariye_name = "?"
	if mission.assigned_cariye_id != -1 and mission.assigned_cariye_id in mission_manager.concubines:
		cariye_name = mission_manager.concubines[mission.assigned_cariye_id].name
	var status_icon = "✅" if mission.completed_successfully else ("❌" if mission.status == Mission.Status.BAŞARISIZ else "⚠️")
	var rewards_text = ""
	for k in mission.rewards.keys():
		rewards_text += "[color=lightgreen]%s: %s[/color]  " % [str(k), str(mission.rewards[k])]
	var penalties_text = ""
	for k in mission.penalties.keys():
		penalties_text += "[color=tomato]%s: %s[/color]  " % [str(k), str(mission.penalties[k])]
	var report = "" 
	report += "[b]%s %s[/b]\n" % [status_icon, mission.name]
	report += "Tür: %s | Zorluk: %s | Risk: %s\n" % [mission.get_mission_type_name(), mission.get_difficulty_name(), mission.risk_level]
	report += "Cariye: %s\n" % cariye_name
	report += "Süre: %.1fs  Başlangıç: %s  Bitiş: %s\n" % [mission.duration, str(mission.start_time), str(mission.end_time)]
	if rewards_text != "":
		report += "Ödül: %s\n" % rewards_text
	if penalties_text != "":
		report += "Ceza: %s\n" % penalties_text
	mission_history_detail_label.bbcode_text = report

# Görev geçmişi kartı oluştur
func create_mission_history_card(mission: Mission, is_selected: bool) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(750, 80)
	
	# Seçili kart rengi
	if is_selected:
		card.modulate = Color(1, 1, 0.8, 1)
	else:
		card.modulate = Color(0.9, 0.9, 0.9, 1)
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_top", 10)
	vbox.add_theme_constant_override("margin_bottom", 10)
	
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	# Görev adı ve durumu
	var title_label = Label.new()
	var status_icon = "✅" if mission.completed_successfully else "❌"
	title_label.text = "%s %s" % [status_icon, mission.name]
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title_label)
	
	# Görev türü
	var type_label = Label.new()
	type_label.text = mission.get_mission_type_name()
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	hbox.add_child(type_label)
	
	# Süre
	var duration_label = Label.new()
	duration_label.text = "%.1fs" % mission.duration
	duration_label.add_theme_font_size_override("font_size", 12)
	duration_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	hbox.add_child(duration_label)
	
	return card

# Görev geçmişi istatistiklerini güncelle
func update_mission_history_stats():
	var completed_missions = mission_manager.get_completed_missions()
	var total_missions = completed_missions.size()
	var successful_missions = 0
	
	for mission_id in completed_missions:
		if mission_id in mission_manager.missions:
			var mission = mission_manager.missions[mission_id]
			if mission.completed_successfully:
				successful_missions += 1
	
	var success_rate = 0.0
	if total_missions > 0:
		success_rate = (float(successful_missions) / float(total_missions)) * 100.0
	
	if stats_content:
		stats_content.text = "Toplam Görev: %d | Başarılı: %d | Başarısız: %d | Başarı Oranı: %.1f%%" % [
			total_missions, successful_missions, total_missions - successful_missions, success_rate
		]
	else:
		print("⚠️ update_mission_history_stats: stats_content is null!")

# Görev zincirleri UI'ını güncelle
func update_mission_chains_ui():
	if not mission_manager:
		return
	
	# MissionChainsList'i temizle
	var chains_list = get_node_or_null("MissionsPage/MissionChainsPanel/MissionChainsScroll/MissionChainsList")
	if not chains_list:
		return
	
	# Mevcut çocukları temizle
	for child in chains_list.get_children():
		child.queue_free()
	
	# Görev zincirlerini al ve sıralı ID listesi hazırla
	var mission_chains = mission_manager.mission_chains
	_chain_ids_ordered.clear()
	for cid in mission_chains.keys():
		_chain_ids_ordered.append(cid)
	_chain_ids_ordered.sort()  # basit alfabetik
	if mission_chains.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Aktif görev zinciri yok"
		empty_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		chains_list.add_child(empty_label)
		return
	
	# Her zincir için kart oluştur
	for i in range(_chain_ids_ordered.size()):
		var chain_id = _chain_ids_ordered[i]
		var chain_info = mission_chains[chain_id]
		var is_selected = (i == current_chain_index)
		var card = create_mission_chain_card(chain_id, chain_info)
		card.modulate = Color(1,1,0.8,1) if (is_selected and current_history_focus == "chains") else Color(1,1,1,1)
		chains_list.add_child(card)

# Görev zinciri kartı oluştur
func create_mission_chain_card(chain_id: String, chain_info: Dictionary) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(750, 100)
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_top", 10)
	vbox.add_theme_constant_override("margin_bottom", 10)
	
	# Zincir adı
	var name_label = Label.new()
	var chain_type_icon = "🔗"
	match chain_info.get("type", Mission.ChainType.NONE):
		Mission.ChainType.SEQUENTIAL: chain_type_icon = "🔗"
		Mission.ChainType.PARALLEL: chain_type_icon = "🔀"
		Mission.ChainType.CHOICE: chain_type_icon = "🔀"
	
	name_label.text = "%s %s" % [chain_type_icon, chain_info.get("name", "Bilinmeyen Zincir")]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# İlerleme
	var progress = mission_manager.get_chain_progress(chain_id)
	var progress_label = Label.new()
	progress_label.text = "İlerleme: %d/%d (%d%%)" % [progress.completed, progress.total, progress.percentage]
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	vbox.add_child(progress_label)
	
	# Açıklama (misyonlardan ilkini örnek olarak kullan)
	var description_label = Label.new()
	var missions_in_chain = mission_manager.get_chain_missions(chain_id)
	var desc_text = ""
	if missions_in_chain.size() > 0:
		desc_text = missions_in_chain[0].description
	else:
		desc_text = "Zincir açıklaması"
	description_label.text = desc_text
	description_label.add_theme_font_size_override("font_size", 10)
	description_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(description_label)
	
	# Ödüller
	if chain_info.has("rewards"):
		var rewards_text = "Ödül: "
		for reward_type in chain_info["rewards"]:
			var amount = chain_info["rewards"][reward_type]
			rewards_text += "%s " % reward_type
		rewards_text = rewards_text.strip_edges()
		
		var rewards_label = Label.new()
		rewards_label.text = rewards_text
		rewards_label.add_theme_font_size_override("font_size", 10)
		rewards_label.add_theme_color_override("font_color", Color.YELLOW)
		vbox.add_child(rewards_label)
	
	return card

# Zincir detay panelini güncelle
func _update_chain_detail_panel():
	var detail_panel = get_node_or_null("MissionsPage/MissionHistoryPanel/MissionHistoryStats")
	if not detail_panel:
		return
	# Basit metin: seçili zincirdeki görevler ve durumları
	var content: Label = get_node_or_null("MissionsPage/MissionHistoryPanel/MissionHistoryStats/StatsContent")
	if not content:
		return
	if _chain_ids_ordered.is_empty():
		return
	var selected_chain_id = _chain_ids_ordered[min(current_chain_index, _chain_ids_ordered.size()-1)]
	var missions_in_chain = mission_manager.get_chain_missions(selected_chain_id)
	var text = ""
	text += "Zincir: %s\n" % mission_manager.get_chain_info(selected_chain_id).get("name","?")
	text += "Görevler:\n"
	for m in missions_in_chain:
		var status_icon = "✅" if m.status == Mission.Status.TAMAMLANDI else "⏳" if m.status == Mission.Status.AKTİF else "•"
		text += "  %s %s\n" % [status_icon, m.name]
	content.text = text

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

# --- PLAYSTATION KONTROLLERİ ---

# Input handling
func _input(event):
	if not visible:
		return
	# Menü açıkken tüm inputları biz tüketeceğiz ki oyuncu hareket etmesin
	get_viewport().set_input_as_handled()
	if event is InputEvent and event.is_pressed():
		var action := ""
		if event.is_action("ui_up"): action = "ui_up"
		elif event.is_action("ui_down"): action = "ui_down"
		elif event.is_action("ui_left"): action = "ui_left"
		elif event.is_action("ui_right"): action = "ui_right"
		elif event.is_action("ui_accept"): action = "ui_accept"
		elif event.is_action("ui_cancel"): action = "ui_cancel"
		elif event.is_action("l2_trigger"): action = "l2_trigger"
		elif event.is_action("r2_trigger"): action = "r2_trigger"
		if action != "":
			print("[MissionCenter] Input consumed: ", action)
	
	# B tuşu ile geri gitme (basılı tutma desteği)
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		b_button_pressed = true
		b_button_timer = 0.0
		handle_back_button()
		return
	if event.is_action_released("ui_cancel") or event.is_action_released("ui_back"):
		b_button_pressed = false
	
	# L2/R2 ile sayfa değiştirme
	# Her iki aksiyon adını da destekle (proje: l2_trigger/r2_trigger)
	if event.is_action_pressed("ui_page_left") or Input.is_action_just_pressed("l2_trigger"):
		print("=== L2 TRIGGER ===")
		previous_page()
		return
	if event.is_action_pressed("ui_page_right") or Input.is_action_just_pressed("r2_trigger"):
		print("=== R2 TRIGGER ===")
		next_page()
		return
	
	# Mevcut sayfaya göre kontrolleri işle
	match current_page:
		PageType.MISSIONS:
			handle_missions_input(event)
		PageType.ASSIGNMENT:
			handle_assignment_input(event)
		PageType.CONSTRUCTION:
			handle_construction_input(event)
		PageType.NEWS:
			handle_news_input(event)
		PageType.CONCUBINE_DETAILS:
			handle_concubine_details_input(event)
		PageType.TRADE:
			handle_trade_input(event)

# Görevler sayfası kontrolleri
func handle_missions_input(event):
	# D-Pad debounce kontrolü
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		print("🎮 D-Pad input geldi - Timer: %.2f" % dpad_debounce_timer)
		if dpad_debounce_timer > 0:
			print("⏰ Debounce aktif, input görmezden geliniyor")
			return  # Debounce aktif, input'u görmezden gel
		print("✅ Debounce geçti, input işleniyor")
		dpad_debounce_timer = dpad_debounce_delay
	
	if event.is_action_pressed("ui_up"):
		print("⬆️ Yukarı D-Pad basıldı")
		handle_missions_up()
	elif event.is_action_pressed("ui_down"):
		print("⬇️ Aşağı D-Pad basıldı")
		handle_missions_down()
	elif event.is_action_pressed("ui_accept"):
		print("✅ A tuşu basıldı")
		handle_missions_accept()
	elif event.is_action_pressed("ui_select"):
		print("🔘 Select tuşu basıldı")
		handle_missions_select()
		return
	# Geçmiş görünümünde sol/sağ ile odak değişimi (geçmiş ↔ zincirler)
	if current_mission_menu_state == MissionMenuState.GÖREV_GEÇMİŞİ:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			if dpad_debounce_timer > 0:
				return
			dpad_debounce_timer = dpad_debounce_delay
			current_history_focus = "history" if event.is_action_pressed("ui_left") else "chains"
			update_missions_ui()
			return

	# Zincir görünümü açıkken D-Pad ile navigasyon
	if current_mission_menu_state == MissionMenuState.GÖREV_GEÇMİŞİ:
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
			if dpad_debounce_timer > 0:
				return
			dpad_debounce_timer = dpad_debounce_delay
			if current_history_focus == "history":
				# gez geçmiş listesi
				if event.is_action_pressed("ui_up"):
					current_history_index = max(0, current_history_index - 1)
				else:
					var completed = mission_manager.get_completed_missions()
					current_history_index = min(max(0,completed.size()-1), current_history_index + 1)
				update_missions_ui()
				update_mission_history_detail()
			else:
				# gez zincir listesi
				if event.is_action_pressed("ui_up"):
					current_chain_index = max(0, current_chain_index - 1)
				else:
					var total = _chain_ids_ordered.size()
					current_chain_index = min(max(0,total-1), current_chain_index + 1)
				update_mission_chains_ui()
				_update_chain_detail_panel()

# Görevler sayfası yukarı
func handle_missions_up():
	print("📋 handle_missions_up() çağrıldı - Menü durumu: %s" % MissionMenuState.keys()[current_mission_menu_state])
	match current_mission_menu_state:
		MissionMenuState.GÖREV_LISTESİ:
			var available_missions = mission_manager.get_available_missions()
			print("📋 Görev listesi - Mevcut index: %d, Toplam görev: %d" % [current_mission_index, available_missions.size()])
			if not available_missions.is_empty():
				current_mission_index = max(0, current_mission_index - 1)
				print("📋 Yeni görev index: %d" % current_mission_index)
				update_missions_ui()
		MissionMenuState.CARİYE_SEÇİMİ:
			var idle_cariyeler = mission_manager.get_idle_concubines()
			print("👥 Cariye seçimi - Mevcut index: %d, Toplam cariye: %d" % [current_cariye_index, idle_cariyeler.size()])
			if not idle_cariyeler.is_empty():
				current_cariye_index = max(0, current_cariye_index - 1)
				print("👥 Yeni cariye index: %d" % current_cariye_index)
				update_missions_ui()
		MissionMenuState.GÖREV_GEÇMİŞİ:
			var completed_missions = mission_manager.get_completed_missions()
			print("📜 Geçmiş - Mevcut index: %d, Toplam geçmiş: %d" % [current_history_index, completed_missions.size()])
			if not completed_missions.is_empty():
				current_history_index = max(0, current_history_index - 1)
				print("📜 Yeni geçmiş index: %d" % current_history_index)
				update_missions_ui()
				update_mission_history_detail()

# Görevler sayfası aşağı
func handle_missions_down():
	print("📋 handle_missions_down() çağrıldı - Menü durumu: %s" % MissionMenuState.keys()[current_mission_menu_state])
	match current_mission_menu_state:
		MissionMenuState.GÖREV_LISTESİ:
			var available_missions = mission_manager.get_available_missions()
			print("📋 Görev listesi - Mevcut index: %d, Toplam görev: %d" % [current_mission_index, available_missions.size()])
			if not available_missions.is_empty():
				current_mission_index = min(available_missions.size() - 1, current_mission_index + 1)
				print("📋 Yeni görev index: %d" % current_mission_index)
				update_missions_ui()
				# Seçim görünür kalsın
				_scroll_available_to_index(current_mission_index)
		MissionMenuState.CARİYE_SEÇİMİ:
			var idle_cariyeler = mission_manager.get_idle_concubines()
			print("👥 Cariye seçimi - Mevcut index: %d, Toplam cariye: %d" % [current_cariye_index, idle_cariyeler.size()])
			if not idle_cariyeler.is_empty():
				current_cariye_index = min(idle_cariyeler.size() - 1, current_cariye_index + 1)
				print("👥 Yeni cariye index: %d" % current_cariye_index)
				update_missions_ui()
		MissionMenuState.GÖREV_GEÇMİŞİ:
			var completed_missions = mission_manager.get_completed_missions()
			print("📜 Geçmiş - Mevcut index: %d, Toplam geçmiş: %d" % [current_history_index, completed_missions.size()])
			if not completed_missions.is_empty():
				current_history_index = min(completed_missions.size() - 1, current_history_index + 1)
				print("📜 Yeni geçmiş index: %d" % current_history_index)
				update_missions_ui()
				update_mission_history_detail()

# Görevler sayfası kabul
func handle_missions_accept():
	match current_mission_menu_state:
		MissionMenuState.GÖREV_LISTESİ:
			# Görev seçildi, cariye seçimine geç
			var available_missions = mission_manager.get_available_missions()
			if not available_missions.is_empty() and current_mission_index < available_missions.size():
				current_mission_menu_state = MissionMenuState.CARİYE_SEÇİMİ
				current_cariye_index = 0
				update_missions_ui()
		MissionMenuState.CARİYE_SEÇİMİ:
			# Cariye seçildi, görevi ata
			assign_selected_mission()
		MissionMenuState.GÖREV_GEÇMİŞİ:
			# Görev geçmişi detayına geç
			current_mission_menu_state = MissionMenuState.GEÇMİŞ_DETAYI
			update_missions_ui()

# Görevler sayfası seçim
func handle_missions_select():
	match current_mission_menu_state:
		MissionMenuState.GÖREV_LISTESİ:
			# Artık görev zincirleri ayrı değil; Select geçmiş ↔ görev listesi arasında geçer
			current_mission_menu_state = MissionMenuState.GÖREV_GEÇMİŞİ
			current_history_index = 0
			update_missions_ui()
		MissionMenuState.GÖREV_GEÇMİŞİ:
			# Görev listesine geri dön
			current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
			update_missions_ui()

# Seçili görevi ata
func assign_selected_mission():
	var available_missions = mission_manager.get_available_missions()
	var idle_cariyeler = mission_manager.get_idle_concubines()
	
	if available_missions.is_empty() or idle_cariyeler.is_empty():
		return
	
	if current_mission_index >= available_missions.size() or current_cariye_index >= idle_cariyeler.size():
		return
	
	var mission = available_missions[current_mission_index]
	var cariye = idle_cariyeler[current_cariye_index]
	
	print("=== GÖREV ATAMA DEBUG ===")
	print("Görev: %s (ID: %s)" % [mission.name, mission.id])
	print("Cariye: %s (ID: %d)" % [cariye.name, cariye.id])
	
	# MissionManager'a görev ata
	var success = mission_manager.assign_mission_to_concubine(cariye.id, mission.id)
	
	if success:
		print("✅ Görev başarıyla atandı!")
		# Görev listesine geri dön
		current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
		# current_mission_index = 0  # Index'i sıfırlama - kullanıcının seçimini koru
		update_missions_ui()
	else:
		print("❌ Görev atanamadı!")
	
	print("========================")

# Atama sayfası kontrolleri
func handle_assignment_input(event):
	# Mevcut atanabilir binaları al
	var all_buildings = get_all_available_buildings()
	var has_buildings = not all_buildings.is_empty()

	# Debounce
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		if dpad_debounce_timer > 0:
			return
		dpad_debounce_timer = dpad_debounce_delay

	match current_assignment_menu_state:
		AssignmentMenuState.BİNA_LISTESİ:
			if not has_buildings:
				update_assignment_ui()
				return
			# Yukarı/Aşağı: Bina seçimi
			if event.is_action_pressed("ui_up"):
				current_assignment_building_index = max(0, current_assignment_building_index - 1)
				update_assignment_ui()
				return
			if event.is_action_pressed("ui_down"):
				current_assignment_building_index = min(all_buildings.size() - 1, current_assignment_building_index + 1)
				update_assignment_ui()
				return
			# Sol/Sağ: İşçi çıkar/ekle
			if event.is_action_pressed("ui_left"):
				print("=== SOL D-PAD: İşçi çıkarılıyor ===")
				remove_worker_from_building(all_buildings[current_assignment_building_index])
				update_assignment_ui()
				return
			if event.is_action_pressed("ui_right"):
				print("=== SAĞ D-PAD: İşçi ekleniyor ===")
				add_worker_to_building(all_buildings[current_assignment_building_index])
				update_assignment_ui()
				return
			# A: Detay
			if event.is_action_pressed("ui_accept"):
				current_assignment_menu_state = AssignmentMenuState.BİNA_DETAYI
				update_assignment_ui()
				return

		AssignmentMenuState.BİNA_DETAYI:
			if event.is_action_pressed("ui_cancel"):
				current_assignment_menu_state = AssignmentMenuState.BİNA_LISTESİ
				update_assignment_ui()
				return

# İnşaat sayfası kontrolleri
func handle_construction_input(event):
	# D-Pad debounce kontrolü
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		print("🏗️ İnşaat D-Pad input geldi - Timer: %.2f, Menü Durumu: %s" % [dpad_debounce_timer, MenuState.keys()[current_menu_state]])
		if dpad_debounce_timer > 0:
			print("⏰ Debounce aktif, input görmezden geliniyor")
			return  # Debounce aktif, input'u görmezden gel
		print("✅ Debounce geçti, input işleniyor")
		dpad_debounce_timer = dpad_debounce_delay
	
	# Menü durumuna göre D-Pad kontrolleri
	match current_menu_state:
		MenuState.İŞLEM_SEÇİMİ:
			# Sadece Sol/Sağ D-Pad çalışır (işlem seçimi)
			if event.is_action_pressed("ui_left"):
				print("⬅️ Sol D-Pad - İşlem: %d -> %d" % [current_construction_action, max(0, current_construction_action - 1)])
				current_construction_action = max(0, current_construction_action - 1)
				update_construction_ui()
			elif event.is_action_pressed("ui_right"):
				print("➡️ Sağ D-Pad - İşlem: %d -> %d" % [current_construction_action, min(3, current_construction_action + 1)])
				current_construction_action = min(3, current_construction_action + 1)  # 4 işlem var
				update_construction_ui()
			# Yukarı/Aşağı D-Pad bu durumda çalışmaz
		
		MenuState.KATEGORİ_SEÇİMİ:
			# Sadece Yukarı/Aşağı D-Pad çalışır (kategori seçimi)
			if event.is_action_pressed("ui_up"):
				print("⬆️ Yukarı D-Pad - Kategori: %d -> %d" % [current_building_category, max(0, current_building_category - 1)])
				current_building_category = max(0, current_building_category - 1)
				current_building_index = 0
				update_construction_ui()
			elif event.is_action_pressed("ui_down"):
				print("⬇️ Aşağı D-Pad - Kategori: %d -> %d" % [current_building_category, min(3, current_building_category + 1)])
				current_building_category = min(3, current_building_category + 1)  # 4 kategori var
				current_building_index = 0
				update_construction_ui()
			# Sol/Sağ D-Pad bu durumda çalışmaz
		
		MenuState.BİNA_SEÇİMİ:
			# Sadece Yukarı/Aşağı D-Pad çalışır (bina seçimi)
			if event.is_action_pressed("ui_up"):
				print("⬆️ Yukarı D-Pad - Bina: %d -> %d" % [current_building_index, max(0, current_building_index - 1)])
				current_building_index = max(0, current_building_index - 1)
				update_construction_ui()
			elif event.is_action_pressed("ui_down"):
				var buildings = building_categories.get(current_building_category, [])
				print("⬇️ Aşağı D-Pad - Bina: %d -> %d" % [current_building_index, min(buildings.size() - 1, current_building_index + 1)])
				current_building_index = min(buildings.size() - 1, current_building_index + 1)
				update_construction_ui()
			# Sol/Sağ D-Pad bu durumda çalışmaz
	
	# A tuşu her durumda çalışır
	if event.is_action_pressed("ui_accept"):
		print("✅ A tuşu - İnşaat işlemi başlatılıyor")
		execute_construction()
	
	# B tuşu ile geri dönme
	if event.is_action_pressed("ui_cancel"):
		print("🔙 B tuşu - Geri dönme")
		match current_menu_state:
			MenuState.İŞLEM_SEÇİMİ:
				# En üst seviyede, geri dönülemez
				print("Zaten en üst seviyede, geri gidilemez")
			MenuState.KATEGORİ_SEÇİMİ:
				# İşlem seçimine geri dön
				print("🔙 Kategori seçiminden işlem seçimine dönülüyor")
				current_menu_state = MenuState.İŞLEM_SEÇİMİ
				update_construction_ui()
			MenuState.BİNA_SEÇİMİ:
				# Kategori seçimine geri dön
				print("🔙 Bina seçiminden kategori seçimine dönülüyor")
				current_menu_state = MenuState.KATEGORİ_SEÇİMİ
				update_construction_ui()

# Haber sayfası kontrolleri
func handle_news_input(event):
	# Navigasyon: Sol/Sağ ile panel değiştir, Yukarı/Aşağı ile öğe seç, A ile detay, B ile kapat
	# Detay overlay açıksa öncelik kapatmadadır
	if news_detail_overlay:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			_news_close_detail()
			return
	if event.is_action_pressed("ui_left"):
		if dpad_debounce_timer > 0:
			return
		dpad_debounce_timer = dpad_debounce_delay
		news_focus = "village" if news_focus == "world" else ("world" if news_focus == "random" else "village")
		_news_refresh_selection_visual()
		return
	if event.is_action_pressed("ui_right"):
		if dpad_debounce_timer > 0:
			return
		dpad_debounce_timer = dpad_debounce_delay
		news_focus = "world" if news_focus == "village" else ("random" if news_focus == "world" else "random")
		_news_refresh_selection_visual()
		return
	if event.is_action_pressed("ui_up"):
		if dpad_debounce_timer > 0:
			return
		dpad_debounce_timer = dpad_debounce_delay
		_news_move(-1)
		return
	if event.is_action_pressed("ui_down"):
		if dpad_debounce_timer > 0:
			return
		dpad_debounce_timer = dpad_debounce_delay
		_news_move(1)
		return
	if event.is_action_pressed("ui_accept"):
		_news_open_detail()
		return
	if event.is_action_pressed("ui_cancel"):
		_news_close_detail()
		return

func _on_news_posted(news: Dictionary):
	# Kuyruklara ekle ve UI'ya render et (üstte olacak şekilde)
	var is_village = news.get("category", "") in ["Başarı", "Bilgi"]
	if is_village:
		news_queue_village.push_front(news)
		var list_node: VBoxContainer = get_node_or_null("NewsCenterPage/NewsContent/VillageNewsPanel/VillageNewsScroll/VillageNewsList")
		if list_node:
			var card = create_news_card(news)
			list_node.add_child(card)
	else:
		news_queue_world.push_front(news)
		var list_node2: VBoxContainer = get_node_or_null("NewsCenterPage/NewsContent/WorldNewsPanel/WorldNewsScroll/WorldNewsList")
		if list_node2:
			var card2 = create_news_card(news)
			list_node2.add_child(card2)
	if current_page == PageType.NEWS:
		_news_refresh_selection_visual()

func _open_trade_overlay():
	if trade_overlay:
		trade_overlay.visible = true
		return
	# Basit overlay
	trade_overlay = Panel.new()
	trade_overlay.name = "TradeOverlay"
	trade_overlay.custom_minimum_size = Vector2(600, 360)
	trade_overlay.anchor_left = 0.5
	trade_overlay.anchor_top = 0.5
	trade_overlay.anchor_right = 0.5
	trade_overlay.anchor_bottom = 0.5
	trade_overlay.offset_left = -300
	trade_overlay.offset_right = 300
	trade_overlay.offset_top = -180
	trade_overlay.offset_bottom = 180
	
	var root = get_tree().get_root()
	root.add_child(trade_overlay)
	
	var vb = VBoxContainer.new()
	trade_overlay.add_child(vb)
	vb.anchor_left = 0
	vb.anchor_top = 0
	vb.anchor_right = 1
	vb.anchor_bottom = 1
	vb.offset_left = 16
	vb.offset_right = -16
	vb.offset_top = 16
	vb.offset_bottom = -16

	var title = Label.new()
	title.text = "Ticaret Anlaşmaları"
	title.add_theme_font_size_override("font_size", 18)
	vb.add_child(title)

	trade_offers_vbox = VBoxContainer.new()
	trade_offers_vbox.add_theme_constant_override("separation", 8)
	vb.add_child(trade_offers_vbox)

	# Örnek teklif listesi (ileride MissionManager'dan dinamik)
	available_trade_offers = [
		{"partner": "Doğu Köyü", "daily_gold": 100, "mods": {"food": 3}, "infinite": true},
		{"partner": "Batı Kasabası", "daily_gold": 60, "mods": {"wood": 2}, "days": 3, "infinite": false}
	]
	current_trade_index = 0
	_update_trade_overlay()
	trade_mode = true

func _update_trade_overlay():
	if not trade_offers_vbox:
		return
	for c in trade_offers_vbox.get_children():
		c.queue_free()
	for i in range(available_trade_offers.size()):
		var t = available_trade_offers[i]
		var row = HBoxContainer.new()
		trade_offers_vbox.add_child(row)
		var mark = Label.new()
		mark.text = ">" if i == current_trade_index else "  "
		row.add_child(mark)
		var lbl = Label.new()
		var mods_text = ""
		for r in t.get("mods", {}).keys():
			var d = int(t["mods"][r])
			mods_text += "%s%s %s  " % ["+" if d>=0 else "", d, r]
		lbl.text = "%s | %d altın/gün | %s%s" % [t.get("partner","?"), int(t.get("daily_gold",0)), mods_text, (" (Süresiz)" if t.get("infinite",false) else "")]
		row.add_child(lbl)

func _apply_selected_trade_offer():
	if available_trade_offers.is_empty():
		return
	var sel = available_trade_offers[current_trade_index]
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("add_trade_agreement"):
		mm.add_trade_agreement(sel.get("partner","?"), int(sel.get("daily_gold",0)), sel.get("mods",{}), int(sel.get("days",0)), bool(sel.get("infinite",false)))
	_close_trade_overlay()

func _close_trade_overlay():
	trade_mode = false
	if trade_overlay:
		trade_overlay.visible = false

# Cariye detay sayfası kontrolleri
func handle_concubine_details_input(event):
	if event.is_action_pressed("ui_up"):
		# Cariye yukarı
		var concubine_count = mission_manager.concubines.size()
		if concubine_count > 0:
			current_concubine_detail_index = max(0, current_concubine_detail_index - 1)
			update_concubine_details_ui()
	elif event.is_action_pressed("ui_down"):
		# Cariye aşağı
		var concubine_count = mission_manager.concubines.size()
		if concubine_count > 0:
			current_concubine_detail_index = min(concubine_count - 1, current_concubine_detail_index + 1)
			update_concubine_details_ui()
	elif event.is_action_pressed("ui_accept"):
		# Cariye detayı
		pass

# --- TİCARET SAYFASI ---
func handle_trade_input(event):
	# Sol panel (aktif) ile sağ panel (teklifler) arasında LEFT/RIGHT ile geçiş yapalım
	var focus_offers = (current_focus_panel == "offers")
	var allow_step = dpad_debounce_timer <= 0
	# LEFT
	if event.is_action_pressed("ui_left"):
		if event.is_echo() or not allow_step:
			return
		dpad_debounce_timer = dpad_debounce_delay
		current_focus_panel = "active"
		update_trade_ui()
		return
	# RIGHT
	if event.is_action_pressed("ui_right"):
		if event.is_echo() or not allow_step:
			return
		dpad_debounce_timer = dpad_debounce_delay
		current_focus_panel = "offers"
		update_trade_ui()
		return
	# UP
	if event.is_action_pressed("ui_up"):
		if event.is_echo() or not allow_step:
			return
		dpad_debounce_timer = dpad_debounce_delay
		if current_focus_panel == "active":
			current_trade_index = max(0, current_trade_index - 1)
		else:
			current_offer_index = max(0, current_offer_index - 1)
		update_trade_ui()
		return
	# DOWN
	if event.is_action_pressed("ui_down"):
		if event.is_echo() or not allow_step:
			return
		dpad_debounce_timer = dpad_debounce_delay
		if current_focus_panel == "active":
			var mm = get_node_or_null("/root/MissionManager")
			var size = mm.trade_agreements.size() if (mm and "trade_agreements" in mm) else 0
			current_trade_index = min(max(0,size-1), current_trade_index + 1)
		else:
			current_offer_index = min(max(0,available_trade_offers.size()-1), current_offer_index + 1)
		update_trade_ui()
		_scroll_trade_selection()
		return
	if event.is_action_pressed("ui_accept"):
		if current_focus_panel == "active":
			_cancel_selected_trade_agreement()
		else:
			_apply_selected_trade_offer_gamepad()
		return

func update_trade_ui():
	if current_page != PageType.TRADE:
		return
	var active_list = get_node_or_null("TradePage/TradeContent/ActiveAgreementsPanel/ActiveAgreementsScroll/ActiveAgreementsList")
	var offers_list = get_node_or_null("TradePage/TradeContent/OffersPanel/OffersScroll/OffersList")
	# Navigation indices clamp
	if current_trade_index < 0:
		current_trade_index = 0
	if current_offer_index < 0:
		current_offer_index = 0
	if active_list:
		for c in active_list.get_children():
			c.queue_free()
		var mm = get_node_or_null("/root/MissionManager")
		if mm and "trade_agreements" in mm:
			for i in range(mm.trade_agreements.size()):
				var ta = mm.trade_agreements[i]
				var card = Panel.new()
				card.custom_minimum_size = Vector2(0, 72)
				card.modulate = Color(1,1,0.8,1) if i == current_trade_index else Color(1,1,1,1)
				active_list.add_child(card)
				var vb = VBoxContainer.new()
				card.add_child(vb)
				vb.anchor_left = 0
				vb.anchor_top = 0
				vb.anchor_right = 1
				vb.anchor_bottom = 1
				vb.offset_left = 10
				vb.offset_right = -10
				vb.offset_top = 8
				vb.offset_bottom = -8
				var title = Label.new()
				title.text = "🤝 %s" % ta.get("partner","?")
				title.add_theme_font_size_override("font_size", 14)
				vb.add_child(title)
				var info = Label.new()
				var mods_text = ""
				for r in ta.get("modifiers", {}).keys():
					var d = int(ta["modifiers"][r])
					mods_text += "%s%s %s  " % ["+" if d>=0 else "", d, r]
				var tail = " (Süresiz)" if ta.get("infinite",false) else ""
				var days_text = ""
				if not ta.get("infinite", false):
					var rd = int(ta.get("remaining_days", 0))
					days_text = "   ⏳ %d gün" % rd
				info.text = "💰 %d altın/gün   |   %s%s%s" % [int(ta.get("daily_gold",0)), mods_text, tail, days_text]
				info.add_theme_font_size_override("font_size", 12)
				info.add_theme_color_override("font_color", Color.LIGHT_GRAY)
				vb.add_child(info)
				# İptal butonu yerine gamepad ile A: iptal için highlight kullanacağız; görsel ipucu için küçük etiket
				var hint = Label.new()
				hint.text = "A: İptal" if i == current_trade_index else ""
				hint.add_theme_font_size_override("font_size", 10)
				hint.add_theme_color_override("font_color", Color(0.9,0.6,0.6))
				vb.add_child(hint)
	if offers_list:
		for c in offers_list.get_children():
			c.queue_free()
		# MissionManager'dan teklifler
		var mm2 = get_node_or_null("/root/MissionManager")
		available_trade_offers = mm2.get_trade_offers() if (mm2 and mm2.has_method("get_trade_offers")) else []
		for i in range(available_trade_offers.size()):
			var t = available_trade_offers[i]
			var card2 = Panel.new()
			card2.custom_minimum_size = Vector2(0, 72)
			card2.modulate = Color(1,1,0.8,1) if i == current_offer_index else Color(1,1,1,1)
			offers_list.add_child(card2)
			var hb = HBoxContainer.new()
			card2.add_child(hb)
			hb.anchor_left = 0
			hb.anchor_top = 0
			hb.anchor_right = 1
			hb.anchor_bottom = 1
			hb.offset_left = 10
			hb.offset_right = -10
			hb.offset_top = 8
			hb.offset_bottom = -8
			var vb2 = VBoxContainer.new()
			hb.add_child(vb2)
			var title2 = Label.new()
			title2.text = "📜 %s" % t.get("partner","?")
			title2.add_theme_font_size_override("font_size", 14)
			vb2.add_child(title2)
			var info2 = Label.new()
			var mods2 = ""
			for r in t.get("mods", {}).keys():
				var d2 = int(t["mods"][r])
				mods2 += "%s%s %s  " % ["+" if d2>=0 else "", d2, r]
			info2.text = "💰 %d altın/gün   |   %s%s" % [int(t.get("daily_gold",0)), mods2, (" (Süresiz)" if t.get("infinite",false) else "")]
			info2.add_theme_font_size_override("font_size", 12)
			info2.add_theme_color_override("font_color", Color.LIGHT_GRAY)
			vb2.add_child(info2)
			# A: Oluştur (gamepad); ipucu etiketi
			var hint2 = Label.new()
			hint2.text = "A: Oluştur" if i == current_offer_index else ""
			hint2.add_theme_font_size_override("font_size", 10)
			hint2.add_theme_color_override("font_color", Color(0.6,0.9,0.6))
			hb.add_child(hint2)

	# Seçimler görünür kalsın
	_scroll_trade_selection()

func _on_trade_offer_accept(index: int):
	if index < 0 or index >= available_trade_offers.size():
		return
	var sel = available_trade_offers[index]
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("add_trade_agreement"):
		mm.add_trade_agreement(sel.get("partner","?"), int(sel.get("daily_gold",0)), sel.get("mods",{}), int(sel.get("days",0)), bool(sel.get("infinite",false)))
	update_trade_ui()

func _scroll_trade_selection():
	# Aktif anlaşmalar
	var active_scroll: ScrollContainer = get_node_or_null("TradePage/TradeContent/ActiveAgreementsPanel/ActiveAgreementsScroll")
	var active_list: VBoxContainer = get_node_or_null("TradePage/TradeContent/ActiveAgreementsPanel/ActiveAgreementsScroll/ActiveAgreementsList")
	if active_scroll and active_list and current_trade_index >= 0 and current_trade_index < active_list.get_child_count():
		var ctrl := active_list.get_child(current_trade_index)
		if ctrl is Control:
			active_scroll.ensure_control_visible(ctrl)
	# Teklifler
	var offers_scroll: ScrollContainer = get_node_or_null("TradePage/TradeContent/OffersPanel/OffersScroll")
	var offers_list: VBoxContainer = get_node_or_null("TradePage/TradeContent/OffersPanel/OffersScroll/OffersList")
	if offers_scroll and offers_list and current_offer_index >= 0 and current_offer_index < offers_list.get_child_count():
		var ctrl2 := offers_list.get_child(current_offer_index)
		if ctrl2 is Control:
			offers_scroll.ensure_control_visible(ctrl2)

func _on_trade_offers_updated():
	if current_page == PageType.TRADE:
		update_trade_ui()

func _apply_selected_trade_offer_gamepad():
	if current_offer_index < 0 or current_offer_index >= available_trade_offers.size():
		return
	_on_trade_offer_accept(current_offer_index)

func _cancel_selected_trade_agreement():
	var mm = get_node_or_null("/root/MissionManager")
	if not (mm and "trade_agreements" in mm):
		return
	if current_trade_index < 0 or current_trade_index >= mm.trade_agreements.size():
		return
	if mm.has_method("cancel_trade_agreement_by_index"):
		mm.cancel_trade_agreement_by_index(current_trade_index)
	current_trade_index = max(0, current_trade_index - 1)
	update_trade_ui()

# İnşaat işlemini gerçekleştir
func execute_construction():
	print("=== İNŞAAT DEBUG ===")
	print("İşlem: %s" % action_names[current_construction_action])
	print("Kategori: %s" % category_names[current_building_category])
	
	# Menü durumuna göre işlem yap
	match current_menu_state:
		MenuState.İŞLEM_SEÇİMİ:
			print("=== A TUŞU: İşlem seçildi, kategorilere geçiliyor ===")
			current_menu_state = MenuState.KATEGORİ_SEÇİMİ
			current_building_category = 0  # Kategori seçimine başla
			update_construction_ui()
		
		MenuState.KATEGORİ_SEÇİMİ:
			print("=== A TUŞU: Kategori seçildi, binalara geçiliyor ===")
			current_menu_state = MenuState.BİNA_SEÇİMİ
			current_building_index = 0  # Bina seçimine başla
			update_construction_ui()
		
		MenuState.BİNA_SEÇİMİ:
			print("=== A TUŞU: Bina inşa ediliyor ===")
			perform_construction_action()
	
	print("===================")

# Gerçek inşaat işlemini gerçekleştir
func perform_construction_action():
	var building_name = building_categories[current_building_category][current_building_index]
	print("Bina: %s" % building_name)
	
	match current_construction_action:
		ConstructionAction.BUILD:
			print("=== İNŞAAT İŞLEMİ ===")
			print("Bina türü: %s" % building_name)
			# Gerçek inşaat: VillageManager üzerinden yerleştir
			var scene_path = building_scene_paths.get(building_name, "")
			if scene_path.is_empty():
				printerr("Build error: scene path not found for ", building_name)
			else:
				var vm = get_node_or_null("/root/VillageManager")
				if vm and vm.has_method("request_build_building"):
					var ok = vm.request_build_building(scene_path)
					if ok:
						print("✅ Bina inşa edildi!")
					else:
						print("❌ İnşa başarısız (şartlar/yer yok)!")
				else:
					printerr("VillageManager not found or missing request_build_building")
		
		ConstructionAction.DEMOLISH:
			print("=== YIKMA İŞLEMİ ===")
			print("Bina türü: %s" % building_name)
			# Burada gerçek yıkma işlemi yapılacak
			print("✅ Bina yıkıldı!")
		
		ConstructionAction.UPGRADE:
			print("=== YÜKSELTME İŞLEMİ ===")
			print("Bina türü: %s" % building_name)
			# Burada gerçek yükseltme işlemi yapılacak
			print("✅ Bina yükseltildi!")
		
		ConstructionAction.INFO:
			print("=== BİLGİ GÖSTERİMİ ===")
			print("Bina türü: %s" % building_name)
			# Burada bina bilgileri gösterilecek
			print("ℹ️ Bina bilgileri gösterildi!")
	
	# İşlem tamamlandıktan sonra menü durumunu sıfırla
	current_menu_state = MenuState.İŞLEM_SEÇİMİ
	current_construction_action = 0
	current_building_category = 0
	current_building_index = 0
	update_construction_ui()

# --- EKSİK UI GÜNCELLEME FONKSİYONLARI ---

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

# --- HABER SİSTEMİ ---

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

# Köy haberlerini güncelle
func update_village_news():
	var village_news_list = get_node_or_null("NewsCenterPage/NewsContent/VillageNewsPanel/VillageNewsScroll/VillageNewsList")
	if not village_news_list:
		return
	
	# Mevcut haberleri temizle
	for child in village_news_list.get_children():
		child.queue_free()
	
	# Örnek köy haberleri
	var village_news = [
		{
			"title": "✅ Yeni Bina Tamamlandı",
			"content": "Oduncu kampı başarıyla inşa edildi. Artık odun üretimi başlayabilir.",
			"time": "2 dakika önce"
		},
		{
			"title": "👥 İşçi Atandı",
			"content": "Yeni işçi kuyuya atandı. Su üretimi artacak.",
			"time": "5 dakika önce"
		},
		{
			"title": "🏗️ İnşaat Başladı",
			"content": "Taş madeni inşaatı başladı. 10 dakika içinde tamamlanacak.",
			"time": "8 dakika önce"
		}
	]
	
	# Haberleri göster
	for news in village_news:
		var news_card = create_news_card(news)
		village_news_list.add_child(news_card)

# Dünya haberlerini güncelle
func update_world_news():
	var world_news_list = get_node_or_null("NewsCenterPage/NewsContent/WorldNewsPanel/WorldNewsScroll/WorldNewsList")
	if not world_news_list:
		return
	
	# Mevcut haberleri temizle
	for child in world_news_list.get_children():
		child.queue_free()
	
	# MissionManager'dan dünya olaylarını al
	var world_events = []
	if mission_manager:
		world_events = mission_manager.get_active_world_events()
	
	# Örnek dünya haberleri
	var world_news = [
		{
			"title": "⚠️ Kuzey Köyü Saldırıya Uğradı",
			"content": "Haydutlar kuzey köyüne saldırdı. Ticaret yolları tehlikede.",
			"time": "1 saat önce",
			"color": Color(1, 0.8, 0.8, 1)
		},
		{
			"title": "✅ Yeni Ticaret Yolu Açıldı",
			"content": "Doğu ticaret yolu güvenli hale geldi. Yeni fırsatlar doğdu.",
			"time": "3 saat önce",
			"color": Color(0.8, 1, 0.8, 1)
		}
	]
	
	# Aktif dünya olaylarını ekle
	for event in world_events:
		world_news.append({
			"title": "🌍 " + event.get("name", "Bilinmeyen Olay"),
			"content": event.get("description", "Açıklama yok"),
			"time": "Şimdi",
			"color": Color(1, 1, 0.8, 1)
		})
	
	# Haberleri göster
	for news in world_news:
		var news_card = create_news_card(news)
		world_news_list.add_child(news_card)

# Rastgele olayları güncelle
func update_random_events():
	var random_events_list = get_node_or_null("NewsCenterPage/RandomEventsPanel/RandomEventsScroll/RandomEventsList")
	if not random_events_list:
		return
	
	# Mevcut olayları temizle
	for child in random_events_list.get_children():
		child.queue_free()
	
	# MissionManager'dan aktif olayları al
	var active_events = []
	if mission_manager:
		active_events = mission_manager.get_active_world_events()
	
	# Örnek rastgele olaylar
	var random_events = [
		{
			"title": "🌧️ Kuraklık Başladı",
			"content": "Su üretimi %20 azaldı",
			"color": Color(1, 1, 0.8, 1)
		},
		{
			"title": "👥 Göçmenler Geldi",
			"content": "Yeni işçi mevcut",
			"color": Color(0.8, 1, 0.8, 1)
		},
		{
			"title": "🐺 Kurt Sürüsü",
			"content": "Avcılık tehlikeli",
			"color": Color(1, 0.8, 0.8, 1)
		}
	]
	
	# Aktif olayları ekle
	for event in active_events:
		random_events.append({
			"title": "🌍 " + event.get("name", "Bilinmeyen Olay"),
			"content": event.get("description", "Açıklama yok"),
			"color": Color(1, 1, 0.8, 1)
		})
	
	# Olayları göster
	for event in random_events:
		var event_card = create_random_event_card(event)
		random_events_list.add_child(event_card)

# Haber kartı oluştur
func create_news_card(news: Dictionary) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(350, 80)
	card.focus_mode = Control.FOCUS_NONE
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_top", 10)
	vbox.add_theme_constant_override("margin_bottom", 10)
	
	# Haber başlığı
	var title_label = Label.new()
	title_label.text = news.get("title", "Başlık yok")
	title_label.add_theme_font_size_override("font_size", 14)
	if news.has("color"):
		title_label.add_theme_color_override("font_color", news["color"])
	else:
		title_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_label)
	
	# Haber içeriği
	var content_label = Label.new()
	content_label.text = news.get("content", "İçerik yok")
	content_label.add_theme_font_size_override("font_size", 12)
	content_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(content_label)
	
	# Zaman
	var time_label = Label.new()
	time_label.text = news.get("time", "Zaman yok")
	time_label.add_theme_font_size_override("font_size", 10)
	time_label.add_theme_color_override("font_color", Color.GRAY)
	vbox.add_child(time_label)
	
	return card

func _news_lists() -> Dictionary:
	return {
		"village_scroll": get_node_or_null("NewsCenterPage/NewsContent/VillageNewsPanel/VillageNewsScroll"),
		"village_list": get_node_or_null("NewsCenterPage/NewsContent/VillageNewsPanel/VillageNewsScroll/VillageNewsList"),
		"world_scroll": get_node_or_null("NewsCenterPage/NewsContent/WorldNewsPanel/WorldNewsScroll"),
		"world_list": get_node_or_null("NewsCenterPage/NewsContent/WorldNewsPanel/WorldNewsScroll/WorldNewsList"),
		"random_scroll": get_node_or_null("NewsCenterPage/RandomEventsPanel/RandomEventsScroll"),
		"random_list": get_node_or_null("NewsCenterPage/RandomEventsPanel/RandomEventsScroll/RandomEventsList")
	}

func _news_refresh_selection_visual():
	var lists = _news_lists()
	# reset all card colors
	for key in ["village_list", "world_list", "random_list"]:
		var l = lists[key]
		if l:
			for child in l.get_children():
				if child is Panel:
					child.modulate = Color(1,1,1,1)
	# highlight current
	match news_focus:
		"village":
			_news_highlight(lists["village_list"], lists["village_scroll"], current_news_index_village)
		"world":
			_news_highlight(lists["world_list"], lists["world_scroll"], current_news_index_world)
		"random":
			_news_highlight(lists["random_list"], lists["random_scroll"], current_news_index_random)

func _news_highlight(list, scroll: ScrollContainer, index: int):
	if not list:
		return
	var count = list.get_child_count()
	if count == 0:
		return
	var i = clamp(index, 0, count - 1)
	var card = list.get_child(i)
	if card and card is Panel:
		card.modulate = Color(1,1,0.8,1)
		if scroll:
			scroll.ensure_control_visible(card)

func _news_move(dir: int):
	var lists = _news_lists()
	match news_focus:
		"village":
			var l = lists["village_list"]
			if l:
				current_news_index_village = clamp(current_news_index_village + dir, 0, max(0, l.get_child_count()-1))
		"world":
			var l2 = lists["world_list"]
			if l2:
				current_news_index_world = clamp(current_news_index_world + dir, 0, max(0, l2.get_child_count()-1))
		"random":
			var l3 = lists["random_list"]
			if l3:
				current_news_index_random = clamp(current_news_index_random + dir, 0, max(0, l3.get_child_count()-1))
	_news_refresh_selection_visual()

func _news_open_detail():
	var lists = _news_lists()
	var list: VBoxContainer = null
	var idx: int = 0
	match news_focus:
		"village":
			list = lists["village_list"]
			idx = current_news_index_village
		"world":
			list = lists["world_list"]
			idx = current_news_index_world
		"random":
			list = lists["random_list"]
			idx = current_news_index_random
	if not list or idx < 0 or idx >= list.get_child_count():
		return
	var card = list.get_child(idx)
	if not (card and card.get_child_count() > 0):
		return
	var vb = card.get_child(0)
	if not (vb and vb is VBoxContainer and vb.get_child_count() >= 2):
		return
	var title = (vb.get_child(0) as Label).text if vb.get_child(0) is Label else "Haber"
	var content = (vb.get_child(1) as Label).text if vb.get_child(1) is Label else ""
	_show_news_detail(title, content)

func _show_news_detail(title: String, content: String):
	if news_detail_overlay:
		news_detail_overlay.queue_free()
	news_detail_overlay = Panel.new()
	news_detail_overlay.custom_minimum_size = Vector2(600, 300)
	news_detail_overlay.anchor_left = 0.5
	news_detail_overlay.anchor_top = 0.5
	news_detail_overlay.anchor_right = 0.5
	news_detail_overlay.anchor_bottom = 0.5
	news_detail_overlay.offset_left = -300
	news_detail_overlay.offset_right = 300
	news_detail_overlay.offset_top = -150
	news_detail_overlay.offset_bottom = 150
	var vb = VBoxContainer.new()
	news_detail_overlay.add_child(vb)
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("margin_left", 16)
	vb.add_theme_constant_override("margin_right", 16)
	vb.add_theme_constant_override("margin_top", 16)
	vb.add_theme_constant_override("margin_bottom", 16)
	var t = Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 18)
	vb.add_child(t)
	var c = Label.new()
	c.text = content
	c.add_theme_font_size_override("font_size", 13)
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(c)
	get_tree().get_root().add_child(news_detail_overlay)

func _news_close_detail():
	if news_detail_overlay:
		news_detail_overlay.queue_free()
		news_detail_overlay = null

# Rastgele olay kartı oluştur
func create_random_event_card(event: Dictionary) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(200, 100)
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_top", 10)
	vbox.add_theme_constant_override("margin_bottom", 10)
	
	# Olay başlığı
	var title_label = Label.new()
	title_label.text = event.get("title", "Başlık yok")
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", event.get("color", Color.WHITE))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# Olay içeriği
	var content_label = Label.new()
	content_label.text = event.get("content", "İçerik yok")
	content_label.add_theme_font_size_override("font_size", 10)
	content_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(content_label)
	
	return card

# --- CARİYE DETAY SAYFASI ---

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

# Cariye liste kartı oluştur
func create_concubine_list_card(cariye: Concubine, is_selected: bool) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(250, 100)
	
	# Seçili kart rengi
	if is_selected:
		card.modulate = Color(1, 1, 0.8, 1)
	else:
		card.modulate = Color(0.9, 0.9, 0.9, 1)
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_top", 10)
	vbox.add_theme_constant_override("margin_bottom", 10)
	
	# Cariye adı ve seviyesi
	var name_label = Label.new()
	name_label.text = "%s (Lv.%d)" % [cariye.name, cariye.level]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# Durum
	var status_label = Label.new()
	status_label.text = "Durum: %s" % cariye.get_status_name()
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	vbox.add_child(status_label)
	
	# En iyi yetenek
	var best_skill = cariye.get_best_skill()
	var skills_label = Label.new()
	skills_label.text = "En İyi: %s (%d)" % [cariye.get_skill_name(best_skill), cariye.get_skill_level(best_skill)]
	skills_label.add_theme_font_size_override("font_size", 10)
	skills_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	vbox.add_child(skills_label)
	
	return card

# Seçili cariye detaylarını güncelle
func update_selected_concubine_details():
	if not mission_manager:
		return
	
	var concubines = mission_manager.concubines
	if concubines.is_empty():
		return
	
	var concubine_ids = concubines.keys()
	if current_concubine_detail_index >= concubine_ids.size():
		current_concubine_detail_index = 0
	
	var cariye_id = concubine_ids[current_concubine_detail_index]
	var cariye = concubines[cariye_id]
	
	# Temel bilgileri güncelle
	update_basic_info_panel(cariye)
	
	# Yetenekleri güncelle
	update_skills_panel(cariye)
	
	# Görev geçmişini güncelle
	update_concubine_mission_history(cariye)
	
	# Başarıları güncelle
	update_achievements_panel(cariye)

# Temel bilgiler panelini güncelle
func update_basic_info_panel(cariye: Concubine):
	var basic_info_content = get_node_or_null("ConcubineDetailsPage/ConcubineContent/ConcubineDetailsPanel/ConcubineDetailsScroll/ConcubineDetailsContent/BasicInfoPanel/BasicInfoVBox/BasicInfoContent")
	if not basic_info_content:
		return
	
	var info_text = "İsim: %s\n" % cariye.name
	info_text += "Seviye: %d (%d/%d XP)\n" % [cariye.level, cariye.experience, cariye.max_experience]
	info_text += "Durum: %s\n" % cariye.get_status_name()
	info_text += "Sağlık: %d/%d\n" % [cariye.health, cariye.max_health]
	info_text += "Moral: %d/%d" % [cariye.moral, cariye.max_moral]
	
	basic_info_content.text = info_text

# Yetenekler panelini güncelle
func update_skills_panel(cariye: Concubine):
	var skills_content = get_node_or_null("ConcubineDetailsPage/ConcubineContent/ConcubineDetailsPanel/ConcubineDetailsScroll/ConcubineDetailsContent/SkillsPanel/SkillsVBox/SkillsContent")
	if not skills_content:
		return
	
	var skills_text = "🗡️ Savaş: %d/100\n" % cariye.get_skill_level(Concubine.Skill.SAVAŞ)
	skills_text += "🤝 Diplomasi: %d/100\n" % cariye.get_skill_level(Concubine.Skill.DİPLOMASİ)
	skills_text += "💰 Ticaret: %d/100\n" % cariye.get_skill_level(Concubine.Skill.TİCARET)
	skills_text += "📋 Bürokrasi: %d/100\n" % cariye.get_skill_level(Concubine.Skill.BÜROKRASİ)
	skills_text += "🔍 Keşif: %d/100" % cariye.get_skill_level(Concubine.Skill.KEŞİF)
	
	skills_content.text = skills_text

# Cariye görev geçmişini güncelle
func update_concubine_mission_history(cariye: Concubine):
	var mission_history_content = get_node_or_null("ConcubineDetailsPage/ConcubineContent/ConcubineDetailsPanel/ConcubineDetailsScroll/ConcubineDetailsContent/MissionHistoryPanel/MissionHistoryVBox/MissionHistoryContent")
	if not mission_history_content:
		return
	
	var completed_count = cariye.completed_missions.size()
	var failed_count = cariye.failed_missions.size()
	var total_count = completed_count + failed_count
	var success_rate = 0.0
	if total_count > 0:
		success_rate = (float(completed_count) / float(total_count)) * 100.0
	
	var history_text = "✅ Tamamlanan: %d görev\n" % completed_count
	history_text += "❌ Başarısız: %d görev\n" % failed_count
	history_text += "📊 Başarı Oranı: %.1f%%\n" % success_rate
	history_text += "🏆 Toplam Deneyim: %d XP" % cariye.total_experience_gained
	
	mission_history_content.text = history_text

# Başarılar panelini güncelle
func update_achievements_panel(cariye: Concubine):
	var achievements_content = get_node_or_null("ConcubineDetailsPage/ConcubineContent/ConcubineDetailsPanel/ConcubineDetailsScroll/ConcubineDetailsContent/AchievementsPanel/AchievementsVBox/AchievementsContent")
	if not achievements_content:
		return
	
	var achievements_text = ""
	if cariye.special_achievements.is_empty():
		achievements_text = "Henüz özel başarı yok"
	else:
		for achievement in cariye.special_achievements:
			achievements_text += "🏆 %s\n" % achievement
	
	achievements_content.text = achievements_text

# Aktif görevleri kart olarak güncelle
func update_active_missions_cards():
	if not active_missions_list:
		print("⚠️ update_active_missions_cards: active_missions_list is null!")
		return
	clear_list(active_missions_list)
	# Kartlar arası boşluk
	active_missions_list.add_theme_constant_override("separation", 10)
	
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

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

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
	if page_dot6:
		page_dot6.modulate = Color(0.5, 0.5, 0.5, 1)
	
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
		PageType.TRADE:
			if page_dot6:
				page_dot6.modulate = Color(1, 1, 1, 1)

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
	
	print("📰 Haber Merkezi güncelleniyor...")
	# Kuyruktan çiz: önce temizle
	var village_list = get_node_or_null("NewsCenterPage/NewsContent/VillageNewsPanel/VillageNewsScroll/VillageNewsList")
	var world_list = get_node_or_null("NewsCenterPage/NewsContent/WorldNewsPanel/WorldNewsScroll/WorldNewsList")
	if village_list:
		for c in village_list.get_children():
			c.queue_free()
		for n in news_queue_village:
			village_list.add_child(create_news_card(n))
	if world_list:
		for c in world_list.get_children():
			c.queue_free()
		for n in news_queue_world:
			world_list.add_child(create_news_card(n))
	# Rastgele olay paneli şimdilik korunuyor (placeholder)
	update_random_events()
	_news_refresh_selection_visual()

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
# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

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

# Bu fonksiyon zaten yukarıda tanımlanmış, duplicate kaldırıldı

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

# Mission Center menüsünü aç
func open_menu():
	print("🎯 Mission Center açılıyor...")
	visible = true
	# Fallback: Global pause (oyuncu ve düşmanlar tamamen donar)
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	if has_node("."):
		for child in get_children():
			if child is Node:
				child.process_mode = Node.PROCESS_MODE_ALWAYS
	# VillageManager referansını tazele ve idle sayısını logla
	village_manager = get_node_or_null("/root/VillageManager")
	if village_manager:
		print("[Assignment] idle_workers:", int(village_manager.idle_workers))
	# Test sahnelerinde worker kayıtlarını garantile
	_ensure_workers_registered()
	find_and_lock_player()
	# Ek kilit: player süreçlerini tamamen kapat
	if player and is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_DISABLED
	# Not: input tüketimi `_input` içinde yapılır
	# Sayfayı doğru başlat ve UI'yı hemen doldur
	show_page(PageType.MISSIONS)
	await get_tree().process_frame
	update_missions_ui()
	update_active_missions_cards()
	update_available_missions_cards()

# Mission Center menüsünü kapat
func close_menu():
	print("🎯 Mission Center kapanıyor...")
	visible = false
	unlock_player()
	# Fallback pause kapat
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_INHERIT
	if has_node("."):
		for child in get_children():
			if child is Node:
				child.process_mode = Node.PROCESS_MODE_INHERIT
	# Player process modunu geri al
	if player and is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_INHERIT
	# Input serbest
	# (Gerekirse burada handled flag'ini temizlemeye gerek yok, bir frame sonra sıfırlanır)
