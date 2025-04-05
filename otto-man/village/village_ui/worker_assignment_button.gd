extends Button
class_name WorkerAssignmentButton

var worker_id: int = -1
var worker_name: String = "Worker"
var assigned_resource: String = ""

@onready var name_label: Label = $HBoxContainer/NameLabel
@onready var resource_label: Label = $HBoxContainer/ResourceLabel

func _ready() -> void:
	# Focus mode'u aktif hale getir
	focus_mode = FOCUS_ALL
	
	# İşçi bilgilerini güncelle
	update_display()
	
	# Butona tıklama olayını bağla
	pressed.connect(_on_button_pressed)
	
	# Focus değişikliği olaylarını takip et
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

func set_worker_id(id: int) -> void:
	worker_id = id
	update_display()

func set_worker_name(name: String) -> void:
	worker_name = name
	update_display()

func set_assigned_resource(resource: String) -> void:
	assigned_resource = resource
	update_display()

func update_display() -> void:
	# İşçi adını göster
	if name_label:
		name_label.text = worker_name
	
	# Atanan kaynağı göster
	if resource_label:
		if assigned_resource == "":
			resource_label.text = "Atanmamış"
		else:
			var resource_name = ""
			match assigned_resource:
				"wood": resource_name = "Oduncu"
				"water": resource_name = "Su Taşıyıcı"
				"food": resource_name = "Avcı"
				"stone": resource_name = "Taş Ustası"
				"metal": resource_name = "Madenci"
				_: resource_name = assigned_resource
			
			resource_label.text = resource_name

func _on_button_pressed() -> void:
	# Burada özel işlemler yapabilirsiniz
	# Örneğin, seçili olduğunu belirtmek için stil değiştirme
	modulate = Color(1.2, 1.2, 0.8) # Seçildiğinde rengini değiştir
	
	# Seçim işlemi üst script tarafından yönetiliyor
	# VillageUI._on_worker_button_selected() ile

func _on_focus_entered() -> void:
	# Buton odak aldığında stilini değiştir
	modulate = Color(1.1, 1.1, 0.9) # Hafif parlaklaştır

func _on_focus_exited() -> void:
	# Buton odak kaybettiğinde stilini normale çevir
	modulate = Color(1.0, 1.0, 1.0) # Normal görünüm 
