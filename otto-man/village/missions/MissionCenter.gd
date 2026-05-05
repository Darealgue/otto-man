extends CanvasLayer

var _assign_lr_cooldown_ms: int = 180 # Sol/Sağ atama cooldown (ms)
var _assign_lr_last_ms: int = 0

# Sayfa türleri
enum PageType { MISSIONS, ASSIGNMENT, CONSTRUCTION, NEWS, CONCUBINE_DETAILS, TRADE, DIPLOMACY }

# İnşaat menüsü için enum'lar
enum ConstructionAction { BUILD, UPGRADE, DEMOLISH, INFO }
enum BuildingCategory { PRODUCTION, LIFE, MILITARY, DECORATION }

# Menü durumları (PlayStation mantığı)
enum MenuState { İŞLEM_SEÇİMİ, KATEGORİ_SEÇİMİ, BİNA_SEÇİMİ }

# Atama sayfası için menü durumları
enum AssignmentMenuState { BİNA_LISTESİ, BİNA_DETAYI, ASKER_EKİPMAN }

# Görevler sayfası için menü durumları
enum MissionMenuState { GÖREV_LISTESİ, CARİYE_SEÇİMİ, ASKER_SEÇİMİ, GÖREV_DETAYI, GÖREV_GEÇMİŞİ, GEÇMİŞ_DETAYI, GÖREV_ZİNCİRLERİ }

# Mevcut sayfa
var current_page: PageType = PageType.MISSIONS

# İnşaat seçimleri
var current_construction_action: int = ConstructionAction.BUILD
var current_building_category: int = BuildingCategory.PRODUCTION
var current_building_index: int = 0  # Bina seçimi için index

# Atama seçimleri
var current_assignment_building_index: int = 0 # Atama sayfasında bina seçimi için index
var current_assignment_menu_state: AssignmentMenuState = AssignmentMenuState.BİNA_LISTESİ # Atama sayfasındaki menü durumu
var current_soldier_index: int = 0 # Asker ekipman atama sayfasında asker seçimi için index
var current_equipment_action: int = 0 # 0: weapon, 1: armor (sol/sağ ile değiştirilebilir)

# Kışla ekipman pop-up menüsü
var barracks_equipment_popup: Panel = null
var barracks_equipment_popup_label: Label = null
var barracks_equipment_popup_active: bool = false
var barracks_equipment_selected_weapons: int = 0 # Dağıtılacak silah sayısı
var barracks_equipment_selected_armors: int = 0 # Dağıtılacak zırh sayısı
var barracks_equipment_selected_row: int = 0 # 0: weapon, 1: armor (yukarı/aşağı ile satır seçimi)

# Görevler seçimleri
var current_mission_index: int = 0 # Görevler sayfasında görev seçimi için index
var current_mission_menu_state: MissionMenuState = MissionMenuState.GÖREV_LISTESİ # Görevler sayfasındaki menü durumu
var current_cariye_index: int = 0 # Cariye seçimi için index
var current_soldier_count: int = 0 # Raid görevleri için seçilen asker sayısı
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

# Cariye rol atama pop-up'ı
var current_concubine_role_popup_open: bool = false
var concubine_role_popup: Panel = null
var concubine_role_popup_label: Label = null
var current_concubine_role_selection: int = 0 # Concubine.Role enum degeri (NONE..TIBBIYECI)

# Görev sonucu gösterimi
var showing_mission_result: bool = false

# Haber kuyrukları - MissionCenter'da doğrudan sakla
var village_news: Array[Dictionary] = []
var world_news: Array[Dictionary] = []
var news_queue_village: Array[Dictionary] = []
var news_queue_world: Array[Dictionary] = []
var mission_result_timer: float = 0.0
var mission_result_duration: float = 5.0

# Haber filtre çubuğu (dinamik oluşturulacak)
var news_filter_bar: HBoxContainer = null
var filter_village_label: Label = null
var filter_world_label: Label = null
 
# Alt kategori filtreleri
var news_subcategory_bar: HBoxContainer = null
var subcategory_labels: Array[Label] = []
var current_subcategory: String = "all"  # all, critical, info, success, warning

# Portre instance'ları için görünmeyen container (sahnenin dışında)
var portrait_instances_container: Node2D = null
var portrait_instances: Dictionary = {}  # concubine_id -> concubine_instance

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
var diplomacy_page: Control = null
@onready var page_label: Label = $PageLabel
@onready var page_indicator: Control = $PageIndicator

# Sayfa göstergesi referansları
@onready var page_dot1: Panel = $PageIndicator/PageDot1
@onready var page_dot2: Panel = $PageIndicator/PageDot2
@onready var page_dot3: Panel = $PageIndicator/PageDot3
@onready var page_dot4: Panel = $PageIndicator/PageDot4
@onready var page_dot5: Panel = $PageIndicator/PageDot5
@onready var page_dot6: Panel = $PageIndicator/PageDot6
var page_dot7: Panel = null

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

# Seçili görev özet şeridi (kodla eklenir; kart listesiyle aynı kaynak)
var mission_detail_panel: PanelContainer = null
var mission_detail_label: Label = null

# Sayfa isimleri
var page_names: Array[String] = ["GÖREVLER", "ATAMALAR", "İNŞAAT", "HABERLER", "CARİYELER", "TİCARET", "DİPLOMASİ"]

# Action ve Category isimleri
var action_names: Array[String] = ["YAP", "YÜKSELT", "YIK", "BİLGİ"]
var category_names: Array[String] = ["ÜRETİM", "YAŞAM", "ORDU", "DEKORASYON"]

# İnşaat sayfası için görsel progress bar (dinamik)
var upgrade_progress_bar: ProgressBar = null
 
# --- Diplomasi Paneli (hafif) ---
var diplomacy_panel: VBoxContainer = null
var diplomacy_actions_container: HBoxContainer = null
var diplomacy_info_label: Label = null
var diplomacy_list: VBoxContainer = null
var diplomacy_action_label: Label = null
var current_diplomacy_index: int = 0
var current_diplomacy_action: int = 0 # 0:gift, 1:threat, 2:trade_agreement, 3:passage
var diplomacy_manager: Node = null

# Bina türleri kategorilere göre (gerçek bina türleri)
var building_categories: Dictionary = {
	BuildingCategory.PRODUCTION: [
		"Kuyu",
		"Avcı",
		"Oduncu",
		"Taş Madeni",
		"Kerestehane",
		"Tuğla Ocağı",
		"Fırın",
		"Dokuma Tezgahı",
		"Terzi",
		"Demirci",
		"Silahçı",
		"Zırh Ustası",
		"Çayhane",
		"Sabuncu",
		"Şifacı"
	],
	BuildingCategory.LIFE: ["Ev", "Depo"],
	BuildingCategory.MILITARY: ["Kışla", "Kale", "Kule"], # Kışla eklendi
	BuildingCategory.DECORATION: ["Çeşme", "Bahçe"] # Gelecekte eklenecek
}

# Bina sahne yolları (gerçek dosya yolları)
var building_scene_paths: Dictionary = {
	"Kuyu": "res://village/buildings/Well.tscn",
	"Avcı": "res://village/buildings/HunterGathererHut.tscn",
	"Oduncu": "res://village/buildings/WoodcutterCamp.tscn",
	"Taş Madeni": "res://village/buildings/StoneMine.tscn",
	"Kerestehane": "res://village/buildings/Sawmill.tscn",
	"Tuğla Ocağı": "res://village/buildings/Brickworks.tscn",
	"Fırın": "res://village/buildings/Bakery.tscn",
	"Dokuma Tezgahı": "res://village/buildings/Weaver.tscn",
	"Ev": "res://village/buildings/House.tscn",
	"Depo": "res://village/buildings/StorageBuilding.tscn",
	"Demirci": "res://village/buildings/Blacksmith.tscn",
	"Silahçı": "res://village/buildings/Gunsmith.tscn",
	"Zırh Ustası": "res://village/buildings/Armorer.tscn",
	"Terzi": "res://village/buildings/Tailor.tscn",
	"Çayhane": "res://village/buildings/TeaHouse.tscn",
	"Sabuncu": "res://village/buildings/SoapMaker.tscn",
	"Şifacı": "res://village/buildings/Herbalist.tscn",
	"Kışla": "res://village/buildings/Barracks.tscn"
}

var building_recipe_texts: Dictionary = {
	"Kerestehane": "Girdi: Odun + Su ⇒ Kereste",
	"Tuğla Ocağı": "Girdi: Taş + Su ⇒ Tuğla",
	"Fırın": "Girdi: Yiyecek + Su ⇒ Ekmek",
	"Dokuma Tezgahı": "Girdi: Yiyecek + Su ⇒ Kumaş",
	"Terzi": "Girdi: Kumaş x2 + Su ⇒ Giyim",
	"Demirci": "Girdi: Taş + Odun ⇒ Metal",
	"Silahçı": "Girdi: Metal + Odun + Su ⇒ Silah",
	"Zırh Ustası": "Girdi: Metal x2 + Su ⇒ Zırh",
	"Çayhane": "Girdi: Yiyecek + Su ⇒ Çay",
	"Sabuncu": "Girdi: Yiyecek + Su x2 ⇒ Sabun",
	"Şifacı": "Girdi: Yiyecek + Su ⇒ İlaç"
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
var current_trade_index: int = 0  # Gelen tüccarlar için
var current_trader_mission_index: int = 0  # Tüccar cariye görevleri için
var active_traders: Array = []  # Aktif tüccarlar listesi

# Tüccar satın alma pop-up
var trader_buy_popup: Panel = null
var trader_buy_grid: GridContainer = null
var current_trader_buy_index: int = 0
var selected_trader: Dictionary = {}
var trader_buy_popup_open: bool = false
const TRADER_BUY_GRID_COLUMNS: int = 4
var current_focus_panel: String = "active" # "active" or "offers"

# Tüccar cariye görev pop-up
var trader_mission_popup: Panel = null
var trader_mission_popup_open: bool = false
var trader_mission_step: int = 0  # 0: köy seçimi, 1: asker sayısı, 2: mal seçimi
var trader_mission_selected_route_index: int = 0
var trader_mission_selected_route: Dictionary = {}
var trader_mission_soldier_count: int = 0
var trader_mission_selected_products: Dictionary = {}  # {resource: quantity}
var trader_mission_current_product_index: int = 0
var trader_mission_selected_concubine: Concubine = null
const TRADER_MISSION_PRODUCT_COLUMNS: int = 4
const TRADEABLE_RESOURCES: Array[String] = ["wood", "stone", "food", "water"]
# Miktar alt pop-up (mal seçiminde A ile açılır)
var trader_mission_quantity_popup_open: bool = false
var trader_mission_quantity_editing_resource: String = ""
var trader_mission_quantity_temp_value: int = 0
var trader_mission_quantity_panel: Panel = null
var trader_mission_quantity_label: Label = null

# Haber merkezi navigasyonu durumu
var news_focus: String = "village" # "village" | "world" | "random"
var current_news_index_village: int = 0
var current_news_index_world: int = 0
var current_news_index_random: int = 0
var news_detail_overlay: Panel = null

# Düzleştirilmiş bina listesi (Kategorisiz grid görünümü için)
var all_buildings_flat: Array = []
const GRID_COLUMNS: int = 6

# Haber kuyrukları artık MissionManager'da tutuluyor

func _ready():
	print("=== MISSION CENTER DEBUG ===")
	
	# MissionManager referansını al
	mission_manager = get_node("/root/MissionManager")
	if not mission_manager:
		print("❌ MissionManager bulunamadı!")
		return
	
	print("✅ MissionManager bulundu")
	# VillageManager referansını al (gerekli olacağı için başta çek)
	village_manager = get_node_or_null("/root/VillageManager")
	if not village_manager:
		printerr("MissionCenter: VillageManager not found at _ready; will lazy-fetch when needed.")
	elif village_manager:
		if village_manager.has_signal("village_data_changed") and not village_manager.village_data_changed.is_connected(_on_village_manager_data_changed_construction):
			village_manager.village_data_changed.connect(_on_village_manager_data_changed_construction)
		if village_manager.has_signal("construction_started") and not village_manager.construction_started.is_connected(_on_village_manager_data_changed_construction):
			village_manager.construction_started.connect(_on_village_manager_data_changed_construction)
		if village_manager.has_signal("construction_completed") and not village_manager.construction_completed.is_connected(_on_village_manager_data_changed_construction):
			village_manager.construction_completed.connect(_on_village_manager_data_changed_construction)
	
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
		if mission_manager.has_signal("active_traders_updated"):
			mission_manager.active_traders_updated.connect(_on_active_traders_updated)
	if mission_manager.has_signal("mission_chain_progressed"):
		mission_manager.mission_chain_progressed.connect(_on_chain_progressed)
	if mission_manager.has_signal("mission_list_changed"):
		mission_manager.mission_list_changed.connect(_on_mission_list_changed)

	# WorldManager sinyalleri (lazy load destekli)
	var wm = _get_world_manager()
	if wm and wm.has_signal("relation_changed"):
		wm.relation_changed.connect(_on_relation_changed)
	if wm and wm.has_signal("world_event_started"):
		wm.world_event_started.connect(_on_world_event_started)
	
	# Portre instance'ları için görünmeyen container oluştur
	_setup_portrait_instances()
	
	print("✅ MissionManager sinyalleri bağlandı")
	
	# MissionCenter'ı group'a ekle
	add_to_group("mission_center")
	print("✅ MissionCenter group'a eklendi")

	# Başlangıçta sayfa göstergelerini sıfırla
	update_page_indicator()

	# Unread rozeti başlat
	_update_unread_badge()
	# Haber filtre barı kurulumu
	_ensure_news_filter_bar()
	
	# Bina listesini düzleştir
	_flatten_buildings_list()
	_ensure_news_subcategory_bar()

	# Diplomasi panelini oluştur (MissionsPage altında)
	# Diplomasi için ayrı bir sayfa kullan (TradePage yerine)
	var existing_diplomacy = get_node_or_null("DiplomacyPage")
	if existing_diplomacy == null:
		diplomacy_page = Control.new()
		diplomacy_page.name = "DiplomacyPage"
		add_child(diplomacy_page)
		diplomacy_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Başlangıçta gizli
		diplomacy_page.visible = false
	else:
		diplomacy_page = existing_diplomacy
	_ensure_diplomacy_panel()

	# DiplomasiManager hazırla
	diplomacy_manager = _get_diplomacy_manager()

	# PageIndicator'da gerekli nokta sayısını garanti et (sayfa sayısı kadar)
	_ensure_page_indicator_dots(page_names.size())

func _ensure_page_indicator_dots(target_count: int) -> void:
	if page_indicator == null:
		return
	# Mevcut dot sayısını say
	var existing_count := 0
	for i in range(1, 21): # güvenli üst sınır
		var n = page_indicator.get_node_or_null("PageDot%d" % i)
		if n != null:
			existing_count = i
		else:
			break
	# Eksikleri oluştur
	var base_dot: Panel = page_dot6 if page_dot6 else page_dot1
	for i in range(existing_count + 1, target_count + 1):
		var dot := Panel.new()
		dot.name = "PageDot%d" % i
		if base_dot:
			dot.custom_minimum_size = base_dot.custom_minimum_size
			var sb = base_dot.get_theme_stylebox("panel")
			if sb:
				dot.add_theme_stylebox_override("panel", sb.duplicate())
		else:
			var sbf := StyleBoxFlat.new()
			sbf.bg_color = Color(1,1,1,0.6)
			sbf.corner_radius_top_left = 4
			sbf.corner_radius_top_right = 4
			sbf.corner_radius_bottom_left = 4
			sbf.corner_radius_bottom_right = 4
			dot.add_theme_stylebox_override("panel", sbf)
		
		# Numara Etiketi Ekle (Eksik olan kısım)
		var lbl = Label.new()
		lbl.name = "PageDot%dLabel" % i
		lbl.text = str(i)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dot.add_child(lbl)
		
		# Varsayılan olarak sönük (gri) başlat
		dot.modulate = Color(0.5, 0.5, 0.5, 1)
		
		page_indicator.add_child(dot)
		if i == 7:
			page_dot7 = dot

func _update_unread_badge():
	var mm = get_node_or_null("/root/MissionManager")
	if not mm or not mm.has_method("get_unread_counts"):
		return
	# Kullanıcı isteği üzerine renk değişikliği iptal edildi.
	# Sadece aktif sayfa kontrolü ile standart renkler kullanılacak.
	
	var is_active = (current_page == PageType.NEWS)
	if page_dot4:
		page_dot4.modulate = Color(1, 1, 1, 1) if is_active else Color(0.5, 0.5, 0.5, 1)

func is_active_page(page_type: int) -> bool:
	return current_page == page_type

func _ensure_news_filter_bar():
	if current_page != PageType.NEWS:
		return
	var parent: VBoxContainer = get_node_or_null("NewsCenterPage")
	if not parent:
		return
	# İlk kez oluştur
	if news_filter_bar == null:
		news_filter_bar = HBoxContainer.new()
		news_filter_bar.name = "NewsFilterBar"
		news_filter_bar.add_theme_constant_override("separation", 16)
		parent.add_child(news_filter_bar)
		news_filter_bar.move_child(news_filter_bar, 1) # Header'dan hemen sonra
		filter_village_label = Label.new()
		filter_village_label.text = "🏘️ KÖY"
		# filter_village_label.add_theme_font_size_override("font_size", 12)
		news_filter_bar.add_child(filter_village_label)
		filter_world_label = Label.new()
		filter_world_label.text = "🌍 DÜNYA"
		# filter_world_label.add_theme_font_size_override("font_size", 12)
		news_filter_bar.add_child(filter_world_label)

func _ensure_news_subcategory_bar():
	if current_page != PageType.NEWS:
		return
	var parent: VBoxContainer = get_node_or_null("NewsCenterPage")
	if not parent:
		return
	# İlk kez oluştur
	if news_subcategory_bar == null:
		news_subcategory_bar = HBoxContainer.new()
		news_subcategory_bar.name = "NewsSubcategoryBar"
		news_subcategory_bar.add_theme_constant_override("separation", 12)
		parent.add_child(news_subcategory_bar)
		# Filter bar'ın hemen altına yerleştir (varsayılan ekleme sırasıyla uyumlu)
		var label_all = Label.new(); label_all.text = "TÜMÜ (Y)"; 
		# label_all.add_theme_font_size_override("font_size", 10); 
		label_all.set_meta("category", "all"); news_subcategory_bar.add_child(label_all); subcategory_labels.append(label_all)
		var label_crit = Label.new(); label_crit.text = "🚨 KRİTİK"; 
		# label_crit.add_theme_font_size_override("font_size", 10); 
		label_crit.set_meta("category", "critical"); news_subcategory_bar.add_child(label_crit); subcategory_labels.append(label_crit)
		var label_info = Label.new(); label_info.text = "ℹ️ BİLGİ"; 
		# label_info.add_theme_font_size_override("font_size", 10); 
		label_info.set_meta("category", "info"); news_subcategory_bar.add_child(label_info); subcategory_labels.append(label_info)
		var label_succ = Label.new(); label_succ.text = "✅ BAŞARI"; 
		# label_succ.add_theme_font_size_override("font_size", 10); 
		label_succ.set_meta("category", "success"); news_subcategory_bar.add_child(label_succ); subcategory_labels.append(label_succ)
		var label_warn = Label.new(); label_warn.text = "⚠️ UYARI"; 
		# label_warn.add_theme_font_size_override("font_size", 10); 
		label_warn.set_meta("category", "warning"); news_subcategory_bar.add_child(label_warn); subcategory_labels.append(label_warn)

func _update_news_subcategory_bar_visual():
	if news_subcategory_bar == null:
		return
	for label in subcategory_labels:
		if label and label.has_meta("category"):
			var category = label.get_meta("category")
			var is_selected = (category == current_subcategory)
			label.add_theme_color_override("font_color", Color(1,1,1, 1.0 if is_selected else 0.5))
			if is_selected:
				label.add_theme_color_override("font_color", Color(1,1,0.5,1))

func _news_passes_subcategory_filter(n: Dictionary) -> bool:
	match current_subcategory:
		"all":
			return true
		"critical":
			return n.get("category", "") in ["Uyarı", "Dünya", "Kritik"]
		"info":
			return n.get("category", "") in ["Bilgi"]
		"success":
			return n.get("category", "") in ["Başarı"]
		"warning":
			return n.get("category", "") in ["Uyarı"]
		_:
			return true

func _update_news_filter_bar_visual():
	if news_filter_bar == null:
		return
	if filter_village_label:
		filter_village_label.add_theme_color_override("font_color", Color(1,1,1, 1.0 if news_focus == "village" else 0.6))
	if filter_world_label:
		filter_world_label.add_theme_color_override("font_color", Color(1,1,1, 1.0 if news_focus == "world" else 0.6))
	
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

func _on_mission_list_changed() -> void:
	# Yeni görev eklendi (örn. Haydut Temizliği); görev listesini yenile
	if current_page == PageType.MISSIONS:
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

# İnşaat sayfasında D-pad navigasyonu (PlayStation mantığı)
func handle_construction_navigation():
	# İnşaat sayfasında değilse çık
	if current_page != PageType.CONSTRUCTION:
		return

	# Yeni akış: doğrudan kategori+bina listesi ekranı
	current_menu_state = MenuState.BİNA_SEÇİMİ
	_debug_construction("handle_construction_navigation -> init")
	handle_building_selection()

# _input(event) tarafından çağrılır
func _flatten_buildings_list():
	all_buildings_flat.clear()
	# Kategorileri sırayla gezerek listeyi oluştur
	for buildings in building_categories.values():
		all_buildings_flat.append_array(buildings)
	print("[MissionCenter] Binalar düzleştirildi. Toplam: ", all_buildings_flat.size())

func handle_construction_input(event):
	if current_page != PageType.CONSTRUCTION:
		return
	
	# D-Pad debounce kontrolü
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		if dpad_debounce_timer > 0:
			return
		dpad_debounce_timer = dpad_debounce_delay
	
	current_menu_state = MenuState.BİNA_SEÇİMİ
	
	# Yıkım onayı
	if _demolish_confirm_open:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_forward"):
			_debug_construction("Confirm DEMOLISH -> YES")
			_close_demolish_confirm_popup()
			_demolish_selected_building()
			update_construction_ui()
			return
		elif event.is_action_pressed("ui_cancel"):
			_debug_construction("Confirm DEMOLISH -> CANCEL")
			_close_demolish_confirm_popup()
			update_construction_ui()
			return

	if all_buildings_flat.is_empty():
		return

	# Grid Navigasyonu
	var total_items = all_buildings_flat.size()
	
	if event.is_action_pressed("ui_left"):
		current_building_index = (current_building_index - 1) % total_items
		if current_building_index < 0: current_building_index = total_items - 1
		update_construction_ui()
		return
	elif event.is_action_pressed("ui_right"):
		current_building_index = (current_building_index + 1) % total_items
		update_construction_ui()
		return
	elif event.is_action_pressed("ui_up"):
		var new_index = current_building_index - GRID_COLUMNS
		if new_index >= 0:
			current_building_index = new_index
		update_construction_ui()
		return
	elif event.is_action_pressed("ui_down"):
		var new_index = current_building_index + GRID_COLUMNS
		if new_index < total_items:
			current_building_index = new_index
		update_construction_ui()
		return
		
	# A: İnşa/Yükselt
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_forward"):
		_build_or_upgrade_selected()
		update_construction_ui()
		return
	# Y: Bilgi
	if event.is_action_pressed("ui_select"):
		_open_building_info_popup()
		return
	# X: Yık onayı
	if event.is_action_pressed("attack"):
		_open_demolish_confirm_popup()
		update_construction_ui()
		return

# Global input yakalama: İnşaat sayfasında yön ve tuşları doğrudan işle
func _unhandled_input(event):
	if current_page != PageType.CONSTRUCTION:
		return
	# D-Pad debounce kontrolü (just_pressed yönler)
	if InputManager.is_ui_left_just_pressed() or InputManager.is_ui_right_just_pressed() or InputManager.is_ui_up_just_pressed() or InputManager.is_ui_down_just_pressed():
		if dpad_debounce_timer > 0:
			return
		dpad_debounce_timer = dpad_debounce_delay
	# Önce açık bir yıkım onayı varsa onu işle (just_pressed ile)
	if _demolish_confirm_open:
		if InputManager.is_ui_accept_just_pressed():
			get_viewport().set_input_as_handled()
			_debug_construction("Confirm DEMOLISH -> YES")
			_close_demolish_confirm_popup()
			_demolish_selected_building()
			update_construction_ui()
			return
		elif InputManager.is_ui_cancel_just_pressed():
			get_viewport().set_input_as_handled()
			_debug_construction("Confirm DEMOLISH -> CANCEL")
			_close_demolish_confirm_popup()
			update_construction_ui()
			return
	# Grid Navigasyonu (Düzleştirilmiş liste)
	if all_buildings_flat.is_empty():
		return
	
	var total_items = all_buildings_flat.size()

	# Sol/Sağ
	if InputManager.is_ui_left_just_pressed():
		get_viewport().set_input_as_handled()
		current_building_index = (current_building_index - 1) % total_items
		if current_building_index < 0: current_building_index = total_items - 1
		update_construction_ui()
		return
	if InputManager.is_ui_right_just_pressed():
		get_viewport().set_input_as_handled()
		current_building_index = (current_building_index + 1) % total_items
		update_construction_ui()
		return
		
	# Yukarı/Aşağı
	if InputManager.is_ui_up_just_pressed():
		get_viewport().set_input_as_handled()
		var new_index = current_building_index - GRID_COLUMNS
		if new_index >= 0:
			current_building_index = new_index
		update_construction_ui()
		return
	if InputManager.is_ui_down_just_pressed():
		get_viewport().set_input_as_handled()
		var new_index = current_building_index + GRID_COLUMNS
		if new_index < total_items:
			current_building_index = new_index
		update_construction_ui()
		return
	# A: İnşa / Yükselt
	if InputManager.is_ui_accept_just_pressed():
		get_viewport().set_input_as_handled()
		_debug_construction("A -> build_or_upgrade")
		_build_or_upgrade_selected()
		update_construction_ui()
		return
	# Y: Bilgi
	if InputManager.is_ui_select_just_pressed():
		get_viewport().set_input_as_handled()
		_debug_construction("Y -> info_popup")
		_open_building_info_popup()
		return
	# X: Yık
	if InputManager.is_attack_just_pressed():
		get_viewport().set_input_as_handled()
		_debug_construction("X -> demolish_confirm_open")
		_open_demolish_confirm_popup()
		update_construction_ui()
		return
	# B: Info popup kapat
	if InputManager.is_ui_cancel_just_pressed():
		if _construction_info_popup:
			get_viewport().set_input_as_handled()
			_debug_construction("B -> close_info_popup")
			_close_building_info_popup()
			update_construction_ui()
			return

# İşlem seçimi seviyesi (YAP/YÜKSELT/YIK/BİLGİ)
func handle_action_selection():
	# Sol/Sağ D-pad: İşlem seçimi
	if InputManager.is_ui_left_just_pressed():
		print("=== SOL D-PAD: İşlem değiştiriliyor ===")
		current_construction_action = (current_construction_action - 1) % action_names.size()
		if current_construction_action < 0:
			current_construction_action = action_names.size() - 1
		print("Yeni işlem: ", action_names[current_construction_action])
		update_construction_ui()

	elif InputManager.is_ui_right_just_pressed():
		print("=== SAĞ D-PAD: İşlem değiştiriliyor ===")
		current_construction_action = (current_construction_action + 1) % action_names.size()
		print("Yeni işlem: ", action_names[current_construction_action])
		update_construction_ui()

	# A tuşu (ui_forward): İşlemi seç, kategorilere geç
	elif InputManager.is_ui_accept_just_pressed():
		print("=== A TUŞU: İşlem seçildi, kategorilere geçiliyor ===")
		current_menu_state = MenuState.KATEGORİ_SEÇİMİ
		update_construction_ui()

# Kategori seçimi seviyesi (ÜRETİM/YAŞAM/ORDU/DEKORASYON)
func handle_category_selection():
	# Sol/Sağ D-pad: Kategori seçimi
	if InputManager.is_ui_left_just_pressed():
		print("=== SOL D-PAD: Kategori değiştiriliyor ===")
		current_building_category = (current_building_category - 1) % category_names.size()
		if current_building_category < 0:
			current_building_category = category_names.size() - 1
		print("Yeni kategori: ", category_names[current_building_category])
		update_construction_ui()

	elif InputManager.is_ui_right_just_pressed():
		print("=== SAĞ D-PAD: Kategori değiştiriliyor ===")
		current_building_category = (current_building_category + 1) % category_names.size()
		print("Yeni kategori: ", category_names[current_building_category])
		update_construction_ui()

	# A tuşu (ui_forward): Kategoriyi seç, binalara geç
	elif InputManager.is_ui_accept_just_pressed():
		print("=== A TUŞU: Kategori seçildi, binalara geçiliyor ===")
		current_menu_state = MenuState.BİNA_SEÇİMİ
		update_construction_ui()

	# B tuşu: Geri dön, işlem seçimine
	elif InputManager.is_ui_cancel_just_pressed():
		print("=== B TUŞU: Geri dönülüyor, işlem seçimine ===")
		current_menu_state = MenuState.İŞLEM_SEÇİMİ
		update_construction_ui()

# Bina seçimi seviyesi
func handle_building_selection():
	var buildings = building_categories.get(current_building_category, [])
	if buildings.is_empty():
		print("Bu kategoride bina yok!")
		return

	# Yıkım onayı açıksa, yalnızca A/B işle
	if _demolish_confirm_open:
		if InputManager.is_ui_accept_just_pressed():
			_close_demolish_confirm_popup()
			_demolish_selected_building()
			update_construction_ui()
			return
		elif InputManager.is_ui_cancel_just_pressed():
			_close_demolish_confirm_popup()
			update_construction_ui()
			return
	
	# Sol/Sağ: Kategori değiştir
	if InputManager.is_ui_left_just_pressed():
		current_building_category = (current_building_category - 1) % category_names.size()
		if current_building_category < 0:
			current_building_category = category_names.size() - 1
		current_building_index = 0
		update_construction_ui()
		return
	elif InputManager.is_ui_right_just_pressed():
		current_building_category = (current_building_category + 1) % category_names.size()
		current_building_index = 0
		update_construction_ui()
		return

	# Yukarı/Aşağı: Bina seçimi
	if InputManager.is_ui_up_just_pressed():
		current_building_index = (current_building_index - 1) % buildings.size()
		if current_building_index < 0:
			current_building_index = buildings.size() - 1
		update_construction_ui()
		return
	elif InputManager.is_ui_down_just_pressed():
		current_building_index = (current_building_index + 1) % buildings.size()
		update_construction_ui()
		return

	# A: İnşa / Yükselt
	if InputManager.is_ui_accept_just_pressed():
		_build_or_upgrade_selected()
		update_construction_ui()
		return

	# Y: Bilgi
	if InputManager.is_ui_select_just_pressed():
		_open_building_info_popup()
		return

	# X: Yık (önce onay penceresi)
	if InputManager.is_attack_just_pressed():
		_open_demolish_confirm_popup()
		update_construction_ui()
		return

func _on_village_manager_data_changed_construction(_a = null, _b = null) -> void:
	if current_page == PageType.CONSTRUCTION:
		update_construction_ui()

func _mc_get_or_create_active_construction_banner_lines() -> VBoxContainer:
	if not construction_page:
		return null
	var wrap := construction_page.get_node_or_null("ActiveConstructionSummary") as PanelContainer
	if wrap == null:
		wrap = PanelContainer.new()
		wrap.name = "ActiveConstructionSummary"
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.12, 0.1, 0.96)
		sb.set_content_margin_all(10)
		wrap.add_theme_stylebox_override("panel", sb)
		var outer := VBoxContainer.new()
		var title := Label.new()
		title.text = "Devam eden şantiyeler"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 12)
		outer.add_child(title)
		var lines := VBoxContainer.new()
		lines.name = "ConstructionLines"
		outer.add_child(lines)
		wrap.add_child(outer)
		var scroll_node := construction_page.get_node_or_null("ConstructionScroll")
		var insert_idx := 2
		if scroll_node:
			insert_idx = scroll_node.get_index()
		construction_page.add_child(wrap)
		construction_page.move_child(wrap, insert_idx)
		return lines
	var outer_node := wrap.get_child(0) as VBoxContainer
	if outer_node == null:
		return null
	return outer_node.get_node_or_null("ConstructionLines") as VBoxContainer

func _mc_refresh_active_construction_banner() -> void:
	var line_host := _mc_get_or_create_active_construction_banner_lines()
	if line_host == null:
		return
	for c in line_host.get_children():
		c.queue_free()
	var vm := get_node_or_null("/root/VillageManager")
	if vm and vm.has_method("get_pending_construction_display_lines"):
		var arr: Array = vm.get_pending_construction_display_lines()
		for line_text in arr:
			var lab := Label.new()
			lab.text = String(line_text)
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lab.add_theme_font_size_override("font_size", 11)
			lab.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
			line_host.add_child(lab)

# İnşaat UI'ını güncelle (PlayStation mantığı)
func update_construction_ui():
	if current_page != PageType.CONSTRUCTION:
		return
	
	_mc_refresh_active_construction_banner()
		
	var action_label = construction_page.get_node_or_null("ActionRow/ActionLabel")
	if action_label:
		action_label.text = "Yön Tuşları: Seçim  |  A: İnşa/Yükselt  |  X: Yık  |  Y: Bilgi"
		
	var construction_grid = construction_page.get_node_or_null("ConstructionScroll/CenterContainer/ConstructionGrid")
	if not construction_grid:
		# Fallback if grid doesn't exist yet (e.g. older tscn loaded)
		return

	# Temizle
	for child in construction_grid.get_children():
		child.queue_free()
		
	# Grid'i doldur
	for i in range(all_buildings_flat.size()):
		var building_name = all_buildings_flat[i]
		var is_selected = (i == current_building_index)
		
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(180, 140)
		
		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		
		# Tema renklerini kullan (dark brown ve gold)
		if is_selected:
			style.bg_color = Color(0.2, 0.18, 0.15, 1.0) # Seçili (hafif açık kahve)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = Color(0.6, 0.5, 0.3, 1) # Gold/Bronz sınır
		else:
			style.bg_color = Color(0.15, 0.13, 0.1, 0.85) # Normal (koyu kahve - ui_panel_style benzeri)
			
		panel.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		panel.add_child(vbox)
		
		var label = Label.new()
		label.text = building_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(label)
		
		# Durum bilgisi (Var mı?)
		var existing = find_existing_buildings(building_name)
		var vm = get_node_or_null("/root/VillageManager")
		var scene_path: String = String(building_scene_paths.get(building_name, ""))
		var status_label = Label.new()
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", 10)
		
		if existing.is_empty():
			var pending := false
			var remaining_min := 0
			if vm and scene_path != "" and vm.has_method("has_pending_construction"):
				pending = bool(vm.has_pending_construction(scene_path))
				if pending and vm.has_method("get_pending_construction_minutes"):
					remaining_min = int(vm.get_pending_construction_minutes(scene_path))
			if pending:
				status_label.text = "İnşa Halinde (%.1fsa)" % [float(remaining_min) / 60.0]
				status_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
			else:
				status_label.text = "İnşa Edilmedi"
				status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		else:
			status_label.text = "Mevcut"
			status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
			
		vbox.add_child(status_label)

		# Maliyet bilgisi
		var reqs: Dictionary = {}
		if vm and scene_path != "" and vm.has_method("get_building_requirements"):
			reqs = vm.get_building_requirements(scene_path)
		var cost_label = Label.new()
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost_label.add_theme_font_size_override("font_size", 10)
		cost_label.text = _mc_format_build_cost(reqs.get("cost", {}))
		cost_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
		vbox.add_child(cost_label)

		var duration_label = Label.new()
		duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		duration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		duration_label.add_theme_font_size_override("font_size", 10)
		if vm and scene_path != "":
			var build_hours := float(vm.get_build_duration_hours(scene_path)) if vm.has_method("get_build_duration_hours") else 1.0
			var upg_hours := build_hours
			if not existing.is_empty() and vm.has_method("get_upgrade_duration_hours_for_building"):
				upg_hours = float(vm.get_upgrade_duration_hours_for_building(existing[0]))
			duration_label.text = "Süre: İnşa %.1fsa | Yükselt %.1fsa" % [build_hours, upg_hours]
		else:
			duration_label.text = "Süre: -"
		duration_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		vbox.add_child(duration_label)

		# Neden inşa edilemedi bilgisi (yalnızca seçili kartta göster)
		if is_selected and existing.is_empty() and vm and scene_path != "":
			var can_build: bool = true
			if vm.has_method("can_meet_requirements"):
				can_build = bool(vm.can_meet_requirements(scene_path))
			if not can_build:
				var missing_label = Label.new()
				missing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				missing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				missing_label.add_theme_font_size_override("font_size", 10)
				missing_label.text = _mc_format_missing_requirements(reqs)
				missing_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
				vbox.add_child(missing_label)
		
		construction_grid.add_child(panel)

func _mc_format_build_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Maliyet: Yok"
	var ordered := []
	if cost.has("gold"):
		ordered.append("gold")
	for key in cost.keys():
		if key == "gold":
			continue
		ordered.append(key)
	var parts := []
	for key in ordered:
		var key_str: String = String(key)
		var amount := int(cost.get(key_str, 0))
		if amount <= 0:
			continue
		parts.append("%s: %d" % [_mc_resource_name(key_str), amount])
	if parts.is_empty():
		return "Maliyet: Yok"
	return "Maliyet: " + ", ".join(parts)

func _mc_format_missing_requirements(requirements: Dictionary) -> String:
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		return "Eksik: -"
	var missing_cost := []
	var cost: Dictionary = requirements.get("cost", {})
	for key in cost.keys():
		var key_str: String = String(key)
		var required := int(cost.get(key_str, 0))
		if required <= 0:
			continue
		var current := int(GlobalPlayerData.gold) if key_str == "gold" else int(vm.get_resource_level(key_str))
		if current < required:
			missing_cost.append("%s %d/%d" % [_mc_resource_name(key_str), current, required])
	var missing_levels := []
	var levels: Dictionary = requirements.get("requires_level", {})
	for key in levels.keys():
		var key_str: String = String(key)
		var req_lvl := int(levels.get(key_str, 0))
		var cur_lvl := int(vm.get_available_resource_level(key_str))
		if cur_lvl < req_lvl:
			missing_levels.append("%s Sv %d/%d" % [_mc_resource_name(key_str), cur_lvl, req_lvl])
	var out := []
	if not missing_cost.is_empty():
		out.append("Eksik maliyet: " + ", ".join(missing_cost))
	if not missing_levels.is_empty():
		out.append("Eksik seviye: " + ", ".join(missing_levels))
	if out.is_empty():
		return "Eksik: -"
	return "\n".join(out)

func _mc_resource_name(resource_key: String) -> String:
	match resource_key:
		"gold": return "Altın"
		"wood": return "Odun"
		"stone": return "Taş"
		"food": return "Yiyecek"
		"water": return "Su"
		"lumber": return "Kereste"
		"brick": return "Tuğla"
		"metal": return "Metal"
		"cloth": return "Kumaş"
		"garment": return "Giysi"
		"bread": return "Ekmek"
		"tea": return "Çay"
		"soap": return "Sabun"
		"medicine": return "İlaç"
		"weapon": return "Silah"
		"armor": return "Zırh"
		_: return resource_key.capitalize()

# Atama bina listesi seçimi
func handle_assignment_building_list_selection(event):
	var all_buildings = get_all_available_buildings()
	if all_buildings.is_empty():
		print("Atanabilir bina yok!")
		return
	
	# Yukarı/Aşağı D-pad: Bina seçimi
	if event.is_action_pressed("ui_up"):
		print("=== YUKARI D-PAD: Bina seçimi ===")
		current_assignment_building_index = (current_assignment_building_index - 1) % all_buildings.size()
		if current_assignment_building_index < 0:
			current_assignment_building_index = all_buildings.size() - 1
		print("Seçilen bina: ", all_buildings[current_assignment_building_index]["name"])
		update_assignment_ui()

	elif event.is_action_pressed("ui_down"):
		print("=== AŞAĞI D-PAD: Bina seçimi ===")
		current_assignment_building_index = (current_assignment_building_index + 1) % all_buildings.size()
		print("Seçilen bina: ", all_buildings[current_assignment_building_index]["name"])
		update_assignment_ui()

	# Sol/Sağ D-pad: İşçi ekle/çıkar (tekrar hızını sınırlamak için cooldown)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		var now_ms = Time.get_ticks_msec()
		var elapsed = now_ms - _assign_lr_last_ms
		if elapsed < _assign_lr_cooldown_ms:
			return
		_assign_lr_last_ms = now_ms

		if event.is_action_pressed("ui_left"):
			print("=== SOL D-PAD: İşçi çıkarılıyor ===")
			remove_worker_from_building(all_buildings[current_assignment_building_index])
		else:
			print("=== SAĞ D-PAD: İşçi ekleniyor ===")
			add_worker_to_building(all_buildings[current_assignment_building_index])
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
	
	# Eğer Kışla ise, asker ekipman menüsüne geç
	if building_type == "Kışla" and building_node.has_method("get_military_force"):
		current_assignment_menu_state = AssignmentMenuState.ASKER_EKİPMAN
		current_soldier_index = 0
		current_equipment_action = 0
		update_assignment_ui()
		return
	
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
	
	print("[DEBUG] PlacedBuildings içinde %d child var" % placed_buildings.get_child_count())
	
	for building in placed_buildings.get_children():
		# Node'un geçerli olup olmadığını kontrol et
		if not is_instance_valid(building):
			print("[DEBUG] Geçersiz node atlandı: ", building)
			continue
		
		# Sadece gerçekten kurulu binaları göster - scene_file_path olmalı (gerçek bina sahnesi)
		# scene_file_path olmayan veya boş olan node'ları atla (bunlar test amaçlı veya geçici node'lar olabilir)
		var scene_path = building.get("scene_file_path")
		if scene_path == null or scene_path == "":
			print("[DEBUG] scene_file_path olmayan node atlandı: ", building.name, " (script: ", building.get_script().resource_path if building.get_script() else "none", ")")
			continue
		
		# Script kontrolü - script'i olmayan veya bilinmeyen script'li binaları atla
		if not building.has_method("get_script") or building.get_script() == null:
			print("[DEBUG] Script olmayan node atlandı: ", building.name)
			continue
		
		var building_type = get_building_type_name(building)
		# "Bilinmeyen" tipindeki binaları atla
		if building_type == "Bilinmeyen":
			print("[DEBUG] Bilinmeyen tip node atlandı: ", building.name, " (script path: ", building.get_script().resource_path if building.get_script() else "none", ")")
			continue
		
		# Sadece işçi atanabilir binaları ekle (add_worker veya remove_worker metodu olmalı)
		if not (building.has_method("add_worker") or building.has_method("remove_worker")):
			print("[DEBUG] add_worker/remove_worker metodu olmayan node atlandı: ", building.name, " (type: ", building_type, ")")
			continue

		# Gerçek zamanlı verileri al
		var assigned_workers = 0
		var max_workers = 1
		
		if building.get("assigned_workers") != null:
			assigned_workers = building.assigned_workers
		if building.get("max_workers") != null:
			max_workers = building.max_workers
		
		print("[DEBUG] ✅ Bina eklendi: ", building.name, " (type: ", building_type, ", scene_file_path: ", scene_path, ")")
		
		var building_info = {
			"node": building,
			"name": building.name,
			"type": building_type,
			"current_workers": assigned_workers, # assigned_workers -> current_workers olarak değiştirildi
			"max_workers": max_workers
		}
		all_buildings.append(building_info)
	
	print("[DEBUG] Toplam %d bina bulundu" % all_buildings.size())
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
		"res://village/scripts/Sawmill.gd": return "Kerestehane"
		"res://village/scripts/Brickworks.gd": return "Tuğla Ocağı"
		"res://village/scripts/Blacksmith.gd": return "Demirci"
		"res://village/scripts/Gunsmith.gd": return "Silahçı"
		"res://village/scripts/Armorer.gd": return "Zırh Ustası"
		"res://village/scripts/Weaver.gd": return "Dokuma Tezgahı"
		"res://village/scripts/Tailor.gd": return "Terzi"
		"res://village/scripts/TeaHouse.gd": return "Çayhane"
		"res://village/scripts/SoapMaker.gd": return "Sabuncu"
		"res://village/scripts/Herbalist.gd": return "Şifacı"
		"res://village/scripts/House.gd": return "Ev"
		"res://village/scripts/Barracks.gd": return "Kışla"
		_: return "Bilinmeyen"

# Binaya işçi ekle
func add_worker_to_building(building_info: Dictionary) -> void:
	print("=== ADD WORKER DEBUG ===")
	print("İşçi ekleniyor: ", building_info["name"])
	
	var building = building_info["node"]
	if not building:
		print("❌ Bina node'u bulunamadı!")
		return
	
	# Kışla binası için özel işlem
	if building.has_method("add_worker") and building.get_script() and building.get_script().resource_path == "res://village/scripts/Barracks.gd":
		var success = building.add_worker()
		if success:
			print("✅ Köylü asker yapıldı: ", building_info["name"])
			update_assignment_ui()
		else:
			print("❌ Köylü asker yapılamadı: ", building_info["name"])
		return
	
	# Diğer binalar için normal işlem
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
	
	# Kışla binası için özel işlem
	if building.has_method("remove_worker") and building.get_script() and building.get_script().resource_path == "res://village/scripts/Barracks.gd":
		var success = building.remove_worker()
		if success:
			print("✅ Asker köylü yapıldı: ", building_info["name"])
			# EKSTRA KONTROL: İşçinin görünür olduğundan emin ol!
			_ensure_worker_visibility_after_removal(building)
			update_assignment_ui()
		else:
			print("❌ Asker köylü yapılamadı: ", building_info["name"])
		return
	
	# Diğer binalar için normal işlem
	# Gerçek zamanlı veri kontrolü
	var current_assigned = building.assigned_workers if "assigned_workers" in building else 0
	
	if current_assigned <= 0:
		print("❌ Binada işçi yok: ", building_info["name"], " (", current_assigned, ")")
		return
	
	# İşçiyi binadan çıkar (ama silme! Sadece idle yap!)
	if building.has_method("remove_worker"):
		# ÖNEMLİ: Önce VillageManager'da işçiyi unregister et (bina scripti çağrılmadan önce!)
		# Çünkü bina scripti çağrıldığında assigned_building_node zaten null oluyor
		var worker_id = -1
		if building.has_method("get_assigned_worker_ids"):
			# Eğer bina scriptinde get_assigned_worker_ids metodu varsa onu kullan (Bakery gibi)
			var ids = building.get_assigned_worker_ids()
			if ids.size() > 0:
				worker_id = ids[0]
		elif "assigned_worker_ids" in building:
			# Yoksa direkt değişkene erişmeyi dene
			worker_id = building.assigned_worker_ids[0] if building.assigned_worker_ids.size() > 0 else -1
		if worker_id != -1:
			print("🔧 VillageManager'da işçi %d unregister ediliyor (bina scripti çağrılmadan önce)" % worker_id)
			if not village_manager:
				village_manager = get_node_or_null("/root/VillageManager")
			if village_manager and village_manager.has_method("unregister_generic_worker"):
				village_manager.unregister_generic_worker(worker_id)
			else:
				printerr("MissionCenter: VillageManager unavailable or missing method 'unregister_generic_worker'. Skipping unregister.")
		
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
		# Kalan süre ve yüzde
		if ("upgrade_timer" in building) and building.upgrade_timer and ("upgrade_time_seconds" in building):
			var total := float(building.upgrade_time_seconds)
			if total > 0.0:
				var left := float(building.upgrade_timer.time_left)
				var ratio: float = clamp((total - left) / total, 0.0, 1.0)
				var pct: int = int(round(ratio * 100.0))
				info += " ⏳" + str(int(ceil(left))) + "sn (" + str(pct) + "%)"
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
			# Süre bilgisi
			if "upgrade_time_seconds" in building:
				info += " ⏱" + str(int(building.upgrade_time_seconds)) + "sn"
			# Basit etki önizleme
			if "max_workers" in building:
				var cur_workers := int(building.max_workers)
				info += " • Etki: İşçi " + str(cur_workers) + "→" + str(cur_workers + 1)

	if building_recipe_texts.has(building_type):
		if info != "":
			info += "\n"
		info += building_recipe_texts[building_type]
	
	return info

# Bina inşa etme işlemi
func execute_build_action():
	var buildings = building_categories.get(current_building_category, [])
	if buildings.is_empty():
		print("Bu kategoride bina yok!")
		return
	
	# Seçili binayı al (index kontrolü ile)
	var selected_building = ""
	if current_building_index >= 0 and current_building_index < buildings.size():
		selected_building = buildings[current_building_index]
	else:
		# Index geçersizse ilk binayı seç
		selected_building = buildings[0] if buildings.size() > 0 else ""
		current_building_index = 0  # Index'i düzelt
	
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
		info += "⚡ Yükseltiliyor..."
		if ("upgrade_timer" in building) and building.upgrade_timer and ("upgrade_time_seconds" in building):
			var total := float(building.upgrade_time_seconds)
			if total > 0.0:
				var left := float(building.upgrade_timer.time_left)
				var ratio: float = clamp((total - left) / total, 0.0, 1.0)
				var pct: int = int(round(ratio * 100.0))
				info += " ⏳ Kalan: " + str(int(ceil(left))) + "sn (" + str(pct) + "%)"
		info += "\n"
	
	# İşçi bilgileri
	if "assigned_workers" in building and "max_workers" in building:
		info += "👥 İşçiler: " + str(building.assigned_workers) + "/" + str(building.max_workers) + "\n"
	
	# Yükseltme maliyeti
	if building.has_method("get_next_upgrade_cost"):
		var upgrade_cost = building.get_next_upgrade_cost()
		if upgrade_cost.has("gold") and upgrade_cost["gold"] > 0:
			info += "💰 Yükseltme: " + str(upgrade_cost["gold"]) + " Altın\n"
	
	# Yükseltme süresi
	if "upgrade_time_seconds" in building:
		info += "⏱ Süre: " + str(int(building.upgrade_time_seconds)) + "sn\n"

	# Basit etki önizleme
	if "max_workers" in building:
		var cur_workers := int(building.max_workers)
		info += "✨ Etki: İşçi " + str(cur_workers) + "→" + str(cur_workers + 1) + "\n"
	
	# Üretim bilgileri (eğer varsa)
	if building.has_method("get_production_info"):
		var production_info = building.get_production_info()
		info += "📈 Üretim: " + production_info + "\n"
	if building_recipe_texts.has(building_type):
		info += "🧪 " + String(building_recipe_texts[building_type]) + "\n"
	
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
		var vm = get_node_or_null("/root/VillageManager")
		if vm and vm.has_method("prepare_building_upgrade"):
			vm.prepare_building_upgrade(building_to_upgrade)
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
		"Kerestehane": script_path = "res://village/scripts/Sawmill.gd"
		"Tuğla Ocağı": script_path = "res://village/scripts/Brickworks.gd"
		"Fırın": script_path = "res://village/scripts/Bakery.gd"
		"Demirci": script_path = "res://village/scripts/Blacksmith.gd"
		"Silahçı": script_path = "res://village/scripts/Gunsmith.gd"
		"Zırh Ustası": script_path = "res://village/scripts/Armorer.gd"
		"Dokuma Tezgahı": script_path = "res://village/scripts/Weaver.gd"
		"Terzi": script_path = "res://village/scripts/Tailor.gd"
		"Çayhane": script_path = "res://village/scripts/TeaHouse.gd"
		"Sabuncu": script_path = "res://village/scripts/SoapMaker.gd"
		"Şifacı": script_path = "res://village/scripts/Herbalist.gd"
		"Ev": script_path = "res://village/scripts/House.gd"
		"Kışla": script_path = "res://village/scripts/Barracks.gd"
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
		# Ev türü için: dükkan gibi binaların üstüne eklenen extension House'ları da ara.
		if building_type == "Ev":
			for sub in building.get_children():
				if sub.has_method("get_script") and sub.get_script() != null:
					var sub_scr = sub.get_script()
					if sub_scr is GDScript and sub_scr.resource_path == script_path:
						buildings.append(sub)

	print("Bulunan binalar: ", buildings.size(), " adet")
	return buildings

# Atama UI'ını güncelle
func update_assignment_ui():
	"""Atama sayfası UI'ını güncelle"""
	if current_page != PageType.ASSIGNMENT:
		return
	
	# Grid Container Referansı
	var grid_container = assignment_page.get_node_or_null("AssignmentScroll/CenterContainer/AssignmentGrid")
	if not grid_container: 
		# Eski label tabanlı yapı varsa, grid'e geçene kadar işlem yapma
		# Fakat label'ı gizle ki karışıklık olmasın
		var old_label = assignment_page.get_node_or_null("AssignmentLabel")
		if old_label: old_label.visible = false
		return
	
	# Eski label varsa gizle
	var old_assignment_label = assignment_page.get_node_or_null("AssignmentLabel")
	if old_assignment_label: old_assignment_label.visible = false
	
	if current_assignment_menu_state == AssignmentMenuState.BİNA_LISTESİ:
		# Temizle
		for c in grid_container.get_children():
			c.queue_free()
			
		var all_buildings = get_all_available_buildings()
		if all_buildings.is_empty():
			var empty_lbl = Label.new()
			empty_lbl.text = "Atanabilir bina yok.\nÖnce inşaat yapmalısın."
			grid_container.add_child(empty_lbl)
			return
			
		for i in range(all_buildings.size()):
			var b_info = all_buildings[i]
			var building_name = b_info["name"]
			var current_workers = b_info["current_workers"]
			var max_workers = b_info["max_workers"]
			var is_selected = (i == current_assignment_building_index)
			
			var panel = PanelContainer.new()
			panel.custom_minimum_size = Vector2(180, 140)
			
			var style = StyleBoxFlat.new()
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			
			# Tema renklerini kullan
			if is_selected:
				style.bg_color = Color(0.2, 0.18, 0.15, 1.0) # Seçili
				style.border_width_left = 2
				style.border_width_top = 2
				style.border_width_right = 2
				style.border_width_bottom = 2
				style.border_color = Color(0.6, 0.5, 0.3, 1) # Gold/Bronz
			else:
				style.bg_color = Color(0.15, 0.13, 0.1, 0.85) # Normal
				
			panel.add_theme_stylebox_override("panel", style)
			
			var vbox = VBoxContainer.new()
			panel.add_child(vbox)
			vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
			vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			
			# İsim
			var name_lbl = Label.new()
			name_lbl.text = building_name
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.add_theme_font_size_override("font_size", 14)
			vbox.add_child(name_lbl)
			
			# İşçi Sayısı
			var worker_lbl = Label.new()
			worker_lbl.text = "İşçiler: %d / %d" % [current_workers, max_workers]
			worker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if current_workers >= max_workers and max_workers > 0:
				worker_lbl.add_theme_color_override("font_color", Color(0.5, 1, 0.5)) # Dolu
			elif current_workers == 0:
				worker_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8)) # Boş
			else:
				worker_lbl.add_theme_color_override("font_color", Color(1, 1, 0.5)) # Kısmi
			vbox.add_child(worker_lbl)
			
			# Tip
			var type_lbl = Label.new()
			type_lbl.text = b_info["type"]
			type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			type_lbl.add_theme_font_size_override("font_size", 10)
			type_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			vbox.add_child(type_lbl)
			
			grid_container.add_child(panel)
			
	elif current_assignment_menu_state == AssignmentMenuState.BİNA_DETAYI:
		# Detay görünümü için eski text tabanlı yapıyı kullanabiliriz veya özel bir panel açabiliriz.
		# Şimdilik grid'i temizleyip tek bir büyük panel gösterelim
		for c in grid_container.get_children():
			c.queue_free()
			
		var all_buildings = get_all_available_buildings()
		if not all_buildings.is_empty():
			var selected_building_info = all_buildings[current_assignment_building_index]
			var building_node = selected_building_info["node"]
			var building_type = selected_building_info["type"]
			var info = get_building_detailed_info(building_node, building_type)
			
			var detail_label = Label.new()
			detail_label.text = "=== BİNA DETAYI ===\n\n" + info
			detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid_container.add_child(detail_label)
			
	elif current_assignment_menu_state == AssignmentMenuState.ASKER_EKİPMAN:
		# Asker ekipman menüsü için grid yerine liste görünümü daha uygun olabilir
		# Şimdilik grid'i temizleyip text gösterelim (mevcut text logic'i grid içine label olarak)
		for c in grid_container.get_children():
			c.queue_free()
			
		var soldiers = get_barracks_soldiers()
		var vm = get_node_or_null("/root/VillageManager")
		var available_weapons = vm.resource_levels.get("weapon", 0) if vm else 0
		var available_armors = vm.resource_levels.get("armor", 0) if vm else 0
		var text = "=== ASKER EKİPMAN ATAMA ===\n\n"
		text += "📦 Stok: Silah: %d | Zırh: %d\n\n" % [available_weapons, available_armors]
		var accept_key = InputManager.get_accept_key_name()
		var cancel_key = InputManager.get_cancel_key_name()
		if soldiers.is_empty():
			text += "Kışlada asker yok!\n\n[%s: Geri]" % cancel_key
		else:
			text += "Yukarı/Aşağı: Asker seç\n"
			text += "Sol/Sağ: Silah/Zırh seç\n"
			text += "%s: Ekipman Ver/Al\n\n" % accept_key
			var equipment_names = ["⚔️ Silah", "🛡️ Zırh"]
			text += "Seçili Ekipman: %s\n\n" % equipment_names[current_equipment_action]
			for i in range(soldiers.size()):
				var soldier = soldiers[i]
				var marker = "> " if i == current_soldier_index else "  "
				var weapon_mark = "⚔️" if soldier["equipment"].get("weapon", false) else "  "
				var armor_mark = "🛡️" if soldier["equipment"].get("armor", false) else "  "
				text += marker + "Asker %d %s %s\n" % [soldier["worker_id"], weapon_mark, armor_mark]
			text += "\n[%s: Geri]" % cancel_key
			
		var equip_label = Label.new()
		equip_label.text = text
		equip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid_container.add_child(equip_label)

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
	print("[DEBUG_MC] show_page: Index: ", page_index)
	current_page = page_index

	missions_page.visible = false
	assignment_page.visible = false
	construction_page.visible = false
	news_page.visible = false
	concubine_details_page.visible = false
	if trade_page:
		trade_page.visible = false
	if diplomacy_page:
		diplomacy_page.visible = false

	# print("Tüm sayfalar gizlendi")

	match current_page:
		PageType.MISSIONS:
			missions_page.visible = true
			print("[DEBUG_MC] show_page: MissionsPage.visible = true yapıldı")
			# Görevler sayfası açıldığında başlangıç durumuna sıfırla
			current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
			# current_mission_index = 0  # Index'i sıfırlama - kullanıcının seçimini koru
			print("[DEBUG_MC] show_page: update_missions_ui() çağrılıyor")
			update_missions_ui()
			print("[DEBUG_MC] show_page: update_active_missions_cards() çağrılıyor")
			update_active_missions_cards()
			print("[DEBUG_MC] show_page: update_available_missions_cards() çağrılıyor")
			update_available_missions_cards()
		PageType.ASSIGNMENT:
			assignment_page.visible = true
			# print("AssignmentPage gösterildi")
			# Atama sayfası açıldığında başlangıç durumuna sıfırla
			current_assignment_menu_state = AssignmentMenuState.BİNA_LISTESİ
			# current_assignment_building_index = 0  # Index'i sıfırlama - kullanıcının seçimini koru
			update_assignment_ui()
		PageType.CONSTRUCTION:
			construction_page.visible = true
			# print("ConstructionPage gösterildi")
			# İnşaat sayfası açıldığında başlangıç durumuna sıfırla
			current_menu_state = MenuState.İŞLEM_SEÇİMİ
			# current_building_index = 0  # Index'i sıfırlama - kullanıcının seçimini koru
			update_construction_ui()
		PageType.NEWS:
			news_page.visible = true
			# print("NewsPage gösterildi")
			# Haber sayfası açıldığında güncelle
			update_news_ui()
		PageType.TRADE:
			if trade_page:
				trade_page.visible = true
				# print("TradePage gösterildi")
				_update_trade_diplomacy_visibility()
				# Başlıkları güncelle
				var active_title = get_node_or_null("TradePage/TradeContent/ActiveAgreementsPanel/ActiveAgreementsTitle")
				if active_title:
					active_title.text = "💰 GELEN TÜCCARLAR"
				var offers_title = get_node_or_null("TradePage/TradeContent/OffersPanel/OffersTitle")
				if offers_title:
					offers_title.text = "👤 TÜCCAR CARİYE GÖREVLERİ"
				update_trade_ui()
				# Pop-up açıksa göster
				if trader_buy_popup_open and trader_buy_popup:
					trader_buy_popup.visible = true
		PageType.DIPLOMACY:
			# Diplomasi: ayrı sayfa
			if diplomacy_page:
				if trade_page:
					trade_page.visible = false
				diplomacy_page.visible = true
				# print("DiplomacyPage gösterildi")
				_update_diplomacy_ui()
		PageType.CONCUBINE_DETAILS:
			concubine_details_page.visible = true
			# print("ConcubineDetailsPage gösterildi")
			# Cariye detay sayfası açıldığında güncelle
			current_concubine_detail_index = 0
			update_concubine_details_ui()
	
	page_label.text = page_names[page_index]
	
	# Sayfa göstergesini hemen güncelle (gecikme olmasın)
	update_page_indicator()
	
	# await get_tree().process_frame # Zaten kaldırılmıştı

	# print("Sayfa değişti: ", page_names[page_index])
	# print("Mevcut sayfa enum değeri: ", current_page)

# Duplicate close_menu function removed - using the one at the end of file

# B tuşu ile geri gitme
func handle_back_button():
	if current_page == PageType.CONSTRUCTION:
		if _demolish_confirm_open:
			_debug_construction("B -> cancel_demolish")
			_close_demolish_confirm_popup()
			update_construction_ui()
			return
		if _construction_info_popup:
			_debug_construction("B -> close_info_popup")
			_close_building_info_popup()
			update_construction_ui()
			return
		_debug_construction("B -> back_to_missions")
		show_page(PageType.MISSIONS)
		return
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
	print("[DEBUG_MC] update_missions_ui: Başladı. current_page: ", current_page)
	if current_page == PageType.MISSIONS:
		# Kart sistemi ile güncelle
		print("[DEBUG_MC] update_missions_ui: update_missions_ui_cards() çağrılıyor")
		update_missions_ui_cards()
	else:
		print("[DEBUG_MC] update_missions_ui: current_page MISSIONS değil, çıkılıyor")

func _mission_display_name(m) -> String:
	if m == null:
		return "?"
	if m is Mission:
		return m.name
	if m is Dictionary:
		return str(m.get("name", "?"))
	return str(m)

func _mission_id_text(m) -> String:
	if m is Mission:
		return m.id
	if m is Dictionary:
		return str(m.get("id", ""))
	return ""

func _mission_unique_id(m) -> String:
	return _mission_id_text(m)

func _get_merged_available_missions() -> Array:
	if not mission_manager:
		return []
	var pool: Array = mission_manager.get_available_missions()
	var chain_missions_to_show: Array = []
	if "mission_chains" in mission_manager:
		for chain_id in mission_manager.mission_chains.keys():
			var chain_missions = mission_manager.get_chain_missions(chain_id)
			for m in chain_missions:
				if m.status == Mission.Status.MEVCUT and m.are_prerequisites_met(mission_manager.get_completed_missions()):
					chain_missions_to_show.append(m)
	var unique_ids: Dictionary = {}
	var merged: Array = []
	for mission in pool:
		var uid: String = _mission_unique_id(mission)
		if uid.is_empty():
			continue
		if not unique_ids.has(uid):
			unique_ids[uid] = true
			merged.append(mission)
	for mission in chain_missions_to_show:
		var uid2: String = _mission_unique_id(mission)
		if uid2.is_empty():
			continue
		if not unique_ids.has(uid2):
			unique_ids[uid2] = true
			merged.append(mission)
	return merged

func _active_mission_remaining_display(m) -> String:
	if m is Mission and m.has_method("get_remaining_time"):
		return "%.1f dk" % m.get_remaining_time()
	if m is Dictionary:
		return "?"
	return "?"

func _build_mission_detail_text(m) -> String:
	if m == null:
		return ""
	if m is Mission:
		var lines: Array = []
		lines.append("Tür: %s" % m.get_mission_type_name())
		lines.append("Zorluk: %s" % m.get_difficulty_name())
		lines.append("Süre: %s" % _format_game_time_minutes(m.duration))
		lines.append("Başarı şansı: %d%%" % int(m.success_chance * 100))
		if String(m.completes_incident_id).length() > 0:
			var hx = String(m.world_hex_key)
			if hx.is_empty():
				lines.append("Köprü: yerleşim krizi → %s" % m.target_location)
			else:
				lines.append("Köprü: kriz çözümü | %s (%s)" % [m.target_location, hx])
		elif String(m.completes_alliance_aid_settlement_id).length() > 0:
			var hxa = String(m.world_hex_key)
			if hxa.is_empty():
				lines.append("Köprü: muttefik yardım çağrısı → %s" % m.target_location)
			else:
				lines.append("Köprü: muttefik yardım | %s (%s)" % [m.target_location, hxa])
		elif String(m.world_hex_key).length() > 0:
			lines.append("Harita hedefi: %s — Kendin git veya cariye gönder." % m.world_hex_key)
		if String(m.description).length() > 0:
			lines.append("")
			lines.append(String(m.description))
		if not m.rewards.is_empty():
			lines.append("")
			lines.append("Ödüller: %s" % str(m.rewards))
		if not m.penalties.is_empty():
			lines.append("Cezalar: %s" % str(m.penalties))
		return _join_detail_lines(lines)
	if m is Dictionary:
		var d: Dictionary = m
		var lines2: Array = []
		lines2.append("Tür: %s" % str(d.get("type", "?")))
		lines2.append("Süre: %s" % str(d.get("duration", "?")))
		var tgt = str(d.get("target", d.get("name", "")))
		if tgt.length() > 0:
			lines2.append("Hedef: %s" % tgt)
		if String(d.get("completes_incident_id", "")).length() > 0:
			lines2.append("Köprü: komşu yerleşim krizi")
		elif String(d.get("completes_alliance_aid_settlement_id", "")).length() > 0:
			lines2.append("Köprü: muttefik yardım çağrısı")
		return _join_detail_lines(lines2)
	return str(m)

func _join_detail_lines(lines: Array) -> String:
	var out := ""
	for i in range(lines.size()):
		if i > 0:
			out += "\n"
		out += str(lines[i])
	return out

func _ensure_mission_detail_strip() -> void:
	if mission_detail_label != null and is_instance_valid(mission_detail_label):
		return
	if not missions_page:
		return
	var panel := PanelContainer.new()
	panel.name = "SelectedMissionDetailStrip"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.11, 0.09, 0.92)
	sb.set_content_margin_all(8)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78))
	lbl.text = ""
	mission_detail_label = lbl
	panel.add_child(lbl)
	mission_detail_panel = panel
	missions_page.add_child(panel)
	if missions_page.get_child_count() > 2:
		missions_page.move_child(panel, 1)

func _refresh_mission_selection_detail() -> void:
	_ensure_mission_detail_strip()
	if mission_detail_panel == null or mission_detail_label == null:
		return
	var hide_strip := showing_mission_result
	if current_mission_menu_state == MissionMenuState.GÖREV_GEÇMİŞİ or current_mission_menu_state == MissionMenuState.GEÇMİŞ_DETAYI:
		hide_strip = true
	mission_detail_panel.visible = not hide_strip and current_page == PageType.MISSIONS
	if hide_strip or current_page != PageType.MISSIONS:
		return
	var m = get_selected_mission()
	if m == null:
		mission_detail_label.text = "Yapılabilir görev yok. Liste güncellenince tekrar deneyin."
		return
	var title := _mission_display_name(m)
	var body := _build_mission_detail_text(m)
	mission_detail_label.text = "%s\n%s" % [title, body]

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
			if not mission_manager.missions.has(mission_id):
				continue
			var mission = mission_manager.missions[mission_id]
			var cariye = mission_manager.concubines[cariye_id]
			
			var rem = _active_mission_remaining_display(mission)
			text += "• %s → %s (%s kaldı)\n" % [cariye.name, _mission_display_name(mission), rem]
		text += "\n"
	else:
		text += "📋 AKTİF GÖREV YOK\n\n"
	
	# Mevcut görevler (birleşik liste — kartlarla aynı)
	var available_missions = _get_merged_available_missions()
	if not available_missions.is_empty():
		text += "📝 YAPILABİLİR GÖREVLER:\n"
		for i in range(available_missions.size()):
			var mission = available_missions[i]
			var selection_marker = " ← SEÇİLİ" if i == current_mission_index else ""
			text += "• %s%s\n" % [_mission_display_name(mission), selection_marker]
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
	text += "Görev: %s\n\n" % _mission_display_name(selected_mission)
	
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
	
	var title = _mission_display_name(selected_mission)
	var text = "📋 GÖREV DETAYI:\n\n"
	text += "%s\n\n" % title
	text += _build_mission_detail_text(selected_mission)
	text += "\n\n[B: Geri]"
	content_label.text = text

# Seçili görevi döndür
func get_selected_mission():
	var available_missions = _get_merged_available_missions()
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
	
	print("✅ Seçili görev: %s (ID: %s)" % [_mission_display_name(selected_mission), _mission_id_text(selected_mission)])
	
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
	return _get_merged_available_missions()

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
func update_mission_result_content(cariye: Concubine, mission, successful: bool, results: Dictionary):
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
	# title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)
	
	# Boşluk
	var spacer1 = Control.new()
	spacer1.custom_minimum_size.y = 10
	main_container.add_child(spacer1)
	
	# Cariye ve görev bilgisi
	var info_label = Label.new()
	info_label.text = "👤 %s → 🎯 %s" % [cariye.name, _mission_display_name(mission)]
	# info_label.add_theme_font_size_override("font_size", 18)
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
	# result_label.add_theme_font_size_override("font_size", 20)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(result_label)
	
	# Boşluk
	var spacer3 = Control.new()
	spacer3.custom_minimum_size.y = 15
	main_container.add_child(spacer3)
	
	# Ödüller/Cezalar
	var rewards_dict: Dictionary = {}
	var penalties_dict: Dictionary = {}
	if mission is Mission:
		rewards_dict = mission.rewards
		penalties_dict = mission.penalties
	elif mission is Dictionary:
		var rd = mission.get("rewards", {})
		var pd = mission.get("penalties", {})
		if rd is Dictionary:
			rewards_dict = rd
		if pd is Dictionary:
			penalties_dict = pd
	
	if successful and rewards_dict.size() > 0:
		var rewards_label = Label.new()
		rewards_label.text = "💰 ÖDÜLLER:"
		# rewards_label.add_theme_font_size_override("font_size", 16)
		rewards_label.add_theme_color_override("font_color", Color.YELLOW)
		rewards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_container.add_child(rewards_label)
		
		for reward_type in rewards_dict:
			var amount = rewards_dict[reward_type]
			var reward_text = "  • %s: +%d" % [reward_type, amount]
			var reward_label = Label.new()
			reward_label.text = reward_text
			# reward_label.add_theme_font_size_override("font_size", 14)
			reward_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
			reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			main_container.add_child(reward_label)
	
	if not successful and penalties_dict.size() > 0:
		var penalties_label = Label.new()
		penalties_label.text = "⚠️ CEZALAR:"
		# penalties_label.add_theme_font_size_override("font_size", 16)
		penalties_label.add_theme_color_override("font_color", Color.ORANGE)
		penalties_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_container.add_child(penalties_label)
		
		for penalty_type in penalties_dict:
			var amount = penalties_dict[penalty_type]
			var penalty_text = "  • %s: %d" % [penalty_type, amount]
			var penalty_label = Label.new()
			penalty_label.text = penalty_text
			# penalty_label.add_theme_font_size_override("font_size", 14)
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
	# cariye_status_label.add_theme_font_size_override("font_size", 14)
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
	# close_label.add_theme_font_size_override("font_size", 12)
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
	# title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color.GOLD)
	mission_result_content.add_child(title_label)
	
	# Cariye bilgisi
	var cariye_label = Label.new()
	cariye_label.text = "%s seviye %d'ye yükseldi!" % [cariye.name, new_level]
	# cariye_label.add_theme_font_size_override("font_size", 16)
	cariye_label.add_theme_color_override("font_color", Color.WHITE)
	mission_result_content.add_child(cariye_label)
	
	# Yeni özellikler
	var stats_label = Label.new()
	stats_label.text = "YENİ ÖZELLİKLER:"
	# stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color.YELLOW)
	mission_result_content.add_child(stats_label)
	
	# Sağlık ve moral
	var health_label = Label.new()
	health_label.text = "• Maksimum Sağlık: %d" % cariye.max_health
	# health_label.add_theme_font_size_override("font_size", 12)
	health_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	mission_result_content.add_child(health_label)
	
	var moral_label = Label.new()
	moral_label.text = "• Maksimum Moral: %d" % cariye.max_moral
	# moral_label.add_theme_font_size_override("font_size", 12)
	moral_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	mission_result_content.add_child(moral_label)
	
	# Yetenekler
	var skills_label = Label.new()
	skills_label.text = "YETENEK ARTIŞLARI:"
	# skills_label.add_theme_font_size_override("font_size", 14)
	skills_label.add_theme_color_override("font_color", Color.YELLOW)
	mission_result_content.add_child(skills_label)
	
	for skill in cariye.skills:
		var skill_label = Label.new()
		skill_label.text = "• %s: %d" % [cariye.get_skill_name(skill), cariye.skills[skill]]
		# skill_label.add_theme_font_size_override("font_size", 12)
		skill_label.add_theme_color_override("font_color", Color.LIGHT_CYAN)
		mission_result_content.add_child(skill_label)
	
	# Kapatma talimatı
	var close_label = Label.new()
	close_label.text = "3 saniye sonra otomatik kapanır..."
	# close_label.add_theme_font_size_override("font_size", 10)
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
	# title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_label)
	
	# Tür ve süre
	var info_label = Label.new()
	info_label.text = "Tür: %s | Süre: %.1fs" % [mission.get_mission_type_name(), mission.duration]
	# info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(info_label)
	
	# Başarı şansı
	var success_label = Label.new()
	success_label.text = "Başarı Şansı: %d%%" % (mission.success_chance * 100)
	# success_label.add_theme_font_size_override("font_size", 12)
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
	var card = PanelContainer.new()
	# card.custom_minimum_size = Vector2(450, 0)  # Yükseklik dinamik olsun
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Stil (StyleBoxFlat) oluştur
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	# Kart rengi - seçili ise daha parlak
	if is_selected:
		style.bg_color = Color(0.25, 0.22, 0.18, 1.0).lightened(0.2) # Sarımsı/Açık Kahve
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.9, 0.8, 0.2, 1.0) # Gold
	else:
		style.bg_color = Color(0.15, 0.13, 0.1, 0.85) # Koyu Kahve
		style.border_color = Color(0.4, 0.35, 0.3, 1.0) # Bronz
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		
	card.add_theme_stylebox_override("panel", style)
	
	# Kart içeriği
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.add_theme_constant_override("separation", 8)
	
	# Cariye ve görev
	var title_label = Label.new()
	var selection_marker = " ← SEÇİLİ" if is_selected else ""
	title_label.text = "%s → %s%s" % [cariye.name, mission.name, selection_marker]
	# title_label.add_theme_font_size_override("font_size", 16)
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
	var time_text = _format_game_time_minutes(remaining_time)
	time_label.text = "⏱️ %s kaldı" % time_text
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
		_refresh_mission_selection_detail()
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
	
	_refresh_mission_selection_detail()

# Yapılabilir görevleri kart olarak güncelle

func update_available_missions_cards():
	print("[DEBUG_MC] update_available_missions_cards: Başladı")
	if not available_missions_list:
		print("⚠️ [DEBUG_MC] update_available_missions_cards: available_missions_list is null!")
		return
	clear_list(available_missions_list)
	# Kartlar arası boşluk
	available_missions_list.add_theme_constant_override("separation", 10)
	
	print("[DEBUG_MC] update_available_missions_cards: mission_manager kontrol ediliyor")
	if not mission_manager:
		print("⚠️ [DEBUG_MC] update_available_missions_cards: mission_manager is null!")
		return
		
	var available_missions = _get_merged_available_missions()
	print("[DEBUG_MC] update_available_missions_cards: Final görev sayısı: ", available_missions.size())
	
	if not available_missions.is_empty() and current_mission_index >= available_missions.size():
		current_mission_index = max(0, available_missions.size() - 1)
	
	if available_missions.is_empty():
		print("[DEBUG_MC] update_available_missions_cards: Liste boş, 'Yok' etiketi ekleniyor")
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
	
	print("[DEBUG_MC] update_available_missions_cards: Kartlar eklendi")

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
func create_available_mission_card(mission, is_selected: bool) -> Control:
	# Mission objesi mi yoksa Dictionary mi kontrol et
	var is_dict = mission is Dictionary
	var mission_name: String
	var mission_type_str: String
	var mission_type_emoji: String
	var difficulty_name: String
	var risk_level: String
	var duration: float
	var success_chance: float
	var rewards: Dictionary
	var required_level: int
	var required_army: int
	var required_resources: Dictionary
	var target_location: String
	var distance: float
	var is_world_map_order: bool = false
	
	if is_dict:
		# Dictionary görevleri için
		mission_name = mission.get("name", "Bilinmeyen Görev")
		mission_type_str = mission.get("type", "unknown")
		difficulty_name = mission.get("difficulty", "medium")
		risk_level = mission.get("risk_level", "Orta")
		duration = float(mission.get("duration", 10.0))
		success_chance = float(mission.get("success_chance", 0.5))
		rewards = mission.get("rewards", {})
		required_level = int(mission.get("required_cariye_level", 1))
		required_army = int(mission.get("required_army_size", 0))
		required_resources = mission.get("required_resources", {})
		target_location = mission.get("target", mission.get("attacker", ""))
		distance = float(mission.get("distance", 0.0))
		is_world_map_order = String(mission.get("source", "")) == "world_map"
		
		# Emoji belirleme
		match mission_type_str:
			"defense", "raid":
				mission_type_emoji = "⚔️"
			_:
				mission_type_emoji = "📋"
	else:
		# Mission objesi için
		mission_name = mission.name
		mission_type_str = mission.get_mission_type_name()
		difficulty_name = mission.get_difficulty_name()
		risk_level = mission.risk_level
		duration = mission.duration
		success_chance = mission.success_chance
		rewards = mission.rewards
		required_level = mission.required_cariye_level
		required_army = mission.required_army_size
		required_resources = mission.required_resources
		target_location = mission.target_location
		distance = mission.distance
		is_world_map_order = String(mission.id).begins_with("worldmap_") or String(mission.name).begins_with("Harita ")
		
		# Emoji belirleme
		if mission.mission_type == Mission.MissionType.SAVAŞ:
			mission_type_emoji = "⚔️"
		elif mission.mission_type == Mission.MissionType.KEŞİF:
			mission_type_emoji = "🧭"
		elif mission.mission_type == Mission.MissionType.DİPLOMASİ:
			mission_type_emoji = "🤝"
		elif mission.mission_type == Mission.MissionType.TİCARET:
			mission_type_emoji = "💰"
		elif mission.mission_type == Mission.MissionType.BÜROKRASİ:
			mission_type_emoji = "📜"
		else:
			mission_type_emoji = "🕵️"
	
	var card = PanelContainer.new()
	# card.custom_minimum_size = Vector2(300, 0)  # Minimum yükseklik
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Stil (StyleBoxFlat) oluştur
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	# Seçili kart rengi
	if is_selected:
		style.bg_color = Color(0.25, 0.22, 0.18, 1.0).lightened(0.2) # Sarımsı/Açık Kahve
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.9, 0.8, 0.2, 1.0) # Gold
	else:
		style.bg_color = Color(0.15, 0.13, 0.1, 0.85) # Koyu Kahve
		style.border_color = Color(0.4, 0.35, 0.3, 1.0) # Bronz
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	vbox.add_theme_constant_override("separation", 8)
	
	# Görev başlığı
	var title_label = Label.new()
	title_label.text = "%s %s" % [mission_type_emoji, mission_name]
	# title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_label)
	
	var relief_line: String = ""
	if is_dict:
		var cid_dict: String = String(mission.get("completes_incident_id", ""))
		var tl_dict: String = String(mission.get("target_location", mission.get("name", "")))
		if not cid_dict.is_empty():
			relief_line = "Komsu kriz | %s" % tl_dict
		elif String(mission.get("completes_alliance_aid_settlement_id", "")).length() > 0:
			relief_line = "Muttefik yardim cagrisi | %s" % tl_dict
	else:
		if String(mission.completes_incident_id).length() > 0:
			var hex_hint: String = String(mission.world_hex_key)
			if hex_hint.is_empty():
				relief_line = "Komsu kriz yardimi | %s" % mission.target_location
			else:
				relief_line = "Komsu kriz yardimi | %s (%s)" % [mission.target_location, hex_hint]
		elif String(mission.completes_alliance_aid_settlement_id).length() > 0:
			var hex_a: String = String(mission.world_hex_key)
			if hex_a.is_empty():
				relief_line = "Muttefik yardim cagrisi | %s" % mission.target_location
			else:
				relief_line = "Muttefik yardim cagrisi | %s (%s)" % [mission.target_location, hex_a]
	if not relief_line.is_empty():
		var relief_label = Label.new()
		relief_label.text = relief_line
		relief_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
		relief_label.add_theme_font_size_override("font_size", 12)
		relief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(relief_label)
	
	# Rozetler: Zorluk, Risk, Süre
	var badges = HBoxContainer.new()
	badges.add_theme_constant_override("separation", 8)
	vbox.add_child(badges)

	# Zincir rozetini ekle (varsa - sadece Mission objeleri için)
	if not is_dict and mission.has_method("is_part_of_chain") and mission.is_part_of_chain():
		var chain_badge = Label.new()
		chain_badge.text = "🔗 Zincir"
		# chain_badge.add_theme_font_size_override("font_size", 11)
		chain_badge.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5, 1))
		badges.add_child(chain_badge)
	
	# Acil/Savunma rozeti (Dictionary görevleri için)
	if is_dict and mission.get("status", "") == "urgent":
		var urgent_badge = Label.new()
		urgent_badge.text = "🚨 Acil"
		# urgent_badge.add_theme_font_size_override("font_size", 11)
		urgent_badge.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
		badges.add_child(urgent_badge)
	
	# Harita emri rozeti
	if is_world_map_order:
		var map_badge = Label.new()
		map_badge.text = "🗺️ Harita Emri"
		map_badge.add_theme_color_override("font_color", Color(0.72, 0.95, 1.0, 1.0))
		badges.add_child(map_badge)
	
	if is_dict and String(mission.get("completes_incident_id", "")).length() > 0:
		var relief_badge = Label.new()
		relief_badge.text = "🏘️ Komşu Yardım"
		relief_badge.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0, 1.0))
		badges.add_child(relief_badge)
	elif is_dict and (String(mission.get("id", "")).begins_with("ally_relief_") or String(mission.get("completes_alliance_aid_settlement_id", "")).length() > 0):
		var ally_badge_d = Label.new()
		ally_badge_d.text = "🤝 Muttefik Yardım"
		ally_badge_d.add_theme_color_override("font_color", Color(0.82, 0.95, 0.88, 1.0))
		badges.add_child(ally_badge_d)
	elif not is_dict and (String(mission.id).begins_with("relief_") or String(mission.completes_incident_id).length() > 0):
		var relief_badge2 = Label.new()
		relief_badge2.text = "🏘️ Komşu Yardım"
		relief_badge2.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0, 1.0))
		badges.add_child(relief_badge2)
	elif not is_dict and (String(mission.id).begins_with("ally_relief_") or String(mission.completes_alliance_aid_settlement_id).length() > 0):
		var ally_badge = Label.new()
		ally_badge.text = "🤝 Muttefik Yardım"
		ally_badge.add_theme_color_override("font_color", Color(0.82, 0.95, 0.88, 1.0))
		badges.add_child(ally_badge)

	var diff_badge = Label.new()
	diff_badge.text = "🎯 %s" % difficulty_name
	# diff_badge.add_theme_font_size_override("font_size", 11)
	diff_badge.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	badges.add_child(diff_badge)

	var risk_badge = Label.new()
	risk_badge.text = "⚠️ %s" % risk_level
	# risk_badge.add_theme_font_size_override("font_size", 11)
	risk_badge.add_theme_color_override("font_color", Color(1, 0.7, 0.2, 1))
	badges.add_child(risk_badge)

	var duration_badge = Label.new()
	var duration_text = _format_game_time_minutes(duration)
	duration_badge.text = "⏱️ %s" % duration_text
	# duration_badge.add_theme_font_size_override("font_size", 11)
	duration_badge.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	badges.add_child(duration_badge)

	# Görev bilgileri
	var info_label = Label.new()
	duration_text = _format_game_time_minutes(duration)  # duration_text zaten yukarıda tanımlı
	info_label.text = "Tür: %s | Süre: %s" % [mission_type_str, duration_text]
	# info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)
	
	# Başarı şansı
	var success_label = Label.new()
	success_label.text = "Başarı Şansı: %d%%" % int(success_chance * 100)
	# success_label.add_theme_font_size_override("font_size", 12)
	success_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	vbox.add_child(success_label)
	
	# Ödüller
	var rewards_text = "Ödüller: "
	var first = true
	for reward_type in rewards.keys():
		var amount = rewards[reward_type]
		if not first:
			rewards_text += ", "
		rewards_text += "%s: %s" % [str(reward_type), str(amount)]
		first = false
	if first:
		rewards_text += "-"
	
	var rewards_label = Label.new()
	rewards_label.text = rewards_text
	# rewards_label.add_theme_font_size_override("font_size", 10)
	rewards_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	rewards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(rewards_label)

	# Gereksinimler
	var reqs_label = Label.new()
	reqs_label.text = "Min. Seviye: %d | Min. Ordu: %d" % [required_level, required_army]
	# reqs_label.add_theme_font_size_override("font_size", 10)
	reqs_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(reqs_label)

	# Mesafe ve hedef
	if target_location != "" or distance > 0.0:
		var travel_label = Label.new()
		var dist_text = "%.1f gün" % distance if distance > 0.0 else "-"
		var tgt_text = target_location if target_location != "" else "Bilinmeyen"
		travel_label.text = "Hedef Yerlesim: %s | Mesafe: %s" % [tgt_text, dist_text]
		# travel_label.add_theme_font_size_override("font_size", 10)
		travel_label.add_theme_color_override("font_color", Color(0.85,0.85,0.85,1))
		vbox.add_child(travel_label)

	# Gerekli kaynaklar
	if not required_resources.is_empty():
		var req_text = "Gerekli Kaynaklar: "
		var first_req = true
		for r in required_resources.keys():
			if not first_req:
				req_text += ", "
			req_text += "%s: %s" % [str(r), str(required_resources[r])]
			first_req = false
		var req_label = Label.new()
		req_label.text = req_text
		# req_label.add_theme_font_size_override("font_size", 10)
		req_label.add_theme_color_override("font_color", Color(0.9,0.8,0.6,1))
		req_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(req_label)
	
	return card

# Cariye seçimi kartlarını güncelle
func update_cariye_selection_cards():
	if not cariye_selection_list:
		print("⚠️ update_cariye_selection_cards: cariye_selection_list is null!")
		return
	clear_list(cariye_selection_list)
	
	var max_soldiers = _get_available_soldier_count()
	var soldier_label = Label.new()
	soldier_label.text = "Yanında asker: %d / %d  (Sol/Sağ ile değiştir)" % [current_soldier_count, max_soldiers]
	soldier_label.add_theme_color_override("font_color", Color.WHITE)
	cariye_selection_list.add_child(soldier_label)
	
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
	# name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# Yetenekler
	var best_skill = cariye.get_best_skill()
	var skills_text = "En İyi: %s (%d)" % [cariye.get_skill_name(best_skill), cariye.get_skill_level(best_skill)]
	var skills_label = Label.new()
	skills_label.text = skills_text
	# skills_label.add_theme_font_size_override("font_size", 12)
	skills_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	vbox.add_child(skills_label)
	
	# Durum
	var status_label = Label.new()
	status_label.text = "Durum: %s" % cariye.get_status_name()
	# status_label.add_theme_font_size_override("font_size", 12)
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
		# mission_history_detail_label.add_theme_font_size_override("normal_font_size", 12)
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
	# title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title_label)
	
	# Görev türü
	var type_label = Label.new()
	type_label.text = mission.get_mission_type_name()
	# type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	hbox.add_child(type_label)
	
	# Süre
	var duration_label = Label.new()
	duration_label.text = "%.1fs" % mission.duration
	# duration_label.add_theme_font_size_override("font_size", 12)
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
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 64)
	var vb := VBoxContainer.new()
	panel.add_child(vb)

	var title := Label.new()
	title.text = "🧭 " + String(chain_info.get("name", chain_id))
	vb.add_child(title)

	var progress: Dictionary = mission_manager.get_chain_progress(chain_id)
	var prog_label := Label.new()
	prog_label.text = "İlerleme: %d/%d (%.0f%%)" % [int(progress.get("completed",0)), int(progress.get("total",0)), float(progress.get("percentage",0.0))]
	vb.add_child(prog_label)

	# Adımlar
	var steps := HBoxContainer.new()
	steps.custom_minimum_size = Vector2(0, 24)
	vb.add_child(steps)
	var missions_in_chain: Array = mission_manager.get_chain_missions(chain_id)
	for mid in missions_in_chain:
		var m = mission_manager.missions.get(mid, null)
		if m != null:
			var badge := Label.new()
			var st: int = 0
			if ("status" in m):
				st = int(m.status)
			var icon: String = "⏳" if st == 1 else ("✔" if st == 2 else "•")
			badge.text = icon + " " + String(m.name)
			steps.add_child(badge)

	return panel

# --- Diplomasi Paneli Oluşturma ve Güncelleme ---
func _ensure_diplomacy_panel() -> void:
	if diplomacy_panel != null:
		return
	if diplomacy_page == null:
		return
	# Tam sayfa diplomasi paneli
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE)
	margin.add_theme_constant_override("margin_left", 220) # Arttırıldı (UI güncellemelerine uygun)
	margin.add_theme_constant_override("margin_top", 130) # Header yüksekliği
	margin.add_theme_constant_override("margin_right", 220) # Arttırıldı
	margin.add_theme_constant_override("margin_bottom", 120)
	diplomacy_page.add_child(margin)

	diplomacy_panel = VBoxContainer.new()
	diplomacy_panel.name = "DiplomacyPanel"
	margin.add_child(diplomacy_panel)
	
	# Header (Title) Container - Centered
	var header_box = HBoxContainer.new()
	header_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	diplomacy_panel.add_child(header_box)
	
	# Title Panel (Frame)
	var title_panel = PanelContainer.new()
	# Tema yüklenmiş varsayıyoruz veya manuel stil uygulayabiliriz. 
	# Ancak en temiz yol global temayı kullanmasıdır. 
	# PanelContainer varsayılan olarak temadan stil çeker.
	header_box.add_child(title_panel)

	var title := Label.new()
	title.text = "🤝 DİPLOMASİ"
	# title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_panel.add_child(title)
	
	# Spacer to push content down
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 30
	diplomacy_panel.add_child(spacer)
	
	# Action Squares Container (Center for alignment)
	var actions_center = CenterContainer.new()
	diplomacy_panel.add_child(actions_center)
	
	diplomacy_actions_container = HBoxContainer.new()
	diplomacy_actions_container.add_theme_constant_override("separation", 20)
	actions_center.add_child(diplomacy_actions_container)
	
	# Action Info Label
	diplomacy_info_label = Label.new()
	diplomacy_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diplomacy_info_label.text = "..."
	# diplomacy_info_label.add_theme_font_size_override("font_size", 14)
	diplomacy_panel.add_child(diplomacy_info_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diplomacy_panel.add_child(scroll)

	# İçeriği ortalamak için CenterContainer
	var center_cont = CenterContainer.new()
	center_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center_cont)

	diplomacy_list = VBoxContainer.new()
	diplomacy_list.custom_minimum_size.x = 600 # Genişlik vererek ortalanmış sütun oluştur
	diplomacy_list.add_theme_constant_override("separation", 10)
	center_cont.add_child(diplomacy_list)

	diplomacy_action_label = Label.new()
	diplomacy_action_label.text = "[Yukarı/Aşağı] Fraksiyon • [Sol/Sağ] Eylem • [A] Uygula • [B] Geri"
	diplomacy_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# diplomacy_action_label.add_theme_font_size_override("font_size", 11)
	diplomacy_panel.add_child(diplomacy_action_label)

func _update_trade_diplomacy_visibility() -> void:
	if trade_page:
		trade_page.visible = (current_page == PageType.TRADE)
	if diplomacy_page:
		diplomacy_page.visible = (current_page == PageType.DIPLOMACY)

func _update_diplomacy_ui() -> void:
	_update_diplomacy_action_squares()
	_update_diplomacy_action_info()

	if diplomacy_list == null:
		return
	for c in diplomacy_list.get_children():
		c.queue_free()
	var wm = _get_world_manager()
	if wm == null:
		var info := Label.new()
		info.text = "WorldManager bulunamadı. Diplomasi verisi mevcut değil."
		info.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		diplomacy_list.add_child(info)
		_update_diplomacy_footer()
		return
	var factions: Array = []
	if ("factions" in wm):
		if wm.factions is Array:
			factions = wm.factions
		elif wm.factions is Dictionary:
			factions = wm.factions.keys()
	if current_diplomacy_index >= factions.size():
		current_diplomacy_index = max(0, factions.size() - 1)
	if factions.is_empty():
		var empty := Label.new()
		empty.text = "Henüz tanımlı fraksiyon yok."
		empty.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		diplomacy_list.add_child(empty)
		_update_diplomacy_footer()
		return
		
	var visible_index = 0
	for f in factions:
		if String(f) == "Köy":
			continue
			
		# Kart yapısı (PanelContainer)
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 60)
		
		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		
		# Seçim durumuna göre stil
		if visible_index == current_diplomacy_index:
			style.bg_color = Color(0.2, 0.18, 0.15, 1.0) # Seçili (hafif açık kahve)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = Color(0.6, 0.5, 0.3, 1) # Gold/Bronz
		else:
			style.bg_color = Color(0.15, 0.13, 0.1, 0.85) # Normal
			# Normal durumda kenarlık yok veya çok ince olabilir
			
		card.add_theme_stylebox_override("panel", style)
		diplomacy_list.add_child(card)
		visible_index += 1
		
		# İçerik
		var row := HBoxContainer.new()
		card.add_child(row)
		
		var name_lbl := Label.new()
		name_lbl.text = " " + String(f) # Biraz boşluk
		name_lbl.custom_minimum_size.x = 150
		row.add_child(name_lbl)
		
		var rel_val := 0
		if wm.has_method("get_relation"):
			rel_val = wm.get_relation("Köy", String(f))
			
		var bar := ProgressBar.new()
		bar.min_value = -100
		bar.max_value = 100
		bar.value = rel_val
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size.y = 20
		row.add_child(bar)
		
		# stance label
		var stance := Label.new()
		var dm = _get_diplomacy_manager()
		if dm and dm.has_method("get_stance"):
			stance.text = " " + dm.get_stance(rel_val) + " "
			stance.add_theme_color_override("font_color", Color.LIGHT_BLUE)
		row.add_child(stance)
		
	_update_diplomacy_footer()

func _update_diplomacy_action_squares() -> void:
	if diplomacy_actions_container == null:
		return
	
	for c in diplomacy_actions_container.get_children():
		c.queue_free()
		
	var actions = ["🎁 Hediye", "☠️ Tehdit", "💰 Ticaret", "🛡️ Geçiş"]
	
	for i in range(actions.size()):
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(80, 80) # Kare boyutları
		
		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		
		if i == current_diplomacy_action:
			style.bg_color = Color(0.3, 0.25, 0.2, 1.0) # Seçili
			style.border_color = Color(0.9, 0.8, 0.2, 1.0) # Gold
		else:
			style.bg_color = Color(0.15, 0.13, 0.1, 0.8) # Normal
			style.border_color = Color(0.4, 0.35, 0.3, 1.0) # Bronz
			
		panel.add_theme_stylebox_override("panel", style)
		diplomacy_actions_container.add_child(panel)
		
		var lbl = Label.new()
		lbl.text = actions[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(lbl)

func _update_diplomacy_action_info() -> void:
	if diplomacy_info_label == null:
		return
		
	# Seçili fraksiyonu bul
	var target_faction_name = ""
	var wm = _get_world_manager()
	if wm:
		var factions = []
		if ("factions" in wm):
			if wm.factions is Array: factions = wm.factions
			elif wm.factions is Dictionary: factions = wm.factions.keys()
		
		# Köy'ü çıkar
		var filtered_factions = []
		for f in factions:
			if String(f) != "Köy":
				filtered_factions.append(String(f))
				
		if current_diplomacy_index < filtered_factions.size():
			target_faction_name = filtered_factions[current_diplomacy_index]
			
	if target_faction_name == "":
		diplomacy_info_label.text = "Fraksiyon seçiniz."
		return
		
	var info_text = ""
	match current_diplomacy_action:
		0: # Gift
			info_text = "Eylem: %s'a Hediye Gönder | Maliyet: 100 Altın | Sonuç: +10 İlişki" % target_faction_name
		1: # Threat
			info_text = "Eylem: %s'ı Tehdit Et | Maliyet: Yok | Sonuç: -15 İlişki (Riskli)" % target_faction_name
		2: # Trade
			info_text = "Eylem: %s ile Ticaret Anlaşması | Gereksinim: +20 İlişki | Sonuç: Ticaret Rotası Açılır" % target_faction_name
		3: # Passage
			info_text = "Eylem: %s'dan Geçiş İzni İste | Gereksinim: +50 İlişki | Sonuç: Topraklardan Geçiş İzni" % target_faction_name
			
	diplomacy_info_label.text = info_text

func _get_world_manager():
	var wm = get_node_or_null("/root/WorldManager")
	if wm != null:
		return wm
	# Autoload yoksa temin etmeyi dene
	var wm_res = load("res://autoload/WorldManager.gd")
	if wm_res == null:
		return null
	var inst = wm_res.new()
	inst.name = "WorldManager"
	# Root'a ekle
	get_tree().get_root().add_child(inst)
	return inst

func _get_diplomacy_manager():
	if diplomacy_manager != null and is_instance_valid(diplomacy_manager):
		return diplomacy_manager
	var dm = get_node_or_null("/root/DiplomacyManager")
	if dm != null:
		diplomacy_manager = dm
		return dm
	var dm_res = load("res://autoload/DiplomacyManager.gd")
	if dm_res == null:
		return null
	var inst = dm_res.new()
	inst.name = "DiplomacyManager"
	get_tree().get_root().add_child(inst)
	diplomacy_manager = inst
	return inst

func _on_relation_changed(a: String, b: String, value: int) -> void:
	if current_page == PageType.DIPLOMACY:
		_update_diplomacy_ui()

func _on_world_event_started(event_data: Dictionary) -> void:
	if current_page == PageType.DIPLOMACY:
		_update_diplomacy_ui()


func _update_diplomacy_footer() -> void:
	if diplomacy_action_label:
		var dm = _get_diplomacy_manager()
		var key := "gift"
		if current_diplomacy_action == 1:
			key = "threat"
		elif current_diplomacy_action == 2:
			key = "trade_agreement"
		elif current_diplomacy_action == 3:
			key = "passage"
		var action_name := key
		if dm and dm.has_method("get_action_label"):
			action_name = dm.get_action_label(key)
		diplomacy_action_label.text = "[Sol/Sağ] Eylem: %s | [A] Uygula | [B] Geri" % action_name

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
	
	# Windows tuşunu filtrele - hiçbir şey yapmasın
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.meta_pressed or key_event.keycode == KEY_META or key_event.physical_keycode == KEY_META:
			return
	
	# ESC ve Dodge tuşu ile geri gitme (basılı tutma desteği)
	# Önce açık alt pop-up'ları kapat (B tuşu tek basışta pop-up'ı kapatsın)
	var back_or_dash = event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back") or event.is_action_pressed("dash")
	if back_or_dash:
		if trader_mission_quantity_popup_open:
			_close_trader_mission_quantity_popup()
			return
		if trader_mission_popup_open:
			_close_trader_mission_popup()
			return
		if trader_buy_popup_open:
			_close_trader_buy_popup()
			return
	
	var should_close := false
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		# Windows tuşunu kontrol et
		if event is InputEventKey:
			var key_event = event as InputEventKey
			if not (key_event.meta_pressed or key_event.keycode == KEY_META or key_event.physical_keycode == KEY_META):
				should_close = true
		else:
			should_close = true
	
	if event.is_action_pressed("dash"):
		should_close = true
	
	if should_close:
		b_button_pressed = true
		b_button_timer = 0.0
		handle_back_button()
		return
	
	if event.is_action_released("ui_cancel") or event.is_action_released("ui_back") or event.is_action_released("dash"):
		b_button_pressed = false
	
	# L2/R2 ile sayfa değiştirme
	# Her iki aksiyon adını da destekle (proje: l2_trigger/r2_trigger)
	if event.is_action_pressed("ui_page_left") or InputManager.is_ui_page_left_just_pressed():
		print("=== L2 TRIGGER ===")
		previous_page()
		return
	if event.is_action_pressed("ui_page_right") or InputManager.is_ui_page_right_just_pressed():
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
		PageType.DIPLOMACY:
			# DİPLOMASİ kontrolleri
			handle_diplomacy_input(event)

# Diplomasi Sayfası Kontrolleri
func handle_diplomacy_input(event):
	# D-Pad debounce kontrolü
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		if dpad_debounce_timer > 0:
			return
		dpad_debounce_timer = dpad_debounce_delay
	
	var wm = _get_world_manager()
	var factions = []
	if wm and ("factions" in wm):
		if wm.factions is Array:
			factions = wm.factions
		elif wm.factions is Dictionary:
			factions = wm.factions.keys()
	
	# "Köy" fraksiyonunu filtrele (UI'da göstermediğimiz için)
	var visible_factions = []
	for f in factions:
		if String(f) != "Köy":
			visible_factions.append(f)
	
	if visible_factions.is_empty():
		return

	# Yukarı/Aşağı: Fraksiyon Seçimi
	if event.is_action_pressed("ui_up"):
		current_diplomacy_index = (current_diplomacy_index - 1) % visible_factions.size()
		if current_diplomacy_index < 0:
			current_diplomacy_index = visible_factions.size() - 1
		_update_diplomacy_ui()
		return
	elif event.is_action_pressed("ui_down"):
		current_diplomacy_index = (current_diplomacy_index + 1) % visible_factions.size()
		_update_diplomacy_ui()
		return
		
	# Sol/Sağ: Eylem Seçimi (0-3)
	if event.is_action_pressed("ui_left"):
		current_diplomacy_action = (current_diplomacy_action - 1) % 4
		if current_diplomacy_action < 0: current_diplomacy_action = 3
		_update_diplomacy_ui()
		return
	elif event.is_action_pressed("ui_right"):
		current_diplomacy_action = (current_diplomacy_action + 1) % 4
		_update_diplomacy_ui()
		return
		
	# A: Uygula
	if event.is_action_pressed("ui_accept"):
		if visible_factions.size() > current_diplomacy_index:
			var target_faction = visible_factions[current_diplomacy_index]
			_apply_diplomacy_action(target_faction)
		return

func _apply_diplomacy_action(target_faction_name: String) -> void:
	var wm = _get_world_manager()
	if wm == null: return
	
	match current_diplomacy_action:
		0: # Gift
			var cost = 100
			var vm = get_node_or_null("/root/VillageManager")
			if vm and vm.get_resource_level("gold") >= cost:
				vm.add_resource("gold", -cost)
				wm.change_relation("Köy", target_faction_name, 10)
				print("Hediye gönderildi: %s (+10 ilişki)" % target_faction_name)
			else:
				print("Yetersiz altın!")
		1: # Threat
			wm.change_relation("Köy", target_faction_name, -15)
			print("Tehdit edildi: %s (-15 ilişki)" % target_faction_name)
		2: # Trade Agreement
			# Basit bir implementasyon, normalde daha karmaşık olur
			if wm.get_relation("Köy", target_faction_name) > 20:
				print("Ticaret anlaşması teklif edildi: %s" % target_faction_name)
			else:
				print("İlişkiler yetersiz!")
		3: # Passage
			if wm.get_relation("Köy", target_faction_name) > 50:
				print("Geçiş izni istendi: %s" % target_faction_name)
			else:
				print("İlişkiler yetersiz!")
	
	_update_diplomacy_ui()

# Atama sayfası kontrolleri
func handle_assignment_input(event):
	# Asker ekipman menüsü için özel input handler
	if current_assignment_menu_state == AssignmentMenuState.ASKER_EKİPMAN:
		handle_soldier_equipment_input(event)
		return
	
	# D-Pad debounce kontrolü
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		if dpad_debounce_timer > 0:
			return
		dpad_debounce_timer = dpad_debounce_delay
	
	if current_assignment_menu_state == AssignmentMenuState.BİNA_LISTESİ:
		# Pop-up açıksa önce pop-up'ı kapat
		if barracks_equipment_popup_active:
			handle_barracks_equipment_popup_input(event)
			return
		
		var all_buildings = get_all_available_buildings()
		if all_buildings.is_empty():
			return
			
		var total = all_buildings.size()
		var grid_cols = 6
		
		# --- Navigasyon ---
		if event.is_action_pressed("ui_left"):
			current_assignment_building_index = (current_assignment_building_index - 1) % total
			if current_assignment_building_index < 0: current_assignment_building_index = total - 1
			update_assignment_ui()
			return
		elif event.is_action_pressed("ui_right"):
			current_assignment_building_index = (current_assignment_building_index + 1) % total
			update_assignment_ui()
			return
		elif event.is_action_pressed("ui_up"):
			var new_idx = current_assignment_building_index - grid_cols
			if new_idx >= 0:
				current_assignment_building_index = new_idx
			update_assignment_ui()
			return
		elif event.is_action_pressed("ui_down"):
			var new_idx = current_assignment_building_index + grid_cols
			if new_idx < total:
				current_assignment_building_index = new_idx
			update_assignment_ui()
			return
			
		# --- Eylemler ---
		# Jump (Zıplama) -> İşçi Ekle
		if event.is_action_pressed("jump"):
			print("=== JUMP: İşçi Ekleniyor ===")
			add_worker_to_building(all_buildings[current_assignment_building_index])
			update_assignment_ui()
			return
			
		# Attack (Saldırı) -> İşçi Çıkar
		if event.is_action_pressed("attack"):
			print("=== ATTACK: İşçi Çıkarılıyor ===")
			remove_worker_from_building(all_buildings[current_assignment_building_index])
			update_assignment_ui()
			return
			
		# Attack Heavy (Özel Vuruş) -> Detay
		if event.is_action_pressed("attack_heavy"):
			print("=== SPECIAL: Detay Gösteriliyor ===")
			handle_assignment_building_detail()
			return
	
	elif current_assignment_menu_state == AssignmentMenuState.BİNA_DETAYI:
		# B tuşu ile geri dön
		if event.is_action_pressed("ui_back") or event.is_action_pressed("ui_cancel"):
			current_assignment_menu_state = AssignmentMenuState.BİNA_LISTESİ
			update_assignment_ui()
		# A tuşu ile detay göster (sadece kışla olmayan binalar için)
		elif event.is_action_pressed("ui_accept"):
			handle_assignment_building_detail()
	
	elif current_assignment_menu_state == AssignmentMenuState.ASKER_EKİPMAN:
		handle_soldier_equipment_input(event)

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
	
	# Cariye seçimi görünümünde sol/sağ ile yanında götürülecek asker sayısı (0..max)
	if current_mission_menu_state == MissionMenuState.CARİYE_SEÇİMİ:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			if dpad_debounce_timer > 0:
				return
			dpad_debounce_timer = dpad_debounce_delay
			var max_soldiers = _get_available_soldier_count()
			if event.is_action_pressed("ui_left"):
				current_soldier_count = max(0, current_soldier_count - 1)
			else:
				current_soldier_count = min(max_soldiers, current_soldier_count + 1)
			update_missions_ui()
			return

	# Asker seçimi görünümünde sol/sağ ile asker sayısı ayarı (raid için eski akış, artık cariye ekranında yapılıyor)
	if current_mission_menu_state == MissionMenuState.ASKER_SEÇİMİ:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			if dpad_debounce_timer > 0:
				return
			dpad_debounce_timer = dpad_debounce_delay
			var max_soldiers = _get_available_soldier_count()
			if event.is_action_pressed("ui_left"):
				current_soldier_count = max(1, current_soldier_count - 1)
			else:
				current_soldier_count = min(max_soldiers, current_soldier_count + 1)
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
			var available_missions = _get_merged_available_missions()
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
		MissionMenuState.ASKER_SEÇİMİ:
			# Sol/Sağ: Asker sayısını ayarla
			print("⚔️ Asker seçimi - Mevcut sayı: %d" % current_soldier_count)
			var max_soldiers = _get_available_soldier_count()
			current_soldier_count = max(1, current_soldier_count - 1)
			print("⚔️ Yeni asker sayısı: %d" % current_soldier_count)
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
			var available_missions = _get_merged_available_missions()
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
		MissionMenuState.ASKER_SEÇİMİ:
			# Sol/Sağ: Asker sayısını ayarla
			print("⚔️ Asker seçimi - Mevcut sayı: %d" % current_soldier_count)
			var max_soldiers = _get_available_soldier_count()
			current_soldier_count = min(max_soldiers, current_soldier_count + 1)
			print("⚔️ Yeni asker sayısı: %d" % current_soldier_count)
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
			# Görev seçildi, cariye seçimine geç (asker sayısı cariye ekranında sol/sağ ile ayarlanır)
			var available_missions = _get_merged_available_missions()
			if not available_missions.is_empty() and current_mission_index < available_missions.size():
				current_mission_menu_state = MissionMenuState.CARİYE_SEÇİMİ
				current_cariye_index = 0
				current_soldier_count = 0  # Varsayılan 0; sol/sağ ile artırılır
				update_missions_ui()
		MissionMenuState.CARİYE_SEÇİMİ:
			# Cariye seçildi, görevi seçilen asker sayısıyla ata (sol/sağ ile ayarlandı)
			assign_selected_mission_with_soldiers()
		MissionMenuState.ASKER_SEÇİMİ:
			# Asker sayısı seçildi, görevi ata
			assign_selected_mission_with_soldiers()
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

# Seçili görevi asker sayısıyla ata
func assign_selected_mission_with_soldiers():
	var available_missions = _get_merged_available_missions()
	var idle_cariyeler = mission_manager.get_idle_concubines()
	
	if available_missions.is_empty() or idle_cariyeler.is_empty():
		return
	
	if current_mission_index >= available_missions.size() or current_cariye_index >= idle_cariyeler.size():
		return
	
	var mission = available_missions[current_mission_index]
	var cariye = idle_cariyeler[current_cariye_index]
	var mid: String = _mission_id_text(mission)
	if mid.is_empty():
		return
	
	print("=== GÖREV ATAMA DEBUG (ASKERLERLE) ===")
	print("Görev: %s (ID: %s)" % [_mission_display_name(mission), mid])
	print("Cariye: %s (ID: %d)" % [cariye.name, cariye.id])
	print("Asker sayısı: %d" % current_soldier_count)
	
	# MissionManager'a görev ata (asker sayısıyla)
	var success = mission_manager.assign_mission_to_concubine(cariye.id, mid, current_soldier_count)
	
	if success:
		print("✅ Görev başarıyla atandı!")
		# Görev listesine geri dön
		current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
		current_soldier_count = 0
		update_missions_ui()
	else:
		print("❌ Görev atanamadı!")
	
	print("========================")

# Mevcut asker sayısını al (görevde olan askerler düşülür; 4 asker varken 2 görevdeyse en fazla 2 atanabilir)
func _get_available_soldier_count() -> int:
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		return 0
	
	var barracks = mm._find_barracks()
	if not barracks or not "assigned_workers" in barracks:
		return 0
	
	var total = barracks.assigned_workers
	var on_mission = mm.get_total_soldiers_on_mission()
	var available = max(0, total - on_mission)
	print("[RAID_DEBUG] _get_available_soldier_count: total=%d on_mission=%d available=%d" % [total, on_mission, available])
	return available

# Seçili görevi ata
func assign_selected_mission():
	var available_missions = _get_merged_available_missions()
	var idle_cariyeler = mission_manager.get_idle_concubines()
	
	if available_missions.is_empty() or idle_cariyeler.is_empty():
				return

	if current_mission_index >= available_missions.size() or current_cariye_index >= idle_cariyeler.size():
				return
	
	var mission = available_missions[current_mission_index]
	var cariye = idle_cariyeler[current_cariye_index]
	var mid2: String = _mission_id_text(mission)
	if mid2.is_empty():
		return
	
	print("=== GÖREV ATAMA DEBUG ===")
	print("Görev: %s (ID: %s)" % [_mission_display_name(mission), mid2])
	print("Cariye: %s (ID: %d)" % [cariye.name, cariye.id])
	
	# MissionManager'a görev ata
	var success = mission_manager.assign_mission_to_concubine(cariye.id, mid2)
	
	if success:
		print("✅ Görev başarıyla atandı!")
		# Görev listesine geri dön
		current_mission_menu_state = MissionMenuState.GÖREV_LISTESİ
		# current_mission_index = 0  # Index'i sıfırlama - kullanıcının seçimini koru
		update_missions_ui()
	else:
		print("❌ Görev atanamadı!")
	
	print("========================")

# İnşaat sayfası kontrolleri (v2)
func handle_construction_input_v2(event):
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
				var buildings = building_categories.get(current_building_category, [])
				if not buildings.is_empty():
					print("⬆️ Yukarı D-Pad - Bina: %d -> %d" % [current_building_index, max(0, current_building_index - 1)])
					current_building_index = max(0, current_building_index - 1)
					update_construction_ui()
			elif event.is_action_pressed("ui_down"):
				var buildings = building_categories.get(current_building_category, [])
				if not buildings.is_empty():
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
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			# A veya B tuşu: Kapat
			_news_close_detail()
			return
	if event.is_action_pressed("ui_left"):
		if dpad_debounce_timer > 0:
			return
		dpad_debounce_timer = dpad_debounce_delay
		news_focus = "village" if news_focus == "world" else ("world" if news_focus == "random" else "village")
		_news_refresh_selection_visual()
		_update_news_filter_bar_visual()
		_update_news_subcategory_bar_visual()
		return
	if event.is_action_pressed("ui_right"):
		if dpad_debounce_timer > 0:
			return
		dpad_debounce_timer = dpad_debounce_delay
		news_focus = "world" if news_focus == "village" else ("random" if news_focus == "world" else "random")
		_news_refresh_selection_visual()
		_update_news_filter_bar_visual()
		_update_news_subcategory_bar_visual()
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
	# Hepsini okundu işaretle (Y veya Triangle benzeri - ui_select already used; use ui_focus_next?)
	if event.is_action_pressed("mark_all_read"):
		var mm = get_node_or_null("/root/MissionManager")
		if mm and mm.has_method("mark_all_news_read"):
			mm.mark_all_news_read("all")
			_update_unread_badge()
			# UI yenile
			update_news_ui()
		return
	# Alt kategori değişimi: X/Square (ui_select)
	if event.is_action_pressed("ui_select"):
		var order = ["all", "critical", "info", "success", "warning"]
		var idx = order.find(current_subcategory)
		if idx == -1:
			idx = 0
		idx = (idx + 1) % order.size()
		current_subcategory = order[idx]
		_update_news_subcategory_bar_visual()
		update_news_ui()

func _on_news_posted(news: Dictionary):
	# Tek kaynak: MissionManager.post_news kuyrukları (yinelenen giriş yapılmaz)
	var is_village = news.get("category", "") in ["Başarı", "Bilgi"]
	print("📰 ===== YENİ HABER DEBUG =====")
	print("📰 Yeni haber geldi: ", news.get("title", "Başlık yok"), " | Village: ", is_village)
	print("📰 Mevcut sayfa: ", current_page, " | NEWS sayfası mı: ", current_page == PageType.NEWS)

	# Sadece haber sayfasındaysak UI'ya ekle
	if current_page == PageType.NEWS:
		print("📰 ✅ Haber sayfasındayız, UI'ya ekleniyor...")
		if is_village:
			var list_node: VBoxContainer = get_node_or_null("NewsCenterPage/NewsContent/VillageNewsPanel/VillageNewsScroll/VillageNewsList")
			if list_node:
				var card = create_news_card(news)
				list_node.add_child(card)
				print("📰 ✅ Village haber kartı eklendi")
			else:
				print("📰 ❌ Village list node bulunamadı!")
		else:
			var list_node2: VBoxContainer = get_node_or_null("NewsCenterPage/NewsContent/WorldNewsPanel/WorldNewsScroll/WorldNewsList")
			if list_node2:
				var card2 = create_news_card(news)
				list_node2.add_child(card2)
				print("📰 ✅ World haber kartı eklendi")
			else:
				print("📰 ❌ World list node bulunamadı!")
		_news_refresh_selection_visual()
	else:
		print("📰 ⚠️ Haber sayfasında değiliz, UI'ya eklenmedi")
	print("📰 ===== YENİ HABER DEBUG BİTTİ =====")
	# Unread badge güncelle
	_update_unread_badge()

# ESKİ OVERLAY SİSTEMİ KALDIRILDI - Artık ticaret sekmesi kullanılıyor
# Bu fonksiyonlar yeni sistemde kullanılmıyor

# Cariye detay sayfası kontrolleri
func handle_concubine_details_input(event):
	# Rol atama pop-up'ı açıkken özel input handling
	if current_concubine_role_popup_open:
		handle_concubine_role_popup_input(event)
		return
	
	# Not: just_pressed kullanarak hassas tekrarı önle
	if Input.is_action_just_pressed("ui_up"):
		print("[ConcubineDetails] UP pressed")
		# Cariye yukarı
		var concubine_count = _get_concubines_sorted_by_name().size()
		if concubine_count > 0:
			current_concubine_detail_index = max(0, current_concubine_detail_index - 1)
			update_concubine_details_ui()
	elif Input.is_action_just_pressed("ui_down"):
		print("[ConcubineDetails] DOWN pressed")
		# Cariye aşağı
		var concubine_count = _get_concubines_sorted_by_name().size()
		if concubine_count > 0:
			current_concubine_detail_index = min(concubine_count - 1, current_concubine_detail_index + 1)
			update_concubine_details_ui()
	elif event.is_action_pressed("ui_accept"):  # A tuşu
		# Rol atama pop-up'ını aç
		open_concubine_role_popup()

# --- TİCARET SAYFASI ---
func handle_trade_input(event):
	# Pop-up açıksa SADECE pop-up input'larını işle, diğerlerini engelle
	if trader_buy_popup_open:
		var handled = handle_trader_buy_popup_input(event)
		if handled:
			return
		# Pop-up açıkken diğer input'ları engelle
		return
	
	# Tüccar cariye görev pop-up açıksa (önce miktar alt pop-up kontrolü)
	if trader_mission_popup_open:
		if trader_mission_quantity_popup_open:
			var handled = handle_trader_mission_quantity_popup_input(event)
			if handled:
				return
		var handled = handle_trader_mission_popup_input(event)
		if handled:
			return
		# Pop-up açıkken diğer input'ları engelle
		return
	
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
			current_trader_mission_index = max(0, current_trader_mission_index - 1)
		update_trade_ui()
		return
	# DOWN
	if event.is_action_pressed("ui_down"):
		if event.is_echo() or not allow_step:
			return
		dpad_debounce_timer = dpad_debounce_delay
		if current_focus_panel == "active":
			var mm = get_node_or_null("/root/MissionManager")
			var size = active_traders.size() if mm else 0
			current_trade_index = min(max(0,size-1), current_trade_index + 1)
		else:
			var mm = get_node_or_null("/root/MissionManager")
			var trader_concubines = []
			if mm:
				for cariye in mm.concubines.values():
					if cariye.role == Concubine.Role.TÜCCAR and cariye.status == Concubine.Status.BOŞTA:
						trader_concubines.append(cariye)
			current_trader_mission_index = min(max(0,trader_concubines.size()-1), current_trader_mission_index + 1)
		update_trade_ui()
		_scroll_trade_selection()
		return
	if event.is_action_pressed("ui_accept"):
		if current_focus_panel == "active":
			_open_trader_buy_menu()
		else:
			_open_trader_mission_menu()
		return

func update_trade_ui():
	if current_page != PageType.TRADE:
		return
	
	# Sol panel: Gelen Tüccarlar
	var traders_list = get_node_or_null("TradePage/TradeContent/ActiveAgreementsPanel/ActiveAgreementsScroll/ActiveAgreementsList")
	# Sağ panel: Tüccar Cariye Görevleri (eski OffersPanel'i kullanıyoruz)
	var missions_list = get_node_or_null("TradePage/TradeContent/OffersPanel/OffersScroll/OffersList")
	
	# Navigation indices clamp
	if current_trade_index < 0:
		current_trade_index = 0
	if current_trader_mission_index < 0:
		current_trader_mission_index = 0
	
	# === SOL PANEL: GELEN TÜCCARLAR ===
	if traders_list:
		for c in traders_list.get_children():
			c.queue_free()
		
		var mm = get_node_or_null("/root/MissionManager")
		if mm and mm.has_method("get_active_traders"):
			active_traders = mm.get_active_traders()
			
			if active_traders.is_empty():
				var empty_label = Label.new()
				empty_label.text = "Şu anda köyde tüccar yok.\nTüccarlar zaman zaman köye gelecek."
				empty_label.add_theme_font_size_override("font_size", 14)
				empty_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
				traders_list.add_child(empty_label)
			else:
				for i in range(active_traders.size()):
					var trader = active_traders[i]
					var card = PanelContainer.new()
					card.custom_minimum_size = Vector2(0, 100)
					var style = StyleBoxFlat.new()
					style.corner_radius_top_left = 4
					style.corner_radius_top_right = 4
					style.corner_radius_bottom_left = 4
					style.corner_radius_bottom_right = 4
					
					if i == current_trade_index:
						style.border_width_left = 2
						style.border_width_top = 2
						style.border_width_right = 2
						style.border_width_bottom = 2
						style.border_color = Color(0.6, 0.5, 0.3, 1)
						style.bg_color = Color(0.2, 0.18, 0.15, 1.0)
					else:
						style.bg_color = Color(0.15, 0.13, 0.1, 0.85)
					
					card.add_theme_stylebox_override("panel", style)
					traders_list.add_child(card)
					
					var vb = VBoxContainer.new()
					card.add_child(vb)
					
					var title = Label.new()
					title.text = "💰 %s" % trader.get("name", "Tüccar")
					title.add_theme_font_size_override("font_size", 14)
					vb.add_child(title)
					
					var origin = Label.new()
					origin.text = "📍 %s'den geldi" % trader.get("origin_settlement", "?")
					origin.add_theme_font_size_override("font_size", 12)
					origin.add_theme_color_override("font_color", Color.LIGHT_GRAY)
					vb.add_child(origin)
					
					# Ürünler (her ürün ayrı satırda)
					var products = trader.get("products", [])
					if not products.is_empty():
						var products_title = Label.new()
						products_title.text = "Satıyor:"
						products_title.add_theme_font_size_override("font_size", 11)
						products_title.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
						vb.add_child(products_title)
						
						# Her ürün için ayrı satır (max 2-3 ürün göster, fazlası için "...")
						var max_show = 3
						for idx in range(min(products.size(), max_show)):
							var p = products[idx]
							var res_name = _get_resource_display_name(p.get("resource", "?"))
							var price = p.get("price_per_unit", 0)
							var product_line = Label.new()
							product_line.text = "  • %s (%d altın)" % [res_name, price]
							product_line.add_theme_font_size_override("font_size", 10)
							product_line.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
							vb.add_child(product_line)
						
						if products.size() > max_show:
							var more_label = Label.new()
							more_label.text = "  ... ve %d ürün daha" % (products.size() - max_show)
							more_label.add_theme_font_size_override("font_size", 9)
							more_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
							vb.add_child(more_label)
					
					# Kalan günler
					var tm = get_node_or_null("/root/TimeManager")
					var current_day = tm.get_day() if (tm and tm.has_method("get_day")) else 0
					var leaves_day = trader.get("leaves_day", current_day + 1)
					var days_left = max(0, leaves_day - current_day)
					
					var days_label = Label.new()
					days_label.text = "⏳ %d gün sonra ayrılacak" % days_left
					days_label.add_theme_font_size_override("font_size", 10)
					days_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5))
					vb.add_child(days_label)
					
					var hint = Label.new()
					hint.text = "A: Ürünleri Gör" if i == current_trade_index else ""
					hint.add_theme_font_size_override("font_size", 10)
					hint.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
					vb.add_child(hint)
	
	# === SAĞ PANEL: TÜCCAR CARİYE GÖREVLERİ ===
	if missions_list:
		for c in missions_list.get_children():
			c.queue_free()
		
		# Tüccar rolündeki cariyeleri bul
		var mm = get_node_or_null("/root/MissionManager")
		if not mm:
			return
		
		var trader_concubines = []
		for cariye in mm.concubines.values():
			if cariye.role == Concubine.Role.TÜCCAR and cariye.status == Concubine.Status.BOŞTA:
				trader_concubines.append(cariye)
		
		if trader_concubines.is_empty():
			var empty_label = Label.new()
			empty_label.text = "Tüccar rolünde boşta cariye yok.\nCariye yönetiminden rol atayabilirsiniz."
			empty_label.add_theme_font_size_override("font_size", 14)
			empty_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
			missions_list.add_child(empty_label)
		else:
			# Yerleşimler listesi (ticaret görevleri için)
			var settlements = mm.settlements if mm else []
			if settlements.is_empty() and mm.has_method("create_settlements"):
				mm.create_settlements()
				settlements = mm.settlements if mm else []
			
			for i in range(trader_concubines.size()):
				var cariye = trader_concubines[i]
				var card = PanelContainer.new()
				card.custom_minimum_size = Vector2(0, 80)
				var style = StyleBoxFlat.new()
				style.corner_radius_top_left = 4
				style.corner_radius_top_right = 4
				style.corner_radius_bottom_left = 4
				style.corner_radius_bottom_right = 4
				
				if i == current_trader_mission_index:
					style.border_width_left = 2
					style.border_width_top = 2
					style.border_width_right = 2
					style.border_width_bottom = 2
					style.border_color = Color(0.6, 0.5, 0.3, 1)
					style.bg_color = Color(0.2, 0.18, 0.15, 1.0)
				else:
					style.bg_color = Color(0.15, 0.13, 0.1, 0.85)
				
				card.add_theme_stylebox_override("panel", style)
				missions_list.add_child(card)
				
				var vb = VBoxContainer.new()
				card.add_child(vb)
				
				var title = Label.new()
				title.text = "👤 %s (Tüccar)" % cariye.name
				title.add_theme_font_size_override("font_size", 14)
				vb.add_child(title)
				
				var info = Label.new()
				info.text = "Ticaret yeteneği: %d | Seviye: %d" % [cariye.get_skill_level(Concubine.Skill.TİCARET), cariye.level]
				info.add_theme_font_size_override("font_size", 12)
				info.add_theme_color_override("font_color", Color.LIGHT_GRAY)
				vb.add_child(info)
				
				var hint = Label.new()
				hint.text = "A: Görev Gönder" if i == current_trader_mission_index else ""
				hint.add_theme_font_size_override("font_size", 10)
				hint.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
				vb.add_child(hint)
	
	# Seçimler görünür kalsın
	_scroll_trade_selection()

# Kaynak isimlerini Türkçe'ye çevir
func _get_resource_display_name(resource: String) -> String:
	match resource:
		"food": return "Yemek"
		"wood": return "Odun"
		"stone": return "Taş"
		"water": return "Su"
		_: return resource.capitalize()

# ESKİ FONKSİYON KALDIRILDI - Artık tüccardan satın alma sistemi kullanılıyor

func _scroll_trade_selection():
	# Gelen Tüccarlar
	var traders_scroll: ScrollContainer = get_node_or_null("TradePage/TradeContent/ActiveAgreementsPanel/ActiveAgreementsScroll")
	var traders_list: VBoxContainer = get_node_or_null("TradePage/TradeContent/ActiveAgreementsPanel/ActiveAgreementsScroll/ActiveAgreementsList")
	if traders_scroll and traders_list and current_trade_index >= 0 and current_trade_index < traders_list.get_child_count():
		var ctrl := traders_list.get_child(current_trade_index)
		if ctrl is Control:
			traders_scroll.ensure_control_visible(ctrl)
	# Tüccar Cariye Görevleri
	var missions_scroll: ScrollContainer = get_node_or_null("TradePage/TradeContent/OffersPanel/OffersScroll")
	var missions_list: VBoxContainer = get_node_or_null("TradePage/TradeContent/OffersPanel/OffersScroll/OffersList")
	if missions_scroll and missions_list and current_trader_mission_index >= 0 and current_trader_mission_index < missions_list.get_child_count():
		var ctrl2 := missions_list.get_child(current_trader_mission_index)
		if ctrl2 is Control:
			missions_scroll.ensure_control_visible(ctrl2)

func _on_active_traders_updated():
	if current_page == PageType.TRADE:
		update_trade_ui()

# Tüccardan satın alma menüsü aç
func _open_trader_buy_menu():
	if current_trade_index < 0 or current_trade_index >= active_traders.size():
		return
	
	var trader = active_traders[current_trade_index]
	var products = trader.get("products", [])
	if products.is_empty():
		return
	
	selected_trader = trader
	current_trader_buy_index = 0
	
	# Pop-up oluştur veya göster
	if not trader_buy_popup:
		_create_trader_buy_popup()
	
	# Pop-up'ı göster ve aktif et
	trader_buy_popup_open = true
	if trader_buy_popup:
		trader_buy_popup.visible = true
		trader_buy_popup.z_index = 1000
		# Top-level değil, MissionCenter içinde olduğu için anchor'lar otomatik merkezler
		
		_update_trader_buy_popup()
		print("[TRADER_BUY] ✅ Pop-up açıldı: %s, Ürün sayısı: %d, Visible: %s" % [trader.get("name", "Tüccar"), products.size(), trader_buy_popup.visible])
	else:
		print("[TRADER_BUY] ❌ Pop-up oluşturulamadı!")

# Tüccar satın alma pop-up'ı oluştur
func _create_trader_buy_popup():
	# Pop-up'ı MissionCenter'a ekle (CanvasLayer içinde, diğer UI'lar gibi)
	trader_buy_popup = Panel.new()
	trader_buy_popup.name = "TraderBuyPopup"
	trader_buy_popup.custom_minimum_size = Vector2(800, 600)
	# Anchor'ları merkeze ayarla
	trader_buy_popup.anchor_left = 0.5
	trader_buy_popup.anchor_top = 0.5
	trader_buy_popup.anchor_right = 0.5
	trader_buy_popup.anchor_bottom = 0.5
	trader_buy_popup.offset_left = -400
	trader_buy_popup.offset_right = 400
	trader_buy_popup.offset_top = -300
	trader_buy_popup.offset_bottom = 300
	trader_buy_popup.visible = false  # Başlangıçta gizli
	trader_buy_popup.z_index = 1000  # En üstte görünsün
	trader_buy_popup.mouse_filter = Control.MOUSE_FILTER_STOP  # Mouse event'lerini yakala
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.6, 0.5, 0.3, 1)
	trader_buy_popup.add_theme_stylebox_override("panel", style)
	
	# MissionCenter'a ekle (top-level değil, CanvasLayer içinde)
	add_child(trader_buy_popup)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16
	vbox.offset_right = -16
	vbox.offset_top = 16
	vbox.offset_bottom = -16
	trader_buy_popup.add_child(vbox)
	
	# Başlık (dinamik olarak güncellenecek)
	var title_label = Label.new()
	title_label.name = "TraderBuyTitle"
	title_label.text = "💰 Tüccardan Satın Al"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	var origin_label = Label.new()
	origin_label.name = "TraderBuyOrigin"
	origin_label.text = "📍 Tüccar bilgisi"
	origin_label.add_theme_font_size_override("font_size", 14)
	origin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	origin_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(origin_label)
	
	# Grid Container
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	
	trader_buy_grid = GridContainer.new()
	trader_buy_grid.columns = TRADER_BUY_GRID_COLUMNS
	trader_buy_grid.add_theme_constant_override("h_separation", 10)
	trader_buy_grid.add_theme_constant_override("v_separation", 10)
	center.add_child(trader_buy_grid)
	
	# Alt bilgi
	var info_label = Label.new()
	info_label.name = "TraderBuyInfoLabel"
	info_label.text = "Yön Tuşları: Seçim  |  A: Satın Al  |  B: Kapat"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(info_label)

# Tüccar satın alma pop-up'ını güncelle
func _update_trader_buy_popup():
	if not trader_buy_popup or not trader_buy_grid:
		return
	
	# Başlık ve origin'i güncelle
	var title_label = trader_buy_popup.get_node_or_null("VBoxContainer/TraderBuyTitle")
	if title_label:
		title_label.text = "💰 Tüccardan Satın Al: %s" % selected_trader.get("name", "Tüccar")
	
	var origin_label = trader_buy_popup.get_node_or_null("VBoxContainer/TraderBuyOrigin")
	if origin_label:
		origin_label.text = "📍 %s'den geldi" % selected_trader.get("origin_settlement", "?")
	
	# Grid'i temizle
	for child in trader_buy_grid.get_children():
		child.queue_free()
	
	var products = selected_trader.get("products", [])
	if products.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Bu tüccarın satacak ürünü yok."
		trader_buy_grid.add_child(empty_label)
		return
	
	# Her ürün için grid item oluştur
	for i in range(products.size()):
		var product = products[i]
		var is_selected = (i == current_trader_buy_index)
		
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(180, 180)
		
		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		
		if is_selected:
			style.bg_color = Color(0.2, 0.18, 0.15, 1.0)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = Color(0.6, 0.5, 0.3, 1)
		else:
			style.bg_color = Color(0.15, 0.13, 0.1, 0.85)
		
		panel.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(vbox)
		
		# Ürün ikonu (emoji)
		var icon_label = Label.new()
		var resource = product.get("resource", "")
		icon_label.text = _get_resource_icon(resource)
		icon_label.add_theme_font_size_override("font_size", 48)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(icon_label)
		
		# Ürün ismi
		var name_label = Label.new()
		name_label.text = _get_resource_display_name(resource)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(name_label)
		
		# Fiyat
		var price_label = Label.new()
		var price = product.get("price_per_unit", 0)
		price_label.text = "%d altın/birim" % price
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 12)
		price_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
		vbox.add_child(price_label)
		
		# Miktar bilgisi (tüccarın elinde sınırsız varsayıyoruz)
		var stock_label = Label.new()
		stock_label.text = "Sınırsız"
		stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stock_label.add_theme_font_size_override("font_size", 10)
		stock_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		vbox.add_child(stock_label)
		
		# Seçim göstergesi ve miktar bilgisi
		if is_selected:
			var select_label = Label.new()
			select_label.text = "> SEÇİLİ <"
			select_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			select_label.add_theme_font_size_override("font_size", 10)
			select_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
			vbox.add_child(select_label)
			
			var quantity_label = Label.new()
			quantity_label.text = "1 birim satın alınacak"
			quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			quantity_label.add_theme_font_size_override("font_size", 9)
			quantity_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
			vbox.add_child(quantity_label)
		
		trader_buy_grid.add_child(panel)
	
	# Seçili item'ı görünür yap
	_ensure_trader_buy_selection_visible()

# Kaynak ikonu
func _get_resource_icon(resource: String) -> String:
	match resource:
		"food": return "🍞"
		"wood": return "🪵"
		"stone": return "🪨"
		"water": return "💧"
		_: return "📦"

# Seçili item'ı görünür yap
func _ensure_trader_buy_selection_visible():
	if not trader_buy_popup or not trader_buy_grid:
		return
	
	var scroll = trader_buy_popup.get_node_or_null("VBoxContainer/ScrollContainer")
	if not scroll:
		return
	
	var children = trader_buy_grid.get_children()
	if current_trader_buy_index >= 0 and current_trader_buy_index < children.size():
		var selected_panel = children[current_trader_buy_index]
		if selected_panel is Control:
			scroll.ensure_control_visible(selected_panel)

# Tüccar satın alma pop-up input handling
func handle_trader_buy_popup_input(event):
	if not trader_buy_popup_open or not trader_buy_popup:
		return false
	
	var products = selected_trader.get("products", [])
	if products.is_empty():
		return false
	
	var allow_step = dpad_debounce_timer <= 0
	
	# Grid navigasyonu
	if event.is_action_pressed("ui_left"):
		if event.is_echo() or not allow_step:
			return true
		dpad_debounce_timer = dpad_debounce_delay
		current_trader_buy_index = max(0, current_trader_buy_index - 1)
		_update_trader_buy_popup()
		return true
	elif event.is_action_pressed("ui_right"):
		if event.is_echo() or not allow_step:
			return true
		dpad_debounce_timer = dpad_debounce_delay
		current_trader_buy_index = min(products.size() - 1, current_trader_buy_index + 1)
		_update_trader_buy_popup()
		return true
	elif event.is_action_pressed("ui_up"):
		if event.is_echo() or not allow_step:
			return true
		dpad_debounce_timer = dpad_debounce_delay
		var new_index = current_trader_buy_index - TRADER_BUY_GRID_COLUMNS
		if new_index < 0:
			new_index = products.size() - 1
		current_trader_buy_index = new_index
		_update_trader_buy_popup()
		return true
	elif event.is_action_pressed("ui_down"):
		if event.is_echo() or not allow_step:
			return true
		dpad_debounce_timer = dpad_debounce_delay
		var new_index = current_trader_buy_index + TRADER_BUY_GRID_COLUMNS
		if new_index >= products.size():
			new_index = 0
		current_trader_buy_index = new_index
		_update_trader_buy_popup()
		return true
	elif event.is_action_pressed("ui_accept"):
		# Satın al
		_execute_trader_buy()
		return true
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		# Kapat (ESC veya Dodge tuşu)
		_close_trader_buy_popup()
		return true
	
	return false

# Tüccar satın alma işlemini gerçekleştir
func _execute_trader_buy():
	if selected_trader.is_empty():
		print("[TRADER_BUY] ❌ Seçili tüccar yok!")
		return
	
	var products = selected_trader.get("products", [])
	if products.is_empty():
		print("[TRADER_BUY] ❌ Tüccarın ürünü yok!")
		return
	
	if current_trader_buy_index < 0 or current_trader_buy_index >= products.size():
		print("[TRADER_BUY] ❌ Geçersiz ürün index'i: %d (Toplam: %d)" % [current_trader_buy_index, products.size()])
		return
	
	var product = products[current_trader_buy_index]
	var resource = product.get("resource", "")
	var price = product.get("price_per_unit", 0)
	var res_name = _get_resource_display_name(resource)
	
	print("[TRADER_BUY] Satın alınıyor: %d x %s (%d altın)" % [1, res_name, price])
	
	# Şimdilik 1 birim satın al (ileride miktar seçimi eklenebilir)
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("buy_from_trader"):
		var success = mm.buy_from_trader(selected_trader.get("id", ""), resource, 1)
		if success:
			print("[TRADER_BUY] ✅ Satın alma başarılı!")
			update_trade_ui()
			# Pop-up'ı kapatma, kullanıcı tekrar satın alabilir
			_update_trader_buy_popup()
		else:
			print("[TRADER_BUY] ❌ Satın alma başarısız!")
	else:
		print("[TRADER_BUY] ❌ MissionManager bulunamadı veya buy_from_trader metodu yok!")

# Tüccar satın alma pop-up'ını kapat
func _close_trader_buy_popup():
	trader_buy_popup_open = false
	if trader_buy_popup:
		trader_buy_popup.visible = false

# === TÜCCAR CARİYE GÖREV POP-UP SİSTEMİ ===

# Tüccar cariye görev pop-up'ı oluştur
func _create_trader_mission_popup():
	trader_mission_popup = Panel.new()
	trader_mission_popup.name = "TraderMissionPopup"
	trader_mission_popup.custom_minimum_size = Vector2(800, 600)
	trader_mission_popup.anchor_left = 0.5
	trader_mission_popup.anchor_top = 0.5
	trader_mission_popup.anchor_right = 0.5
	trader_mission_popup.anchor_bottom = 0.5
	trader_mission_popup.offset_left = -400
	trader_mission_popup.offset_right = 400
	trader_mission_popup.offset_top = -300
	trader_mission_popup.offset_bottom = 300
	trader_mission_popup.visible = false
	trader_mission_popup.z_index = 1000
	trader_mission_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.3, 0.6, 0.5, 1)  # Yeşilimsi renk (ticaret için)
	trader_mission_popup.add_theme_stylebox_override("panel", style)
	
	add_child(trader_mission_popup)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16
	vbox.offset_right = -16
	vbox.offset_top = 16
	vbox.offset_bottom = -16
	trader_mission_popup.add_child(vbox)
	
	# Başlık
	var title_label = Label.new()
	title_label.name = "TraderMissionTitle"
	title_label.text = "🚚 Ticaret Görevi Oluştur"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# Cariye bilgisi
	var cariye_label = Label.new()
	cariye_label.name = "TraderMissionCariye"
	cariye_label.text = "👤 Cariye: "
	cariye_label.add_theme_font_size_override("font_size", 14)
	cariye_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cariye_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(cariye_label)
	
	# İçerik alanı (scroll container)
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.name = "ContentVBox"
	scroll.add_child(content_vbox)
	
	# Alt bilgi
	var info_label = Label.new()
	info_label.name = "TraderMissionInfo"
	info_label.text = "Yön Tuşları: Seçim  |  A: Onayla  |  B: Geri/İptal"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(info_label)

# Tüccar cariye görev pop-up'ını güncelle
func _update_trader_mission_popup():
	if not trader_mission_popup or not trader_mission_selected_concubine:
		return
	
	var content_vbox = trader_mission_popup.get_node_or_null("VBoxContainer/ScrollContainer/ContentVBox")
	if not content_vbox:
		return
	
	# İçeriği temizle
	for child in content_vbox.get_children():
		child.queue_free()
	
	# Başlık ve cariye bilgisini güncelle
	var title_label = trader_mission_popup.get_node_or_null("VBoxContainer/TraderMissionTitle")
	if title_label:
		var step_names = ["📍 Köy Seçimi", "⚔️ Asker Sayısı", "📦 Ticaret Malları"]
		title_label.text = "🚚 Ticaret Görevi: %s" % step_names[trader_mission_step]
	
	var cariye_label = trader_mission_popup.get_node_or_null("VBoxContainer/TraderMissionCariye")
	if cariye_label:
		cariye_label.text = "👤 Cariye: %s" % trader_mission_selected_concubine.name
	
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		return
	
	match trader_mission_step:
		0:  # Köy seçimi
			_update_trader_mission_step_village(content_vbox, mm)
		1:  # Asker sayısı
			_update_trader_mission_step_soldiers(content_vbox)
		2:  # Mal seçimi
			_update_trader_mission_step_products(content_vbox)

# Adım 0: Köy seçimi
func _update_trader_mission_step_village(content_vbox: VBoxContainer, mm: Node):
	var routes = mm.get_active_trade_routes() if mm.has_method("get_active_trade_routes") else []
	
	if routes.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Aktif ticaret rotası yok!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_vbox.add_child(empty_label)
		return
	
	# Rotaları listele
	for i in range(routes.size()):
		var route = routes[i]
		var route_label = Label.new()
		var prefix = "> " if i == trader_mission_selected_route_index else "  "
		var route_name = "%s → %s" % [route.get("from_name", "?"), route.get("to_name", "?")]
		var distance = route.get("distance", 0.0)
		var risk = route.get("risk", "?")
		var relation = route.get("relation", 50)
		
		route_label.text = "%s%s (Mesafe: %.1f, Risk: %s, İlişki: %d)" % [prefix, route_name, distance, risk, relation]
		route_label.add_theme_font_size_override("font_size", 16)
		if i == trader_mission_selected_route_index:
			route_label.add_theme_color_override("font_color", Color.YELLOW)
		content_vbox.add_child(route_label)
	
	# Bilgi
	var info = Label.new()
	info.text = "\nYukarı/Aşağı: Rota Seç\nA: Devam Et"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	content_vbox.add_child(info)

# Adım 1: Asker sayısı
func _update_trader_mission_step_soldiers(content_vbox: VBoxContainer):
	var vm = get_node_or_null("/root/VillageManager")
	var max_soldiers = 0
	if vm:
		# Kışladaki asker sayısını al
		var all_buildings = get_all_available_buildings()
		for building_info in all_buildings:
			if building_info["type"] == "Kışla":
				var barracks = building_info["node"]
				# assigned_workers property'sini kullan (sayı döndürür)
				if "assigned_workers" in barracks:
					max_soldiers = barracks.assigned_workers
				# Alternatif: assigned_worker_ids.size() kullan
				elif "assigned_worker_ids" in barracks:
					max_soldiers = barracks.assigned_worker_ids.size()
				break
	
	var soldier_label = Label.new()
	soldier_label.text = "Asker Sayısı: %d / %d" % [trader_mission_soldier_count, max_soldiers]
	soldier_label.add_theme_font_size_override("font_size", 18)
	soldier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if trader_mission_soldier_count > 0:
		soldier_label.add_theme_color_override("font_color", Color.YELLOW)
	content_vbox.add_child(soldier_label)
	
	var info = Label.new()
	info.text = "\nSol/Sağ: Miktar Ayarla\nA: Devam Et"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	content_vbox.add_child(info)

# Adım 2: Mal seçimi
func _update_trader_mission_step_products(content_vbox: VBoxContainer):
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		return
	
	# Grid container oluştur
	var grid = GridContainer.new()
	grid.columns = TRADER_MISSION_PRODUCT_COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content_vbox.add_child(grid)
	
	# Her kaynak için grid item oluştur
	for i in range(TRADEABLE_RESOURCES.size()):
		var resource = TRADEABLE_RESOURCES[i]
		var available = vm.get_resource_level(resource) if vm.has_method("get_resource_level") else 0
		var selected_qty = trader_mission_selected_products.get(resource, 0)
		
		var item_panel = PanelContainer.new()
		var item_vbox = VBoxContainer.new()
		item_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		item_vbox.add_theme_constant_override("separation", 5)
		item_panel.add_child(item_vbox)
		
		# Seçili mi kontrolü
		var is_selected = (i == trader_mission_current_product_index)
		var panel_style = StyleBoxFlat.new()
		if is_selected:
			panel_style.bg_color = Color(0.2, 0.3, 0.2, 0.8)
			panel_style.border_width_left = 3
			panel_style.border_width_right = 3
			panel_style.border_width_top = 3
			panel_style.border_width_bottom = 3
			panel_style.border_color = Color.YELLOW
		else:
			panel_style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
		item_panel.add_theme_stylebox_override("panel", panel_style)
		item_panel.custom_minimum_size = Vector2(150, 120)
		
		# İkon (basit emoji)
		var icon_label = Label.new()
		var icon_map = {"wood": "🪵", "stone": "🪨", "food": "🍞", "water": "💧"}
		icon_label.text = icon_map.get(resource, "📦")
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 32)
		item_vbox.add_child(icon_label)
		
		# İsim
		var name_label = Label.new()
		var name_map = {"wood": "Odun", "stone": "Taş", "food": "Yiyecek", "water": "Su"}
		name_label.text = name_map.get(resource, resource)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		item_vbox.add_child(name_label)
		
		# Miktar
		var qty_label = Label.new()
		qty_label.text = "Seçili: %d / %d" % [selected_qty, available]
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label.add_theme_font_size_override("font_size", 12)
		if selected_qty > 0:
			qty_label.add_theme_color_override("font_color", Color.GREEN)
		item_vbox.add_child(qty_label)
		
		# Seçili işareti
		if is_selected:
			var selected_label = Label.new()
			selected_label.text = "> SEÇİLİ <"
			selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			selected_label.add_theme_color_override("font_color", Color.YELLOW)
			item_vbox.add_child(selected_label)
		
		grid.add_child(item_panel)
	
	# Bilgi
	var info = Label.new()
	info.text = "\nYön Tuşları: Ürün Seç  |  A: Miktar Ayarla  |  X: Görevi Başlat"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	content_vbox.add_child(info)
	selected_trader = {}
	current_trader_buy_index = 0
	print("[TRADER_BUY] Pop-up kapatıldı")

# Tüccar cariye görev menüsü aç
func _open_trader_mission_menu():
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		return
	
	var trader_concubines = []
	for cariye in mm.concubines.values():
		if cariye.role == Concubine.Role.TÜCCAR and cariye.status == Concubine.Status.BOŞTA:
			trader_concubines.append(cariye)
	
	if current_trader_mission_index < 0 or current_trader_mission_index >= trader_concubines.size():
		return
	
	var cariye = trader_concubines[current_trader_mission_index]
	
	# Pop-up menüyü aç
	trader_mission_selected_concubine = cariye
	trader_mission_step = 0
	trader_mission_selected_route_index = 0
	trader_mission_soldier_count = 0
	trader_mission_selected_products = {}
	trader_mission_current_product_index = 0
	
	if not trader_mission_popup:
		_create_trader_mission_popup()
	
	trader_mission_popup_open = true
	if trader_mission_popup:
		trader_mission_popup.visible = true
		_update_trader_mission_popup()
		print("[TRADER_MISSION] ✅ Pop-up açıldı: %s" % cariye.name)

# Tüccar cariye görev pop-up input handler
func handle_trader_mission_popup_input(event) -> bool:
	if not trader_mission_popup_open or not trader_mission_popup:
		return false
	
	var allow_step = dpad_debounce_timer <= 0
	
	match trader_mission_step:
		0:  # Köy seçimi
			return _handle_trader_mission_step_village_input(event, allow_step)
		1:  # Asker sayısı
			return _handle_trader_mission_step_soldiers_input(event, allow_step)
		2:  # Mal seçimi
			return _handle_trader_mission_step_products_input(event, allow_step)
	
	return false

# Adım 0 input handler
func _handle_trader_mission_step_village_input(event, allow_step: bool) -> bool:
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		return false
	
	var routes = mm.get_active_trade_routes() if mm.has_method("get_active_trade_routes") else []
	if routes.is_empty():
		return false
	
	if event.is_action_pressed("ui_up"):
		if event.is_echo() or not allow_step:
			return true
		dpad_debounce_timer = dpad_debounce_delay
		trader_mission_selected_route_index = max(0, trader_mission_selected_route_index - 1)
		_update_trader_mission_popup()
		return true
	elif event.is_action_pressed("ui_down"):
		if event.is_echo() or not allow_step:
			return true
		dpad_debounce_timer = dpad_debounce_delay
		trader_mission_selected_route_index = min(routes.size() - 1, trader_mission_selected_route_index + 1)
		_update_trader_mission_popup()
		return true
	elif event.is_action_pressed("ui_accept"):
		# Rota seçildi, bir sonraki adıma geç
		if trader_mission_selected_route_index < routes.size():
			trader_mission_selected_route = routes[trader_mission_selected_route_index]
			trader_mission_step = 1
			_update_trader_mission_popup()
		return true
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		_close_trader_mission_popup()
		return true
	
	return false

# Adım 1 input handler
func _handle_trader_mission_step_soldiers_input(event, allow_step: bool) -> bool:
	var vm = get_node_or_null("/root/VillageManager")
	var max_soldiers = 0
	if vm:
		var all_buildings = get_all_available_buildings()
		for building_info in all_buildings:
			if building_info["type"] == "Kışla":
				var barracks = building_info["node"]
				# assigned_workers property'sini kullan (sayı döndürür)
				if "assigned_workers" in barracks:
					max_soldiers = barracks.assigned_workers
				# Alternatif: assigned_worker_ids.size() kullan
				elif "assigned_worker_ids" in barracks:
					max_soldiers = barracks.assigned_worker_ids.size()
				break
	
	if event.is_action_pressed("ui_left"):
		if event.is_echo() or not allow_step:
			return true
		dpad_debounce_timer = dpad_debounce_delay
		trader_mission_soldier_count = max(0, trader_mission_soldier_count - 1)
		_update_trader_mission_popup()
		return true
	elif event.is_action_pressed("ui_right"):
		if event.is_echo() or not allow_step:
			return true
		dpad_debounce_timer = dpad_debounce_delay
		trader_mission_soldier_count = min(max_soldiers, trader_mission_soldier_count + 1)
		_update_trader_mission_popup()
		return true
	elif event.is_action_pressed("ui_accept"):
		# Asker sayısı seçildi, bir sonraki adıma geç
		trader_mission_step = 2
		_update_trader_mission_popup()
		return true
	elif event.is_action_pressed("ui_back"):
		# Önceki adıma dön
		trader_mission_step = 0
		_update_trader_mission_popup()
		return true
	elif event.is_action_pressed("ui_cancel"):
		_close_trader_mission_popup()
		return true
	
	return false

# Adım 2 input handler
func _handle_trader_mission_step_products_input(event, allow_step: bool) -> bool:
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		return false
	
	# Grid navigasyonu
	if event.is_action_pressed("ui_left"):
		if event.is_echo() or not allow_step:
			return true
		dpad_debounce_timer = dpad_debounce_delay
		trader_mission_current_product_index = max(0, trader_mission_current_product_index - 1)
		_update_trader_mission_popup()
		return true
	elif event.is_action_pressed("ui_right"):
		if event.is_echo() or not allow_step:
			return true
		dpad_debounce_timer = dpad_debounce_delay
		trader_mission_current_product_index = min(TRADEABLE_RESOURCES.size() - 1, trader_mission_current_product_index + 1)
		_update_trader_mission_popup()
		return true
	elif event.is_action_pressed("ui_up"):
		if event.is_echo() or not allow_step:
			return true
		dpad_debounce_timer = dpad_debounce_delay
		var new_index = trader_mission_current_product_index - TRADER_MISSION_PRODUCT_COLUMNS
		if new_index < 0:
			new_index = TRADEABLE_RESOURCES.size() - 1
		trader_mission_current_product_index = new_index
		_update_trader_mission_popup()
		return true
	elif event.is_action_pressed("ui_down"):
		if event.is_echo() or not allow_step:
			return true
		dpad_debounce_timer = dpad_debounce_delay
		var new_index = trader_mission_current_product_index + TRADER_MISSION_PRODUCT_COLUMNS
		if new_index >= TRADEABLE_RESOURCES.size():
			new_index = 0
		trader_mission_current_product_index = new_index
		_update_trader_mission_popup()
		return true
	
	var selected_resource = TRADEABLE_RESOURCES[trader_mission_current_product_index] if trader_mission_current_product_index < TRADEABLE_RESOURCES.size() else ""
	
	# Zıplama (jump) veya ui_accept: Seçili ürün için miktar pop-up'ı aç
	var press_jump = event.is_action_pressed("jump") if InputMap.has_action("jump") else false
	var press_accept = event.is_action_pressed("ui_accept")
	if press_jump or press_accept:
		if selected_resource != "":
			_open_trader_mission_quantity_popup(selected_resource)
		return true
	# Saldırı (attack) veya ui_select: Görevi başlat
	var press_attack = event.is_action_pressed("attack") if InputMap.has_action("attack") else false
	var press_select = event.is_action_pressed("ui_select")
	if press_attack or press_select:
		_execute_trader_mission()
		return true
	elif event.is_action_pressed("ui_back"):
		# Önceki adıma dön
		trader_mission_step = 1
		_update_trader_mission_popup()
		return true
	elif event.is_action_pressed("ui_cancel"):
		_close_trader_mission_popup()
		return true
	
	return false

# Pop-up'ı kapat
func _close_trader_mission_popup():
	if trader_mission_quantity_popup_open:
		_close_trader_mission_quantity_popup()
	trader_mission_popup_open = false
	if trader_mission_popup:
		trader_mission_popup.visible = false
	trader_mission_selected_concubine = null
	trader_mission_step = 0
	trader_mission_selected_route_index = 0
	trader_mission_selected_route = {}
	trader_mission_soldier_count = 0
	trader_mission_selected_products = {}
	trader_mission_current_product_index = 0

# Miktar alt pop-up'ı aç (mal seçiminde A ile)
func _open_trader_mission_quantity_popup(resource: String):
	var vm = get_node_or_null("/root/VillageManager")
	var available = vm.get_resource_level(resource) if vm and vm.has_method("get_resource_level") else 0
	trader_mission_quantity_editing_resource = resource
	trader_mission_quantity_temp_value = trader_mission_selected_products.get(resource, 0)
	trader_mission_quantity_temp_value = clampi(trader_mission_quantity_temp_value, 0, available)
	trader_mission_quantity_popup_open = true
	
	if not trader_mission_quantity_panel:
		_create_trader_mission_quantity_popup()
	if trader_mission_quantity_panel:
		trader_mission_quantity_panel.visible = true
		_update_trader_mission_quantity_popup()

func _create_trader_mission_quantity_popup():
	trader_mission_quantity_panel = Panel.new()
	trader_mission_quantity_panel.name = "TraderMissionQuantityPopup"
	trader_mission_quantity_panel.custom_minimum_size = Vector2(400, 220)
	trader_mission_quantity_panel.anchor_left = 0.5
	trader_mission_quantity_panel.anchor_top = 0.5
	trader_mission_quantity_panel.anchor_right = 0.5
	trader_mission_quantity_panel.anchor_bottom = 0.5
	trader_mission_quantity_panel.offset_left = -200
	trader_mission_quantity_panel.offset_right = 200
	trader_mission_quantity_panel.offset_top = -110
	trader_mission_quantity_panel.offset_bottom = 110
	trader_mission_quantity_panel.z_index = 1100
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.2, 0.18, 0.98)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.4, 0.7, 0.5, 1)
	trader_mission_quantity_panel.add_theme_stylebox_override("panel", style)
	
	trader_mission_quantity_label = Label.new()
	trader_mission_quantity_label.name = "QuantityLabel"
	trader_mission_quantity_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trader_mission_quantity_label.offset_left = 20
	trader_mission_quantity_label.offset_right = -20
	trader_mission_quantity_label.offset_top = 20
	trader_mission_quantity_label.offset_bottom = -20
	trader_mission_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trader_mission_quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trader_mission_quantity_label.add_theme_font_size_override("font_size", 18)
	trader_mission_quantity_panel.add_child(trader_mission_quantity_label)
	
	if trader_mission_popup:
		trader_mission_popup.add_child(trader_mission_quantity_panel)
	else:
		add_child(trader_mission_quantity_panel)

func _update_trader_mission_quantity_popup():
	if not trader_mission_quantity_label:
		return
	var name_map = {"wood": "Odun", "stone": "Taş", "food": "Yiyecek", "water": "Su"}
	var res_name = name_map.get(trader_mission_quantity_editing_resource, trader_mission_quantity_editing_resource)
	var vm = get_node_or_null("/root/VillageManager")
	var available = vm.get_resource_level(trader_mission_quantity_editing_resource) if vm and vm.has_method("get_resource_level") else 0
	trader_mission_quantity_label.text = "📦 %s\n\nMiktar: %d / %d\n\nSol/Sağ: Değiştir\nA: Onayla  |  B: İptal" % [res_name, trader_mission_quantity_temp_value, available]

func _close_trader_mission_quantity_popup():
	trader_mission_quantity_popup_open = false
	trader_mission_quantity_editing_resource = ""
	trader_mission_quantity_temp_value = 0
	if trader_mission_quantity_panel:
		trader_mission_quantity_panel.visible = false

func handle_trader_mission_quantity_popup_input(event) -> bool:
	if not trader_mission_quantity_popup_open:
		return false
	var vm = get_node_or_null("/root/VillageManager")
	var available = vm.get_resource_level(trader_mission_quantity_editing_resource) if vm and vm.has_method("get_resource_level") else 0
	
	if event.is_action_pressed("ui_left"):
		trader_mission_quantity_temp_value = max(0, trader_mission_quantity_temp_value - 1)
		_update_trader_mission_quantity_popup()
		return true
	elif event.is_action_pressed("ui_right"):
		trader_mission_quantity_temp_value = min(available, trader_mission_quantity_temp_value + 1)
		_update_trader_mission_quantity_popup()
		return true
	# Onayla: miktarı kaydet (ui_accept veya zıplama)
	var confirm_qty = event.is_action_pressed("ui_accept") or (InputMap.has_action("jump") and event.is_action_pressed("jump"))
	if confirm_qty:
		if trader_mission_quantity_temp_value > 0:
			trader_mission_selected_products[trader_mission_quantity_editing_resource] = trader_mission_quantity_temp_value
		else:
			trader_mission_selected_products.erase(trader_mission_quantity_editing_resource)
		_close_trader_mission_quantity_popup()
		_update_trader_mission_popup()
		return true
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		_close_trader_mission_quantity_popup()
		_update_trader_mission_popup()
		return true
	return false

# Görevi oluştur ve başlat
func _execute_trader_mission():
	if not trader_mission_selected_concubine or trader_mission_selected_route.is_empty():
		print("[TRADER_MISSION] ❌ Eksik bilgi: cariye veya rota seçilmedi!")
		return
	
	# En az bir mal seçilmeli
	if trader_mission_selected_products.is_empty():
		print("[TRADER_MISSION] ❌ En az bir ticaret malı seçmelisiniz!")
		return
	
	var mm = get_node_or_null("/root/MissionManager")
	if not mm or not mm.has_method("create_trade_mission_for_route"):
		print("[TRADER_MISSION] ❌ MissionManager bulunamadı!")
		return
	
	# Kaynakları kontrol et ve eksikse uyar
	var vm = get_node_or_null("/root/VillageManager")
	if vm:
		for resource in trader_mission_selected_products:
			var qty = trader_mission_selected_products[resource]
			var available = vm.get_resource_level(resource) if vm.has_method("get_resource_level") else 0
			if qty > available:
				print("[TRADER_MISSION] ❌ Yetersiz kaynak: %s (İhtiyaç: %d, Mevcut: %d)" % [resource, qty, available])
				return
	
	# Görevi oluştur
	var route_id = trader_mission_selected_route.get("id", "")
	var mission = mm.create_trade_mission_for_route(
		trader_mission_selected_concubine.id,
		route_id,
		trader_mission_selected_products,
		trader_mission_soldier_count
	)
	
	if not mission:
		print("[TRADER_MISSION] ❌ Görev oluşturulamadı!")
		return
	
	# Görevi sözlüğe ekleyip ata (MissionManager.start_mission yok, assign_mission_to_concubine kullanılır)
	mm.missions[mission.id] = mission
	var success = mm.assign_mission_to_concubine(
		trader_mission_selected_concubine.id,
		mission.id,
		trader_mission_soldier_count
	)
	if success:
		# Kaynakları harca
		if vm:
			for resource in trader_mission_selected_products:
				var qty = trader_mission_selected_products[resource]
				if vm.has_method("get_resource_level"):
					var current = vm.get_resource_level(resource)
					vm.resource_levels[resource] = max(0, current - qty)
		print("[TRADER_MISSION] ✅ Görev başlatıldı: %s → %s" % [
			trader_mission_selected_route.get("from_name", "?"),
			trader_mission_selected_route.get("to_name", "?")
		])
		_close_trader_mission_popup()
		update_trade_ui()
	else:
		print("[TRADER_MISSION] ❌ Görev başlatılamadı!")

# İnşaat işlemini gerçekleştir
func execute_construction():
	print("=== İNŞAAT DEBUG ===")
	print("Kategori: %s" % category_names[current_building_category])
	
	# Menü durumuna göre işlem yap
	if current_menu_state != MenuState.BİNA_SEÇİMİ:
		current_menu_state = MenuState.BİNA_SEÇİMİ
	print("=== A TUŞU: Seçili bina için işlem (inşa/yükselt) ===")
	_build_or_upgrade_selected()
	
	print("===================")

# Gerçek inşaat işlemini gerçekleştir
func _build_or_upgrade_selected():
	if all_buildings_flat.is_empty(): return
	var building_name = all_buildings_flat[current_building_index]
	var existing = find_existing_buildings(building_name)
	if existing.is_empty():
		# İnşa et
		var scene_path = building_scene_paths.get(building_name, "")
		if scene_path.is_empty():
			printerr("Build error: scene path not found for ", building_name)
			return
		var vm = get_node_or_null("/root/VillageManager")
		if vm and vm.has_method("request_build_building"):
			var ok = vm.request_build_building(scene_path)
			if ok:
				print("✅ Bina inşa edildi: ", building_name)
				if vm.has_signal("village_data_changed"):
					vm.emit_signal("village_data_changed")
			else:
				print("❌ İnşa başarısız (şartlar/yer yok)!")
		else:
			printerr("VillageManager not found or missing request_build_building")
	else:
		# Ev gibi "katlanabilir" binalarda yükselme = yeni kat eklemedir.
		# Ev: request_build_building konut katı veya yeni parselde şantiye kuyruğunu kullanır.
		var vm = get_node_or_null("/root/VillageManager")
		var scene_path = building_scene_paths.get(building_name, "")
		var is_house = scene_path == "res://village/buildings/House.tscn"
		if is_house and vm and vm.has_method("request_build_building"):
			var ok_floor = vm.request_build_building(scene_path)
			if ok_floor:
				print("✅ Eve yeni kat eklendi: ", building_name)
				if vm.has_signal("village_data_changed"):
					vm.emit_signal("village_data_changed")
			else:
				print("❌ Yeni kat eklenemedi (kaynak/alan/kat limiti): ", building_name)
			return

		# Diğer binalarda klasik yükseltme akışı
		var b = existing[0]
		if b and b.has_method("start_upgrade"):
			if vm and vm.has_method("prepare_building_upgrade"):
				vm.prepare_building_upgrade(b)
			var ok2 = b.start_upgrade()
			if ok2:
				print("✅ Yükseltme başlatıldı: ", b.name)
			else:
				print("❌ Yükseltme başlatılamadı: ", b.name)
		else:
			print("ℹ️ Bu bina için yükseltme mevcut değil: ", building_name)

func _demolish_selected_building():
	if all_buildings_flat.is_empty(): return
	# Index kontrolü - array sınırlarını aşmaması için
	if current_building_index < 0 or current_building_index >= all_buildings_flat.size():
		print("⚠️ Geçersiz bina index'i: ", current_building_index, " (Array boyutu: ", all_buildings_flat.size(), ")")
		current_building_index = 0  # Index'i düzelt
	var building_name = all_buildings_flat[current_building_index]
	var existing = find_existing_buildings(building_name)
	if existing.is_empty():
		print("ℹ️ Yıkılacak bina bulunamadı: ", building_name)
		return
	var b = existing[0]
	if b and is_instance_valid(b):
		# demolish() varsa onu çağır (sakinleri temizler, kat-kat yıkım yapar).
		# Yoksa doğrudan queue_free().
		if b.has_method("demolish"):
			b.demolish()
		else:
			b.queue_free()
		print("🛠️ Bina yıkıldı: ", building_name)
		var vm = get_node_or_null("/root/VillageManager")
		if vm and vm.has_signal("village_data_changed"):
			vm.emit_signal("village_data_changed")

var _construction_info_popup: Panel = null
var _construction_info_label: Label = null
var _demolish_confirm_popup: Panel = null
var _demolish_confirm_label: Label = null
var _demolish_confirm_open: bool = false
var _construction_debug_label: Label = null

func _debug_construction(msg: String) -> void:
	print("[CONSTRUCTION] ", msg)
	if current_page == PageType.CONSTRUCTION:
		if _construction_debug_label == null and construction_page != null:
			_construction_debug_label = Label.new()
			_construction_debug_label.name = "ConstructionDebugLabel"
			_construction_debug_label.position = Vector2(20, 20)
			_construction_debug_label.add_theme_color_override("font_color", Color(1,1,0.6))
			construction_page.add_child(_construction_debug_label)
		if _construction_debug_label:
			var cat_name := String(category_names[current_building_category]) if typeof(category_names) != TYPE_NIL else "?"
			_construction_debug_label.text = "%s\nCat:%s Idx:%d Open:%s" % [msg, cat_name, int(current_building_index), str(_demolish_confirm_open)]

func _open_building_info_popup():
	if _construction_info_popup:
		return
	if all_buildings_flat.is_empty():
		return
	var building_name = all_buildings_flat[current_building_index]
	_construction_info_popup = Panel.new()
	_construction_info_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay := StyleBoxFlat.new()
	overlay.bg_color = Color(0,0,0,0.65)
	_construction_info_popup.add_theme_stylebox_override("panel", overlay)
	add_child(_construction_info_popup)
	var inner = Panel.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inner.offset_left = -300
	inner.offset_right = 300
	inner.offset_top = -180
	inner.offset_bottom = 180
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2,0.2,0.2,1)
	inner.add_theme_stylebox_override("panel", sb)
	_construction_info_popup.add_child(inner)
	_construction_info_label = Label.new()
	_construction_info_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_construction_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_construction_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(_construction_info_label)
	var info_text = get_building_status_info(building_name)
	_construction_info_label.text = building_name + "\n\n" + info_text + "\n\n[B ile kapat]"

func _close_building_info_popup():
	if _construction_info_popup:
		_construction_info_popup.queue_free()
		_construction_info_popup = null
		_construction_info_label = null

func _open_demolish_confirm_popup():
	if _demolish_confirm_open:
		return
	_demolish_confirm_popup = Panel.new()
	_demolish_confirm_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay2 := StyleBoxFlat.new()
	overlay2.bg_color = Color(0,0,0,0.65)
	_demolish_confirm_popup.add_theme_stylebox_override("panel", overlay2)
	add_child(_demolish_confirm_popup)
	var inner2 := Panel.new()
	inner2.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inner2.offset_left = -260
	inner2.offset_right = 260
	inner2.offset_top = -110
	inner2.offset_bottom = 110
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color(0.22,0.22,0.22,1)
	inner2.add_theme_stylebox_override("panel", sb2)
	_demolish_confirm_popup.add_child(inner2)
	_demolish_confirm_label = Label.new()
	_demolish_confirm_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_demolish_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_demolish_confirm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner2.add_child(_demolish_confirm_label)
	var buildings = building_categories.get(current_building_category, [])
	var name_text: String = ""
	if buildings.size() > 0:
		# Index kontrolü - array sınırlarını aşmaması için
		if current_building_index >= 0 and current_building_index < buildings.size():
			name_text = String(buildings[current_building_index])
		else:
			# Index geçersizse ilk binayı göster veya boş bırak
			name_text = String(buildings[0]) if buildings.size() > 0 else ""
	_demolish_confirm_label.text = "\n" + name_text + "\n\nBu binayı yıkmak istiyor musun?\n\nA: Evet    B: Hayır"
	_demolish_confirm_open = true

func _close_demolish_confirm_popup():
	if _demolish_confirm_popup:
		_demolish_confirm_popup.queue_free()
		_demolish_confirm_popup = null
		_demolish_confirm_label = null
	_demolish_confirm_open = false

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
	# Okunmamış haberi vurgula
	var is_unread := not bool(news.get("read", false))
	if is_unread:
		card.modulate = Color(1, 1, 0.92, 1)
	
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
	# Unread badge
	if is_unread:
		title_label.text = "● " + title_label.text
	vbox.add_child(title_label)
	
	# Haber içeriği
	var content_label = Label.new()
	content_label.text = news.get("content", "İçerik yok")
	content_label.add_theme_font_size_override("font_size", 12)
	content_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(content_label)
	
	# Zaman
	var time_label = Label.new()
	var time_text = _format_news_time(news.get("timestamp", 0), news)
	if time_text == "":
		time_text = news.get("time", "Zaman yok")
	time_label.text = time_text
	time_label.add_theme_font_size_override("font_size", 10)
	time_label.add_theme_color_override("font_color", Color.GRAY)
	vbox.add_child(time_label)

	# Haber tıklanınca okundu işaretle ve detay göster (özellikle battle stories için)
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var mm = get_node_or_null("/root/MissionManager")
			if mm and mm.has_method("mark_news_read"):
				mm.mark_news_read(int(news.get("id", -1)))
				# UI'da görsel güncelleme
				card.modulate = Color(1,1,1,1)
				if title_label.text.begins_with("● "):
					title_label.text = title_label.text.substr(2)
				_update_unread_badge()
			
			# Battle stories için detay görünümü göster (uzun içerik için)
			var subcategory = news.get("subcategory", "")
			if subcategory == "battle":
				var title = news.get("title", "Battle Report")
				var content = news.get("content", "")
				_show_news_detail(title, content)
	)
	
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
	# Larger size for battle stories (longer content)
	var content_length = content.length()
	var panel_height = 350
	var panel_width = 600
	if content_length > 500:  # Battle stories are typically longer
		panel_height = 500
		panel_width = 700
	news_detail_overlay.custom_minimum_size = Vector2(panel_width, panel_height)
	news_detail_overlay.anchor_left = 0.5
	news_detail_overlay.anchor_top = 0.5
	news_detail_overlay.anchor_right = 0.5
	news_detail_overlay.anchor_bottom = 0.5
	news_detail_overlay.offset_left = -panel_width / 2
	news_detail_overlay.offset_right = panel_width / 2
	news_detail_overlay.offset_top = -panel_height / 2
	news_detail_overlay.offset_bottom = panel_height / 2
	
	# Add background style
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.5, 0.3, 0.1, 1.0)
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	news_detail_overlay.add_theme_stylebox_override("panel", stylebox)
	
	var vb = VBoxContainer.new()
	news_detail_overlay.add_child(vb)
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("margin_left", 20)
	vb.add_theme_constant_override("margin_right", 20)
	vb.add_theme_constant_override("margin_top", 20)
	vb.add_theme_constant_override("margin_bottom", 20)
	
	var t = Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	
	# Scroll container for long content (battle stories)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, panel_height - 150)
	vb.add_child(scroll)
	
	var c = Label.new()
	c.text = content
	c.add_theme_font_size_override("font_size", 13)
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(c)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vb.add_child(spacer)
	
	# Buton alanı
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(button_container)
	
	# Spacer (buton kaldırıldı)
	var button_spacer = Control.new()
	button_spacer.custom_minimum_size = Vector2(40, 0)
	button_container.add_child(button_spacer)
	
	# Geri butonu
	var back_button = Label.new()
	back_button.text = "⬅️ Geri (B)"
	back_button.add_theme_font_size_override("font_size", 14)
	back_button.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8, 1))
	button_container.add_child(back_button)
	
	# Alt kategori değiştirme bilgisi
	var filter_info = Label.new()
	filter_info.text = "Alt kategori: Y tuşu"
	filter_info.add_theme_font_size_override("font_size", 10)
	filter_info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	filter_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(filter_info)
	
	get_tree().get_root().add_child(news_detail_overlay)

func _news_close_detail():
	if news_detail_overlay:
		news_detail_overlay.queue_free()
		news_detail_overlay = null

# Haber→görev dönüştürme özelliği kaldırıldı

# Oyun dakikasını saat/dakika formatına çevir (örn: 180 -> "3 saat", 210 -> "3 saat 30 dakika")
func _format_game_time_minutes(minutes: float) -> String:
	var total_minutes = int(minutes)
	if total_minutes <= 0:
		return "Tamamlandı"
	
	var hours = total_minutes / 60
	var remaining_minutes = total_minutes % 60
	
	if hours > 0 and remaining_minutes > 0:
		return "%d saat %d dakika" % [hours, remaining_minutes]
	elif hours > 0:
		return "%d saat" % hours
	else:
		return "%d dakika" % remaining_minutes

func _format_news_time(timestamp: int, news_dict: Dictionary = {}) -> String:
	if timestamp <= 0:
		return ""
	
	# Oyun içi saatle göster
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("get_total_game_minutes"):
		var diff_game_minutes = 0.0
		
		# Eğer haber dictionary'sinde oyun zamanı varsa, onu kullan
		if news_dict.has("game_time_minutes") and news_dict["game_time_minutes"] > 0:
			var current_game_time = time_manager.get_total_game_minutes()
			diff_game_minutes = current_game_time - news_dict["game_time_minutes"]
		else:
			# Eski haberler için: gerçek zaman timestamp'ini oyun zamanına çevir
			var current_real_time = int(Time.get_unix_time_from_system())
			var diff_real_seconds = current_real_time - timestamp
			# Gerçek saniyeyi oyun dakikasına çevir (1 oyun dakikası = 2.5 gerçek saniyesi)
			diff_game_minutes = diff_real_seconds / 2.5
		
		if diff_game_minutes < 1:
			return "Az önce"
		elif diff_game_minutes < 60:
			return "%d dakika önce" % int(diff_game_minutes)
		else:
			var hours = int(diff_game_minutes / 60)
			var minutes = int(diff_game_minutes) % 60
			if minutes > 0:
				return "%d saat %d dakika önce" % [hours, minutes]
			else:
				return "%d saat önce" % hours
	
	# Fallback: gerçek zaman (eski sistem)
	var current_time = int(Time.get_unix_time_from_system())
	var diff = current_time - timestamp
	
	if diff < 60:
		return str(diff) + " saniye önce"
	elif diff < 3600:
		var minutes = int(diff / 60)
		return str(minutes) + " dakika önce"
	elif diff < 86400:
		var hours = int(diff / 3600)
		return str(hours) + " saat önce"
	else:
		var days = int(diff / 86400)
		return str(days) + " gün önce"

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
	# name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# Durum
	var status_label = Label.new()
	status_label.text = "Durum: %s" % cariye.get_status_name()
	# status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	vbox.add_child(status_label)
	
	# En iyi yetenek
	var best_skill = cariye.get_best_skill()
	var skills_label = Label.new()
	skills_label.text = "En İyi: %s (%d)" % [cariye.get_skill_name(best_skill), cariye.get_skill_level(best_skill)]
	# skills_label.add_theme_font_size_override("font_size", 10)
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
	print("[MissionCenter] DEBUG: update_basic_info_panel çağrıldı - cariye: %s" % (cariye.name if cariye else "null"))
	var basic_info_vbox = get_node_or_null("ConcubineDetailsPage/ConcubineContent/ConcubineDetailsPanel/ConcubineDetailsScroll/ConcubineDetailsContent/BasicInfoPanel/BasicInfoVBox")
	if not basic_info_vbox:
		print("[MissionCenter] DEBUG: BasicInfoVBox bulunamadı!")
		return
	print("[MissionCenter] DEBUG: BasicInfoVBox bulundu")
	
	# Eski BasicInfoContent'ı temizle (artık InfoVBox içinde olacak)
	var old_basic_info_content = basic_info_vbox.get_node_or_null("BasicInfoContent")
	if old_basic_info_content:
		old_basic_info_content.queue_free()
	
	# BasicInfoTitle'ı bul (container'ı onun altına ekleyeceğiz ama üst kenara dayanacak)
	var basic_info_title = basic_info_vbox.get_node_or_null("BasicInfoTitle")
	
	# Portre için HBoxContainer oluştur veya bul
	var portrait_container = basic_info_vbox.get_node_or_null("PortraitContainer")
	if not portrait_container:
		portrait_container = HBoxContainer.new()
		portrait_container.name = "PortraitContainer"
		portrait_container.custom_minimum_size = Vector2(0, 200)  # Minimum yükseklik artırıldı (portre için, üst kenara dayanması için)
		portrait_container.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Container'ın üst ve alt kenarlara dayanması için
		portrait_container.clip_contents = false  # Clipping'i kapat
		portrait_container.visible = true
		portrait_container.modulate = Color.WHITE
		# BasicInfoTitle'dan sonra ekle (ama container'ın üst kenara dayanması için)
		var title_index = 0
		if basic_info_title:
			for i in range(basic_info_vbox.get_child_count()):
				if basic_info_vbox.get_child(i).name == "BasicInfoTitle":
					title_index = i + 1
					break
		basic_info_vbox.add_child(portrait_container)
		basic_info_vbox.move_child(portrait_container, title_index)
		# Container'ın üst kenara dayanması için margin'leri negatif yap (title'ın üstüne taş)
		portrait_container.add_theme_constant_override("margin_top", -100)  # Title'ın üstüne taş (üst kenara dayan)
		portrait_container.add_theme_constant_override("margin_bottom", 0)
		print("[MissionCenter] DEBUG: PortraitContainer oluşturuldu ve eklendi")
	else:
		print("[MissionCenter] DEBUG: PortraitContainer zaten var, temizleniyor...")
		# Mevcut container'ın ayarlarını güncelle
		portrait_container.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Container'ın üst ve alt kenarlara dayanması için
		portrait_container.clip_contents = false
		portrait_container.visible = true
		portrait_container.modulate = Color.WHITE
		# Container'ın üst kenara dayanması için margin'leri negatif yap (yukarı kaydır)
		portrait_container.add_theme_constant_override("margin_top", -30)  # 30 piksel yukarı kaydır
		portrait_container.add_theme_constant_override("margin_bottom", 0)
		# Eski child'ları hemen kaldır (queue_free yerine remove_child kullan)
		# Önce viewport'ları temizle (eğer varsa)
		var children_to_remove = []
		for child in portrait_container.get_children():
			children_to_remove.append(child)
		for child in children_to_remove:
			# Eğer child bir TextureRect ise ve viewport referansı varsa, önce viewport'u temizle
			if child is TextureRect:
				var old_viewport = child.get_meta("viewport_ref", null) if child.has_meta("viewport_ref") else null
				var old_instance = child.get_meta("instance_ref", null) if child.has_meta("instance_ref") else null
				if old_viewport and is_instance_valid(old_viewport):
					if old_instance and is_instance_valid(old_instance) and old_instance.get_parent() == old_viewport:
						old_viewport.remove_child(old_instance)
						old_instance.queue_free()
					old_viewport.queue_free()
			portrait_container.remove_child(child)
			child.queue_free()
	
	# Bilgiler için VBoxContainer (önce ekle - sol taraf)
	var info_vbox = VBoxContainer.new()
	info_vbox.name = "InfoVBox"
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Sol taraf genişler
	portrait_container.add_child(info_vbox)
	print("[MissionCenter] DEBUG: InfoVBox oluşturuldu ve eklendi, container children: %d" % portrait_container.get_child_count())
	
	# Portre TextureRect oluştur (sonra ekle - sağ taraf)
	var portrait_rect = TextureRect.new()
	portrait_rect.name = "Portrait"
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # Aspect ratio'yu koru
	portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL  # expand_mode gerekli olabilir
	portrait_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Çerçeve içinde tam doldur
	portrait_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Çerçeve içinde tam doldur
	portrait_rect.visible = true  # Görünürlüğü aç
	portrait_rect.modulate = Color.WHITE  # Tam opaklık
	portrait_rect.self_modulate = Color.WHITE  # Tam opaklık
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Mouse etkileşimini kapat
	portrait_rect.z_index = 1  # Z-index'i artır
	portrait_rect.z_as_relative = false  # Z-index'i mutlak yap
	
	# Debug: TextureRect'in render edilip edilmediğini kontrol et
	print("[MissionCenter] DEBUG: TextureRect oluşturuldu - size: %s, visible: %s, modulate: %s, expand_mode: %s, stretch_mode: %s" % [
		portrait_rect.size,
		portrait_rect.visible,
		portrait_rect.modulate,
		portrait_rect.expand_mode,
		portrait_rect.stretch_mode
	])
	
	# Portre texture'ı oluştur (async) - InfoVBox'tan SONRA ekle (sağda görünsün)
	# Çerçeve için PanelContainer ekle - container'ın sağ tarafını tamamen kaplar
	var frame_container = PanelContainer.new()
	frame_container.name = "PortraitFrame"
	# Container'ın sağ tarafını tamamen kaplar, TÜM kenarlara (üst, alt, sağ) dayanır
	frame_container.size_flags_horizontal = Control.SIZE_SHRINK_END  # Sağa hizala
	frame_container.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Üst ve alt kenarlara dayan (tam yükseklik)
	# Minimum genişlik (portre için yeterli, yükseklik container'a göre ayarlanacak)
	frame_container.custom_minimum_size = Vector2(180, 0)  # Genişlik artırıldı, yükseklik 0 (container'a göre)
	# Margin'leri negatif yap - container'ın üst kenarına dayanması için yukarı kaydır
	frame_container.add_theme_constant_override("margin_left", -1)  # 1 piksel sola kaydır
	frame_container.add_theme_constant_override("margin_right", 0)
	frame_container.add_theme_constant_override("margin_top", -100)  # 100 piksel yukarı kaydır (üst kenara dayan)
	frame_container.add_theme_constant_override("margin_bottom", 0)
	
	# Çerçeve stili için StyleBoxFlat oluştur
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Koyu gri arka plan
	frame_style.border_color = Color(0.8, 0.6, 0.4, 1.0)  # Altın rengi çerçeve
	frame_style.border_width_left = 2
	frame_style.border_width_top = 2
	frame_style.border_width_right = 2
	frame_style.border_width_bottom = 2
	frame_style.corner_radius_top_left = 4
	frame_style.corner_radius_top_right = 4
	frame_style.corner_radius_bottom_left = 4
	frame_style.corner_radius_bottom_right = 4
	frame_container.add_theme_stylebox_override("panel", frame_style)
	
	# TextureRect'i çerçeve içine ekle
	frame_container.add_child(portrait_rect)
	portrait_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Çerçeveyi container'a ekle
	portrait_container.add_child(frame_container)
	print("[MissionCenter] DEBUG: PortraitFrame ve PortraitRect eklendi, frame parent: %s, rect parent: %s, visible: %s, size: %s" % [
		frame_container.get_parent().name if frame_container.get_parent() else "null",
		portrait_rect.get_parent().name if portrait_rect.get_parent() else "null",
		portrait_rect.visible,
		portrait_rect.size
	])
	
	# Child sırasını kontrol et
	for i in range(portrait_container.get_child_count()):
		var child = portrait_container.get_child(i)
		print("[MissionCenter] DEBUG: Container child %d: %s" % [i, child.name])
	
	# Birkaç frame bekle ve layout'u zorla güncelle
	await get_tree().process_frame
	portrait_container.queue_redraw()  # Container'ı yeniden çiz
	portrait_rect.queue_redraw()  # TextureRect'i yeniden çiz
	await get_tree().process_frame
	await get_tree().process_frame  # Ekstra frame bekle
	
	print("[MissionCenter] DEBUG: PortraitRect kontrol (3 frame sonra) - visible: %s, size: %s, rect: %s, parent visible: %s, parent size: %s, parent rect: %s" % [
		portrait_rect.visible,
		portrait_rect.size,
		portrait_rect.get_rect(),
		portrait_rect.get_parent().visible if portrait_rect.get_parent() else "null",
		portrait_rect.get_parent().size if portrait_rect.get_parent() else "null",
		portrait_rect.get_parent().get_rect() if portrait_rect.get_parent() else "null"
	])
	
	_generate_concubine_portrait_async(cariye, portrait_rect)
	
	# Eski BasicInfoContent'ı bul veya oluştur
	var basic_info_content = info_vbox.get_node_or_null("BasicInfoContent")
	if not basic_info_content:
		basic_info_content = Label.new()
		basic_info_content.name = "BasicInfoContent"
		info_vbox.add_child(basic_info_content)
	
	var info_text = "İsim: %s\n" % cariye.name
	info_text += "Seviye: %d (%d/%d XP)\n" % [cariye.level, cariye.experience, cariye.max_experience]
	info_text += "Durum: %s\n" % cariye.get_status_name()
	info_text += "Rol: %s\n" % cariye.get_role_name()
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

# Cariye portresi oluştur (idle frame 1 yakınlaştırılmış) - async versiyon
# Portre instance'ları için görünmeyen container ve instance'ları oluştur
func _setup_portrait_instances():
	print("[MissionCenter] DEBUG: Portre instance'ları oluşturuluyor...")
	
	# Görünmeyen container oluştur (sahnenin dışında - ekranın çok altında)
	if not portrait_instances_container:
		portrait_instances_container = Node2D.new()
		portrait_instances_container.name = "PortraitInstancesContainer"
		# Ekranın çok altında, oyuncunun asla göremeyeceği bir yerde
		# CanvasLayer kullanıyoruz, bu yüzden position kullanıyoruz
		portrait_instances_container.position = Vector2(0, 100000)  # Çok çok aşağıda (ekran dışında)
		portrait_instances_container.z_index = -10000  # En arkada
		portrait_instances_container.visible = false  # Görünmez yap (animasyonlar process_mode ile çalışacak)
		portrait_instances_container.process_mode = Node.PROCESS_MODE_ALWAYS  # Her zaman işle (animasyonlar için)
		# CanvasLayer'ın altına ekle (UI layer'ın dışında)
		add_child(portrait_instances_container)
		print("[MissionCenter] DEBUG: PortraitInstancesContainer oluşturuldu ve eklendi (y: 100000, visible: false, process_mode: ALWAYS)")
	
	# Tüm cariyeler için instance oluştur
	if not mission_manager:
		print("[MissionCenter] DEBUG: MissionManager bulunamadı, portre instance'ları oluşturulamadı")
		return
	
	# concubines property'sine direkt eriş (has() kullanma - Godot 4'te yok)
	var concubines = mission_manager.concubines if mission_manager.concubines else null
	if not concubines:
		print("[MissionCenter] DEBUG: MissionManager'da concubines bulunamadı veya boş, portre instance'ları oluşturulamadı")
		return
	if not concubines:
		print("[MissionCenter] DEBUG: Cariye yok, portre instance'ları oluşturulamadı")
		return
	
	# Concubine scene'ini yükle
	var concubine_scene = preload("res://village/scenes/Concubine.tscn")
	if not concubine_scene:
		printerr("[MissionCenter] Concubine scene bulunamadı!")
		return
	
	# Her cariye için instance oluştur
	for concubine_id in concubines:
		var cariye = concubines[concubine_id]
		if not cariye:
			continue
		
		# Eğer zaten varsa atla
		if concubine_id in portrait_instances:
			print("[MissionCenter] DEBUG: Cariye %d için portre instance zaten var, atlanıyor" % concubine_id)
			continue
		
		# Instance oluştur
		var instance = concubine_scene.instantiate()
		if not instance:
			printerr("[MissionCenter] Cariye %d için instance oluşturulamadı!" % concubine_id)
			continue
		
		# Appearance'ı ata
		instance.appearance = cariye.appearance
		
		# Görünmeyen yere yerleştir (her instance farklı x pozisyonunda, y aynı)
		# Ekranın çok altında, oyuncunun asla göremeyeceği bir yerde
		instance.position = Vector2(concubine_id * 200, 0)  # Her instance yan yana
		instance.global_position = Vector2(concubine_id * 200, 100000)  # Ekranın çok çok altında
		instance.z_index = -10000  # En arkada
		
		# Sola bakar pozisyonda sabitle (scale.x = -1)
		instance.scale.x = -1.0  # Sola bakar
		instance.scale.y = 1.0
		
		# Hareket etmesin - tamamen sabit
		instance.move_target_x = instance.global_position.x  # Hedef = mevcut pozisyon
		instance._target_global_y = instance.global_position.y  # Hedef = mevcut pozisyon
		
		# Container'a ekle
		portrait_instances_container.add_child(instance)
		
		# Dictionary'ye ekle
		portrait_instances[concubine_id] = instance
		
		# Birkaç frame bekle (instance'ın hazır olması için)
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Hareket etmesin - _physics_process'i devre dışı bırak
		instance.set_physics_process(false)
		
		# Idle animasyonunu sürekli oynat
		if instance.has_method("play_animation"):
			instance.play_animation("idle")
			print("[MissionCenter] DEBUG: play_animation('idle') çağrıldı - Cariye %d" % concubine_id)
		
		# AnimationPlayer ile idle animasyonunu başlat
		var animation_player = instance.get_node_or_null("AnimationPlayer")
		if animation_player:
			if animation_player.has_animation("idle"):
				animation_player.play("idle")
				# Animasyonu durdurma - sürekli oynasın
				print("[MissionCenter] DEBUG: AnimationPlayer.play('idle') çağrıldı - Cariye %d, is_playing: %s, current_animation: %s" % [
					concubine_id,
					animation_player.is_playing(),
					animation_player.current_animation
				])
			else:
				print("[MissionCenter] DEBUG: UYARI - Cariye %d için 'idle' animasyonu bulunamadı!" % concubine_id)
		else:
			print("[MissionCenter] DEBUG: UYARI - Cariye %d için AnimationPlayer bulunamadı!" % concubine_id)
		
		print("[MissionCenter] DEBUG: Cariye %d (%s) için portre instance oluşturuldu - pozisyon: %s, scale: %s, physics_process: false" % [
			concubine_id, 
			cariye.name,
			instance.global_position,
			instance.scale
		])
	
	print("[MissionCenter] DEBUG: Toplam %d portre instance oluşturuldu" % portrait_instances.size())

func _generate_concubine_portrait_async(cariye: Concubine, portrait_rect: TextureRect):
	print("[MissionCenter] DEBUG: Portre oluşturuluyor - cariye: %s (ID: %d), appearance: %s" % [
		cariye.name if cariye else "null",
		cariye.id if cariye else -1,
		"var" if cariye and cariye.appearance else "null"
	])
	
	if not cariye or not cariye.appearance:
		print("[MissionCenter] DEBUG: Cariye veya appearance yok, fallback texture kullanılıyor")
		# Fallback: boş texture
		var empty_texture = ImageTexture.new()
		var empty_image = Image.create(128, 128, false, Image.FORMAT_RGB8)
		empty_image.fill(Color(0.2, 0.2, 0.2, 1))
		empty_texture.create_from_image(empty_image)
		portrait_rect.texture = empty_texture
		return
	
	# Görünmeyen portre instance'ını kullan (eğer varsa)
	var concubine_instance = null
	if cariye.id in portrait_instances:
		concubine_instance = portrait_instances[cariye.id]
		print("[MissionCenter] DEBUG: Mevcut portre instance kullanılıyor (ID: %d)" % cariye.id)
	else:
		print("[MissionCenter] DEBUG: UYARI: Cariye %d için portre instance bulunamadı, yeni oluşturuluyor..." % cariye.id)
		# Instance yoksa oluştur (geçici çözüm)
		var concubine_scene = preload("res://village/scenes/Concubine.tscn")
		if concubine_scene:
			concubine_instance = concubine_scene.instantiate()
			if concubine_instance:
				concubine_instance.appearance = cariye.appearance
				# Scale'i ayarla - portreler sola bakmalı (scale.x = -1)
				concubine_instance.scale.x = -1.0
				concubine_instance.scale.y = 1.0
				print("[MissionCenter] DEBUG: Yeni instance scale ayarlandı: %s" % concubine_instance.scale)
				# Geçici olarak viewport'a ekleyeceğiz
	
	if not concubine_instance:
		printerr("[MissionCenter] Concubine instance oluşturulamadı!")
		return
	
	# Appearance'ı güncelle (kıyafet değişiklikleri için)
	concubine_instance.appearance = cariye.appearance
	
	print("[MissionCenter] DEBUG: Viewport oluşturuluyor...")
	# Viewport oluştur - daha yüksek çözünürlük (flu görüntüyü önlemek için)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(1024, 1024)  # 512'den 1024'e çıkardık (daha net görüntü için)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.snap_2d_transforms_to_pixel = true  # Pixel-perfect rendering
	viewport.snap_2d_vertices_to_pixel = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST  # Pixel-perfect
	
	# Scene tree'ye ekle (render için gerekli)
	add_child(viewport)
	print("[MissionCenter] DEBUG: Viewport scene tree'ye eklendi")
	
	# Instance'ı viewport'a ekle (duplicate et çünkü görünmeyen instance zaten başka bir yerde)
	var viewport_instance = concubine_instance.duplicate()
	viewport.add_child(viewport_instance)
	
	# Bir frame bekle (instance'ın hazır olması için)
	await get_tree().process_frame
	
	# Duplicate'ın appearance'ını güncelle
	viewport_instance.appearance = cariye.appearance
	
	# Scale'i ayarla - portreler sola bakmalı (scale.x = -1)
	viewport_instance.scale.x = -1.0
	viewport_instance.scale.y = 1.0
	print("[MissionCenter] DEBUG: Duplicate instance scale ayarlandı: %s" % viewport_instance.scale)
	
	# Duplicate instance için _physics_process'i devre dışı bırak (hareket kontrolü yapmasın)
	viewport_instance.set_physics_process(false)
	
	# Duplicate instance'ın hareket hedeflerini mevcut pozisyonuna eşitle (idle'da kalsın)
	if "move_target_x" in viewport_instance:
		viewport_instance.move_target_x = viewport_instance.global_position.x
	if "_target_global_y" in viewport_instance:
		viewport_instance._target_global_y = viewport_instance.global_position.y
	if "_current_animation_name" in viewport_instance:
		viewport_instance._current_animation_name = "idle"
	
	# Duplicate'ın idle animasyonunu başlat
	if viewport_instance.has_method("play_animation"):
		viewport_instance.play_animation("idle")
		print("[MissionCenter] DEBUG: Duplicate için play_animation('idle') çağrıldı")
	
	# Bir frame bekle (play_animation'ın uygulanması için)
	await get_tree().process_frame
	
	var viewport_animation_player = viewport_instance.get_node_or_null("AnimationPlayer")
	if viewport_animation_player:
		if viewport_animation_player.has_animation("idle"):
			viewport_animation_player.play("idle")
			print("[MissionCenter] DEBUG: Duplicate için AnimationPlayer.play('idle') çağrıldı, is_playing: %s" % viewport_animation_player.is_playing())
		else:
			print("[MissionCenter] DEBUG: UYARI - Duplicate için 'idle' animasyonu bulunamadı!")
	else:
		print("[MissionCenter] DEBUG: UYARI - Duplicate için AnimationPlayer bulunamadı!")
	
	# Artık viewport_instance kullan
	concubine_instance = viewport_instance
	
	print("[MissionCenter] DEBUG: ===== PORTRE OLUŞTURMA BAŞLADI - Cariye: %s =====" % cariye.name)
	
	# Concubine instance'ın pozisyonunu TAMAMEN SABİTLE (viewport içinde)
	concubine_instance.position = Vector2(0, 0)
	concubine_instance.global_position = Vector2(0, 0)
	# Scale'i tekrar ayarla (duplicate sonrası kaybolmuş olabilir)
	concubine_instance.scale.x = -1.0
	concubine_instance.scale.y = 1.0
	print("[MissionCenter] DEBUG: Concubine instance pozisyonu: %s, global_position: %s, scale: %s" % [concubine_instance.position, concubine_instance.global_position, concubine_instance.scale])
	
	# Tüm sprite'ların pozisyonlarını SABİTLE (her cariye için aynı)
	# Sprite'lar scene'de Vector2(0, -48) pozisyonunda olmalı
	var sprite_names = ["BodySprite", "PantsSprite", "ClothingSprite", "MouthSprite", "EyesSprite", "HairSprite"]
	for sprite_name in sprite_names:
		var sprite = concubine_instance.get_node_or_null(sprite_name)
		if sprite:
			var old_pos = sprite.position
			sprite.position = Vector2(0, -48)  # Scene'deki sabit pozisyon
			sprite.centered = true  # Merkez hizalama garantisi
			print("[MissionCenter] DEBUG: %s - Eski pozisyon: %s, Yeni pozisyon: %s, Texture: %s, hframes: %d, vframes: %d, frame: %d" % [
				sprite_name, 
				old_pos, 
				sprite.position,
				sprite.texture.get_path() if sprite.texture else "null",
				sprite.hframes,
				sprite.vframes,
				sprite.frame
			])
		else:
			print("[MissionCenter] DEBUG: UYARI: %s bulunamadı!" % sprite_name)
	
	print("[MissionCenter] DEBUG: Concubine instance ve tüm sprite'lar sabitlendi")
	
	# Birkaç frame bekle (sprite'ların yüklenmesi için)
	await get_tree().process_frame
	await get_tree().process_frame
	
	# SPRITE DURUMU KONTROLÜ (play_animation öncesi)
	print("[MissionCenter] DEBUG: === SPRITE DURUMU (play_animation ÖNCESİ) ===")
	for sprite_name in sprite_names:
		var sprite = concubine_instance.get_node_or_null(sprite_name)
		if sprite:
			print("[MissionCenter] DEBUG: %s - Pozisyon: %s, frame: %d, hframes: %d, vframes: %d" % [
				sprite_name, sprite.position, sprite.frame, sprite.hframes, sprite.vframes
			])
	
	# Idle animasyonu zaten görünmeyen instance'da oynuyor olmalı
	# Sadece emin olmak için kontrol et
	var animation_player = concubine_instance.get_node_or_null("AnimationPlayer")
	if animation_player:
		if animation_player.has_animation("idle"):
			# Eğer oynamıyorsa başlat
			if not animation_player.is_playing() or animation_player.current_animation != "idle":
				animation_player.play("idle")
				print("[MissionCenter] DEBUG: Idle animasyonu başlatıldı (viewport için)")
		else:
			print("[MissionCenter] DEBUG: UYARI: 'idle' animasyonu bulunamadı!")
	else:
		print("[MissionCenter] DEBUG: UYARI: AnimationPlayer bulunamadı!")
	
	# Bir frame bekle (seek'in uygulanması için)
	await get_tree().process_frame
	
	# SPRITE DURUMU KONTROLÜ (seek sonrası)
	print("[MissionCenter] DEBUG: === SPRITE DURUMU (seek SONRASI) ===")
	for sprite_name in sprite_names:
		var sprite = concubine_instance.get_node_or_null(sprite_name)
		if sprite:
			print("[MissionCenter] DEBUG: %s - Pozisyon: %s, frame: %d, hframes: %d, vframes: %d, texture_path: %s" % [
				sprite_name, 
				sprite.position, 
				sprite.frame, 
				sprite.hframes, 
				sprite.vframes,
				sprite.texture.resource_path if sprite.texture and "resource_path" in sprite.texture else "N/A"
			])
	
	# Birkaç frame bekle (sprite'ların render olması için)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# SON SPRITE DURUMU KONTROLÜ (render öncesi)
	print("[MissionCenter] DEBUG: === SON SPRITE DURUMU (render ÖNCESİ) ===")
	for sprite_name in sprite_names:
		var sprite = concubine_instance.get_node_or_null(sprite_name)
		if sprite:
			print("[MissionCenter] DEBUG: %s - Pozisyon: %s, frame: %d, hframes: %d, vframes: %d" % [
				sprite_name, sprite.position, sprite.frame, sprite.hframes, sprite.vframes
			])
	
	# Sprite'ların görsel merkez noktası - TAMAMEN SABIT (tüm cariyeler için aynı)
	# Sprite'lar Vector2(0, -48) pozisyonunda, portre için başın merkez noktası
	# Kamera pozisyonunu daha aşağı al (daha iyi çerçeveleme için)
	var head_center = Vector2(0, -40)  # Sabit pozisyon (portre için baş merkezi - daha aşağı)
	print("[MissionCenter] DEBUG: Sabit head_center kullanılıyor: %s (tüm cariyeler için aynı)" % head_center)
	
	# Camera2D ekle (yakınlaştırma için) - hesaplanan merkez noktasına odaklan
	var camera = Camera2D.new()
	camera.zoom = Vector2(48.0, 48.0)  # 48x yakınlaştırma (12'den 4 kat daha yakın)
	camera.position = head_center  # Hesaplanan baş merkez noktasına odaklan
	viewport.add_child(camera)
	camera.make_current()
	print("[MissionCenter] DEBUG: Camera eklendi ve aktif, position: %s, zoom: %s" % [camera.position, camera.zoom])
	
	# Render için birkaç frame bekle (viewport'un render olması için)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("[MissionCenter] DEBUG: Frame'ler beklendi, viewport texture bağlanıyor...")
	
	# Viewport'u sürekli güncelle (animasyon için)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# ViewportTexture kullan (animasyonlu görüntü için)
	# Bu sayede viewport sürekli güncellenir ve animasyon görünür
	var viewport_texture = viewport.get_texture()
	if viewport_texture:
		print("[MissionCenter] DEBUG: Viewport texture bulundu, TextureRect'e bağlanıyor...")
		# ViewportTexture'ı direkt TextureRect'e bağla (animasyonlu)
		portrait_rect.texture = viewport_texture
		portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # Pixel-perfect (flu değil)
		portrait_rect.visible = true  # Görünürlüğü zorla aç
		portrait_rect.queue_redraw()  # Zorla yeniden çiz
		
		# Viewport'u sakla (temizlik için - portrait_rect silindiğinde temizlenecek)
		portrait_rect.set_meta("viewport_ref", viewport)
		portrait_rect.set_meta("instance_ref", concubine_instance)
		
		print("[MissionCenter] DEBUG: ViewportTexture TextureRect'e bağlandı, animasyon aktif")
	else:
		print("[MissionCenter] DEBUG: Viewport texture bulunamadı!")
		# Fallback texture
		var empty_image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
		empty_image.fill(Color(0, 1, 0, 1))  # Yeşil - debug için
		var empty_texture = ImageTexture.create_from_image(empty_image)
		portrait_rect.texture = empty_texture
		portrait_rect.queue_redraw()  # Zorla yeniden çiz
	
	# Viewport'u temizleme - artık TextureRect viewport'u kullanıyor
	# Temizlik işlemi portrait_rect silindiğinde (update_basic_info_panel'de) yapılacak
	print("[MissionCenter] DEBUG: ViewportTexture bağlandı, viewport ve instance saklandı (temizlik portrait_rect silindiğinde yapılacak)")

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
		achievements_text = "🌟 Henüz başarı kazanılmadı\n\nBaşarılar görev tamamlama, seviye atlama ve yetenek geliştirme ile kazanılır."
	else:
		achievements_text = "🏆 Toplam %d Başarı Kazanıldı\n\n" % cariye.special_achievements.size()
		for achievement in cariye.special_achievements:
			# Başarı ismini ve açıklamasını ayır (varsa)
			var achievement_parts = achievement.split(" - ", false, 1)
			if achievement_parts.size() == 2:
				# İsim ve açıklama var
				achievements_text += "%s\n   └─ %s\n\n" % [achievement_parts[0], achievement_parts[1]]
			else:
				# Sadece isim var
				achievements_text += "%s\n\n" % achievement
	
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
	# title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_label)
	
	# Görev türü ve zorluk
	var info_label = Label.new()
	info_label.text = "Tür: %s | Zorluk: %s" % [mission.get_mission_type_name(), mission.get_difficulty_name()]
	# info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(info_label)
	
	# Tamamlanma tarihi ve süre
	var time_label = Label.new()
	var completion_time = "Tamamlandı: %.1f saniye" % mission.duration
	time_label.text = "⏱️ %s" % completion_time
	# time_label.add_theme_font_size_override("font_size", 12)
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
	if page_dot7:
		page_dot7.modulate = Color(0.5, 0.5, 0.5, 1)
	
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
		PageType.DIPLOMACY:
			if page_dot7:
				page_dot7.modulate = Color(1, 1, 1, 1)
	
	# Bildirim rozetini en son güncelle (her zaman)
	_update_unread_badge()

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
	print("📰 ===== HABER DEBUG BAŞLADI =====")
	print("📰 Haber Merkezi güncelleniyor...")
	
	# MissionManager'dan haber kuyruklarını al
	if not MissionManager:
		print("📰 ❌ MissionManager bulunamadı!")
		return
	
	print("📰 ✅ MissionManager bulundu")
	print("📰 MissionManager type: ", MissionManager.get_class())
	print("📰 MissionManager script: ", MissionManager.get_script())
	
	# Haber kuyruklarını yöneticiden çek (persist)
	var village_news: Array = []
	var world_news: Array = []
	if MissionManager and MissionManager.has_method("get_village_news") and MissionManager.has_method("get_world_news"):
		village_news = MissionManager.get_village_news()
		world_news = MissionManager.get_world_news()
	else:
		# Yedek: MissionCenter'daki yerel kuyruklar
		village_news = news_queue_village.duplicate(true)
		world_news = news_queue_world.duplicate(true)
	
	print("📰 ✅ MissionCenter haber kuyrukları kullanıldı")
	print("📰 Final Village haber sayısı: ", village_news.size())
	print("📰 Final World haber sayısı: ", world_news.size())
	print("📰 ===== HABER DEBUG BİTTİ =====")
	
	# Filtre çubuklarını hazırla (ilk sefer)
	_ensure_news_filter_bar()
	_ensure_news_subcategory_bar()
	_update_news_filter_bar_visual()
	_update_news_subcategory_bar_visual()
	
	# Başlıkta unread rozetini güncelle
	_update_unread_badge()
	
	# Kuyruktan çiz: önce temizle, sonra doldur
	var village_list = get_node_or_null("NewsCenterPage/NewsContent/VillageNewsPanel/VillageNewsScroll/VillageNewsList")
	var world_list = get_node_or_null("NewsCenterPage/NewsContent/WorldNewsPanel/WorldNewsScroll/WorldNewsList")
	
	# Sadece gerçek haberler varsa listeyi güncelle
	if village_news.size() > 0 and village_list:
		print("📰 🔄 Village haber listesi güncelleniyor: ", village_news.size(), " haber")
		for c in village_list.get_children():
			c.queue_free()
		for n in village_news:
			if not _news_passes_subcategory_filter(n):
				continue
			village_list.add_child(create_news_card(n))
		print("📰 ✅ Village haber listesi güncellendi")
	elif village_list:
		print("📰 ⚠️ Village haber yok, liste temizleniyor")
		for c in village_list.get_children():
			c.queue_free()
	
	if world_news.size() > 0 and world_list:
		print("📰 🔄 World haber listesi güncelleniyor: ", world_news.size(), " haber")
		for c in world_list.get_children():
			c.queue_free()
		for n in world_news:
			if not _news_passes_subcategory_filter(n):
				continue
			world_list.add_child(create_news_card(n))
		print("📰 ✅ World haber listesi güncellendi")
	elif world_list:
		print("📰 ⚠️ World haber yok, liste temizleniyor")
		for c in world_list.get_children():
			c.queue_free()
	# Rastgele olay paneli şimdilik korunuyor (placeholder)
	update_random_events()
	if current_page == PageType.NEWS:
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
	_update_concubine_list_dynamic()
	_update_selected_concubine_details_dynamic()
	
	# Cariye listesini güncelle
func _update_concubine_list_dynamic():
	var list_node: VBoxContainer = get_node_or_null("ConcubineDetailsPage/ConcubineContent/ConcubineListPanel/ConcubineListScroll/ConcubineList")
	if not list_node:
		return
	for c in list_node.get_children():
		c.queue_free()
	if not mission_manager:
		return
	# concubines sorted by name for consistent ordering
	var concubine_array: Array = _get_concubines_sorted_by_name()
	for idx in range(concubine_array.size()):
		var c: Concubine = concubine_array[idx]
		var item = Panel.new()
		item.custom_minimum_size = Vector2(250, 90)
		var vb = VBoxContainer.new()
		item.add_child(vb)
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var name_l = Label.new()
		var marker = "> " if idx == current_concubine_detail_index else "  "
		name_l.text = "%s%s (Lv.%d)" % [marker, c.name, c.level]
		# name_l.add_theme_font_size_override("font_size", 14)
		name_l.add_theme_color_override("font_color", Color.WHITE)
		vb.add_child(name_l)
		var status_l = Label.new()
		status_l.text = "Durum: %s" % c.get_status_name()
		# status_l.add_theme_font_size_override("font_size", 11)
		status_l.add_theme_color_override("font_color", Color.LIGHT_GREEN)
		vb.add_child(status_l)
		var best_skill = c.get_best_skill()
		var skill_l = Label.new()
		skill_l.text = "En İyi: %s (%d)" % [c.get_skill_name(best_skill), c.get_skill_level(best_skill)]
		# skill_l.add_theme_font_size_override("font_size", 11)
		skill_l.add_theme_color_override("font_color", Color.LIGHT_BLUE)
		vb.add_child(skill_l)
		list_node.add_child(item)

func _update_selected_concubine_details_dynamic():
	var details_root: VBoxContainer = get_node_or_null("ConcubineDetailsPage/ConcubineContent/ConcubineDetailsPanel/ConcubineDetailsScroll/ConcubineDetailsContent")
	if not details_root:
		return
	if not mission_manager:
		return
	# Seçili cariyeyi, ada göre sıralanmış listeden al
	var concubine_array: Array = _get_concubines_sorted_by_name()
	var selected: Concubine = null
	if not concubine_array.is_empty():
		current_concubine_detail_index = clamp(current_concubine_detail_index, 0, concubine_array.size() - 1)
		selected = concubine_array[current_concubine_detail_index]
	if selected == null:
		return

	# 1) Temel Bilgiler: update_basic_info_panel fonksiyonunu kullan (portre dahil)
	update_basic_info_panel(selected)

	# 2) Başarılar: update_achievements_panel fonksiyonunu kullan
	update_achievements_panel(selected)

	# 3) Yetenekler: SkillsVBox varsa içini temizleyip yeniden doldur; yoksa oluştur
	var skills_panel: Control = get_node_or_null("ConcubineDetailsPage/ConcubineContent/ConcubineDetailsPanel/ConcubineDetailsScroll/ConcubineDetailsContent/SkillsPanel")
	if skills_panel:
		var skills_vb: VBoxContainer = skills_panel.get_node_or_null("SkillsVBox")
		if not skills_vb:
			skills_vb = VBoxContainer.new()
			skills_vb.name = "SkillsVBox"
			skills_panel.add_child(skills_vb)
		# Clear
		for ch in skills_vb.get_children():
			ch.queue_free()
		# Refill
		var stitle = Label.new()
		stitle.text = "⚔️ Yetenekler"
		# stitle.add_theme_font_size_override("font_size", 18) # Remove hardcoded size to use theme
		stitle.add_theme_color_override("font_color", Color.WHITE)
		skills_vb.add_child(stitle)
		for s in selected.skills.keys():
			var l = Label.new()
			l.text = "• %s: %d" % [selected.get_skill_name(s), int(selected.skills[s])]
			# l.add_theme_font_size_override("font_size", 12) # Remove hardcoded size
			l.add_theme_color_override("font_color", Color(0.8,0.9,1,1))
			skills_vb.add_child(l)

	# 4) Görev Geçmişi: MissionHistoryVBox varsa içini temizleyip yeniden doldur; yoksa oluştur
	var hist_panel: Control = get_node_or_null("ConcubineDetailsPage/ConcubineContent/ConcubineDetailsPanel/ConcubineDetailsScroll/ConcubineDetailsContent/MissionHistoryPanel")
	if hist_panel:
		var hist_vb: VBoxContainer = hist_panel.get_node_or_null("MissionHistoryVBox")
		if not hist_vb:
			hist_vb = VBoxContainer.new()
			hist_vb.name = "MissionHistoryVBox"
			hist_panel.add_child(hist_vb)
		# Clear
		for ch in hist_vb.get_children():
			ch.queue_free()
		# Refill
		var htitle = Label.new()
		htitle.text = "📚 Görev Geçmişi"
		# htitle.add_theme_font_size_override("font_size", 18)
		htitle.add_theme_color_override("font_color", Color.WHITE)
		hist_vb.add_child(htitle)
		var history = mission_manager.get_mission_history_for_cariye(selected.id)
		var sum_success := 0
		for h in history:
			if h.get("successful", false):
				sum_success += 1
		var content = Label.new()
		content.text = "✅ Tamamlanan: %d\n❌ Başarısız: %d\n📊 Başarı Oranı: %d%%" % [
			sum_success, history.size() - sum_success, int((float(max(0,sum_success)) / float(max(1,history.size()))) * 100.0)
		]
		# content.add_theme_font_size_override("font_size", 14)
		content.add_theme_color_override("font_color", Color(0.8,0.8,0.8,1))
		hist_vb.add_child(content)

	# 5) Kontrol metni: ControlsVBox varsa temizle, yoksa oluştur
	var controls_panel: Control = get_node_or_null("ConcubineDetailsPage/ConcubineContent/ConcubineDetailsPanel/ConcubineDetailsScroll/ConcubineDetailsContent/ControlsPanel")
	if controls_panel:
		var controls_vb: VBoxContainer = controls_panel.get_node_or_null("ControlsVBox")
		if not controls_vb:
			controls_vb = VBoxContainer.new()
			controls_vb.name = "ControlsVBox"
			controls_panel.add_child(controls_vb)
		for ch in controls_vb.get_children():
			ch.queue_free()
		var ctitle = Label.new()
		ctitle.text = "🎮 KONTROLLER"
		# ctitle.add_theme_font_size_override("font_size", 18)
		ctitle.add_theme_color_override("font_color", Color.WHITE)
		controls_vb.add_child(ctitle)
		var controls_text = Label.new()
		controls_text.text = "Yukarı/Aşağı: Cariye Seç\nA tuşu: Rol Ata\nB tuşu: Geri"
		controls_text.add_theme_font_size_override("font_size", 14)
		controls_text.add_theme_color_override("font_color", Color.YELLOW)
		controls_vb.add_child(controls_text)

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

# Ada göre sıralı cariye listesi (UI listesiyle aynı sıra)
func _get_concubines_sorted_by_name() -> Array:
	var arr: Array = get_all_concubines_list()
	arr.sort_custom(func(a, b): return a.name < b.name)
	return arr

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
	print("[DEBUG_MC] open_menu: Başladı")
	visible = true
	print("[DEBUG_MC] open_menu: visible = true yapıldı")
	
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
		print("[DEBUG_MC] open_menu: idle_workers:", int(village_manager.idle_workers))
	# Test sahnelerinde worker kayıtlarını garantile
	_ensure_workers_registered()
	find_and_lock_player()
	# Ek kilit: player süreçlerini tamamen kapat
	if player and is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Not: input tüketimi `_input` içinde yapılır
	# Sayfayı doğru başlat ve UI'yı hemen doldur
	print("[DEBUG_MC] open_menu: show_page(MISSIONS) çağrılıyor")
	show_page(PageType.MISSIONS)
	
	# Layout'u zorla güncelle
	if missions_page:
		missions_page.visible = true
		print("[DEBUG_MC] open_menu: missions_page.visible zorla true yapıldı")
	else:
		print("[DEBUG_MC] open_menu: HATA! missions_page null!")
		
	# UI'ı güncelle - 3 aşamalı garanti (Hemen, Process Frame sonrası, Deferred)
	print("[DEBUG_MC] open_menu: 1. update_missions_ui (Hemen)")
	update_missions_ui()
	
	await get_tree().process_frame
	print("[DEBUG_MC] open_menu: 2. update_missions_ui (Process Frame Sonrası)")
	update_missions_ui()
	
	print("[DEBUG_MC] open_menu: 3. Deferred çağrılar yapılıyor")
	call_deferred("update_missions_ui")
	call_deferred("update_active_missions_cards")
	call_deferred("update_available_missions_cards")
	
	# Haber kuyruklarını yeniden yükle (yeni instance için)
	print("[DEBUG_MC] open_menu: Haber kuyrukları yükleniyor...")
	update_news_ui()
	print("[DEBUG_MC] open_menu: Bitti")
	_update_unread_badge()

# Mission Center menüsünü kapat
func close_menu():
	print("🎯 Mission Center kapanıyor...")
	# Açık tüccar pop-up'larını kapat (menü kapandığında kalmasın)
	if trader_mission_quantity_popup_open:
		_close_trader_mission_quantity_popup()
	if trader_mission_popup_open:
		_close_trader_mission_popup()
	if trader_buy_popup_open:
		_close_trader_buy_popup()
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

func _on_chain_progressed(chain_id: String, progress: Dictionary) -> void:
	# UI'da zincir listesini tazele
	update_mission_chains_ui()

# === HABER FİLTRELEME VE RENK KODLU UYARI SİSTEMİ ===
# (Duplicate functions removed - using the ones defined earlier)

func _update_news_filter_highlighting() -> void:
	"""Update filter bar button highlighting"""
	if not filter_village_label or not filter_world_label:
		return
	
	# Reset colors
	filter_village_label.add_theme_color_override("font_color", Color.WHITE)
	filter_world_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Highlight current filter
	match news_focus:
		"village":
			filter_village_label.add_theme_color_override("font_color", Color.YELLOW)
		"world":
			filter_world_label.add_theme_color_override("font_color", Color.YELLOW)

func _update_subcategory_highlighting() -> void:
	"""Update subcategory button highlighting"""
	for label in subcategory_labels:
		if not label:
			continue
		
		var category_key = label.name.replace("Subcategory_", "")
		var is_selected = (category_key == current_subcategory)
		
		# Reset to base color
		var base_colors = {
			"all": Color.WHITE,
			"critical": Color.RED,
			"warning": Color.ORANGE,
			"success": Color.GREEN,
			"info": Color.CYAN
		}
		
		var base_color = base_colors.get(category_key, Color.WHITE)
		var final_color = base_color if not is_selected else Color.YELLOW
		label.add_theme_color_override("font_color", final_color)

func _get_filtered_news() -> Array[Dictionary]:
	"""Get news filtered by current settings"""
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		return []
	
	var all_news = []
	
	# Get news based on current filter
	match news_focus:
		"village":
			all_news = mm.news_queue_village if mm.has_method("get_news_queue_village") else []
		"world":
			all_news = mm.news_queue_world if mm.has_method("get_news_queue_world") else []
		_:
			# Combine both
			var village_news = mm.news_queue_village if mm.has_method("get_news_queue_village") else []
			var world_news = mm.news_queue_world if mm.has_method("get_news_queue_world") else []
			all_news = village_news + world_news
	
	# Filter by subcategory
	if current_subcategory != "all":
		var filtered = []
		for news in all_news:
			var news_subcat = news.get("subcategory", "info")
			if news_subcat == current_subcategory:
				filtered.append(news)
		all_news = filtered
	
	return all_news

func _display_news_with_colors(news_list: Array[Dictionary]) -> void:
	"""Display news with color coding based on subcategory"""
	# Find news display container
	var news_display = get_node_or_null("NewsCenterPage/NewsDisplay")
	if not news_display:
		# Create news display container if it doesn't exist
		news_display = VBoxContainer.new()
		news_display.name = "NewsDisplay"
		var news_container = get_node_or_null("NewsCenterPage")
		if news_container:
			news_container.add_child(news_display)
	
	# Clear existing news
	for child in news_display.get_children():
		child.queue_free()
	
	# Display news with color coding
	for news in news_list:
		var news_item = _create_colored_news_item(news)
		news_display.add_child(news_item)

func _create_colored_news_item(news: Dictionary) -> Panel:
	"""Create a colored news item based on subcategory"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(750, 60)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_top", 5)
	vbox.add_theme_constant_override("margin_bottom", 5)
	
	# Title with color coding
	var title_label = Label.new()
	title_label.text = news.get("title", "Başlıksız Haber")
	title_label.add_theme_font_size_override("font_size", 16)
	
	# Color based on subcategory
	var subcategory = news.get("subcategory", "info")
	var title_color = _get_subcategory_color(subcategory)
	title_label.add_theme_color_override("font_color", title_color)
	
	vbox.add_child(title_label)
	
	# Content
	var content_label = Label.new()
	content_label.text = news.get("content", "")
	content_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(content_label)
	
	# Background color based on subcategory
	var bg_color = _get_subcategory_background_color(subcategory)
	panel.add_theme_color_override("background_color", bg_color)
	
	return panel

func _get_subcategory_color(subcategory: String) -> Color:
	"""Get text color for subcategory"""
	match subcategory:
		"critical":
			return Color.RED
		"warning":
			return Color.ORANGE
		"success":
			return Color.GREEN
		"info":
			return Color.CYAN
		_:
			return Color.WHITE

func _get_subcategory_background_color(subcategory: String) -> Color:
	"""Get background color for subcategory"""
	match subcategory:
		"critical":
			return Color(0.3, 0.0, 0.0, 0.3)  # Dark red with transparency
		"warning":
			return Color(0.3, 0.15, 0.0, 0.3)  # Dark orange with transparency
		"success":
			return Color(0.0, 0.3, 0.0, 0.3)   # Dark green with transparency
		"info":
			return Color(0.0, 0.0, 0.3, 0.3)   # Dark blue with transparency
		_:
			return Color(0.1, 0.1, 0.1, 0.2)   # Dark gray with transparency

# === ASKER EKİPMAN ATAMA SİSTEMİ ===

func get_barracks_soldiers() -> Array:
	"""Kışladaki askerleri ve ekipman durumlarını döndür"""
	var all_buildings = get_all_available_buildings()
	if all_buildings.is_empty():
		return []
	
	# Kışla binasını bul
	var barracks = null
	for building_info in all_buildings:
		if building_info["type"] == "Kışla":
			barracks = building_info["node"]
			break
	
	if not barracks or not barracks.has_method("get_military_force"):
		return []
	
	# Asker listesini oluştur
	var soldiers: Array = []
	if "assigned_worker_ids" in barracks:
		var vm = get_node_or_null("/root/VillageManager")
		if not vm:
			return []
		
		for worker_id in barracks.assigned_worker_ids:
			var equip = {"weapon": false, "armor": false}
			if "soldier_equipment" in barracks and barracks.soldier_equipment.has(worker_id):
				equip = barracks.soldier_equipment[worker_id]
			
			soldiers.append({
				"worker_id": worker_id,
				"equipment": equip
			})
	
	return soldiers

func handle_soldier_equipment_input(event):
	"""Asker ekipman atama menüsü için input handler"""
	if current_assignment_menu_state != AssignmentMenuState.ASKER_EKİPMAN:
		return
	
	var soldiers = get_barracks_soldiers()
	if soldiers.is_empty():
		# Eğer asker yoksa geri dön
		if event.is_action_pressed("ui_back"):
			current_assignment_menu_state = AssignmentMenuState.BİNA_DETAYI
			update_assignment_ui()
		return
	
	# Yukarı/Aşağı: Asker seçimi
	if event.is_action_pressed("ui_up"):
		current_soldier_index = (current_soldier_index - 1) % soldiers.size()
		update_assignment_ui()
	elif event.is_action_pressed("ui_down"):
		current_soldier_index = (current_soldier_index + 1) % soldiers.size()
		update_assignment_ui()
	
	# Sol/Sağ: Ekipman tipi seçimi (weapon/armor)
	elif event.is_action_pressed("ui_left"):
		current_equipment_action = 0  # weapon
		update_assignment_ui()
	elif event.is_action_pressed("ui_right"):
		current_equipment_action = 1  # armor
		update_assignment_ui()
	
	# A tuşu: Ekipman ver/al
	elif event.is_action_pressed("ui_accept"):
		if current_soldier_index < soldiers.size():
			var soldier = soldiers[current_soldier_index]
			var equipment_type = "weapon" if current_equipment_action == 0 else "armor"
			var barracks = _get_current_barracks()
			if barracks:
				var has_equipment = soldier["equipment"].get(equipment_type, false)
				if has_equipment:
					# Ekipmanı kaldır
					barracks.unequip_soldier(soldier["worker_id"], equipment_type)
				else:
					# Ekipmanı ver
					barracks.equip_soldier(soldier["worker_id"], equipment_type)
				update_assignment_ui()
	
	# B tuşu: Geri dön
	elif event.is_action_pressed("ui_back"):
		current_assignment_menu_state = AssignmentMenuState.BİNA_DETAYI
		current_soldier_index = 0
		update_assignment_ui()

func _get_current_barracks() -> Node:
	"""Şu anki seçili kışla binasını döndür"""
	var all_buildings = get_all_available_buildings()
	if all_buildings.is_empty() or current_assignment_building_index >= all_buildings.size():
		return null
	
	var selected_building_info = all_buildings[current_assignment_building_index]
	if selected_building_info["type"] == "Kışla":
		return selected_building_info["node"]
	return null

# (Duplicate update_assignment_ui function removed - using the one defined earlier)

# Kışla ekipman pop-up menüsü
func open_barracks_equipment_popup():
	"""Kışla ekipman pop-up menüsünü aç"""
	if barracks_equipment_popup_active:
		return
	
	# Pop-up panel oluştur
	barracks_equipment_popup = Panel.new()
	barracks_equipment_popup.name = "BarracksEquipmentPopup"
	barracks_equipment_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.8)  # Yarı saydam siyah arka plan
	barracks_equipment_popup.add_theme_stylebox_override("panel", overlay_style)
	add_child(barracks_equipment_popup)
	
	# İçerik paneli (ortada)
	var content_panel = Panel.new()
	content_panel.name = "ContentPanel"
	content_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content_panel.offset_left = -300
	content_panel.offset_right = 300
	content_panel.offset_top = -200
	content_panel.offset_bottom = 200
	var content_style := StyleBoxFlat.new()
	content_style.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	content_panel.add_theme_stylebox_override("panel", content_style)
	barracks_equipment_popup.add_child(content_panel)
	
	# Label oluştur
	barracks_equipment_popup_label = Label.new()
	barracks_equipment_popup_label.name = "PopupLabel"
	barracks_equipment_popup_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	barracks_equipment_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	barracks_equipment_popup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content_panel.add_child(barracks_equipment_popup_label)
	
	# Başlangıç değerleri
	barracks_equipment_selected_weapons = 0
	barracks_equipment_selected_armors = 0
	barracks_equipment_selected_row = 0
	
	barracks_equipment_popup_active = true
	# Test kolaylığı: stoklar 0 ise başlangıç stoğu ver
	var vm = get_node_or_null("/root/VillageManager")
	if vm:
		var w = int(vm.resource_levels.get("weapon", 0))
		var a = int(vm.resource_levels.get("armor", 0))
		if w == 0 and a == 0:
			vm.resource_levels["weapon"] = 5
			vm.resource_levels["armor"] = 5
			vm.emit_signal("village_data_changed")
	update_barracks_equipment_popup()

func close_barracks_equipment_popup():
	"""Kışla ekipman pop-up menüsünü kapat"""
	if not barracks_equipment_popup_active:
		return
	
	if barracks_equipment_popup:
		barracks_equipment_popup.queue_free()
		barracks_equipment_popup = null
		barracks_equipment_popup_label = null
	
	barracks_equipment_popup_active = false
	barracks_equipment_selected_weapons = 0
	barracks_equipment_selected_armors = 0
	barracks_equipment_selected_row = 0

func update_barracks_equipment_popup():
	"""Pop-up menü UI'ını güncelle"""
	if not barracks_equipment_popup_active or not barracks_equipment_popup_label:
		return
	
	var barracks = _get_current_barracks()
	if not barracks:
		barracks_equipment_popup_label.text = "Hata: Kışla bulunamadı!"
		return
	
	var soldiers = get_barracks_soldiers()
	var vm = get_node_or_null("/root/VillageManager")
	var available_weapons = vm.resource_levels.get("weapon", 0) if vm else 0
	var available_armors = vm.resource_levels.get("armor", 0) if vm else 0
	var soldier_count = soldiers.size()
	
	var text = "=== ASKER EKİPMAN DAĞITIMI ===\n\n"
	text += "📦 Stok: Silah: %d | Zırh: %d\n" % [available_weapons, available_armors]
	text += "👥 Asker Sayısı: %d\n\n" % soldier_count
	
	# Silah satırı
	if barracks_equipment_selected_row == 0:
		text += "> ⚔️ Silah: %d\n" % barracks_equipment_selected_weapons
	else:
		text += "  ⚔️ Silah: %d\n" % barracks_equipment_selected_weapons
	
	# Zırh satırı
	if barracks_equipment_selected_row == 1:
		text += "> 🛡️ Zırh: %d\n\n" % barracks_equipment_selected_armors
	else:
		text += "  🛡️ Zırh: %d\n\n" % barracks_equipment_selected_armors
	
	text += "Yukarı/Aşağı: Satır Seç\n"
	text += "Sol/Sağ: Miktar Ayarla\n"
	text += "A tuşu: Dağıt\n"
	text += "B tuşu: İptal"
	
	barracks_equipment_popup_label.text = text

# (duplicate stubs removed)

func handle_barracks_equipment_popup_input(event):
	"""Pop-up menü için input handler"""
	if not barracks_equipment_popup_active:
		return

	# Zamanlayıcı: fazla tekrarları sınırlamak için
	var now_ms = Time.get_ticks_msec()
	
	# Yukarı/Aşağı: Satır seçimi (Silah/Zırh)
	if event.is_action_pressed("ui_up"):
		barracks_equipment_selected_row = 0  # Silah satırı
		update_barracks_equipment_popup()
	elif event.is_action_pressed("ui_down"):
		barracks_equipment_selected_row = 1  # Zırh satırı
		update_barracks_equipment_popup()
	
	# Sol/Sağ: Seçili satırdaki miktarı ayarla
	elif event.is_action_pressed("ui_right"):
		if now_ms - _assign_lr_last_ms < _assign_lr_cooldown_ms:
			return
		_assign_lr_last_ms = now_ms
		if barracks_equipment_selected_row == 0:
			# Silah sayısını artır
			var vm = get_node_or_null("/root/VillageManager")
			var available_weapons = vm.resource_levels.get("weapon", 0) if vm else 0
			var soldiers = get_barracks_soldiers()
			var max_weapons = min(available_weapons, soldiers.size())
			barracks_equipment_selected_weapons = min(max_weapons, barracks_equipment_selected_weapons + 1)
		else:
			# Zırh sayısını artır
			var vm = get_node_or_null("/root/VillageManager")
			var available_armors = vm.resource_levels.get("armor", 0) if vm else 0
			var soldiers = get_barracks_soldiers()
			var max_armors = min(available_armors, soldiers.size())
			barracks_equipment_selected_armors = min(max_armors, barracks_equipment_selected_armors + 1)
		update_barracks_equipment_popup()
	elif event.is_action_pressed("ui_left"):
		if now_ms - _assign_lr_last_ms < _assign_lr_cooldown_ms:
			return
		_assign_lr_last_ms = now_ms
		if barracks_equipment_selected_row == 0:
			# Silah sayısını azalt
			barracks_equipment_selected_weapons = max(0, barracks_equipment_selected_weapons - 1)
		else:
			# Zırh sayısını azalt
			barracks_equipment_selected_armors = max(0, barracks_equipment_selected_armors - 1)
		update_barracks_equipment_popup()
	
	# A tuşu: Dağıt
	elif event.is_action_pressed("ui_accept"):
		distribute_equipment_to_soldiers()
		close_barracks_equipment_popup()
		update_assignment_ui()
	
	# B tuşu: İptal
	elif event.is_action_pressed("ui_back") or event.is_action_pressed("ui_cancel"):
		close_barracks_equipment_popup()
		update_assignment_ui()

func distribute_equipment_to_soldiers():
	"""Seçilen miktarda silah ve zırhı askerlere dağıt"""
	var barracks = _get_current_barracks()
	if not barracks:
		print("❌ Kışla bulunamadı!")
		return
	
	var soldiers = get_barracks_soldiers()
	if soldiers.is_empty():
		print("❌ Kışlada asker yok!")
		return
	
	# Silah dağıtımı
	var weapons_distributed = 0
	for i in range(min(barracks_equipment_selected_weapons, soldiers.size())):
		var soldier = soldiers[i]
		if not soldier["equipment"].get("weapon", false):
			if barracks.equip_soldier(soldier["worker_id"], "weapon"):
				weapons_distributed += 1
	
	# Zırh dağıtımı
	var armors_distributed = 0
	for i in range(min(barracks_equipment_selected_armors, soldiers.size())):
		var soldier = soldiers[i]
		if not soldier["equipment"].get("armor", false):
			if barracks.equip_soldier(soldier["worker_id"], "armor"):
				armors_distributed += 1
	
	print("✅ Ekipman dağıtıldı: %d silah, %d zırh" % [weapons_distributed, armors_distributed])
	
	# VillageManager'a haber ver
	var vm = get_node_or_null("/root/VillageManager")
	if vm:
		vm.emit_signal("village_data_changed")

# --- CARİYE ROL ATAMA SİSTEMİ ---

func open_concubine_role_popup():
	"""Cariye rol atama pop-up'ını aç"""
	if current_concubine_role_popup_open:
		return
	
	# Seçili cariyeyi al
	var all_concubines = get_all_concubines_list()
	if all_concubines.is_empty() or current_concubine_detail_index >= all_concubines.size():
		print("❌ Cariye bulunamadı!")
		return
	
	var selected_concubine = all_concubines[current_concubine_detail_index]
	
	# Pop-up panel oluştur
	concubine_role_popup = Panel.new()
	concubine_role_popup.name = "ConcubineRolePopup"
	concubine_role_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.8)  # Yarı saydam siyah arka plan
	concubine_role_popup.add_theme_stylebox_override("panel", overlay_style)
	add_child(concubine_role_popup)
	
	# İçerik paneli (ortada)
	var content_panel = Panel.new()
	content_panel.name = "ContentPanel"
	content_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content_panel.offset_left = -300
	content_panel.offset_right = 300
	content_panel.offset_top = -200
	content_panel.offset_bottom = 200
	var content_style := StyleBoxFlat.new()
	content_style.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	content_panel.add_theme_stylebox_override("panel", content_style)
	concubine_role_popup.add_child(content_panel)
	
	# Label oluştur
	concubine_role_popup_label = Label.new()
	concubine_role_popup_label.name = "PopupLabel"
	concubine_role_popup_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	concubine_role_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	concubine_role_popup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content_panel.add_child(concubine_role_popup_label)
	
	# Başlangıç değerleri - mevcut rolü seç
	current_concubine_role_selection = int(selected_concubine.role)
	
	current_concubine_role_popup_open = true
	update_concubine_role_popup()

func close_concubine_role_popup():
	"""Cariye rol atama pop-up'ını kapat"""
	if not current_concubine_role_popup_open:
		return
	
	if concubine_role_popup:
		concubine_role_popup.queue_free()
		concubine_role_popup = null
		concubine_role_popup_label = null
	
	current_concubine_role_popup_open = false
	current_concubine_role_selection = 0

func update_concubine_role_popup():
	"""Pop-up menü UI'ını güncelle"""
	if not current_concubine_role_popup_open or not concubine_role_popup_label:
		return
	
	# Seçili cariyeyi al
	var all_concubines = get_all_concubines_list()
	if all_concubines.is_empty() or current_concubine_detail_index >= all_concubines.size():
		concubine_role_popup_label.text = "Hata: Cariye bulunamadı!"
		return
	
	var selected_concubine = all_concubines[current_concubine_detail_index]
	
	var text = "=== CARİYE ROL ATAMA ===\n\n"
	text += "👤 Cariye: %s\n" % selected_concubine.name
	text += "📊 Mevcut Rol: %s\n\n" % selected_concubine.get_role_name()
	
	# Rol seçenekleri (Tüccar etkin - ticaret görevleri için)
	var roles = [
		{"id": 0, "name": "Rol Yok", "active": true},
		{"id": 1, "name": "Komutan", "active": true},
		{"id": 2, "name": "Ajan", "active": false},
		{"id": 3, "name": "Diplomat", "active": false},
		{"id": 4, "name": "Tüccar", "active": true},
		{"id": 5, "name": "Alim", "active": true},
		{"id": 6, "name": "Tibbiyeci", "active": true}
	]
	
	for role in roles:
		var prefix = "> " if current_concubine_role_selection == role.id else "  "
		var color = "" if role.active else " (Gelecekte)"
		text += "%s%s%s\n" % [prefix, role.name, color]
	
	text += "\nYukarı/Aşağı: Rol Seç\n"
	text += "A tuşu: Uygula\n"
	text += "B tuşu: İptal"
	
	concubine_role_popup_label.text = text

func handle_concubine_role_popup_input(event):
	"""Pop-up menü için input handler"""
	if not current_concubine_role_popup_open:
		return
	
	# Yukarı/Aşağı: Rol seçimi (hassasiyet kontrolü ile)
	if Input.is_action_just_pressed("ui_up"):
		current_concubine_role_selection = max(0, current_concubine_role_selection - 1)
		update_concubine_role_popup()
	elif Input.is_action_just_pressed("ui_down"):
		current_concubine_role_selection = min(int(Concubine.Role.TIBBIYECI), current_concubine_role_selection + 1)
		update_concubine_role_popup()
	
	# A tuşu: Rolü uygula
	elif event.is_action_pressed("ui_accept"):
		apply_concubine_role()
		close_concubine_role_popup()
		update_concubine_details_ui()
	
	# B tuşu: İptal
	elif event.is_action_pressed("ui_back") or event.is_action_pressed("ui_cancel"):
		close_concubine_role_popup()

func apply_concubine_role():
	"""Seçilen rolü cariyeye uygula"""
	if not mission_manager:
		print("❌ MissionManager bulunamadı!")
		return
	
	# Seçili cariyeyi al
	var all_concubines = get_all_concubines_list()
	if all_concubines.is_empty() or current_concubine_detail_index >= all_concubines.size():
		print("❌ Cariye bulunamadı!")
		return
	
	var selected_concubine = all_concubines[current_concubine_detail_index]
	var new_role = Concubine.Role.values()[current_concubine_role_selection]
	
	# Rolü ata
	var success = mission_manager.set_concubine_role(selected_concubine.id, new_role)
	if success:
		print("✅ Cariye rolü güncellendi: %s -> %s" % [selected_concubine.name, selected_concubine.get_role_name()])
	else:
		print("❌ Cariye rolü güncellenemedi!")
