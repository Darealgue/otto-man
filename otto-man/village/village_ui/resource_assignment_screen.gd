extends Control

signal back_button_pressed
signal worker_assigned(worker_id: int, resource_type: String)

# Düğümler
@onready var resource_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ResourceList
@onready var back_button: Button = $PanelContainer/MarginContainer/VBoxContainer/BackButton
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel

# Seçilen işçi
var selected_worker_id: int = -1
var selected_resource_type: String = ""

func _ready() -> void:
	print("Resource atama ekranı başlatıldı")
	
	# Başlık ayarla
	title_label.text = "Kaynak Yönetimi"
	
	# Focus mode'u aktif hale getir
	for child in resource_list.get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_ALL
			print("Kaynak butonu hazırlandı: ", child.name)
	
	# Geri butonu focus mode
	back_button.focus_mode = Control.FOCUS_ALL
	
	# İlk butona odaklan
	if resource_list.get_child_count() > 0:
		var first_button = resource_list.get_child(0)
		if first_button is Button:
			first_button.grab_focus()
			print("İlk butona odaklandı: ", first_button.name)

func _on_back_button_pressed() -> void:
	print("Geri butonu tıklandı")
	back_button_pressed.emit()

# _on_resource_button_pressed, Sahne dosyasında düğmelere bağlanmıştır
func _on_resource_button_pressed(button_node=null) -> void:
	# Basılan düğmeyi tespit et
	var button: Button
	
	if button_node == null:
		# Eğer bind ile bir nesne gelmediyse (doğrudan tıklama durumu)
		button = get_viewport().gui_get_focus_owner() as Button
		print("Odak sahibi buton tespit edildi: ", button.name if button else "Bulunamadı")
	elif button_node is int:
		# Eğer bind ile bir int geldiyse (Scene tarafından otomatik bağlantı)
		print("Sahneden bir buton basıldı, bind değeri: ", button_node)
		button = get_viewport().gui_get_focus_owner() as Button
	else:
		# Eğer bind ile bir Control nesnesi geldiyse (_connect_resource_buttons() ile bağlanan)
		button = button_node as Button
		print("Tıklanan kaynak butonu: ", button.name if button else "Belirsiz")
	
	if not button:
		print("HATA: Basılan buton tespit edilemedi!")
		return
	
	print("İşlenen buton: ", button.name)
	
	if selected_worker_id == -1:
		print("HATA: Hiçbir işçi seçilmemiş!")
		return
	
	# Butonun ismine göre kaynak türünü belirle
	var resource_type = button.name.to_lower().replace("button", "")
	print("Kaynak türü: ", resource_type)
	
	# Eğer belirli bir kaynak talebi varsa o tipe ata, yoksa butonun türünü kullan
	if selected_resource_type != "":
		resource_type = selected_resource_type
		print("Önceden seçilmiş kaynak tipine atanıyor: ", resource_type)
	
	# VillageManager aracılığıyla işçiyi kaynağa ata
	var success = VillageManager.assign_worker_to_resource(selected_worker_id, resource_type)
	print("İşçi atama sonucu: ", success)
	
	# Sinyal gönder
	worker_assigned.emit(selected_worker_id, resource_type)
	
	# Geri dön
	back_button_pressed.emit()

func set_selected_worker(worker_id: int) -> void:
	selected_worker_id = worker_id
	print("Seçilen işçi ID: ", worker_id)
	
	# Başlığı güncelle
	var worker_name = "İşçi #" + str(worker_id)
	title_label.text = worker_name + " için Kaynak Seç"
	
	# İlk butona odaklan
	if resource_list.get_child_count() > 0:
		var first_button = resource_list.get_child(0)
		if first_button is Button:
			first_button.grab_focus()
			print("İlk kaynak butonuna odaklandı: ", first_button.name)

# Seçili kaynak tipini belirle (tıklanan kaynak göre)
func set_resource_type(resource_type: String) -> void:
	selected_resource_type = resource_type
	print("Kaynak tipi seçildi: ", resource_type)
	
	# Başlığı güncelle
	if resource_type != "":
		title_label.text = resource_type.capitalize() + " Kaynağı Yönetimi"
	else:
		title_label.text = "Kaynak Yönetimi"
	
	# İlgili butona odaklan
	for child in resource_list.get_children():
		if child is Button and child.name.to_lower().find(resource_type.to_lower()) != -1:
			child.grab_focus()
			print("İlgili kaynak butonuna odaklandı: ", child.name)
			break

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
		print("Attack tuşuna basıldı, seçilen butona tıklanacak")
		_press_focused_button()
		get_viewport().set_input_as_handled()

func _navigate_button_list(direction: int) -> void:
	var buttons = []
	
	# Tüm butonları topla
	for child in resource_list.get_children():
		if child is Button:
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
		print("Hiçbir buton odakta değildi, ilk butona odaklandı: ", buttons[0].name)
		return
	
	# Yeni indeksi hesapla
	var new_index = (current_index + direction + buttons.size()) % buttons.size()
	
	# Yeni butona odaklan
	buttons[new_index].grab_focus()
	print("Odak değişti: ", buttons[current_index].name, " -> ", buttons[new_index].name)

func _press_focused_button() -> void:
	var focused_button = get_viewport().gui_get_focus_owner() as Button
	
	if focused_button:
		print("Odaktaki butona tıklanıyor: ", focused_button.name)
		if focused_button == back_button:
			_on_back_button_pressed()
		else:
			# Kaynak butonlarından biriyse
			_on_resource_button_pressed()
	else:
		print("UYARI: Odakta hiçbir buton yok!") 
