extends Control

signal back_button_pressed
signal worker_assigned(worker_id: int, building_id: int)

# Düğümler
@onready var building_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/BuildingList
@onready var back_button: Button = $PanelContainer/MarginContainer/VBoxContainer/BackButton
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var no_buildings_label: Label = $PanelContainer/MarginContainer/VBoxContainer/NoBuildingsLabel

# Seçilen işçi
var selected_worker_id: int = -1

func _ready() -> void:
	# Odak modu ayarla
	back_button.focus_mode = Control.FOCUS_ALL
	
	# Butonlara sinyal bağla
	back_button.pressed.connect(_on_back_button_pressed)
	
	# Binaları listele
	_populate_building_list()

func _populate_building_list() -> void:
	# Mevcut butonları temizle
	for child in building_list.get_children():
		child.queue_free()
	
	# Binaları al
	var buildings = VillageManager.get_buildings_data()
	
	if buildings.is_empty():
		# Bina yoksa uyarı göster
		building_list.visible = false
		no_buildings_label.visible = true
		return
	else:
		building_list.visible = true
		no_buildings_label.visible = false
	
	# Her bina için buton oluştur
	for building_id in buildings:
		var building_data = buildings[building_id]
		var button = Button.new()
		
		building_list.add_child(button)
		
		# Buton özelliklerini ayarla
		button.text = _get_building_name(building_data.type) + " #" + str(building_id)
		button.focus_mode = Control.FOCUS_ALL
		
		# Doluluk durumuna göre metni güncelle
		if building_data.worker_id != -1:
			button.text += " (Dolu)"
			button.disabled = true
		
		# Butona tıklama olayını bağla
		button.pressed.connect(_on_building_button_pressed.bind(building_id))
	
	# İlk butona odaklan
	_focus_first_available_button()

func _get_building_name(building_type: String) -> String:
	match building_type:
		"house": return "Ev"
		"farm": return "Çiftlik"
		"lumberjack": return "Oduncu"
		"well": return "Kuyu"
		"mine": return "Maden"
		"tower": return "Kule"
		"blacksmith": return "Demirci"
		_: return building_type.capitalize()

func _on_back_button_pressed() -> void:
	back_button_pressed.emit()

func _on_building_button_pressed(building_id: int) -> void:
	if selected_worker_id == -1:
		return
	
	# VillageManager aracılığıyla işçiyi binaya ata
	VillageManager.assign_worker_to_building(selected_worker_id, building_id)
	
	# Sinyal gönder
	worker_assigned.emit(selected_worker_id, building_id)
	
	# Geri dön
	back_button_pressed.emit()

func set_selected_worker(worker_id: int) -> void:
	selected_worker_id = worker_id
	
	# Başlığı güncelle
	var worker_name = "İşçi #" + str(worker_id)
	title_label.text = worker_name + " için Bina Seç"
	
	# Binaları yeniden popüle et (başka bir işçinin binadan çıkmış olma ihtimali var)
	_populate_building_list()
	
	# İlk butona odaklan
	_focus_first_available_button()

func _focus_first_available_button() -> void:
	for child in building_list.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			return
	
	# Kullanılabilir buton yoksa geri butonuna odaklan
	back_button.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Yön tuşları ile butonlar arasında gezin
	if event.is_action_pressed("ui_up"):
		_navigate_button_list(-1)
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("ui_down"):
		_navigate_button_list(1)
		get_viewport().set_input_as_handled()
	
	# Seçme
	elif event.is_action_pressed("attack"):
		_press_focused_button()
		get_viewport().set_input_as_handled()

func _navigate_button_list(direction: int) -> void:
	var buttons = []
	
	# Tüm butonları topla (devre dışı olmayanlar)
	for child in building_list.get_children():
		if child is Button and not child.disabled:
			buttons.append(child)
	
	# Geri butonunu da ekle
	buttons.append(back_button)
	
	if buttons.is_empty():
		return
	
	# Şu anda odaklanan butonu bul
	var current_index = -1
	for i in range(buttons.size()):
		if buttons[i].has_focus():
			current_index = i
			break
	
	if current_index == -1:
		# Hiçbir buton odaklanmamışsa ilk butona odaklan
		buttons[0].grab_focus()
		return
	
	# Yeni indeksi hesapla
	var new_index = (current_index + direction + buttons.size()) % buttons.size()
	
	# Yeni butona odaklan
	buttons[new_index].grab_focus()

func _press_focused_button() -> void:
	# Önce bina listesindeki butonları kontrol et
	for child in building_list.get_children():
		if child is Button and child.has_focus() and not child.disabled:
			child.emit_signal("pressed")
			return
	
	# Sonra geri butonunu kontrol et
	if back_button.has_focus():
		back_button.emit_signal("pressed") 