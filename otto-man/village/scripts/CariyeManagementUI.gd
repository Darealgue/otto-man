extends PanelContainer

# --- UI Element References ---
# @onready yerine _ready() içinde get_node() kullanılacak
var cariye_item_list: ItemList
var mission_item_list: ItemList
var assign_button: Button
var close_button: Button

# Seçili cariye ve görevin ID'lerini tutmak için
var selected_cariye_id: int = -1
var selected_gorev_id: int = -1

# --- Ready Function ---
func _ready() -> void:
	# Node referanslarını get_node_or_null ile al ve kontrol et
	cariye_item_list = get_node_or_null("MarginContainer/MainVBox/ContentHBox/CariyeVBox/CariyeItemList")
	if cariye_item_list == null:
		printerr("ERROR: CariyeItemList node not found at path: MarginContainer/MainVBox/ContentHBox/CariyeVBox/CariyeItemList")
		return # Hata durumunda devam etme
	
	mission_item_list = get_node_or_null("MarginContainer/MainVBox/ContentHBox/MissionVBox/MissionItemList")
	if mission_item_list == null:
		printerr("ERROR: MissionItemList node not found at path: MarginContainer/MainVBox/ContentHBox/MissionVBox/MissionItemList")
		return
		
	assign_button = get_node_or_null("MarginContainer/MainVBox/ActionHBox/AssignButton")
	if assign_button == null:
		printerr("ERROR: AssignButton node not found at path: MarginContainer/MainVBox/ActionHBox/AssignButton")
		return
		
	close_button = get_node_or_null("MarginContainer/MainVBox/ActionHBox/CloseButton")
	if close_button == null:
		printerr("ERROR: CloseButton node not found at path: MarginContainer/MainVBox/ActionHBox/CloseButton")
		return

	# ItemList sinyallerini bağla (bir öğe seçildiğinde)
	cariye_item_list.item_selected.connect(_on_cariye_item_selected)
	mission_item_list.item_selected.connect(_on_mission_item_selected)
	
	# Buton sinyallerini bağla
	assign_button.pressed.connect(_on_assign_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Başlangıçta listeleri doldur ve buton durumunu ayarla
	populate_cariye_list()
	populate_mission_list()
	_update_assign_button_state()
	
	# VillageManager'dan gelen sinyallere bağlan
	if VillageManager.has_signal("cariye_data_changed"):
		VillageManager.cariye_data_changed.connect(populate_cariye_list)
	else:
		printerr("VillageManager'da 'cariye_data_changed' sinyali bulunamadı!")
		
	if VillageManager.has_signal("gorev_data_changed"):
		VillageManager.gorev_data_changed.connect(populate_mission_list)
	else:
		printerr("VillageManager'da 'gorev_data_changed' sinyali bulunamadı!")

# --- List Population Functions ---

# Cariye listesini VillageManager'dan alınan verilerle doldurur
func populate_cariye_list() -> void:
	# Null kontrolü eklendi
	if cariye_item_list == null:
		printerr("ERROR: populate_cariye_list called but cariye_item_list is null!")
		return
		
	cariye_item_list.clear()
	var cariyeler: Dictionary = VillageManager.cariyeler
	for id in cariyeler:
		var cariye: Dictionary = cariyeler[id]
		# Doğru dictionary anahtarları kullanıldı
		var cariye_name = cariye.get("isim", "İsimsiz") 
		var cariye_level = cariye.get("seviye", 0)    
		var cariye_status = cariye.get("durum", "Bilinmiyor") 
		var cariye_text: String = "%s (Seviye %d) - %s" % [cariye_name, cariye_level, cariye_status]
		cariye_item_list.add_item(cariye_text)
		# Öğe metadata'sına cariye ID'sini ekle
		cariye_item_list.set_item_metadata(cariye_item_list.item_count - 1, id)

# Görev listesini VillageManager'dan alınan verilerle doldurur
func populate_mission_list() -> void:
	# Null kontrolü eklendi
	if mission_item_list == null:
		printerr("ERROR: populate_mission_list called but mission_item_list is null!")
		return
		
	mission_item_list.clear()
	var gorevler: Dictionary = VillageManager.gorevler
	for id in gorevler:
		var gorev: Dictionary = gorevler[id]
		# Göreve atanmış cariye varsa göster
		var assignment_text: String = ""
		# Atanmış cariye ID'sini kontrol etme mekanizması VillageManager'a göre güncellenmeli
		# Şimdilik bu kısmı basitleştirelim veya VillageManager'daki yapıyı kullanalım
		# (Önceki kod parçacığında VillageManager.get_cariye kullanılıyordu, onu geri alabiliriz)
		# --- VillageManager.active_missions kontrolü daha doğru olabilir --- 
		var is_assigned = false
		var assigned_cariye_name = ""
		for cariye_id_in_mission in VillageManager.active_missions:
			if VillageManager.active_missions[cariye_id_in_mission].get("gorev_id") == id:
				is_assigned = true
				var assigned_c = VillageManager.cariyeler.get(cariye_id_in_mission)
				if assigned_c:
					assigned_cariye_name = assigned_c.get("isim", "Bilinmeyen")
				break # Görevi bulan ilk cariyeyi al
				
		if is_assigned:
			assignment_text = " [Atanan: %s]" % assigned_cariye_name
		# -------------------------------------------------------------
			
		# Doğru dictionary anahtarları kullanıldı
		var gorev_name = gorev.get("isim", "İsimsiz Görev")
		var gorev_difficulty = gorev.get("zorluk", "Bilinmiyor")
		var gorev_text: String = "%s (Zorluk: %s)%s" % [gorev_name, gorev_difficulty, assignment_text]
		mission_item_list.add_item(gorev_text)
		# Öğe metadata'sına görev ID'sini ekle
		mission_item_list.set_item_metadata(mission_item_list.item_count - 1, id)

# --- Signal Handlers ---

func _on_cariye_item_selected(index: int) -> void:
	selected_cariye_id = cariye_item_list.get_item_metadata(index)
	_update_assign_button_state()
	print("UI: Cariye seçildi: ID %d" % selected_cariye_id)

func _on_mission_item_selected(index: int) -> void:
	var metadata = mission_item_list.get_item_metadata(index)
	# Eğer metadata beklenen türde (int) değilse, dönüştürmeyi dene veya hata ver
	if typeof(metadata) == TYPE_INT:
		selected_gorev_id = metadata
	else:
		printerr("ERROR: Mission metadata is not an integer!")
		selected_gorev_id = -1 # Hata durumunda ID'yi sıfırla
		
	_update_assign_button_state()
	print("UI: Görev seçildi: ID %d" % selected_gorev_id)

func _on_assign_button_pressed() -> void:
	if selected_cariye_id != -1 and selected_gorev_id != -1:
		print("UI: Göreve ata butonuna basıldı. Cariye: %d, Görev: %d" % [selected_cariye_id, selected_gorev_id])
		var result = VillageManager.assign_cariye_to_mission(selected_cariye_id, selected_gorev_id)
		if result:
			print("UI: Görev atama başarılı.")
			# Atama sonrası seçimleri sıfırla
			cariye_item_list.deselect_all()
			mission_item_list.deselect_all()
			selected_cariye_id = -1
			selected_gorev_id = -1
			_update_assign_button_state()
		else:
			print("UI: Görev atama başarısız (belki cariye zaten görevde veya görev dolu).")
	else:
		print("UI: Atama yapmak için bir cariye ve bir görev seçilmelidir.")

func _on_close_button_pressed() -> void:
	hide()

# --- Helper Functions ---

# "Göreve Ata" butonunun durumunu günceller
func _update_assign_button_state() -> void:
	# Null kontrolü eklendi
	if assign_button == null:
		printerr("ERROR: _update_assign_button_state called but assign_button is null!")
		return
		
	# Eğer geçerli bir cariye ve görev seçiliyse ve görev boşsa butonu etkinleştir
	if selected_cariye_id != -1 and selected_gorev_id != -1:
		# Fonksiyon çağırmak yerine dictionary'den .get() ile al
		var gorev = VillageManager.gorevler.get(selected_gorev_id)
		var cariye = VillageManager.cariyeler.get(selected_cariye_id)
		# Görev ve cariyenin var olduğundan emin ol
		# Doğru dictionary anahtarları ve görev boşta kontrolü güncellendi
		if gorev and cariye:
			var is_mission_available = true # Görevin boşta olduğunu varsayalım
			for cariye_id_in_mission in VillageManager.active_missions:
				if VillageManager.active_missions[cariye_id_in_mission].get("gorev_id") == selected_gorev_id:
					is_mission_available = false # Görev zaten atanmış
					break
					
			# Cariye durumu 'boşta' ise ve görev boşta ise butonu etkinleştir
			if is_mission_available and cariye.get("durum", "") == "boşta":
				assign_button.disabled = false
			else:
				assign_button.disabled = true
		else:
			assign_button.disabled = true # Görev veya cariye bulunamadıysa
	else:
		assign_button.disabled = true

# --- Visibility Change ---
# Bu fonksiyon node'un görünürlüğü değiştiğinde otomatik çağrılır.
# Sahne ağacında node'un `visibility_changed` sinyalini kendisine bağlamanız gerekebilir
# (Gerçi PanelContainer gibi bazı nodelar bunu otomatik yapabilir).
# Emin olmak için Godot editöründe PanelContainer'ı seçip Sinyaller sekmesine bakabilirsiniz.
# Eğer bağlı değilse, sinyali kendinize bağlayın (_on_visibility_changed metoduna).
func _on_visibility_changed() -> void:
	if visible:
		# Görünür olduğunda listeleri ve buton durumunu güncelle
		populate_cariye_list()
		populate_mission_list()
		_update_assign_button_state()
	else:
		# Gizlendiğinde seçimleri temizle
		# Null kontrolü
		if cariye_item_list != null:
			cariye_item_list.deselect_all()
		
		if mission_item_list != null:
			mission_item_list.deselect_all()
			
		selected_cariye_id = -1
		selected_gorev_id = -1

# --- YENİ: Ortalanmış Gösterme Fonksiyonu (await ile) ---
func show_centered() -> void:
	# Önce görünür yap
	visible = true
	# Boyutların hesaplanması için bir frame bekle
	await get_tree().process_frame
	# Viewport ve panel boyutlarını al
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = size
	# Ortalanmış pozisyonu hesapla
	var centered_pos = (viewport_size - panel_size) / 2
	# Pozisyonu ayarla
	position = centered_pos
	# Eğer Cariye menüsünün de açıldığında güncellenmesi gereken
	# bir fonksiyonu varsa, onu burada çağırabilirsin.
	# Örn: if has_method("update_cariye_ui"): update_cariye_ui()
	
	# Mevcut null hatalarını gidermek için UI güncelleme fonksiyonlarını çağırabiliriz
	# Ancak bu fonksiyonların kendisi de null check yapmalı
	if has_method("populate_cariye_list"):
		populate_cariye_list()
	if has_method("populate_mission_list"):
		populate_mission_list()
	if has_method("_update_assign_button_state"):
		_update_assign_button_state()
