extends Control
class_name BuildingSelectionUI

signal building_selected(building_type: String)
signal ui_closed

@export var button_scene: PackedScene = null

var current_slot_index: int = -1
var available_building_types: Array = []

@onready var building_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/BuildingContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton

func _ready() -> void:
	# UI başlatıldığında gizle
	visible = false
	
	# Kapat düğmesini bağla
	close_button.pressed.connect(_on_close_button_pressed)

func show_for_slot(slot_index: int, allowed_types: Array) -> void:
	print("BuildingSelectionUI: show_for_slot çağrıldı - slot_index:", slot_index, ", allowed_types:", allowed_types)
	
	# Geçerli slotu kaydet
	current_slot_index = slot_index
	
	# İzin verilen bina tiplerini kaydet
	available_building_types = allowed_types
	
	# Temizle
	_clear_building_buttons()
	
	# Bina düğmelerini oluştur
	_create_building_buttons()
	
	# Ekranı göster
	visible = true
	print("BuildingSelectionUI: Görünürlük true olarak ayarlandı.")
	
	# Başlık güncelle
	title_label.text = "İnşaat Yönetimi"
	print("BuildingSelectionUI: Başlık güncellendi: ", title_label.text)
	
	# Kapat düğmesine odak modu ver
	close_button.focus_mode = Control.FOCUS_ALL

func _clear_building_buttons() -> void:
	# Mevcut düğmeleri temizle
	for child in building_container.get_children():
		child.queue_free()

func _create_building_buttons() -> void:
	if button_scene == null:
		push_error("Bina seçim düğmesi sahnesi ayarlanmamış!")
		return
	
	# Her bina tipi için düğme oluştur
	for building_type in available_building_types:
		var button = button_scene.instantiate()
		building_container.add_child(button)
		
		# Düğme özelliklerini ayarla
		button.set_building_type(building_type)
		
		# Gereksinimleri kontrol et ve uygun şekilde devre dışı bırak
		var can_build = VillageManager.can_build(building_type)
		button.set_enabled(can_build)
		
		# Butona tıklama fonksiyonunu bağla
		button.pressed.connect(_on_building_button_pressed.bind(building_type))
		
		# Odak modunu aktif hale getir
		button.focus_mode = Control.FOCUS_ALL
	
	# İlk düğmeye odaklan
	if building_container.get_child_count() > 0:
		var first_button = building_container.get_child(0)
		first_button.grab_focus()

func _on_building_button_pressed(building_type: String) -> void:
	# Bina seçildi sinyali gönder
	building_selected.emit(building_type)
	
	# UI'ı kapat
	hide()
	ui_closed.emit()

func _on_close_button_pressed() -> void:
	# UI'ı kapat
	hide()
	ui_closed.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	# Yön tuşları ile navigasyon
	if event.is_action_pressed("ui_up"):
		_navigate_button_list(-1)
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("ui_down"):
		_navigate_button_list(1)
		get_viewport().set_input_as_handled()
	
	# Seçim onayı
	elif event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		_press_focused_button()
		get_viewport().set_input_as_handled()
	
	# ESC tuşuna basılınca kapat
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("jump"):
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()

func _navigate_button_list(direction: int) -> void:
	var buttons = []
	
	# Tüm bina butonlarını topla
	for child in building_container.get_children():
		if child is Button:
			buttons.append(child)
	
	# Kapat butonunu ekle
	buttons.append(close_button)
	
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
	
	# Yeni indeksi hesapla (döngüsel)
	var new_index = (current_index + direction + buttons.size()) % buttons.size()
	
	# Yeni butona odaklan
	buttons[new_index].grab_focus()

func _press_focused_button() -> void:
	var focused_button = get_viewport().gui_get_focus_owner() as Button
	
	if focused_button:
		print("Seçilen butona tıklandı: ", focused_button.name)
		if focused_button == close_button:
			_on_close_button_pressed()
		else:
			# Butonun tıklama olayını tetikle
			focused_button.pressed.emit()
	else:
		print("UYARI: Odakta hiçbir buton yok!") 